# sr-tuner

Desktop super-resolution workstation — Flutter frontend + Python FastAPI backend, running locally on Linux.

---

## Development startup

**Start the backend** (FastAPI on `127.0.0.1:8765`, hot-reload enabled):

```sh
scripts/dev_backend.sh
```

**Start the Flutter Linux frontend** (connects to the backend automatically):

```sh
scripts/dev_frontend.sh
```

Both can run simultaneously in separate terminals. The Flutter app launches the backend process automatically when packaged; in dev mode it relies on `dev_backend.sh` already running.

---

## Testing

**Backend unit and integration tests** (pytest, no PyTorch required):

```sh
uv run --project backend pytest backend/tests/ -q
```

Tests that require PyTorch are skipped automatically with a `pytest.skip` message when the dependency is not installed. The full test suite covers the API layer via `TestClient` — no live server needed.

**Flutter static analysis and widget tests:**

```sh
flutter analyze
flutter test
```

**Regenerate fixture PNG images** (only needed if `backend/tests/fixtures/` is missing or corrupt):

```sh
python3 scripts/gen_fixtures.py
```

---

## Cleanup

Remove build output, Python caches, and known temporary artifacts:

```sh
scripts/clean.sh           # keeps backend/.venv
scripts/clean.sh --venv    # also removes backend/.venv (run uv sync --project backend to restore)
```

---

## Generated local files

| Path | Description |
|---|---|
| `build/` | Flutter build output — safe to delete |
| `backend/.venv/` | Python virtual environment managed by uv |
| `backend/.pytest_cache/` | pytest cache — safe to delete |
| `backend/src/sr_tuner_api/__pycache__/` | Python bytecode — safe to delete |
| `config/sr_tuner.local.json` | Local dev overrides (port, host) — not committed |

---

## Dependencies

### Required (always)

