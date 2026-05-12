## Context

The current preview pipeline uses a latest-style folder and transient metadata:

```text
run metadata latest_preview
        │
        ▼
runs/<run_id>/previews/latest/<kind>.png
        │
        ▼
/projects/<project_id>/runs/<run_id>/preview-assets/<kind>
```

That works for a single current placeholder but does not satisfy the new behavior:
- one sample per epoch
- inspectable preview files in the project folder
- diff file structure based on diff mode
- preview source switching between validation and training data
- frontend image refresh only when the epoch changes

The Inference tab crash is separate but currently blocks a related workflow. The likely causes are dropdown values that are not found exactly once in their item lists:
- whole `CheckpointSummary` objects used as values while selected objects may not be identical to list objects
- `Map<String, dynamic>` values used for tile options, where each build creates new map instances
- async-loaded run/checkpoint/device lists that can leave stale selected IDs behind

## Proposed Flow

```text
training epoch completes
        │
        ▼
choose preview source
        │
        ├─ validation enabled + validation samples exist ─▶ first validation sample
        │
        └─ otherwise ─────────────────────────────────────▶ first training sample
        │
        ▼
run model on input sample
        │
        ▼
write epoch folder
        │
        ▼
runs/<run_id>/previews/epoch_0001/
        │
        ├─ input.png
        ├─ output.png
        ├─ target.png
        ├─ diff_absolute.png
        └─ diff_heatmap.png
        │
        ▼
store latest_preview metadata with epoch + stable URLs
        │
        ▼
Live tab refreshes preview only when epoch changes
```

## Decisions

### Run Folder Identity
- **Decision**: Use `run_id` for preview folder paths.
- **Rationale**: `training-runs` already requires stable folder-safe run folders from run IDs. Human run names are display metadata and can contain spaces, duplicates, or later edits.

### Epoch Folder Naming
- **Decision**: Use zero-padded `epoch_0001` folders.
- **Rationale**: Sorted directory listings stay chronological and remain readable on disk.

### Asset Names
- **Decision**: Save preview assets as `input.png`, `output.png`, `target.png`, `diff_absolute.png`, and `diff_heatmap.png`.
- **Rationale**: These names match the UI concepts directly while preserving explicit diff mode identity.

### Preview API Compatibility
- **Decision**: Keep `/preview` as the metadata endpoint for the latest preview, and return URLs that point to saved epoch assets.
- **Rationale**: The frontend already polls preview metadata by run ID; changing the metadata shape minimally reduces UI churn. The asset route can become epoch-aware internally or via URL path/query while the frontend only follows returned URLs.

### Diff Mode
- **Decision**: Save only the diff assets implied by the run's diff mode.
- **Rules**:
  - `absolute`: write `diff_absolute.png`
  - `heatmap`: write `diff_heatmap.png`
  - `both`: write both files

### Inference Dropdown Safety
- **Decision**: Use scalar dropdown values for mutable domain objects and option sets.
- **Rationale**: Flutter dropdowns require the selected value to match exactly one item. Stable string/int option values avoid object identity and map equality pitfalls.

## Risks

- **Preview generation cost**: Running preview generation every epoch adds work. Mitigation: use a single sample and reuse the current model pass already available during training.
- **Old runs**: Existing runs may only have `previews/latest`. Mitigation: latest-preview endpoint should tolerate missing epoch folders and return an empty/skeleton preview until a new epoch preview is generated.
- **URL caching**: Stable URLs can be cached. Mitigation: epoch-specific URLs naturally change once per epoch; metadata can include generated timestamp.
- **Inference tab hidden stale state**: Fixing one dropdown may reveal another stale value path. Mitigation: normalize every dropdown in `inference_tab.dart` that depends on async item lists.

## Open Questions

- Should the UI expose previous epoch previews later, or only latest? This change only requires latest display with saved epoch folders.
- Should preview folders be pruned for long runs? This change keeps all epoch preview folders because they are small and inspectable.
