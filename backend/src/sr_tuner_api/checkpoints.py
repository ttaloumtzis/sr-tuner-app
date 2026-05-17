from __future__ import annotations

import importlib.util
import json
import shutil
from pathlib import Path
from typing import Any, Literal

from pydantic import BaseModel, Field

from .errors import ApiError
from .ids import new_id
from .jobs import Job, utc_now_iso
from .project_store import open_project, store_asset_path, write_project
from .runs import build_internal_sr_model, build_model
from .schemas import ProjectState


CHECKPOINT_SCHEMA_VERSION = 1
_APP_VERSION = "0.1.0"


class CheckpointMetadata(BaseModel):
    id: str = Field(default_factory=lambda: new_id("ckpt"))
    run_id: str
    model_id: str = ""
    epoch: int
    iteration: int
    path: str
    size_bytes: int = 0
    saved_at: str = Field(default_factory=utc_now_iso)
    metrics: dict[str, float] = Field(default_factory=dict)
    tags: list[str] = Field(default_factory=list)
    deleted: bool = False
    model_architecture: str = ""
    scale: int = 0


class CheckpointListResponse(BaseModel):
    run_id: str
    checkpoints: list[CheckpointMetadata]


class ProjectCheckpointIndex(BaseModel):
    checkpoints: list[CheckpointMetadata] = Field(default_factory=list)


class OnnxReadinessResponse(BaseModel):
    available: bool
    message: str


class ExportPthRequest(BaseModel):
    destination: str


class ExportOnnxRequest(BaseModel):
    destination: str


def save_checkpoint(
    project_root: Path,
    *,
    run_raw: dict[str, Any],
    epoch: int,
    iteration: int,
    model_state: dict[str, Any] | None = None,
    optimizer_state: dict[str, Any] | None = None,
    scheduler_state: dict[str, Any] | None = None,
    metrics: dict[str, float],
    model_config: dict[str, Any],
    dataset_id: str,
    scale: int,
    architecture: str,
    app_version: str = _APP_VERSION,
) -> CheckpointMetadata:
    """Write a checkpoint file and record metadata on the run. Returns the new metadata."""
    run_id = run_raw["id"]
    run_folder = _resolve_run_folder(project_root, run_raw)
    checkpoints_dir = run_folder / "checkpoints"
    checkpoints_dir.mkdir(parents=True, exist_ok=True)

    filename = f"epoch_{epoch:04d}_iter_{iteration:06d}.pth"
    checkpoint_path = checkpoints_dir / filename

    payload: dict[str, Any] = {
        "schema_version": CHECKPOINT_SCHEMA_VERSION,
        "app_version": app_version,
        "epoch": epoch,
        "iteration": iteration,
        "model_config": model_config,
        "dataset_id": dataset_id,
        "scale": scale,
        "architecture": architecture,
        "metrics": metrics,
    }
    if model_state is not None:
        payload["model_state_dict"] = model_state
    if optimizer_state is not None:
        payload["optimizer_state_dict"] = optimizer_state
    if scheduler_state is not None:
        payload["scheduler_state_dict"] = scheduler_state

    if _module_available("torch"):
        import torch
        torch.save(payload, checkpoint_path)
    else:
        _write_payload_json(checkpoint_path, payload)

    size_bytes = checkpoint_path.stat().st_size if checkpoint_path.exists() else 0
    stored_path = store_asset_path(project_root, checkpoint_path).stored

    meta = CheckpointMetadata(
        run_id=run_id,
        epoch=epoch,
        iteration=iteration,
        path=stored_path,
        size_bytes=size_bytes,
        metrics=metrics,
        model_architecture=architecture,
        scale=scale,
    )

    project = open_project(project_root)
    for index, raw in enumerate(project.runs):
        if raw.get("id") == run_id:
            existing = [CheckpointMetadata.model_validate(c) for c in raw.get("checkpoints", [])]
            existing.append(meta)
            _assign_markers(existing)
            raw["checkpoints"] = [c.model_dump() for c in existing]
            raw["updated_at"] = utc_now_iso()
            project.runs[index] = raw
            break
    write_project(project)
    return meta


