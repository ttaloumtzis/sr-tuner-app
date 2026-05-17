## Context

### Bug Inventory

| ID | Severity | File | Description |
|----|----------|------|-------------|
| BUG-01 | Critical | `main.py:284` | `NameError: name 'model_id' is not defined` in `_training_worker` — never assigned in function scope |
| BUG-02 | Critical | `main.py:254-255` | `ApiError` raised before try/except block causes silent thread death; job stays stuck in "running" |
| BUG-03 | High | `backend_client.dart` | `duplicateModel` sends `name` in POST body; FastAPI binds scalar POST params without annotation as query params → 422 |
| BUG-04 | High | `checkpoints_tab.dart` | `_findRunIdForCheckpoint` returns `widget.project.runs.first.id` for every checkpoint instead of the checkpoint's own `runId` |
| BUG-05 | High | `backend_client.dart` | `resumeRun` and `syncRunJob` are called from UI widgets but missing from `BackendClient` |
| BUG-06 | High | `backend_client.dart` | `_getList` casts response body to `List<dynamic>` before HTTP status check → `CastError` on any non-2xx response |
| BUG-07 | Medium | `inference_tab.dart:60` | `_device` initialised to `'auto'` which is not a valid backend device ID |
| BUG-08 | Medium | `training_tab.dart:177` | `_resolveFineTuneHandoff` loops `if (run.id == checkpointId)` — run IDs and checkpoint IDs are different; `_modelId` never set |
| BUG-09 | Medium | `models.py:195-207` | `check_dataset_model_compatibility` had model lookup before dataset None check → wrong 404 message or crash when model exists but dataset doesn't |
| BUG-10 | Low | `runs.py:569-577` | `_validate_run_setup` called `training_readiness()` and `_active_run()` twice each; redundant I/O |
| BUG-11 | Medium | `runs.py:520`, `inference.py:443` | `torch.ByteStorage.from_buffer` removed in PyTorch 2.x → `AttributeError` at runtime |
| BUG-12 | Medium | `checkpoints_tab.dart` | `_loading` / `_error` state fields declared but never read in `build()`; `_onnxReadiness` fetched but export not gated on it |
| BUG-13 | Medium | `inference_tab.dart` | `_error` field declared but never displayed; build method returns raw Column with no error path |
| BUG-14 | Low | `inference_tab.dart:1790` | `_SettingsPanel` class (290 lines) defined but never instantiated anywhere in the file |
| BUG-15 | Info | `inference_tab.dart` | 6× `DropdownButtonFormField.value` deprecated after Flutter v3.33.0 |
| BUG-16 | Info | `model_tab.dart:205-206` | Bare `if`/`else` without curly braces in `onSelectionChanged` callback |

### Root Cause Patterns

**Pattern A — Variable scoping error (BUG-01):** The `_training_worker` function receives `model_id` as a key in a `kwargs` dict but the code references it as a local name that was never assigned. This is a straightforward typo (`model_id` → `run.model_id`) that went undetected because the function runs in a daemon thread with no automatic error surfacing.

**Pattern B — Error handling architecture (BUG-02):** The training worker raises `ApiError` before the `try/except` block that would catch it and update the job to "failed". The correct pattern for background thread errors is to update job state directly and `return`, not to raise.

**Pattern C — FastAPI parameter binding (BUG-03):** FastAPI binds scalar POST body values only when annotated with `Body()`. Without annotation, scalars are treated as query parameters. The `duplicate` endpoint uses `name: str` as a plain param → it's a query param. The client was posting it in the JSON body.

**Pattern D — ID space confusion (BUG-04, BUG-08):** Two independent bugs compare IDs from different namespaces. BUG-04 returns the first run's ID for every checkpoint. BUG-08 checks `run.id == checkpointId` — these are prefixed differently (`run_xxx` vs `ckpt_xxx`) and can never match.

**Pattern E — Cast before status check (BUG-06):** The `_getList` helper decoded the response body as `List<dynamic>` before confirming HTTP 2xx. Error responses are `{"error": {...}}` maps, not lists → `TypeError` on any backend error.

