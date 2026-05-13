from __future__ import annotations

import importlib.util
import time
from pathlib import Path
from typing import Any, Literal

from pydantic import BaseModel, Field

from .checkpoints import CheckpointMetadata, _get_active_checkpoint, validate_checkpoint_payload
from .datasets import SUPPORTED_IMAGE_EXTENSIONS
from .diagnostic_logger import create_component_logger
from .errors import ApiError
from .ids import new_id
from .jobs import Job, JobError, utc_now_iso
from . import logging_schema as log_schema
from .project_store import open_project, store_asset_path, write_project
from .runs import DependencyItem, available_devices

_log = create_component_logger(log_schema.COMPONENT_INFERENCE)


PaddingMode = Literal["reflect", "replicate", "constant"]
BlendStrategy = Literal["average", "linear"]
InferenceMode = Literal["single", "batch"]


class TileConfig(BaseModel):
    enabled: bool = False
    tile_size: int = Field(default=512, ge=64)
    overlap: int = Field(default=32, ge=0)
    padding_mode: PaddingMode = "reflect"
    blend_strategy: BlendStrategy = "average"


class InferenceRequest(BaseModel):
    checkpoint_id: str
    run_id: str
    input_path: str
    output_dir: str | None = None
    output_format: Literal["png", "jpg"] = "png"
    mode: InferenceMode = "single"
    device: str = "cpu"
    tile_config: TileConfig = Field(default_factory=TileConfig)


class InferenceReadinessResponse(BaseModel):
    available: bool
    dependencies: list[DependencyItem]
    message: str


class PerFileResult(BaseModel):
    filename: str
    status: Literal["success", "failed"]
    output_path: str | None = None
    error: str | None = None


class InferenceRecord(BaseModel):
    id: str = Field(default_factory=lambda: new_id("inf"))
    checkpoint_id: str
    run_id: str
    checkpoint_path: str
    scale: int
    mode: InferenceMode
    input_path: str
    output_path: str | None = None
    output_dir: str | None = None
    device: str
    tile_config: TileConfig = Field(default_factory=TileConfig)
    runtime_seconds: float = 0.0
    metrics: dict[str, float] = Field(default_factory=dict)
    per_file_results: list[PerFileResult] = Field(default_factory=list)
    status: Literal["completed", "partial", "failed"] = "completed"
    created_at: str = Field(default_factory=utc_now_iso)


class InferenceHistoryResponse(BaseModel):
    records: list[InferenceRecord]


def inference_readiness(device: str = "cpu") -> InferenceReadinessResponse:
    torch_ok = _module_available("torch")
    pil_ok = _module_available("PIL")

    device_ok = any(d.id == device for d in available_devices().devices)
    deps = [
        DependencyItem(
            name="torch",
            available=torch_ok,
            required=True,
            message="PyTorch is available." if torch_ok else "PyTorch is not installed.",
        ),
        DependencyItem(
            name="image_loading",
            available=pil_ok,
            required=True,
            message="Pillow is available." if pil_ok else "Pillow is required for image loading.",
        ),
        DependencyItem(
            name="device",
            available=device_ok,
            required=True,
            message=f"Device '{device}' is available." if device_ok else f"Device '{device}' is not available.",
        ),
    ]
    missing = [d for d in deps if d.required and not d.available]
    return InferenceReadinessResponse(
        available=not missing,
        dependencies=deps,
        message="Inference dependencies are ready." if not missing else "Required inference dependencies are missing.",
    )


