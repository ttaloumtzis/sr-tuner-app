## MODIFIED Requirements

### Requirement: Metric cards and charts
The system SHALL display loss, PSNR, SSIM, learning rate, progress, and speed as live metric cards and history charts, and SHALL log structured diagnostic events for metric ingest, render latency, and stream interruption conditions.

#### Scenario: Metrics are written
- **WHEN** the backend records new training metrics
- **THEN** the Live Metrics tab updates the displayed values and curves and both frontend and backend emit correlated diagnostic logs for ingest and render update boundaries

#### Scenario: Metrics polling is interrupted
- **WHEN** the frontend metrics poller encounters a timeout, transport failure, or backend error
- **THEN** the frontend emits a correlated diagnostic event with poll target, elapsed time, and a stable interruption cause code

### Requirement: Hardware panel
The system SHALL display available runtime hardware telemetry such as device name, memory usage, utilization, temperature, and iteration speed, and SHALL report telemetry collection unavailability with explicit diagnostic cause codes.

#### Scenario: Hardware telemetry is available
- **WHEN** the backend reports hardware statistics
- **THEN** Live Metrics renders them in a hardware panel and logs a correlated telemetry update event

#### Scenario: Hardware telemetry is unavailable
- **WHEN** a platform or device cannot provide utilization, temperature, or memory telemetry
- **THEN** the backend marks those fields unavailable rather than reporting misleading zero values and logs a structured unavailability reason with a stable diagnostic cause code
