## ADDED Requirements

### Requirement: Dataset source presentation
The system SHALL expose dataset source metadata for Classic Workspace source rows including source type, name, pair count, status, status severity, and optional note.

#### Scenario: Dataset source list renders
- **WHEN** the Dataset tab displays a populated dataset
- **THEN** the UI shows each source with icon, name, pair count, note, and status border color

#### Scenario: Source actions are opened
- **WHEN** the user opens a dataset source row's more menu
- **THEN** the UI shows supported source actions such as inspect, relink, remove, or unavailable-state explanations according to backend capabilities

#### Scenario: Source is unreadable
- **WHEN** validation marks a source as unreadable
- **THEN** the source row exposes recovery guidance and a remove or relink action when backend support is available

### Requirement: Dataset health checks
The system SHALL expose dataset health checks with pass, warning, or error severity for alignment, brightness, duplicate pruning, unreadable files, and other validation outcomes available from the backend.

#### Scenario: Health checks are available
- **WHEN** dataset validation or scanning records health results
- **THEN** the Dataset tab shows health check rows with severity-specific styling

### Requirement: Dataset preview and histogram
The system SHALL provide preview data for a matched LR/HR pair and histogram summary data when available.

#### Scenario: Preview pair is requested
- **WHEN** the user opens the dataset preview pane or shuffles preview selection
- **THEN** the backend returns a previewable LR/HR pair or a recoverable unavailable state

#### Scenario: User navigates preview pairs
- **WHEN** the user chooses previous or next preview pair
- **THEN** the backend returns the requested indexed pair or a bounded unavailable state

#### Scenario: Histogram channel is selected
- **WHEN** the user selects an available histogram channel such as L, A, or B
- **THEN** the histogram card updates to the selected channel when that data is available

### Requirement: Degradation pipeline display
The system SHALL store or derive a human-readable degradation pipeline summary for generated datasets.

#### Scenario: Generated dataset is displayed
- **WHEN** the selected dataset was created from video or another degradation workflow
- **THEN** the Dataset tab shows blur, noise, JPEG, downscale, and related parameter ranges when available

#### Scenario: User requests re-synthesis
- **WHEN** the user chooses Re-synthesize for a generated dataset
- **THEN** the backend either creates a new dataset version linked to the source dataset and source metadata or returns a clear unsupported-state response

### Requirement: Dataset empty onboarding
The system SHALL show the handoff's three dataset onboarding options when a project has no dataset sources.

#### Scenario: Project has no datasets
- **WHEN** the Dataset tab is selected
- **THEN** the UI shows Extract from video, Folder of images, Pre-made pairs, drop zone, and beginner guidance

### Requirement: Dataset video import wizard
The system SHALL present video dataset generation as a multi-step wizard with Source, Sampling, Filters, and Review steps.

#### Scenario: Video is selected
- **WHEN** the user chooses a source video for dataset generation
- **THEN** the wizard displays source metadata, sampling strategy controls, estimated yield, output size, and deduplication guidance before generation

### Requirement: Dataset rescan and export affordances
The system SHALL expose Dataset tab actions for adding a source, rescanning validation metadata, and exporting dataset files when backend support is available.

#### Scenario: User rescans dataset
- **WHEN** the user chooses Re-scan for a dataset
- **THEN** the backend refreshes validation/source metadata and the UI updates health and summary data
