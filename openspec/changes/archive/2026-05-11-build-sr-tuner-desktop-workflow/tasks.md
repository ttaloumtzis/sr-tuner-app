## 1. Repository And App Skeleton

- [x] 1.1 Create the Flutter desktop app structure for Linux development.
- [x] 1.2 Create the Python backend package structure with FastAPI entrypoint.
- [x] 1.3 Add development scripts for running the Flutter frontend and backend locally.
- [x] 1.4 Add shared configuration for local backend host, port, and health checks.

## 2. Backend Project Foundation

- [x] 2.1 Implement FastAPI health and version endpoints.
- [x] 2.2 Implement project creation that writes `sr-tuner.project.json` and required subfolders.
- [x] 2.3 Implement project opening and validation for existing project folders.
- [x] 2.4 Implement project state read/write helpers with relative path support for project assets.
- [x] 2.5 Add backend tests for create/open project persistence.
- [x] 2.6 Implement project schema version validation, backup, and migration helpers.
- [x] 2.7 Refuse non-empty non-project target folders by default during project creation.
- [x] 2.8 Add project-scoped session ID mapping so later APIs can use project IDs instead of raw paths.
- [x] 2.9 Implement atomic project-file writes with temporary file, rename, and backup recovery support.
- [x] 2.10 Implement stable opaque ID and folder-safe slug helpers for project objects.
- [x] 2.11 Implement standard structured API error responses.
- [x] 2.12 Implement local API session token protection for project-mutating endpoints.
- [x] 2.13 Implement shared backend job schema, job store, status endpoint, log tail, and cancellation state.
- [x] 2.14 Add foundation tests for migrations, atomic writes, backup recovery, project-scoped sessions, ID/slug helpers, structured errors, token rejection, and job status/cancellation.

## 3. Flutter Project Workflow

- [x] 3.1 Build the startup screen with prominent `sr-tuner` title and create/open project actions.
- [x] 3.2 Implement Flutter backend process startup and health wait logic.
- [x] 3.3 Implement create project and open project flows using backend APIs.
- [x] 3.4 Build the six-tab project workspace navigation.
- [x] 3.5 Persist and restore basic active project workspace state.
- [x] 3.6 Split the large Flutter app file into app, backend, project, workspace, and shared modules before adding real tab UIs.
- [x] 3.7 Add native desktop file and folder pickers while keeping typed path fields as an advanced fallback.
- [x] 3.8 Isolate backend startup behind dev, packaged, and future remote launcher modes.
- [x] 3.9 Add shared Flutter rendering for structured API errors, job progress, cancelable jobs, and empty or blocked tab states.
- [x] 3.10 Implement frontend-generated session token bootstrap for dev and packaged backend launch modes.
- [x] 3.11 Implement bounded polling clients for jobs, active run status, metrics, and hardware telemetry.

## 4. Dataset Management

- [x] 4.1 Implement dataset object schema and project persistence.
- [x] 4.2 Implement Type 1 paired dataset validation for `HR/` and `LR/` folders.
- [x] 4.3 Implement deterministic Type 1 pair matching by filename stem with supported image format filtering.
- [x] 4.4 Implement Type 1 declared-versus-validated scale checks from sampled pair dimensions.
- [x] 4.5 Implement quick and full dataset validation modes with stored validation mode metadata.
- [x] 4.6 Implement dataset image mode and bit-depth policy with grayscale conversion warnings and unsupported image errors.
- [x] 4.7 Implement Type 1 external reference storage with absolute paths.
- [x] 4.8 Implement Type 1 copy or move estimation, staging, validation, commit, and safe move cleanup through shared jobs.
- [x] 4.9 Implement Type 2 video-to-paired dataset generation settings schema.
- [x] 4.10 Implement video dependency readiness checks for ffmpeg or the configured video decoding backend.
- [x] 4.11 Implement Type 2 HR frame extraction and LR generation into project dataset folders through shared jobs.
- [x] 4.12 Validate generated Type 2 HR/LR dimensions and persist validated scale metadata.
- [x] 4.13 Build Dataset tab UI for multiple datasets, Type 1 registration, Type 2 generation, storage operation confirmation, video dependency readiness, and progress/status display.
- [x] 4.14 Add tests for dataset validation, pair matching, validation depth, image policy, scale validation, video dependency failures, metadata persistence, and storage modes.

## 5. Model Management

- [x] 5.1 Implement model object schema with architecture, scale, features, blocks, optimizer, scheduler, and loss weights.
- [x] 5.2 Implement create, list, update, and read APIs for model objects.
- [x] 5.3 Derive model status for untrained, trained, and fine-tune-capable states from usable checkpoint metadata.
- [x] 5.4 Define the minimal internal residual pixel-shuffle SR model config and supported scales.
- [x] 5.5 Validate loss-weight support against the selected training path and block unsupported perceptual or adversarial loss use.
- [x] 5.6 Build Model tab UI with Create Model and Models sections.
- [x] 5.7 Add compatibility helper for dataset scale versus model scale.
- [x] 5.8 Add tests for model persistence, internal baseline config, loss support validation, derived status, and scale compatibility.

## 6. Training Setup And Execution

