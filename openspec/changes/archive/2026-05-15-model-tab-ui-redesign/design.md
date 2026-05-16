## Layout

```
┌──────────────────────────────────────────────────────────────────────┐
│  Model Tab                                                            │
├──────────────────┬───────────────────────────────────────────────────┤
│  ARCHITECTURES   │  [ Create ]  [ Manage ] ← segmented control      │
│  (sidebar)       │                                                   │
│                  │  Right panel swaps based on active mode:          │
│  ┌────────────┐  │                                                   │
│  │ selected   │  │  CREATE MODE:                                     │
│  │ template   │  │  ┌─────────────────────────────────────────────┐ │
│  │ card       │  │  │ Create Model                                 │ │
│  │            │  │  │ Name: [_____________________________]       │ │
│  │ Param: 1.2M│  │  │                                             │ │
│  │ VRAM: 2GB  │  │  │ ┌──────────┐ ┌──────────┐                  │ │
│  │             │  │  │ │Features  │ │ Blocks   │                  │ │
│  │ Best for:  │  │  │ │[───o───] │ │ [──o────] │                  │ │
│  │ General    │  │  │ │   32     │ │    4      │                  │ │
│  │ purpose    │  │  │ └──────────┘ └──────────┘                  │ │
│  │            │  │  │                                             │ │
│  │ scale-    │  │  │ ℹ️ Scale-agnostic architecture.              │ │
│  │ agnostic  │  │  │   I/O layers auto-configured from dataset    │ │
│  │ badge     │  │  │   at training time. Output scale set at     │ │
│  │            │  │  │   inference.                                 │ │
│  └────────────┘  │  │                                             │ │
│                  │  │   [Reset]    [Save as model]                │ │
│                  │  └─────────────────────────────────────────────┘ │
│                  │                                                   │
│                  │  MANAGE MODE:                                     │
│                  │  ┌─ Model Card ───────────────────────────────┐  │
│                  │  │ model_alpha  [trained ✓]  [▸ 3 sessions]  │  │
│                  │  │ 32 features · 4 blocks · scale-agnostic    │  │
│                  │  │ [Train] [Duplicate] [Rename] [Delete]      │  │
│                  │  │ ── expanded sessions ──                    │  │
│                  │  │ Session 1 (x4, urban100, 200 epochs)       │  │
│                  │  │   Best PSNR: 32.14 dB                      │  │
│                  │  │   ★ best_core.pth  [Infer] [Export] [Del]  │  │
│                  │  │   epoch_0050 ...    31.02  [Infer]         │  │
│                  │  │   epoch_0100 ...    31.89  [Infer]         │  │
│                  │  └────────────────────────────────────────────┘  │
│                  │                                                   │
│                  │  ┌─ Model Card ───────────────────────────────┐  │
│                  │  │ model_beta  [untrained]                    │  │
│                  │  │ 64 features · 8 blocks · scale-agnostic    │  │
│                  │  │ [Train] [Rename] [Delete]                  │  │
│                  │  └────────────────────────────────────────────┘  │
│                  │                                                   │
│                  │             [ + New model from template ]        │
│                  └───────────────────────────────────────────────────┘
└──────────────────┴───────────────────────────────────────────────────┘
```

## Component Tree

```
ModelTab (StatefulWidget)
├── Row
│   ├── _ArchitectureSidebar (left, ~320px)
│   │   ├── header: "Architectures"
│   │   └── template card (currently selected)
│   │       ├── icon + name
│   │       ├── param count
│   │       ├── VRAM estimate
│   │       ├── best-for label
│   │       └── scale-agnostic badge
│   │
│   └── Expanded
│       └── Column
│           ├── SegmentedButton<bool> ("Create" | "Manage")
│           └── Expanded
│               └── _CreatePanel or _ManagePanel depending on mode
```

### _CreatePanel

```
_CreatePanel
├── info banner (scale-agnostic explanation)
├── TextField (name)
├── Row
│   ├── _SliderField("Features", min:8, max:256, value:_features)
│   └── _SliderField("Blocks", min:1, max:64, value:_blocks)
├── Row
│   ├── OutlinedButton("Reset")
│   └── FilledButton("Save as model")
└── progress indicator + error banner (conditional)
```

### _ManagePanel

```
_ManagePanel
├── ListView
│   for each model:
│   └── Card
│       ├── Row: icon + name + status chip + session count chip
│       ├── Text: features · blocks · scale-agnostic
│       ├── Wrap: action buttons
│       │   ├── [Train] → navigate to training tab (tab index 3)
│       │   ├── [Duplicate] → call duplicateModel() (trained only)
│       │   ├── [Rename] → inline edit mode
│       │   └── [Delete] → confirm dialog → deleteModel()
│       └── ExpansionTile: "Training Sessions" (if history exists)
│           for each session in train_history:
│           └── _SessionTile
│               ├── header: date · dataset · scale · best PSNR
│               └── for each checkpoint:
│                   └── _CheckpointRow
│                       ├── name + metrics
│                       ├── ★ badge if best
│                       └── [Infer] → navigate to inference tab
```

## State Management

- `_mode`: `"create" | "manage"` — toggled by SegmentedButton
- `_features`: int (8–256) — slider value in create form
- `_blocks`: int (1–64) — slider value in create form
- `_name`: TextEditingController — model name in create form
- `_editingModelId`: String? — tracks which model card is in rename mode
- `_editingName`: TextEditingController — rename text field
- `_catalog`, `_selectedTemplate`: template catalog state (same as now)
- `_busy`, `_error`: existing busy/error state
- Existing state: `_busy`, `_error`, `_catalog`, `_selected`

## Interactive Behaviors

1. **Template click in sidebar** → switches to Create mode, pre-fills name with template name
2. **Save as model** → calls `saveTemplateAsModel` with name + features + blocks, then switches to Manage mode
3. **Train button** → calls `onNavigateToTab(3)` (Training tab) — future enhancement could pre-select model
4. **Duplicate button** → calls `duplicateModel()`, then refreshes model list
5. **Rename button** → replaces name text with inline TextField, press Enter/Return to save via `updateModel`
6. **Delete button** → confirm dialog, calls `deleteModel()`
7. **Session expansion** → reads `train_history` from model data, renders checkpoints inline
8. **Infer button on checkpoint** → calls `onInferenceHandoff(checkpointId)` (existing callback pattern)

## Data Flow

```
save_template_as_model:
  User fills form → CreateModelRequest(name, num_features, num_blocks)
                  → POST /projects/{id}/model-templates/{tid}/save-as-model
                  → backend creates model → returns ProjectState
                  → frontend sets _mode = "manage", refreshes model list

duplicate_model:
  User clicks Duplicate → POST /projects/{id}/models/{mid}/duplicate?name=<copy-name>
                        → backend copies config + core weights → returns ProjectState
                        → frontend refreshes model list

rename model:
  User edits name inline → PUT /projects/{id}/models/{mid} {name: "new-name"}
                         → backend updates → returns ProjectState
                         → frontend exits edit mode, refreshes list
```
