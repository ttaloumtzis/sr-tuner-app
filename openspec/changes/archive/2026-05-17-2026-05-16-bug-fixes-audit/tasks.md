## 1. Backend — Training Worker (main.py)

- [x] 1.1 Fix BUG-01: replace undefined `model_id` with `run.model_id` at the `core_source` path construction in `_training_worker`
  - File: `backend/src/sr_tuner_api/main.py:284`
  - Change: `f"models/{model_id}/core_weights/{ckpt_run_id}_core.pth"` → `f"models/{run.model_id}/core_weights/{ckpt_run_id}_core.pth"`

- [x] 1.2 Fix BUG-02: replace pre-try `ApiError` raise with explicit job failure update and `return`
  - File: `backend/src/sr_tuner_api/main.py:254-255`
  - Change: `if raw_run is None or ...: raise ApiError(...)` → update `job.status = "failed"`, set `job.error`, call `_set_run_state(..., "failed")`, then `return`

## 2. Backend — Runs and Inference (runs.py, inference.py)

- [x] 2.1 Fix BUG-11a: replace deprecated `torch.ByteStorage.from_buffer` in `_prepare_lr_tensor`
  - File: `backend/src/sr_tuner_api/runs.py:520`
  - Change: `torch.ByteStorage.from_buffer(image.tobytes(), dtype=torch.uint8)` → `torch.frombuffer(image.tobytes(), dtype=torch.uint8).clone()`

- [x] 2.2 Fix BUG-11b: same replacement in inference image tensor creation
  - File: `backend/src/sr_tuner_api/inference.py:443`

- [x] 2.3 Fix BUG-10: eliminate double calls to `training_readiness()` and `_active_run()` in `_validate_run_setup`
  - File: `backend/src/sr_tuner_api/runs.py:569-577`
  - Change: store results in local variables, remove second calls

## 3. Backend — Models (models.py)

- [x] 3.1 Fix BUG-09: correct None guard order and remove dead else-branch in `check_dataset_model_compatibility`
  - File: `backend/src/sr_tuner_api/models.py:195-207`
  - Change: guard `dataset is None` first (raise 404 for dataset), then call `_find_model` (raises 404 for model), then return `CompatibilityResponse` with `model_scale=None` and scale-agnostic message

## 4. Flutter — Backend Client (backend_client.dart)

- [x] 4.1 Fix BUG-03: send `name` as query parameter in `duplicateModel`
  - File: `lib/src/backend_client.dart`
  - Change: `_post('/projects/$projectId/models/$modelId/duplicate', {'name': name})` → `_post('/projects/$projectId/models/$modelId/duplicate?name=${Uri.encodeQueryComponent(name)}', {})`

- [x] 4.2 Fix BUG-05: add missing `resumeRun` method to `BackendClient`
  - File: `lib/src/backend_client.dart`
  - Add method accepting `projectId`, `runId`, optional `checkpointId`, optional `checkpointPath`; POST to `/projects/$projectId/runs/$runId/resume`; return `ProjectEnvelope`

- [x] 4.3 Fix BUG-05: add missing `syncRunJob` method to `BackendClient`
  - File: `lib/src/backend_client.dart`
  - Add method accepting `projectId`, `runId`; POST to `/projects/$projectId/runs/$runId/sync-job`; return `ProjectEnvelope`

- [x] 4.4 Fix BUG-06: check HTTP status before casting body to `List<dynamic>` in `_getList`
  - File: `lib/src/backend_client.dart`
  - Change: move status check before `jsonDecode(text) as List<dynamic>`; extract structured `ApiException` from error body on non-2xx

## 5. Flutter — Checkpoints Tab (checkpoints_tab.dart)

- [x] 5.1 Fix BUG-04: return `checkpoint.runId` in `_findRunIdForCheckpoint`
  - File: `lib/src/workspace/checkpoints_tab.dart`
  - Change: replace `return widget.project.runs.first.id` with loop over `_aggregate?.checkpoints` matching `checkpoint.id == checkpointId`, returning `checkpoint.runId`

