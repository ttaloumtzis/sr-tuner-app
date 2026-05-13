## MODIFIED Requirements

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