- [x] 6.1 Implement run object schema and run folder creation under the project.
- [x] 6.2 Implement explicit run lifecycle states and interrupted-run recovery on backend startup/open.
- [x] 6.3 Implement run folder naming based on run IDs rather than editable display names.
- [x] 6.4 Implement run setup API with dataset, model, train mode, validation split, device, logging, precision, compile, epochs, checkpoint cadence, warmup, and scheduler options.
- [x] 6.5 Implement TensorBoard logging configuration, run log directory metadata, and missing logging dependency validation.
- [x] 6.6 Implement training dependency detection for PyTorch, image loading, and optional accelerators.
- [x] 6.7 Implement device detection with CPU default and optional supported accelerator reporting.
- [x] 6.8 Implement index-based train/validation split without moving dataset files.
- [x] 6.9 Implement a minimal internal PyTorch residual pixel-shuffle SR model and dataset loader.
- [x] 6.10 Implement local training launch as a shared job with one-active-run enforcement based on lifecycle state.
- [x] 6.11 Implement deterministic mapping from shared training job status to run lifecycle state.
- [x] 6.12 Implement pause, live resume, checkpoint resume, fine-tune lineage, and stop controls for runs.
- [x] 6.13 Build Training Setup tab UI with dataset/model selectors, dependency readiness, TensorBoard readiness, run settings, estimate panel, lifecycle status, and launch action.
- [x] 6.14 Add tests for run validation, TensorBoard dependency readiness, lifecycle transitions, job-to-run mapping, split generation, interrupted recovery, resume/fine-tune semantics, and one-active-run enforcement.

## 7. Live Metrics

- [x] 7.1 Write run metrics to structured files such as `metrics.jsonl`.
- [x] 7.2 Persist metric definition metadata for PSNR, SSIM, component losses, total loss, and speed values.
- [x] 7.3 Expose bounded-polling backend endpoints for active run status, metrics, hardware telemetry, and validation preview assets.
- [x] 7.4 Represent unavailable hardware telemetry explicitly instead of reporting misleading zero values.
- [x] 7.5 Generate validation preview images for LR input, SR output, HR target, and selected diff mode.
- [x] 7.6 Build Live Metrics tab status bar, metric cards, charts, hardware panel, preview grid, and empty/no-run state.
- [x] 7.7 Add tests for metric serialization, metric definitions, telemetry availability, and preview metadata.

## 8. Checkpoints

- [x] 8.1 Save checkpoints under each run folder according to checkpoint cadence.
- [x] 8.2 Store checkpoint metadata as run-owned metadata with epoch, metrics, path, size, saved time, and tags.
- [x] 8.3 Implement internal `.pth` checkpoint payload contract with weights, optimizer, scheduler, epoch, iteration, model config, dataset ID, scale, metrics, app version, and schema version.
- [x] 8.4 Validate checkpoint payload schema, architecture, scale, and required fields before inference, resume, fine-tune, or export.
- [x] 8.5 Derive any project-level checkpoint list from run-owned checkpoint metadata.
- [x] 8.6 Treat top-level project `checkpoints/` as derived/export/cache storage and keep run-owned checkpoint metadata authoritative.
- [x] 8.7 Implement latest, best PSNR, and best loss marker calculation.
- [x] 8.8 Implement ONNX dependency readiness checks and conditional ONNX export availability.
- [x] 8.9 Implement checkpoint list, delete, export `.pth`, and conditional ONNX export APIs through shared jobs where needed.
- [x] 8.10 Preserve historical references but disable dependent actions when a referenced checkpoint is deleted.
- [x] 8.11 Build Checkpoints tab with run selector, checkpoint table, details panel, delete confirmation, export, ONNX readiness, and inference handoff.
- [x] 8.12 Add tests for checkpoint payload validation, run-owned metadata, marker calculation, deletion, dependent references, derived index rebuilding, ONNX dependency failures, and export behavior.

## 9. Inference

- [x] 9.1 Implement inference request schema using selected checkpoint-derived scale.
- [x] 9.2 Implement inference dependency and device readiness checks.
- [x] 9.3 Implement single-image inference and output persistence through shared jobs.
- [x] 9.4 Implement batch-folder inference with per-file success and failure reporting through shared jobs.
- [x] 9.5 Implement tiled inference with tile size, overlap, padding mode, blend strategy, and recoverable OOM guidance.
- [x] 9.6 Store inference history objects with input, output, checkpoint, scale, tile settings, device, runtime, available metrics, and partial-result metadata.
- [x] 9.7 Build Inference tab with input selection, checkpoint selection, tile/output settings, batch controls, dependency readiness, and quality/info panels.
- [x] 9.8 Build draggable vertical before/after comparison with side-by-side and zoom/pan preview modes.
- [x] 9.9 Add tests for inference metadata, dependency readiness, checkpoint scale handling, tiling config, OOM guidance, and partial batch results.

## 10. End-To-End Verification

- [x] 10.1 Add a tiny fixture paired dataset for CPU smoke testing.
- [x] 10.2 Verify complete flow: create project, add Type 1 dataset, create model, configure run, train, save checkpoint, run inference.
- [x] 10.3 Verify project reopen restores datasets, models, runs, checkpoints, and inference history.
- [x] 10.4 Run backend test suite and Flutter analyzer/tests.
- [x] 10.5 Verify shared job progress, cancellation, structured error rendering, atomic project saves, token rejection, job-to-run mapping, and backup recovery in smoke scenarios.
- [x] 10.6 Add a development cleanup script for generated caches, build output, and known temporary smoke artifacts.
- [x] 10.7 Document development startup commands, generated local files, dependency expectations, TensorBoard behavior, checkpoint storage layout, local API token behavior, polling behavior, and current CPU-first limitations.
