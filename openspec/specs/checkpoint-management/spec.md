## Purpose
Define how sr-tuner stores, validates, displays, deletes, exports, and hands off training checkpoints.

## Requirements

### Requirement: Run-based checkpoint browsing
The system SHALL show a run selection column and populate checkpoint lists and details for the selected run.

#### Scenario: Run is selected
- **WHEN** the user selects a run in the Checkpoints tab
- **THEN** the checkpoint table and details panel show checkpoints for that run

### Requirement: Checkpoint metadata
The system SHALL store checkpoint metadata including epoch, PSNR, SSIM, loss where available, file path, size, saved time, and tags.

#### Scenario: Checkpoint is saved
- **WHEN** training writes a checkpoint
- **THEN** the system records checkpoint metadata and shows it in the Checkpoints tab

### Requirement: Checkpoint payload contract
The system SHALL save enough checkpoint payload data to support inference, resume, fine-tuning, and export for supported internal models.

#### Scenario: Internal checkpoint is saved
- **WHEN** the backend saves a checkpoint for an internal PyTorch model
- **THEN** the `.pth` payload includes model weights, optimizer state when available, scheduler state when available, epoch, iteration, model config, source dataset ID, dataset scale, metric summary, app version, and checkpoint schema version

#### Scenario: Checkpoint is loaded
- **WHEN** the backend loads a checkpoint for inference, resume, fine-tuning, or export
- **THEN** it validates checkpoint schema, model architecture, scale, and required payload fields before use

### Requirement: Model-owned checkpoints (archived)
The system SHALL copy checkpoint files from run folders to a model-owned directory when a training run completes successfully. This decouples checkpoint survival from run lifecycle.

#### Scenario: Training run completes successfully
- **WHEN** a training run completes successfully and is archived to model.train_history
- **THEN** the backend copies all `.pth` files from `runs/{runId}/checkpoints/` to `models/{modelId}/archived_checkpoints/{sessionId}/`
- **AND** updates the checkpoint metadata paths to point to the new location

#### Scenario: Run is deleted after archiving
- **WHEN** a user deletes a run that has been archived to a model
- **THEN** the run folder and its `.pth` files are removed, but the model-owned copies survive

#### Scenario: Failed run checkpoint is deleted
- **WHEN** a failed run and its run folder are deleted
- **THEN** no model-owned copy exists; checkpoint history in trainHistory is preserved with empty path references

### Requirement: Checkpoint storage layout
The system SHALL maintain two storage tiers for checkpoints:
1. **Run-owned** (source of truth during training): checkpoint files under `runs/{runId}/checkpoints/`
2. **Model-owned** (archived for persistence): copies under `models/{modelId}/archived_checkpoints/{sessionId}/`
The model-owned copy is the canonical source after archiving. Run-owned files can be safely deleted.

#### Scenario: Training checkpoint is saved
- **WHEN** a run saves a training checkpoint
- **THEN** the checkpoint file is written under that run folder as the initial source of truth

#### Scenario: Archived checkpoint is referenced for inference
- **WHEN** inference or export targets an archived checkpoint
- **THEN** the backend resolves the path from the model-owned trainHistory entry, not from the run folder

### Requirement: Latest and best markers
The system SHALL mark latest checkpoint, best PSNR checkpoint, and best loss checkpoint when the data is available.

#### Scenario: Checkpoints are compared
- **WHEN** checkpoint metrics are available
- **THEN** the system identifies latest and best checkpoints in the checkpoint list

### Requirement: Checkpoint deletion
The system SHALL allow users to delete checkpoints from the UI after confirmation.

#### Scenario: User confirms deletion
- **WHEN** the user confirms checkpoint deletion
- **THEN** the system removes the checkpoint file and updates checkpoint metadata

#### Scenario: Deleted checkpoint is referenced
- **WHEN** a checkpoint selected as a fine-tune source or inference history source is deleted
- **THEN** the system preserves historical metadata but marks dependent actions unavailable until another checkpoint is selected

### Requirement: Checkpoint export
The system SHALL allow users to export supported checkpoints as `.pth` and expose ONNX export only when supported.

