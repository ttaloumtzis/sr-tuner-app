# Checkpoints Tab as Model Version Manager

## Problem

The current checkpoints tab aggregates checkpoint data from all runs into a flat
list via `GET /checkpoints/aggregate`. This has several issues:

1. **No model association** — checkpoints are shown per-run, not per-model.
   Users can't see which checkpoints belong to which model without cross-referencing.
2. **Run-dependent** — if a run is deleted, its checkpoints vanish from the
   aggregate API, even though they're archived in `model.trainHistory`.
3. **No version management** — there's no way to promote a checkpoint to the
   active "core" of a model, compare checkpoints across runs, or export/import
   a complete model package (weights + config).
4. **Flat table is undifferentiated** — legacy mode shows all checkpoints from
   all runs in one table with no run context.
5. **Model-based inference is broken** — `inference.py` has the same `body.` prefix
   bug as training had, causing RuntimeError when loading core weights. Users
   can only infer from full checkpoints, not from trained models.
6. **Checkpoint files not preserved across run deletion** — deleting a run config
   removes the entire run folder including all `.pth` files. Archived checkpoints
   in trainHistory reference paths that no longer exist.

## Proposal

Replace the checkpoints tab with a **model version browser**:

- **Left sidebar**: lists all models with run/checkpoint counts. Select a model
  to browse its archived training history.
- **Main area**: shows the selected model's archived sessions (from
  `model.trainHistory[]`). Each session is a collapsed card; expand to see
  checkpoints.
- **Checkpoint rows**: epoch, PSNR, SSIM, plus a "★ CORE" badge when the
  checkpoint is the model's active core.
- **Set as Core**: promotes any checkpoint to be the model's active weights
  (extracts body-only weights, updates `trained_core_weights_path`).
- **Delete**: removes checkpoint/session from `trainHistory` (archival cleanup,
  original `.pth` file and run untouched).
- **Export Package**: zips a checkpoint (body weights) + `config.json` (architecture,
  hyperparams) + `metadata.json` into a portable `.zip`.
- **Import Package**: upload a `.zip` to recreate a model in the current project.
- **Archive file preservation**: when a run completes successfully, `.pth` files
  are copied from `runs/{runId}/checkpoints/` to `models/{modelId}/archived_checkpoints/{sessionId}/`
  so they survive run deletion.
- **Bug fix**: model-based inference in `inference.py` now correctly strips the
  `body.` prefix before loading core weights.

## Key Design Decisions

1. **Data source**: checkpoints come from `model.trainHistory[*].checkpoints`,
   not from the aggregate API. This decouples the checkpoints tab from run
   lifecycle.
2. **Core tracking**: `ModelObject` gains `core_checkpoint_id` and `core_run_id`
   fields for explicit core identification. Auto-set only on first training run;
   subsequent trainings do NOT overwrite. Users manually promote via "Set as Core".
3. **Delete removes both history and files** — removing a checkpoint/session from
   `trainHistory` also deletes the orphaned `.pth` files from the model-owned
   directory (`models/{id}/archived_checkpoints/{sessionId}/`). Run-owned files
   (if the run still exists) are untouched.
4. **Runs collapsed by default** — accommodates 100+ checkpoints across many
   sessions.
5. **Export package contains full state_dict** — the `.zip` includes `model.pth`
   (full state_dict, not body-only), `config.json` (architecture, hyperparams),
   and `metadata.json`. This enables exact checkpoint reproduction, not just
   portable inference.
6. **Checkpoint files owned by model** — successful runs copy `.pth` files to
   a model-owned directory during archiving. Failed runs delete everything.
7. **Export PTH is client-side** — copies from `checkpoint.path` directly using
   Dart `File().copy()`, no backend endpoint needed.