def run_inference(project_root: Path, request: InferenceRequest) -> tuple[InferenceRecord, Job]:
    readiness = inference_readiness(request.device)
    if not readiness.available:
        _log.error(
            log_schema.EventNames.INFERENCE_FAILED,
            "Inference dependencies missing.",
            context={"device": request.device, "mode": request.mode},
        )
        raise ApiError(
            409,
            "inference_dependencies_missing",
            readiness.message,
            details={"dependencies": [d.model_dump() for d in readiness.dependencies]},
        )

    project = open_project(project_root)
    checkpoint = _resolve_checkpoint(project, request.run_id, request.checkpoint_id)
    payload = validate_checkpoint_payload(project_root, checkpoint.path)
    scale = payload.get("scale", checkpoint.scale)

    output_dir = _resolve_output_dir(project_root, project, request)
    output_dir.mkdir(parents=True, exist_ok=True)

    job = Job(
        type="inference",
        project_id=project.id,
        object_id=request.checkpoint_id,
        status="running",
        started_at=utc_now_iso(),
        logs=["Inference started."],
    )

    _log.info(
        log_schema.EventNames.INFERENCE_SUBMIT,
        f"Inference {request.mode} submitted.",
        context={"mode": request.mode, "device": request.device, "input_path": request.input_path, "scale": scale},
    )

    start = time.monotonic()
    per_file_results: list[PerFileResult] = []
    final_output_path: str | None = None

    if request.mode == "single":
        input_path = Path(request.input_path)
        if not input_path.exists():
            raise ApiError(422, "input_not_found", "Input image was not found.", details={"path": str(input_path)})
        try:
            out = _infer_single(input_path, output_dir, payload, scale, request)
            final_output_path = str(out)
            per_file_results.append(PerFileResult(filename=input_path.name, status="success", output_path=str(out)))
            job.logs.append(f"Processed {input_path.name}.")
        except ApiError:
            raise
        except Exception as exc:
            _handle_oom_or_raise(exc)
    else:
        input_dir = Path(request.input_path)
        if not input_dir.is_dir():
            raise ApiError(422, "input_folder_not_found", "Input folder was not found.", details={"path": str(input_dir)})
        image_files = _list_images(input_dir)
        if not image_files:
            raise ApiError(422, "no_images_found", "No supported images found in input folder.")
        job.logs.append(f"Found {len(image_files)} images.")
        for img_path in image_files:
            try:
                out = _infer_single(img_path, output_dir, payload, scale, request)
                per_file_results.append(PerFileResult(filename=img_path.name, status="success", output_path=str(out)))
            except Exception as exc:
                err_msg = str(exc)
                if _is_oom(exc):
                    err_msg = _oom_message()
                per_file_results.append(PerFileResult(filename=img_path.name, status="failed", error=err_msg))

    elapsed = time.monotonic() - start

    successes = [r for r in per_file_results if r.status == "success"]
    failures = [r for r in per_file_results if r.status == "failed"]
    if not successes:
        record_status: Literal["completed", "partial", "failed"] = "failed"
    elif failures:
        record_status = "partial"
    else:
        record_status = "completed"

    job.status = "completed" if record_status != "failed" else "failed"
    if record_status == "failed":
        job.error = JobError(code="inference_failed", message="All images failed to process.", recoverable=True)
    job.progress = len(successes) / max(len(per_file_results), 1)
    job.finished_at = utc_now_iso()
    job.logs.append(f"Finished in {elapsed:.1f}s. {len(successes)}/{len(per_file_results)} succeeded.")

    if record_status == "failed":
        _log.error(
            log_schema.EventNames.INFERENCE_FAILED,
            f"Inference failed: 0/{len(per_file_results)} succeeded.",
            context={"mode": request.mode, "elapsed_seconds": round(elapsed, 2), "total": len(per_file_results)},
        )
    elif record_status == "partial":
        _log.warn(
            log_schema.EventNames.INFERENCE_FAILED,
            f"Inference partial: {len(successes)}/{len(per_file_results)} succeeded.",
            context={
                "mode": request.mode, "elapsed_seconds": round(elapsed, 2),
                "successes": len(successes), "failures": len(failures),
            },
        )
    else:
        _log.info(
            log_schema.EventNames.INFERENCE_COMPLETE,
            f"Inference {request.mode} completed.",
            context={
                "mode": request.mode, "elapsed_seconds": round(elapsed, 2),
                "total_files": len(per_file_results),
            },
        )

    if request.mode == "batch":
        _log.info(
            log_schema.EventNames.INFERENCE_BATCH_SUMMARY,
            f"Batch inference summary: {len(successes)}/{len(per_file_results)} succeeded.",
            context={
                "mode": "batch", "elapsed_seconds": round(elapsed, 2),
                "successes": len(successes), "failures": len(failures),
                "total": len(per_file_results),
            },
        )

    stored_output_dir = store_asset_path(project_root, output_dir).stored
    record = InferenceRecord(
        checkpoint_id=request.checkpoint_id,
        run_id=request.run_id,
        checkpoint_path=checkpoint.path,
        scale=scale,
        mode=request.mode,
        input_path=request.input_path,
        output_path=final_output_path,
        output_dir=stored_output_dir,
        device=request.device,
        tile_config=request.tile_config,
        runtime_seconds=elapsed,
        per_file_results=per_file_results,
        status=record_status,
    )

    project = open_project(project_root)
    project.inference_history.append(record.model_dump())
    write_project(project)

    return record, job


