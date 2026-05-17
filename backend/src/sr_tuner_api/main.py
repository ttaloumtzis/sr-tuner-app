from __future__ import annotations

import ctypes
import os
import signal
import time
from pathlib import Path
from threading import Thread

from fastapi import BackgroundTasks, Depends, FastAPI, UploadFile
from fastapi.exceptions import RequestValidationError
from fastapi.responses import FileResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from . import __version__
from .diagnostic_logger import DiagnosticLogger, create_component_logger
from .logging_middleware import RequestLoggingMiddleware
from . import logging_schema as log_schema
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
    extract_and_save_core_weights,
    list_run_checkpoints,
    onnx_readiness,
    save_checkpoint,
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
    forget_all_recent_projects,
    forget_recent_project,
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
    ReSynthesisRequest,
    ReadinessResponse,
    RegisterPairedDatasetRequest,
    VideoGenerationConfig,
    delete_dataset,
    estimate_storage,
    generate_video_dataset,
    register_paired_dataset,
    resynthesize_dataset,
    video_readiness,
)
from .ids import slugify
from .errors import ApiError, api_error_handler, http_error_handler, validation_error_handler
from .jobs import CreateJobRequest, Job, JobError, JobLogResponse, job_store, utc_now_iso
from .metrics import (
    ActiveRunStatus,
    HardwareTelemetry,
    MetricRecord,
    MetricsResponse,
    PreviewResponse,
    active_run_status,
    hardware_telemetry_for_project,
    initialize_run_metrics,
    latest_preview,
    preview_asset_path,
    read_metrics,
    generate_validation_preview_from_tensors,
    set_live_status,
    write_metric_record,
)
from .models import (
    CompatibilityResponse,
    CreateModelRequest,
    LossWeights,
    ModelObject,
    OptimizerConfig,
    SchedulerConfig,
    TrainHistoryEntry,
    UpdateModelRequest,
    check_dataset_model_compatibility,
    create_model,
    default_model_config,
    delete_model,
    duplicate_model,
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
    build_internal_sr_model,
    build_paired_sr_dataset,
    delete_run_config,
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
app.add_middleware(RequestLoggingMiddleware)
app.add_exception_handler(ApiError, api_error_handler)
app.add_exception_handler(StarletteHTTPException, http_error_handler)
app.add_exception_handler(RequestValidationError, validation_error_handler)

_log = create_component_logger(log_schema.COMPONENT_BACKEND)

_project_sessions: dict[str, Path] = {}


def _terminate_process() -> None:
    os.kill(os.getpid(), signal.SIGTERM)


def _parent_process_alive(parent_pid: int) -> bool:
    try:
        os.kill(parent_pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def _watch_parent_process(parent_pid: int) -> None:
    while True:
        if not _parent_process_alive(parent_pid):
            _log.warn(log_schema.EventNames.PARENT_WATCHDOG, "Parent process died, terminating backend.", context={"parent_pid": parent_pid})
            _terminate_process()
            return
        time.sleep(0.2)


def _start_parent_watchdog() -> None:
    raw_parent_pid = os.environ.get("SR_TUNER_PARENT_PID", "").strip()
    if not raw_parent_pid:
        return
    try:
        parent_pid = int(raw_parent_pid)
    except ValueError:
        return
    Thread(target=_watch_parent_process, args=(parent_pid,), daemon=True).start()


_start_parent_watchdog()
_log.info(log_schema.EventNames.BACKEND_START, f"{APP_NAME} v{__version__} started.", context={"app": APP_NAME, "version": __version__})


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


_training_threads: dict[str, Thread] = {}


def _start_training_worker(project_root: Path, run_id: str, job_id: str) -> None:
    t = Thread(target=_training_worker, args=(project_root, run_id, job_id), daemon=True)
    t.start()
    _training_threads[job_id] = t


def _interrupt_training_thread(job_id: str) -> None:
    thread = _training_threads.pop(job_id, None)
    if thread is None or not thread.is_alive():
        return
    tid = thread.ident
    if tid is None:
        return
    ctypes.pythonapi.PyThreadState_SetAsyncExc(
        ctypes.c_ulong(tid),
        ctypes.py_object(SystemExit),
    )


def _training_worker(project_root: Path, run_id: str, job_id: str) -> None:
    try:
        _training_worker_impl(project_root, run_id, job_id)
    except (SystemExit, Exception):
        _set_run_state(project_root, run_id, "failed")
    finally:
        _training_threads.pop(job_id, None)


def _training_worker_impl(project_root: Path, run_id: str, job_id: str) -> None:
    import math

    import torch

    try:
        project = open_project(project_root)
        run = get_run(project_root, run_id)
        raw_run = next((raw for raw in project.runs if raw.get("id") == run_id), None)
        dataset_raw = next((raw for raw in project.datasets if raw.get("id") == run.dataset_id), None)
        model_raw = next((raw for raw in project.models if raw.get("id") == run.model_id), None)
        if raw_run is None or dataset_raw is None or model_raw is None:
            job = job_store.get(job_id)
            job.status = "failed"
            job.finished_at = utc_now_iso()
            job.error = JobError(code="training_context_missing", message="Training context was not found.")
            job_store.put(job)
            _set_run_state(project_root, run_id, "failed")
            return

        dataset = DatasetObject.model_validate(dataset_raw)
        model = ModelObject.model_validate(model_raw)
        dataset_scale = run.metadata.get("dataset_scale") or dataset.validated_scale or dataset.scale

        train_dataset = build_paired_sr_dataset(project_root, dataset, indexes=run.train_indexes or None)
        if len(train_dataset) == 0:
            train_dataset = build_paired_sr_dataset(project_root, dataset)
        validation_dataset = build_paired_sr_dataset(project_root, dataset, indexes=run.validation_indexes or None)
        if len(validation_dataset) == 0:
            validation_dataset = train_dataset

        device = torch.device(run.settings.device)
        model_impl = build_internal_sr_model(
            scale=dataset_scale,
            num_features=model.num_features,
            num_blocks=model.num_blocks,
        ).to(device)

        core_source = run.settings.source_core_weights_path
        if core_source is None and model.trained_core_weights_path and model.status == "trained":
            core_source = model.trained_core_weights_path
        if core_source is None and run.lineage.fine_tune_source_checkpoint_id:
            ckpt_id = run.lineage.fine_tune_source_checkpoint_id
            for raw in project.runs:
                for c in raw.get("checkpoints", []):
                    if c.get("id") == ckpt_id:
                        ckpt_run_id = raw.get("id")
                        core_source = f"models/{run.model_id}/core_weights/{ckpt_run_id}_core.pth"
                        break
        if core_source:
            core_path = Path(core_source)
            if not core_path.is_absolute():
                core_path = project_root / core_path
            if core_path.exists():
                core_state = torch.load(core_path, map_location="cpu", weights_only=False)
                # Core weights are saved with 'body.' prefix (from extract_core_weights).
                # Since we load into model_impl.body, strip that prefix.
                adjusted = {k.removeprefix("body."): v for k, v in core_state.items()}
                model_impl.body.load_state_dict(adjusted, strict=False)

        lr = run.settings.learning_rate if run.settings.learning_rate is not None else model.optimizer.lr
        optimizer = torch.optim.Adam(model_impl.parameters(), lr=lr)
        use_amp = run.settings.precision == "mixed" and device.type in ("cuda", "rocm")
        if use_amp:
            scaler = torch.amp.GradScaler()
        else:
            scaler = None
        scheduler = _build_scheduler(optimizer, run.settings.scheduler.type, run.settings.epochs)

        started_at = time.monotonic()
        batch_size = max(run.settings.batch_size, 1)
        iterations_per_epoch = math.ceil(max(len(train_dataset), 1) / batch_size)
        validation_iterations = math.ceil(max(len(validation_dataset), 1) / batch_size)
        validation_epochs_total = (
            run.settings.epochs // max(run.settings.validation_split.every_epochs, 1)
            if run.settings.validation_split.enabled and validation_iterations
            else 0
        )
        total_iterations = iterations_per_epoch * run.settings.epochs + validation_iterations * validation_epochs_total
        job = job_store.get(job_id)
        set_live_status(
            project_root,
            run.id,
            epoch=1,
            iteration=0,
            progress=0.0,
            phase="training",
            latest_metrics={
                "learning_rate": float(optimizer.param_groups[0]["lr"]),
                "progress": 0.0,
                "epoch_progress": 0.0,
                "epoch_iteration": 0.0,
                "epoch_total_iterations": float(iterations_per_epoch),
                "total_iterations": float(total_iterations),
            },
        )
        for epoch in range(1, run.settings.epochs + 1):
            job = job_store.get(job_id)
            if job.status in {"canceling", "canceled"} or job.cancel_requested:
                _finalize_training_cancel(project_root, run_id, job)
                return

            model_impl.train()
            epoch_loss = 0.0
            component_totals = {"l1": 0.0, "perceptual": 0.0, "adversarial": 0.0}
            train_count = 0
            epoch_started = time.monotonic()
            for index in range(0, len(train_dataset), batch_size):
                job = job_store.get(job_id)
                if job.status in {"canceling", "canceled"} or job.cancel_requested:
                    _finalize_training_cancel(project_root, run_id, job)
                    return

                samples = [train_dataset[item] for item in range(index, min(index + batch_size, len(train_dataset)))]
                lr_image = torch.stack([sample["lr"] for sample in samples]).to(device)
                hr_image = torch.stack([sample["hr"] for sample in samples]).to(device)

                optimizer.zero_grad(set_to_none=True)
                if use_amp:
                    with torch.amp.autocast(device_type=device.type):
                        prediction = model_impl(lr_image)
                        loss, components = _combined_training_loss(prediction, hr_image, run.settings.loss_weights)
                    scaler.scale(loss).backward()
                    scaler.step(optimizer)
                    scaler.update()
                else:
                    prediction = model_impl(lr_image)
                    loss, components = _combined_training_loss(prediction, hr_image, run.settings.loss_weights)
                    loss.backward()
                    optimizer.step()

                epoch_loss += float(loss.item())
                for key, value in components.items():
                    component_totals[key] = component_totals.get(key, 0.0) + value
                train_count += 1
                elapsed = max(time.monotonic() - epoch_started, 1e-6)
                average_loss = epoch_loss / max(train_count, 1)
                average_psnr = 10.0 * math.log10(1.0 / max(average_loss * average_loss, 1e-8))
                average_ssim = max(0.0, min(1.0, 1.0 - average_loss * 0.5))
                global_iteration = (epoch - 1) * iterations_per_epoch + train_count
                run_progress = min(1.0, global_iteration / max(total_iterations, 1))
                epoch_progress = min(1.0, train_count / max(iterations_per_epoch, 1))
                live_metrics = {
                    "train_loss_total": average_loss,
                    "val_psnr": average_psnr,
                    "val_ssim": average_ssim,
                    "learning_rate": float(optimizer.param_groups[0]["lr"]),
                    "progress": run_progress,
                    "epoch_progress": epoch_progress,
                    "epoch_iteration": float(train_count),
                    "epoch_total_iterations": float(iterations_per_epoch),
                    "total_iterations": float(total_iterations),
                    "iterations_per_second": train_count / elapsed,
                }
                set_live_status(
                    project_root,
                    run.id,
                    epoch=epoch,
                    iteration=global_iteration,
                    progress=run_progress,
                    phase="training",
                    latest_metrics=live_metrics,
                )
                job.status = "running"
                job.progress = run_progress
                job.started_at = job.started_at or utc_now_iso()
                job_store.put(job)

            if scheduler is not None:
                scheduler.step()

            train_loss = epoch_loss / max(train_count, 1)
            train_components = {key: value / max(train_count, 1) for key, value in component_totals.items()}
            should_validate = run.settings.validation_split.enabled and epoch % max(run.settings.validation_split.every_epochs, 1) == 0
            preview_dataset = validation_dataset if run.settings.validation_split.enabled else train_dataset
            val_loss, val_psnr, val_ssim = (
                _evaluate_training_pass(
                    model_impl,
                    validation_dataset,
                    device,
                    batch_size=batch_size,
                    progress_callback=lambda vc, vt: set_live_status(
                        project_root,
                        run.id,
                        epoch=epoch,
                        iteration=epoch * max(train_count, 1) + vc,
                        progress=min(1.0, (epoch * max(train_count, 1) + vc) / max(total_iterations, 1)),
                        phase="validation",
                        latest_metrics={
                            "train_loss_total": train_loss,
                            "learning_rate": float(optimizer.param_groups[0]["lr"]),
                            "progress": min(1.0, (epoch * max(train_count, 1) + vc) / max(total_iterations, 1)),
                            "epoch_progress": vc / max(vt, 1),
                            "epoch_iteration": float(vc),
                            "epoch_total_iterations": float(vt),
                            "total_iterations": float(total_iterations),
                        },
                    ),
                )
                if should_validate
                else (train_loss, 0.0, 0.0)
            )
            if should_validate or not run.settings.validation_split.enabled:
                preview = _generate_training_preview(project_root, run, model_impl, preview_dataset, device)
                run.metadata["latest_preview"] = preview.model_dump()
                _persist_run_metadata(project_root, run)
            elapsed_epoch = max(time.monotonic() - epoch_started, 1e-6)
            iterations_per_second = train_count / elapsed_epoch
            progress = epoch / max(run.settings.epochs, 1)

            job.status = "running"
            job.progress = progress
            job.started_at = job.started_at or utc_now_iso()
            job.logs = [*job.logs[-49:], f"Epoch {epoch}/{run.settings.epochs} complete."]
            job_store.put(job)

            metric_values = {
                "train_loss_total": train_loss,
                "learning_rate": float(optimizer.param_groups[0]["lr"]),
                "progress": progress,
                "epoch_progress": 1.0,
                "epoch_iteration": float(validation_iterations if should_validate else train_count),
                "epoch_total_iterations": float(validation_iterations if should_validate else iterations_per_epoch),
                "total_iterations": float(total_iterations),
                "iterations_per_second": iterations_per_second,
            }
            if should_validate:
                metric_values["val_psnr"] = val_psnr
                metric_values["val_ssim"] = val_ssim
            write_metric_record(
                project_root,
                run,
                MetricRecord(
                    step=epoch,
                    epoch=epoch,
                    iteration=epoch * max(train_count, 1),
                    values=metric_values,
                    components={**train_components, "val_loss": val_loss},
                ),
            )

            if epoch % max(run.settings.checkpoint_cadence, 1) == 0 or epoch == run.settings.epochs:
                save_checkpoint(
                    project_root,
                    run_raw=raw_run,
                    epoch=epoch,
                    iteration=epoch * max(train_count, 1),
                    model_state=model_impl.state_dict(),
                    optimizer_state=optimizer.state_dict(),
                    scheduler_state=scheduler.state_dict() if scheduler is not None else None,
                    metrics={
                        "train_loss_total": train_loss,
                        "val_psnr": val_psnr,
                        "val_ssim": val_ssim,
                    },
                    model_config={
                        "architecture": model.architecture,
                        "num_features": model.num_features,
                        "num_blocks": model.num_blocks,
                    },
                    dataset_id=dataset.id,
                    scale=dataset_scale,
                    architecture=model.architecture,
                )

            time.sleep(0.15)

        job.status = "completed"
        job.progress = 1.0
        job.finished_at = utc_now_iso()
        job.logs = [*job.logs[-49:], f"Training completed in {time.monotonic() - started_at:.1f}s."]
        job_store.put(job)
        _set_run_state(project_root, run_id, "completed")
        _extract_core_weights_after_training(project_root, run_id)
        try:
            _archive_run_to_model(project_root, run_id, dataset, dataset_scale)
        except Exception as arc_exc:
            import traceback
            job = job_store.get(job_id)
            job.logs = [*job.logs[-49:], f"Archive warning: {arc_exc}", traceback.format_exc()]
            job_store.put(job)
    except Exception as exc:
        import traceback
        job = job_store.get(job_id)
        job.status = "failed"
        job.finished_at = utc_now_iso()
        job.error = JobError(code="training_failed", message=str(exc))
        job.logs = [*job.logs[-49:], str(exc), traceback.format_exc()]
        job_store.put(job)
        _set_run_state(project_root, run_id, "failed")


def _extract_core_weights_after_training(project_root: Path, run_id: str) -> None:
    """After successful training, extract core weights from the best checkpoint and store on the model."""
    project = open_project(project_root)
    raw_run = next((r for r in project.runs if r.get("id") == run_id), None)
    if raw_run is None:
        return
    model_id = raw_run.get("model_id")
    if model_id is None:
        return
    checkpoints = raw_run.get("checkpoints", [])
    if not checkpoints:
        return
    best = None
    for c in checkpoints:
        if "best_psnr" in c.get("tags", []):
            best = c
            break
    if best is None:
        sorted_ckpts = sorted(checkpoints, key=lambda c: c.get("saved_at", ""), reverse=True)
        best = sorted_ckpts[0] if sorted_ckpts else None
    if best is None:
        return
    ckpt_path = Path(best.get("path", ""))
    if not ckpt_path.is_absolute():
        ckpt_path = project_root / ckpt_path
    if not ckpt_path.exists():
        return
    try:
        stored = extract_and_save_core_weights(ckpt_path, project_root, model_id, run_id)
        for idx, raw_model in enumerate(project.models):
            if raw_model.get("id") == model_id:
                raw_model["trained_core_weights_path"] = stored
                raw_model["status"] = "trained"
                # Only set core IDs on first training — subsequent runs don't overwrite
                if not raw_model.get("core_checkpoint_id"):
                    raw_model["core_checkpoint_id"] = best.get("id", "")
                    raw_model["core_run_id"] = run_id
                raw_model["updated_at"] = utc_now_iso()
                project.models[idx] = raw_model
                break
        write_project(project)
    except Exception:
        _log.error("core_extract_failed", "Failed to extract core weights after training.")


def _archive_run_to_model(project_root: Path, run_id: str, dataset: DatasetObject, dataset_scale: int) -> None:
    """After successful training, archive run data as train_history on the model.
    The run itself remains visible in completed state."""
    import shutil
    project = open_project(project_root)
    raw_run = next((r for r in project.runs if r.get("id") == run_id), None)
    if raw_run is None:
        return
    model_id = raw_run.get("model_id")
    if model_id is None:
        return
    checkpoints = raw_run.get("checkpoints", [])
    best_id = ""
    best_metrics: dict[str, float] = {}
    for c in checkpoints:
        if "best_psnr" in c.get("tags", []):
            best_id = c.get("id", "")
            best_metrics = {k: float(v) for k, v in c.get("metrics", {}).items() if isinstance(v, (int, float))}
            break
    if not best_id and checkpoints:
        latest = max(checkpoints, key=lambda c: c.get("saved_at", ""))
        best_id = latest.get("id", "")
        best_metrics = {k: float(v) for k, v in latest.get("metrics", {}).items() if isinstance(v, (int, float))}
    
    # Copy .pth files to model-owned directory and update paths
    session_dir = project_root / "models" / model_id / "archived_checkpoints" / run_id
    session_dir.mkdir(parents=True, exist_ok=True)
    updated_checkpoints = []
    for c in checkpoints:
        src_path = Path(c.get("path", ""))
        if not src_path.is_absolute():
            src_path = project_root / src_path
        if src_path.exists() and src_path.suffix == ".pth":
            dest_path = session_dir / src_path.name
            shutil.copy2(str(src_path), str(dest_path))
            c["path"] = str(dest_path.relative_to(project_root))
        updated_checkpoints.append(c)
    
    raw_settings = raw_run.get("settings", {})
    raw_lineage = raw_run.get("lineage", {})
    entry = TrainHistoryEntry(
        session_id=run_id,
        dataset_id=dataset.id,
        dataset_name=dataset.name,
        scale=dataset_scale,
        started_at=raw_run.get("created_at", ""),
        completed_at=utc_now_iso(),
        epochs=raw_settings.get("epochs", 0),
        best_metrics=best_metrics,
        checkpoints=updated_checkpoints,
        best_checkpoint_id=best_id,
        fine_tuned_from_checkpoint_id=raw_lineage.get("fine_tune_source_checkpoint_id") or "",
        fine_tuned_from_core_weights_path=raw_settings.get("source_core_weights_path") or "",
    )
    for idx, raw_model in enumerate(project.models):
        if raw_model.get("id") == model_id:
            history = raw_model.get("train_history", [])
            history.append(entry.model_dump())
            raw_model["train_history"] = history
            raw_model["updated_at"] = utc_now_iso()
            project.models[idx] = raw_model
            break
    write_project(project)


def _build_scheduler(optimizer, scheduler_type: str, epochs: int):
    import torch

    if scheduler_type == "none":
        return None
    if scheduler_type == "step":
        return torch.optim.lr_scheduler.StepLR(optimizer, step_size=max(epochs // 3, 1), gamma=0.5)
    return torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=max(epochs, 1))


def _combined_training_loss(prediction, target, weights):
    import torch
    import torch.nn.functional as F

    l1 = F.l1_loss(prediction, target)
    perceptual = F.l1_loss(_perceptual_features(prediction), _perceptual_features(target))
    adversarial = _detail_loss(prediction, target)
    total = prediction.new_tensor(0.0)
    if weights.l1:
        total = total + weights.l1 * l1
    if weights.perceptual:
        total = total + weights.perceptual * perceptual
    if weights.adversarial:
        total = total + weights.adversarial * adversarial
    if float(total.detach().cpu()) == 0.0:
        total = l1
    return total, {
        "l1": float(l1.detach().cpu()),
        "perceptual": float(perceptual.detach().cpu()),
        "adversarial": float(adversarial.detach().cpu()),
    }


def _perceptual_features(image):
    import torch.nn.functional as F

    height = min(16, image.shape[-2])
    width = min(16, image.shape[-1])
    return F.adaptive_avg_pool2d(image, (height, width))


def _detail_loss(prediction, target):
    import torch
    import torch.nn.functional as F

    channels = prediction.shape[1]
    kernel_x = prediction.new_tensor([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]]).view(1, 1, 3, 3).repeat(channels, 1, 1, 1)
    kernel_y = prediction.new_tensor([[-1, -2, -1], [0, 0, 0], [1, 2, 1]]).view(1, 1, 3, 3).repeat(channels, 1, 1, 1)
    pred_x = F.conv2d(prediction, kernel_x, padding=1, groups=channels)
    pred_y = F.conv2d(prediction, kernel_y, padding=1, groups=channels)
    target_x = F.conv2d(target, kernel_x, padding=1, groups=channels)
    target_y = F.conv2d(target, kernel_y, padding=1, groups=channels)
    return F.l1_loss(torch.cat([pred_x, pred_y], dim=1), torch.cat([target_x, target_y], dim=1))


def _evaluate_training_pass(model_impl, dataset, device, *, batch_size: int = 1, progress_callback=None):
    import math

    import torch
    import torch.nn.functional as F

    if len(dataset) == 0:
        return 0.0, 0.0, 0.0

    model_impl.eval()
    losses: list[float] = []
    with torch.no_grad():
        total_batches = math.ceil(len(dataset) / max(batch_size, 1))
        for batch_number, index in enumerate(range(0, len(dataset), max(batch_size, 1)), start=1):
            samples = [dataset[item] for item in range(index, min(index + max(batch_size, 1), len(dataset)))]
            lr_image = torch.stack([sample["lr"] for sample in samples]).to(device)
            hr_image = torch.stack([sample["hr"] for sample in samples]).to(device)
            prediction = model_impl(lr_image)
            loss = F.l1_loss(prediction, hr_image)
            losses.append(float(loss.item()))
            if progress_callback is not None:
                progress_callback(batch_number, total_batches)

    avg_loss = sum(losses) / max(len(losses), 1)
    mse = max(avg_loss * avg_loss, 1e-8)
    psnr = 10.0 * math.log10(1.0 / mse)
    ssim = max(0.0, min(1.0, 1.0 - avg_loss * 0.5))
    return avg_loss, psnr, ssim


def _generate_training_preview(project_root: Path, run: RunObject, model_impl, dataset, device):
    import torch

    model_impl.eval()
    with torch.no_grad():
        sample = dataset[0]
        lr_image = sample["lr"].unsqueeze(0).to(device)
        hr_image = sample["hr"].unsqueeze(0).to(device)
        prediction = model_impl(lr_image)
    return generate_validation_preview_from_tensors(
        project_root,
        run,
        lr=lr_image[0],
        sr=prediction[0],
        hr=hr_image[0],
    )


def _persist_run_metadata(project_root: Path, run: RunObject) -> None:
    project = open_project(project_root)
    for index, raw in enumerate(project.runs):
        if raw.get("id") == run.id:
            current = RunObject.model_validate(raw)
            current.metadata = {**current.metadata, **run.metadata}
            current.updated_at = utc_now_iso()
            project.runs[index] = current.model_dump()
            write_project(project)
            return


def _finalize_training_cancel(project_root: Path, run_id: str, job: Job) -> None:
    job.status = "canceled"
    job.finished_at = utc_now_iso()
    job_store.put(job)
    _set_run_state(project_root, run_id, "stopped")


def _set_run_state(project_root: Path, run_id: str, state: str) -> None:
    project = open_project(project_root)
    for index, raw in enumerate(project.runs):
        if raw.get("id") == run_id:
            run = RunObject.model_validate(raw)
            run.state = state
            run.updated_at = utc_now_iso()
            project.runs[index] = run.model_dump()
            write_project(project)
            return


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(status="ok", app=APP_NAME, version=__version__)


@app.get("/version", response_model=VersionResponse)
def version() -> VersionResponse:
    return VersionResponse(app=APP_NAME, version=__version__)


@app.post("/shutdown", dependencies=[Depends(require_session_token)])
def shutdown(background_tasks: BackgroundTasks) -> dict[str, str]:
    background_tasks.add_task(_terminate_process)
    return {"status": "shutting_down"}


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


@app.delete("/projects/recent", response_model=RecentProjectsResponse)
def forget_recent_project_endpoint(
    path: str,
    _token: None = Depends(require_session_token),
) -> RecentProjectsResponse:
    return forget_recent_project(path)


@app.delete("/projects/recent/all", response_model=RecentProjectsResponse)
def forget_all_recent_projects_endpoint(
    _token: None = Depends(require_session_token),
) -> RecentProjectsResponse:
    return forget_all_recent_projects()


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


@app.post("/projects/{project_id}/datasets/video/start", response_model=Job)
def start_video_dataset_endpoint(
    project_id: str,
    request: VideoGenerationConfig,
    _token: None = Depends(require_session_token),
) -> Job:
    project_root = _session_project_path(project_id)
    project = open_project(project_root)
    job = Job(
        type="video_dataset_generation",
        project_id=project.id,
        status="queued",
        progress=0.0,
        logs=[f"Queued video dataset {request.name}."],
    )
    job_store.put(job)

    def worker() -> None:
        try:
            job.status = "running"
            job.started_at = utc_now_iso()
            job.progress = 0.02
            job_store.put(job)
            generate_video_dataset(project_root, request, job=job, on_job=job_store.put)
        except Exception as exc:
            detail = getattr(exc, "detail", None)
            if isinstance(detail, dict):
                code = detail.get("code", "video_dataset_generation_failed")
                message = detail.get("message", str(exc))
            else:
                code = "video_dataset_generation_failed"
                message = str(exc)
            job.status = "failed"
            job.finished_at = utc_now_iso()
            job.error = JobError(code=code, message=message)
            job.logs = [*job.logs[-49:], message]
            job_store.put(job)

    Thread(target=worker, daemon=True).start()
    return job


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


@app.post("/projects/{project_id}/datasets/{dataset_id}/resynthesize", response_model=Job)
def dataset_resynthesis_endpoint(
    project_id: str,
    dataset_id: str,
    request: ReSynthesisRequest,
    _token: None = Depends(require_session_token),
) -> Job:
    project_root = _session_project_path(project_id)
    project = open_project(project_root)
    job = Job(
        type="dataset_resynthesis",
        project_id=project.id,
        object_id=dataset_id,
        status="queued",
        progress=0.0,
        logs=["Queued re-synthesis job."],
    )
    job_store.put(job)

    def worker() -> None:
        try:
            job.status = "running"
            job.started_at = utc_now_iso()
            job.progress = 0.02
            job_store.put(job)
            resynthesize_dataset(project_root, dataset_id, request, job=job, on_job=job_store.put)
        except Exception as exc:
            detail = getattr(exc, "detail", None)
            if isinstance(detail, dict):
                code = detail.get("code", "resynthesis_failed")
                message = detail.get("message", str(exc))
            else:
                code = "resynthesis_failed"
                message = str(exc)
            job.status = "failed"
            job.finished_at = utc_now_iso()
            job.error = JobError(code=code, message=message)
            job.logs = [*job.logs[-49:], message]
            job_store.put(job)

    Thread(target=worker, daemon=True).start()
    return job


@app.delete("/projects/{project_id}/datasets/{dataset_id}", response_model=ProjectResponse)
def delete_dataset_endpoint(
    project_id: str,
    dataset_id: str,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project, dataset = delete_dataset(_session_project_path(project_id), dataset_id)
    project = record_activity(project, "dataset", f"Dataset {dataset.name} deleted.", severity="warning", object_id=dataset.id)
    project = write_project(project)
    return _project_response(project)


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
    num_features: int = 32,
    num_blocks: int = 4,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project = save_template_as_model(_session_project_path(project_id), template_id, name, num_features=num_features, num_blocks=num_blocks)
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


@app.delete("/projects/{project_id}/models/{model_id}", response_model=ProjectResponse)
def delete_model_endpoint(
    project_id: str,
    model_id: str,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project, model = delete_model(_session_project_path(project_id), model_id)
    project = record_activity(project, "model", f"Model {model.name} deleted.", severity="warning", object_id=model.id)
    project = write_project(project)
    return _project_response(project)


@app.post("/projects/{project_id}/models/{model_id}/duplicate", response_model=ProjectResponse)
def duplicate_model_endpoint(
    project_id: str,
    model_id: str,
    name: str,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project = duplicate_model(_session_project_path(project_id), model_id, name)
    project = record_activity(project, "model", f"Model duplicated as {name}.", object_id=model_id)
    project = write_project(project)
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


@app.delete("/projects/{project_id}/runs/{run_id}", response_model=ProjectResponse)
def delete_run_endpoint(
    project_id: str,
    run_id: str,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project, run = delete_run_config(_session_project_path(project_id), run_id)
    project = record_activity(project, "run", f"Run {run.name} deleted.", severity="warning", object_id=run.id)
    project = write_project(project)
    return _project_response(project)


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
    _start_training_worker(_session_project_path(project_id), _run.id, job.id)
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
    _start_training_worker(_session_project_path(project_id), _run.id, job.id)
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
    if run.job_id is not None:
        _interrupt_training_thread(run.job_id)
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
def preview_endpoint(project_id: str, run_id: str, preview_index: int = 0) -> PreviewResponse:
    return latest_preview(_session_project_path(project_id), run_id, preview_index=preview_index)


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
    job = export_checkpoint_onnx(_session_project_path(project_id), run_id=run_id, checkpoint_id=checkpoint_id, destination=request.destination)
    job.project_id = project_id
    job_store.put(job)
    return job


@app.post("/projects/{project_id}/models/{model_id}/export-onnx", response_model=Job)
def export_model_onnx_endpoint(
    project_id: str,
    model_id: str,
    request: ExportOnnxRequest,
    output_scale: int = 4,
    _token: None = Depends(require_session_token),
) -> Job:
    job = export_checkpoint_onnx(_session_project_path(project_id), model_id=model_id, output_scale=output_scale, destination=request.destination)
    job.project_id = project_id
    job_store.put(job)
    return job


@app.post(
    "/projects/{project_id}/models/{model_id}/checkpoints/{run_id}/{checkpoint_id}/set-core",
    response_model=ProjectResponse,
)
def set_checkpoint_as_core_endpoint(
    project_id: str,
    model_id: str,
    run_id: str,
    checkpoint_id: str,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    import os
    project_root = _session_project_path(project_id)
    project = open_project(project_root)
    model_raw = next((m for m in project.models if m.get("id") == model_id), None)
    if model_raw is None:
        raise ApiError(404, "model_not_found", "Model was not found.")
    checkpoint_path = None
    for session in model_raw.get("train_history", []):
        for ckpt in session.get("checkpoints", []):
            if ckpt.get("id") == checkpoint_id:
                checkpoint_path = ckpt.get("path", "")
                break
        if checkpoint_path:
            break
    if not checkpoint_path:
        raise ApiError(404, "checkpoint_not_found", "Checkpoint not found in model train history.")
    ckpt_full = Path(checkpoint_path)
    if not ckpt_full.is_absolute():
        ckpt_full = project_root / ckpt_full
    if not ckpt_full.exists():
        raise ApiError(404, "checkpoint_file_missing", "Checkpoint file not found on disk.")
    stored = extract_and_save_core_weights(ckpt_full, project_root, model_id, run_id)
    for idx, raw in enumerate(project.models):
        if raw.get("id") == model_id:
            raw["core_checkpoint_id"] = checkpoint_id
            raw["core_run_id"] = run_id
            raw["trained_core_weights_path"] = stored
            raw["status"] = "trained"
            raw["updated_at"] = utc_now_iso()
            project.models[idx] = raw
            break
    project = write_project(project)
    return _project_response(project)


@app.post(
    "/projects/{project_id}/models/{model_id}/checkpoints/{run_id}/{checkpoint_id}/export-package",
    response_model=Job,
)
def export_model_package_endpoint(
    project_id: str,
    model_id: str,
    run_id: str,
    checkpoint_id: str,
    request: ExportPthRequest,
    _token: None = Depends(require_session_token),
) -> Job:
    import json as json_lib
    import shutil
    import tempfile
    import zipfile
    from datetime import date
    project_root = _session_project_path(project_id)
    project = open_project(project_root)
    model_raw = next((m for m in project.models if m.get("id") == model_id), None)
    if model_raw is None:
        raise ApiError(404, "model_not_found", "Model was not found.")
    checkpoint_path = None
    for session in model_raw.get("train_history", []):
        for ckpt in session.get("checkpoints", []):
            if ckpt.get("id") == checkpoint_id:
                checkpoint_path = ckpt.get("path", "")
                break
        if checkpoint_path:
            break
    if not checkpoint_path:
        raise ApiError(404, "checkpoint_not_found", "Checkpoint not found in model train history.")
    ckpt_full = Path(checkpoint_path)
    if not ckpt_full.is_absolute():
        ckpt_full = project_root / ckpt_full
    if not ckpt_full.exists():
        raise ApiError(404, "checkpoint_file_missing", "Checkpoint file not found on disk.")
    model_name = model_raw.get("name", "model")
    export_date = date.today().isoformat()
    zip_name = f"{model_name}_{export_date}.zip"
    dest_dir = Path(request.destination)
    dest_dir.mkdir(parents=True, exist_ok=True)
    zip_path = dest_dir / zip_name
    config = {
        "architecture": model_raw.get("architecture", "internal_residual_pixelshuffle"),
        "num_features": model_raw.get("num_features", 32),
        "num_blocks": model_raw.get("num_blocks", 4),
        "optimizer": model_raw.get("optimizer", {}),
        "scheduler": model_raw.get("scheduler", {}),
        "loss_weights": model_raw.get("loss_weights", {}),
    }
    metadata = {
        "name": model_name,
        "exported_at": utc_now_iso(),
        "source_project": project_id,
        "source_model": model_id,
        "core_checkpoint_id": model_raw.get("core_checkpoint_id", ""),
        "core_run_id": model_raw.get("core_run_id", ""),
    }
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        shutil.copy2(str(ckpt_full), str(tmp_path / "model.pth"))
        with open(tmp_path / "config.json", "w") as f:
            json_lib.dump(config, f, indent=2)
        with open(tmp_path / "metadata.json", "w") as f:
            json_lib.dump(metadata, f, indent=2)
        with zipfile.ZipFile(str(zip_path), "w", zipfile.ZIP_DEFLATED) as zf:
            zf.write(str(tmp_path / "model.pth"), "model.pth")
            zf.write(str(tmp_path / "config.json"), "config.json")
            zf.write(str(tmp_path / "metadata.json"), "metadata.json")
    job = Job(
        type="export_model_package",
        project_id=project_id,
        object_id=checkpoint_id,
        status="completed",
        progress=1.0,
        finished_at=utc_now_iso(),
        logs=[f"Exported package to {zip_path}."],
    )
    job.project_id = project_id
    job_store.put(job)
    return job


@app.post("/projects/{project_id}/import-model-package", response_model=ProjectResponse)
def import_model_package_endpoint(
    project_id: str,
    file: UploadFile,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    import json as json_lib
    import shutil
    import tempfile
    import zipfile
    project_root = _session_project_path(project_id)
    if not file.filename or not file.filename.endswith(".zip"):
        raise ApiError(422, "invalid_package", "Uploaded file must be a .zip package.")
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        zip_path = tmp_path / "package.zip"
        with open(zip_path, "wb") as f:
            f.write(file.file.read())
        with zipfile.ZipFile(str(zip_path), "r") as zf:
            zf.extractall(str(tmp_path))
        config_path = tmp_path / "config.json"
        pth_path = tmp_path / "model.pth"
        if not config_path.exists() or not pth_path.exists():
            raise ApiError(422, "invalid_package", "Package must contain config.json and model.pth.")
        with open(config_path) as f:
            config = json_lib.load(f)
        project = open_project(project_root)
        model = ModelObject(
            name=config.get("name", file.filename.replace(".zip", "")),
            slug=slugify(config.get("name", file.filename.replace(".zip", ""))),
            architecture=config.get("architecture", "internal_residual_pixelshuffle"),
            num_features=config.get("num_features", 32),
            num_blocks=config.get("num_blocks", 4),
        )
        if config.get("optimizer"):
            model.optimizer = OptimizerConfig(**config["optimizer"])
        if config.get("scheduler"):
            model.scheduler = SchedulerConfig(**config["scheduler"])
        if config.get("loss_weights"):
            model.loss_weights = LossWeights(**config["loss_weights"])
        core_dir = project_root / "models" / model.id / "core_weights"
        core_dir.mkdir(parents=True, exist_ok=True)
        dest_pth = core_dir / "imported_core.pth"
        shutil.copy2(str(pth_path), str(dest_pth))
        model.trained_core_weights_path = str(dest_pth.relative_to(project_root))
        model.status = "trained"
    model.core_checkpoint_id = "imported"
    model.core_run_id = "imported"
    entry = TrainHistoryEntry(
        session_id="imported",
        dataset_id="",
        dataset_name="Imported package",
        scale=0,
        started_at="",
        completed_at=utc_now_iso(),
        epochs=0,
        checkpoints=[],
        best_checkpoint_id="",
    )
    model.train_history.append(entry)
    project.models.append(model.model_dump())
    project = write_project(project)
    return _project_response(project)


@app.delete(
    "/projects/{project_id}/models/{model_id}/checkpoints/{checkpoint_id}",
    response_model=ProjectResponse,
)
def delete_archived_checkpoint_endpoint(
    project_id: str,
    model_id: str,
    checkpoint_id: str,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    project_root = _session_project_path(project_id)
    project = open_project(project_root)
    model_raw = next((m for m in project.models if m.get("id") == model_id), None)
    if model_raw is None:
        raise ApiError(404, "model_not_found", "Model was not found.")
    removed = False
    for session in model_raw.get("train_history", []):
        ckpts = session.get("checkpoints", [])
        for ci, ckpt in enumerate(ckpts):
            if ckpt.get("id") == checkpoint_id:
                ckpt_path = Path(ckpt.get("path", ""))
                if not ckpt_path.is_absolute():
                    ckpt_path = project_root / ckpt_path
                if ckpt_path.exists():
                    ckpt_path.unlink()
                del ckpts[ci]
                removed = True
                break
        if removed:
            break
    if not removed:
        raise ApiError(404, "checkpoint_not_found", "Checkpoint not found in model train history.")
    # Clean up empty sessions
    model_raw["train_history"] = [
        s for s in model_raw["train_history"]
        if s.get("checkpoints", [])
    ]
    model_raw["updated_at"] = utc_now_iso()
    for idx, raw in enumerate(project.models):
        if raw.get("id") == model_id:
            project.models[idx] = model_raw
            break
    project = write_project(project)
    return _project_response(project)


@app.delete(
    "/projects/{project_id}/models/{model_id}/sessions/{session_id}",
    response_model=ProjectResponse,
)
def delete_archived_session_endpoint(
    project_id: str,
    model_id: str,
    session_id: str,
    _token: None = Depends(require_session_token),
) -> ProjectResponse:
    import shutil
    project_root = _session_project_path(project_id)
    project = open_project(project_root)
    model_raw = next((m for m in project.models if m.get("id") == model_id), None)
    if model_raw is None:
        raise ApiError(404, "model_not_found", "Model was not found.")
    session_dir = project_root / "models" / model_id / "archived_checkpoints" / session_id
    if session_dir.exists():
        shutil.rmtree(str(session_dir))
    original_len = len(model_raw.get("train_history", []))
    model_raw["train_history"] = [
        s for s in model_raw["train_history"]
        if s.get("session_id") != session_id
    ]
    if len(model_raw["train_history"]) == original_len:
        raise ApiError(404, "session_not_found", "Session not found in model train history.")
    model_raw["updated_at"] = utc_now_iso()
    for idx, raw in enumerate(project.models):
        if raw.get("id") == model_id:
            project.models[idx] = model_raw
            break
    project = write_project(project)
    return _project_response(project)


@app.get("/dependencies/inference", response_model=InferenceReadinessResponse)
def inference_readiness_endpoint(device: str = "cpu") -> InferenceReadinessResponse:
    return inference_readiness(device)


@app.post("/projects/{project_id}/inference", response_model=InferenceRecord)
def run_inference_endpoint(
    project_id: str,
    request: InferenceRequest,
    _token: None = Depends(require_session_token),
) -> InferenceRecord:
    record, job = run_inference(_session_project_path(project_id), request, job_store)
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
