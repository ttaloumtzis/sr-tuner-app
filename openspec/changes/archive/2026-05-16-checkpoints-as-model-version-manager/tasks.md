# Implementation Tasks

## Backend

### B1: Add model_id to CheckpointMetadata
- **File**: `backend/src/sr_tuner_api/checkpoints.py`
- **Change**: Add `model_id: str = ""` field to `CheckpointMetadata` class
- **Test**: Verify checkpoint JSON round-trips with new field

### B2: Add core_checkpoint_id and core_run_id to ModelObject
- **File**: `backend/src/sr_tuner_api/models.py`
- **Change**: Add `core_checkpoint_id: str = ""` and `core_run_id: str = ""` to `ModelObject`
- **Test**: Verify model serialization round-trips

### B3: Update _extract_core_weights_after_training to set core IDs
- **File**: `backend/src/sr_tuner_api/main.py`
- **Change**: After extracting core weights, only set `raw_model["core_checkpoint_id"]` and `raw_model["core_run_id"]` if they are currently empty (first training only). Leave them untouched on subsequent trainings — the user manually promotes via set-core.
- **Test**: First training -> core IDs set. Second training -> core IDs unchanged.

### B4: Copy .pth files to model folder during archive
- **File**: `backend/src/sr_tuner_api/main.py`
- **Change**: In `_archive_run_to_model()`, after appending trainHistory entry:
  1. Create `models/{modelId}/archived_checkpoints/{sessionId}/`
  2. For each checkpoint in the run's checkpoints:
     - Copy `.pth` from `runs/{runId}/checkpoints/{filename}` to `models/{modelId}/archived_checkpoints/{sessionId}/{filename}`
     - Update the `path` in the checkpoint metadata dict to point to the new location
  3. Write the updated project.json
- **Test**: Archive a run -> verify files exist in model folder -> verify checkpoint paths updated

### B5: Fix inference.py model-based path (BUG FIX)
- **File**: `backend/src/sr_tuner_api/inference.py`
- **Change**: In `_infer_single()`, strip `body.` prefix before `load_state_dict`:
  ```python
  adjusted = {k.removeprefix("body."): v for k, v in core_state.items()}
  model.body.load_state_dict(adjusted, strict=False)
  ```
- **Test**: Run model-based inference -> verify no RuntimeError -> verify output image created

### B6: New endpoint POST /.../set-core
- **File**: `backend/src/sr_tuner_api/main.py`
- **Endpoint**: `POST /projects/{project_id}/models/{model_id}/checkpoints/{run_id}/{checkpoint_id}/set-core`
- **Logic**:
  1. Find checkpoint in model's `trainHistory` by id (resolve path from any session)
  2. Call `extract_and_save_core_weights(checkpoint_path, project_root, model_id, run_id)`
  3. Set `model.core_checkpoint_id = checkpoint_id`
  4. Set `model.core_run_id = run_id`
  5. Set `model.trained_core_weights_path = stored_path`
  6. Set `model.status = "trained"`
  7. Write `project.json`, return `ProjectResponse`
- **Test**: POST with valid params -> core weights saved, model updated

### B7: New endpoint DELETE /.../delete-archived-checkpoint
- **File**: `backend/src/sr_tuner_api/main.py`
- **Endpoint**: `DELETE /projects/{project_id}/models/{model_id}/checkpoints/{checkpoint_id}`
- **Logic**:
  1. Find checkpoint in `model.train_history[*].checkpoints` by id
  2. Delete the `.pth` file at the checkpoint's stored path from the model-owned directory
  3. Remove that entry from its session's checkpoints list
  4. If session has no more checkpoints, remove the session too
  5. Write project.json, return `ProjectResponse`
- **Test**: Delete checkpoint -> verify removed from model's trainHistory -> verify .pth file deleted from model-owned dir

### B8: New endpoint DELETE /.../delete-archived-session
- **File**: `backend/src/sr_tuner_api/main.py`
- **Endpoint**: `DELETE /projects/{project_id}/models/{model_id}/sessions/{session_id}`
- **Logic**:
  1. Find session in `model.train_history` by `sessionId` (= run_id)
  2. Delete `models/{model_id}/archived_checkpoints/{session_id}/` directory (all .pth files)
  3. Remove the session entry from model.train_history
  4. Write project.json, return `ProjectResponse`
- **Test**: Delete session -> verify removed from model's trainHistory -> verify archived dir deleted

### B9: New endpoint POST /.../export-package
- **File**: `backend/src/sr_tuner_api/main.py`
- **Endpoint**: `POST /projects/{project_id}/models/{model_id}/checkpoints/{run_id}/{checkpoint_id}/export-package`
- **Logic**:
  1. Load checkpoint .pth from stored path (model-owned after archive)
  2. Copy the **full state_dict** from checkpoint (not body-only)
  3. Build config.json (architecture, num_features, num_blocks, optimizer, scheduler, loss_weights)
  4. Build metadata.json (name, exported_at, source_project, source_model, core_checkpoint_id, core_run_id)
  5. Zip model.pth (full weights) + config.json + metadata.json
  6. Auto-generate filename: `{model_name}_{export_date}.zip`
  7. Return Job
- **Test**: Export -> verify .zip contains model.pth (full state_dict), config.json, metadata.json

### B10: New endpoint POST /.../import-model-package
- **File**: `backend/src/sr_tuner_api/main.py`
- **Endpoint**: `POST /projects/{project_id}/import-model-package`
- **Note**: Add `from fastapi import UploadFile` to imports
- **Logic**:
  1. Receive uploaded .zip file
  2. Extract to temp dir
  3. Read config.json -> create ModelObject
  4. Save model.pth as `models/{new_id}/core_weights/imported_core.pth`
  5. Create TrainHistoryEntry with session_id="imported", include metadata about source
  6. Append to model.train_history, write project.json
  7. Return ProjectResponse
