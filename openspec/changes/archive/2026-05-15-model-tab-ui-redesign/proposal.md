## Why

The current Model tab focuses on the template catalog as its primary content, with saved models buried at the bottom of a right-side detail pane. This makes common tasks — viewing, editing, duplicating, and training models — slow and undiscoverable.

Additionally, users cannot configure `num_features` or `num_blocks` when creating a model from a template (they default to 32/4 with no UI control). There is no duplicate/import-with-weights button despite the backend already supporting it. Editing an existing model (rename, change architecture params before training) is not possible in the UI.

## What Changes

1. **Left sidebar always visible** showing the selected architecture template with specs (parameter count, VRAM estimate, best-for tag, scale-agnostic badge). When additional architectures are added in the future, they appear as a browsable list.

2. **Two-mode right panel** controlled by a segmented control (Create / Manage):
   - **Create mode**: Name field + sliders for `num_features` (8–256) and `num_blocks` (1–64) + info banner explaining the model is scale-agnostic + Save/Revert buttons
   - **Manage mode**: Scrollable list of model cards, each showing status (trained/untrained), architecture params, action buttons (Train → training tab, Duplicate, Rename inline, Delete), and expandable training sessions with per-checkpoint metrics

3. **No scale anywhere** — removed from create form, removed from model cards, removed from sidebar. Replaced with a succinct banner: "Scale-agnostic architecture — I/O layers are auto-configured from dataset at training time. Output scale is configurable at inference."

4. **Inline rename** — clicking Rename on a model card replaces the name text with an editable text field.

5. **Duplicate button** — only shown for trained models, calls the existing `duplicateModel()` backend endpoint.

6. **Template interaction** — clicking a template in the sidebar pre-fills the Create form. If currently in Manage mode, switches to Create mode.

## Capabilities

- `model-architectures-sidebar`: Shows available model architectures with their specs (params, VRAM, best-for). Users can browse and select which architecture to create from.
- `model-create-form`: Name + features + blocks sliders + scale-agnostic info banner. No scale dropdown.
- `model-manage-list`: Card-based list of all saved models with status, params, actions, and expandable training history.
- `model-edit-inline`: Rename a model or edit its architecture params (only when untrained) without leaving the tab.
- `model-duplicate-ui`: One-click duplicate of trained models with weights via the existing backend endpoint.

## Impact

**Backend** (minimal):
- `classic_workspace.py`: Extend `save_template_as_model` to accept `num_features` and `num_blocks` query params
- `models.py`: Extend `UpdateModelRequest` with optional `num_features` and `num_blocks`; guard against editing when trained

**Frontend** (significant):
- `backend_client.dart`: Add optional `numFeatures`/`numBlocks` to `saveTemplateAsModel` and `updateModel`
- `model_tab.dart`: Full rewrite — left sidebar + two-mode right panel + model cards + inline rename + duplicate button + expandable sessions
