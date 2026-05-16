## 1. Backend Data Model Changes

- [x] 1.1 Update ModelObject in `backend/src/sr_tuner_api/models.py`:
  - Remove `scale` from required fields (make optional with default None)
  - Add `trained_core_weights_path: str | None = None`
  - Add `train_history: list[TrainHistoryEntry] = []` — accumulates successful training sessions
  - Add `original_model_id: str | None = None`

- [x] 1.2 Add `TrainHistoryEntry` model class in `models.py`:
  ```python
  class TrainHistoryEntry(BaseModel):
      session_id: str              # run_id (for traceability)
      dataset_id: str
      dataset_name: str
      scale: int                   # training scale at time of this session
      started_at: str
      completed_at: str
      epochs: int
      best_metrics: dict           # {"val_psnr": ..., "val_ssim": ...}
      checkpoints: list[dict]      # CheckpointMetadata dicts
      best_checkpoint_id: str
  ```

- [x] 1.3 Update CreateModelRequest in `backend/src/sr_tuner_api/models.py`:
  - Remove `scale` parameter (will be derived from dataset at run time)

- [x] 1.4 Update ModelSummary in `lib/src/project_models.dart`:
  - Add `trainedCoreWeightsPath: String?` field
  - Add `trainHistory: List<TrainHistoryEntry>?` field
  - Update `fromJson` to parse new fields

- [x] 1.5 No legacy model handling needed (per user request - existing projects will be deleted)

## 2. Core Weight Extraction

- [x] 2.1 Create `extract_core_weights()` function in `backend/src/sr_tuner_api/checkpoints.py`:
  ```python
  def extract_core_weights(checkpoint_path: Path, model_id: str) -> tuple[dict, dict]:
      """Extract core weights (exclude first_conv head and last_conv tail)."""
  ```

- [x] 2.2 Define layer identification for `internal_residual_pixelshuffle`:
  - Head (first conv): `nn.Conv2d(3, num_features, 3, padding=1)` - weight shape `(num_features, 3, 3, 3)`
  - Tail (last conv): `nn.Conv2d(num_features, 3 * scale * scale, 3, padding=1)` + `nn.PixelShuffle(scale)`
  - Core = residual blocks between head and tail
  - Layer key naming: head key is `head.0.weight` (actually just `head.weight` since head is a single Conv2d, not Sequential), body keys match `body.{i}.body.{j}` pattern, tail keys are `tail.0.weight` and `tail.0.bias` (tail is Sequential wrapping Conv2d + PixelShuffle)

- [x] 2.3 Create function to save core weights to `models/<model_id>/core_weights/best_core.pth`:
  - Create directory if not exists
  - Save state_dict with only core weights

- [x] 2.4 Add metadata JSON sidecar `models/<model_id>/core_weights/best_core.json`:

- [x] 2.5 Test core weight extraction on a checkpoint

## 3. Training Pipeline Integration

- [x] 3.1 Update run creation in `backend/src/sr_tuner_api/runs.py:200` (`create_run()`):
  - Derive scale from dataset: `dataset.validated_scale or dataset.scale`
  - Store in run metadata: `"dataset_scale": dataset_scale` (already exists)
  - Remove `model.scale` from metadata (model no longer has scale)

- [x] 3.2 Modify model builder in `backend/src/sr_tuner_api/runs.py:469-483` (`build_internal_sr_model()`):
  - Accept `scale` as required parameter (from dataset, not model)
  - Build head and tail dynamically with the provided scale
  - No change needed — build_internal_sr_model already takes scale as parameter

- [x] 3.3 Add core weight extraction to `_training_worker()` in `backend/src/sr_tuner_api/main.py:466-471`:
  - After training loop completes (after `_set_run_state` or before it), find the best checkpoint
  - Call `extract_core_weights()` on the best checkpoint's .pth file
  - Update model in project: set `trained_core_weights_path`, status = "trained"
  - Handle case where no checkpoint has "best_psnr" tag (fallback to "latest")
  - This is NOT a hook inside save_checkpoint — it runs as a post-step at training completion