- **Test**: Import -> verify model created with correct params

## Frontend

### F1: Add coreCheckpointId and coreRunId to ModelSummary
- **File**: `lib/src/project_models.dart`
- **Change**: Add `final String? coreCheckpointId;` and `final String? coreRunId;` fields
- **Test**: Parse JSON with new fields -> verify populated

### F2: Add backend client methods
- **File**: `lib/src/backend_client.dart`
- **Changes**:
  - `setCheckpointAsCore(projectId, modelId, runId, checkpointId)` -> ProjectEnvelope
  - `exportModelPackage(projectId, modelId, runId, checkpointId, destination)` -> JobState
  - `deleteArchivedCheckpoint(projectId, modelId, checkpointId)` -> ProjectEnvelope
  - `deleteArchivedSession(projectId, modelId, sessionId)` -> ProjectEnvelope
  - `importModelPackage(projectId, filePath)` -> ProjectEnvelope (multipart upload)
- **Test**: Mock HTTP -> verify correct URLs and body

### F3: Rewrite checkpoints_tab.dart
- **File**: `lib/src/workspace/checkpoints_tab.dart`
- **Changes**:

  **F3a: Constructor - add onProjectChanged**
  - Add `required this.onProjectChanged` of type `ValueChanged<ProjectState>`
  - Wire to project_workspace.dart

  **F3b: State and initState**
  - Remove `_aggregate`, `_selectedForComparison`, `_onnxReadiness` state vars
  - Add `_selectedModel` (ModelSummary?), `_sidebarWidth` (double, default 220)
  - `initState`: auto-select first model with non-empty `trainHistory`
  - Add `@override didUpdateWidget` to update selection when project changes

  **F3c: Build method**
  - Replace current build with sidebar + detail layout
  - Error/loading/empty states preserved

  **F3d: _ModelSidebar widget**
  - Resizable sidebar (220px default, 160-320 range)
  - List of model cards: name, status chip, "N runs · N checkpoints"
  - Selected model highlight with accent border
  - "Import Model Package" button at bottom
  - Drag handle on right edge for resize (GestureDetector + setState)

  **F3e: _ModelDetailHeader widget**
  - Model name, status chip, core checkpoint info
  - Action buttons: [Infer from Core] [Fine-tune] [Export Package] [Export ONNX]

  **F3f: _RunCard widget (collapsible)**
  - Collapsed by default (all runs collapsed)
  - Header: dataset name, scale, epochs, best PSNR, [Delete session]
  - Expanded: checkpoint rows
  - Delete button calls `deleteArchivedSession` with confirmation

  **F3g: _CheckpointRow widget (simplified)**
  - Checkbox for multi-select, epoch, PSNR, SSIM, tags
  - "★ CORE" badge if `checkpoint.id == model.coreCheckpointId`
  - PopupMenuButton: Set as Core, Infer, Fine-tune, Export PTH, Export ONNX, Export Package, Delete
  - "Set as Core" calls `setCheckpointAsCore` with confirmation -> `onProjectChanged`
  - "Export PTH" copies from `checkpoint.path` directly (File().copy(), no API call)
  - Delete calls `deleteArchivedCheckpoint` with confirmation -> `onProjectChanged`

  **F3h: _CheckpointsFooter (simplified)**
  - "N selected" [Delete Selected]
  - [Export Best PTH] [Export Best ONNX]

  **F3i: Remove old widgets**
  - Remove: `_AggregateHeader`, `_PsnrStrip`, `_CheckpointTable`, `_ComparisonFooter`,
    `_LegacyCheckpointList`, `_ModelSessionGroup`, `_TrainingSessionCard`,
    `_SessionCheckpointRow`, `_findRunIdForCheckpoint()`
  - Keep: `_TagChip`, `_EmptyCheckpoints` (rewrite for new context),
    `_fmtMetric`, `_fmtTime`, `_fmtSize` helpers

### F4: Update project_workspace.dart
- **File**: `lib/src/workspace/project_workspace.dart`
- **Change**: Add `onProjectChanged` callback to `CheckpointsTab` constructor call:
  ```dart
  CheckpointsTab(
    client: widget.client,
    project: widget.project,
    onProjectChanged: (project) => setState(() { widget.project = project; }),
    ...
  )
  ```
- **Test**: Verify checkpoints tab can trigger project state refresh

## Testing

### T1: Run backend tests
```bash
uv run --project backend pytest backend/tests/ -q
```
- Verify all existing tests pass
- Add tests for new endpoints if applicable

### T2: Run flutter analyze
```bash
flutter analyze lib/src/workspace/checkpoints_tab.dart
```
- Verify no errors, no new warnings

## Order of Implementation

```
B1 → B2 → F1     (data model, can be parallel)
  ↓
B3               (update core extraction)
  ↓
B4               (archive file copying)
  ↓
B5               (fix inference.py bug)
  ↓
B6 → B7 → B8     (core API endpoints, can be parallel)
  ↓
B9 → B10         (export/import endpoints, can be parallel)
  ↓
F2               (frontend API client)
  ↓
F3a → F3b → F3c  (state + build + sidebar)
  ↓
F3d → F3e → F3f  (header + run card + checkpoint row)
  ↓
F3g → F3h → F3i  (footer + cleanup)
  ↓
F4               (wire onProjectChanged)
  ↓
T1 → T2          (testing)
```
