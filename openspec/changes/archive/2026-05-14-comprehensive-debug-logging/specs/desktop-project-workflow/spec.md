## MODIFIED Requirements

### Requirement: Backend process lifecycle
The system SHALL start the local Python FastAPI backend automatically when the desktop app needs project functionality and SHALL wait for a healthy backend before issuing API requests, while logging structured startup diagnostics including launch arguments policy, health-check attempts, bounded process output tail, and failure classifications.

#### Scenario: Backend starts successfully
- **WHEN** the user creates or opens a project
- **THEN** the Flutter app starts the backend process, confirms the health endpoint is ready, continues to the workspace, and records correlated startup lifecycle logs

#### Scenario: Backend fails to start
- **WHEN** the backend process cannot become healthy
- **THEN** the Flutter app displays a recoverable error with the most recent backend process output, backend status details, and records structured failure logs with categorized root-cause hints

### Requirement: Standard API errors
The system SHALL return local API errors in a consistent structured shape that the Flutter UI can render as actionable messages, and SHALL include correlation identifiers that map each error to frontend request logs and backend diagnostic events.

#### Scenario: API request fails
- **WHEN** the backend rejects a request
- **THEN** it returns an error object containing a stable code, human-readable message, optional details, whether the error is recoverable, and a correlation identifier for diagnostic tracing