def validate_checkpoint_payload(
    project_root: Path,
    checkpoint_path_stored: str,
    *,
    expected_architecture: str | None = None,
    expected_scale: int | None = None,
) -> dict[str, Any]:
    """Load and validate a checkpoint payload. Raises ApiError on any failure."""
    full_path = _resolve_stored_path(project_root, checkpoint_path_stored)
    if not full_path.exists():
        raise ApiError(404, "checkpoint_file_missing", "Checkpoint file was not found.", details={"path": checkpoint_path_stored})

    payload = _load_payload(full_path)

    missing = [field for field in ("schema_version", "epoch", "iteration", "model_config", "dataset_id", "scale") if field not in payload]
    if missing:
        raise ApiError(422, "checkpoint_payload_invalid", "Checkpoint payload is missing required fields.", details={"missing": missing})

    schema_v = payload.get("schema_version")
    if schema_v != CHECKPOINT_SCHEMA_VERSION:
        raise ApiError(422, "checkpoint_schema_unsupported", f"Checkpoint schema version {schema_v} is not supported.", details={"expected": CHECKPOINT_SCHEMA_VERSION})

    if expected_architecture is not None:
        actual = payload.get("architecture", payload.get("model_config", {}).get("architecture", ""))
        if actual != expected_architecture:
            raise ApiError(422, "checkpoint_architecture_mismatch", "Checkpoint architecture does not match.", details={"expected": expected_architecture, "actual": actual})

    if expected_scale is not None:
        actual_scale = payload.get("scale")
        if actual_scale != expected_scale:
            raise ApiError(422, "checkpoint_scale_mismatch", "Checkpoint scale does not match.", details={"expected": expected_scale, "actual": actual_scale})

    return payload


def list_run_checkpoints(project_root: Path, run_id: str) -> CheckpointListResponse:
    project = open_project(project_root)
    raw_run = _find_run_raw(project, run_id)
    checkpoints = [CheckpointMetadata.model_validate(c) for c in raw_run.get("checkpoints", [])]
    _assign_markers(checkpoints)
    return CheckpointListResponse(run_id=run_id, checkpoints=checkpoints)


def derive_project_checkpoints(project_root: Path) -> ProjectCheckpointIndex:
    project = open_project(project_root)
    all_checkpoints: list[CheckpointMetadata] = []
    for raw_run in project.runs:
        for raw_ckpt in raw_run.get("checkpoints", []):
            all_checkpoints.append(CheckpointMetadata.model_validate(raw_ckpt))
    all_checkpoints.sort(key=lambda c: c.saved_at)
    return ProjectCheckpointIndex(checkpoints=all_checkpoints)


def delete_checkpoint(project_root: Path, run_id: str, checkpoint_id: str) -> CheckpointListResponse:
    project = open_project(project_root)
    raw_run = _find_run_raw(project, run_id)
    checkpoints = [CheckpointMetadata.model_validate(c) for c in raw_run.get("checkpoints", [])]
    target = next((c for c in checkpoints if c.id == checkpoint_id), None)
    if target is None:
        raise ApiError(404, "checkpoint_not_found", "Checkpoint was not found.", details={"checkpoint_id": checkpoint_id})
    if target.deleted:
        raise ApiError(409, "checkpoint_already_deleted", "Checkpoint has already been deleted.")

    full_path = _resolve_stored_path(project_root, target.path)
    if full_path.exists():
        full_path.unlink()

    target.deleted = True
    target.tags = []
    _assign_markers([c for c in checkpoints if not c.deleted])

    _save_run_checkpoints(project, run_id, checkpoints)
    return CheckpointListResponse(run_id=run_id, checkpoints=checkpoints)


def export_checkpoint_pth(project_root: Path, run_id: str, checkpoint_id: str, destination: str) -> Job:
    project = open_project(project_root)
    raw_run = _find_run_raw(project, run_id)
    checkpoints = [CheckpointMetadata.model_validate(c) for c in raw_run.get("checkpoints", [])]
    target = _get_active_checkpoint(checkpoints, checkpoint_id)

    src = _resolve_stored_path(project_root, target.path)
    if not src.exists():
        raise ApiError(404, "checkpoint_file_missing", "Checkpoint file was not found.")

    dest = Path(destination)
    if dest.is_dir():
        dest = dest / src.name

    shutil.copy2(src, dest)

    job = Job(
        type="export_pth",
        project_id=project.id,
        object_id=checkpoint_id,
        status="completed",
        progress=1.0,
        started_at=utc_now_iso(),
        finished_at=utc_now_iso(),
        logs=[f"Exported {src.name} to {dest}."],
    )
    return job


