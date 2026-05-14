## Purpose
Define how sr-tuner runs checkpoint-based single-image and batch super-resolution inference and records outputs.

## Requirements

### Requirement: Single image inference
The system SHALL allow users to run inference on a single image using a selected model checkpoint, and SHALL record correlated diagnostic logs across frontend action, API request lifecycle, backend execution stages, and completion outcome.

#### Scenario: Single image is processed
- **WHEN** the user selects an image, checkpoint, output settings, and starts inference
- **THEN** the backend writes the SR output, records inference metadata, and emits correlated logs that identify request dispatch, job start, execution milestones, and final status

### Requirement: Batch inference
The system SHALL allow users to run inference on a folder of images using a selected model checkpoint, and SHALL emit structured per-batch diagnostic summaries with correlation context and per-file failure details where applicable.

#### Scenario: Batch folder is processed
- **WHEN** the user selects a folder and starts batch inference
- **THEN** the backend writes outputs for supported images, records batch inference metadata, and emits correlated batch lifecycle logs including counts of successes and failures

### Requirement: Trained model-based inference
The system SHALL use trained models (with core weights) for inference instead of individual checkpoints. The user SHALL specify the output scale at inference time.

#### Scenario: Trained model is selected
- **WHEN** the user selects a trained model in Inference
- **THEN** the UI displays the model's core architecture (num_features, num_blocks) and allows output scale selection

#### Scenario: User specifies output scale
- **WHEN** the user sets output scale for inference
- **THEN** the backend constructs output layer with the specified scale using the model's core weights

#### Scenario: No trained models available
- **WHEN** the project has no trained models (no trained_core_weights_path)
- **THEN** Inference tab shows a message that no trained models are available and directs user to train first

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
The system SHALL store inference history objects with input path, output path, model_id, output_scale, tile settings, device, runtime, and available metrics.

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
