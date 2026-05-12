from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path
from typing import Any, Literal

from pydantic import BaseModel, Field

from . import __version__
from .checkpoints import CheckpointMetadata, derive_project_checkpoints
from .config import PROJECT_FILE_NAME
from .datasets import DatasetObject, VideoGenerationConfig, validate_paired_dataset
from .errors import ApiError
from .ids import slugify
from .inference import InferenceRecord, TileConfig, list_inference_history
from .jobs import Job, utc_now_iso
from .metrics import active_run_status, read_metrics
from .models import CreateModelRequest, OptimizerConfig, SchedulerConfig, default_model_config
from .project_store import open_project, project_file, write_project
from .runs import ACTIVE_RUN_STATES, RunObject, RunSetupRequest, available_devices, create_run
from .schemas import ProjectState, WorkspaceState


UnsupportedReason = Literal["unsupported", "unavailable", "missing_prerequisite"]
Severity = Literal["info", "success", "warning", "error"]


class UnsupportedState(BaseModel):
    supported: bool = False
    reason: UnsupportedReason = "unsupported"
    code: str
    message: str
    action_label: str | None = None


class ActionState(BaseModel):
    id: str
    label: str
    supported: bool
    reason: str | None = None


class RecentProjectSummary(BaseModel):
    dataset_count: int = 0
    model_count: int = 0
    run_count: int = 0
    checkpoint_count: int = 0


class RecentProject(BaseModel):
    name: str
    path: str
    last_opened_at: str | None = None
    status: Literal["available", "missing", "invalid"] = "available"
    status_message: str = "Project is available."
    summary: RecentProjectSummary = Field(default_factory=RecentProjectSummary)


class RecentProjectsResponse(BaseModel):
    projects: list[RecentProject]


class ActivityEvent(BaseModel):
    id: str
    timestamp: str
    category: Literal["dataset", "model", "run", "checkpoint", "inference", "project"]
    severity: Severity = "info"
    description: str
    object_id: str | None = None


class ActivityFeedResponse(BaseModel):
    events: list[ActivityEvent]


class StatusBarData(BaseModel):
    app_version: str
    project_path: str
    vcs_branch: str | None = None
    vcs_available: bool = False
    backend_state: Literal["ok", "error"] = "ok"
    disk_free_bytes: int | None = None
    disk_warning: bool = False
    busy_state: Literal["idle", "busy"] = "idle"


class NextStepGuidance(BaseModel):
    state: str
    title: str
    description: str
    action_label: str
    target_tab: int
    severity: Severity = "info"


class DashboardSummary(BaseModel):
    dataset_count: int
    model_count: int
    run_count: int
    dataset_pair_total: int
    active_model: str | None = None
    best_psnr: float | None = None
    active_run_state: str | None = None
    backend_status: Literal["ok", "error"] = "ok"
    device_badge: str
    app_version: str
    project_path: str
    disk_free_bytes: int | None = None
    disk_warning: bool = False
    busy_state: Literal["idle", "busy"] = "idle"
    vcs_branch: str | None = None
    status_bar: StatusBarData
    next_step: NextStepGuidance


class WorkspacePreferencesResponse(BaseModel):
    selected_tab: int = 0
    theme: Literal["system", "light", "dark"] = "system"
    density: Literal["comfortable", "compact"] = "comfortable"
    per_project_ui_state: dict[str, Any] = Field(default_factory=dict)


class DatasetSourceRow(BaseModel):
    id: str
    source_type: str
    name: str
    pair_count: int
    status: str
    severity: Severity
    note: str | None = None
    actions: list[ActionState] = Field(default_factory=list)


class HealthCheckRow(BaseModel):
    id: str
    label: str
    severity: Severity
    message: str


class DatasetPreviewPair(BaseModel):
    index: int
    total: int
    lr_path: str | None = None
    hr_path: str | None = None
    unavailable: UnsupportedState | None = None


class HistogramSummary(BaseModel):
    available: bool
    channels: list[str] = Field(default_factory=list)
    selected_channel: str | None = None
    bins: list[int] = Field(default_factory=list)
    unavailable: UnsupportedState | None = None


