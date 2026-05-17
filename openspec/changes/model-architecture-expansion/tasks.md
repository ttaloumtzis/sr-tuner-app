## 1. Backend — PyTorch model classes (`runs.py`)

- [ ] 1.1 Add `_ResBlockNoBN(nn.Module)` — EDSR residual block with two Conv2d layers, ReLU, and `res_scale` multiplier
- [ ] 1.2 Add `EDSR(nn.Module)` — head Conv2d, body Sequential of `_ResBlockNoBN` blocks + end Conv2d, PixelShuffle tail; clamp output to [0,1]
- [ ] 1.3 Add `_DenseBlock(nn.Module)` — five Conv2d dense layers with LeakyReLU; concatenate inputs; multiply output by 0.2 before residual addition
- [ ] 1.4 Add `_RRDB(nn.Module)` — three `_DenseBlock` instances; multiply combined output by 0.2 before residual addition
- [ ] 1.5 Add `RRDBNet(nn.Module)` — head Conv2d, body Sequential of `_RRDB` blocks + end Conv2d, PixelShuffle tail; clamp output to [0,1]
- [ ] 1.6 Add `build_model(model_obj, scale) -> nn.Module` factory dispatching on `model_obj.architecture`

## 2. Backend — Schema (`models.py`)

- [ ] 2.1 Extend `ModelObject.architecture` Literal to include `"edsr"` and `"rrdb"`
- [ ] 2.2 Add `res_scale: float = Field(default=0.1, ge=0.0, le=1.0)` to `ModelObject`
- [ ] 2.3 Add `architecture` and `res_scale` fields to `CreateModelRequest`
- [ ] 2.4 Update `create_model()` to copy `architecture` and `res_scale` from request onto the new `ModelObject`

## 3. Backend — Training loop (`main.py`)

- [ ] 3.1 Import `build_model` from `.runs` and replace every `build_internal_sr_model(scale, ...)` call in the training worker with `build_model(model_obj, scale)`

## 4. Backend — Inference pipeline (`inference.py`)

- [ ] 4.1 Import `build_model` from `.runs` and replace every `build_internal_sr_model(scale, ...)` call in the inference path with `build_model(model_obj, scale)`

## 5. Backend — Template catalog (`classic_workspace.py`)

- [ ] 5.1 Add `_count_edsr_params(features, blocks, scale=4) -> int` — head + body (blocks × 2×Conv + end_conv) + tail
- [ ] 5.2 Add `_count_rrdb_params(features, blocks, gc=32, scale=4) -> int` — head + body (blocks × 3×dense_block + end_conv) + tail
- [ ] 5.3 Update EDSR template: set `parameter_count=_count_edsr_params(64, 16)`, `support_state="supported"`, `save_as_model_action.supported=True`
- [ ] 5.4 Update RRDB template: set `parameter_count=_count_rrdb_params(64, 23)`, `support_state="supported"`, `save_as_model_action.supported=True`
- [ ] 5.5 Update `save_template_as_model()` to accept `"edsr"` and `"rrdb"` template IDs and pass `architecture` and `res_scale` through to `create_model()`

## 6. Frontend — Data models (`project_models.dart`)

- [ ] 6.1 Add `architecture` (String, default `"internal_residual_pixelshuffle"`) and `resScale` (double, default `0.1`) to `ModelSummary`
- [ ] 6.2 Parse both fields from JSON in `ModelSummary.fromJson()` using `as String?` / `as double?` with safe defaults

## 7. Frontend — Backend client (`backend_client.dart`)

- [ ] 7.1 Add `architecture` (String) and `resScale` (double) parameters to `saveTemplateAsModel()`; include them in the request body

## 8. Frontend — Model tab (`model_tab.dart`)

- [ ] 8.1 Add `architecture` parameter to `_HardwareEstimatePanel`; implement architecture-aware `_paramCount()` with distinct formulas for `edsr`, `rrdb`, and internal; add "estimated at scale 4" note for non-internal archs
- [ ] 8.2 Add `_resScale` state variable; show a `Slider(0.01–1.0)` with label "Residual scale" in Create panel only when the selected template is EDSR
- [ ] 8.3 Reset features/blocks sliders to template defaults (internal: 32/4, EDSR: 64/16, RRDB: 64/23) when the user selects a different template in `_selectTemplate()`
- [ ] 8.4 Pass `architecture` (from selected template ID) and `resScale` to `saveTemplateAsModel()` on save; pass `architecture` to `_HardwareEstimatePanel` in Create panel
- [ ] 8.5 Add a collapsible `ExpansionTile` titled "Hardware estimate" to each model card in the Manage panel, containing `_HardwareEstimatePanel` with `model.numFeatures`, `model.numBlocks`, and `model.architecture`
- [ ] 8.6 Update `_isSupported` logic so EDSR and RRDB templates are treated as supported (remove "coming soon" banner for all three templates)
