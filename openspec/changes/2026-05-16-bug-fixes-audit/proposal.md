## Why

A comprehensive full-stack code audit of the SR-Tuner codebase (Flutter frontend + FastAPI/PyTorch backend) identified 16 bugs ranging from critical runtime crashes to silent data corruption and dead UI code. Left unaddressed, these bugs cause:

1. **Silent training failures**: The `_training_worker` thread dies with an unhelpful stack trace and leaves the job stuck in "running" state
2. **Broken 422 errors on model import**: The `duplicateModel` client call sends `name` in the POST body; FastAPI expects it as a query parameter
3. **Wrong checkpoint operations**: The checkpoint tab looks up run IDs by comparing them against checkpoint IDs — a comparison that can never match
4. **Missing API client methods**: `resumeRun` and `syncRunJob` are used in the UI but not implemented in `BackendClient`
5. **Crash on backend errors from list endpoints**: `_getList` blindly casts the response body to `List<dynamic>` before checking HTTP status, causing `CastError` on any non-2xx response
6. **Fine-tune handoff broken**: `_resolveFineTuneHandoff` searches for a run whose ID equals the checkpoint ID — these are different ID spaces, so `_modelId` is never set
7. **Deprecated PyTorch API**: `torch.ByteStorage.from_buffer` was removed in PyTorch 2.x; it's used in two places during training and inference
8. **Dead code and UI warnings**: An unused `_SettingsPanel` class (290 lines), hardcoded dead `hasCheckpoint = false` branches, and 6 deprecated `value:` usages generate flutter analyze warnings

## What Changes

1. **`main.py` — training worker crash fixes**
   - Fix `NameError: model_id` by replacing the undefined name with `run.model_id`
   - Replace the pre-try `ApiError` raise with a proper job failure path so the thread exits cleanly

2. **`runs.py` — PyTorch deprecation + double calls**
   - Replace `torch.ByteStorage.from_buffer(image.tobytes(), dtype=torch.uint8)` with `torch.frombuffer(image.tobytes(), dtype=torch.uint8).clone()`
   - Eliminate two redundant calls to `training_readiness()` and `_active_run()` in `_validate_run_setup`

3. **`inference.py` — PyTorch deprecation**
   - Same `torch.ByteStorage` → `torch.frombuffer` fix as in runs.py

4. **`models.py` — compatibility check dead branch**
   - Fix `None` guard order in `check_dataset_model_compatibility` to raise 404 when dataset is not found
   - Remove unreachable `else` branch with an incorrect message

5. **`backend_client.dart` — three Flutter client fixes**
   - `duplicateModel`: send `name` as query parameter, not in POST body
   - Add missing `resumeRun` and `syncRunJob` methods
   - `_getList`: check HTTP status before casting body to `List<dynamic>`

6. **`checkpoints_tab.dart` — two UI fixes**
   - `_findRunIdForCheckpoint`: return `checkpoint.runId` instead of `widget.project.runs.first.id`
   - Wire `_loading` / `_error` into the build method; gate ONNX export on `_onnxReadiness?.available`

7. **`inference_tab.dart` — four UI fixes**
   - Change `_device` default from `'auto'` (invalid) to `'cpu'`
   - Wire `_error` into the build method with a dismissible error banner
   - Remove 290-line dead `_SettingsPanel` class that was never instantiated
   - Suppress 6 `deprecated_member_use` warnings on `DropdownButtonFormField.value` (controlled dropdowns that cannot be converted to `initialValue` without behavioral regression)
   - Remove `final hasCheckpoint = false` and inline its always-false value in the `_InferenceBlockedTab` prerequisite list

8. **`training_tab.dart` — fine-tune handoff fix**
   - Replace `if (run.id == checkpointId)` (wrong ID space) with a search through `widget.project.models[].trainHistory[].checkpoints` to find the model that owns the checkpoint

9. **`model_tab.dart` — style/safety fix**
   - Add curly braces to the bare `if`/`else` in the `SegmentedButton.onSelectionChanged` callback

## Capabilities

### Modified Capabilities

- `training-run`: Training worker no longer silently dies; job state is correctly set to "failed" when context is missing at startup
- `inference`: Inference image tensor creation uses the current PyTorch API
- `model-management`: `check_dataset_model_compatibility` correctly returns 404 for missing datasets
- `checkpoint-management`: Checkpoint operations use the correct run ID lookup
- `model-import-with-weights`: `duplicateModel` call now sends the name in the correct location

## Impact

**Backend:**
- `backend/src/sr_tuner_api/main.py`: Two training worker crash paths fixed
- `backend/src/sr_tuner_api/runs.py`: PyTorch API + double-call cleanup
- `backend/src/sr_tuner_api/inference.py`: PyTorch API fix
- `backend/src/sr_tuner_api/models.py`: Compatibility check None guard

**Frontend:**
- `lib/src/backend_client.dart`: Three API call correctness fixes + two new methods
- `lib/src/workspace/checkpoints_tab.dart`: Run ID lookup + loading/error wiring + ONNX gate
- `lib/src/workspace/inference_tab.dart`: Device default + error banner + dead code removal + lint fixes
- `lib/src/workspace/training_tab.dart`: Fine-tune handoff lookup corrected
- `lib/src/workspace/model_tab.dart`: Style fix on if/else
