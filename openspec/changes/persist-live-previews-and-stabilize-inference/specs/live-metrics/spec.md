## ADDED Requirements

### Requirement: Epoch-scoped preview artifact storage
The system SHALL save Live preview images as persistent epoch-scoped artifacts under the run folder.

#### Scenario: Epoch preview is generated
- **WHEN** training finishes an epoch
- **THEN** the backend saves the preview images under `runs/<run_id>/previews/epoch_0001/` using the current epoch number

#### Scenario: Run names change
- **WHEN** a run has a user-facing name that contains spaces, duplicates another run name, or is later edited
- **THEN** preview artifact paths continue to use the stable run ID folder and remain valid

### Requirement: Preview asset names match UI slots
The system SHALL name saved preview files according to the Live preview slots.

#### Scenario: Base preview assets are saved
- **WHEN** an epoch preview is generated
- **THEN** the backend writes `input.png`, `output.png`, and `target.png`

#### Scenario: Absolute diff mode is selected
- **WHEN** `diff_mode` is `absolute`
- **THEN** the backend writes `diff_absolute.png` and does not require `diff_heatmap.png`

#### Scenario: Heatmap diff mode is selected
- **WHEN** `diff_mode` is `heatmap`
- **THEN** the backend writes `diff_heatmap.png` and does not require `diff_absolute.png`

#### Scenario: Both diff modes are selected
- **WHEN** `diff_mode` is `both`
- **THEN** the backend writes both `diff_absolute.png` and `diff_heatmap.png`

### Requirement: Preview source follows validation availability
The system SHALL choose the preview source based on validation availability for the run.

#### Scenario: Validation is enabled and available
- **WHEN** validation is enabled and at least one validation sample exists
- **THEN** the epoch preview uses the first validation sample

#### Scenario: Validation is disabled
- **WHEN** validation is disabled or the validation split is `0.0`
- **THEN** the epoch preview uses the first training sample

#### Scenario: Validation split has no usable samples
- **WHEN** validation is enabled but no validation samples are available
- **THEN** the epoch preview falls back to the first training sample

### Requirement: Live preview metadata references saved files
The system SHALL return preview metadata whose asset URLs point to saved epoch preview files.

#### Scenario: Latest preview is requested
- **WHEN** the Live tab requests preview metadata for a run
- **THEN** the backend returns the latest saved epoch preview metadata including asset kind, URL, dimensions, and generated timestamp

#### Scenario: No epoch preview exists yet
- **WHEN** a run has started but no epoch preview has been saved
- **THEN** the backend returns no preview assets or an explicit unavailable state so the Live tab can show skeleton placeholders

### Requirement: Live preview refresh is epoch-bound
The Live tab SHALL refresh preview metadata and image URLs only when the active epoch changes or the selected active run changes.

#### Scenario: Metrics poll within same epoch
- **WHEN** live metric polling updates within the same epoch
- **THEN** the frontend keeps the current preview image URLs instead of requesting image assets again

#### Scenario: Epoch changes
- **WHEN** the active run advances to a new epoch
- **THEN** the frontend requests preview metadata for the latest epoch and displays the saved preview files
