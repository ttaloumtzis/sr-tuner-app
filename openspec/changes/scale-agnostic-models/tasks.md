## 1. Backend Data Model Changes

- [ ] 1.1 Update ModelObject in `backend/src/sr_tuner_api/models.py`:
  - Remove `scale` from required fields (make optional with default None)
  - Add `trained_core_weights_path: str | None = None`
  - Add `trained_input_config: dict | None = None`
  - Add `trained_output_config: dict | None = None`
  - Add `original_model_id: str | None = None`

- [ ] 1.2 Update CreateModelRequest in `backend/src/sr_tuner_api/models.py`:
  - Remove `scale` parameter (will be derived from dataset at run time)
  - Keep for backward compatibility during transition (will be ignored)

- [ ] 1.3 Update ModelSummary in `lib/src/project_models.dart`:
  - Add `trainedCoreWeightsPath: String?` field
  - Update `fromJson` to parse new field

- [ ] 1.4 No legacy model handling needed (per user request - existing projects will be deleted)

## 2. Core Weight Extraction

- [ ] 2.1 Create `extract_core_weights()` function in `backend/src/sr_tuner_api/checkpoints.py`:
  ```python
  def extract_core_weights(checkpoint_path: Path, model_id: str) -> tuple[dict, dict]:
      """Extract core weights (exclude first_conv head and last_conv tail)."""
  ```

- [ ] 2.2 Define layer identification for `internal_residual_pixelshuffle`:
  - Head (first conv): `nn.Conv2d(3, num_features, 3, padding=1)` - weight shape `(num_features, 3, 3, 3)`
  - Tail (last conv): `nn.Conv2d(num_features, 3 * scale * scale, 3, padding=1)` + `nn.PixelShuffle(scale)`
  - Core = residual blocks between head and tail

- [ ] 2.3 Create function to save core weights to `models/<model_id>/core_weights/best_core.pth`:
  - Create directory if not exists
  - Save state_dict with only core weights

- [ ] 2.4 Add metadata JSON sidecar `models/<model_id>/core_weights/best_core.json`:
  ```json
  {"model_id": "...", "extracted_at": "...", "source_checkpoint": "...", "input_channels": 3, "output_channels": 3}
  ```

- [ ] 2.5 Test core weight extraction on a checkpoint

## 3. Training Pipeline Integration

- [ ] 3.1 Update run creation in `backend/src/sr_tuner_api/runs.py:200` (`create_run()`):
  - Derive scale from dataset: `dataset.validated_scale or dataset.scale`
  - Store in run metadata: `"dataset_scale": dataset_scale` (already exists)
  - Remove `model.scale` from metadata (model no longer has scale)

- [ ] 3.2 Modify model builder in `backend/src/sr_tuner_api/runs.py:469-483` (`build_model()`):
  - Accept `scale` as parameter (from dataset, not model)
  - Build head and tail dynamically with the provided scale

- [ ] 3.3 Update run completion handler in `backend/src/sr_tuner_api/training.py`:
  - After best checkpoint saved, call `extract_core_weights()`
  - Save to `models/<model_id>/core_weights/best_core.pth`
  - Update model in project: set `trained_core_weights_path`, status = "trained"

- [ ] 3.4 Handle fine-tuning:
  - When `model.trained_core_weights_path` exists, load core weights
  - Build new head/tail with new dataset scale
  - Continue training from core weights

## 4. Backend Inference Changes

- [ ] 4.1 Modify inference endpoint to accept model_id instead of checkpoint_id:
  - In `backend/src/sr_tuner_api/inference.py`, update InferenceRequest:
    ```python
    class InferenceRequest(BaseModel):
      # Old (keep for backward compat):
      checkpoint_id: str | None = None
      run_id: str | None = None
      # New:
      model_id: str | None = None
      output_scale: int | None = None
    ```

- [ ] 4.2 Add `output_scale` parameter to inference request

- [ ] 4.3 Implement dynamic input/output layer construction at inference time:
  - If `model_id` provided: load core weights, build head/tail with output_scale
  - If `checkpoint_id` provided: use existing behavior (backward compat)

- [ ] 4.4 Load core weights from `trained_core_weights_path`

- [ ] 4.5 Handle error when model has no trained weights:
  - Return 422 error: "Model has no trained core weights. Train the model first."

- [ ] 4.6 Update InferenceRecord to track model_id instead of checkpoint_id:
  - Add `model_id: str | None = None`
  - Add `model_name: str | None = None` (for display)

## 5. Model Import with Weights

- [ ] 5.1 Create import endpoint:
  - `POST /projects/{project_id}/models/import-with-weights`
  - Request: `{"source_project_id": str, "model_id": str}`
  - In `backend/src/sr_tuner_api/models.py`

- [ ] 5.2 Implement file copy for core weights:
  - Copy `models/<model_id>/core_weights/` from source to destination project

- [ ] 5.3 Add `original_model_id` to imported model metadata

- [ ] 5.4 Update backend_client in `lib/src/backend_client.dart`:
  - Add `importModelWithWeights()` method

## 6. Frontend - Model Tab

- [ ] 6.1 Update model display in `lib/src/workspace/model_tab.dart`:
  - Show "trained" badge when `trainedCoreWeightsPath != null`
  - Display: "Scale: inherited from dataset" instead of "x{scale}"

- [ ] 6.2 Add locking logic for num_features and num_blocks:
  - Check `model.status == "trained"` in edit form
  - Disable `numFeatures` and `numBlocks` fields when trained

- [ ] 6.3 Show warning message when user tries to edit locked core params:
  - "Core parameters locked after training. Start a new model to change architecture."

- [ ] 6.4 Update import template button:
  - Show "Import with weights" for trained models

- [ ] 6.5 Add "inherited from dataset" display for scale in project models list

## 7. Frontend - Training Tab

- [ ] 7.1 Remove manual scale selector from training form in `lib/src/workspace/training_tab.dart`

- [ ] 7.2 Add "Scale: inherited from dataset (x<n>)" display

- [ ] 7.3 Update compatibility check (`training_tab.dart:530`):
  - Change from `dataset.scale == model.scale` to always return true
  - Scale is now derived from dataset, not model

- [ ] 7.4 Show warning when dataset scale differs from model's original training scale (for context only)

## 8. Frontend - Inference Tab

- [ ] 8.1 Replace checkpoint dropdown with trained model dropdown in `lib/src/workspace/inference_tab.dart`

- [ ] 8.2 Show only models with `trainedCoreWeightsPath != null` in the dropdown

- [ ] 8.3 Add output scale selector (independent of model):
  - Dropdown: "Output scale" (x2, x3, x4, x8)
  - Default to training scale or user's choice

- [ ] 8.4 Update blocked state when no trained models available:
  - Show: "Train a model first to enable inference"

- [ ] 8.5 Update InferenceRecord display to show model name instead of checkpoint

## 9. Testing and Validation

- [ ] 9.1 Test full flow: create model → train → core weights extracted → inference with different scale
- [ ] 9.2 Test import with weights: export model → import to new project → inference works
- [ ] 9.3 Test fine-tuning: train on x4 → fine-tune on x2 dataset → works
- [ ] 9.4 Run backend unit tests: `uv run --project backend pytest backend/tests/ -q`
- [ ] 9.5 Run Flutter tests: `flutter test`
- [ ] 9.6 Run Flutter analyze: `flutter analyze`

## 10. Documentation and Cleanup

- [ ] 10.1 Update API documentation for new inference endpoint
- [ ] 10.2 Add user-facing documentation for new model workflow
- [ ] 10.3 Clean up any temporary test files