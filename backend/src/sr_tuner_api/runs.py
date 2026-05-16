from __future__ import annotations

import importlib.util
import random
import shutil
from pathlib import Path
from typing import Any, Literal

from pydantic import BaseModel, Field, model_validator

from .datasets import DatasetObject, SUPPORTED_IMAGE_EXTENSIONS
from .errors import ApiError
from .ids import new_id
from .jobs import Job, JobError, utc_now_iso
from .models import LossWeights, ModelObject
from .project_store import open_project, store_asset_path, write_project
from .schemas import ProjectState


RunLifecycleState = Literal[
    "draft",
    "configured",
    "running",
    "pausing",
    "paused",
    "resuming",
    "stopping",
    "stopped",
    "completed",
    "failed",
    "interrupted",
]
TrainMode = Literal["new", "resume", "fine_tune"]
PrecisionMode = Literal["float32", "mixed"]
SchedulerType = Literal["none", "cosine", "step"]
DiffMode = Literal["absolute", "heatmap", "both"]

ACTIVE_RUN_STATES = {"running", "pausing", "paused", "resuming", "stopping"}
TERMINAL_RUN_STATES = {"stopped", "completed", "failed", "interrupted"}


class ValidationSplitConfig(BaseModel):
    enabled: bool = True
    percentage: float = Field(default=0.1, ge=0, lt=1)
    every_epochs: int = Field(default=1, ge=1)
    seed: int = 42
    shuffle: bool = True


class LoggingConfig(BaseModel):
    tensorboard: bool = False


class SchedulerOptions(BaseModel):
    type: SchedulerType = "cosine"
    warmup_epochs: int = Field(default=0, ge=0)
    decay_epochs: list[int] = Field(default_factory=list)
    decay_factor: float = Field(default=0.5, gt=0, le=1)


class RunSettings(BaseModel):
    train_mode: TrainMode = "new"
    device: str = "cpu"
    epochs: int = Field(default=10, ge=1)
    batch_size: int = Field(default=16, ge=1)
    checkpoint_cadence: int = Field(default=1, ge=1)
    validation_split: ValidationSplitConfig = Field(default_factory=ValidationSplitConfig)
    logging: LoggingConfig = Field(default_factory=LoggingConfig)
    precision: PrecisionMode = "float32"
    compile: bool = False
    scheduler: SchedulerOptions = Field(default_factory=SchedulerOptions)
    diff_mode: DiffMode = "absolute"
    loss_weights: LossWeights = Field(default_factory=LossWeights)
    learning_rate: float | None = None
    source_core_weights_path: str | None = None


class RunLineage(BaseModel):
    source_run_id: str | None = None
    source_checkpoint_id: str | None = None
    source_checkpoint_path: str | None = None
    fine_tune_source_checkpoint_id: str | None = None


class RunObject(BaseModel):
    id: str = Field(default_factory=lambda: new_id("run"))
    name: str
    dataset_id: str
    model_id: str
    train_mode: TrainMode = "new"
    state: RunLifecycleState = "configured"
    folder: str
    log_dir: str | None = None
    job_id: str | None = None
    settings: RunSettings = Field(default_factory=RunSettings)
    train_indexes: list[int] = Field(default_factory=list)
    validation_indexes: list[int] = Field(default_factory=list)
    checkpoints: list[dict[str, Any]] = Field(default_factory=list)
    lineage: RunLineage = Field(default_factory=RunLineage)
    error: dict[str, Any] | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)
    created_at: str = Field(default_factory=utc_now_iso)
    updated_at: str = Field(default_factory=utc_now_iso)


