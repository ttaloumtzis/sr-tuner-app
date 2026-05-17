from __future__ import annotations

import shutil
import subprocess
from pathlib import Path
from typing import Any, Callable, Literal

from pydantic import BaseModel, Field

from .errors import ApiError
from .ids import new_id, slugify
from .image_probe import ImageInfo, probe_image
from .jobs import Job, JobError, utc_now_iso
from .project_store import open_project, store_asset_path, write_project
from .schemas import ProjectState


SUPPORTED_IMAGE_EXTENSIONS = {"png", "jpg", "jpeg", "webp", "tif", "tiff"}
ValidationMode = Literal["quick", "full"]
StorageMode = Literal["external", "project"]
StorageOperation = Literal["reference", "copy", "move"]


class DatasetPaths(BaseModel):
    root: str
    hr: str
    lr: str
    mode: Literal["relative", "absolute"]


class DatasetValidation(BaseModel):
    usable: bool
    mode: ValidationMode
    pair_count: int = 0
    sampled_count: int = 0
    declared_scale: int
    validated_scale: int | None = None
    errors: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)
    unmatched_hr: list[str] = Field(default_factory=list)
    unmatched_lr: list[str] = Field(default_factory=list)
    format_counts: dict[str, int] = Field(default_factory=dict)
    min_hr_resolution: list[int] | None = None
    max_hr_resolution: list[int] | None = None
    consistent_aspect_ratio: bool | None = None
    black_pair_count: int = 0


class DatasetObject(BaseModel):
    id: str = Field(default_factory=lambda: new_id("dataset"))
    name: str
    slug: str
    type: Literal["paired", "video_generated"]
    scale: int
    declared_scale: int
    validated_scale: int | None = None
    storage_mode: StorageMode
    paths: DatasetPaths
    validation: DatasetValidation
    generation: dict[str, Any] = Field(default_factory=dict)
    metadata: dict[str, Any] = Field(default_factory=dict)
    created_at: str = Field(default_factory=utc_now_iso)
    updated_at: str = Field(default_factory=utc_now_iso)


class RegisterPairedDatasetRequest(BaseModel):
    name: str
    dataset_path: str
    scale: int = Field(ge=2, le=8)
    validation_mode: ValidationMode = "quick"
    storage_operation: StorageOperation = "reference"
    replace: bool = False


class DatasetStorageEstimateRequest(BaseModel):
    dataset_path: str
    name: str
    operation: Literal["copy", "move"]


class DatasetStorageEstimate(BaseModel):
    file_count: int
    total_bytes: int
    destination: str
    destination_exists: bool


class VideoGenerationConfig(BaseModel):
    name: str
    source_video: str
    scale: int = Field(ge=2, le=8)
    fps: float = Field(default=1.0, gt=0)
    output_format: Literal["png", "jpg"] = "png"
    downscale_method: str = "bicubic"
    pre_blur: float = Field(default=0.0, ge=0)
    blur: float = Field(default=0.0, ge=0)
    noise: float = Field(default=0.0, ge=0)
    jpeg_quality: int = Field(default=95, ge=1, le=100)
    frame_limit: int | None = Field(default=None, gt=0)


class ReSynthesisRequest(BaseModel):
    downscale_method: str | None = None
    pre_blur: float | None = None
    blur: float | None = None
    noise: float | None = None
    jpeg_quality: int | None = None
    output_format: Literal["png", "jpg"] | None = None


class ReadinessResponse(BaseModel):
    available: bool
    tool: str
    message: str


def _project_dataset_folder(project_root: Path, dataset_name: str) -> Path:
    return project_root / "datasets" / slugify(dataset_name)


def _supported_files(folder: Path) -> dict[str, Path]:
    files: dict[str, Path] = {}
    for path in folder.iterdir():
        if path.name.startswith(".") or not path.is_file():
            continue
        if path.suffix.lower().lstrip(".") in SUPPORTED_IMAGE_EXTENSIONS:
            files[path.stem] = path
    return files


