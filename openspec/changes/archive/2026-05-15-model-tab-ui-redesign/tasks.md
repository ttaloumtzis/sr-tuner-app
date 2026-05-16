## 1. Backend — Extend save_template_as_model

- [x] 1.1 Update `save_template_as_model()` in `classic_workspace.py`:
  - Add `num_features: int = 32` and `num_blocks: int = 4` parameters
  - Pass through to `CreateModelRequest`

- [x] 1.2 Update the `save_template_as_model` endpoint in `main.py`:
  - Add `num_features` and `num_blocks` as optional query params with defaults

## 2. Backend — Extend edit support

- [x] 2.1 Add `num_features: int | None = None` and `num_blocks: int | None = None` to `UpdateModelRequest` in `models.py`

- [x] 2.2 Update `update_model()` in `models.py`:
  - Handle `num_features` and `num_blocks` updates
  - Guard: reject editing core params if `trained_core_weights_path` is set (model is trained)
  - Return appropriate error: `"core_params_locked"`

## 3. Frontend — Extend API client

- [x] 3.1 Update `saveTemplateAsModel()` in `backend_client.dart`:
  - Add optional `numFeatures` and `numBlocks` params
  - Pass as query params

- [x] 3.2 Create dedicated `updateModel()` method that accepts name + features + blocks

## 4. Frontend — Rewrite model_tab.dart layout

- [x] 4.1 Add segmented control (Create / Manage) above the right panel

- [x] 4.2 Build `_ArchitectureSidebar` widget:
  - Left sidebar (~300px) showing current template card
  - Display: name, icon, param count, VRAM estimate, best-for label, scale-agnostic badge
  - Clicking sidebar template switches to Create mode

- [x] 4.3 Build `_CreatePanel` widget:
  - Info banner: "Scale-agnostic architecture — I/O layers auto-configured from dataset at training time"
  - Name TextField
  - Features slider (8–256, default 32)
  - Blocks slider (1–64, default 4)
  - Reset button (reverts sliders to defaults)
  - Save as model button (calls `saveTemplateAsModel`)
  - Busy/error states

- [x] 4.4 Build `_ManagePanel` widget:
  - Scrollable list of model cards
  - Each card: status chip, session count, features/blocks text, scale-agnostic tag
  - Action buttons: Duplicate (trained only), Rename (toggles inline edit), Delete

- [x] 4.5 Build session expansion within model cards:
  - Per-session container within each model card
  - Session header: dataset name, scale, epoch count, best PSNR/SSIM
  - Per-checkpoint rows: name, ★ badge if best

- [x] 4.6 Build inline rename:
  - Clicking Rename replaces name text with TextField
  - Press Enter/Return or focus-out calls `updateModel`
  - Cancel button exits rename mode

- [x] 4.7 Wire up Duplicate button:
  - Only shown for trained models
  - Calls `duplicateModel()` -> refreshes model list

- [x] 4.9 Add placeholder Train button

## 5. Testing

- [x] 5.1 Run `flutter analyze` — 0 errors
- [x] 5.2 Run `flutter test` — 20/20 pass
- [x] 5.3 Run `uv run --project backend pytest backend/tests/ -q` — 101 pass
