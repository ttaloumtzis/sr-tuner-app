## 1. Backend — Extend DatasetValidation Model

- [x] 1.1 Add `format_counts: dict[str, int]`, `min_hr_resolution: list[int] | None`, `max_hr_resolution: list[int] | None`, `consistent_aspect_ratio: bool | None`, and `black_pair_count: int` fields with defaults to `DatasetValidation` in `datasets.py`
- [x] 1.2 Update `validate_paired_dataset()` to collect `format_counts` from HR file extensions during the sample loop
- [x] 1.3 Update `validate_paired_dataset()` to track min/max HR resolution and set `consistent_aspect_ratio` from sampled pairs
- [x] 1.4 Add PIL-based black image detection in `validate_paired_dataset()`: resize HR image to 32×32, convert to greyscale, check mean < 8; gate to 1-in-4 pairs in quick mode and all pairs in full mode
- [x] 1.5 Populate all new fields on the returned `DatasetValidation` instance

## 2. Backend — Video Generation Config

- [x] 2.1 Add `pre_blur: float = Field(default=0.0, ge=0)` to `VideoGenerationConfig` in `datasets.py`
- [x] 2.2 Update `generate_video_dataset()` LR filter chain: insert `gblur=sigma={pre_blur}` before the scale step when `pre_blur > 0`
- [x] 2.3 Verify `output_format` and `downscale_method` are already accepted by the backend (they are — confirm the video metadata and start endpoints accept them)

## 3. Backend — Re-synthesis Endpoint

- [x] 3.1 Create `ReSynthesisRequest` Pydantic model with fields: `downscale_method`, `pre_blur`, `blur`, `noise`, `jpeg_quality`, `output_format`
- [x] 3.2 Implement `resynthesize_dataset(project_root, dataset_id, request)` in `datasets.py`: load dataset, raise 422 if not `video_generated` or `source_video` missing/non-existent, raise 409 if active run found
- [x] 3.3 In `resynthesize_dataset()`: merge stored `generation` dict with request overrides into a new `VideoGenerationConfig`, delete LR folder contents only (keep HR), re-run the ffmpeg LR pipeline
- [x] 3.4 In `resynthesize_dataset()`: re-validate the dataset with the existing `validate_paired_dataset()`, update `dataset.generation` and `dataset.validation`, write the project file, return `(project, dataset, job)`
- [x] 3.5 Replace the stub resynthesize endpoint in `main.py` with one that accepts `ReSynthesisRequest`, calls `resynthesize_dataset()`, and returns a `JobState`

## 4. Backend — Health Checks

- [x] 4.1 Update `_dataset_health_checks()` in `classic_workspace.py`: add `pair_count_quality` check (warning if < 100 pairs)
- [x] 4.2 Add `format_consistency` check: warning if `len(format_counts) > 1`, success showing the detected format, omitted if `format_counts` is empty
- [x] 4.3 Add `resolution` check: warning if `min_hr_resolution` width or height < 128, success showing min/max, omitted if no resolution data
- [x] 4.4 Add `aspect_ratio` check: warning if `consistent_aspect_ratio == False`, success if `True`, omitted if `None`
- [x] 4.5 Add `black_images` check: warning with count if `black_pair_count > 0`, omitted otherwise
- [x] 4.6 Update `_degradation_pipeline()` to insert `"Pre-blur (optical): σ={pre_blur}"` as step 2 when `pre_blur > 0` in generation metadata

## 5. Frontend — Backend Client

- [x] 5.1 Add `downscaleMethod`, `outputFormat`, `preBlur`, and `jpegQuality` parameters to `videoWizardMetadata()` in `backend_client.dart`; pass them in the request body replacing hardcoded values
- [x] 5.2 Apply the same parameter additions to `startVideoDataset()` and `generateVideoDataset()`
- [x] 5.3 Add `resynthesizeDataset({projectId, datasetId, downscaleMethod, outputFormat, preBlur, blur, noise, jpegQuality})` method returning `JobState`