def _is_black_image(path: Path) -> int:
    try:
        from PIL import Image  # noqa: PLC0415

        with Image.open(path) as img:
            thumb = img.convert("L").resize((32, 32))
            mean = sum(thumb.getdata()) / (32 * 32)
            return 1 if mean < 8 else 0
    except Exception:
        return 0


def validate_paired_dataset(dataset_root: Path, scale: int, mode: ValidationMode) -> DatasetValidation:
    hr = dataset_root / "HR"
    lr = dataset_root / "LR"
    errors: list[str] = []
    warnings: list[str] = []
    if not hr.is_dir():
        errors.append("Missing HR folder.")
    if not lr.is_dir():
        errors.append("Missing LR folder.")
    if errors:
        return DatasetValidation(usable=False, mode=mode, declared_scale=scale, errors=errors)

    hr_files = _supported_files(hr)
    lr_files = _supported_files(lr)
    stems = sorted(set(hr_files) & set(lr_files))
    unmatched_hr = sorted(set(hr_files) - set(lr_files))
    unmatched_lr = sorted(set(lr_files) - set(hr_files))
    if not stems:
        errors.append("No matched HR/LR image pairs were found.")
    if unmatched_hr:
        errors.append("Some HR images do not have matching LR files.")
    if unmatched_lr:
        errors.append("Some LR images do not have matching HR files.")

    format_counts: dict[str, int] = {}
    for path in hr_files.values():
        ext = path.suffix.lower().lstrip(".")
        format_counts[ext] = format_counts.get(ext, 0) + 1

    widths: list[int] = []
    heights: list[int] = []
    aspect_ratios: list[float] = []
    black_pair_count = 0

    sample_stems = stems if mode == "full" else stems[: min(16, len(stems))]
    for index, stem in enumerate(sample_stems):
        try:
            hr_info = probe_image(hr_files[stem])
            lr_info = probe_image(lr_files[stem])
            _validate_image_policy(hr_info, hr_files[stem], warnings, errors)
            _validate_image_policy(lr_info, lr_files[stem], warnings, errors)
            if hr_info.width != lr_info.width * scale or hr_info.height != lr_info.height * scale:
                errors.append(
                    f"Scale mismatch for {stem}: HR {hr_info.width}x{hr_info.height}, "
                    f"LR {lr_info.width}x{lr_info.height}, declared x{scale}."
                )
            widths.append(hr_info.width)
            heights.append(hr_info.height)
            if hr_info.height > 0:
                aspect_ratios.append(hr_info.width / hr_info.height)
            if mode == "full" or index % 4 == 0:
                black_pair_count += _is_black_image(hr_files[stem])
        except Exception as exc:
            errors.append(f"{stem}: {exc}")

    min_hr_resolution = [min(widths), min(heights)] if widths else None
    max_hr_resolution = [max(widths), max(heights)] if widths else None
    consistent_aspect_ratio: bool | None = None
    if len(aspect_ratios) > 1:
        base = aspect_ratios[0]
        consistent_aspect_ratio = base > 0 and all(abs(r - base) / base < 0.01 for r in aspect_ratios)
    elif len(aspect_ratios) == 1:
        consistent_aspect_ratio = True

    return DatasetValidation(
        usable=not errors,
        mode=mode,
        pair_count=len(stems),
        sampled_count=len(sample_stems),
        declared_scale=scale,
        validated_scale=scale if not errors else None,
        errors=errors,
        warnings=warnings,
        unmatched_hr=[hr_files[stem].name for stem in unmatched_hr],
        unmatched_lr=[lr_files[stem].name for stem in unmatched_lr],
        format_counts=format_counts,
        min_hr_resolution=min_hr_resolution,
        max_hr_resolution=max_hr_resolution,
        consistent_aspect_ratio=consistent_aspect_ratio,
        black_pair_count=black_pair_count,
    )


