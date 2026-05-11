from __future__ import annotations

from pathlib import Path

from fastapi import Depends, FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.responses import FileResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from . import __version__
from .inference import (
    InferenceHistoryResponse,
    InferenceReadinessResponse,
    InferenceRecord,
    InferenceRequest,
    inference_readiness,
    list_inference_history,
    run_inference,
)
from .checkpoints import (
    CheckpointListResponse,
    CheckpointMetadata,
    ExportOnnxRequest,
    ExportPthRequest,
    OnnxReadinessResponse,
    ProjectCheckpointIndex,
    delete_checkpoint,
    derive_project_checkpoints,
    export_checkpoint_onnx,
    export_checkpoint_pth,
    list_run_checkpoints,
    onnx_readiness,
)
from .classic_workspace import (
    ActivityFeedResponse,
    CheckpointAggregateResponse,
    DashboardSummary,
    DatasetDetailResponse,
    InferenceInspectorResponse,
    LiveRunDetailResponse,
    ModelTemplateCatalogResponse,
    RecentProjectsResponse,
    SnapshotResponse,
    TrainingEstimateResponse,
    UnsupportedState,
    VideoWizardMetadata,
    WorkspacePreferencesResponse,
    activity_feed,
    checkpoint_aggregate,
    dashboard_summary,
    dataset_detail,
    inference_inspector,
    list_recent_projects,
    live_detail,
    model_template_catalog,
    record_activity,
    remember_recent_project,
    save_template_as_model,
    snapshot_checkpoint,
    training_estimate,
    update_workspace,
    video_wizard_metadata,
    workspace_preferences,
)
from .config import APP_NAME
from .datasets import (
    DatasetObject,
    DatasetStorageEstimate,
    DatasetStorageEstimateRequest,
    ReadinessResponse,
    RegisterPairedDatasetRequest,
    VideoGenerationConfig,
    estimate_storage,
    generate_video_dataset,
    register_paired_dataset,
    video_readiness,
)
from .errors import ApiError, api_error_handler, http_error_handler, validation_error_handler
from .jobs import CreateJobRequest, Job, JobLogResponse, job_store
from .metrics import (
    ActiveRunStatus,
    HardwareTelemetry,
    MetricsResponse,
    PreviewResponse,
    active_run_status,
    hardware_telemetry_for_project,
    initialize_run_metrics,
    latest_preview,
    preview_asset_path,
    read_metrics,
)
from .models import (
    CompatibilityResponse,
    CreateModelRequest,
    ModelObject,
    UpdateModelRequest,
    check_dataset_model_compatibility,
    create_model,
    default_model_config,
    get_model,
    list_models,
    update_model,
)
from .project_store import create_project, open_project, write_project
from .runs import (
    DeviceListResponse,
    LaunchRunRequest,
    ResumeRunRequest,
    RunObject,
    RunSetupRequest,
    TrainingReadinessResponse,
    available_devices,
    create_run,
    get_run,
    launch_run,
    list_runs,
    map_job_to_run,
    pause_run,
    recover_interrupted_runs,
    resume_run,
    stop_run,
    training_readiness,
)
from .schemas import (
    CreateProjectRequest,
    HealthResponse,
    OpenProjectRequest,
    ProjectResponse,
    SaveWorkspaceRequest,
    VersionResponse,
    normalize_path,
)
from .security import require_session_token

app = FastAPI(title="sr-tuner local API", version=__version__)
app.add_exception_handler(ApiError, api_error_handler)
app.add_exception_handler(StarletteHTTPException, http_error_handler)
app.add_exception_handler(RequestValidationError, validation_error_handler)

_project_sessions: dict[str, Path] = {}


def _remember_project(project_root: str, project_id: str) -> None:
    _project_sessions[project_id] = normalize_path(project_root)


def _project_response(project) -> ProjectResponse:
    if project.root_path is None:
        raise ApiError(500, "project_root_missing", "Project root is not bound for this session.", recoverable=False)
    _remember_project(project.root_path, project.id)
    remember_recent_project(project)
    root = normalize_path(project.root_path)
    return ProjectResponse(project=project, project_id=project.id, root_path=str(root), project_file=str(root / "sr-tuner.project.json"))


def _open_session_project(project_id: str):
    project = open_project(_session_project_path(project_id))
    project = recover_interrupted_runs(project)
    return project


