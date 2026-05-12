## ADDED Requirements

### Requirement: Project dashboard summary
The system SHALL expose a project dashboard summary with dataset count, model count, run count, dataset pair total, active model, best available PSNR, active run state, backend status, device badge, project path, app version, VCS branch when available, and disk free status.

#### Scenario: Overview opens
- **WHEN** the user opens the Overview tab
- **THEN** the UI can render header badges, metric cards, and status bar values from the dashboard summary

### Requirement: Recent projects
The system SHALL remember recent projects opened on the local machine with project name, path, last opened time, status, and short summary metadata.

#### Scenario: Start screen opens
- **WHEN** the user launches sr-tuner
- **THEN** recent project cards are available for display and can be filtered by the start screen

#### Scenario: Recent project is selected
- **WHEN** the user selects a recent project card
- **THEN** the app opens that project path using the same validation flow as manual project open

### Requirement: Project activity feed
The system SHALL expose recent project activity events for dataset, model, run, checkpoint, and inference actions with timestamp, category, severity, and description.

#### Scenario: Activity is recorded
- **WHEN** a tracked project action completes or fails
- **THEN** the dashboard activity feed includes a concise event suitable for the Overview tab

### Requirement: Next step guidance
The system SHALL derive a next-step recommendation from project prerequisites and active state.

#### Scenario: Project has no dataset
- **WHEN** the project has no usable dataset
- **THEN** the dashboard recommends creating or importing a dataset

#### Scenario: Project is ready to train
- **WHEN** the project has a usable dataset and compatible model but no active run
- **THEN** the dashboard recommends configuring or resuming training

#### Scenario: Project has usable checkpoint
- **WHEN** the project has a usable checkpoint
- **THEN** the dashboard can recommend running inference or continuing from the best checkpoint

#### Scenario: Training loss plateaus
- **WHEN** recent run metrics indicate a plateau according to backend policy
- **THEN** the dashboard can recommend actions such as tuning the learning rate, trying inference, or resuming with adjusted settings

### Requirement: Workspace preferences
The system SHALL store workspace preferences for theme and density and SHALL default missing preferences without breaking existing projects.

#### Scenario: User changes density
- **WHEN** the user selects compact or comfortable density
- **THEN** the preference is persisted for the project workspace and applied when the project reopens

### Requirement: Status bar data
The system SHALL expose status bar data including app version, project path, optional VCS branch, backend state, disk free amount, disk warning state, and current idle/busy state.

#### Scenario: Disk is low
- **WHEN** project storage has less than the configured free-space threshold
- **THEN** the status bar marks disk status as warning and write-heavy actions can show caution