## 6. Frontend — Project Models

- [x] 6.1 Add `formatCounts`, `minHrResolution`, `maxHrResolution`, `consistentAspectRatio`, `blackPairCount` fields to the `DatasetValidation` Dart class in `project_models.dart` with safe defaults in `fromJson()`

## 7. Frontend — Video Wizard

- [x] 7.1 Add `_videoDownscaleMethod` (`String`, default `'bicubic'`) state var to `_DatasetTabState`; add downscale method `DropdownButtonFormField` (options: bicubic, bilinear, lanczos, nearest, area) to `_VideoWizard`
- [x] 7.2 Add `_videoPreBlur` (`double`, default `0.0`) state var; add pre-blur `Slider` (0.0–3.0) with label "Pre-blur σ" to `_VideoWizard`
- [x] 7.3 Add `_videoOutputFormat` (`String`, default `'png'`) state var; add output format dropdown (PNG / JPEG) to `_VideoWizard`
- [x] 7.4 Add `_videoJpegQuality` (`int`, default `95`) state var; add JPEG quality slider (1–100) that is only visible when `_videoOutputFormat == 'jpg'`
- [x] 7.5 Add FPS guidance helper text near the FPS field (1–5 fps for distinct frames; higher rates may produce near-duplicate pairs)
- [x] 7.6 Wire all new state vars into `videoWizardMetadata()` and `startVideoDataset()` calls; update metadata chip row to include format and pre-blur when non-zero

## 8. Frontend — Pipeline Card

- [x] 8.1 Convert `_PipelineCard` to a `StatefulWidget` with local state vars mirroring the stored generation metadata (downscale method, pre_blur, blur, noise, jpeg_quality, output_format)
- [x] 8.2 Show interactive controls for `video_generated` datasets: downscale method dropdown, pre-blur slider (0–3.0), blur slider (0–5.0), noise slider (0–50), output format toggle, JPEG quality slider (1–100, visible when JPEG)
- [x] 8.3 Show static "No generation metadata" message for `paired` datasets
- [x] 8.4 Track a `_dirty` flag; enable the "Re-synthesize" button when `_dirty == true`
- [x] 8.5 Remove the "Coming soon" tooltip from the Re-synthesize button; on tap call `resynthesizeDataset()` and show a progress dialog (reuse `_DatasetCreationProgressDialog` pattern)
- [x] 8.6 On re-synthesis completion reload dataset detail and reset `_dirty = false`

## 9. Frontend — Preview Pane

- [x] 9.1 Add a full-width `Slider` below the LR/HR image pair in `_PreviewPane`, range 0 to `total-1`, with 200 ms debounce on `onChanged` calling `onPreview`
- [x] 9.2 Add an editable `TextField` (~80px wide) in the section header showing the 1-based pair index; on submit parse the value, clamp to [1, total], and call `onPreview(clamped - 1)`
- [x] 9.3 Hide the scrubber slider when `total == 0`

## 10. Frontend — Empty State & Type 1 Wizard

- [x] 10.1 Update `_DatasetEmptyState` so the Type 1 `_OnboardingCard` button calls `_showPairedDatasetDialog()` directly instead of `_showCreateDatasetDialog()`
- [x] 10.2 Update `_DatasetEmptyState` so the Type 2 `_OnboardingCard` button calls `_showVideoWizard()` directly
- [x] 10.3 Enrich the Type 1 onboarding card description to mention supported formats (PNG, JPG, WebP, TIFF) and the HR/LR subfolder requirement
- [x] 10.4 Enrich the Type 2 onboarding card description to show ffmpeg availability and note that pairs are extracted automatically
- [x] 10.5 Add a folder structure hint inside the Type 1 creation dialog (e.g. a monospace text block showing `dataset/HR/` and `dataset/LR/`)
