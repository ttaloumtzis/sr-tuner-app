## Why

The Live tab now shows a larger four-way preview, but the preview images are still treated like transient "latest" assets. That makes the preview hard to inspect after an epoch changes, causes unstable URLs, and can trigger repeated image fetching while the frontend polls live metrics.

The Inference tab also has a Flutter `DropdownButton` assertion when selected dropdown values drift away from their item lists. This blocks users from reaching inference even when checkpoints exist.

## What Changes

### Persistent Live Preview Artifacts
- Save one preview sample for each epoch under the run folder using the stable run ID folder already created by the backend.
- Store preview assets in epoch folders:

```text
<project>/
  runs/
    <run_id>/
      previews/
        epoch_0001/
          input.png
          output.png
          target.png
          diff_absolute.png
          diff_heatmap.png
```

- Use `run_id`, not the human run name, because run IDs are stable and filesystem-safe while names can be duplicated or edited.
- Save `diff_absolute.png`, `diff_heatmap.png`, or both according to the run's selected diff mode.
- Generate the sample from validation data when validation is enabled and available.
- Fall back to the first training sample when validation is disabled, validation split is `0.0`, or no validation samples exist.
- Return preview metadata with stable file URLs so the frontend can display saved files without refetching every second.

### Inference Tab Stability
- Fix Inference dropdowns so selected values are always either `null` or exactly one value from the current item list.
- Avoid object identity and map equality problems in dropdown values by using stable scalar IDs/options.
- Keep the tab usable when checkpoints, runs, devices, or tiling options load asynchronously.

## Capabilities

### Modified Capabilities
- `live-metrics`: Persist epoch-scoped preview image artifacts and expose stable preview metadata.
- `inference-workflow`: Ensure Inference tab dropdown state remains valid as source lists change.

## Impact

- **Backend**: preview generation/storage in `backend/src/sr_tuner_api/metrics.py` and training preview calls in `backend/src/sr_tuner_api/main.py`.
- **Backend API**: preview metadata and preview asset routes may need epoch-aware URLs while preserving current latest-preview behavior.
- **Frontend**: `lib/src/workspace/live_metrics_tab.dart`, `lib/src/project_models.dart`, and `lib/src/workspace/inference_tab.dart`.
- **Tests**: backend API tests for saved preview folders and Flutter widget/model tests for dropdown safety and preview metadata parsing.
