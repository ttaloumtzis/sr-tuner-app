## Purpose
Define how sr-tuner reports active training status, metric history, hardware telemetry, and validation previews.

## Requirements

### Requirement: Active run status
The system SHALL show active training status, model, dataset, epoch, iteration, and pause/stop controls in the Live Metrics tab.

#### Scenario: Training is active
- **WHEN** a run is training
- **THEN** Live Metrics displays the run status and current progress

### Requirement: Metric cards and charts
The system SHALL display loss, PSNR, SSIM, learning rate, progress, and speed as live metric cards and history charts, and SHALL log structured diagnostic events for metric ingest, render latency, and stream interruption conditions.

#### Scenario: Metrics are written
- **WHEN** the backend records new training metrics
- **THEN** the Live Metrics tab updates the displayed values and curves and both frontend and backend emit correlated diagnostic logs for ingest and render update boundaries

#### Scenario: Metrics polling is interrupted
- **WHEN** the frontend metrics poller encounters a timeout, transport failure, or backend error
- **THEN** the frontend emits a correlated diagnostic event with poll target, elapsed time, and a stable interruption cause code

### Requirement: Metric definitions
The system SHALL define how training and validation metrics are computed and SHALL persist enough metadata for charts to be interpreted after reopening a project.

#### Scenario: PSNR is computed
- **WHEN** validation PSNR is recorded
- **THEN** the backend stores whether PSNR was computed on RGB or luminance, the input value range, and whether the value is from a preview batch or the full validation split

#### Scenario: SSIM is computed
- **WHEN** validation SSIM is recorded
- **THEN** the backend stores the image channel policy, value range, and aggregation scope used for the value

#### Scenario: Loss is recorded
- **WHEN** loss values are written
- **THEN** the backend records component losses separately where available and records total loss using the configured loss weights

#### Scenario: Speed is recorded
- **WHEN** iteration speed is displayed
- **THEN** the backend reports whether the value is the last interval or a moving average

### Requirement: Hardware panel
The system SHALL display available runtime hardware telemetry such as device name, memory usage, utilization, temperature, and iteration speed, and SHALL report telemetry collection unavailability with explicit diagnostic cause codes.

#### Scenario: Hardware telemetry is available
- **WHEN** the backend reports hardware statistics
- **THEN** Live Metrics renders them in a hardware panel and logs a correlated telemetry update event

#### Scenario: Hardware telemetry is unavailable
- **WHEN** a platform or device cannot provide utilization, temperature, or memory telemetry
- **THEN** the backend marks those fields unavailable rather than reporting misleading zero values and logs a structured unavailability reason with a stable diagnostic cause code

### Requirement: Validation preview
The system SHALL display validation LR input, SR output, HR target, and diff preview images for the active run.

#### Scenario: Validation preview is generated
- **WHEN** a validation preview is produced
- **THEN** the Live Metrics tab displays the latest input, output, target, and diff images

### Requirement: Diff mode configuration
The system SHALL support absolute difference, heatmap, or both as validation diff modes selected from Training Setup.

#### Scenario: Diff mode is selected
- **WHEN** a validation preview is generated
- **THEN** the backend creates the diff output according to the selected mode