- [x] 3.4 Pass scale as explicit parameter to `_training_worker()`:
  - Read `run.metadata["dataset_scale"]` instead of `model.scale`
  - Pass to `build_internal_sr_model(scale=..., ...)`
  - Also pass to `save_checkpoint(scale=...)` calls inside the training loop

- [x] 3.5 Handle fine-tuning (train_mode == "fine_tune"):
  - At training start, check `model.trained_core_weights_path` and `run.settings.train_mode`
  - If fine-tuning: build model with new dataset scale, load core weights into `model_impl.body`, keep randomly initialized head/tail
  - If fine-tuning: do NOT load optimizer state (fresh optimizer for all params)
  - If fine-tuning and no core weights exist: error — "Cannot fine-tune untrained model"
  - If new training but core weights exist: warn and proceed with fresh init (overwrite)

- [x] 3.6 Consume successful run into model history:
  - In `_training_worker()` after training completes, package checkpoints + metrics + dataset info into a `TrainHistoryEntry`
  - Append to `model.train_history`, write project
  - Set run state to "consumed" (remove from active runs, keep in project for traceability)
  - On the frontend: remove successful runs from the run list; show only failed/interrupted

- [x] 3.7 Handle failed/interrupted runs:
  - If training fails or is cancelled, the run stays visible in the UI for debugging
  - No core weight extraction occurs
  - Existing core weights (if any) are preserved

  ```
  Training → successful → run consumed → checkpoints → model.train_history
  Training → failed      → run stays visible → user can debug/retry
  Training → cancelled   → run stays visible → user can delete manually
  ```

## 4. Backend Inference Changes

- [x] 4.1 Modify inference endpoint to accept model_id instead of checkpoint_id
- [x] 4.2 Add `output_scale` parameter to inference request
- [x] 4.3 Implement dual inference paths
- [x] 4.4 Handle error when model has no trained weights
- [x] 4.5 Update InferenceRecord to track model_id instead of checkpoint_id
- [x] 4.6 Add ONNX export for model-based path
- [x] 4.7 Cache constructed model for same (model_id, scale) combination
- [x] 4.8 Show training scale info in inference response metadata

## 5. Model Import with Weights

- [x] 5.1 Create import endpoint (same-project only):
  - `POST /projects/{project_id}/models/{model_id}/duplicate`
  - Creates new model with copied config + core weights
  - New model gets new ID, new core weights folder
  - Cross-project import returns error: "Not yet supported"

- [x] 5.2 Implement file copy for core weights:
  - Copy `models/<model_id>/core_weights/` to new model's folder
  - Update `trained_core_weights_path` on the new model to point to new location

- [x] 5.3 Add `original_model_id` to imported model metadata

- [x] 5.4 Update backend_client in `lib/src/backend_client.dart`:
  - Add `duplicateModel()` method

## 6. Frontend - Model Tab

- [x] 6.1 Update model display in `lib/src/workspace/model_tab.dart`:
  - Show "trained" badge when `trainedCoreWeightsPath != null`
  - Display: "Scale: inherited from dataset" instead of "x{scale}"

- [x] 6.2 Add locking logic for num_features and num_blocks:
  - Check `model.status == "trained"` in edit form
  - Disable `numFeatures` and `numBlocks` fields when trained

- [x] 6.3 Show warning message when user tries to edit locked core params:
  - "Core parameters locked after training. Start a new model to change architecture."

- [x] 6.4 Update import template button:
  - Show "Import with weights" for trained models

- [x] 6.5 Add "inherited from dataset" display for scale in project models list

- [x] 6.6 Show training history on model detail view:
  - Display `train_history` entries under the model: each training session shows:
    - Date completed, dataset used, scale, epochs, best PSNR/SSIM
    - Number of checkpoints saved
  - Click a history entry to expand and see its checkpoints
  - "View checkpoints" button links to checkpoint tab filtered by this model

## 7. Frontend - Training Tab

- [x] 7.1 Remove manual scale selector from training form in `lib/src/workspace/training_tab.dart`

- [x] 7.2 Add "Scale: inherited from dataset (x<n>)" display

