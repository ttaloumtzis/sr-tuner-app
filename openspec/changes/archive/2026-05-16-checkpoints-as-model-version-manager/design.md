# Design: Checkpoints as Model Version Manager

## Backend Changes

### Data Model (`backend/src/sr_tuner_api/models.py`)

Add fields to `ModelObject`:

```python
core_checkpoint_id: str = ""
core_run_id: str = ""
trained_core_weights_path: str | None = None   # existing
```

Also update `_extract_core_weights_after_training()` in `main.py` to populate
`core_checkpoint_id` and `core_run_id` **only on the first training run**.
If these fields are already set (subsequent training), they are NOT overwritten.
Users promote a different checkpoint via the set-core endpoint.

### New Backend API Endpoints

All in `backend/src/sr_tuner_api/main.py`:

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/projects/{pid}/models/{mid}/checkpoints/{rid}/{cid}/set-core` | Promote checkpoint to core |
| POST | `/projects/{pid}/models/{mid}/checkpoints/{rid}/{cid}/export-package` | Zip weights + config + metadata |
| POST | `/projects/{pid}/import-model-package` | Upload .zip to create model |
| DELETE | `/projects/{pid}/models/{mid}/checkpoints/{cid}` | Remove checkpoint from trainHistory |
| DELETE | `/projects/{pid}/models/{mid}/sessions/{sessionId}` | Remove entire session from trainHistory |

**set-core endpoint logic:**
1. Receive `model_id`, `run_id`, `checkpoint_id`
2. Resolve checkpoint path from model's `trainHistory` entries (after archive fix, path points to `models/{id}/archived_checkpoints/{sessionId}/`)
3. Call `extract_and_save_core_weights(checkpoint_path, project_root, model_id, run_id)`
4. Set `model.core_checkpoint_id = checkpoint_id`
5. Set `model.core_run_id = run_id`
6. Set `model.trained_core_weights_path = stored_path`
7. Set `model.status = "trained"`
8. Write `project.json`, return updated project state

**export-package endpoint logic:**
1. Receive `model_id`, `checkpoint_id`, `destination`
2. Load checkpoint `.pth` from its stored path (model-owned after archive)
3. Copy the **full state_dict** from the checkpoint file (not body-only — user
   confirmed full state_dict for exact reproduction)
4. Build `config.json` from `ModelObject`: architecture, num_features, num_blocks,
   optimizer (type/lr/betas), scheduler (type), loss_weights
5. Build `metadata.json`: name, exported_at, source_project, source_model,
   core_checkpoint_id, core_run_id
6. Create temp dir, write model.pth + config.json + metadata.json
7. Zip to destination path with filename `{model_name}_{date}.zip`
8. Return Job (completed)

**import-model-package endpoint logic:**
1. Receive uploaded `.zip` file (`UploadFile`)
2. Extract to temp dir
3. Read `config.json` → create `ModelObject` with those params
4. Read `model.pth` → save as `models/{new_id}/core_weights/imported_core.pth`
5. Create `trainHistory` entry marking session_id="imported", source metadata
6. Append to `model.train_history`, write project.json
7. Return updated project state

**delete-archived-checkpoint endpoint logic:**
1. Receive `model_id`, `checkpoint_id`
2. Find the checkpoint in `model.train_history[*].checkpoints`
3. Delete the `.pth` file from the model-owned directory
   (`models/{modelId}/archived_checkpoints/{sessionId}/{filename}`)
4. Remove that entry from its session's checkpoints list. If session has no more checkpoints, remove the session too
5. Write project.json, return updated project state

**delete-archived-session endpoint logic:**
1. Receive `model_id`, `sessionId` (which is the run_id)
2. Find and remove the session from `model.train_history`
3. Delete all `.pth` files in `models/{modelId}/archived_checkpoints/{sessionId}/`
4. Remove the empty session directory
5. Write project.json, return updated project state

**Note**: These deletes remove both the `trainHistory` metadata AND the orphaned
`.pth` files from the model-owned directory. If the original run still exists,
its own checkpoint files under `runs/{runId}/checkpoints/` are untouched. This
mirrors what the spec already says: "Deleted checkpoint is referenced — mark
dependent actions unavailable."

### Archive checkpoint file preservation

Modify `_archive_run_to_model()` in `main.py` to physically copy `.pth` files
from the run's folder to a model-owned location:

1. After `_archive_run_to_model()` runs (when a training run completes successfully):
   - Create `models/{modelId}/archived_checkpoints/{sessionId}/` (sessionId = runId)
   - For each checkpoint in the run's checkpoints:
     - Copy the `.pth` file from `runs/{runId}/checkpoints/{filename}` to `models/{modelId}/archived_checkpoints/{sessionId}/{filename}`
     - Update the `path` field in the checkpoint metadata to point to the new location
2. The original `.pth` files in the run's folder remain intact
3. If the user later deletes the run config (`delete_run_config`), the run folder is removed
   but the model's copies survive

This ensures:
- Successful run checkpoints survive run deletion
- Failed run checkpoints are deleted with the run folder
- Export PTH, Set Core, Infer all work from model-owned paths

File layout after archive:
```
models/{modelId}/
  archived_checkpoints/{sessionId}/
    epoch_0010_iter_000320.pth
    epoch_0020_iter_000640.pth
    ...
  core_weights/
    {sessionId}_core.pth
