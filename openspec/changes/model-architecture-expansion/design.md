## Context

The backend currently has a single PyTorch model class (`InternalResidualPixelShuffleSR`) instantiated directly everywhere via `build_internal_sr_model()`. There is no factory or registry; the `architecture` field on `ModelObject` is metadata-only. The training loop in `main.py`, inference in `inference.py`, and checkpoint extraction in `checkpoints.py` all call `build_internal_sr_model()` directly. EDSR and RRDB template cards exist in the catalog but are blocked from creation (`save_as_model_action.supported=False`, `support_state="coming_soon"`).

## Goals / Non-Goals

**Goals:**
- Make EDSR and RRDB fully trainable end-to-end (create → train → checkpoint → inference)
- Introduce a model factory so new architectures can be added without touching the training loop
- Show hardware estimate (params + memory) in both Create and Manage modes
- Keep backward compatibility with existing projects (default architecture stays `internal_residual_pixelshuffle`)

**Non-Goals:**
- GAN / discriminator / perceptual loss changes — RRDB trains with L1 like the internal model for now
- Pre-trained weight importing (no ImageNet pretrain)
- Scale-specific model variants (all architectures remain scale-agnostic like the internal model)
- Changing the core weight extraction format

## Decisions

**D1 — Model factory in `runs.py`**
Add `build_model(model_obj, scale) -> nn.Module` that switches on `model_obj.architecture`. All callers in `main.py`, `inference.py`, and anywhere else are updated to call this factory. Alternative: a class registry dict. Chosen approach is simpler for three architectures and keeps the implementations co-located.

**D2 — All new model classes in `runs.py`**
EDSR and RRDBNet classes live in `runs.py` alongside the existing internal model. Alternative: separate `architectures/` package. Rejected because the codebase is small and a new package adds navigation overhead with no current benefit.

**D3 — EDSR body includes end conv inside Sequential**
The EDSR body Sequential contains `num_blocks` residual blocks + a final Conv2d. This means `body.*` key extraction in `checkpoints.py` captures the end conv without any change to core weight extraction. Alternative: separate `end_conv` attribute. Rejected to keep extraction logic unchanged.

**D4 — RRDB growth channels fixed at 32**
`gc=32` is the standard ESRGAN configuration and is not exposed as a hyperparameter. Alternative: expose as a slider. Rejected because ESRGAN-style models are always trained at gc=32 and exposing it adds UI noise for no practical benefit.

**D5 — `res_scale` stored on `ModelObject`, ignored by non-EDSR archs**
`res_scale` is a field on `ModelObject` with a default of 0.1. For internal/RRDB models the field exists but is silently ignored by the factory. Alternative: subclasses or union types. Rejected as overly complex for a single extra float.

**D6 — Template defaults reset on sidebar selection**
When the user clicks a different template card in the sidebar, the features/blocks sliders reset to that template's recommended defaults (32/4 for internal, 64/16 for EDSR, 64/23 for RRDB). This prevents accidentally creating an RRDB with 4 blocks. The reset is triggered in `_selectTemplate()`.

**D7 — Hardware estimate in Manage via `ExpansionTile`**
Each model card in the Manage panel gets a collapsible "Hardware estimate" section using `ExpansionTile`. This avoids inflating card height for users who don't need the estimate. The estimate uses the same `_HardwareEstimatePanel` widget, which now accepts an `architecture` parameter.

## Risks / Trade-offs

- **RRDB memory**: At 64f/23b the model is ~16.6M params. With a batch of 4 and Adam, GPU VRAM demand is substantial. The hardware estimate panel should make this visible before the user commits to training.  → The estimate panel is the mitigation; no training guard is added (user responsibility).
- **Param count formula accuracy**: EDSR and RRDB formulas are computed analytically assuming scale=4 for the tail. For other scales the tail differs slightly. → Display a note "estimated at scale 4" in the panel for non-internal architectures.
- **Core weight compatibility**: Existing checkpoints for `internal_residual_pixelshuffle` load into the internal model class. If a checkpoint is loaded with the wrong architecture the state dict keys won't match. → The checkpoint always stores `architecture` in its metadata; load path reads it and calls the correct factory branch.
