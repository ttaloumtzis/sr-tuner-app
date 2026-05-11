## Why

`sr-tuner` needs an end-to-end desktop workflow that helps users create projects, register super-resolution datasets, configure models, train locally, inspect progress, manage checkpoints, and run inference without manually wiring scripts together.

This establishes the first complete product slice for a beginner-friendly Linux desktop SR workstation while keeping the frontend/backend boundary clean enough to support stronger ML workflows and future remote execution.

## What Changes

- Add a Flutter desktop app shell for Linux development with a start screen showing the `sr-tuner` name and actions to create or open projects.
- Add an automatically started local Python FastAPI backend that the Flutter frontend communicates with over local HTTP.
- Add project folders and a `sr-tuner.project.json` save file that persists datasets, models, runs, checkpoints, inference history, and relevant metadata.
- Add multiple dataset objects per project, including existing paired `HR/` and `LR/` datasets and generated paired datasets from video.
- Add model objects with architecture, scale, feature/block counts, optimizer, scheduler, and loss-weight metadata.
- Add training setup for one active local run at a time, including dataset/model selection, scale compatibility checks, index-based validation split, device selection, logging, mixed precision, compile toggle, epochs, checkpoint cadence, warmup, and scheduler-specific options.
- Add a minimal internal PyTorch SR training path first, with BasicSR-compatible expansion planned after the workflow is proven.
- Add live metrics for the active run, including losses, PSNR, SSIM, learning rate, progress, hardware status, and validation image previews.
- Add checkpoint browsing grouped by run, including latest/best markers, export, deletion, and use-for-inference actions.
- Add inference for single images and batch folders, including checkpoint selection, output history, saved results, and draggable before/after comparison.

## Capabilities

### New Capabilities
- `desktop-project-workflow`: Defines desktop app startup, backend lifecycle, project creation/opening, project persistence, and workspace navigation.
- `dataset-management`: Defines dataset object creation, validation, metadata, storage modes, and video-to-paired-dataset generation.
- `model-management`: Defines model object creation, editable model configuration, trained/fine-tune model metadata, and dataset/model scale compatibility.
- `training-runs`: Defines local run setup, one-active-run behavior, PyTorch training execution, index-based validation split, run persistence, and training controls.
- `live-metrics`: Defines live training status, metric charts, hardware reporting, and validation preview/diff behavior.
- `checkpoint-management`: Defines checkpoint listing by run, metadata, latest/best markers, deletion, export, and inference handoff.
- `inference-workflow`: Defines single-image and batch inference, checkpoint/model selection, output persistence, history, and comparison preview.

### Modified Capabilities
- None.

## Impact

- Introduces a Flutter desktop frontend targeting Linux development first.
- Introduces a local Python FastAPI backend launched and monitored by the frontend.
- Introduces PyTorch as the initial ML execution dependency, defaulting to CPU with future CUDA, ROCm, and DirectML build flavors.
- Introduces project-level persistence under portable project folders using JSON metadata files and run/checkpoint/inference subfolders.
- Introduces local HTTP API endpoints for project, dataset, model, training, metrics, checkpoint, and inference operations.