def delete_dataset(project_root: Path, dataset_id: str) -> tuple[ProjectState, DatasetObject]:
    project = open_project(project_root)
    dataset: DatasetObject | None = None
    for raw in project.datasets:
        if raw.get("id") == dataset_id:
            dataset = DatasetObject.model_validate(raw)
            break
    if dataset is None:
        raise ApiError(404, "dataset_not_found", "Dataset was not found.", details={"dataset_id": dataset_id})
    active = next(
        (
            raw
            for raw in project.runs
            if raw.get("dataset_id") == dataset_id
            and raw.get("state") in {"running", "pausing", "paused", "resuming", "stopping"}
        ),
        None,
    )
    if active is not None:
        raise ApiError(
            409,
            "dataset_in_active_run",
            "Dataset is used by an active run and cannot be deleted.",
            details={"dataset_id": dataset_id, "run_id": active.get("id")},
        )
    project.datasets = [raw for raw in project.datasets if raw.get("id") != dataset_id]
    if dataset.storage_mode == "project":
        folder = _resolve_dataset_folder(project_root, dataset)
        project_datasets = (project_root / "datasets").resolve()
        if folder.exists() and folder.resolve().is_relative_to(project_datasets):
            shutil.rmtree(folder)
    return write_project(project), dataset


def _resolve_dataset_folder(project_root: Path, dataset: DatasetObject) -> Path:
    root = Path(dataset.paths.root)
    if dataset.paths.mode == "relative":
        return project_root / root
    return root


def _validate_image_policy(info: ImageInfo, path: Path, warnings: list[str], errors: list[str]) -> None:
    if info.mode == "RGB" and info.bit_depth in {8, None}:
        return
    if info.mode == "L" and info.bit_depth in {8, None}:
        warnings.append(f"{path.name} is grayscale and will be converted to RGB for training.")
        return
    errors.append(f"{path.name} has unsupported mode or bit depth: {info.mode} {info.bit_depth}.")


def register_paired_dataset(project_root: Path, request: RegisterPairedDatasetRequest) -> tuple[ProjectState, DatasetObject, Job | None]:
    source_root = Path(request.dataset_path).expanduser().resolve()
    if not source_root.is_dir():
        raise ApiError(404, "dataset_path_missing", "Dataset folder was not found.", details={"path": str(source_root)})
    target_root = source_root
    storage_mode: StorageMode = "external"
    job: Job | None = None
    if request.storage_operation in {"copy", "move"}:
        target_root = _project_dataset_folder(project_root, request.name)
        job = _copy_or_move_dataset(source_root, target_root, request.storage_operation, request.replace)
        storage_mode = "project"

    validation = validate_paired_dataset(target_root, request.scale, request.validation_mode)
    path_info = store_asset_path(project_root, target_root)
    dataset = DatasetObject(
        name=request.name.strip(),
        slug=slugify(request.name),
        type="paired",
        scale=request.scale,
        declared_scale=request.scale,
        validated_scale=validation.validated_scale,
        storage_mode=storage_mode,
        paths=DatasetPaths(
            root=path_info.stored,
            hr=(Path(path_info.stored) / "HR").as_posix() if path_info.mode == "relative" else str(target_root / "HR"),
            lr=(Path(path_info.stored) / "LR").as_posix() if path_info.mode == "relative" else str(target_root / "LR"),
            mode=path_info.mode,
        ),
        validation=validation,
        metadata={"source_path": str(source_root), "storage_operation": request.storage_operation},
    )
    project = open_project(project_root)
    project.datasets.append(dataset.model_dump())
    write_project(project)
    return project, dataset, job


def estimate_storage(project_root: Path, request: DatasetStorageEstimateRequest) -> DatasetStorageEstimate:
    source = Path(request.dataset_path).expanduser().resolve()
    if not source.is_dir():
        raise ApiError(404, "dataset_path_missing", "Dataset folder was not found.", details={"path": str(source)})
    file_count = 0
    total_bytes = 0
    for path in source.rglob("*"):
        if path.is_file():
            file_count += 1
            total_bytes += path.stat().st_size
    destination = _project_dataset_folder(project_root, request.name)
    return DatasetStorageEstimate(
        file_count=file_count,
        total_bytes=total_bytes,
        destination=str(destination),
        destination_exists=destination.exists(),
    )


