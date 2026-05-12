## ADDED Requirements

### Requirement: Classic training setup layout
The system SHALL render Training as the handoff's three-column workspace covering Basics, Schedule, Optimizer, Loss, Validation, Checkpoints, and Estimate sections, including visible unsupported-loss states.

#### Scenario: Training prerequisites are met
- **WHEN** a usable dataset and compatible model exist
- **THEN** Training displays the Classic Workspace run setup layout with current draft settings

#### Scenario: Unsupported loss is shown
- **WHEN** a loss option such as FFT, perceptual, or adversarial loss is visible but unsupported by the selected backend path
- **THEN** the loss row is disabled or marked unavailable and cannot be silently applied

### Requirement: Training estimate
The system SHALL provide estimated time, iterations per epoch, VRAM peak, and disk per checkpoint when enough dataset/model/device information is available.

#### Scenario: Estimate is available
- **WHEN** the user selects dataset, model, device, and schedule settings
- **THEN** the Training tab displays the estimate values in the Estimate card

### Requirement: Low pair count guard
The system SHALL warn or block training startup when the selected dataset has fewer than the configured minimum useful pair count for super-resolution training.

#### Scenario: Dataset has fewer than 100 pairs
- **WHEN** the user attempts to start training with fewer than 100 usable pairs
- **THEN** the UI shows beginner guidance that the model may not generalize and requires explicit confirmation or additional data according to backend policy

### Requirement: Clone and resume training actions
The system SHALL expose actions to clone settings from an existing run and resume training when a compatible run or checkpoint exists.

#### Scenario: User clones settings
- **WHEN** the user chooses Clone settings from an existing run
- **THEN** the training draft is populated from that run without mutating the source run

### Requirement: Suggested training fixes
The system SHALL expose applyable training fixes for known recoverable failures such as CUDA out-of-memory.

#### Scenario: Suggested fix is applied
- **WHEN** the user applies a suggested fix such as lower batch size, lower crop size, AMP, or gradient checkpointing
- **THEN** the backend validates and writes the setting change into the run or draft config and enables retry when prerequisites are met

### Requirement: Checkpoint retention settings
The system SHALL make training runs the owner of checkpoint retention settings including save cadence, keep-best metric, maximum retained automatic checkpoints, manual-save protection, and EMA settings when supported.

#### Scenario: User configures keep-best policy
- **WHEN** the user configures checkpoint retention for a run
- **THEN** the backend stores the policy on the run configuration so checkpoint management can apply it consistently

#### Scenario: EMA is unsupported
- **WHEN** EMA checkpointing is visible but unsupported by the selected training path
- **THEN** the UI disables the setting or reports why it cannot be applied

### Requirement: Stop confirmation detail
The system SHALL confirm destructive stop actions with recent checkpoint and loss context when available.

#### Scenario: User stops active training
- **WHEN** the user chooses Stop on an active run
- **THEN** the app shows a confirmation dialog with run name, last checkpoint age, and latest loss when available
