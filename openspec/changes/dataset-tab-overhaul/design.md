## Context

The Dataset tab is the entry point for all training data management in sr-tuner. Currently it has two health checks (matched pairs, scale alignment), hardcodes bicubic+PNG in the video wizard, shows a static read-only degradation pipeline card, and offers only next/previous buttons to browse potentially thousands of image pairs. Datasets are persisted as JSON in the project file; `DatasetValidation` is stored inline on each dataset object. The `VideoGenerationConfig` is stored verbatim as the `generation` dict on video-generated datasets, making re-synthesis straightforward since the source video path is already persisted.

## Goals / Non-Goals

**Goals:**
- Expose the full ffmpeg scale filter vocabulary (bilinear, lanczos, nearest, area) plus a pre-downscale Gaussian blur (`pre_blur`) in the video wizard.
- Surface richer validation statistics (format counts, resolution range, aspect ratio consistency, near-black pair count) as typed health check rows — without changing the `HealthCheckRow` wire format.
- Allow users to adjust degradation settings on an existing video-generated dataset and regenerate only LR frames (HR frames are immutable).
- Replace the tedious next/prev pair navigator with a scrubber slider and direct index jump.
- Improve the empty state and creation wizards so first-time users understand the difference between dataset types without reading documentation.

**Non-Goals:**
- Full dataset versioning / history of re-synthesis runs.
- Re-synthesis for Type 1 (paired) datasets — they have no stored generation config.
- Changing the pair-matching algorithm, storage modes, or scale validation logic.
- Supporting new image formats beyond the existing `{png, jpg, jpeg, webp, tif, tiff}` set.

## Decisions

### D1 — Extended validation stats stored on `DatasetValidation`, not a separate model

**Decision**: Add optional fields directly to `DatasetValidation` (`format_counts`, `min_hr_resolution`, `max_hr_resolution`, `consistent_aspect_ratio`, `black_pair_count`) rather than introducing a separate `ValidationStats` model.

**Rationale**: `DatasetValidation` is already serialised into the project JSON per dataset. Keeping stats inline avoids a second read path and keeps the workspace state flat. All new fields have defaults so existing stored datasets deserialise without error.

**Alternative considered**: A separate `metadata` sub-dict on `DatasetObject`. Rejected — already has a generic `metadata: dict` field that is not well-typed; adding more untyped data there makes health-check generation fragile.

### D2 — Black image detection uses PIL thumbnail mean, quick-mode gated

**Decision**: Detect near-black pairs by opening each HR image via PIL, resizing to 32×32, converting to grayscale, and checking mean pixel value < 8. In quick-mode validation, sample 1-in-4 images only; in full-mode, check every pair.

**Rationale**: `probe_image()` already reads raw bytes to extract dimensions without PIL, which is fast. Adding a PIL pass only for black detection would double I/O in quick mode where it matters least. Gating to 1-in-4 keeps quick validation snappy while still flagging obvious problems.

**Alternative considered**: Computing variance instead of mean to catch grey/uniform images too. Not chosen — the user's stated concern is "black images with no data"; mean < 8 captures that precisely without adding a second pass.

### D3 — Re-synthesis regenerates LR frames only, re-uses existing HR folder

**Decision**: `resynthesize_dataset()` deletes only the LR folder contents, re-runs the ffmpeg LR pipeline with the new config, then re-validates. HR frames are never touched.

**Rationale**: HR frames are lossless (PNG by default) and represent ground truth — they should never be re-derived from a lossy re-encode. The stored `generation.source_video` path is used directly; if the file has moved, the endpoint returns a 422 with a `source_video_missing` code so the user can relink.

**Alternative considered**: Full re-generation (HR + LR). Rejected — wasteful, and HR quality would degrade on repeated JPEG re-encodes if the user had chosen JPEG output.

### D4 — `pre_blur` is a pre-scale Gaussian filter, not a new downscale_method enum value

**Decision**: `pre_blur: float` is an independent field on `VideoGenerationConfig` that inserts `gblur=sigma={pre_blur}` into the ffmpeg filter chain *before* the scale step. It is orthogonal to `downscale_method`.

**Rationale**: The user wants to combine optical blur simulation with any downscale algorithm (e.g. lanczos + pre_blur for maximum realism). Encoding it as a special downscale_method value like `"gaussian_blur"` would prevent that combination. Keeping them separate is more expressive and maps directly to how ffmpeg filter chains work.

### D5 — Pipeline card is editable only for `video_generated` datasets

**Decision**: The `_PipelineCard` shows interactive sliders/dropdowns when `dataset.type == 'video_generated'`; for `paired` datasets it shows a static message ("No generated degradation metadata — dataset was registered from existing files.").

**Rationale**: Paired datasets have no stored source to re-derive LR frames from. Showing editable controls with a permanently disabled Re-synthesize button would confuse users.

### D6 — Empty state cards route directly; choice modal retained for the "+ Create dataset" button

**Decision**: In `_DatasetEmptyState`, each `_OnboardingCard` calls `_showPairedDatasetDialog()` or `_showVideoWizard()` directly. The intermediate `_showCreateDatasetDialog()` choice modal is kept for the "+ Create dataset" button in the populated state header.

**Rationale**: When there are no datasets, the user has already seen both card options side-by-side; routing through a choice modal adds an unnecessary extra click. When datasets exist and the user clicks "+ Create dataset", they need the choice modal because they're not looking at the empty state cards.

## Risks / Trade-offs

- **Source video moved or deleted**: Re-synthesis will fail with a clear error, but there is no UI to relink the source path. Mitigation: return a structured `source_video_missing` error code the frontend can detect and display with a path-picker action.
- **Black image detection PIL import**: `datasets.py` currently avoids PIL for performance (uses raw byte probing). Adding a conditional PIL import for black detection couples the module to PIL at runtime. Mitigation: wrap in a `try/except ImportError` and skip black-image check gracefully if PIL is absent (it is always present in the current venv).
- **Scrubber debounce on large datasets**: Dragging the slider fires many `_loadDetail` calls. Mitigation: 200 ms debounce timer in `_PreviewPane`; backend image reads are O(1) file seeks so latency is low.
- **Re-synthesis during active training run**: If a training run is using the dataset while LR frames are being regenerated, the run may read partially-written frames. Mitigation: check for active runs using the dataset (same guard used in `delete_dataset`) and return 409 if found.

## Migration Plan

1. Deploy backend with new `DatasetValidation` fields (all optional with defaults) — existing stored datasets continue to load without error.
2. On next dataset rescan or creation, new stats fields are populated. Old datasets show health checks that say "Run a full rescan to collect resolution and format stats."
3. Frontend picks up new health check rows automatically via the existing `HealthCheckRow` list rendering — no format change required.
4. No database migrations, no file format version bump needed.
