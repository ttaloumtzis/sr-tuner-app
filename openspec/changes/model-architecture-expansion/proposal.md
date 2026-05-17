## Why

The model tab only supports one trainable architecture (Internal Residual PixelShuffle), leaving EDSR and RRDB listed as "coming soon" with no training path. The hardware estimate panel also only appears in Create mode, leaving users with no memory breakdown when reviewing their existing trained models in Manage mode.

## What Changes

- Add `EDSR` and `RRDBNet` PyTorch `nn.Module` implementations to the training backend
- Add `build_model(model_obj, scale)` factory that dispatches on the `architecture` field, replacing all direct `build_internal_sr_model()` calls in the training loop and inference pipeline
- Extend `ModelObject.architecture` Literal and add `res_scale` field (EDSR residual scaling)
- Update `CreateModelRequest` and `create_model()` to accept architecture and res_scale
- Mark EDSR and RRDB templates as `supported`; use accurate per-architecture parameter count formulas
- Update `save_template_as_model()` to accept all three template IDs
- Add `architecture` and `resScale` to the `ModelSummary` Dart model
- Add `res_scale` slider (EDSR only) and template-driven feature/block defaults to the Create panel
- Add hardware estimate `ExpansionTile` inside each Manage panel model card

## Capabilities

### New Capabilities

- `edsr-architecture`: EDSR PyTorch model class, builder, and full training/inference support
- `rrdb-architecture`: RRDBNet (ESRGAN backbone) PyTorch model class, builder, and full training/inference support
- `model-hardware-estimate`: Hardware estimation panel (params, memory breakdown) available in both Create and Manage modes

### Modified Capabilities

- `model-management`: Model creation now accepts architecture and res_scale; model cards in Manage show hardware estimate; template selection resets feature/block defaults

## Impact

- **Backend**: `runs.py` (new model classes + factory), `models.py` (schema), `main.py` (training loop), `inference.py` (inference path), `classic_workspace.py` (templates, param count, save_template_as_model)
- **Frontend**: `project_models.dart` (ModelSummary), `backend_client.dart` (saveTemplateAsModel), `model_tab.dart` (CreatePanel, ManagePanel, HardwareEstimatePanel)
- **No breaking changes**: existing projects with `architecture="internal_residual_pixelshuffle"` deserialize correctly via default; `body.*` core weight extraction is architecture-agnostic