class DatasetDetailResponse(BaseModel):
    dataset: DatasetObject
    sources: list[DatasetSourceRow]
    health_checks: list[HealthCheckRow]
    degradation_pipeline: list[str] = Field(default_factory=list)
    preview: DatasetPreviewPair
    histogram: HistogramSummary
    rescan_action: ActionState
    export_action: ActionState
    resynthesis: UnsupportedState | None = None


class VideoWizardMetadata(BaseModel):
    source_path: str
    exists: bool
    sampling_strategy: str
    estimated_yield: int | None = None
    output_size_bytes: int | None = None
    deduplication_guidance: str
    readiness: UnsupportedState | None = None


class ModelTemplate(BaseModel):
    id: str
    display_name: str
    architecture_summary: str
    best_for: str
    speed_label: str
    supported_scales: list[int]
    parameter_count: int | None = None
    vram_estimate: str
    input_crop: int
    support_state: Literal["supported", "unsupported"] = "unsupported"
    unavailable: UnsupportedState | None = None
    architecture_steps: list[str] = Field(default_factory=list)
    hyperparameters: dict[str, Any] = Field(default_factory=dict)
    defaults: dict[str, Any] = Field(default_factory=dict)
    import_action: ActionState
    reset_action: ActionState
    save_as_model_action: ActionState


class ModelTemplateCatalogResponse(BaseModel):
    templates: list[ModelTemplate]
    filters: dict[str, list[str]] = Field(default_factory=dict)


class TrainingEstimateResponse(BaseModel):
    available: bool
    estimated_time_seconds: int | None = None
    iterations_per_epoch: int | None = None
    vram_peak_bytes: int | None = None
    disk_per_checkpoint_bytes: int | None = None
    low_pair_guard: UnsupportedState | None = None
    unsupported_losses: list[UnsupportedState] = Field(default_factory=list)
    suggested_fixes: list[ActionState] = Field(default_factory=list)
    retention: dict[str, Any] = Field(default_factory=dict)
    ema: UnsupportedState | None = None


class LiveRunDetailResponse(BaseModel):
    active: bool
    run: RunObject | None = None
    epoch_progress: float = 0.0
    run_progress: float = 0.0
    eta_seconds: int | None = None
    recent_events: list[ActivityEvent] = Field(default_factory=list)
    log_tail: list[str] = Field(default_factory=list)
    open_log: ActionState
    validation_samples: list[dict[str, Any]] = Field(default_factory=list)
    crash_snapshot: UnsupportedState | None = None
    oom_error: dict[str, Any] | None = None


class SnapshotResponse(BaseModel):
    checkpoint: CheckpointMetadata | None = None
    unavailable: UnsupportedState | None = None


class CheckpointAggregateResponse(BaseModel):
    checkpoints: list[CheckpointMetadata]
    best_checkpoint: CheckpointMetadata | None = None
    psnr_delta: float | None = None
    actions: dict[str, ActionState]


class InferenceInspectorResponse(BaseModel):
    blocked_checklist: list[ActionState]
    inspector: dict[str, Any] = Field(default_factory=dict)
    recent: list[InferenceRecord] = Field(default_factory=list)
    add_tile_action: ActionState
    batch_drop_zone: ActionState
    tuning: dict[str, UnsupportedState] = Field(default_factory=dict)
    compare_view: dict[str, Any] = Field(default_factory=dict)


