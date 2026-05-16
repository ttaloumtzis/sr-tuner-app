from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field

from .errors import ApiError
from .ids import new_id, slugify
from .jobs import utc_now_iso
from .project_store import open_project, write_project
from .schemas import ProjectState


SUPPORTED_INTERNAL_SCALES = {2, 3, 4, 8}


class OptimizerConfig(BaseModel):
    type: Literal["adam"] = "adam"
    lr: float = Field(default=2e-4, gt=0)
    beta1: float = 0.9
    beta2: float = 0.99


class SchedulerConfig(BaseModel):
    type: Literal["none", "cosine", "step"] = "cosine"
    warmup_epochs: int = Field(default=0, ge=0)
    decay_epochs: list[int] = Field(default_factory=list)
    decay_factor: float = Field(default=0.5, gt=0, le=1)


class LossWeights(BaseModel):
    l1: float = Field(default=1.0, ge=0)
    perceptual: float = Field(default=0.0, ge=0)
    adversarial: float = Field(default=0.0, ge=0)


class TrainHistoryEntry(BaseModel):
    session_id: str
    dataset_id: str
    dataset_name: str
    scale: int
    started_at: str
    completed_at: str
    epochs: int
    best_metrics: dict[str, float] = Field(default_factory=dict)
    checkpoints: list[dict[str, Any]] = Field(default_factory=list)
    best_checkpoint_id: str = ""
    fine_tuned_from_checkpoint_id: str = ""
    fine_tuned_from_core_weights_path: str = ""


class ModelObject(BaseModel):
    id: str = Field(default_factory=lambda: new_id("model"))
    name: str
    slug: str
    architecture: Literal["internal_residual_pixelshuffle"] = "internal_residual_pixelshuffle"
    scale: int | None = None
    num_features: int = Field(default=32, ge=8, le=256)
    num_blocks: int = Field(default=4, ge=1, le=64)
    optimizer: OptimizerConfig = Field(default_factory=OptimizerConfig)
    scheduler: SchedulerConfig = Field(default_factory=SchedulerConfig)
    loss_weights: LossWeights = Field(default_factory=LossWeights)
    status: Literal["untrained", "trained"] = "untrained"
    trained_core_weights_path: str | None = None
    train_history: list[TrainHistoryEntry] = Field(default_factory=list)
    original_model_id: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)
    created_at: str = Field(default_factory=utc_now_iso)
    updated_at: str = Field(default_factory=utc_now_iso)


class CreateModelRequest(BaseModel):
    name: str
    num_features: int = 32
    num_blocks: int = 4
    optimizer: OptimizerConfig = Field(default_factory=OptimizerConfig)
    scheduler: SchedulerConfig = Field(default_factory=SchedulerConfig)
    loss_weights: LossWeights = Field(default_factory=LossWeights)


class UpdateModelRequest(BaseModel):
    name: str | None = None
    num_features: int | None = None
    num_blocks: int | None = None
    optimizer: OptimizerConfig | None = None
    scheduler: SchedulerConfig | None = None
    loss_weights: LossWeights | None = None


class CompatibilityResponse(BaseModel):
    compatible: bool
    dataset_scale: int | None
    model_scale: int | None
    message: str


def default_model_config() -> dict[str, Any]:
    return {
        "architecture": "internal_residual_pixelshuffle",
        "supported_scales": sorted(SUPPORTED_INTERNAL_SCALES),
        "num_features": 32,
        "num_blocks": 4,
        "upsampler": "pixel_shuffle",
    }


def create_model(project_root, request: CreateModelRequest) -> tuple[ProjectState, ModelObject]:
    _validate_model_config(request.loss_weights)
    project = open_project(project_root)
    model = ModelObject(
        name=request.name.strip(),
        slug=slugify(request.name),
        num_features=request.num_features,
        num_blocks=request.num_blocks,
        optimizer=request.optimizer,
        scheduler=request.scheduler,
        loss_weights=request.loss_weights,
    )
    project.models.append(model.model_dump())
    write_project(project)
    return project, model


def list_models(project_root) -> list[ModelObject]:
    project = open_project(project_root)
    return [_derive_status(project, ModelObject.model_validate(raw)) for raw in project.models]


def get_model(project_root, model_id: str) -> ModelObject:
    project = open_project(project_root)
    return _derive_status(project, _find_model(project, model_id))