class RunSetupRequest(BaseModel):
    name: str
    dataset_id: str
    model_id: str
    train_mode: TrainMode = "new"
    device: str = "cpu"
    epochs: int = Field(default=10, ge=1)
    batch_size: int = Field(default=16, ge=1)
    checkpoint_cadence: int = Field(default=1, ge=1)
    validation_enabled: bool = True
    validation_percentage: float = Field(default=0.1, ge=0, lt=1)
    validation_every_epochs: int = Field(default=1, ge=1)
    validation_seed: int = 42
    validation_shuffle: bool = True
    tensorboard: bool = False
    precision: PrecisionMode = "float32"
    compile: bool = False
    warmup_epochs: int = Field(default=0, ge=0)
    scheduler_type: SchedulerType = "cosine"
    scheduler_decay_epochs: list[int] = Field(default_factory=list)
    scheduler_decay_factor: float = Field(default=0.5, gt=0, le=1)
    diff_mode: DiffMode = "absolute"
    loss_weights: LossWeights = Field(default_factory=LossWeights)
    learning_rate: float | None = None
    source_core_weights_path: str | None = None
    source_checkpoint_id: str | None = None
    source_checkpoint_path: str | None = None

    @model_validator(mode="after")
    def validate_resume_source(self) -> "RunSetupRequest":
        if self.train_mode in {"resume", "fine_tune"} and not (self.source_checkpoint_id or self.source_checkpoint_path or self.source_core_weights_path):
            raise ValueError("A checkpoint source is required for resume or fine-tune runs.")
        return self


class LaunchRunRequest(BaseModel):
    run_id: str


class ResumeRunRequest(BaseModel):
    checkpoint_id: str | None = None
    checkpoint_path: str | None = None


class DependencyItem(BaseModel):
    name: str
    available: bool
    required: bool
    message: str


class TrainingReadinessResponse(BaseModel):
    available: bool
    dependencies: list[DependencyItem]
    message: str


class DeviceInfo(BaseModel):
    id: str
    label: str
    type: str
    available: bool = True


class DeviceListResponse(BaseModel):
    default_device: str = "cpu"
    devices: list[DeviceInfo]


def recover_interrupted_runs(project: ProjectState) -> ProjectState:
    changed = False
    recovered: list[dict[str, Any]] = []
    for raw in project.runs:
        if raw.get("state") in {"running", "pausing", "resuming", "stopping"}:
            previous_state = raw.get("state")
            raw["state"] = "interrupted"
            raw["updated_at"] = utc_now_iso()
            recovered.append({"run_id": raw.get("id"), "previous_state": previous_state})
            changed = True
    if changed:
        project.metadata["interrupted_run_recovery"] = {
            "recovered_at": utc_now_iso(),
            "runs": recovered,
        }
        return write_project(project)
    return project


def list_runs(project_root: Path) -> list[RunObject]:
    project = open_project(project_root)
    return [RunObject.model_validate(raw) for raw in project.runs]


def get_run(project_root: Path, run_id: str) -> RunObject:
    project = open_project(project_root)
    return _find_run(project, run_id)