BACKEND_VIEW_MODEL_CONTRACTS: dict[str, dict[str, str]] = {
    "recent_projects": {"method": "GET", "path": "/projects/recent", "response": "RecentProjectsResponse"},
    "open_recent_project": {"method": "POST", "path": "/projects/recent/open", "request": "OpenProjectRequest", "response": "ProjectResponse"},
    "workspace_preferences": {"method": "GET/PUT", "path": "/projects/{project_id}/workspace", "response": "ProjectResponse"},
    "dashboard_summary": {"method": "GET", "path": "/projects/{project_id}/dashboard", "response": "DashboardSummary"},
    "activity_feed": {"method": "GET", "path": "/projects/{project_id}/activity", "response": "ActivityFeedResponse"},
    "dataset_detail": {"method": "GET", "path": "/projects/{project_id}/datasets/{dataset_id}/detail", "response": "DatasetDetailResponse"},
    "video_wizard": {"method": "POST", "path": "/projects/{project_id}/datasets/video/metadata", "response": "VideoWizardMetadata"},
    "dataset_resynthesis": {"method": "POST", "path": "/projects/{project_id}/datasets/{dataset_id}/resynthesize", "response": "UnsupportedState"},
    "model_templates": {"method": "GET", "path": "/projects/{project_id}/model-templates", "response": "ModelTemplateCatalogResponse"},
    "training_estimate": {"method": "POST", "path": "/projects/{project_id}/training/estimate", "response": "TrainingEstimateResponse"},
    "run_settings_patch": {"method": "PATCH", "path": "/projects/{project_id}/runs/{run_id}/settings", "response": "ProjectResponse"},
    "live_detail": {"method": "GET", "path": "/projects/{project_id}/live/detail", "response": "LiveRunDetailResponse"},
    "snapshot_checkpoint": {"method": "POST", "path": "/projects/{project_id}/runs/{run_id}/snapshot", "response": "SnapshotResponse"},
    "checkpoint_aggregate": {"method": "GET", "path": "/projects/{project_id}/checkpoints/aggregate", "response": "CheckpointAggregateResponse"},
    "inference_inspector": {"method": "GET", "path": "/projects/{project_id}/inference/inspector", "response": "InferenceInspectorResponse"},
}


def remember_recent_project(project: ProjectState) -> None:
    if project.root_path is None:
        return
    records = _read_recent_records()
    root = str(Path(project.root_path).expanduser().resolve())
    records = [item for item in records if item.get("path") != root]
    records.insert(0, {"path": root, "last_opened_at": project.workspace.last_opened_at or utc_now_iso()})
    _write_recent_records(records[:20])


def list_recent_projects() -> RecentProjectsResponse:
    return RecentProjectsResponse(projects=[_recent_from_record(item) for item in _read_recent_records()])


def forget_recent_project(path: str) -> RecentProjectsResponse:
    root = str(Path(path).expanduser().resolve())
    records = [item for item in _read_recent_records() if item.get("path") != root]
    _write_recent_records(records)
    return list_recent_projects()


def workspace_preferences(project_root: Path) -> WorkspacePreferencesResponse:
    workspace = open_project(project_root).workspace
    return WorkspacePreferencesResponse(**workspace.model_dump())


def update_workspace(project_root: Path, **updates: Any) -> ProjectState:
    project = open_project(project_root)
    if updates.get("selected_tab") is not None:
        project.workspace.selected_tab = updates["selected_tab"]
    if updates.get("theme") is not None:
        project.workspace.theme = updates["theme"]
    if updates.get("density") is not None:
        project.workspace.density = updates["density"]
    if updates.get("per_project_ui_state") is not None:
        project.workspace.per_project_ui_state = updates["per_project_ui_state"]
    return write_project(project)


def dashboard_summary(project_root: Path) -> DashboardSummary:
    project = open_project(project_root)
    checkpoints = derive_project_checkpoints(project_root).checkpoints
    active = active_run_status(project_root)
    disk = shutil.disk_usage(project_root) if project_root.exists() else None
    disk_warning = disk.free < 1_000_000_000 if disk is not None else False
    devices = available_devices().devices
    device_label = next((d.label for d in devices if d.id == (active.run.settings.device if active.run else "cpu")), "CPU")
    best_psnr = max((c.metrics.get("val_psnr", 0.0) for c in checkpoints if not c.deleted and c.metrics.get("val_psnr")), default=None)
    status = StatusBarData(
        app_version=__version__,
        project_path=str(project_root),
        vcs_branch=_vcs_branch(project_root),
        vcs_available=_vcs_branch(project_root) is not None,
        disk_free_bytes=disk.free if disk is not None else None,
        disk_warning=disk_warning,
        busy_state="busy" if active.run and active.run.state in ACTIVE_RUN_STATES else "idle",
    )
    return DashboardSummary(
        dataset_count=len(project.datasets),
        model_count=len(project.models),
        run_count=len(project.runs),
        dataset_pair_total=sum((raw.get("validation") or {}).get("pair_count", 0) for raw in project.datasets),
        active_model=_active_model_name(project, active.run),
        best_psnr=best_psnr,
        active_run_state=active.run.state if active.run else None,
        device_badge=device_label,
        app_version=__version__,
        project_path=str(project_root),
        disk_free_bytes=status.disk_free_bytes,
        disk_warning=disk_warning,
        busy_state=status.busy_state,
        vcs_branch=status.vcs_branch,
        status_bar=status,
        next_step=derive_next_step(project, checkpoints, active.run),
    )