**Pattern F — PyTorch breaking change (BUG-11):** `torch.ByteStorage.from_buffer()` was removed in PyTorch 2.0. The replacement is `torch.frombuffer(bytes, dtype=torch.uint8).clone()`.

## Decisions

### D1: BUG-02 — Job failure, not exception raise

**Decision:** Replace `raise ApiError(...)` before the try block with an explicit job state update (`job.status = "failed"`) followed by `return`.

**Rationale:** Background threads cannot propagate exceptions to callers. The job store is the channel for communicating failure. Raising before the try/except block was already wrong — it bypassed all cleanup code. The fix matches the pattern used by all other error paths inside the try block.

### D2: BUG-08 — Search model train history for checkpoint ownership

**Decision:** Replace the broken `run.id == checkpointId` loop with a three-level search: `models → train_history → checkpoints → ckpt.id == checkpointId`.

**Rationale:** `CheckpointSummary.runId` gives us the run's ID from the checkpoint. But in `_resolveFineTuneHandoff` we only have the checkpoint ID and need the model ID. The `ModelSummary.trainHistory[].checkpoints[]` tree already contains `CheckpointSummary` objects with their IDs, so this search is O(total_checkpoints) at most. Alternative: add model ID to the fine-tune handoff payload. Rejected — changes the widget API surface; searching train history costs nothing.

### D3: BUG-15 — Suppress deprecated_member_use rather than migrate to initialValue

**Decision:** Add `// ignore: deprecated_member_use` before each `DropdownButtonFormField.value:` usage.

**Rationale:** `DropdownButtonFormField.value` controls the displayed selection on every rebuild (parent state drives it). `initialValue` is only read in `FormFieldState.initState`, so it does not update when the parent rebuilds with a new value. Migrating to `initialValue` without adding `key: ValueKey(value)` to force widget recreation on each rebuild would cause the displayed value to diverge from the parent's state after any programmatic change. The behavioral regression outweighs the lint noise. The suppression comments are precise and document the reason.

### D4: BUG-14 — Delete _SettingsPanel entirely

**Decision:** Delete the entire `_SettingsPanel` class rather than fixing or converting it.

**Rationale:** The class has zero references in the file. It was superseded by `_InferenceHeader` + `_OutputInspector` in an earlier refactor but never removed. 290 lines of dead code including its own deprecated `value:` usages and duplicate logic. Deletion is safe — no runtime risk.

### D5: BUG-12 / BUG-13 — Wire error state into build methods

**Decision:** Add error banner at the top of both `CheckpointsTab.build` and `InferenceTab.build`. In `CheckpointsTab`, also wrap the build in a loading guard. In `InferenceTab`, use `Expanded(child: Column(...))` to wrap the existing content so the sticky banner doesn't shrink the main content.

**Rationale:** State fields `_loading` and `_error` were written but never read. Users saw no feedback on failures. The banner pattern (Material container + dismissible close button) is consistent with `SrBanner` usage elsewhere in the app.

## Risks / Trade-offs

### R1: BUG-02 — Job state update concurrency

**Risk:** The training worker updates job state from a background thread without a lock.

**Mitigation:** This is the same pattern used throughout the existing code. The job store is a dict protected by Python's GIL for simple reads/writes. No new risk introduced.

### R2: BUG-08 — Train history search cost

**Risk:** If a project has many models each with many training sessions and checkpoints, the three-level search in `_resolveFineTuneHandoff` could be slow.

**Mitigation:** This runs once on widget initialization (not on every rebuild). In practice, a project will have tens of checkpoints at most. The O(n) scan is acceptable.

### R3: BUG-13 — Expanded wrapper depth

**Risk:** Adding `Expanded(child: Column(...))` around the existing content increases widget tree depth, which could affect layout.

**Mitigation:** The wrapping only adds one level of `Expanded` + `Column` around content that was already inside a `Column`. The outer Column is flex-based; `Expanded` ensures the inner content fills available space after the optional error banner takes its height.
