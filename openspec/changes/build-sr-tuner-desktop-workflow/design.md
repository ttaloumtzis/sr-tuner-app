## Context

`sr-tuner` is starting from an OpenSpec-only repository. The first product slice must establish the app shape, persistence model, local backend contract, and a minimal ML execution path before adding heavier BasicSR integrations.

The target development platform is Linux desktop on Arch. The app should still be structured so Windows and macOS builds, GPU-specific Python packages, and future remote execution can be added without rewriting the user workflow.

## Goals / Non-Goals

**Goals:**
- Build a Flutter desktop workspace with start screen, project create/open flow, and six tabs: Dataset, Model, Training Setup, Live Metrics, Checkpoints, and Inference.
- Run a local Python FastAPI backend that Flutter starts automatically and communicates with over local HTTP.
- Persist each project as a portable folder with `sr-tuner.project.json` plus subfolders for datasets, models, runs, inference, and cache; any top-level checkpoints folder is non-authoritative and reserved for derived indexes, exports, or cache artifacts.
- Support multiple dataset objects, Type 1 paired `HR/` and `LR/` datasets, and Type 2 video-generated paired datasets.
- Support model objects with scale, architecture, feature/block counts, optimizer, scheduler, and loss-weight metadata.
- Provide one active local PyTorch training run at a time with CPU default, device detection, metrics, checkpoints, and inference.
- Keep the backend boundary clean enough for future BasicSR, CUDA, ROCm, DirectML, packaging variants, and remote workers.

**Non-Goals:**
- Remote training or server orchestration.
- Multiple concurrent training runs.
- Full BasicSR integration in the first milestone.
- Editable Type 3 datasets.
- Guaranteed GPU support in the default package.
- Physical train/validation dataset splitting.

## Decisions

### Flutter desktop owns the user workflow

Flutter provides the desktop UI, launches the backend process, waits for backend health, and renders the project workspace. This keeps the app installable as a desktop product while the ML code remains in Python.

Alternatives considered:
- Python-only desktop UI: simpler backend integration but weaker desktop UX and cross-platform packaging story.
- Web frontend in browser: easier charts and APIs but less native desktop project/file workflow.

### FastAPI is the local backend

Use FastAPI for the local API because it is lightweight, fast, typed, and provides request/response validation. It fits the requested Flask-like backend while giving stronger contracts for Flutter.

Backend errors should use one structured error shape with a stable code, human-readable message, optional details, and a recoverable flag. Project-mutating calls require a per-session token, and the backend binds only to loopback for v1. For local launches, Flutter generates the token and passes it to the backend process through environment or launch arguments. A pre-existing healthy backend can answer health/version, but project-mutating calls are rejected unless a valid token handshake exists.

Alternatives considered:
- Flask: lightweight but less typed by default.
- gRPC: strong contracts but unnecessary complexity for local desktop v1.

### Project folders are the persistence boundary

Each project is a folder with `sr-tuner.project.json` as the state index. Generated/copied assets use relative paths. External datasets can use absolute paths when users do not want to copy data into the project.

The saved project file should not treat its last opened absolute root path as durable identity. The active root is resolved from the folder selected at open time, and relative paths are resolved against that runtime root. Runtime responses may include the active root path for UI display, but persisted child objects should prefer project-relative paths when the asset is inside the project.

Project files carry a schema version. The backend owns project migrations: current versions open normally, supported older versions are backed up and upgraded, newer versions are rejected, and invalid versions are refused without modifying user files.

Project saves should be atomic. The backend writes a temporary file, completes the write, renames it into place, and retains the previous valid project file as a backup. Stable opaque IDs are the identity for datasets, models, runs, checkpoints, inference records, and jobs; display names are editable metadata.

Alternatives considered:
- Global database: better for search but weaker portability.
- Per-object files only: simpler merges but harder to load project state quickly in v1.

### Local API is project-scoped after open