def create_run(project_root: Path, request: RunSetupRequest) -> tuple[ProjectState, RunObject]:
    project = open_project(project_root)
    dataset = _find_dataset(project, request.dataset_id)
    model = _find_model(project, request.model_id)
    _validate_run_setup(project, dataset, model, request)

    run_id = new_id("run")
    run_folder = project_root / "runs" / run_id
    run_folder.mkdir(parents=True, exist_ok=False)
    (run_folder / "checkpoints").mkdir()
    log_dir: str | None = None
    if request.tensorboard:
        log_path = run_folder / "logs" / "tensorboard"
        log_path.mkdir(parents=True)
        log_dir = store_asset_path(project_root, log_path).stored

    train_indexes, validation_indexes = split_indexes(
        pair_count=dataset.validation.pair_count,
        validation_percentage=request.validation_percentage if request.validation_enabled else 0.0,
        seed=request.validation_seed,
        shuffle=request.validation_shuffle,
    )
    run = RunObject(
        id=run_id,
        name=request.name.strip(),
        dataset_id=dataset.id,
        model_id=model.id,
        train_mode=request.train_mode,
        folder=store_asset_path(project_root, run_folder).stored,
        log_dir=log_dir,
        settings=RunSettings(
            train_mode=request.train_mode,
            device=request.device,
            epochs=request.epochs,
            batch_size=request.batch_size,
            checkpoint_cadence=request.checkpoint_cadence,
            validation_split=ValidationSplitConfig(
                enabled=request.validation_enabled,
                percentage=request.validation_percentage if request.validation_enabled else 0.0,
                every_epochs=request.validation_every_epochs,
                seed=request.validation_seed,
                shuffle=request.validation_shuffle,
            ),
            logging=LoggingConfig(tensorboard=request.tensorboard),
            precision=request.precision,
            compile=request.compile,
            scheduler=SchedulerOptions(
                type=request.scheduler_type,
                warmup_epochs=request.warmup_epochs,
                decay_epochs=request.scheduler_decay_epochs,
                decay_factor=request.scheduler_decay_factor,
            ),
            diff_mode=request.diff_mode,
            loss_weights=request.loss_weights,
            learning_rate=request.learning_rate,
            source_core_weights_path=request.source_core_weights_path,
        ),
        train_indexes=train_indexes,
        validation_indexes=validation_indexes,
        lineage=RunLineage(
            source_checkpoint_id=request.source_checkpoint_id if request.train_mode == "resume" else None,
            source_checkpoint_path=request.source_checkpoint_path if request.train_mode == "resume" else None,
            fine_tune_source_checkpoint_id=request.source_checkpoint_id if request.train_mode == "fine_tune" else None,
        ),
metadata={
            "project_id": project.id,
            "dataset_scale": dataset.validated_scale or dataset.scale,
            "model_architecture": model.architecture,
        },
    )
    project.runs.append(run.model_dump())
    return write_project(project), run


def launch_run(project_root: Path, run_id: str) -> tuple[ProjectState, RunObject, Job]:
    project = open_project(project_root)
    run = _find_run(project, run_id)
    if run.state not in {"configured", "paused", "interrupted", "stopped"}:
        raise ApiError(409, "run_not_launchable", "Run cannot be launched from its current state.", details={"state": run.state})
    active = _active_run(project, exclude_run_id=run.id)
    if active is not None:
        raise ApiError(
            409,
            "active_run_exists",
            "Another training run is already active.",
            details={"run_id": active.id, "state": active.state},
        )
    readiness = training_readiness(include_tensorboard=run.settings.logging.tensorboard)
    if not readiness.available:
        raise ApiError(
            409,
            "training_dependencies_missing",
            readiness.message,
            details={"dependencies": [item.model_dump() for item in readiness.dependencies]},
        )
    job = Job(
        type="training",
        project_id=project.id,
        object_id=run.id,
        status="running",
        progress=0.0,
        started_at=utc_now_iso(),
        logs=[f"Training started for run {run.name}."],
    )
    run.job_id = job.id
    _apply_job_state(run, job)
    project = _replace_run(project, run)
    return write_project(project), run, job


def pause_run(project_root: Path, run_id: str) -> tuple[ProjectState, RunObject]:
    project = open_project(project_root)
    run = _find_run(project, run_id)
    if run.state != "running":
        raise ApiError(409, "run_not_running", "Only a running live run can be paused.", details={"state": run.state})
    run.state = "paused"
    run.updated_at = utc_now_iso()
    return write_project(_replace_run(project, run)), run


