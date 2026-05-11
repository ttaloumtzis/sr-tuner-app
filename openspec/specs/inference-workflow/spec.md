## Purpose
Define how sr-tuner runs checkpoint-based single-image and batch super-resolution inference and records outputs.

## Requirements

### Requirement: Single image inference
The system SHALL allow users to run inference on a single image using a selected model checkpoint.

#### Scenario: Single image is processed
- **WHEN** the user selects an image, checkpoint, output settings, and starts inference
- **THEN** the backend writes the SR output and records inference metadata

### Requirement: Batch inference
The system SHALL allow users to run inference on a folder of images using a selected model checkpoint.

#### Scenario: Batch folder is processed
- **WHEN** the user selects a folder and starts batch inference
- **THEN** the backend writes outputs for supported images and records batch inference metadata

### Requirement: Checkpoint-derived scale
The system SHALL derive inference scale from the selected model checkpoint instead of allowing arbitrary incompatible scale changes.

#### Scenario: Checkpoint is selected
- **WHEN** the user selects a checkpoint
- **THEN** the Inference tab displays the checkpoint scale and uses it for inference

### Requirement: Inference dependency availability
The system SHALL detect required inference dependencies and selected device support before launching inference jobs.

#### Scenario: Required inference dependency is missing
- **WHEN** model loading or image processing dependencies are unavailable
- **THEN** Inference disables run actions and reports the missing dependency

### Requirement: Output persistence
The system SHALL save inference outputs inside the project by default and allow users to choose output format and destination.

#### Scenario: Inference completes
- **WHEN** inference finishes successfully
- **THEN** output files and inference metadata are saved under the project unless the user selected another destination

### Requirement: Inference tiling
The system SHALL support tiled inference settings for large images and SHALL record the effective tiling configuration in inference metadata.

#### Scenario: Tiling is enabled
- **WHEN** the user runs inference with tiling
- **THEN** the backend uses tile size, overlap, padding mode, and blend strategy from the request and stores those values in the inference record

#### Scenario: Image is too large for selected device
- **WHEN** inference fails because the selected device lacks memory
- **THEN** the backend returns a recoverable error suggesting smaller tile size, CPU fallback, or lower concurrency

### Requirement: Inference history
The system SHALL store inference history objects with input path, output path, checkpoint, scale, tile settings, device, runtime, and available metrics.

#### Scenario: User reopens project
- **WHEN** a project with inference history is opened
- **THEN** previous inference records are available from project metadata

### Requirement: Batch inference partial results
The system SHALL preserve successful batch inference outputs and report per-file failures when some images fail.

#### Scenario: Batch inference has mixed results
- **WHEN** some input images process successfully and others fail
- **THEN** the backend records completed outputs, per-file errors, and an overall partial-complete status for the batch job

### Requirement: Before after comparison
The system SHALL provide a draggable vertical before/after comparison preview for inference results.

#### Scenario: Output preview is available
- **WHEN** inference output is loaded
- **THEN** the user can drag a vertical divider to compare input and output images

### Requirement: Preview modes
The system SHALL support side-by-side comparison and zoom or pan controls for inference previews.

#### Scenario: User changes preview mode
- **WHEN** the user selects an available preview mode
- **THEN** the preview updates without rerunning inference