def list_inference_history(project_root: Path) -> InferenceHistoryResponse:
    project = open_project(project_root)
    records = [InferenceRecord.model_validate(r) for r in project.inference_history]
    return InferenceHistoryResponse(records=records)


# ── private helpers ────────────────────────────────────────────────────────────

def _infer_single(
    img_path: Path,
    output_dir: Path,
    payload: dict[str, Any],
    scale: int,
    request: InferenceRequest,
) -> Path:
    import torch
    from PIL import Image

    from .runs import build_internal_sr_model

    model_config = payload.get("model_config", {})
    num_features = model_config.get("num_features", 32)
    num_blocks = model_config.get("num_blocks", 4)

    model = build_internal_sr_model(scale=scale, num_features=num_features, num_blocks=num_blocks)
    state = payload.get("model_state_dict")
    if state is not None:
        model.load_state_dict(state)
    model.eval()

    device = torch.device(request.device)
    model = model.to(device)

    image = Image.open(img_path).convert("RGB")
    tensor = _pil_to_tensor(image).unsqueeze(0).to(device)

    with torch.no_grad():
        if request.tile_config.enabled:
            out_tensor = _tiled_inference(model, tensor, request.tile_config, scale)
        else:
            out_tensor = model(tensor)

    out_image = _tensor_to_pil(out_tensor.squeeze(0).cpu())
    stem = img_path.stem
    ext = "." + request.output_format
    out_path = output_dir / (stem + "_sr" + ext)
    if request.output_format == "jpg":
        out_image.save(out_path, quality=95)
    else:
        out_image.save(out_path)
    return out_path


def _tiled_inference(model, tensor, tile_cfg: TileConfig, scale: int):
    import torch
    import torch.nn.functional as F

    _, _, H, W = tensor.shape
    ts = tile_cfg.tile_size
    overlap = tile_cfg.overlap
    pad_mode = tile_cfg.padding_mode
    stride = ts - overlap

    # Pad input so it fits tile grid
    pad_h = max(0, ts - H) if H < ts else 0
    pad_w = max(0, ts - W) if W < ts else 0
    if pad_h > 0 or pad_w > 0:
        tensor = F.pad(tensor, (0, pad_w, 0, pad_h), mode=pad_mode if pad_mode != "constant" else "constant", value=0)
    _, _, H_pad, W_pad = tensor.shape

    out_H = H_pad * scale
    out_W = W_pad * scale
    output = torch.zeros(1, 3, out_H, out_W, device=tensor.device)
    weight = torch.zeros(1, 1, out_H, out_W, device=tensor.device)

    y_starts = list(range(0, H_pad - ts + 1, stride))
    if not y_starts or y_starts[-1] + ts < H_pad:
        y_starts.append(max(0, H_pad - ts))

    x_starts = list(range(0, W_pad - ts + 1, stride))
    if not x_starts or x_starts[-1] + ts < W_pad:
        x_starts.append(max(0, W_pad - ts))

    for y0 in y_starts:
        for x0 in x_starts:
            tile = tensor[:, :, y0:y0 + ts, x0:x0 + ts]
            with torch.no_grad():
                tile_out = model(tile)

            oy0, ox0 = y0 * scale, x0 * scale
            oy1, ox1 = oy0 + tile_out.shape[2], ox0 + tile_out.shape[3]

            if tile_cfg.blend_strategy == "linear":
                blend = _linear_blend_mask(tile_out.shape[2], tile_out.shape[3], device=tensor.device)
            else:
                blend = torch.ones(1, 1, tile_out.shape[2], tile_out.shape[3], device=tensor.device)

            output[:, :, oy0:oy1, ox0:ox1] += tile_out * blend
            weight[:, :, oy0:oy1, ox0:ox1] += blend

    output = output / weight.clamp(min=1e-6)
    return output[:, :, : H * scale, : W * scale]