The frontend creates or opens a project first. The backend returns a project ID and keeps an in-memory mapping from that ID to the active project root for the local session. Subsequent calls should use project-scoped routes such as `/projects/{project_id}/datasets`, `/projects/{project_id}/models`, and `/projects/{project_id}/runs` instead of repeatedly passing filesystem paths in request bodies.

This keeps file paths inside the local backend boundary and leaves room for future remote execution, where clients should not assume direct access to backend filesystem paths.

Long-running operations use a shared job model. Dataset copy/move, video dataset generation, training, export, ONNX export, single-image inference, and batch inference all return or expose a job with status, progress, logs, timing, associated project/object IDs, cancellation state, and error metadata. Flutter polls jobs, active run status, metrics, and hardware telemetry at bounded intervals through backend endpoints rather than reading project files directly.

Alternatives considered:
- Pass `project_path` on every request: quick for the initial skeleton but leaks filesystem details into every API and makes future remote execution harder.
- Store only one global active project: simpler, but it makes testing, reopen behavior, and future multi-window support weaker.

### Dataset and model are first-class objects

Datasets and models are persisted objects with metadata and IDs. Training setup selects those objects rather than collecting raw form paths. This supports multiple datasets, fine-tuning, compatibility checks, and future workstation features.

Type 1 datasets use strict v1 matching rules: flat `HR/` and `LR/` folders, supported image extensions only, hidden files ignored, and pairs matched by filename stem. Scale is both declared by the user and validated from sampled image dimensions. Type 2 datasets are generated by the app, so their configured scale becomes validated only after generated HR/LR outputs pass dimension checks.

Dataset copy/move into project storage is a staged operation. The backend estimates size first, copies into a staging folder, validates staged output, then commits with a final rename. Move operations delete source data only after verification.

Validation supports quick and full modes. Quick validation checks structure, pair matching, and a bounded dimension sample. Full validation checks readability and dimensions for all pairs. The v1 image policy accepts RGB, converts grayscale to RGB with a warning, and rejects unsupported alpha/channel/bit-depth cases unless a supported conversion policy is selected.

Alternatives considered:
- Treat forms as transient training config only: faster to build but makes reuse, validation, and history weaker.

### Model status is derived from checkpoints

Model objects store architecture and training configuration. Their displayed training status should be computed from run-owned checkpoint metadata. A model with no usable checkpoint is untrained; a model with usable checkpoints is trained; a checkpoint with compatible metadata can be selected for fine-tuning.

The first internal PyTorch architecture is a small residual SR model with pixel-shuffle upsampling, supported scales, configurable feature count, and configurable residual block count. L1 loss is the initial supported training loss. Perceptual and adversarial loss settings can be stored, but launch validation must block or disable them for training paths that do not implement them.

Alternatives considered:
- Persist a mutable model status field as source of truth: simpler but risks drift when checkpoint files are deleted, exported, or restored.

### Training starts with an internal PyTorch path

Implement a simple internal PyTorch SR training path first. Keep model/config objects shaped so BasicSR-compatible models can be added later. The first trainable model should prove dataset loading, model scale, run setup, metrics, checkpoints, and inference.

Training runs use explicit lifecycle states: `draft`, `configured`, `running`, `pausing`, `paused`, `resuming`, `stopping`, `stopped`, `completed`, `failed`, and `interrupted`. Any run in an active transitional state blocks launching another local run. If the backend restarts and finds a run persisted as `running` without an owned live process, it marks the run `interrupted`.

Shared training job status maps deterministically to run state: job `queued` leaves the run configured, job `running` sets run `running`, job `canceling` sets run `stopping`, job `canceled` sets run `stopped`, job `completed` sets run `completed`, and job `failed` sets run `failed` with the structured job error.

Pause/resume means continuing the same owned live process. Resuming an interrupted or stopped run starts a new process from a selected checkpoint while preserving lineage metadata. Fine-tuning always creates a new run linked to the source checkpoint. TensorBoard logging is optional; when enabled, event files are written under the run log directory and missing logging dependencies block or disable the toggle before launch.

Alternatives considered:
- Require BasicSR immediately: more powerful but increases dependency and config risk before the app workflow is proven.