def update_model(project_root, model_id: str, request: UpdateModelRequest) -> tuple[ProjectState, ModelObject]:
    project = open_project(project_root)
    model = _find_model(project, model_id)
    if request.name is not None:
        model.name = request.name.strip()
        model.slug = slugify(request.name)
    if request.num_features is not None or request.num_blocks is not None:
        if model.trained_core_weights_path:
            raise ApiError(
                409, "core_params_locked",
                "Core architecture parameters cannot be changed after training. Create a new model instead.",
                details={"model_id": model_id},
            )
        if request.num_features is not None:
            model.num_features = request.num_features
        if request.num_blocks is not None:
            model.num_blocks = request.num_blocks
    if request.optimizer is not None:
        model.optimizer = request.optimizer
    if request.scheduler is not None:
        model.scheduler = request.scheduler
    if request.loss_weights is not None:
        _validate_model_config(request.loss_weights)
        model.loss_weights = request.loss_weights
    model.updated_at = utc_now_iso()
    for index, raw in enumerate(project.models):
        if raw.get("id") == model_id:
            project.models[index] = model.model_dump()
            break
    write_project(project)
    return project, _derive_status(project, model)


def delete_model(project_root, model_id: str) -> tuple[ProjectState, ModelObject]:
    project = open_project(project_root)
    model = _find_model(project, model_id)
    active = next(
        (
            raw
            for raw in project.runs
            if raw.get("model_id") == model_id
            and raw.get("state") in {"running", "pausing", "paused", "resuming", "stopping"}
        ),
        None,
    )
    if active is not None:
        raise ApiError(
            409,
            "model_in_active_run",
            "Model is used by an active run and cannot be deleted.",
            details={"model_id": model_id, "run_id": active.get("id")},
        )
    import shutil
    core_dir = project_root / "models" / model_id / "core_weights"
    if core_dir.exists():
        shutil.rmtree(core_dir)
    project.models = [raw for raw in project.models if raw.get("id") != model_id]
    write_project(project)
    return project, model


def check_dataset_model_compatibility(project_root, dataset_id: str, model_id: str) -> CompatibilityResponse:
    project = open_project(project_root)
    dataset = next((item for item in project.datasets if item.get("id") == dataset_id), None)
    if dataset is None:
        raise ApiError(404, "dataset_not_found", "Dataset was not found.", details={"dataset_id": dataset_id})
    _find_model(project, model_id)
    dataset_scale = dataset.get("validated_scale") or dataset.get("scale")
    return CompatibilityResponse(
        compatible=True,
        dataset_scale=dataset_scale,
        model_scale=None,
        message="Model is scale-agnostic. Scale is derived from dataset.",
    )


def _find_model(project: ProjectState, model_id: str) -> ModelObject:
    for raw in project.models:
        if raw.get("id") == model_id:
            return ModelObject.model_validate(raw)
    raise ApiError(404, "model_not_found", "Model was not found.", details={"model_id": model_id})


def _validate_model_config(losses: LossWeights) -> None:
    if losses.l1 <= 0 and losses.perceptual <= 0 and losses.adversarial <= 0:
        raise ApiError(
            422,
            "loss_weights_required",
            "At least one loss weight must be greater than zero.",
            details={"l1": losses.l1, "perceptual": losses.perceptual, "adversarial": losses.adversarial},
        )


def _derive_status(project: ProjectState, model: ModelObject) -> ModelObject:
    model.status = "trained" if model.trained_core_weights_path else "untrained"
    return model


def duplicate_model(project_root, source_model_id: str, new_name: str) -> ProjectState:
    import shutil
    project = open_project(project_root)
    source = _find_model(project, source_model_id)
    new_model = ModelObject(
        name=new_name.strip(),
        slug=slugify(new_name),
        architecture=source.architecture,
        num_features=source.num_features,
        num_blocks=source.num_blocks,
        optimizer=source.optimizer,
        scheduler=source.scheduler,
        loss_weights=source.loss_weights,
        original_model_id=source_model_id,
    )
    if source.trained_core_weights_path:
        source_core_dir = project_root / "models" / source_model_id / "core_weights"
        dest_core_dir = project_root / "models" / new_model.id / "core_weights"
        if source_core_dir.exists():
            dest_core_dir.mkdir(parents=True, exist_ok=True)
            for item in source_core_dir.iterdir():
                if item.is_file():
                    shutil.copy2(item, dest_core_dir / item.name)
            best_core = dest_core_dir / "best_core.pth"
            if best_core.exists():
                from .project_store import store_asset_path
                new_model.trained_core_weights_path = store_asset_path(project_root, best_core).stored
                new_model.status = "trained"
    project.models.append(new_model.model_dump())
    return write_project(project)