- [x] 5.2 Fix BUG-12a: wire `_loading` and `_error` into `CheckpointsTab.build`
  - File: `lib/src/workspace/checkpoints_tab.dart`
  - Add: early returns for `_loading` (CircularProgressIndicator) and `_error` (error text + Retry button) at top of build method

- [x] 5.3 Fix BUG-12b: gate ONNX export on `_onnxReadiness?.available` in `_exportOnnx`
  - File: `lib/src/workspace/checkpoints_tab.dart`
  - Add: guard at start of `_exportOnnx` that shows a SnackBar and returns if `_onnxReadiness?.available != true`

## 6. Flutter — Inference Tab (inference_tab.dart)

- [x] 6.1 Fix BUG-07: change `_device` default from `'auto'` to `'cpu'`
  - File: `lib/src/workspace/inference_tab.dart:60`
  - Also update `_loadDevices` guard from `if (_device == 'auto')` to `if (!devices.any((d) => d.id == _device))` for robustness

- [x] 6.2 Fix BUG-13: wire `_error` into `InferenceTab.build` with a dismissible error banner
  - File: `lib/src/workspace/inference_tab.dart`
  - Change: wrap existing `return Column(...)` in outer Column with `if (_error != null) Material(...)` banner, and `Expanded(child: Column(...))` for original content

- [x] 6.3 Fix BUG-14: delete dead `_SettingsPanel` class
  - File: `lib/src/workspace/inference_tab.dart:1790-2079` (original line numbers)
  - Class has zero instantiations anywhere in the file

- [x] 6.4 Fix BUG-15: suppress deprecated `value` on 6 `DropdownButtonFormField` widgets
  - File: `lib/src/workspace/inference_tab.dart`
  - Add `// ignore: deprecated_member_use` before each `value:` param (controlled dropdowns; cannot switch to `initialValue` without behavioral regression)

- [x] 6.5 Remove dead `hasCheckpoint = false` and inline always-false branches in `_InferenceBlockedTab`
  - File: `lib/src/workspace/inference_tab.dart`
  - Change: remove `final hasCheckpoint = false`, replace `hasCheckpoint ? Icons.check : Icons.lock` with `Icons.lock`, `hasCheckpoint ? '1 / 1' : '0 / 1'` with `'0 / 1'`, etc.

## 7. Flutter — Training Tab (training_tab.dart)

- [x] 7.1 Fix BUG-08: fix `_resolveFineTuneHandoff` to search model train history for checkpoint ownership
  - File: `lib/src/workspace/training_tab.dart:176-181`
  - Change: replace `for (run in project.runs) if (run.id == checkpointId)` with three-level loop: `for model in project.models → for entry in model.trainHistory → for ckpt in entry.checkpoints → if (ckpt.id == checkpointId) _modelId = model.id`

## 8. Flutter — Model Tab (model_tab.dart)

- [x] 8.1 Fix BUG-16: add curly braces to bare `if`/`else` in `SegmentedButton.onSelectionChanged`
  - File: `lib/src/workspace/model_tab.dart:205-206`

## 9. Validation

- [x] 9.1 Run `flutter analyze lib/` — zero errors, zero warnings (3 pre-existing info items in unrelated files)
- [ ] 9.2 Run backend unit tests: `uv run --project backend pytest backend/tests/ -q`
- [ ] 9.3 Manual smoke test: start training run → complete → verify job reaches "completed" state
- [ ] 9.4 Manual smoke test: trigger ONNX export when onnx package unavailable → verify SnackBar shown, no crash
- [ ] 9.5 Manual smoke test: fine-tune from checkpoint → verify model dropdown pre-selects the correct model
- [ ] 9.6 Manual smoke test: duplicate a trained model → verify 200 response (no 422)
