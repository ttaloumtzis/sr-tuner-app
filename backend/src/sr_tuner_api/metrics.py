from __future__ import annotations

import json
import math
import os
import re
import shutil
import struct
import subprocess
import zlib
from pathlib import Path
from typing import Any, Literal

from pydantic import BaseModel, Field

from .errors import ApiError
from .project_store import open_project, store_asset_path, write_project
from .runs import ACTIVE_RUN_STATES, RunObject, get_run
from .schemas import ProjectState, utc_now_iso


MetricKind = Literal["loss", "quality", "learning_rate", "progress", "speed"]
MetricScope = Literal["train", "validation", "system"]
TelemetryAvailability = Literal["available", "unavailable"]


class MetricDefinition(BaseModel):
    name: str
    label: str
    kind: MetricKind
    unit: str | None = None
    scope: MetricScope
    channel_policy: str | None = None
    value_range: str | None = None
    aggregation_scope: str | None = None
    components: list[str] = Field(default_factory=list)
    speed_window: str | None = None


class MetricRecord(BaseModel):
    step: int
    epoch: int
    iteration: int
    recorded_at: str = Field(default_factory=utc_now_iso)
    values: dict[str, float]
    components: dict[str, float] = Field(default_factory=dict)


class MetricsResponse(BaseModel):
    run_id: str
    definitions: dict[str, MetricDefinition]
    records: list[MetricRecord]


class ActiveRunStatus(BaseModel):
    run: RunObject | None = None
    model: dict[str, Any] | None = None
    dataset: dict[str, Any] | None = None
    epoch: int = 0
    iteration: int = 0
    progress: float = 0.0
    phase: str = "idle"
    latest_metrics: dict[str, float] = Field(default_factory=dict)


class LiveStatusSnapshot(BaseModel):
    epoch: int
    iteration: int
    progress: float
    phase: str = "training"
    latest_metrics: dict[str, float] = Field(default_factory=dict)


class TelemetryField(BaseModel):
    available: TelemetryAvailability
    value: float | str | None = None
    unit: str | None = None
    reason: str | None = None


class HardwareTelemetry(BaseModel):
    device: str
    device_type: str
    memory_used: TelemetryField
    memory_total: TelemetryField
    utilization: TelemetryField
    temperature: TelemetryField
    iteration_speed: TelemetryField


class PreviewAsset(BaseModel):
    kind: Literal["lr", "sr", "hr", "diff_absolute", "diff_heatmap"]
    path: str
    url: str
    width: int
    height: int


class PreviewResponse(BaseModel):
    run_id: str
    generated_at: str | None
    diff_mode: str
    assets: list[PreviewAsset] = Field(default_factory=list)


DEFAULT_METRIC_DEFINITIONS: dict[str, MetricDefinition] = {
    "train_loss_total": MetricDefinition(
        name="train_loss_total",
        label="Train Loss",
        kind="loss",
        scope="train",
        components=["l1"],
        aggregation_scope="last interval",
    ),
    "val_psnr": MetricDefinition(
        name="val_psnr",
        label="PSNR",
        kind="quality",
        unit="dB",
        scope="validation",
        channel_policy="RGB",
        value_range="0..1",
        aggregation_scope="preview batch",
    ),
    "val_ssim": MetricDefinition(
        name="val_ssim",
        label="SSIM",
        kind="quality",
        scope="validation",
        channel_policy="RGB",
        value_range="0..1",
        aggregation_scope="preview batch",
    ),
    "learning_rate": MetricDefinition(
        name="learning_rate",
        label="Learning Rate",
        kind="learning_rate",
        scope="train",
    ),
    "progress": MetricDefinition(
        name="progress",
        label="Progress",
        kind="progress",
        unit="ratio",
        scope="train",
    ),
    "iterations_per_second": MetricDefinition(
        name="iterations_per_second",
        label="Speed",
        kind="speed",
        unit="it/s",
        scope="system",
        speed_window="moving average",
    ),
}