def _linear_blend_mask(h: int, w: int, device) -> "torch.Tensor":
    import torch

    hy = torch.linspace(0, 1, h // 2, device=device)
    hy = torch.cat([hy, hy.flip(0)] if h % 2 == 0 else [hy, hy[-1:], hy.flip(0)])
    hx = torch.linspace(0, 1, w // 2, device=device)
    hx = torch.cat([hx, hx.flip(0)] if w % 2 == 0 else [hx, hx[-1:], hx.flip(0)])
    mask = (hy.unsqueeze(1) * hx.unsqueeze(0)).clamp(min=0.01)
    return mask.unsqueeze(0).unsqueeze(0)


def _pil_to_tensor(image) -> "torch.Tensor":
    import torch

    w, h = image.size
    data = torch.ByteTensor(torch.ByteStorage.from_buffer(image.tobytes()))
    return data.view(h, w, 3).permute(2, 0, 1).float() / 255.0


def _tensor_to_pil(tensor) -> "PIL.Image.Image":
    from PIL import Image

    arr = (tensor.clamp(0, 1) * 255).byte().permute(1, 2, 0).numpy()
    return Image.fromarray(arr, "RGB")


def _resolve_checkpoint(project, run_id: str, checkpoint_id: str) -> CheckpointMetadata:
    for raw in project.runs:
        if raw.get("id") != run_id:
            continue
        checkpoints = [CheckpointMetadata.model_validate(c) for c in raw.get("checkpoints", [])]
        return _get_active_checkpoint(checkpoints, checkpoint_id)
    raise ApiError(404, "run_not_found", "Run was not found.", details={"run_id": run_id})


def _resolve_output_dir(project_root: Path, project, request: InferenceRequest) -> Path:
    if request.output_dir:
        return Path(request.output_dir)
    return project_root / "inference" / request.checkpoint_id


def _list_images(folder: Path) -> list[Path]:
    return sorted(
        p for p in folder.iterdir()
        if p.is_file() and not p.name.startswith(".")
        and p.suffix.lower().lstrip(".") in SUPPORTED_IMAGE_EXTENSIONS
    )


def _is_oom(exc: Exception) -> bool:
    msg = str(exc).lower()
    return "out of memory" in msg or "cuda out of memory" in msg or "allocat" in msg


def _oom_message() -> str:
    return (
        "Out-of-memory error during inference. "
        "Try enabling tiling with a smaller tile size, switching to CPU, or reducing concurrency."
    )


def _handle_oom_or_raise(exc: Exception) -> None:
    if _is_oom(exc):
        raise ApiError(
            422,
            "inference_oom",
            _oom_message(),
            recoverable=True,
        )
    raise exc


def _module_available(name: str) -> bool:
    try:
        return importlib.util.find_spec(name) is not None
    except (ModuleNotFoundError, ValueError):
        return False