def export_checkpoint_onnx(project_root: Path, run_id: str | None = None, checkpoint_id: str | None = None, destination: str = "", model_id: str | None = None, output_scale: int | None = None) -> Job:
    readiness = onnx_readiness()
    if not readiness.available:
        raise ApiError(409, "onnx_unavailable", readiness.message)

    import torch
    import torch.onnx

    project = open_project(project_root)

    if model_id is not None:
        if output_scale is None:
            raise ApiError(422, "output_scale_required", "Output scale is required for model-based ONNX export.")
        model_raw = next((m for m in project.models if m.get("id") == model_id), None)
        if model_raw is None:
            raise ApiError(404, "model_not_found", "Model was not found.", details={"model_id": model_id})
        if not model_raw.get("trained_core_weights_path"):
            raise ApiError(422, "model_not_trained", "Model has no trained core weights.")
        num_features = model_raw.get("num_features", 32)
        num_blocks = model_raw.get("num_blocks", 4)
        from .models import ModelObject
        _tmp = ModelObject.model_validate(model_raw)
        model = build_model(_tmp, output_scale)
        core_path_str = model_raw.get("trained_core_weights_path")
        if core_path_str:
            core_path = Path(core_path_str)
            if not core_path.is_absolute():
                core_path = project_root / core_path
            if core_path.exists():
                core_state = torch.load(core_path, map_location="cpu", weights_only=False)
                if any(not k.startswith("body.") for k in core_state):
                    model.load_state_dict(core_state, strict=True)
                else:
                    adjusted = {k.removeprefix("body."): v for k, v in core_state.items()}
                    model.body.load_state_dict(adjusted, strict=False)
        model.eval()
        dest = Path(destination)
        if dest.is_dir():
            dest = dest / f"model_{model_id}_x{output_scale}.onnx"
        dummy = torch.zeros(1, 3, 64, 64)
        torch.onnx.export(model, dummy, str(dest), opset_version=17, input_names=["lr"], output_names=["sr"])
        job = Job(
            type="export_onnx",
            project_id=project.id,
            object_id=model_id,
            status="completed",
            progress=1.0,
            started_at=utc_now_iso(),
            finished_at=utc_now_iso(),
            logs=[f"Exported ONNX model to {dest}."],
        )
        return job

    if checkpoint_id is None or run_id is None:
        raise ApiError(422, "export_source_required", "Provide checkpoint_id+run_id or model_id.")
    raw_run = _find_run_raw(project, run_id)
    checkpoints = [CheckpointMetadata.model_validate(c) for c in raw_run.get("checkpoints", [])]
    target = _get_active_checkpoint(checkpoints, checkpoint_id)
    payload = validate_checkpoint_payload(project_root, target.path)

    model_config = payload.get("model_config", {})
    scale = payload.get("scale", target.scale)
    num_features = model_config.get("num_features", 32)
    num_blocks = model_config.get("num_blocks", 4)
    arch = model_config.get("architecture", "internal_residual_pixelshuffle")
    res_scale = model_config.get("res_scale", 0.1)

    from .models import ModelObject
    _tmp = ModelObject(name="tmp", slug="tmp", architecture=arch, res_scale=res_scale,
                       num_features=num_features, num_blocks=num_blocks)
    model = build_model(_tmp, scale)
    state = payload.get("model_state_dict")
    if state is not None:
        model.load_state_dict(state)
    model.eval()

    dummy = torch.zeros(1, 3, 64, 64)
    dest = Path(destination)
    if dest.is_dir():
        dest = dest / f"checkpoint_{target.epoch:04d}.onnx"

    torch.onnx.export(model, dummy, str(dest), opset_version=17, input_names=["lr"], output_names=["sr"])

    job = Job(
        type="export_onnx",
        project_id=project.id,
        object_id=checkpoint_id,
        status="completed",
        progress=1.0,
        started_at=utc_now_iso(),
        finished_at=utc_now_iso(),
        logs=[f"Exported ONNX checkpoint to {dest}."],
    )
    return job


def onnx_readiness() -> OnnxReadinessResponse:
    if not _module_available("torch"):
        return OnnxReadinessResponse(available=False, message="PyTorch is not installed.")
    if not _module_available("onnx"):
        return OnnxReadinessResponse(available=False, message="ONNX package is not installed.")
    return OnnxReadinessResponse(available=True, message="ONNX export is available.")


def _assign_markers(checkpoints: list[CheckpointMetadata]) -> None:
    active = [c for c in checkpoints if not c.deleted]
    for c in active:
        c.tags = [t for t in c.tags if t not in ("latest", "best_psnr", "best_loss")]

    if not active:
        return

    latest = max(active, key=lambda c: c.saved_at)
    latest.tags = list({*latest.tags, "latest"})

    psnr_candidates = [c for c in active if "val_psnr" in c.metrics and c.metrics["val_psnr"] > 0]
    if psnr_candidates:
        best_psnr = max(psnr_candidates, key=lambda c: c.metrics["val_psnr"])
        best_psnr.tags = list({*best_psnr.tags, "best_psnr"})

    loss_candidates = [c for c in active if "train_loss_total" in c.metrics]
    if loss_candidates:
        best_loss = min(loss_candidates, key=lambda c: c.metrics["train_loss_total"])
        best_loss.tags = list({*best_loss.tags, "best_loss"})