def activity_feed(project_root: Path, limit: int = 20) -> ActivityFeedResponse:
    project = open_project(project_root)
    events = list(project.metadata.get("activity_feed", []))
    events.extend(_derived_activity(project))
    events.sort(key=lambda item: item.get("timestamp", ""), reverse=True)
    return ActivityFeedResponse(events=[ActivityEvent.model_validate(item) for item in events[:limit]])


def record_activity(project: ProjectState, category: str, description: str, *, severity: Severity = "info", object_id: str | None = None) -> ProjectState:
    events = list(project.metadata.get("activity_feed", []))
    events.insert(
        0,
        ActivityEvent(
            id=f"activity_{len(events) + 1}",
            timestamp=utc_now_iso(),
            category=category,  # type: ignore[arg-type]
            severity=severity,
            description=description,
            object_id=object_id,
        ).model_dump(),
    )
    project.metadata["activity_feed"] = events[:100]
    return project


def dataset_detail(project_root: Path, dataset_id: str, preview_index: int = 0) -> DatasetDetailResponse:
    project = open_project(project_root)
    dataset = _find_dataset(project, dataset_id)
    source_name = Path(dataset.metadata.get("source_path") or dataset.paths.root).name
    source = DatasetSourceRow(
        id=f"{dataset.id}_source",
        source_type=dataset.type,
        name=source_name,
        pair_count=dataset.validation.pair_count,
        status="Ready" if dataset.validation.usable else "Needs attention",
        severity="success" if dataset.validation.usable else "error",
        note=dataset.metadata.get("source_path"),
        actions=[
            ActionState(id="inspect", label="Inspect", supported=True),
            ActionState(id="relink", label="Relink", supported=False, reason="Source relinking is not implemented yet."),
            ActionState(id="remove", label="Remove", supported=False, reason="Source removal is not implemented yet."),
        ],
    )
    health = _dataset_health_checks(dataset)
    return DatasetDetailResponse(
        dataset=dataset,
        sources=[source],
        health_checks=health,
        degradation_pipeline=_degradation_pipeline(dataset),
        preview=_dataset_preview(project_root, dataset, preview_index),
        histogram=HistogramSummary(
            available=False,
            unavailable=_unsupported("histogram_unavailable", "Channel histograms are not available until full scan metadata is recorded.", reason="unavailable"),
        ),
        rescan_action=ActionState(id="rescan", label="Re-scan", supported=True),
        export_action=ActionState(id="export", label="Export", supported=False, reason="Dataset export is not implemented yet."),
        resynthesis=_unsupported("resynthesis_unavailable", "Re-synthesis creates a new dataset version, but this backend path is not implemented yet."),
    )