def _copy_or_move_dataset(source: Path, target: Path, operation: Literal["copy", "move"], replace: bool) -> Job:
    if target.exists() and not replace:
        raise ApiError(409, "dataset_destination_exists", "Dataset destination already exists.", details={"path": str(target)})
    staging = target.parent / f".staging-{target.name}"
    if staging.exists():
        shutil.rmtree(staging)
    if target.exists():
        shutil.rmtree(target)
    staging.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, staging)
    staging.replace(target)
    if operation == "move":
        shutil.rmtree(source)
    return Job(
        type=f"dataset_{operation}",
        status="completed",
        progress=1.0,
        started_at=utc_now_iso(),
        finished_at=utc_now_iso(),
        logs=[f"{operation.title()} completed: {source} -> {target}"],
        retained_partial_artifacts=False,
    )


def resynthesize_dataset(
    project_root: Path,
    dataset_id: str,
    request: ReSynthesisRequest,
    *,
    job: Job | None = None,
    on_job: Callable[[Job], None] | None = None,
) -> tuple[ProjectState, DatasetObject, Job]:
    project = open_project(project_root)
    dataset: DatasetObject | None = None
    for raw in project.datasets:
        if raw.get("id") == dataset_id:
            dataset = DatasetObject.model_validate(raw)
            break
    if dataset is None:
        raise ApiError(404, "dataset_not_found", "Dataset was not found.", details={"dataset_id": dataset_id})
    if dataset.type != "video_generated":
        raise ApiError(422, "not_video_generated", "Re-synthesis is only available for video-generated datasets.")
    stored_gen = dataset.generation or {}
    if not stored_gen.get("source_video"):
        raise ApiError(422, "source_video_missing", "No source video path stored on this dataset.")
    source = Path(stored_gen["source_video"]).expanduser().resolve()
    if not source.is_file():
        raise ApiError(422, "source_video_missing", "Source video file was not found.", details={"path": str(source)})
    active = next(
        (
            raw
            for raw in project.runs
            if raw.get("dataset_id") == dataset_id
            and raw.get("state") in {"running", "pausing", "paused", "resuming", "stopping"}
        ),
        None,
    )
    if active is not None:
        raise ApiError(409, "dataset_in_active_run", "Dataset is used by an active run.", details={"run_id": active.get("id")})

    overrides = {k: v for k, v in request.model_dump().items() if v is not None}
    merged = {**stored_gen, **overrides}
    config = VideoGenerationConfig.model_validate(merged)

    readiness = video_readiness()
    if not readiness.available:
        raise ApiError(409, "video_dependency_missing", readiness.message, details={"tool": readiness.tool})

    target = _resolve_dataset_folder(project_root, dataset)
    lr_folder = target / "LR"
    for f in lr_folder.iterdir():
        if f.is_file():
            f.unlink()

    total_seconds = _video_progress_seconds(source, config)
    active_job = job or Job(
        type="dataset_resynthesis",
        project_id=project.id,
        object_id=dataset_id,
        status="running",
        progress=0.02,
        started_at=utc_now_iso(),
        logs=[f"Re-synthesizing LR frames for dataset {dataset.name}."],
    )
    _publish_job(active_job, on_job)

    lr_filters = []
    if config.pre_blur > 0:
        lr_filters.append(f"gblur=sigma={config.pre_blur}")
    lr_filters.append(f"scale=trunc(iw/{config.scale}):trunc(ih/{config.scale}):flags={config.downscale_method}")
    if config.blur > 0:
        lr_filters.append(f"gblur=sigma={config.blur}")
    if config.noise > 0:
        lr_filters.append(f"noise=alls={config.noise}:allf=t")
    lr_cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-nostats",
        "-i",
        str(source),
        "-vf",
        f"fps={config.fps}," + ",".join(lr_filters),
    ]
    if config.frame_limit is not None:
        lr_cmd.extend(["-frames:v", str(config.frame_limit)])
    if config.output_format == "jpg":
        ffmpeg_quality = max(2, min(31, round((100 - config.jpeg_quality) / 3.2) + 2))
        lr_cmd.extend(["-q:v", str(ffmpeg_quality)])
    lr_cmd.extend(["-progress", "pipe:1"])
    lr_cmd.append(str(lr_folder / f"frame_%06d.{config.output_format}"))

    active_job.logs = [*active_job.logs[-49:], "Generating LR frames."]
    _publish_job(active_job, on_job)
    lr_code, lr_stderr = _run_ffmpeg_progress(
        lr_cmd,
        total_seconds=total_seconds,
        job=active_job,
        on_job=on_job,
        start=0.1,
        end=0.85,
    )
    if lr_code != 0:
        raise ApiError(500, "video_lr_generation_failed", "ffmpeg failed to regenerate LR frames.", details={"stderr": lr_stderr[-2000:]})

    active_job.progress = 0.9
    active_job.logs = [*active_job.logs[-49:], "Validating regenerated pairs."]
    _publish_job(active_job, on_job)

    validation = validate_paired_dataset(target, config.scale, "full")
    project = open_project(project_root)
    updated_dataset: DatasetObject | None = None
    for raw in project.datasets:
        if raw.get("id") == dataset_id:
            raw["generation"] = config.model_dump()
            raw["validation"] = validation.model_dump()
            raw["updated_at"] = utc_now_iso()
            updated_dataset = DatasetObject.model_validate(raw)
            break
    write_project(project)

    active_job.status = "completed"
    active_job.progress = 1.0
    active_job.finished_at = utc_now_iso()
    active_job.logs = [*active_job.logs[-49:], "Re-synthesis complete."]
    _publish_job(active_job, on_job)
    return project, updated_dataset or dataset, active_job


