from __future__ import annotations

import json
import math
import struct
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


def initialize_run_metrics(project_root: Path, run: RunObject) -> RunObject:
    run_dir = _run_dir(project_root, run)
    run_dir.mkdir(parents=True, exist_ok=True)
    definitions_path = run_dir / "metric_definitions.json"
    definitions = {key: value.model_dump() for key, value in DEFAULT_METRIC_DEFINITIONS.items()}
    definitions_path.write_text(json.dumps(definitions, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    run.metadata["metric_definitions_path"] = store_asset_path(project_root, definitions_path).stored
    run.metadata["metrics_path"] = store_asset_path(project_root, _metrics_path(project_root, run)).stored
    write_metric_record(
        project_root,
        run,
        MetricRecord(
            step=0,
            epoch=0,
            iteration=0,
            values={
                "train_loss_total": 0.0,
                "val_psnr": 0.0,
                "val_ssim": 0.0,
                "learning_rate": 0.0,
                "progress": 0.0,
                "iterations_per_second": 0.0,
            },
            components={"l1": 0.0},
        ),
    )
    preview = generate_validation_preview(project_root, run)
    run.metadata["latest_preview"] = preview.model_dump()
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
    return ActiveRunStatus(
        run=run,
        model=next((item for item in project.models if item.get("id") == run.model_id), None),
        dataset=next((item for item in project.datasets if item.get("id") == run.dataset_id), None),
        epoch=latest.epoch if latest else 0,
        iteration=latest.iteration if latest else 0,
        progress=latest.values.get("progress", 0.0) if latest else 0.0,
        latest_metrics=latest.values if latest else {},
    )


def hardware_telemetry(run: RunObject | None = None) -> HardwareTelemetry:
    device = run.settings.device if run is not None else "cpu"
    device_type = device.split(":", maxsplit=1)[0]
    latest_speed = _latest_speed(run) if run is not None else None
    return HardwareTelemetry(
        device=device,
        device_type=device_type,
        memory_used=_unavailable("Runtime memory telemetry is not available for this device."),
        memory_total=_unavailable("Runtime memory telemetry is not available for this device."),
        utilization=_unavailable("Utilization telemetry is not available for this device."),
        temperature=_unavailable("Temperature telemetry is not available for this device."),
        iteration_speed=TelemetryField(
            available="available" if latest_speed is not None else "unavailable",
            value=latest_speed,
            unit="it/s" if latest_speed is not None else None,
            reason=None if latest_speed is not None else "No speed metric has been recorded yet.",
        ),
    )


def hardware_telemetry_for_project(project_root: Path) -> HardwareTelemetry:
    status = active_run_status(project_root)
    return hardware_telemetry(status.run)


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


def latest_preview(project_root: Path, run_id: str) -> PreviewResponse:
    run = get_run(project_root, run_id)
    metadata = run.metadata.get("latest_preview")
    if metadata is not None:
        return PreviewResponse.model_validate(metadata)
    return generate_validation_preview(project_root, run)


def preview_asset_path(project_root: Path, run_id: str, kind: str) -> Path:
    run = get_run(project_root, run_id)
    allowed = {"lr", "sr", "hr", "diff_absolute", "diff_heatmap"}
    if kind not in allowed:
        raise ApiError(404, "preview_asset_not_found", "Preview asset was not found.", details={"kind": kind})
    path = _run_dir(project_root, run) / "previews" / "latest" / f"{kind}.png"
    if not path.exists():
        generate_validation_preview(project_root, run)
    if not path.exists():
        raise ApiError(404, "preview_asset_not_found", "Preview asset was not found.", details={"kind": kind})
    return path


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