def _get_active_checkpoint(checkpoints: list[CheckpointMetadata], checkpoint_id: str) -> CheckpointMetadata:
    target = next((c for c in checkpoints if c.id == checkpoint_id), None)
    if target is None:
        raise ApiError(404, "checkpoint_not_found", "Checkpoint was not found.", details={"checkpoint_id": checkpoint_id})
    if target.deleted:
        raise ApiError(409, "checkpoint_deleted", "Checkpoint has been deleted and cannot be used.")
    return target


def _save_run_checkpoints(project: ProjectState, run_id: str, checkpoints: list[CheckpointMetadata]) -> None:
    for index, raw in enumerate(project.runs):
        if raw.get("id") == run_id:
            raw["checkpoints"] = [c.model_dump() for c in checkpoints]
            raw["updated_at"] = utc_now_iso()
            project.runs[index] = raw
            break
    write_project(project)


def _find_run_raw(project: ProjectState, run_id: str) -> dict[str, Any]:
    for raw in project.runs:
        if raw.get("id") == run_id:
            return raw
    raise ApiError(404, "run_not_found", "Run was not found.", details={"run_id": run_id})


def _resolve_run_folder(project_root: Path, run_raw: dict[str, Any]) -> Path:
    folder = Path(run_raw["folder"])
    if folder.is_absolute():
        return folder
    return project_root / folder


def _resolve_stored_path(project_root: Path, stored: str) -> Path:
    path = Path(stored)
    if path.is_absolute():
        return path
    return project_root / path


def _load_payload(path: Path) -> dict[str, Any]:
    if path.suffix == ".json":
        return json.loads(path.read_text(encoding="utf-8"))
    if _module_available("torch"):
        import torch
        try:
            return torch.load(path, map_location="cpu", weights_only=False)
        except Exception:
            pass
    try:
        return json.loads(path.read_bytes())
    except Exception:
        raise ApiError(422, "checkpoint_unreadable", "Checkpoint file could not be read. PyTorch may be required for .pth files.")


def _write_payload_json(path: Path, payload: dict[str, Any]) -> None:
    safe = {k: v for k, v in payload.items() if k not in ("model_state_dict", "optimizer_state_dict", "scheduler_state_dict")}
    Path(str(path) + ".json").write_text(json.dumps(safe, indent=2), encoding="utf-8")
    path.write_bytes(json.dumps(safe).encode())


def _module_available(name: str) -> bool:
    try:
        return importlib.util.find_spec(name) is not None
    except (ModuleNotFoundError, ValueError):
        return False


def extract_core_weights(checkpoint_path: Path) -> dict[str, Any]:
    """Load a checkpoint and return the full model state dict (all layers).

    The returned dict is saved directly to disk and loaded back via
    model.load_state_dict() so that head, body, and tail are all restored.
    """
    payload = _load_payload(checkpoint_path)
    state = payload.get("model_state_dict")
    if state is None:
        raise ApiError(422, "checkpoint_no_state", "Checkpoint has no model_state_dict.", details={"path": str(checkpoint_path)})
    if not state:
        raise ApiError(422, "core_weights_empty", "Checkpoint model_state_dict is empty.", details={"path": str(checkpoint_path)})
    return state


def _save_core_weights(core_state: dict[str, Any], model_core_dir: Path, run_id: str) -> Path:
    model_core_dir.mkdir(parents=True, exist_ok=True)
    core_path = model_core_dir / f"{run_id}_core.pth"
    if _module_available("torch"):
        import torch
        torch.save(core_state, core_path)
    else:
        core_path.write_text(json.dumps({"core_weights": {k: v.tolist() if hasattr(v, 'tolist') else v for k, v in core_state.items()}}), encoding="utf-8")
    return core_path


def _save_core_metadata(model_core_dir: Path, model_id: str, source_checkpoint_path: str, run_id: str) -> Path:
    meta = {
        "model_id": model_id,
        "extracted_at": utc_now_iso(),
        "source_checkpoint": source_checkpoint_path,
        "input_channels": 3,
        "output_channels": 3,
        "run_id": run_id,
    }
    meta_path = model_core_dir / f"{run_id}_core.json"
    meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    return meta_path


def extract_and_save_core_weights(
    checkpoint_path: Path,
    project_root: Path,
    model_id: str,
    run_id: str,
) -> str:
    """Extract core weights from a checkpoint and save to models/<model_id>/core_weights/.

    Returns the relative stored path to the saved core weights file.
    """
    core = extract_core_weights(checkpoint_path)
    model_core_dir = project_root / "models" / model_id / "core_weights"
    core_path = _save_core_weights(core, model_core_dir, run_id)
    stored = store_asset_path(project_root, core_path).stored
    _save_core_metadata(model_core_dir, model_id, str(checkpoint_path), run_id)
    return stored