- [x] 7.3 Update compatibility check (`training_tab.dart:530`):
  - Change from `dataset.scale == model.scale` to always return true
  - Scale is now derived from dataset, not model

- [x] 7.4 Show warning when dataset scale differs from model's original training scale (for context only)

## 8. Frontend - Inference Tab

- [x] 8.1 Add model-based inference path alongside existing checkpoint selection:
  - Add state variables and trained model loading (`_useModelBased`, `_selectedModel`, `_outputScale`, `_trainedModels`, `_loadTrainedModels`)
  - Update `_runInference()` to support both model-based and checkpoint-based paths
  - Add mode selector (SegmentedButton: Checkpoint vs Model-based)

- [x] 8.2 Model-based path behavior:
  - When user selects a trained model + output scale, send `model_id` + `output_scale` to backend
  - Backend loads core weights from `trained_core_weights_path`, builds head/tail dynamically

- [x] 8.3 Checkpoint-based path behavior:
  - When user selects a checkpoint, send `checkpoint_id` as before
  - Backend loads full state_dict from checkpoint (old behavior)
  - Scale is fixed to checkpoint's training scale

- [x] 8.4 Update blocked state:
  - If no trained models exist: show "Train a model first to enable model-based inference"
  - If no checkpoints exist: show "No checkpoints available for comparison"

- [x] 8.5 Update InferenceRecord display:
  - For model-based inferences: show model name + output scale
  - For checkpoint-based inferences: show checkpoint name + run name (as before)

- [x] 8.6 Add "best checkpoint" indicator in checkpoint selector:
  - Highlight the checkpoint that was auto-extracted (the one matching `trained_core_weights_path`)
  - Show a star/badge next to it: "★ Best (auto-extracted)"

## 9. Frontend - Checkpoint Tab

- [x] 9.1 Show checkpoints grouped by training session under each model:
  - Each model with `train_history` entries shows its sessions as collapsible groups
  - Each session header shows: date, dataset name, scale, best PSNR/SSIM
  - Each session lists its checkpoints with epoch, iteration, metrics
  - Model selector at top: filter by model (default: selected model from context)

- [x] 9.2 Highlight the auto-extracted checkpoint per session:
  - The best checkpoint (matching `model.trained_core_weights_path`) gets a "★ Best (auto-extracted)" badge
  - Other checkpoints show metrics comparison relative to the best

- [x] 9.3 Add "Use for inference" button per checkpoint:
  - Clicking a checkpoint switches the inference tab to checkpoint-based mode with this checkpoint selected
  - Allows quick A/B comparison: "Infer with session 1's best vs session 2's best"

- [x] 9.4 Show no-checkpoints state:
  - If model has no train_history entries: "No training history. Train this model first."

## 10. Frontend - Run List Removal

- [x] 10.1 Remove successful runs from the run list UI:
  - After training completes successfully, the run disappears from the run list
  - Only failed/interrupted runs remain visible for debugging
  - The run's data is accessible via the model's train_history and the checkpoint tab

- [x] 10.2 Add "View training history" link on model card:
  - Clicking opens the checkpoint tab filtered to that model's sessions

## 11. Testing and Validation

- [ ] 11.1 Test full flow: create model → train → core weights extracted → model-based inference with different scale → checkpoint comparison
- [ ] 11.2 Test run lifecycle: train successfully → run disappears from UI → checkpoints appear under model history
- [ ] 11.3 Test same-project duplication: duplicate trained model → infer from copied model
- [ ] 11.4 Test fine-tuning: train on x4 → fine-tune on x2 dataset → infer from fine-tuned model
- [ ] 11.5 Test cross-session comparison: train twice → compare inference from session 1 checkpoint vs session 2 checkpoint
- [x] 11.6 Run backend unit tests: `uv run --project backend pytest backend/tests/ -q`
- [x] 11.7 Run Flutter tests: `flutter test`
- [x] 11.8 Run Flutter analyze: `flutter analyze`

## 12. Documentation and Cleanup

- [ ] 12.1 Update API documentation for inference (both model-based and checkpoint-based paths)
- [ ] 12.2 Add user-facing documentation for new model workflow
- [ ] 12.3 Clean up any temporary test files