#### Scenario: User exports checkpoint
- **WHEN** the user chooses an available export action
- **THEN** the system writes the exported checkpoint artifact to the selected destination

### Requirement: Core checkpoint promotion
The system SHALL allow users to promote any checkpoint in a model's trainHistory to be the model's active core weights.

#### Scenario: User sets checkpoint as core
- **WHEN** the user selects a checkpoint and chooses "Set as Core"
- **THEN** the backend extracts body-only weights from that checkpoint
- **AND** stores them at `models/{modelId}/core_weights/{runId}_core.pth`
- **AND** updates the model's `core_checkpoint_id`, `core_run_id`, and `trained_core_weights_path`
- **AND** sets model status to "trained"
- **AND** the frontend refreshes to show the ★ CORE badge on the promoted checkpoint

#### Scenario: Core is set on first training
- **WHEN** a run completes its first successful training
- **THEN** the backend auto-extracts core weights from the best checkpoint
- **AND** sets `core_checkpoint_id` and `core_run_id` — but only if they are currently empty
- **AND** subsequent training runs do NOT overwrite the core IDs

### Requirement: Model-sidebar checkpoint browsing
The system SHALL present a model-centric checkpoint browser with a sidebar listing all models and a detail area showing archived training sessions.

#### Scenario: User opens checkpoints tab
- **WHEN** a project has models with trainHistory entries
- **THEN** the checkpoints tab shows a resizable sidebar (default 220px, 160-320px range) with model cards (name, status, "N runs · N checkpoints")
- **AND** the first model with trainHistory is auto-selected
- **AND** sessions are shown as collapsible cards, all collapsed by default

#### Scenario: Sidebar model is selected
- **WHEN** the user clicks a model in the sidebar
- **THEN** the detail area shows the model header (name, status, active core info, action buttons) and archived sessions

#### Scenario: All collapsed sessions
- **WHEN** the checkpoints tab loads
- **THEN** all training session cards start collapsed; users expand them individually

### Requirement: Checkpoint export package
The system SHALL allow users to export a checkpoint as a portable `.zip` package containing the full state_dict, config, and metadata.

#### Scenario: User exports checkpoint as package
- **WHEN** the user selects "Export Package" on a checkpoint
- **THEN** the backend creates a `.zip` containing `model.pth` (full state_dict), `config.json` (architecture, hyperparameters), and `metadata.json` (name, dates, source info)

### Requirement: Model package import
The system SHALL allow importing a `.zip` package to recreate a model with its checkpoint history.

#### Scenario: User imports model package
- **WHEN** the user imports a `.zip` model package from the local filesystem
- **THEN** the backend creates a new model with the imported config
- **AND** saves the `.pth` as `models/{newId}/core_weights/imported_core.pth`
- **AND** creates a trainHistory entry with `session_id="imported"`
- **AND** sets the model's status to "trained"

### Requirement: Archived checkpoint deletion (model-owned)
The system SHALL allow deleting checkpoints and sessions from a model's trainHistory, including cleaning up the model-owned `.pth` files.

#### Scenario: User deletes archived checkpoint
- **WHEN** the user confirms deleting a checkpoint from a model's trainHistory
- **THEN** the backend removes the `.pth` file from the model-owned directory
- **AND** removes the entry from its session's checkpoint list
- **AND** if the session has no more checkpoints, the session is also removed

#### Scenario: User deletes archived session
- **WHEN** the user confirms deleting an entire archived session
- **THEN** the backend removes the session's directory and all `.pth` files from the model-owned directory
- **AND** removes the session from the model's trainHistory
- **AND** the original run's files are untouched

#### Scenario: Deleted checkpoint is referenced elsewhere
- **WHEN** a checkpoint that has been deleted from trainHistory was previously used as a fine-tune source or inference record
- **THEN** the historical metadata is preserved but the action is marked unavailable

### Requirement: Inference handoff
The system SHALL allow users to send a selected checkpoint to the Inference tab.

#### Scenario: User chooses run inference
- **WHEN** the user selects a checkpoint and chooses the inference action
- **THEN** the Inference tab opens with that checkpoint selected