_LIVE_STATUS: dict[str, LiveStatusSnapshot] = {}


def _live_status_key(project_root: Path, run_id: str) -> str:
    return f"{project_root.resolve()}::{run_id}"


def set_live_status(
    project_root: Path,
    run_id: str,
    *,
    epoch: int,
    iteration: int,
    progress: float,
    latest_metrics: dict[str, float],
    phase: str = "training",
) -> None:
    _LIVE_STATUS[_live_status_key(project_root, run_id)] = LiveStatusSnapshot(
        epoch=epoch,
        iteration=iteration,
        progress=progress,
        phase=phase,
        latest_metrics=latest_metrics,
    )


def get_live_status(project_root: Path, run_id: str) -> LiveStatusSnapshot | None:
    return _LIVE_STATUS.get(_live_status_key(project_root, run_id))


def initialize_run_metrics(project_root: Path, run: RunObject) -> RunObject:
    run_dir = _run_dir(project_root, run)
    run_dir.mkdir(parents=True, exist_ok=True)
    definitions_path = run_dir / "metric_definitions.json"
    definitions = {key: value.model_dump() for key, value in DEFAULT_METRIC_DEFINITIONS.items()}
    definitions_path.write_text(json.dumps(definitions, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    run.metadata["metric_definitions_path"] = store_asset_path(project_root, definitions_path).stored
    metrics_path = _metrics_path(project_root, run)
    metrics_path.touch()
    run.metadata["metrics_path"] = store_asset_path(project_root, metrics_path).stored
    run.metadata["telemetry"] = hardware_telemetry(run).model_dump()
    project = open_project(project_root)
    for index, raw in enumerate(project.runs):
        if raw.get("id") == run.id:
            project.runs[index] = run.model_dump()
            write_project(project)
            break
    return run


def write_metric_record(project_root: Path, run: RunObject, record: MetricRecord) -> None:
    path = _metrics_path(project_root, run)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as stream:
        stream.write(record.model_dump_json() + "\n")


def read_metrics(project_root: Path, run_id: str, *, limit: int = 200) -> MetricsResponse:
    run = get_run(project_root, run_id)
    definitions = _read_definitions(project_root, run)
    records: list[MetricRecord] = []
    path = _metrics_path(project_root, run)
    if path.exists():
        lines = path.read_text(encoding="utf-8").splitlines()[-limit:]
        for line in lines:
            if line.strip():
                records.append(MetricRecord.model_validate_json(line))
    return MetricsResponse(run_id=run.id, definitions=definitions, records=records)


def active_run_status(project_root: Path) -> ActiveRunStatus:
    project = open_project(project_root)
    run = _select_active_or_recent_run(project)
    if run is None:
        return ActiveRunStatus()
    metrics = read_metrics(project_root, run.id, limit=1)
    latest = metrics.records[-1] if metrics.records else None
    live = get_live_status(project_root, run.id) if run.state in ACTIVE_RUN_STATES else None
    return ActiveRunStatus(
        run=run,
        model=next((item for item in project.models if item.get("id") == run.model_id), None),
        dataset=next((item for item in project.datasets if item.get("id") == run.dataset_id), None),
        epoch=live.epoch if live else (latest.epoch if latest else 0),
        iteration=live.iteration if live else (latest.iteration if latest else 0),
        progress=live.progress if live else (latest.values.get("progress", 0.0) if latest else 0.0),
        phase=live.phase if live else "idle",
        latest_metrics=live.latest_metrics if live else (latest.values if latest else {}),
    )


def hardware_telemetry(run: RunObject | None = None) -> HardwareTelemetry:
    device = run.settings.device if run is not None else "cpu"
    device_type = device.split(":", maxsplit=1)[0]
    latest_speed = _latest_speed(run) if run is not None else None
    memory_used = _unavailable("Runtime memory telemetry is not available for this device.")
    memory_total = _unavailable("Runtime memory telemetry is not available for this device.")
    utilization = _unavailable("Utilization telemetry is not available for this device.")
    temperature = _unavailable("Temperature telemetry is not available for this device.")
    if device.startswith("cuda"):
        memory_used, memory_total, utilization, temperature = _cuda_telemetry(device)
    elif device == "cpu":
        memory_used, memory_total, utilization, temperature = _cpu_telemetry()
    return HardwareTelemetry(
        device=device,
        device_type=device_type,
        memory_used=memory_used,
        memory_total=memory_total,
        utilization=utilization,
        temperature=temperature,
        iteration_speed=TelemetryField(
            available="available" if latest_speed is not None else "unavailable",
            value=latest_speed,
            unit="it/s" if latest_speed is not None else None,
            reason=None if latest_speed is not None else "No speed metric has been recorded yet.",
        ),
    )


def hardware_telemetry_for_project(project_root: Path) -> HardwareTelemetry:
    status = active_run_status(project_root)
    telemetry = hardware_telemetry(status.run)
    if status.latest_metrics.get("iterations_per_second") is not None:
        telemetry.iteration_speed = TelemetryField(
            available="available",
            value=status.latest_metrics["iterations_per_second"],
            unit="it/s",
        )
    return telemetry


def _cuda_telemetry(device: str) -> tuple[TelemetryField, TelemetryField, TelemetryField, TelemetryField]:
    try:
        import torch

        index = int(device.split(":", maxsplit=1)[1]) if ":" in device else 0
        if not torch.cuda.is_available() or index >= torch.cuda.device_count():
            unavailable = _unavailable("CUDA/ROCm device is not available to PyTorch.")
            return unavailable, unavailable, unavailable, unavailable
        free_bytes, total_bytes = torch.cuda.mem_get_info(index)
        used_bytes = total_bytes - free_bytes
        memory_used = TelemetryField(available="available", value=round(used_bytes / (1024**3), 2), unit="GB")
        memory_total = TelemetryField(available="available", value=round(total_bytes / (1024**3), 2), unit="GB")
        if getattr(torch.version, "hip", None):
            utilization, temperature = _amd_gpu_utilization_temperature(index)
        else:
            utilization, temperature = _nvidia_gpu_utilization_temperature(index)
        return memory_used, memory_total, utilization, temperature
    except Exception as exc:
        unavailable = _unavailable(f"GPU telemetry query failed: {exc}")
        return unavailable, unavailable, unavailable, unavailable


def _cpu_telemetry() -> tuple[TelemetryField, TelemetryField, TelemetryField, TelemetryField]:
    memory_used = _unavailable("CPU memory telemetry is not available.")
    memory_total = _unavailable("CPU memory telemetry is not available.")
    utilization = _unavailable("CPU utilization telemetry is not available.")
    temperature = _unavailable("CPU temperature telemetry is not available.")
    try:
        import psutil

        memory = psutil.virtual_memory()
        memory_used = TelemetryField(available="available", value=round((memory.total - memory.available) / (1024**3), 2), unit="GB")
        memory_total = TelemetryField(available="available", value=round(memory.total / (1024**3), 2), unit="GB")
        utilization = TelemetryField(available="available", value=round(psutil.cpu_percent(interval=None), 1), unit="%")
        current_temp = _psutil_cpu_temperature(psutil)
        if current_temp is not None:
            temperature = TelemetryField(available="available", value=round(current_temp, 1), unit="C")
    except Exception:
        memory_used, memory_total = _linux_memory_telemetry()
        utilization = _linux_cpu_utilization()

    if not temperature.available:
        sys_temp = _linux_cpu_temperature()
        if sys_temp is not None:
            temperature = TelemetryField(available="available", value=round(sys_temp, 1), unit="C")
    return memory_used, memory_total, utilization, temperature


def _psutil_cpu_temperature(psutil_module: Any) -> float | None:
    try:
        readings = psutil_module.sensors_temperatures(fahrenheit=False)
    except Exception:
        return None
    preferred = ["k10temp", "coretemp", "cpu_thermal", "acpitz"]
    groups = [*(readings.get(key, []) for key in preferred), *(items for key, items in readings.items() if key not in preferred)]
    for items in groups:
        for item in items:
            current = getattr(item, "current", None)
            if isinstance(current, (int, float)) and current > 0:
                return float(current)
    return None


def _linux_memory_telemetry() -> tuple[TelemetryField, TelemetryField]:
    try:
        values: dict[str, int] = {}
        for line in Path("/proc/meminfo").read_text(encoding="utf-8").splitlines():
            key, raw_value = line.split(":", maxsplit=1)
            values[key] = int(raw_value.strip().split()[0]) * 1024
        total = values["MemTotal"]
        available = values.get("MemAvailable", values.get("MemFree", 0))
        return (
            TelemetryField(available="available", value=round((total - available) / (1024**3), 2), unit="GB"),
            TelemetryField(available="available", value=round(total / (1024**3), 2), unit="GB"),
        )
    except Exception:
        unavailable = _unavailable("CPU memory telemetry is not available.")
        return unavailable, unavailable


def _linux_cpu_utilization() -> TelemetryField:
    try:
        load_1m = os.getloadavg()[0]
        cpus = os.cpu_count() or 1
        return TelemetryField(available="available", value=round(min(100.0, max(0.0, load_1m / cpus * 100)), 1), unit="%")
    except Exception:
        return _unavailable("CPU utilization telemetry is not available.")


def _linux_cpu_temperature() -> float | None:
    for path in sorted(Path("/sys/class/thermal").glob("thermal_zone*/temp")):
        try:
            value = float(path.read_text(encoding="utf-8").strip())
        except Exception:
            continue
        if value > 1000:
            value /= 1000
        if 0 < value < 130:
            return value
    return None


def _nvidia_gpu_utilization_temperature(index: int) -> tuple[TelemetryField, TelemetryField]:
    output = _run_monitor_command(
        [
            "nvidia-smi",
            f"--id={index}",
            "--query-gpu=utilization.gpu,temperature.gpu",
            "--format=csv,noheader,nounits",
        ]
    )
    if output is None:
        unavailable = _unavailable("nvidia-smi is not available.")
        return unavailable, unavailable
    parts = [part.strip() for part in output.splitlines()[0].split(",")]
    if len(parts) < 2:
        unavailable = _unavailable("nvidia-smi did not return utilization and temperature.")
        return unavailable, unavailable
    return _percent_field(parts[0], "GPU utilization is unavailable."), _temperature_field(parts[1], "GPU temperature is unavailable.")


def _amd_gpu_utilization_temperature(index: int) -> tuple[TelemetryField, TelemetryField]:
    for command in (
        ["amd-smi", "metric", "-g", str(index), "--json"],
        ["rocm-smi", f"--device={index}", "--showuse", "--showtemp"],
        ["rocm-smi", "--showuse", "--showtemp"],
    ):
        output = _run_monitor_command(command)
        if output is None:
            continue
        utilization = _extract_first_number(output, [r"GPU use[^0-9]*(\d+(?:\.\d+)?)", r"gfx_activity[^0-9]*(\d+(?:\.\d+)?)", r"GPU_UTIL[^0-9]*(\d+(?:\.\d+)?)"])
        temperature = _extract_first_number(output, [r"Temperature[^0-9]*(\d+(?:\.\d+)?)", r"edge_temperature[^0-9]*(\d+(?:\.\d+)?)", r"TEMP[^0-9]*(\d+(?:\.\d+)?)"])
        if utilization is not None or temperature is not None:
            return (
                TelemetryField(available="available", value=round(utilization, 1), unit="%") if utilization is not None else _unavailable("AMD GPU utilization is unavailable."),
                TelemetryField(available="available", value=round(temperature, 1), unit="C") if temperature is not None else _unavailable("AMD GPU temperature is unavailable."),
            )
    unavailable = _unavailable("ROCm/AMD monitoring tools are not available.")
    return unavailable, unavailable


def _run_monitor_command(command: list[str]) -> str | None:
    if shutil.which(command[0]) is None:
        return None
    try:
        return subprocess.run(command, check=False, capture_output=True, text=True, timeout=1.5).stdout.strip()
    except Exception:
        return None


def _extract_first_number(text: str, patterns: list[str]) -> float | None:
    for pattern in patterns:
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if match:
            return float(match.group(1))
    return None


def _percent_field(value: str, reason: str) -> TelemetryField:
    try:
        return TelemetryField(available="available", value=round(float(value), 1), unit="%")
    except ValueError:
        return _unavailable(reason)


def _temperature_field(value: str, reason: str) -> TelemetryField:
    try:
        return TelemetryField(available="available", value=round(float(value), 1), unit="C")
    except ValueError:
        return _unavailable(reason)


def generate_validation_preview(project_root: Path, run: RunObject) -> PreviewResponse:
    preview_dir = _run_dir(project_root, run) / "previews" / "latest"
    preview_dir.mkdir(parents=True, exist_ok=True)
    base_assets = [
        ("lr", (64, 92, 132)),
        ("sr", (84, 164, 118)),
        ("hr", (184, 184, 188)),
    ]
    diff_assets = [("diff_absolute", (180, 82, 82))]
    if run.settings.diff_mode in {"heatmap", "both"}:
        diff_assets.append(("diff_heatmap", (230, 156, 58)))
    assets: list[PreviewAsset] = []
    for kind, color in [*base_assets, *diff_assets]:
        path = preview_dir / f"{kind}.png"
        _write_png(path, width=96, height=64, color=color)
        stored = store_asset_path(project_root, path).stored
        assets.append(
            PreviewAsset(
                kind=kind,
                path=stored,
                url=f"/projects/{run.metadata.get('project_id', '')}/runs/{run.id}/preview-assets/{kind}",
                width=96,
                height=64,
            )
        )
    return PreviewResponse(run_id=run.id, generated_at=utc_now_iso(), diff_mode=run.settings.diff_mode, assets=assets)


def generate_validation_preview_from_tensors(
    project_root: Path,
    run: RunObject,
    *,
    lr,
    sr,
    hr,
) -> PreviewResponse:
    preview_dir = _run_dir(project_root, run) / "previews" / "latest"
    preview_dir.mkdir(parents=True, exist_ok=True)

    tensors = {
        "lr": lr,
        "sr": sr,
        "hr": hr,
        "diff_absolute": (sr - hr).abs(),
    }
    if run.settings.diff_mode in {"heatmap", "both"}:
        tensors["diff_heatmap"] = _heatmap_tensor(tensors["diff_absolute"])

    assets: list[PreviewAsset] = []
    for kind, tensor in tensors.items():
        path = preview_dir / f"{kind}.png"
        width, height = _write_tensor_png(path, tensor)
        stored = store_asset_path(project_root, path).stored
        assets.append(
            PreviewAsset(
                kind=kind,
                path=stored,
                url=f"/projects/{run.metadata.get('project_id', '')}/runs/{run.id}/preview-assets/{kind}",
                width=width,
                height=height,
            )
        )
    return PreviewResponse(run_id=run.id, generated_at=utc_now_iso(), diff_mode=run.settings.diff_mode, assets=assets)


def latest_preview(project_root: Path, run_id: str, preview_index: int = 0) -> PreviewResponse:
    run = get_run(project_root, run_id)
    metadata = run.metadata.get("latest_preview")
    if metadata is not None:
        return PreviewResponse.model_validate(metadata)
    return PreviewResponse(run_id=run.id, generated_at=None, diff_mode=run.settings.diff_mode, assets=[])


def preview_asset_path(project_root: Path, run_id: str, kind: str) -> Path:
    run = get_run(project_root, run_id)
    allowed = {"lr", "sr", "hr", "diff_absolute", "diff_heatmap"}
    if kind not in allowed:
        raise ApiError(404, "preview_asset_not_found", "Preview asset was not found.", details={"kind": kind})
    path = _run_dir(project_root, run) / "previews" / "latest" / f"{kind}.png"
    if not path.exists():
        raise ApiError(404, "preview_asset_not_found", "Preview asset was not found.", details={"kind": kind})
    return path


def _write_tensor_png(path: Path, tensor) -> tuple[int, int]:
    from PIL import Image

    value = tensor.detach().cpu().clamp(0, 1)
    if value.ndim == 4:
        value = value[0]
    if value.shape[0] == 1:
        value = value.repeat(3, 1, 1)
    value = (value * 255).round().byte().permute(1, 2, 0).contiguous()
    height = int(value.shape[0])
    width = int(value.shape[1])
    Image.frombytes("RGB", (width, height), bytes(value.view(-1).tolist())).save(path)
    return width, height


def _heatmap_tensor(diff):
    import torch

    value = diff.detach()
    if value.ndim == 4:
        value = value[0]
    gray = value.mean(dim=0, keepdim=True).clamp(0, 1)
    return torch.cat([gray, (1.0 - (gray - 0.5).abs() * 2).clamp(0, 1), 1.0 - gray], dim=0)


def _read_definitions(project_root: Path, run: RunObject) -> dict[str, MetricDefinition]:
    path = _definition_path(project_root, run)
    if path.exists():
        raw = json.loads(path.read_text(encoding="utf-8"))
        return {key: MetricDefinition.model_validate(value) for key, value in raw.items()}
    return DEFAULT_METRIC_DEFINITIONS


def _select_active_or_recent_run(project: ProjectState) -> RunObject | None:
    active = [
        RunObject.model_validate(raw)
        for raw in project.runs
        if raw.get("state") in ACTIVE_RUN_STATES
    ]
    if active:
        return active[-1]
    if not project.runs:
        return None
    return RunObject.model_validate(project.runs[-1])


def _latest_speed(run: RunObject) -> float | None:
    telemetry = run.metadata.get("telemetry")
    if isinstance(telemetry, dict):
        speed = telemetry.get("iteration_speed")
        if isinstance(speed, dict) and isinstance(speed.get("value"), (int, float)):
            return float(speed["value"])
    return None


def _definition_path(project_root: Path, run: RunObject) -> Path:
    return _run_dir(project_root, run) / "metric_definitions.json"


def _metrics_path(project_root: Path, run: RunObject) -> Path:
    return _run_dir(project_root, run) / "metrics.jsonl"


def _run_dir(project_root: Path, run: RunObject) -> Path:
    folder = Path(run.folder)
    if folder.is_absolute():
        return folder
    return project_root / folder


def _unavailable(reason: str) -> TelemetryField:
    return TelemetryField(available="unavailable", value=None, unit=None, reason=reason)


def _write_png(path: Path, *, width: int, height: int, color: tuple[int, int, int]) -> None:
    raw_rows = []
    for y in range(height):
        shade = 0.82 + 0.18 * math.sin((y / max(1, height - 1)) * math.pi)
        row = bytearray([0])
        for _x in range(width):
            row.extend(max(0, min(255, round(channel * shade))) for channel in color)
        raw_rows.append(bytes(row))
    compressed = zlib.compress(b"".join(raw_rows))
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + _png_chunk(b"IDAT", compressed)
        + _png_chunk(b"IEND", b"")
    )


def _png_chunk(kind: bytes, data: bytes) -> bytes:
    checksum = zlib.crc32(kind + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", checksum)
