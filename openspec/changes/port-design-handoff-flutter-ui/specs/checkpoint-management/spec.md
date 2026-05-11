## ADDED Requirements

### Requirement: Aggregate checkpoint view
The system SHALL expose a project-level checkpoint aggregate view derived from run-owned metadata for the Classic Workspace Checkpoints tab.

#### Scenario: Checkpoints tab opens
- **WHEN** the project has checkpoints across one or more runs
- **THEN** the UI can display aggregate count, best checkpoint, PSNR trend, and checkpoint table rows

#### Scenario: Manual checkpoint is displayed
- **WHEN** a checkpoint is tagged as manual or starred
- **THEN** the table displays the manual/star state and protects it from automatic pruning according to retention policy

### Requirement: Checkpoint ranking strip
The system SHALL provide checkpoint metric trend data and deltas needed to render the handoff PSNR strip.

#### Scenario: PSNR data is available
- **WHEN** checkpoints include PSNR metrics
- **THEN** the Checkpoints tab shows the trend and improvement from first comparable checkpoint to best checkpoint

### Requirement: Checkpoint row actions
The system SHALL expose available row actions for inference handoff, resume from checkpoint, export, delete, and more-menu actions according to checkpoint support and deletion state.

#### Scenario: Row actions render
- **WHEN** a checkpoint row is displayed
- **THEN** unavailable actions are disabled and available actions call the corresponding backend workflow

#### Scenario: User selects checkpoints for comparison
- **WHEN** comparison is supported and the user uses multi-select such as command-click
- **THEN** the UI tracks selected checkpoints and enables comparison only when a valid comparison set is selected

### Requirement: Continue from best
The system SHALL allow users to continue training from the best compatible checkpoint when resume metadata is valid.

#### Scenario: User continues from best
- **WHEN** the user chooses Continue from best
- **THEN** the app starts or prepares a resume workflow using the best compatible checkpoint

### Requirement: Checkpoint empty state actions
The system SHALL show the handoff empty state when no checkpoints exist and provide Start training and Import checkpoint actions according to backend support.

#### Scenario: No checkpoints exist
- **WHEN** the Checkpoints tab opens before any checkpoint is available
- **THEN** the UI explains that training creates checkpoints and routes Start training to the Training tab

### Requirement: Checkpoint comparison and pruning affordances
The system SHALL expose comparison and pruning affordances only when backend support exists or SHALL render them disabled with clear unavailable state.

#### Scenario: Compare is unavailable
- **WHEN** checkpoint comparison is not implemented
- **THEN** the Compare side-by-side action is disabled rather than silently failing

### Requirement: Automatic checkpoint pruning policy
The system SHALL apply run-owned automatic checkpoint pruning policy for retaining best checkpoints plus protected saves, or explicitly disable pruning where unsupported.

#### Scenario: Automatic pruning is enabled
- **WHEN** a run saves a new automatic checkpoint and retention limits are configured
- **THEN** checkpoint management prunes older automatic checkpoints according to the owning run policy while preserving manual, crash-snapshot, exported, or protected checkpoints

#### Scenario: Pruning is unavailable
- **WHEN** automatic pruning is not implemented for the selected run
- **THEN** pruning controls render disabled or explain that checkpoints must be managed manually
