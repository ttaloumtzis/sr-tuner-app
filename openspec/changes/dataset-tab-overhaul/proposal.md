## Why

The Dataset tab provides only two health checks, hardcodes bicubic downscaling and PNG output, shows a read-only degradation pipeline, and forces tedious one-step LR/HR preview navigation — none of which scale well as datasets grow in size and variety. Users need richer validation feedback, more realistic degradation options (including optical pre-blur for deblur model training), the ability to reconfigure and re-synthesize a video dataset without recreating it, and faster ways to browse large pair collections.

## What Changes

- **New health checks**: format consistency, resolution size, aspect ratio consistency, and near-black image detection added to dataset validation output alongside the existing matched-pairs and scale-alignment checks.
- **Extended downscaling options**: bilinear, lanczos, nearest (neighbor), and area methods exposed in the video extraction wizard alongside the existing bicubic default.
- **Optical pre-blur**: a Gaussian pre-downscale blur (`pre_blur` σ parameter) added to `VideoGenerationConfig` so LR frames can simulate lens blur, training SR models to recover sharpness.
- **Video output format choice**: PNG vs JPEG output selection (with JPEG quality slider) exposed in the video wizard; previously hardcoded to PNG.
- **Interactive degradation pipeline + re-synthesis**: pipeline card becomes editable for video-generated datasets; "Re-synthesize" button regenerates only LR frames from the stored source video using new settings.
- **Improved empty state**: per-type onboarding cards route directly to their respective wizard (bypassing the intermediate choice modal); cards include structured descriptions and format hints.
- **Improved creation wizards**: Type 1 gets a folder structure diagram and supported-formats note; Type 2 gains all new degradation controls plus FPS guidance copy.
- **Faster preview navigation**: scrubber slider + editable index field replace sole reliance on next/previous buttons for datasets with hundreds or thousands of pairs.

## Capabilities

### New Capabilities

- `dataset-health-extended`: Extended validation stats (format counts, resolution range, aspect ratio consistency, black image count) surfaced as typed health check rows in the dataset detail view.
- `dataset-video-degradation`: Full degradation control for video-generated datasets — downscale method selection, optical pre-blur, output format (PNG/JPEG), JPEG quality — plus live re-synthesis against the stored source video.
- `dataset-preview-navigation`: Scrubber slider and index jump field for fast non-sequential pair browsing.
- `dataset-creation-ux`: Improved empty state and creation wizard UI — direct routing, folder structure hints, format guidance, FPS copy.

### Modified Capabilities

- `dataset-management`: Validation model gains new optional stats fields; health check contract expands from 2 fixed rows to up to 7 typed rows; `VideoGenerationConfig` gains `pre_blur` and makes `output_format`/`downscale_method` user-selectable.

## Impact

- **Backend**: `datasets.py` (DatasetValidation model, validate_paired_dataset, VideoGenerationConfig, new resynthesize_dataset function), `classic_workspace.py` (_dataset_health_checks, _degradation_pipeline), `main.py` (resynthesize endpoint replaces UnsupportedState stub).
- **Frontend**: `dataset_tab.dart` (_DatasetEmptyState, _PairedDatasetForm, _VideoWizard, _PipelineCard, _PreviewPane), `backend_client.dart` (video API methods gain new params; new resynthesizeDataset method), `project_models.dart` (DatasetValidation Dart model).
- **Dependencies**: PIL/Pillow (already present) used for black-image pixel mean detection; ffmpeg flags extended (no new binary dependency).
- **No breaking changes** to existing stored project JSON — all new `DatasetValidation` fields have defaults.