def video_readiness() -> ReadinessResponse:
    available = shutil.which("ffmpeg") is not None
    return ReadinessResponse(
        available=available,
        tool="ffmpeg",
        message="ffmpeg is available." if available else "ffmpeg was not found on PATH.",
    )


def generate_video_dataset(
    project_root: Path,
    request: VideoGenerationConfig,
    *,
    job: Job | None = None,
    on_job: Callable[[Job], None] | None = None,
) -> tuple[ProjectState, DatasetObject, Job]:
    source = Path(request.source_video).expanduser().resolve()
    if not source.is_file():
        raise ApiError(404, "video_missing", "Source video was not found.", details={"path": str(source)})
    readiness = video_readiness()
    if not readiness.available:
        raise ApiError(409, "video_dependency_missing", readiness.message, details={"tool": readiness.tool})

    target = _project_dataset_folder(project_root, request.name)
    if target.exists():
        raise ApiError(409, "dataset_destination_exists", "Dataset destination already exists.", details={"path": str(target)})
    (target / "HR").mkdir(parents=True)
    (target / "LR").mkdir(parents=True)
    total_seconds = _video_progress_seconds(source, request)
    active_job = job or Job(
        type="video_dataset_generation",
        project_id=open_project(project_root).id,
        status="running",
        progress=0.02,
        started_at=utc_now_iso(),
        logs=[f"Generating dataset {request.name} from {source}."],
    )
    _publish_job(active_job, on_job)
    hr_cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-nostats",
        "-i",
        str(source),
        "-vf",
        f"fps={request.fps}",
    ]
    if request.frame_limit is not None:
        hr_cmd.extend(["-frames:v", str(request.frame_limit)])
    hr_cmd.extend(["-progress", "pipe:1"])
    hr_cmd.append(str(target / "HR" / f"frame_%06d.{request.output_format}"))
    active_job.logs = [*active_job.logs[-49:], "Extracting HR frames."]
    _publish_job(active_job, on_job)
    hr_code, hr_stderr = _run_ffmpeg_progress(
        hr_cmd,
        total_seconds=total_seconds,
        job=active_job,
        on_job=on_job,
        start=0.05,
        end=0.45,
    )
    if hr_code != 0:
        shutil.rmtree(target, ignore_errors=True)
        raise ApiError(
            500,
            "video_extraction_failed",
            "ffmpeg failed to extract video frames.",
            details={"stderr": hr_stderr[-2000:]},
        )
    lr_filters = [f"fps={request.fps}"]
    if request.pre_blur > 0:
        lr_filters.append(f"gblur=sigma={request.pre_blur}")
    lr_filters.append(f"scale=trunc(iw/{request.scale}):trunc(ih/{request.scale}):flags={request.downscale_method}")
    if request.blur > 0:
        lr_filters.append(f"gblur=sigma={request.blur}")
    if request.noise > 0:
        lr_filters.append(f"noise=alls={request.noise}:allf=t")
    lr_cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-nostats",
        "-i",
        str(source),
        "-vf",
        ",".join(lr_filters),
    ]
    if request.frame_limit is not None:
        lr_cmd.extend(["-frames:v", str(request.frame_limit)])
    if request.output_format == "jpg":
        ffmpeg_quality = max(2, min(31, round((100 - request.jpeg_quality) / 3.2) + 2))
        lr_cmd.extend(["-q:v", str(ffmpeg_quality)])
    lr_cmd.extend(["-progress", "pipe:1"])
    lr_cmd.append(str(target / "LR" / f"frame_%06d.{request.output_format}"))
    active_job.logs = [*active_job.logs[-49:], "Generating LR frames."]
    _publish_job(active_job, on_job)
    lr_code, lr_stderr = _run_ffmpeg_progress(
        lr_cmd,
        total_seconds=total_seconds,
        job=active_job,
        on_job=on_job,
        start=0.45,
        end=0.9,
    )
    if lr_code != 0:
        shutil.rmtree(target, ignore_errors=True)
        raise ApiError(
            500,
            "video_lr_generation_failed",
            "ffmpeg failed to generate LR frames.",
            details={"stderr": lr_stderr[-2000:]},
        )
    active_job.progress = 0.95
    active_job.logs = [*active_job.logs[-49:], "Validating generated pairs."]
    _publish_job(active_job, on_job)
    validation = validate_paired_dataset(target, request.scale, "full")
    path_info = store_asset_path(project_root, target)
    dataset = DatasetObject(
        name=request.name,
        slug=slugify(request.name),
        type="video_generated",
        scale=request.scale,
        declared_scale=request.scale,
        validated_scale=None,
        storage_mode="project",
        paths=DatasetPaths(
            root=path_info.stored,
            hr=(Path(path_info.stored) / "HR").as_posix(),
            lr=(Path(path_info.stored) / "LR").as_posix(),
            mode=path_info.mode,
        ),
        validation=validation,
        generation=request.model_dump(),
    )
    project = open_project(project_root)
    project.datasets.append(dataset.model_dump())
    write_project(project)
    active_job.project_id = project.id
    active_job.object_id = dataset.id
    active_job.status = "completed"
    active_job.progress = 1.0
    active_job.finished_at = utc_now_iso()
    active_job.logs = [*active_job.logs[-49:], f"Generated paired HR/LR frames from {source}."]
    _publish_job(active_job, on_job)
    return project, dataset, active_job


