## Purpose
Define cross-cutting diagnostic logging, correlation propagation, structured API error tracing, runtime logging controls, redaction, and stable cause codes for frontend and backend observability.

## Requirements

### Requirement: Unified structured diagnostic logs
The system SHALL emit diagnostic logs in a structured machine-parseable format across frontend and backend with mandatory fields for timestamp, severity, component, stable event name, and correlation context.

#### Scenario: Frontend emits a diagnostic event
- **WHEN** a user action triggers a logged frontend event
- **THEN** the event includes the required structured fields and a stable event name

#### Scenario: Backend emits a diagnostic event
- **WHEN** a backend request or job lifecycle event is logged
- **THEN** the event includes the same required structured fields and is machine-parseable without regex parsing

### Requirement: End-to-end correlation propagation
The system SHALL propagate correlation context from frontend user action through API requests to backend request and job execution logs.

#### Scenario: Correlated request succeeds
- **WHEN** the frontend sends an API request with correlation context
- **THEN** backend logs for ingress, service execution, and completion contain the same correlation identifier

#### Scenario: Correlation context is missing
- **WHEN** an inbound request lacks correlation metadata
- **THEN** the backend generates fallback correlation context and records that fallback generation occurred

### Requirement: Correlated structured API errors
The system SHALL include correlation identifiers in structured API error responses and SHALL preserve those identifiers in frontend API exceptions.

#### Scenario: Backend rejects a correlated request
- **WHEN** a backend endpoint returns a structured API error for a request with correlation context
- **THEN** the error response includes the same correlation identifier as the backend diagnostic logs for that request

#### Scenario: Frontend handles a correlated API error
- **WHEN** the frontend receives a structured API error containing a correlation identifier
- **THEN** the frontend exception preserves that identifier for UI display, diagnostics, and troubleshooting workflows

### Requirement: Logging level controls and scoped debug sessions
The system SHALL support runtime logging levels and scoped debug sessions that can increase verbosity temporarily without requiring permanent global debug mode.

#### Scenario: Default logging mode
- **WHEN** no scoped debug session is active
- **THEN** the system logs only baseline levels configured for normal operation

#### Scenario: Scoped debug session is enabled
- **WHEN** a debug session is activated for a specific project or runtime session
- **THEN** additional debug events are emitted only within the configured scope and duration

### Requirement: Sensitive data redaction
The system SHALL redact or suppress sensitive values before writing logs, including session secrets, credentials, and raw binary payload content.

#### Scenario: Sensitive value is present in log context
- **WHEN** a logging call includes fields marked sensitive by policy
- **THEN** the persisted log output replaces those values with redacted placeholders or omits them

#### Scenario: Request contains binary or image payload data
- **WHEN** a request or workflow contains raw binary, image, checkpoint, or tensor payload content
- **THEN** diagnostic logs record bounded metadata only and do not persist the raw payload content

### Requirement: Diagnostic events are separate from user-facing job logs
The system SHALL preserve concise user-facing job log tails while emitting separate structured diagnostic events for request, job, and workflow troubleshooting.

#### Scenario: Job progress is shown in the UI
- **WHEN** a job updates user-facing progress
- **THEN** the job log tail remains readable text intended for users

#### Scenario: Job emits diagnostic detail
- **WHEN** a job lifecycle or failure boundary is logged for troubleshooting
- **THEN** the diagnostic event includes structured fields, severity, stable event name, and correlation context without requiring the UI job log tail to contain those fields

### Requirement: Diagnostic coverage for direct network asset loads
The system SHALL provide diagnostic coverage for frontend network requests that bypass the primary API client, including preview and image asset loading.

#### Scenario: Preview asset loads successfully
- **WHEN** the frontend loads a preview or image asset directly from the backend
- **THEN** the frontend records a diagnostic event with asset type, request URL path, duration, and correlation context

#### Scenario: Preview asset load fails
- **WHEN** a preview or image asset request fails
- **THEN** the frontend records a diagnostic event with failure classification and correlation context

### Requirement: Stable diagnostic cause codes
The system SHALL use stable machine-readable cause codes for known diagnostic failure classes including backend startup failure, transport failure, poll interruption, telemetry unavailability, and payload redaction.

#### Scenario: Known failure condition is logged
- **WHEN** a known diagnostic failure condition occurs
- **THEN** the diagnostic event includes a stable cause code in addition to any human-readable message