def resume_run(project_root: Path, run_id: str, request: ResumeRunRequest) -> tuple[ProjectState, RunObject, Job]:
    project = open_project(project_root)
    run = _find_run(project, run_id)
    active = _active_run(project, exclude_run_id=run.id)
    if active is not None:
        raise ApiError(409, "active_run_exists", "Another training run is already active.", details={"run_id": active.id})
    if run.state == "paused":
        run.state = "running"
        run.updated_at = utc_now_iso()
        job = Job(type="training", project_id=project.id, object_id=run.id, status="running", progress=0.0, started_at=utc_now_iso())
        run.job_id = job.id
        return write_project(_replace_run(project, run)), run, job
    if run.state not in {"interrupted", "stopped"}:
        raise ApiError(409, "run_not_resumable", "Run cannot be resumed from its current state.", details={"state": run.state})
    if not (request.checkpoint_id or request.checkpoint_path):
        raise ApiError(422, "resume_checkpoint_required", "A checkpoint is required to resume this run.")
    run.lineage.source_checkpoint_id = request.checkpoint_id
    run.lineage.source_checkpoint_path = request.checkpoint_path
    run.state = "running"
    run.updated_at = utc_now_iso()
    job = Job(type="training", project_id=project.id, object_id=run.id, status="running", progress=0.0, started_at=utc_now_iso())
    run.job_id = job.id
    return write_project(_replace_run(project, run)), run, job


def delete_run_config(project_root: Path, run_id: str) -> tuple[ProjectState, RunObject]:
    project = open_project(project_root)
    run = _find_run(project, run_id)
    if run.state in ACTIVE_RUN_STATES:
        raise ApiError(409, "run_is_active", "An active run cannot be deleted.", details={"state": run.state})

    run_folder = _resolve_run_folder(project_root, run)
    if run_folder.is_dir():
        shutil.rmtree(run_folder)
    elif run_folder.exists():
        run_folder.unlink()

    project.runs = [raw for raw in project.runs if raw.get("id") != run_id]
    return write_project(project), run


def stop_run(project_root: Path, run_id: str, job: Job | None = None) -> tuple[ProjectState, RunObject]:
    project = open_project(project_root)
    run = _find_run(project, run_id)
    if run.state not in ACTIVE_RUN_STATES:
        raise ApiError(409, "run_not_active", "Only an active run can be stopped.", details={"state": run.state})
    if job is not None:
        job.status = "canceled"
        job.cancel_requested = True
        job.finished_at = utc_now_iso()
        job.retained_partial_artifacts = True
    run.state = "stopped"
    run.updated_at = utc_now_iso()
    return write_project(_replace_run(project, run)), run


def map_job_to_run(project_root: Path, run_id: str, job: Job) -> tuple[ProjectState, RunObject]:
    project = open_project(project_root)
    run = _find_run(project, run_id)
    _apply_job_state(run, job)
    run.updated_at = utc_now_iso()
    return write_project(_replace_run(project, run)), run


def split_indexes(*, pair_count: int, validation_percentage: float, seed: int, shuffle: bool) -> tuple[list[int], list[int]]:
    indexes = list(range(pair_count))
    if shuffle:
        rng = random.Random(seed)
        rng.shuffle(indexes)
    validation_count = round(pair_count * validation_percentage)
    if validation_percentage > 0 and pair_count > 1:
        validation_count = max(1, min(pair_count - 1, validation_count))
    validation = sorted(indexes[:validation_count])
    train = sorted(indexes[validation_count:])
    return train, validation


def training_readiness(*, include_tensorboard: bool = False) -> TrainingReadinessResponse:
    dependencies = [
        DependencyItem(
            name="torch",
            available=_module_available("torch"),
            required=True,
            message="PyTorch is available." if _module_available("torch") else "PyTorch is not installed in the backend environment.",
        ),
        DependencyItem(
            name="image_loading",
            available=_module_available("PIL"),
            required=True,
            message="Pillow is available." if _module_available("PIL") else "Pillow is required for training image loading.",
        ),
        DependencyItem(
            name="tensorboard",
            available=_module_available("torch.utils.tensorboard") or _module_available("tensorboard"),
            required=include_tensorboard,
            message="TensorBoard logging is available."
            if (_module_available("torch.utils.tensorboard") or _module_available("tensorboard"))
            else "TensorBoard logging dependency is not installed.",
        ),
    ]
    missing_required = [item for item in dependencies if item.required and not item.available]
    return TrainingReadinessResponse(
        available=not missing_required,
        dependencies=dependencies,
        message="Training dependencies are ready." if not missing_required else "Required training dependencies are missing.",
    )


