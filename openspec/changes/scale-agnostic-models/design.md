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
2. Extract and store core weights after first training completes
3. Enable inference using trained models instead of specific checkpoints
4. Allow trained models to be imported with their weights
5. Support fine-tuning of trained models with new datasets

**Non-Goals:**
1. Support multiple core weight versions per model (single "best" core)
2. Real-time weight extraction during training (extract on completion only)
3. Cloud model sharing/registry (local import only)
4. Backward compatibility with pre-change projects

## Decisions

### D1: Scale Field Removal from ModelObject

**Decision:** Remove `scale` field from ModelObject entirely. Scale is now derived from the dataset at run creation time.

**Rationale:** 
- Scale is a property of how the model is used (dataset + inference target), not the model itself
- Models become pure architecture definitions (num_features, num_blocks)
- Backend derives scale at run creation, frontend shows "inherited from dataset"

**Alternative considered:** Keep scale in model but allow override at inference time. Rejected because it creates ambiguity - is scale part of the model or not?

### D2: Core Weight Extraction on Best Checkpoint Only

**Decision:** Extract core weights only when "best" checkpoint is created (tagged with "best_psnr").

**Rationale:**
- Avoids redundant extraction on every checkpoint
- Best checkpoint represents the most useful core weights
- Reduces storage overhead (only one core weights file per run)

**Alternative considered:** Extract on every checkpoint. Rejected - unnecessary I/O, most checkpoints are not the best.

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

### D5: Inference Scale Selection

**Decision:** At inference time, user selects output scale separately from model selection. Model provides core weights, user chooses target scale.

**Rationale:**
- Core weights are scale-agnostic
- User may want to output at different scale than training
- Flexible: trained on x4 dataset → can output x2 or x8

**Alternative considered:** Inference always uses training scale. Rejected - limits usability, user may have different output needs.

### D6: Import with Weights

**Decision:** Import template copies both configuration AND core weights to new model.

**Rationale:**
- Imported model immediately usable for inference
- No need to retrain
- Matches user's expectation of "importing a trained model"

**Alternative considered:** Import config only, require retraining. Rejected - defeats purpose of importing trained model.

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

### R4: Multiple Runs on Same Model

**Risk:** User could run training multiple times on same model - which core weights to keep?

**Mitigation:**
- Each run can produce new core weights
- Store latest by default (overwrite)
- Could add UI to select which run's core to use (future enhancement)
- For now: latest training wins

## Migration Plan

**Phase 1: Backend Core (no user-visible changes)**
1. Add trained_core_weights_path, trained_input_config, trained_output_config to ModelObject schema
2. Add function to extract core weights from checkpoint
3. Modify save_checkpoint to extract core weights when checkpoint is tagged "best"

**Phase 2: Training Integration**
1. Modify run creation to derive scale from dataset
2. Add model status update on run completion
3. Test: create run, complete training, verify core weights extracted

**Phase 3: Inference Update**
1. Modify inference endpoint to accept model_id
2. Load core weights + build input/output dynamically
3. Test: run inference with trained model at different scales

**Phase 4: Frontend Updates**
1. Model tab: show trained status, lock core for trained models
2. Training tab: remove scale selector, show inherited scale
3. Inference tab: replace checkpoint dropdown with model dropdown
4. Test: full flow - create model, train, infer

**Phase 5: Import with Weights**
1. Add import_template endpoint that copies core weights
2. Frontend import button copies weights
3. Test: export model, import to new project, infer

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