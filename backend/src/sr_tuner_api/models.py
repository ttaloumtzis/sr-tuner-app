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


class ModelObject(BaseModel):
    id: str = Field(default_factory=lambda: new_id("model"))
    name: str
    slug: str
    architecture: Literal["internal_residual_pixelshuffle"] = "internal_residual_pixelshuffle"
    scale: int
    num_features: int = Field(default=32, ge=8, le=256)
    num_blocks: int = Field(default=4, ge=1, le=64)
    optimizer: OptimizerConfig = Field(default_factory=OptimizerConfig)
    scheduler: SchedulerConfig = Field(default_factory=SchedulerConfig)
    loss_weights: LossWeights = Field(default_factory=LossWeights)
    status: Literal["untrained", "trained", "fine_tune_available"] = "untrained"
    metadata: dict[str, Any] = Field(default_factory=dict)
    created_at: str = Field(default_factory=utc_now_iso)
    updated_at: str = Field(default_factory=utc_now_iso)


class CreateModelRequest(BaseModel):
    name: str
    scale: int = 4
    num_features: int = 32
    num_blocks: int = 4
    optimizer: OptimizerConfig = Field(default_factory=OptimizerConfig)
    scheduler: SchedulerConfig = Field(default_factory=SchedulerConfig)
    loss_weights: LossWeights = Field(default_factory=LossWeights)


class UpdateModelRequest(BaseModel):
    name: str | None = None
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
        "scale": 4,
        "num_features": 32,
        "num_blocks": 4,
        "upsampler": "pixel_shuffle",
    }


def create_model(project_root, request: CreateModelRequest) -> tuple[ProjectState, ModelObject]:
    _validate_model_config(request.scale, request.loss_weights)
    project = open_project(project_root)
    model = ModelObject(
        name=request.name.strip(),
        slug=slugify(request.name),
        scale=request.scale,
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
    if request.optimizer is not None:
        model.optimizer = request.optimizer
    if request.scheduler is not None:
        model.scheduler = request.scheduler
    if request.loss_weights is not None:
        _validate_model_config(model.scale, request.loss_weights)
        model.loss_weights = request.loss_weights
    model.updated_at = utc_now_iso()
    for index, raw in enumerate(project.models):
        if raw.get("id") == model_id:
            project.models[index] = model.model_dump()
            break
    write_project(project)
    return project, _derive_status(project, model)


def check_dataset_model_compatibility(project_root, dataset_id: str, model_id: str) -> CompatibilityResponse:
    project = open_project(project_root)
    dataset = next((item for item in project.datasets if item.get("id") == dataset_id), None)
    model = _find_model(project, model_id)
    dataset_scale = dataset.get("validated_scale") or dataset.get("scale") if dataset else None
    if dataset is None:
        raise ApiError(404, "dataset_not_found", "Dataset was not found.", details={"dataset_id": dataset_id})
    compatible = dataset_scale == model.scale
    return CompatibilityResponse(
        compatible=compatible,
        dataset_scale=dataset_scale,
        model_scale=model.scale,
        message="Dataset and model scales are compatible."
        if compatible
        else f"Dataset scale x{dataset_scale} does not match model scale x{model.scale}.",
    )


def _find_model(project: ProjectState, model_id: str) -> ModelObject:
    for raw in project.models:
        if raw.get("id") == model_id:
            return ModelObject.model_validate(raw)
    raise ApiError(404, "model_not_found", "Model was not found.", details={"model_id": model_id})


def _validate_model_config(scale: int, losses: LossWeights) -> None:
    if scale not in SUPPORTED_INTERNAL_SCALES:
        raise ApiError(
            422,
            "unsupported_model_scale",
            "The internal residual pixel-shuffle model does not support the selected scale.",
            details={"scale": scale, "supported_scales": sorted(SUPPORTED_INTERNAL_SCALES)},
        )
    if losses.l1 <= 0 and losses.perceptual <= 0 and losses.adversarial <= 0:
        raise ApiError(
            422,
            "loss_weights_required",
            "At least one loss weight must be greater than zero.",
            details={"l1": losses.l1, "perceptual": losses.perceptual, "adversarial": losses.adversarial},
        )


def _derive_status(project: ProjectState, model: ModelObject) -> ModelObject:
    usable = []
    fine_tune = []
    for run in project.runs:
        if run.get("model_id") != model.id:
            continue
        for checkpoint in run.get("checkpoints", []):
            if checkpoint.get("usable") and checkpoint.get("scale") == model.scale:
                usable.append(checkpoint)
                if checkpoint.get("fine_tune_compatible", True):
                    fine_tune.append(checkpoint)
    model.status = "fine_tune_available" if fine_tune else "trained" if usable else "untrained"
    return model