def available_devices() -> DeviceListResponse:
    devices = [DeviceInfo(id="cpu", label="CPU", type="cpu")]
    default_device = "cpu"
    if _module_available("torch"):
        try:
            import torch

            if torch.cuda.is_available():
                backend = "ROCm" if getattr(torch.version, "hip", None) else "CUDA"
                for index in range(torch.cuda.device_count()):
                    name = torch.cuda.get_device_name(index)
                    device_id = f"cuda:{index}"
                    devices.append(DeviceInfo(id=device_id, label=f"{backend} {index}: {name}", type="cuda"))
                    if default_device == "cpu":
                        default_device = device_id
            if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
                devices.append(DeviceInfo(id="mps", label="Apple Metal", type="mps"))
                if default_device == "cpu":
                    default_device = "mps"
        except Exception:
            return DeviceListResponse(default_device=default_device, devices=devices)
    return DeviceListResponse(default_device=default_device, devices=devices)


def build_internal_sr_model(scale: int, num_features: int, num_blocks: int):
    if not _module_available("torch"):
        raise ApiError(409, "torch_missing", "PyTorch is required to build the internal SR model.")
    import torch
    from torch import nn

    class ResidualBlock(nn.Module):
        def __init__(self, channels: int) -> None:
            super().__init__()
            self.body = nn.Sequential(
                nn.Conv2d(channels, channels, 3, padding=1),
                nn.ReLU(inplace=True),
                nn.Conv2d(channels, channels, 3, padding=1),
            )

        def forward(self, value):
            return value + self.body(value)

    class InternalResidualPixelShuffleSR(nn.Module):
        def __init__(self) -> None:
            super().__init__()
            self.head = nn.Conv2d(3, num_features, 3, padding=1)
            self.body = nn.Sequential(*[ResidualBlock(num_features) for _ in range(num_blocks)])
            self.tail = nn.Sequential(
                nn.Conv2d(num_features, 3 * scale * scale, 3, padding=1),
                nn.PixelShuffle(scale),
            )

        def forward(self, value):
            features = self.head(value)
            return torch.clamp(self.tail(features + self.body(features)), 0, 1)

    return InternalResidualPixelShuffleSR()


def build_paired_sr_dataset(project_root: Path, dataset: DatasetObject, indexes: list[int] | None = None):
    if not _module_available("torch"):
        raise ApiError(409, "torch_missing", "PyTorch is required to build the training dataset.")
    if not _module_available("PIL"):
        raise ApiError(409, "image_loading_missing", "Pillow is required to load training images.")
    import torch
    from PIL import Image
    from torch.utils.data import Dataset

    root = _resolve_dataset_root(project_root, dataset)
    hr_files = _dataset_files(root / "HR")
    lr_files = _dataset_files(root / "LR")
    stems = sorted(set(hr_files) & set(lr_files))
    selected = indexes if indexes is not None else list(range(len(stems)))
    pairs = [(lr_files[stems[index]], hr_files[stems[index]]) for index in selected]

    class PairedSuperResolutionDataset(Dataset):
        def __len__(self) -> int:
            return len(pairs)

        def __getitem__(self, index: int):
            lr_path, hr_path = pairs[index]
            lr = _image_to_tensor(lr_path)
            hr = _image_to_tensor(hr_path)
            return {"lr": lr, "hr": hr, "stem": lr_path.stem}

    def _image_to_tensor(path: Path):
        image = Image.open(path).convert("RGB")
        width, height = image.size
        values = torch.frombuffer(image.tobytes(), dtype=torch.uint8).clone()
        values = values.view(height, width, 3).permute(2, 0, 1).float()
        return values / 255.0

    return PairedSuperResolutionDataset()


def _resolve_dataset_root(project_root: Path, dataset: DatasetObject) -> Path:
    root = Path(dataset.paths.root)
    if dataset.paths.mode == "relative":
        return project_root / root
    return root


