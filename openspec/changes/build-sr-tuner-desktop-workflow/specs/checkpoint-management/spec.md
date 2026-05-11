## ADDED Requirements

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

### Requirement: Run-owned checkpoints
The system SHALL store checkpoint metadata as part of the owning run, with any project-level checkpoint list treated only as a derived index.

#### Scenario: Run checkpoint is created
- **WHEN** a run writes checkpoint metadata
- **THEN** the checkpoint record is associated with that run ID and uses a project-relative path under the run folder

#### Scenario: Project checkpoint index is rebuilt
- **WHEN** the project is opened or checkpoint metadata changes
- **THEN** any project-level checkpoint view is derived from run-owned checkpoint metadata

### Requirement: Checkpoint storage layout
The system SHALL treat run folders as the canonical storage location for training checkpoints and SHALL reserve any project-level `checkpoints/` folder for derived indexes, exports, or cache artifacts only.

#### Scenario: Training checkpoint is saved
- **WHEN** a run saves a training checkpoint
- **THEN** the checkpoint file is written under that run folder and not as the source of truth in a top-level project checkpoint folder

#### Scenario: Project-level checkpoint folder exists
- **WHEN** the project contains a top-level `checkpoints/` folder
- **THEN** the backend treats its contents as derived, exported, or cache artifacts and rebuilds authoritative checkpoint state from run-owned metadata

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

### Requirement: Inference handoff
The system SHALL allow users to send a selected checkpoint to the Inference tab.

#### Scenario: User chooses run inference
- **WHEN** the user selects a checkpoint and chooses the inference action
- **THEN** the Inference tab opens with that checkpoint selected
