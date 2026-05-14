## Why

Diagnosing issues across the desktop frontend, its API communication layer, and backend services is currently slow and inconsistent because telemetry is fragmented and lacks correlation. We need a standardized debug logging and traceability model now to reduce mean time to resolution and make production-like troubleshooting reproducible in local and CI environments.

## What Changes

- Introduce a unified debug observability capability covering structured logs, correlation IDs, log levels, and redaction rules across frontend and backend.
- Add deterministic request/response logging for frontend-to-backend communication, including transport errors, retries, and timeout reasons.
- Add backend request lifecycle logging (ingress, validation, service execution, DB/IO boundaries, response) with shared context fields.
- Add correlation identifiers to structured API errors so frontend failures can be tied to backend request and service logs.
- Preserve user-facing job log tails while adding separate diagnostic events for machine-readable troubleshooting.
- Cover direct frontend network paths, including preview/image asset requests that bypass the main API client.
- Define runtime controls for verbosity (default/info/debug/trace) and scoped debug sessions to avoid noisy always-on logging.
- Define minimum log quality requirements: stable event names, machine-parseable payloads, and timestamp/source consistency.
- Define deterministic diagnostic cause codes for unavailable telemetry, backend startup failures, poll interruptions, and transport failures.
- Define operator workflows for collecting and filtering logs for a single user action or run.

## Capabilities

### New Capabilities
- `debug-observability`: End-to-end structured logging and correlation model spanning frontend, API boundary, and backend execution paths.

### Modified Capabilities
- `inference-workflow`: Add requirements for correlated logs across inference request submission, execution, and result handling.
- `live-metrics`: Add requirements for debug visibility into metric stream interruptions, lag, and source-of-truth reconciliation.
- `desktop-project-workflow`: Add requirements for frontend diagnostic logging around user-triggered actions and API orchestration.

## Impact

- Frontend application logging adapters, API client/interceptor layer, and state/action instrumentation points.
- Backend HTTP/middleware/service layers, error handling pipeline, and persistence/integration boundaries.
- Backend process startup/health-check capture, including failure-tail reporting.
- Job infrastructure, inference workflow, live metrics polling, and direct preview asset loading.
- Shared schema for log fields (trace/request/session IDs, component, event name, severity, payload metadata).
- Developer tooling and docs for log configuration, filtering, and incident triage workflows.