```

### Fix inference.py model-based path (BUG FIX)

In `backend/src/sr_tuner_api/inference.py`, `_infer_single()` line ~370:

```python
# CURRENT (BROKEN):
model.body.load_state_dict(core_state)  # keys have "body." prefix

# FIXED:
adjusted = {k.removeprefix("body."): v for k, v in core_state.items()}
model.body.load_state_dict(adjusted, strict=False)
```

The core weights file contains keys with the `body.` prefix (from `extract_core_weights()`).
When loading into `model.body`, these keys must be relative to the Sequential module.
This is the same bug fixed in `main.py` for training — now also fix for inference.

**Impact**: Without this fix, "Infer from Core" and model-based inference from the
inference tab are broken (RuntimeError on load_state_dict).

### Export PTH

Export PTH copies a checkpoint's `.pth` file from its stored path on disk to a
user-chosen destination. This works directly from the file path — no need for a
run-based API endpoint:

**Frontend side** (no backend endpoint needed):
```dart
Future<void> _exportPth(CheckpointSummary checkpoint) async {
  final dest = await PathPicker().pickFolder(confirmButtonText: 'Export here');
  if (dest == null) return;
  final srcFile = File(checkpoint.path);
  final destPath = '$dest/${checkpoint.path.split('/').last}';
  await srcFile.copy(destPath);
}
```

The checkpoint path points to a file that exists either in:
- `runs/{runId}/checkpoints/` (if the run still exists)
- `models/{modelId}/archived_checkpoints/{sessionId}/` (if the run was archived)

## Frontend Changes

### Data Model (`lib/src/project_models.dart`)

Add to `ModelSummary`:
```dart
final String? coreCheckpointId;
final String? coreRunId;
```

Parse in `fromJson`:
```dart
coreCheckpointId: json['core_checkpoint_id'] as String?,
coreRunId: json['core_run_id'] as String?,
```

### API Client (`lib/src/backend_client.dart`)

New methods:
```dart
Future<ProjectEnvelope> setCheckpointAsCore({
  required String projectId,
  required String modelId,
  required String runId,
  required String checkpointId,
})

Future<JobState> exportModelPackage({
  required String projectId,
  required String modelId,
  required String runId,
  required String checkpointId,
  required String destination,
})

Future<ProjectEnvelope> importModelPackage({
  required String projectId,
  required String filePath,
})

Future<ProjectEnvelope> deleteArchivedCheckpoint({
  required String projectId,
  required String modelId,
  required String checkpointId,
})

Future<ProjectEnvelope> deleteArchivedSession({
  required String projectId,
  required String modelId,
  required String sessionId,
})
```

### Checkpoints Tab (`lib/src/workspace/checkpoints_tab.dart`)

**Constructor changes:**
```dart
class CheckpointsTab extends StatefulWidget {
  const CheckpointsTab({
    required this.client,
    required this.project,
    required this.onInferenceHandoff,
    required this.onProjectChanged,       // ← NEW
    this.onFineTuneHandoff,
    this.onNavigateToTab,
    super.key,
  });
}
```

Add `onProjectChanged` callback so set-core/delete operations can trigger a
project state refresh (which updates the sidebar model list, run counts, etc.).

**State (replaces `_aggregate`)**:
```dart
ModelSummary? _selectedModel;
double _sidebarWidth = 220;
```

**initState**: auto-select first model with non-empty `trainHistory`.

**Layout**:
```
Row
  _ModelSidebar(resizable)    ← 220px default, 160-320px range
  VerticalDivider(draggable)
  Expanded
    if _selectedModel == null
      _EmptyState
    else
      Column
        _ModelDetailHeader
        Expanded
          ListView
            _RunCard(collapsible) for each session
              _CheckpointRow for each checkpoint
        _CheckpointsFooter
