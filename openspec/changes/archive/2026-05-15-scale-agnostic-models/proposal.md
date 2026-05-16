## Why

Currently, models in SR-Tuner are tightly coupled to specific scales. When creating a model from a template, users must select a scale (x2, x4, x8), which embeds the input and output layers directly into the model configuration. This creates several problems:

1. **No scale flexibility**: A model created for x4 cannot be used for x2 or x8 inference without retraining
2. **Checkpoint-dependent inference**: Inference requires picking a specific checkpoint from a training run — there's no "just use the trained model" shortcut
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
   - After first training completes, extract core weights from best checkpoint (tagged "best_psnr")
   - Strip input/output layers — store only core residual block weights
   - Store at `models/<model_id>/core_weights/best_core.pth`
   - Mark model status as "trained"
   - On subsequent training runs, overwrite core weights with new best

4. **Lock core architecture for trained models**
   - Once trained (status = "trained"), prevent editing of num_blocks and num_features
   - Allow fine-tuning (continue training from core weights with new dataset)
   - Allow editing of optimizer/scheduler/loss_weights (non-architecture params)

5. **Runs are ephemeral — model accumulates training history**
   - When a training run completes successfully, the run is consumed into the model's history
   - The run's checkpoints, metrics, and dataset info are preserved in the model's `train_history`
   - The run is removed from the UI (no separate run management needed)
   - Failed/interrupted runs remain visible for debugging
   - The checkpoints tab displays successful training sessions grouped under the model

6. **Inference keeps checkpoint selection — adds model-based shortcut**
   - **Checkpoint tab remains**: users browse training sessions per model, pick any checkpoint for inference (compare old vs improved weights)
   - **New model-based inference**: also infer directly from trained model (auto-loads core weights from latest best checkpoint) — a convenience shortcut
   - Inference tab shows: a model dropdown (for trained models) AND a checkpoint selector (for version comparison)
   - User can infer from "current best" (model-based, uses core weights) or from a specific older checkpoint (full weights)
   - Two paths in the backend — model-based (core weights + dynamic head/tail) and checkpoint-based (full state_dict as today)

7. **Import template copies trained weights**
   - Import creates a new model with copied configuration AND core weights
   - Imported models are immediately usable for inference
   - Same-project import only (Phase 1)

## Capabilities

### New Capabilities
- `trained-core-model`: Capability to extract, store, and reuse core model weights separately from input/output layers. Includes core weight extraction, model status tracking, and scale-agnostic inference.
- `scale-agnostic-training`: Capability to train any model on any dataset regardless of scale - scale is derived from dataset at run creation.
- `model-import-with-weights`: Capability to import trained model configurations along with their core weights for immediate use.

### Modified Capabilities
- `training-run`: Scale derived from dataset; run consumed into model history on success
- `inference`: Adds model-based inference path; checkpoint-based path retained for version comparison
- `model-management`: Model becomes scale-agnostic, accumulates train_history, locked core after training

## Impact

**Backend:**
- `backend/src/sr_tuner_api/models.py`: ModelObject schema changes (+ train_history, -scale), _derive_status rewrite
- `backend/src/sr_tuner_api/checkpoints.py`: Core weight extraction logic
- `backend/src/sr_tuner_api/main.py`: Run completion with core weight extraction (inside _training_worker)
- `backend/src/sr_tuner_api/runs.py`: Scale derivation from dataset; run consumed into model on completion
- `backend/src/sr_tuner_api/inference.py`: Model-based inference + model-based ONNX

**Frontend:**
- `lib/src/project_models.dart`: ModelSummary updates
- `lib/src/workspace/model_tab.dart`: Show trained status, lock core params, show train history
- `lib/src/workspace/training_tab.dart`: Remove scale selection
- `lib/src/workspace/inference_tab.dart`: Add model-based path, keep checkpoint selection
- `lib/src/workspace/checkpoint_tab.dart`: Show checkpoints grouped under model's training sessions
- Remove or hide run management UI (runs are consumed on success)

**Data:**
- Models gain `trained_core_weights_path` and `train_history` after first training
- Checkpoints stored inside model history entries (not standalone runs)
- `models/<model_id>/core_weights/best_core.pth` stores latest best core weights
- Runs deleted from UI on successful completion (metadata preserved in model)