def video_wizard_metadata(request: VideoGenerationConfig) -> VideoWizardMetadata:
    source = Path(request.source_video).expanduser()
    exists = source.is_file()
    estimated = request.frame_limit
    output_size = None
    if exists and request.fps > 0:
        metadata = _ffprobe_video_metadata(source)
        duration = metadata.get("duration")
        if estimated is None and duration is not None:
            estimated = max(1, int(duration * request.fps))
        width = metadata.get("width")
        height = metadata.get("height")
        if estimated is not None and width is not None and height is not None:
            lr_pixels = max(1, (width // request.scale) * (height // request.scale))
            hr_pixels = width * height
            output_size = int(estimated * (hr_pixels + lr_pixels) * 0.35)
    return VideoWizardMetadata(
        source_path=str(source),
        exists=exists,
        sampling_strategy=f"{request.fps:g} fps, x{request.scale}, {request.downscale_method}",
        estimated_yield=estimated,
        output_size_bytes=output_size,
        deduplication_guidance="Duplicate pruning is not automatic yet; review extracted frames before long training runs.",
        readiness=None if exists else _unsupported("video_missing", "Select an existing source video.", reason="missing_prerequisite"),
    )


def _ffprobe_video_metadata(source: Path) -> dict[str, float | int]:
    completed = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height:format=duration",
            "-of",
            "json",
            str(source),
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        return {}
    try:
        raw = json.loads(completed.stdout)
    except Exception:
        return {}
    stream = (raw.get("streams") or [{}])[0]
    fmt = raw.get("format") or {}
    result: dict[str, float | int] = {}
    for key in ("width", "height"):
        value = stream.get(key)
        if isinstance(value, int):
            result[key] = value
    try:
        result["duration"] = float(fmt.get("duration"))
    except Exception:
        pass
    return result


def model_template_catalog() -> ModelTemplateCatalogResponse:
    defaults = default_model_config()
    internal = ModelTemplate(
        id="internal-residual-pixelshuffle",
        display_name="Internal Residual PixelShuffle",
        architecture_summary="Small residual SR network with PixelShuffle upsampling.",
        best_for="Local CPU/GPU smoke tests and starter projects",
        speed_label="Fast",
        supported_scales=defaults["supported_scales"],
        parameter_count=None,
        vram_estimate="Low",
        input_crop=64,
        support_state="supported",
        architecture_steps=["RGB input", "Residual trunk", "PixelShuffle upsampler", "RGB output"],
        hyperparameters={"num_features": 32, "num_blocks": 4, "lr": 0.0002},
        defaults=defaults,
        import_action=ActionState(id="import", label="Import template", supported=True),
        reset_action=ActionState(id="reset", label="Reset to defaults", supported=True),
        save_as_model_action=ActionState(id="save_as_model", label="Save as model", supported=True),
    )
    return ModelTemplateCatalogResponse(templates=[internal], filters={"support": ["supported"], "scale": ["2", "3", "4", "8"]})


def save_template_as_model(project_root: Path, template_id: str, name: str, scale: int) -> ProjectState:
    if template_id != "internal-residual-pixelshuffle":
        raise ApiError(409, "template_unsupported", "This model template is not supported by the backend yet.", details={"template_id": template_id})
    from .models import create_model

    project, _model = create_model(project_root, CreateModelRequest(name=name, scale=scale))
    return project


def training_estimate(project_root: Path, request: RunSetupRequest) -> TrainingEstimateResponse:
    project = open_project(project_root)
    dataset = _find_dataset(project, request.dataset_id)
    pair_count = dataset.validation.pair_count
    iterations = max(1, len(range(pair_count)))
    low_pair = None
    if pair_count < 100:
        low_pair = _unsupported("low_pair_count", "Fewer than 100 usable pairs may not generalize; add data or explicitly confirm training.", reason="missing_prerequisite")
    return TrainingEstimateResponse(
        available=dataset.validation.usable,
        estimated_time_seconds=iterations * request.epochs,
        iterations_per_epoch=iterations,
        vram_peak_bytes=None,
        disk_per_checkpoint_bytes=25_000_000,
        low_pair_guard=low_pair,
        unsupported_losses=[],
        suggested_fixes=[
            ActionState(id="lower_batch_size", label="Lower batch size", supported=True),
            ActionState(id="mixed_precision", label="Use mixed precision", supported=True),
        ],
        retention={"checkpoint_cadence": request.checkpoint_cadence, "keep_best_metric": "val_psnr", "max_automatic": None},
        ema=None,
    )


def live_detail(project_root: Path) -> LiveRunDetailResponse:
    status = active_run_status(project_root)
    run = status.run
    if run is None:
        return LiveRunDetailResponse(active=False, open_log=ActionState(id="open_log", label="Open log", supported=False, reason="No run is selected."))
    metrics = read_metrics(project_root, run.id, limit=20)
    latest = metrics.records[-1] if metrics.records else None
    epoch_progress = 0.0
    if latest and run.validation_indexes is not None:
        epoch_progress = 0.0 if latest.iteration == 0 else min(1.0, latest.iteration / max(latest.iteration, 1))
    log_tail = _read_log_tail(project_root, run)
    oom = _oom_error(run)
    return LiveRunDetailResponse(
        active=run.state in ACTIVE_RUN_STATES,
        run=run,
        epoch_progress=epoch_progress,
        run_progress=status.progress,
        eta_seconds=None,
        recent_events=activity_feed(project_root, limit=5).events,
        log_tail=log_tail,
        open_log=ActionState(id="open_log", label="Open log", supported=run.log_dir is not None, reason=None if run.log_dir else "No log directory has been recorded."),
        validation_samples=[run.metadata.get("latest_preview", {})] if run.metadata.get("latest_preview") else [],
        crash_snapshot=_unsupported("crash_snapshot_unavailable", "No protected crash snapshot has been recorded.", reason="unavailable"),
        oom_error=oom,
    )


def snapshot_checkpoint(_project_root: Path, _run_id: str) -> SnapshotResponse:
    return SnapshotResponse(unavailable=_unsupported("snapshot_unavailable", "Manual snapshot checkpoints require an active training worker and are not available yet.", reason="unavailable"))


def checkpoint_aggregate(project_root: Path) -> CheckpointAggregateResponse:
    checkpoints = derive_project_checkpoints(project_root).checkpoints
    active = [c for c in checkpoints if not c.deleted]
    best = max([c for c in active if c.metrics.get("val_psnr") is not None], key=lambda c: c.metrics.get("val_psnr", 0), default=None)
    psnrs = [c.metrics["val_psnr"] for c in active if c.metrics.get("val_psnr") is not None]
    delta = max(psnrs) - psnrs[0] if len(psnrs) >= 2 else None
    return CheckpointAggregateResponse(
        checkpoints=checkpoints,
        best_checkpoint=best,
        psnr_delta=delta,
        actions={
            "compare": ActionState(id="compare", label="Compare side by side", supported=False, reason="Checkpoint comparison is not implemented yet."),
            "prune": ActionState(id="prune", label="Prune automatic checkpoints", supported=False, reason="Automatic pruning is not implemented yet."),
            "continue_from_best": ActionState(id="continue_from_best", label="Continue from best", supported=best is not None, reason=None if best else "No usable checkpoint exists."),
        },
    )


def inference_inspector(project_root: Path) -> InferenceInspectorResponse:
    project = open_project(project_root)
    records = list_inference_history(project_root).records
    has_dataset = any((raw.get("validation") or {}).get("usable") for raw in project.datasets)
    has_model = bool(project.models)
    checkpoints = [c for c in derive_project_checkpoints(project_root).checkpoints if not c.deleted]
    checklist = [
        ActionState(id="dataset", label="Dataset", supported=has_dataset, reason=None if has_dataset else "Create or import a usable dataset."),
        ActionState(id="model", label="Model", supported=has_model, reason=None if has_model else "Create a compatible model."),
        ActionState(id="checkpoint", label="Saved checkpoint", supported=bool(checkpoints), reason=None if checkpoints else "Train until a checkpoint is saved."),
    ]
    selected = records[-1] if records else None
    inspector = {}
    if selected is not None:
        inspector = {
            "resolution": None,
            "format": Path(selected.output_path or "").suffix.lstrip("."),
            "filename": Path(selected.output_path or selected.input_path).name,
            "bit_depth": None,
            "runtime_seconds": selected.runtime_seconds,
            "psnr_estimate": selected.metrics.get("psnr"),
            "sharpness_gain": selected.metrics.get("sharpness_gain"),
            "tuning": selected.tile_config.model_dump(),
        }
    return InferenceInspectorResponse(
        blocked_checklist=checklist,
        inspector=inspector,
        recent=records[-10:],
        add_tile_action=ActionState(id="add_tile", label="Add tile", supported=bool(checkpoints), reason=None if checkpoints else "A checkpoint is required."),
        batch_drop_zone=ActionState(id="batch_drop_zone", label="Batch folder", supported=bool(checkpoints), reason=None if checkpoints else "A checkpoint is required."),
        tuning={
            "denoise_strength": _unsupported("tuning_unsupported", "Denoise tuning is not supported by this checkpoint.", reason="unavailable"),
            "detail_boost": _unsupported("tuning_unsupported", "Detail boost is not supported by this checkpoint.", reason="unavailable"),
            "color_preserve": _unsupported("tuning_unsupported", "Color preserve tuning is not supported by this checkpoint.", reason="unavailable"),
        },
        compare_view={"mode": "slider", "width": None, "height": None},
    )


def _read_recent_records() -> list[dict[str, Any]]:
    path = _recent_projects_path()
    if not path.exists():
        return []
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return []
    return raw if isinstance(raw, list) else []


def _write_recent_records(records: list[dict[str, Any]]) -> None:
    path = _recent_projects_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(records, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _recent_projects_path() -> Path:
    override = os.environ.get("SR_TUNER_RECENT_PROJECTS_FILE")
    if override:
        return Path(override).expanduser()
    return Path.home() / ".local" / "share" / "sr-tuner" / "recent-projects.json"


def _recent_from_record(record: dict[str, Any]) -> RecentProject:
    root = Path(str(record.get("path", ""))).expanduser()
    status: Literal["available", "missing", "invalid"] = "available"
    message = "Project is available."
    summary = RecentProjectSummary()
    name = root.name
    if not root.exists() or not project_file(root).exists():
        status = "missing"
        message = "Project folder or sr-tuner.project.json is missing."
    else:
        try:
            project = open_project(root)
            name = project.name
            checkpoints = derive_project_checkpoints(root).checkpoints
            summary = RecentProjectSummary(
                dataset_count=len(project.datasets),
                model_count=len(project.models),
                run_count=len(project.runs),
                checkpoint_count=len(checkpoints),
            )
        except Exception:
            status = "invalid"
            message = "Project manifest could not be read."
    return RecentProject(name=name, path=str(root), last_opened_at=record.get("last_opened_at"), status=status, status_message=message, summary=summary)


def _unsupported(code: str, message: str, *, reason: UnsupportedReason = "unsupported") -> UnsupportedState:
    return UnsupportedState(code=code, message=message, reason=reason)


def _find_dataset(project: ProjectState, dataset_id: str) -> DatasetObject:
    for raw in project.datasets:
        if raw.get("id") == dataset_id:
            return DatasetObject.model_validate(raw)
    raise ApiError(404, "dataset_not_found", "Dataset was not found.", details={"dataset_id": dataset_id})


def _dataset_health_checks(dataset: DatasetObject) -> list[HealthCheckRow]:
    checks = [
        HealthCheckRow(id="pairs", label="Matched pairs", severity="success" if dataset.validation.pair_count else "error", message=f"{dataset.validation.pair_count} matched pairs."),
        HealthCheckRow(id="scale", label="Scale alignment", severity="success" if dataset.validation.validated_scale else "warning", message=f"Declared x{dataset.declared_scale}."),
    ]
    checks.extend(HealthCheckRow(id=f"error_{index}", label="Validation error", severity="error", message=message) for index, message in enumerate(dataset.validation.errors))
    checks.extend(HealthCheckRow(id=f"warning_{index}", label="Validation warning", severity="warning", message=message) for index, message in enumerate(dataset.validation.warnings))
    return checks


def _dataset_preview(project_root: Path, dataset: DatasetObject, index: int) -> DatasetPreviewPair:
    total = dataset.validation.pair_count
    if total <= 0:
        return DatasetPreviewPair(index=0, total=0, unavailable=_unsupported("preview_unavailable", "No matched LR/HR pairs are available.", reason="missing_prerequisite"))
    root = Path(dataset.paths.root)
    if dataset.paths.mode == "relative":
        root = project_root / root
    lr_files = sorted((root / "LR").glob("*"))
    hr_files = sorted((root / "HR").glob("*"))
    bounded = max(0, min(index, min(len(lr_files), len(hr_files)) - 1))
    if not lr_files or not hr_files:
        return DatasetPreviewPair(index=0, total=total, unavailable=_unsupported("preview_unavailable", "Preview files are not available.", reason="unavailable"))
    return DatasetPreviewPair(index=bounded, total=total, lr_path=str(lr_files[bounded]), hr_path=str(hr_files[bounded]))


def _degradation_pipeline(dataset: DatasetObject) -> list[str]:
    generation = dataset.generation or {}
    if not generation:
        return []
    return [
        f"Downscale: x{dataset.scale} {generation.get('downscale_method', 'bicubic')}",
        f"Blur: {generation.get('blur', 0)}",
        f"Noise: {generation.get('noise', 0)}",
        f"JPEG quality: {generation.get('jpeg_quality', 95)}",
    ]


def _active_model_name(project: ProjectState, run: RunObject | None) -> str | None:
    if run is not None:
        model_id = run.model_id
    elif project.models:
        model_id = project.models[-1].get("id")
    else:
        return None
    model = next((raw for raw in project.models if raw.get("id") == model_id), None)
    return model.get("name") if model else None


def derive_next_step(project: ProjectState, checkpoints: list[CheckpointMetadata], active_run: RunObject | None) -> NextStepGuidance:
    if not any((raw.get("validation") or {}).get("usable") for raw in project.datasets):
        return NextStepGuidance(state="missing_dataset", title="Create a dataset", description="Add LR/HR pairs or extract frames from a video.", action_label="Open Dataset", target_tab=1)
    if not project.models:
        return NextStepGuidance(state="missing_model", title="Choose a model", description="Create a compatible model before training.", action_label="Open Model", target_tab=2)
    if active_run and active_run.state in ACTIVE_RUN_STATES:
        return NextStepGuidance(state="active_training", title="Watch live training", description="A training run is active.", action_label="Open Live", target_tab=4, severity="success")
    if checkpoints:
        return NextStepGuidance(state="inference_ready", title="Run inference", description="A checkpoint is available for image upscaling.", action_label="Open Inference", target_tab=6, severity="success")
    if project.runs:
        return NextStepGuidance(state="checkpoint_ready", title="Continue training", description="Resume or start a run to produce checkpoints.", action_label="Open Training", target_tab=3)
    return NextStepGuidance(state="ready_to_train", title="Start training", description="Dataset and model prerequisites are ready.", action_label="Open Training", target_tab=3)


def _derived_activity(project: ProjectState) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    for raw in project.datasets:
        events.append(ActivityEvent(id=f"dataset_{raw.get('id')}", timestamp=raw.get("updated_at") or raw.get("created_at") or project.updated_at, category="dataset", severity="success" if (raw.get("validation") or {}).get("usable") else "warning", description=f"Dataset {raw.get('name', 'dataset')} registered.", object_id=raw.get("id")).model_dump())
    for raw in project.models:
        events.append(ActivityEvent(id=f"model_{raw.get('id')}", timestamp=raw.get("updated_at") or raw.get("created_at") or project.updated_at, category="model", description=f"Model {raw.get('name', 'model')} configured.", object_id=raw.get("id")).model_dump())
    for raw in project.runs:
        events.append(ActivityEvent(id=f"run_{raw.get('id')}", timestamp=raw.get("updated_at") or raw.get("created_at") or project.updated_at, category="run", severity="error" if raw.get("state") == "failed" else "info", description=f"Run {raw.get('name', 'run')} is {raw.get('state', 'configured')}.", object_id=raw.get("id")).model_dump())
        for checkpoint in raw.get("checkpoints", []):
            events.append(ActivityEvent(id=f"checkpoint_{checkpoint.get('id')}", timestamp=checkpoint.get("saved_at") or project.updated_at, category="checkpoint", severity="success", description=f"Checkpoint saved at epoch {checkpoint.get('epoch', 0)}.", object_id=checkpoint.get("id")).model_dump())
    for raw in project.inference_history:
        events.append(ActivityEvent(id=f"inference_{raw.get('id')}", timestamp=raw.get("created_at") or project.updated_at, category="inference", severity="success" if raw.get("status") == "completed" else "warning", description=f"Inference {raw.get('status', 'completed')}.", object_id=raw.get("id")).model_dump())
    return events


def _vcs_branch(project_root: Path) -> str | None:
    try:
        completed = subprocess.run(["git", "-C", str(project_root), "branch", "--show-current"], check=False, capture_output=True, text=True, timeout=1)
    except Exception:
        return None
    branch = completed.stdout.strip()
    return branch or None


def _read_log_tail(project_root: Path, run: RunObject) -> list[str]:
    if run.log_dir is None:
        return []
    path = Path(run.log_dir)
    if not path.is_absolute():
        path = project_root / path
    if path.is_file():
        return path.read_text(encoding="utf-8", errors="replace").splitlines()[-50:]
    return []


def _oom_error(run: RunObject) -> dict[str, Any] | None:
    error = run.error or {}
    text = f"{error.get('code', '')} {error.get('message', '')}".lower()
    if "out of memory" not in text and "oom" not in text:
        return None
    return {
        "summary": error.get("message", "CUDA out of memory."),
        "suggested_fixes": [
            {"id": "lower_batch_size", "label": "Lower batch size"},
            {"id": "lower_crop_size", "label": "Lower crop size"},
            {"id": "mixed_precision", "label": "Use mixed precision"},
        ],
    }