```

**Widgets:**

- **_ModelSidebar** (StatefulWidget):
  - Width tracked in state with `_sidebarWidth` (default 220)
  - Right-edge `GestureDetector` for horizontal drag resize
  - `ListView` of model cards
  - Each card: model name, status chip, "N runs · N checkpoints"
  - Selected model highlighted with accent border
  - "Import Model Package" button at bottom

- **_ModelDetailHeader**:
  - Model name, status chip, "Core:" label showing which checkpoint is core
  - Action buttons row: [Infer from Core] [Fine-tune from Core] [Export Package] [Export ONNX]
  - "Infer from Core" navigates to inference tab with core checkpoint ID
    (inference tab builds model and loads core weights)

- **_RunCard** (StatefulWidget, collapsible):
  - Collapsed by default (all runs collapsed)
  - Header: dataset name, scale, epoch count, "PSNR: N dB ★" (if best), [Delete session]
  - Expanded: checkpoint rows
  - Delete calls `deleteArchivedSession` with confirmation dialog

- **_CheckpointRow** (StatelessWidget):
  - Checkbox for multi-select, epoch, PSNR, SSIM, tags
  - "★ CORE" badge if `checkpoint.id == model.coreCheckpointId`
  - PopupMenuButton: Set as Core, Infer, Fine-tune, Export PTH, Export ONNX, Export Package, Delete
  - "Set as Core" has confirmation dialog → calls `setCheckpointAsCore` → project refresh
  - "Export PTH" copies file from `checkpoint.path` directly (no API call needed)
  - Delete calls `deleteArchivedCheckpoint` with confirmation dialog

- **_CheckpointsFooter**:
  - "N selected" [Delete Selected]
  - [Export Best PTH] [Export Best ONNX]

### Empty state handling

When a model exists but has no `trainHistory`:
```
[Model name]     (untrained)
No training history yet.
Start training to create checkpoints.
[Start Training →]
```

### Project Workspace (`lib/src/workspace/project_workspace.dart`)

Update `CheckpointsTab` instantiation to pass `onProjectChanged`:
```dart
CheckpointsTab(
  client: widget.client,
  project: widget.project,
  onProjectChanged: (project) => setState(() => widget.project = project),
  onNavigateToTab: _navigateToTab,
  onInferenceHandoff: (checkpointId) { ... },
  onFineTuneHandoff: (checkpointId, coreWeightsPath) { ... },
)
```

## Removed Components

| Component | Lines | Reason |
|-----------|-------|--------|
| `_AggregateHeader` | ~80 | Replaced by model detail header |
| `_PsnrStrip` | ~60 | PSNR shown per-run instead |
| `_CheckpointTable` | ~100 | No flat table needed |
| `_ComparisonFooter` | ~70 | Simplified footer |
| `_LegacyCheckpointList` | ~45 | All data comes from trainHistory |
| `_ModelSessionGroup` | ~90 | Replaced by sidebar + detail |
| `_TrainingSessionCard` | ~110 | Replaced by run card |
| `_findRunIdForCheckpoint()` | ~8 | No longer needed — runId on each checkpoint |

## Data Flow Summary

```
project.models[N].trainHistory[N]     → _ModelSidebar (model list)
  ↓ user selects model
_selectedModel.trainHistory[N]        → _RunCard (collapsible, per session)
  ↓ user expands
session.checkpoints[N]                → _CheckpointRow
  ↓ user clicks "Set as Core"
POST /models/{mid}/checkpoints/{rid}/{cid}/set-core
  → extract_and_save_core_weights(checkpoint_path, ...)
  → model.core_checkpoint_id = ckptId
  → model.core_run_id = runId
  → model.trained_core_weights_path = stored
  → ProjectResponse → frontend rebuilds with new core badge

Core identification:
  final isCore = checkpoint.id == model.coreCheckpointId
              && checkpoint.runId == model.coreRunId;
```

## File Layout After Archive

```
models/{modelId}/
  archived_checkpoints/{sessionId}/
    epoch_0010_iter_000320.pth
    epoch_0020_iter_000640.pth
    ...
  core_weights/
    {sessionId}_core.pth
    ...
```

Checkpoint paths in `trainHistory` point to `models/{modelId}/archived_checkpoints/{sessionId}/`
after archiving. The original `runs/{runId}/checkpoints/` folder can be safely deleted
without affecting the model's checkpoints.