| Dependency | Why |
|---|---|
| Flutter SDK (Linux desktop target) | Frontend |
| Python 3.11+ | Backend |
| [uv](https://github.com/astral-sh/uv) | Python package manager for backend |
| FastAPI + uvicorn | Backend web framework (installed via uv) |

### Required for training and inference

| Dependency | Why |
|---|---|
| PyTorch (CPU or GPU) | Training and inference |
| Pillow | Image loading during training |

Install in the backend environment:

```sh
scripts/setup_backend_cpu.sh
```

For AMD GPUs on Linux with ROCm, install the ROCm PyTorch wheel build instead:

```sh
scripts/setup_backend_rocm.sh
```

The ROCm script defaults to the current PyTorch ROCm 7.1 wheel index:
`https://download.pytorch.org/whl/rocm7.1`. Override it if your installed ROCm stack needs another wheel stream:

```sh
ROCM_WHEEL_INDEX=https://download.pytorch.org/whl/rocm6.4 scripts/setup_backend_rocm.sh
```

### Optional

| Dependency | Why |
|---|---|
| TensorBoard / `torch.utils.tensorboard` | Run metrics logging (toggle in Training Setup tab) |
| onnx + onnxruntime | ONNX checkpoint export (shown only when available) |
| ffmpeg | Type 2 video-to-paired-dataset generation |

---

## Session token

The Flutter frontend generates a random session token at startup and passes it to the backend via the `SR_TUNER_SESSION_TOKEN` environment variable (dev mode) or process arguments (packaged mode). All project-mutating API calls require the token in the `x-sr-tuner-token` header — unauthenticated calls return `401`. This protects the local API against other processes on the same machine.

In dev mode the backend reads the token from the environment:

```sh
SR_TUNER_SESSION_TOKEN=my-dev-token scripts/dev_backend.sh
```

Tests set `SR_TUNER_SESSION_TOKEN` via `monkeypatch.setenv`.

---

## Checkpoint storage layout

Checkpoints are owned by the run that produced them:

```
<project>/
  runs/
    <run-id>/
      checkpoints/
        epoch_0001_iter_000100.pth   ← actual weight file
      metrics.jsonl                  ← structured metric log
      metric_definitions.json        ← metric metadata
      run.json                       ← run state snapshot
  checkpoints/                       ← derived / export / cache only (non-authoritative)
  sr-tuner.project.json              ← project index (atomic writes + backup)
  sr-tuner.project.json.bak          ← previous-version backup
```

The `.pth` payload includes: model weights, optimizer/scheduler state, epoch, iteration, model config, source dataset ID, scale, metric summary, app version, and checkpoint schema version.

---

## Polling behavior

Flutter polls the backend at bounded intervals rather than using a persistent connection:

| Endpoint | Poll interval | Purpose |
|---|---|---|
| `/projects/{id}/active-run` | 2 s | Active run status + latest metrics |
| `/projects/{id}/runs/{id}/metrics` | 5 s | Full metric history for charts |
| `/projects/{id}/hardware` | 3 s | CPU/GPU telemetry |
| `/jobs/{id}` | 1 s | Dataset copy / video gen / export job progress |

Polling stops when the tab is not visible or the project is closed.

---

## TensorBoard

Enable TensorBoard logging in the Training Setup tab before launching a run. Event files are written to `runs/<run-id>/logs/tensorboard/`. Launch TensorBoard separately:

```sh
tensorboard --logdir <project>/runs/<run-id>/logs/tensorboard
```

The backend validates that `torch.utils.tensorboard` or `tensorboard` is importable before allowing a run with logging enabled — missing dependencies block the toggle rather than silently disabling it.

---

## Runtime Notes

- Training always offers CPU. AMD ROCm GPUs are detected through the ROCm PyTorch build; PyTorch exposes ROCm devices through `torch.cuda`, and the UI labels them as `ROCm`.
- Mixed precision (`float16`) is available but may not accelerate training on CPU-only builds.
- `torch.compile` is disabled by default on CPU; enabling it may not improve performance.
- ONNX export requires `onnx` and `onnxruntime` to be installed separately.
- Large image inference is handled via tiled inference; OOM errors on CPU return recoverable guidance suggesting smaller tile sizes.

---

## Classic Workspace UI

The Classic Workspace UI provides a beginner-friendly desktop interface with the following tabs:

| Tab | Description |
|---|---|
| **Overview** | Project dashboard with metrics, recent activity, next-step guidance, and loss sparkline |
| **Dataset** | Source management, health checks, preview pane, and video import wizard |
| **Model** | Template catalog with filter/import controls, hyperparameters, and non-destructive switching |
| **Training** | Three-column layout for run configuration, estimates, and all-runs view |
| **Live** | Active run monitoring with progress, charts, validation samples, and OOM remediation |
| **Checkpoints** | Aggregate checkpoint view with PSNR strip, ranking, pruning, and comparison |
| **Inference** | Before/after compare viewer, inspector, tuning controls, and batch processing |

### Dashboard endpoints

The UI uses several backend view-model endpoints for dashboard state:

| Endpoint | Purpose |
|---|---|
| `GET /projects/{id}/dashboard` | Project summary with counts, best PSNR, active run state, disk status |
| `GET /projects/{id}/activity` | Recent activity feed for dataset, model, run, checkpoint, and inference events |
| `GET /projects/{id}/workspace` | Workspace preferences (theme, density, selected tab, per-project UI state) |
| `GET /projects/recent` | Recent projects with stale/missing path detection |
| `GET /projects/{id}/checkpoints/aggregate` | Checkpoint aggregate with best checkpoint, PSNR trend, and row actions |

### Known unsupported actions

The following features are gated behind unavailable states in this version:

| Feature | State |
|---|---|
| `.srtproj archive` import/export | Disabled placeholder — projects are folders with `sr-tuner.project.json` as the only manifest |
| Checkpoint comparison | Disabled if fewer than 2 checkpoints selected |
| Checkpoint pruning | Disabled when automatic pruning policy is not configured |
| Dataset re-synthesis | Disabled if not supported by backend |
| Model template import | Disabled if import is not available for the selected template |

### Optional platform capabilities

| Capability | Platform | Notes |
|---|---|---|
| Desktop drag/drop for onboarding | Linux (when available) | Falls back to native file/folder picker |
| Show in folder | Native file manager | Guarded behind capability checks |
| IBM Plex font | Bundled | If unavailable, system font is used |
