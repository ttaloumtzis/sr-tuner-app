## Why

Currently, models in SR-Tuner are tightly coupled to specific scales. When creating a model from a template, users must select a scale (x2, x4, x8), which embeds the input and output layers directly into the model configuration. This creates several problems:

1. **No scale flexibility**: A model created for x4 cannot be used for x2 or x8 inference without retraining
2. **Checkpoint-dependent inference**: Inference currently requires selecting a specific checkpoint from a training run, rather than the trained model itself
3. **Duplicated weights**: Checkpoints contain full model weights (including input/output layers) even though only the core residual blocks need to be preserved
4. **Limited reusability**: Users cannot import a trained model and use it directly - they can only import configuration templates

The convolution layers in the core architecture are resolution-agnostic, only the input (first conv) and output (last conv/pixel shuffle) layers are scale-specific. By separating core weights from input/output layers, models become truly scale-agnostic and reusable.

## What Changes

1. **Separate core model from input/output layers**
   - Remove `scale` field from ModelObject - scale now comes from dataset at run creation
   - Add `trained_core_weights_path` to store extracted core weights after first training
   - Models become architecture definitions (num_features, num_blocks) without scale

2. **Auto-configure runs from dataset scale**
   - At run creation, derive scale from selected dataset automatically
   - Construct full model (core + input/output) dynamically at training time
   - Remove manual scale selection from training tab

3. **Extract and store core weights after training**
   - After first training completes, extract core weights from best checkpoint
   - Only strip hardcoded input/output layers - convolution layers are resolution-agnostic
   - Store core weights path in model.metadata
   - Mark model status as "trained"

4. **Lock core architecture for trained models**
   - Once trained (status = "trained"), prevent editing of num_blocks and num_features
   - Allow fine-tuning (continue training from core weights with new dataset)
   - Allow editing of optimizer/scheduler/loss_weights (non-architecture params)

5. **Inference uses trained models instead of checkpoints**
   - Remove checkpoint selection from inference tab
   - Show list of trained models (status = "trained")
   - User selects model and output scale - core weights auto-loaded, input/output built dynamically

6. **Import template copies trained weights**
   - Import creates a new model with copied configuration AND core weights
   - Imported models are immediately usable for inference

## Capabilities

### New Capabilities
- `trained-core-model`: Capability to extract, store, and reuse core model weights separately from input/output layers. Includes core weight extraction, model status tracking, and scale-agnostic inference.
- `scale-agnostic-training`: Capability to train any model on any dataset regardless of scale - scale is derived from dataset at run creation.
- `model-import-with-weights`: Capability to import trained model configurations along with their core weights for immediate use.

### Modified Capabilities
- `training-run`: Requires scale derivation from dataset instead of model config
- `inference`: Changes from checkpoint-based to model-based inference
- `model-management`: Model becomes scale-agnostic, with locked core after training

## Impact

**Backend:**
- `backend/src/sr_tuner_api/models.py`: ModelObject schema changes
- `backend/src/sr_tuner_api/checkpoints.py`: Core weight extraction logic
- `backend/src/sr_tuner_api/training.py`: Run completion with core weight extraction
- `backend/src/sr_tuner_api/runs.py`: Scale derivation from dataset
- `backend/src/sr_tuner_api/inference.py`: Model-based inference

**Frontend:**
- `lib/src/project_models.dart`: ModelSummary updates
- `lib/src/workspace/model_tab.dart`: Show trained status, lock core params
- `lib/src/workspace/training_tab.dart`: Remove scale selection
- `lib/src/workspace/inference_tab.dart`: Use trained models instead of checkpoints

**Data:**
- Models gain `trained_core_weights_path` field after first training
- Checkpoints continue to store full model (for recovery), but best checkpoint triggers core extraction