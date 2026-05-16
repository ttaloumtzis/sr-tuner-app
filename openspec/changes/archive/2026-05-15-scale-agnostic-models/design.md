## Context

### Current State

The SR-Tuner app currently treats models as complete, scale-specific entities:

1. **ModelObject** contains:
   - `scale`: The output scale (2, 3, 4, 8)
   - `num_features`: Number of feature channels
   - `num_blocks`: Number of residual blocks
   - `architecture`: Currently only "internal_residual_pixelshuffle"

2. **Training** requires dataset scale to match model scale exactly (checked in training_tab.dart line 539: `return dataset.scale == model.scale`)

3. **Inference** uses checkpoints directly - user selects a checkpoint, not a trained model

4. **Checkpoints** contain full model state including input/output layers

### Architecture Pattern

The internal_residual_pixelshuffle model has this structure:
```
Input → FirstConv (in_channels=3, out_channels=num_features) → 
  [ResidualBlock × num_blocks] →
  LastConv (num_features → num_features*scale*scale) →
  PixelShuffle(scale) → 
Output (out_channels=3)
```

The first conv (FirstConv) and last conv+shuffle (LastConv) are scale-dependent. The residual blocks in between are resolution-agnostic - they process feature maps of any size.

### Constraints
- No backward compatibility needed - existing projects will be deleted before this change
- Must work with existing checkpoint storage format (extract from checkpoint, don't change format)
- Should minimize frontend changes for user experience

## Goals / Non-Goals

**Goals:**
1. Make models scale-agnostic by separating core weights from input/output layers
2. Extract and store core weights from best checkpoint after each training run completes
3. Enable inference using trained models (auto-best) AND per-checkpoint comparison
4. Allow trained models to be imported with their weights
5. Support fine-tuning of trained models with new datasets
6. Keep checkpoint tab as the version manager — users compare old vs improved weights

**Non-Goals:**
1. Real-time weight extraction during training (extract on completion only)
2. Cloud model sharing/registry (local import only)
3. Backward compatibility with pre-change projects
4. Cross-project import (Phase 1: same-project only)

## Decisions

### D1: Scale Field Removal from ModelObject

**Decision:** Remove `scale` field from ModelObject entirely. Scale is now derived from the dataset at run creation time.

**Rationale:** 
- Scale is a property of how the model is used (dataset + inference target), not the model itself
- Models become pure architecture definitions (num_features, num_blocks)
- Backend derives scale at run creation, frontend shows "inherited from dataset"

**Alternative considered:** Keep scale in model but allow override at inference time. Rejected because it creates ambiguity - is scale part of the model or not?

### D2: Core Weight Extraction on Training Completion

**Decision:** Extract core weights from the best checkpoint when training completes, saving to the model's core weights directory. This is a post-step in `_training_worker()`, not a hook inside `save_checkpoint()`.

**Rationale:**
- `save_checkpoint()` has no callback mechanism for "best_psnr" tag assignment
- The training worker runs in a daemon thread (main.py:241) and has access to best checkpoint at completion — extraction is a natural post-step after the training loop finishes
- Each training run extracts from its own best checkpoint and **overwrites** the model's single core weights file
- Old checkpoints remain on disk (full state_dict) for version comparison — they are NOT stripped

```
Training timeline:
  Run 1: full checkpoints (ckpt_1, ckpt_2, ..., best_ckpt)
         → after completion: extract core from best_ckpt → model.core_weights = best_core_1
  
  Run 2: full checkpoints (ckpt_1, ckpt_2, ..., best_ckpt)
         → after completion: extract core from best_ckpt → model.core_weights = best_core_2 (overwrite)
  
  Checkpoint tab: shows ckpt_1..N for both runs — user can pick any for inference comparison
  Model-based inference: always uses latest best_core (current model.core_weights)
```

**Alternative considered:** Hook inside save_checkpoint that fires when a "best_psnr" tag is assigned. Rejected because it creates a circular dependency — checkpoints.py would need to import model update logic.

### D3: Core Weight Storage Location

**Decision:** Store core weights in `models/<model_id>/core_weights/` directory within the project.

**Rationale:**
- Keeps core weights tied to the model, not the run
- Allows model to be used even after run is deleted
- Easy to locate: project/models/{model_id}/core_weights/best_core.pth

**Alternative considered:** Store in run folder. Rejected - if run is deleted, model becomes unusable.

### D4: Fine-Tuning Support

**Decision:** Trained models can be retrained (fine-tuned) by loading core weights and constructing new input/output layers with the new dataset's scale.

**Rationale:**
- Users may want to adapt a trained model to a different scale
- Maximizes reusability of learned features
- Core weights are resolution-agnostic, so transfer learning works

**Alternative considered:** Lock models after training. Rejected - limits model reusability, less flexible.

### D5: Inference — Dual Path (Model-Based + Checkpoint-Based)

**Decision:** Inference supports two paths:
1. **Model-based** (new): user selects a trained model + output scale → loads core weights, builds head/tail dynamically
2. **Checkpoint-based** (existing): user selects a specific checkpoint → loads full state_dict (old behavior, scale is fixed)

**Rationale:**
- Model-based path is the convenience shortcut: "just use the latest best weights"
- Checkpoint-based path is for version comparison: "did this training run improve things?"
- Both paths coexist — the inference tab shows a model dropdown AND a checkpoint selector
- Checkpoints remain the ground truth for weight versioning; model-based is a derived convenience

```
Inference tab layout:

  ┌─────────────────────────────────────────────┐
  │  Model: [trained_model_v2 ▼]                │
  │  Output scale: [x4 ▼]                       │
  │  ┌─────────────────────────────────────┐    │
  │  │ ● Use latest best (auto)            │    │
  │  │ ○ Pick checkpoint for comparison:   │    │
  │  │                                     │    │
  │  │ Session 1 (2026-05-10 · x4)         │    │
  │  │   ├─ epoch_0050 ...                 │    │
  │  │   ├─ epoch_0100 ...                 │    │
  │  │   └─ epoch_0200 ... ★               │    │
  │  │ Session 2 (2026-05-12 · x2)         │    │
  │  │   ├─ epoch_0050 ...                 │    │
  │  │   └─ epoch_0100 ... ★               │    │
  │  └─────────────────────────────────────┘    │
  │  [Run Inference]                            │
  └─────────────────────────────────────────────┘
  ★ = best checkpoint (auto-extracted)
```

**Alternative considered:** Remove checkpoint selection entirely. Rejected — users need to compare old vs improved weights across training runs.

### D6: Import with Weights

**Decision:** Import template copies both configuration AND core weights to new model.

**Rationale:**
- Imported model immediately usable for inference
- No need to retrain
- Matches user's expectation of "importing a trained model"

**Alternative considered:** Import config only, require retraining. Rejected - defeats purpose of importing trained model.

### D7: Model Status from Core Weights Path, Not Checkpoint Scan

**Decision:** Rewrite `_derive_status()` to check `trained_core_weights_path` directly instead of scanning runs/checkpoints for usable checkpoints.

**Rationale:**
- The current `_derive_status()` (models.py:205-217) compares `checkpoint.scale == model.scale` — after removing `scale` from ModelObject, this comparison breaks
- The old logic also references `checkpoint.get("usable")` which doesn't exist in `CheckpointMetadata` (no `usable` field) — this is a latent bug
- Physical presence of core weights is the ground truth for "trained" status

```
Current _derive_status() logic:
  scan all runs → find checkpoints for this model →
  filter: checkpoint.usable AND checkpoint.scale == model.scale →
  status = "fine_tune_available" | "trained" | "untrained"

New _derive_status() logic:
  model.trained_core_weights_path exists? →
  status = "trained" | "untrained"
```

**Alternative considered:** Fix the checkpoint scan to use `model.metadata["training_scale"]` instead of `model.scale`. Rejected — unnecessary complexity when core weights path is the authoritative source.

### D8: ONNX Export Uses Same Model-Based Path as Inference

**Decision:** ONNX export accepts `model_id` + `output_scale` (building full model from core weights), and retains legacy `checkpoint_id` path for backward compatibility.

**Rationale:**
- ONNX export follows the same pattern as inference — core weights + dynamic head/tail
- Users of trained models should be able to export ONNX without selecting a checkpoint
- The current ONNX export already calls `build_internal_sr_model()` and `load_state_dict()` — the new path just changes where the state dict comes from

**Alternative considered:** Separate ONNX-core-weights endpoint. Rejected — unnecessary duplication, ONNX export naturally follows inference.

### D9: Training Worker Receives Scale as Parameter

**Decision:** The training worker (`_training_worker()` in main.py:241-479) accepts `scale` as an explicit parameter alongside the model config, instead of reading `model.scale`.

**Rationale:**
- The training loop currently hard-codes `model.scale` when building the model (line 265-269)
- After removing scale from ModelObject, scale must come from the run's metadata (`dataset_scale`)
- The run already stores `dataset_scale` in metadata (runs.py create_run sets `"dataset_scale"` in metadata)

**Implication for fine-tuning:** When `model.trained_core_weights_path` exists:
1. Build model with new scale (from dataset)
2. Load core weights into `model_impl.body` only
3. Head and tail are freshly initialized (random weights) — they haven't been trained for the new scale
4. Optimizer is freshly constructed (Adam on all params including new head/tail)

### D10: Import Within Same Project Only (Phase 1)

**Decision:** The initial "import with weights" feature supports importing from the same project only (duplicate a trained model within a project). Cross-project import is deferred.

**Rationale:**
- Cross-project import requires reading from another project's filesystem — introduces path traversal risk and security checks
- Same-project import is simpler: copy `models/<model_id>/core_weights/` to a new model folder under the same project
- Cross-project can be added later via an export/import workflow or shared model registry

**Alternative considered:** Full cross-project import. Rejected — security surface area and complexity not justified for initial release.

### D11: Run Lifecycle — Consumed into Model on Successful Completion

**Decision:** When a training run completes successfully, the run is "consumed" into the model's training history. The run's checkpoints, metrics, and dataset info are preserved in `model.train_history`. The run is removed from the UI run list. Failed or interrupted runs remain visible.

**Rationale:**
- Users don't manage runs directly — they train a model, and the model remembers its training history
- Checkpoints need to persist for version comparison — moving them under the model's history achieves this while removing UI clutter
- The model becomes the primary entity: "train my model" → "check its history" → "compare checkpoints" → "infer"

```
Run lifecycle:
                                      ┌──────────┐
                                      │  Run     │
                                      │ created  │
                                      └────┬─────┘
                                           │
                                      ┌────▼─────┐
                                      │ Training │
                                      │ running  │
                                      └────┬─────┘
                                           │
                              ┌────────────┼────────────┐
                              │ success    │ fail/cancel │
                         ┌────▼────┐  ┌────▼─────┐
                         │ Consume │  │ Run stays│
                         │ into    │  │ visible  │
                         │ model   │  │ for      │
                         │ history │  │ debugging│
                         └────┬────┘  └──────────┘
                              │
                    ┌─────────▼──────────┐
                    │ model.train_history │
                    │ append entry:       │
                    │  - timestamp        │
                    │  - dataset_id       │
                    │  - scale            │
                    │  - metrics          │
                    │  - checkpoints[]    │
                    │  - best_ckpt_id     │
                    └────────────────────┘
```

**Data model for train_history entry:**
```python
class TrainHistoryEntry(BaseModel):
    session_id: str              # run_id (for traceability)
    dataset_id: str
    dataset_name: str
    scale: int                   # training scale
    started_at: str
    completed_at: str
    epochs: int
    best_metrics: dict           # {"val_psnr": ..., "val_ssim": ...}
    final_metrics: dict
    checkpoints: list[dict]      # CheckpointMetadata dicts
    best_checkpoint_id: str
```

**Alternative considered:** Keep runs as separate entities always. Rejected — adds UI complexity, users don't need to see run lifecycle after training completes.

### D12: Checkpoint Tab Shows Model Training Sessions

**Decision:** The checkpoint tab displays training sessions grouped under each model. Each session shows its checkpoints, with the best checkpoint highlighted. Users can pick any checkpoint for inference comparison.

**Rationale:**
- Since runs are consumed into model history, the checkpoint tab is the natural place to browse training results
- Grouping by model + training session makes it easy to compare: "session 1 vs session 2"
- The "best" checkpoint per session is auto-extracted into the model's core weights
- Non-best checkpoints remain for side-by-side comparison

```
Checkpoint tab layout:

  Model: [trained_model_v2 ▼]
  
  ┌── Training Session 1 (2026-05-10 · x4) ──────────────────┐
  │  Best PSNR: 32.14 │ Epochs: 200 │ Dataset: urban100     │
  │  ├─ epoch_0050_iter_000300.pth     PSNR: 31.02          │
  │  ├─ epoch_0100_iter_000600.pth     PSNR: 31.89          │
  │  └─ epoch_0200_iter_001200.pth ★   PSNR: 32.14  ← auto  │
  │                           [Use for inference ▼]          │
  └──────────────────────────────────────────────────────────┘
  
  ┌── Training Session 2 (2026-05-12 · x2) ──────────────────┐
  │  Best PSNR: 33.45 │ Epochs: 150 │ Dataset: set5         │
  │  ├─ epoch_0050_iter_000300.pth     PSNR: 32.10          │
  │  └─ epoch_0100_iter_000600.pth ★   PSNR: 33.45  ← auto  │
  │                           [Use for inference ▼]          │
  └──────────────────────────────────────────────────────────┘

  ★ = best checkpoint (auto-extracted to model.core_weights)
```

**Alternative considered:** Keep checkpoint tab flat (all checkpoints regardless of model/session). Rejected — users need session context to understand which training produced which checkpoint.

## Risks / Trade-offs

### R1: Core Weight Extraction Layer Identification

**Risk:** Automatically identifying which layers to strip (input/output) could be fragile if architecture names change.

**Mitigation:**
- Define explicit layer name patterns in code: "first_conv" and "last_conv/upconv"
- For internal_residual_pixelshuffle: strip first conv (weight shape 3→num_features) and last conv (num_features→features*scale*scale)
- Add validation: extracted core weights must have expected parameter count
- Document expected layer names in architecture spec

### R2: Inference Performance with Dynamic Layers

**Risk:** Building input/output layers on-the-fly at inference time adds overhead.

**Mitigation:**
- Cache constructed model for same (model_id, scale) combination
- Input/output layers are small compared to core - minimal memory impact
- First inference may be slower, subsequent are fast

### R3: Model Lock After Training

**Risk:** Users may want to add more blocks/features after training (模型扩展).

**Mitigation:**
- Allow editing num_blocks/num_features IF model has no trained_core_weights_path
- If core weights exist, lock - but warn user with clear message
- Could add "expand model" action that adds blocks while preserving existing core weights (future enhancement)

### R4: Multiple Runs on Same Model — Which Core Weights to Keep?

**Risk:** User runs training multiple times on same model. Each run produces a best checkpoint with core weights. Only one set of core weights can be the model's "current best."

**Mitigation:**
- Each run's best checkpoint overwrites the model's `trained_core_weights_path` (latest wins)
- Old checkpoints remain on disk with full state_dict — user can still use them for inference comparison
- Checkpoint tab shows all checkpoints across all runs, with the "best" tag highlighted
- Inference tab lets user pick any checkpoint for comparison, or use the auto-best (model-based path)

### R5: _derive_status() Rewrite Risk

**Risk:** Current `_derive_status()` scans checkpoints for both "usable" and scale matching. After removing `scale` from ModelObject, the scale comparison breaks. Also, `checkpoint.get("usable")` doesn't exist in `CheckpointMetadata` — this latent bug means status was already unreliable.

**Mitigation:**
- Replace entirely with direct `trained_core_weights_path` check
- Old status values "untrained"/"trained"/"fine_tune_available" simplify to "untrained"/"trained"
- Remove the "fine_tune_available" status — any trained model can be fine-tuned

### R6: Training Worker Ignores train_mode

**Risk:** The `_training_worker()` always does "new" training — it never loads pre-trained weights, doesn't check `run.settings.train_mode`. Adding fine-tuning support means the training loop needs a conditional load at startup.

**Mitigation:**
- At training start, check `model.trained_core_weights_path` and `run.settings.train_mode`
- If `train_mode == "fine_tune"` and core weights exist: load core weights into body, build new head/tail with dataset scale, fresh optimizer
- If `train_mode == "new"` and core weights exist: warn user that model already has trained weights (overwrite), proceed with fresh initialization
- Document that fine-tuning loses optimizer state (only core body weights are preserved)

Training startup decision tree:
```
                    ┌──────────────────────┐
                    │  training starts      │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │  core_weights_path?   │
                    └────┬────────────┬────┘
                    Yes  │            │  No
                    ┌────▼───┐   ┌────▼─────┐
                    │train   │   │ fresh    │
                    │_mode?  │   │ init     │
                    ├───┬────┤   │ (current)│
                  finetune│new│   └──────────┘
                ┌────▼──┐ │  │
                │load   │ │  │
                │core   │ │  │
                │to body│ │  │
                │fresh  │ │  │
                │head/  │ │  │
                │tail   │ │  │
                └───────┘ │  │
                          │  │
                ┌─────────▼──▼──┐
                │ fresh init    │
                │ (ignore core) │
                └───────────────┘
```

### R7: Scale Quality Tradeoff — Cross-Scale Inference May Be Poor

**Risk:** Core weights are architecture-agnostic but not statistically agnostic. A core trained on x2 learns fine-detail upsampling patterns. Using that same core for x8 inference forces the body's features to be expanded 8× — the output may have artifacts, noise amplification, or blurriness.

**Mitigation:**
- Show recommended scale range in UI: "Trained at x{N}" (informational, not blocking)
- Do NOT block cross-scale inference — user may want to experiment
- Add a user-facing note that quality at scales far from training scale may degrade
- Future enhancement: multi-scale training to produce truly scale-agnostic cores

### R8: ONNX Export Ignores Core Weights

**Risk:** The ONNX export path (`checkpoints.py:240-284`) always loads a checkpoint's full state dict. After this change, trained models have core weights + dynamic head/tail — the ONNX export must handle this or break.

**Mitigation:**
- Add ONNX export path for model-based (core weights) inference
- Accept `model_id` + `output_scale` as alternative to `checkpoint_id`
- Build full model from core weights + dynamic head/tail, then export
- Legacy `checkpoint_id` path still works for backward compat during transition

### R9: Cross-Project Import Security

**Risk:** Import-with-weights that reads from another project's filesystem creates a path traversal attack surface — a malicious request could read arbitrary files via relative paths.

**Mitigation:**
- Phase 1: Same-project import only (duplicate within project)
- Cross-project deferred to later phase with full security review
- If cross-project added later: validate source project ID against known projects, restrict file reads to `models/<model_id>/core_weights/` only, resolve paths through project store

## Migration Plan

**Phase 1: Backend Core (no user-visible changes)**
1. Add `trained_core_weights_path` to ModelObject schema
2. Add `extract_core_weights()` function in checkpoints.py
3. Modify `_training_worker()` in main.py to run extraction after training completes successfully

**Phase 2: Status System Rewrite**
1. Rewrite `_derive_status()` in models.py to check `trained_core_weights_path` instead of scanning checkpoints
2. Remove "fine_tune_available" status — simplify to "untrained"/"trained"
3. Remove broken `checkpoint.get("usable")` reference from status derivation
4. Test: model shows "trained" immediately after first training completes

**Phase 3: Training Integration**
1. Modify run creation to derive scale from dataset
2. Add core weight loading to training startup (check train_mode, load core weights for fine-tuning)
3. Pass scale as explicit parameter to training worker (not from model.scale)
4. Test: create run, complete training, verify core weights extracted
5. Test: fine-tune trained model on different scale dataset

**Phase 3b: Run Lifecycle — Consume Successful Runs into Model**
1. Add `train_history: list[TrainHistoryEntry]` to ModelObject
2. On training completion (in _training_worker), package checkpoints + metrics into a TrainHistoryEntry
3. Append entry to model.train_history, write to project
4. Set run state to "consumed" or delete run metadata from project JSON
5. Frontend: remove successful runs from run list UI
6. Test: train model → run disappears from runs → checkpoints appear under model history

**Phase 4: Inference Update**
1. Modify inference endpoint to accept model_id + output_scale (model-based path)
2. Keep checkpoint_id path for version comparison
3. Load core weights + build head/tail dynamically for model-based path
4. Add model-based ONNX export path
5. Test: model-based inference at different scales
6. Test: checkpoint-based inference for version comparison
7. Test: ONNX export from trained model

**Phase 5: Frontend Updates**
1. Model tab: show trained status, lock core params, show train history
2. Training tab: remove scale selector, show inherited scale
3. Inference tab: add model-based path alongside session-grouped checkpoint selection
4. Checkpoint tab: show training sessions grouped under model with metrics per session
5. Remove run list from UI (successful runs consumed; only failed/interrupted visible)
6. Test: full flow — create model, train, infer via model path, compare via checkpoint path

**Phase 6: Import with Weights (Same-Project Only)**
1. Add endpoint to duplicate model + core weights within same project
2. Frontend import button copies weights
3. Test: duplicate trained model, infer from copied model
4. Cross-project import deferred to future release

## Open Questions

1. **Q: Core weights file format?**
   - Just .pth or include metadata?
   - Decision: Include minimal metadata JSON sidecar: {"model_id": "...", "extracted_at": "...", "source_checkpoint": "..."}

2. **Q: Delete model - also delete core weights?**
   - Yes - cascade delete core weights file when model is deleted
   - This is cleanup, not critical as weights can be re-extracted from checkpoint

3. **Q: Backward compatibility during transition?**
   - During implementation, support both checkpoint-based AND model-based inference
   - Frontend gradually transitions to model-based UI
   - Once fully migrated, can remove backward compat code
   - Decision: Include minimal metadata JSON sidecar: {"model_id": "...", "extracted_at": "...", "source_checkpoint": "..."}

4. **Q: Delete model - also delete core weights?**
   - Yes - cascade delete core weights file when model is deleted
   - This is cleanup, not critical as weights can be re-extracted from checkpoint