def _dataset_files(folder: Path) -> dict[str, Path]:
    files: dict[str, Path] = {}
    for path in folder.iterdir():
        if path.name.startswith(".") or not path.is_file():
            continue
        if path.suffix.lower().lstrip(".") in SUPPORTED_IMAGE_EXTENSIONS:
            files[path.stem] = path
    return files


def _apply_job_state(run: RunObject, job: Job) -> None:
    if job.status == "queued":
        run.state = "configured"
    elif job.status == "running":
        run.state = "running"
    elif job.status == "canceling":
        run.state = "stopping"
    elif job.status == "canceled":
        run.state = "stopped"
    elif job.status == "completed":
        run.state = "completed"
    elif job.status == "failed":
        run.state = "failed"
        if job.error is not None:
            run.error = job.error.model_dump()


def _validate_run_setup(project: ProjectState, dataset: DatasetObject, model: ModelObject, request: RunSetupRequest) -> None:
    if not request.name.strip():
        raise ApiError(422, "run_name_required", "Run name is required.")
    if not dataset.validation.usable:
        raise ApiError(422, "dataset_not_usable", "Selected dataset is not usable for training.", details={"dataset_id": dataset.id})
    losses = request.loss_weights
    if losses.l1 <= 0 and losses.perceptual <= 0 and losses.adversarial <= 0:
        raise ApiError(422, "loss_weights_required", "At least one training loss weight must be greater than zero.")
    if request.tensorboard:
        readiness = training_readiness(include_tensorboard=True)
        if not readiness.available:
            missing = [item.model_dump() for item in readiness.dependencies if item.required and not item.available]
            raise ApiError(409, "tensorboard_dependency_missing", "TensorBoard logging dependency is unavailable.", details={"missing": missing})
    if not any(device.id == request.device for device in available_devices().devices):
        raise ApiError(422, "device_unavailable", "Selected training device is unavailable.", details={"device": request.device})
    active = _active_run(project)
    if active is not None:
        raise ApiError(409, "active_run_exists", "Another training run is already active.", details={"run_id": active.id})


def _active_run(project: ProjectState, *, exclude_run_id: str | None = None) -> RunObject | None:
    for raw in project.runs:
        if raw.get("id") == exclude_run_id:
            continue
        if raw.get("state") in ACTIVE_RUN_STATES:
            return RunObject.model_validate(raw)
    return None


def _replace_run(project: ProjectState, run: RunObject) -> ProjectState:
    for index, raw in enumerate(project.runs):
        if raw.get("id") == run.id:
            project.runs[index] = run.model_dump()
            return project
    raise ApiError(404, "run_not_found", "Run was not found.", details={"run_id": run.id})


def _find_run(project: ProjectState, run_id: str) -> RunObject:
    for raw in project.runs:
        if raw.get("id") == run_id:
            return RunObject.model_validate(raw)
    raise ApiError(404, "run_not_found", "Run was not found.", details={"run_id": run_id})


def _find_dataset(project: ProjectState, dataset_id: str) -> DatasetObject:
    for raw in project.datasets:
        if raw.get("id") == dataset_id:
            return DatasetObject.model_validate(raw)
    raise ApiError(404, "dataset_not_found", "Dataset was not found.", details={"dataset_id": dataset_id})


def _find_model(project: ProjectState, model_id: str) -> ModelObject:
    for raw in project.models:
        if raw.get("id") == model_id:
            return ModelObject.model_validate(raw)
    raise ApiError(404, "model_not_found", "Model was not found.", details={"model_id": model_id})


def _resolve_run_folder(project_root: Path, run: RunObject) -> Path:
    folder = Path(run.folder)
    if folder.is_absolute():
        return folder.resolve()
    return (project_root / folder).resolve()


def _module_available(name: str) -> bool:
    try:
        return importlib.util.find_spec(name) is not None
    except (ModuleNotFoundError, ValueError):
        return False