def _session_project_path(project_id: str) -> Path:
    root = _project_sessions.get(project_id)
    if root is None:
        raise ApiError(
            404,
            "project_session_not_found",
            "Project session was not found. Reopen the project.",
            details={"project_id": project_id},
        )
    return root


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(status="ok", app=APP_NAME, version=__version__)


@app.get("/version", response_model=VersionResponse)
def version() -> VersionResponse:
    return VersionResponse(app=APP_NAME, version=__version__)


@app.post("/projects", response_model=ProjectResponse)
def create_project_endpoint(
    request: CreateProjectRequest,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project = create_project(normalize_path(request.parent_path), request.name, create_here=request.create_here)
    return _project_response(project)


@app.post("/projects/open", response_model=ProjectResponse)
def open_project_endpoint(
    request: OpenProjectRequest,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project = open_project(normalize_path(request.path))
    project = recover_interrupted_runs(project)
    return _project_response(project)


@app.get("/projects/recent", response_model=RecentProjectsResponse)
def recent_projects_endpoint() -> RecentProjectsResponse:
    return list_recent_projects()


@app.post("/projects/recent/open", response_model=ProjectResponse)
def open_recent_project_endpoint(
    request: OpenProjectRequest,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project = open_project(normalize_path(request.path))
    project = recover_interrupted_runs(project)
    return _project_response(project)


@app.put("/projects/{project_id}/workspace", response_model=ProjectResponse)
def save_workspace_endpoint(
    project_id: str,
    request: SaveWorkspaceRequest,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project = update_workspace(
        _session_project_path(project_id),
        selected_tab=request.selected_tab,
        theme=request.theme,
        density=request.density,
        per_project_ui_state=request.per_project_ui_state,
    )
    return _project_response(project)


@app.get("/projects/{project_id}/workspace", response_model=WorkspacePreferencesResponse)
def workspace_preferences_endpoint(project_id: str) -> WorkspacePreferencesResponse:
    return workspace_preferences(_session_project_path(project_id))


@app.get("/projects/{project_id}/dashboard", response_model=DashboardSummary)
def dashboard_endpoint(project_id: str) -> DashboardSummary:
    return dashboard_summary(_session_project_path(project_id))


@app.get("/projects/{project_id}/activity", response_model=ActivityFeedResponse)
def activity_endpoint(project_id: str, limit: int = 20) -> ActivityFeedResponse:
    return activity_feed(_session_project_path(project_id), limit=limit)


@app.get("/projects/{project_id}/datasets", response_model=list[DatasetObject])
def list_datasets_endpoint(project_id: str) -> list[DatasetObject]:
    project = open_project(_session_project_path(project_id))
    return [DatasetObject.model_validate(raw) for raw in project.datasets]


@app.post("/projects/{project_id}/datasets/paired", response_model=ProjectResponse)
def register_paired_dataset_endpoint(
    project_id: str,
    request: RegisterPairedDatasetRequest,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project, _dataset, job = register_paired_dataset(_session_project_path(project_id), request)
    project = record_activity(project, "dataset", f"Dataset {_dataset.name} registered.", severity="success" if _dataset.validation.usable else "warning", object_id=_dataset.id)
    project = write_project(project)
    if job is not None:
        job.project_id = project.id
        job.object_id = _dataset.id
        job_store.put(job)
    return _project_response(project)


@app.post("/projects/{project_id}/datasets/storage-estimate", response_model=DatasetStorageEstimate)
def estimate_dataset_storage_endpoint(
    project_id: str,
    request: DatasetStorageEstimateRequest,
    _token: None = Depends(require_session_token),
) -> DatasetStorageEstimate:
    return estimate_storage(_session_project_path(project_id), request)


@app.get("/dependencies/video", response_model=ReadinessResponse)
def video_readiness_endpoint() -> ReadinessResponse:
    return video_readiness()


@app.post("/projects/{project_id}/datasets/video", response_model=ProjectResponse)
def generate_video_dataset_endpoint(
    project_id: str,
    request: VideoGenerationConfig,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project, _dataset, job = generate_video_dataset(_session_project_path(project_id), request)
    project = record_activity(project, "dataset", f"Video dataset {_dataset.name} generated.", severity="success", object_id=_dataset.id)
    project = write_project(project)
    job_store.put(job)
    return _project_response(project)


@app.get("/projects/{project_id}/datasets/{dataset_id}/detail", response_model=DatasetDetailResponse)
def dataset_detail_endpoint(project_id: str, dataset_id: str, preview_index: int = 0) -> DatasetDetailResponse:
    return dataset_detail(_session_project_path(project_id), dataset_id, preview_index=preview_index)


@app.post("/projects/{project_id}/datasets/video/metadata", response_model=VideoWizardMetadata)
def video_wizard_metadata_endpoint(
    project_id: str,
    request: VideoGenerationConfig,
    _token: None = Depends(require_session_token),
) -> VideoWizardMetadata:
    _session_project_path(project_id)
    return video_wizard_metadata(request)


@app.post("/projects/{project_id}/datasets/{dataset_id}/resynthesize", response_model=UnsupportedState)
def dataset_resynthesis_endpoint(
    project_id: str,
    dataset_id: str,
    _token: None = Depends(require_session_token),
) -> UnsupportedState:
    _session_project_path(project_id)
    return UnsupportedState(code="resynthesis_unavailable", message="Re-synthesis creates a new dataset version, but this backend path is not implemented yet.")


@app.get("/projects/{project_id}/models", response_model=list[ModelObject])
def list_models_endpoint(project_id: str) -> list[ModelObject]:
    return list_models(_session_project_path(project_id))


@app.get("/model-defaults/internal-residual-pixelshuffle")
def model_defaults_endpoint() -> dict:
    return default_model_config()


@app.post("/projects/{project_id}/models", response_model=ProjectResponse)
def create_model_endpoint(
    project_id: str,
    request: CreateModelRequest,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project, _model = create_model(_session_project_path(project_id), request)
    project = record_activity(project, "model", f"Model {_model.name} configured.", object_id=_model.id)
    project = write_project(project)
    return _project_response(project)


@app.get("/projects/{project_id}/model-templates", response_model=ModelTemplateCatalogResponse)
def model_templates_endpoint(project_id: str) -> ModelTemplateCatalogResponse:
    _session_project_path(project_id)
    return model_template_catalog()


@app.post("/projects/{project_id}/model-templates/{template_id}/save-as-model", response_model=ProjectResponse)
def save_template_as_model_endpoint(
    project_id: str,
    template_id: str,
    name: str,
    scale: int = 4,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project = save_template_as_model(_session_project_path(project_id), template_id, name, scale)
    return _project_response(project)


@app.get("/projects/{project_id}/models/{model_id}", response_model=ModelObject)
def get_model_endpoint(project_id: str, model_id: str) -> ModelObject:
    return get_model(_session_project_path(project_id), model_id)


@app.put("/projects/{project_id}/models/{model_id}", response_model=ProjectResponse)
def update_model_endpoint(
    project_id: str,
    model_id: str,
    request: UpdateModelRequest,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project, _model = update_model(_session_project_path(project_id), model_id, request)
    return _project_response(project)


@app.get("/projects/{project_id}/compatibility", response_model=CompatibilityResponse)
def compatibility_endpoint(project_id: str, dataset_id: str, model_id: str) -> CompatibilityResponse:
    return check_dataset_model_compatibility(_session_project_path(project_id), dataset_id, model_id)


@app.get("/dependencies/training", response_model=TrainingReadinessResponse)
def training_readiness_endpoint(tensorboard: bool = False) -> TrainingReadinessResponse:
    return training_readiness(include_tensorboard=tensorboard)


@app.get("/devices", response_model=DeviceListResponse)
def devices_endpoint() -> DeviceListResponse:
    return available_devices()


@app.get("/projects/{project_id}/runs", response_model=list[RunObject])
def list_runs_endpoint(project_id: str) -> list[RunObject]:
    _open_session_project(project_id)
    return list_runs(_session_project_path(project_id))


@app.post("/projects/{project_id}/runs", response_model=ProjectResponse)
def create_run_endpoint(
    project_id: str,
    request: RunSetupRequest,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project, _run = create_run(_session_project_path(project_id), request)
    project = record_activity(project, "run", f"Run {_run.name} configured.", object_id=_run.id)
    project = write_project(project)
    return _project_response(project)


@app.post("/projects/{project_id}/training/estimate", response_model=TrainingEstimateResponse)
def training_estimate_endpoint(
    project_id: str,
    request: RunSetupRequest,
    _token: None = Depends(require_session_token),
) -> TrainingEstimateResponse:
    return training_estimate(_session_project_path(project_id), request)


@app.get("/projects/{project_id}/runs/{run_id}", response_model=RunObject)
def get_run_endpoint(project_id: str, run_id: str) -> RunObject:
    return get_run(_session_project_path(project_id), run_id)


@app.post("/projects/{project_id}/runs/{run_id}/launch", response_model=ProjectResponse)
def launch_run_endpoint(
    project_id: str,
    run_id: str,
    _request: LaunchRunRequest | None = None,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project, _run, job = launch_run(_session_project_path(project_id), run_id)
    initialize_run_metrics(_session_project_path(project_id), _run)
    job.project_id = project.id
    job_store.put(job)
    project = open_project(_session_project_path(project_id))
    project = record_activity(project, "run", f"Run {_run.name} launched.", object_id=_run.id)
    project = write_project(project)
    return _project_response(project)


@app.post("/projects/{project_id}/runs/{run_id}/pause", response_model=ProjectResponse)
def pause_run_endpoint(
    project_id: str,
    run_id: str,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project, _run = pause_run(_session_project_path(project_id), run_id)
    return _project_response(project)


@app.post("/projects/{project_id}/runs/{run_id}/resume", response_model=ProjectResponse)
def resume_run_endpoint(
    project_id: str,
    run_id: str,
    request: ResumeRunRequest,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project, _run, job = resume_run(_session_project_path(project_id), run_id, request)
    job.project_id = project.id
    job_store.put(job)
    return _project_response(project)


@app.post("/projects/{project_id}/runs/{run_id}/stop", response_model=ProjectResponse)
def stop_run_endpoint(
    project_id: str,
    run_id: str,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    run = get_run(_session_project_path(project_id), run_id)
    job = job_store.get(run.job_id) if run.job_id is not None else None
    project, _run = stop_run(_session_project_path(project_id), run_id, job)
    if job is not None:
        job_store.put(job)
    return _project_response(project)


@app.post("/projects/{project_id}/runs/{run_id}/sync-job", response_model=ProjectResponse)
def sync_run_job_endpoint(
    project_id: str,
    run_id: str,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    run = get_run(_session_project_path(project_id), run_id)
    if run.job_id is None:
        return _project_response(open_project(_session_project_path(project_id)))
    job = job_store.get(run.job_id)
    project, _run = map_job_to_run(_session_project_path(project_id), run_id, job)
    return _project_response(project)


@app.get("/projects/{project_id}/active-run", response_model=ActiveRunStatus)
def active_run_endpoint(project_id: str) -> ActiveRunStatus:
    return active_run_status(_session_project_path(project_id))


@app.get("/projects/{project_id}/live/detail", response_model=LiveRunDetailResponse)
def live_detail_endpoint(project_id: str) -> LiveRunDetailResponse:
    return live_detail(_session_project_path(project_id))


@app.post("/projects/{project_id}/runs/{run_id}/snapshot", response_model=SnapshotResponse)
def snapshot_checkpoint_endpoint(
    project_id: str,
    run_id: str,
    _token: None = Depends(require_session_token),
) -> SnapshotResponse:
    return snapshot_checkpoint(_session_project_path(project_id), run_id)


@app.get("/projects/{project_id}/runs/{run_id}/metrics", response_model=MetricsResponse)
def run_metrics_endpoint(project_id: str, run_id: str, limit: int = 200) -> MetricsResponse:
    return read_metrics(_session_project_path(project_id), run_id, limit=limit)


@app.get("/projects/{project_id}/hardware", response_model=HardwareTelemetry)
def hardware_endpoint(project_id: str) -> HardwareTelemetry:
    return hardware_telemetry_for_project(_session_project_path(project_id))


@app.get("/projects/{project_id}/runs/{run_id}/preview", response_model=PreviewResponse)
def preview_endpoint(project_id: str, run_id: str) -> PreviewResponse:
    return latest_preview(_session_project_path(project_id), run_id)


@app.get("/projects/{project_id}/runs/{run_id}/preview-assets/{kind}")
def preview_asset_endpoint(project_id: str, run_id: str, kind: str) -> FileResponse:
    return FileResponse(preview_asset_path(_session_project_path(project_id), run_id, kind), media_type="image/png")


@app.get("/dependencies/onnx", response_model=OnnxReadinessResponse)
def onnx_readiness_endpoint() -> OnnxReadinessResponse:
    return onnx_readiness()


@app.get("/projects/{project_id}/checkpoints", response_model=ProjectCheckpointIndex)
def project_checkpoints_endpoint(project_id: str) -> ProjectCheckpointIndex:
    return derive_project_checkpoints(_session_project_path(project_id))


@app.get("/projects/{project_id}/checkpoints/aggregate", response_model=CheckpointAggregateResponse)
def checkpoint_aggregate_endpoint(project_id: str) -> CheckpointAggregateResponse:
    return checkpoint_aggregate(_session_project_path(project_id))


@app.get("/projects/{project_id}/runs/{run_id}/checkpoints", response_model=CheckpointListResponse)
def list_run_checkpoints_endpoint(project_id: str, run_id: str) -> CheckpointListResponse:
    return list_run_checkpoints(_session_project_path(project_id), run_id)


@app.delete(
    "/projects/{project_id}/runs/{run_id}/checkpoints/{checkpoint_id}",
    response_model=CheckpointListResponse,
)
def delete_checkpoint_endpoint(
    project_id: str,
    run_id: str,
    checkpoint_id: str,
    _token: None = Depends(require_session_token),
) -> CheckpointListResponse:
    return delete_checkpoint(_session_project_path(project_id), run_id, checkpoint_id)


@app.post(
    "/projects/{project_id}/runs/{run_id}/checkpoints/{checkpoint_id}/export-pth",
    response_model=Job,
)
def export_pth_endpoint(
    project_id: str,
    run_id: str,
    checkpoint_id: str,
    request: ExportPthRequest,
    _token: None = Depends(require_session_token),
) -> Job:
    job = export_checkpoint_pth(_session_project_path(project_id), run_id, checkpoint_id, request.destination)
    job.project_id = project_id
    job_store.put(job)
    return job


@app.post(
    "/projects/{project_id}/runs/{run_id}/checkpoints/{checkpoint_id}/export-onnx",
    response_model=Job,
)
def export_onnx_endpoint(
    project_id: str,
    run_id: str,
    checkpoint_id: str,
    request: ExportOnnxRequest,
    _token: None = Depends(require_session_token),
) -> Job:
    job = export_checkpoint_onnx(_session_project_path(project_id), run_id, checkpoint_id, request.destination)
    job.project_id = project_id
    job_store.put(job)
    return job


@app.get("/dependencies/inference", response_model=InferenceReadinessResponse)
def inference_readiness_endpoint(device: str = "cpu") -> InferenceReadinessResponse:
    return inference_readiness(device)


@app.post("/projects/{project_id}/inference", response_model=InferenceRecord)
def run_inference_endpoint(
    project_id: str,
    request: InferenceRequest,
    _token: None = Depends(require_session_token),
) -> InferenceRecord:
    record, job = run_inference(_session_project_path(project_id), request)
    job.project_id = project_id
    job_store.put(job)
    return record


@app.get("/projects/{project_id}/inference", response_model=InferenceHistoryResponse)
def list_inference_endpoint(project_id: str) -> InferenceHistoryResponse:
    return list_inference_history(_session_project_path(project_id))


@app.get("/projects/{project_id}/inference/inspector", response_model=InferenceInspectorResponse)
def inference_inspector_endpoint(project_id: str) -> InferenceInspectorResponse:
    return inference_inspector(_session_project_path(project_id))


@app.post("/jobs", response_model=Job)
def create_job_endpoint(
    request: CreateJobRequest,
    _token: None = Depends(require_session_token),
) -> Job:
    if request.project_id is not None:
        _session_project_path(request.project_id)
    return job_store.create(request)


@app.get("/jobs/{job_id}", response_model=Job)
def get_job_endpoint(job_id: str) -> Job:
    return job_store.get(job_id)


@app.get("/jobs/{job_id}/logs", response_model=JobLogResponse)
def get_job_logs_endpoint(job_id: str) -> JobLogResponse:
    return job_store.log_tail(job_id)


@app.post("/jobs/{job_id}/cancel", response_model=Job)
def cancel_job_endpoint(
    job_id: str,
    _token: None = Depends(require_session_token),
) -> Job:
    return job_store.cancel(job_id)
