## ADDED Requirements

### Requirement: Inference blocked checklist
The system SHALL render a locked Inference state with a checklist for Dataset, Model, Training run reaching minimum useful progress, and Saved checkpoint prerequisites.

#### Scenario: Checkpoint is missing
- **WHEN** the user opens Inference without a usable checkpoint
- **THEN** the tab shows completed and missing prerequisites with Go actions for incomplete items

### Requirement: Inference inspector
The system SHALL provide output inspector data including resolution, format, filename, bit depth when known, runtime, PSNR estimate, sharpness gain when available, and selected tuning parameters.

#### Scenario: Inference result is selected
- **WHEN** an inference result is selected or completed
- **THEN** the inspector shows output metadata and quality/timing information from the inference record

### Requirement: Recent inference filmstrip
The system SHALL show recent inference records as a filmstrip with selectable thumbnails or placeholders.

#### Scenario: History exists
- **WHEN** the project has inference history
- **THEN** the Inference tab displays recent outputs and selecting one loads it into the viewer

#### Scenario: User chooses add tile
- **WHEN** the user selects the filmstrip add tile
- **THEN** the app opens the input picker or drop workflow without losing the currently selected result

### Requirement: Batch drop zone
The system SHALL provide a batch folder drop zone and batch folder picker for inference when batch inference is available.

#### Scenario: User drops folder
- **WHEN** the user drops a folder onto the batch area
- **THEN** the folder is selected for batch inference or the UI reports why the drop cannot be accepted

### Requirement: Tuning controls
The system SHALL expose inference tuning controls for denoise strength, detail boost, and color preserve when the selected model/backend supports them.

#### Scenario: Tuning is unsupported
- **WHEN** the selected checkpoint does not support a tuning control
- **THEN** the control is disabled or omitted and the backend ignores no unsupported tuning silently

### Requirement: Handoff compare viewer
The system SHALL render the handoff compare viewer with slider mode, two-up mode, before/after labels, dimensions, and draggable divider.

#### Scenario: User switches compare mode
- **WHEN** the user selects Slider or 2-up
- **THEN** the viewer changes mode without rerunning inference and preserves the selected result