### Validation split is index-based

Training runs split train/validation by index using percentage, seed, and shuffle settings. Dataset folders are never physically split.

Alternatives considered:
- Require separate train/val folders: common in ML but contradicts the desired `dataset/HR` and `dataset/LR` structure.

### Metrics and events are file-backed

Runs write structured files such as `metrics.jsonl`, `run.json`, and checkpoint metadata. Flutter can poll or subscribe to backend endpoints while files remain inspectable and recoverable.

Checkpoints are owned by their run. Run folders store checkpoint files and checkpoint metadata. Any project-level checkpoint list should be derived from run-owned metadata rather than being the source of truth. A top-level project `checkpoints/` folder, if present, is reserved for derived indexes, exported checkpoint artifacts, or cache data.

Metric records should include definitions, not just values. PSNR/SSIM records include channel policy, value range, and aggregation scope. Loss records include component losses where available plus total loss. Speed records indicate whether they are interval values or moving averages.

Internal `.pth` checkpoints include model weights, optimizer state when available, scheduler state when available, epoch, iteration, model config, source dataset ID, dataset scale, metric summary, app version, and checkpoint schema version.

Alternatives considered:
- In-memory metrics only: easier but loses recovery and history.
- Full event database: heavier than needed for v1.

### Backend launch has dev and packaged modes

During development, Flutter may start the backend through `uv run --project backend uvicorn ...`. That is a development launcher only. The app should isolate backend startup behind a launcher abstraction so a packaged build can start a bundled Python runtime/module later, and a future remote mode can point to a user-provided backend URL.

Dependency readiness is explicit. Core app/project APIs require FastAPI and standard-library file handling. Training and inference require PyTorch and image loading support. Type 2 video generation requires ffmpeg or the configured video decoding backend. ONNX export is shown only when the selected model/checkpoint and ONNX dependencies support it.

Alternatives considered:
- Hard-code `uv` as the only backend launcher: practical for Arch development but unsuitable for packaged desktop builds.

### Native file selection is the primary desktop path workflow

The UI should use native file and folder pickers for project folders, datasets, source videos, checkpoint export destinations, and inference inputs. Typed path fields remain useful for advanced users and recovery, but should not be the primary workflow.

Tabs should expose explicit empty and blocked states. Training is blocked until at least one usable dataset and compatible model exist. Live Metrics is empty without an active or recent run. Checkpoints and Inference guide the user back to training until usable checkpoints exist.

Alternatives considered:
- Typed paths only: fast to scaffold but not beginner-friendly and weak for desktop ergonomics.

### Inference uses explicit tiling and partial-result semantics

Inference records store selected checkpoint, scale, device, output settings, runtime, and effective tiling configuration. Tiling includes tile size, overlap, padding mode, and blend strategy. Memory failures return recoverable errors suggesting smaller tiles, CPU fallback, or lower concurrency. Batch inference preserves successful outputs and records per-file failures when only part of the batch succeeds.

Alternatives considered:
- Whole-image inference only: simpler but too fragile for large desktop images.

## Risks / Trade-offs

- [Risk] Packaging PyTorch with GPU variants can become large and platform-specific -> Mitigation: default to CPU packaging, detect supported devices at runtime, and add CUDA/ROCm/DirectML as explicit build flavors later.
- [Risk] Long-running training can outlive or crash the UI/backend -> Mitigation: persist run state and metrics incrementally, expose stop/resume-aware state, and mark interrupted runs clearly.
- [Risk] Type 2 video generation can consume large disk space -> Mitigation: show estimated frame count/storage before generation and keep generated datasets inside the project by default.
- [Risk] Fast UI updates may overload local HTTP polling -> Mitigation: start with modest polling and structured metric files, then add WebSocket/SSE if needed.
- [Risk] ONNX export may not work for every model -> Mitigation: expose ONNX export only when the selected model/checkpoint supports it.
- [Risk] CPU training may be slow -> Mitigation: frame CPU as the default compatibility mode and allow GPU-enabled builds to expose supported devices.