def _video_progress_seconds(source: Path, request: VideoGenerationConfig) -> float | None:
    if request.frame_limit is not None:
        return request.frame_limit / request.fps
    try:
        completed = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                str(source),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if completed.returncode == 0:
            duration = float(completed.stdout.strip())
            return duration if duration > 0 else None
    except Exception:
        return None
    return None


def _run_ffmpeg_progress(
    cmd: list[str],
    *,
    total_seconds: float | None,
    job: Job,
    on_job: Callable[[Job], None] | None,
    start: float,
    end: float,
) -> tuple[int, str]:
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    assert process.stdout is not None
    current: dict[str, str] = {}
    for line in process.stdout:
        key, _, value = line.strip().partition("=")
        if not key:
            continue
        current[key] = value
        if key == "progress":
            out_time = _progress_seconds(current)
            if total_seconds and out_time is not None:
                phase = max(0.0, min(1.0, out_time / total_seconds))
                job.progress = start + (end - start) * phase
                _publish_job(job, on_job)
            current = {}
    stderr = process.stderr.read() if process.stderr is not None else ""
    return process.wait(), stderr


def _progress_seconds(values: dict[str, str]) -> float | None:
    raw_ms = values.get("out_time_ms")
    if raw_ms:
        try:
            return float(raw_ms) / 1_000_000
        except ValueError:
            return None
    return None


def _publish_job(job: Job, on_job: Callable[[Job], None] | None) -> None:
    if on_job is not None:
        on_job(job)
