## 1. Logging Foundations

- [x] 1.1 Define shared structured log schema and stable event naming conventions for frontend and backend.
- [x] 1.2 Add frontend logging helper(s) with required fields, level gating, and redaction hooks.
- [x] 1.3 Add backend logging helper(s)/middleware enforcing required fields, level gating, and redaction policy.
- [x] 1.4 Implement correlation ID generation and propagation contracts between frontend API client and backend request context.
- [x] 1.5 Define stable diagnostic cause code constants for startup, transport, polling, telemetry, redaction, request validation, and workflow failures.
- [x] 1.6 Decide and document the diagnostic event sink(s), retention bounds, and local file/output behavior for desktop development and packaged runs.

## 2. Frontend Instrumentation

- [x] 2.1 Instrument user-action boundaries for project open/create, training controls, inference submit, and metrics refresh flows.
- [x] 2.2 Instrument API request lifecycle logging (dispatch, retry, timeout, response, structured error) in the frontend networking layer.
- [x] 2.3 Add scoped debug-session controls in frontend configuration/runtime state.
- [x] 2.4 Ensure frontend logs avoid sensitive payload/body dumps and validate redaction behavior.
- [x] 2.5 Extend `ApiException` handling to preserve backend-provided correlation identifiers.
- [x] 2.6 Add diagnostic coverage for direct preview/image asset loads that bypass the main API client.
- [x] 2.7 Update backend startup handling to retain bounded process output and report the latest failure tail with structured startup diagnostics.

## 3. Backend Instrumentation

- [x] 3.1 Add request ingress and response completion logs with correlation context and duration metrics.
- [x] 3.2 Instrument validation, service execution boundaries, and exception paths for project, inference, and metrics endpoints.
- [x] 3.3 Add job lifecycle logs (queued/running/canceling/canceled/completed/failed) with consistent event payloads.
- [x] 3.4 Add explicit diagnostic cause codes for hardware telemetry unavailability and stream interruption conditions.
- [x] 3.5 Extend structured API error payloads to include correlation identifiers and ensure exception handlers log correlated errors.
- [x] 3.6 Keep user-facing `Job.logs` readable while adding a separate structured diagnostic event path for job lifecycle details.

## 4. Capability-Specific Logging Requirements

- [x] 4.1 Update inference workflow code paths to emit correlated single-image and batch lifecycle diagnostic events.
- [x] 4.2 Update live metrics pipeline to log ingest, render-latency boundaries, and metric stream interruptions.
- [x] 4.3 Update desktop backend startup workflow to log health-check attempts and categorized startup failures.
- [x] 4.4 Update structured API error responses to include correlation identifiers for frontend-backend traceability.
- [x] 4.5 Update telemetry code paths to emit stable cause codes for unavailable CUDA/ROCm, vendor tooling, temperature, utilization, and speed metrics.
- [x] 4.6 Update metrics polling diagnostics to include poll target, elapsed time, interruption cause, and recovery events.

## 5. Verification and Rollout

- [x] 5.1 Add automated tests for schema conformance, required fields, and correlation propagation across tiers.
- [x] 5.2 Add automated tests for redaction of sensitive fields and prevention of raw binary payload logging.
- [x] 5.3 Add integration test scenario that reconstructs a failed user flow from frontend action to backend error using one correlation ID.
- [x] 5.4 Document troubleshooting playbook for enabling scoped debug sessions and collecting filtered logs.
- [x] 5.5 Add tests proving structured API errors expose correlation identifiers to frontend exceptions.
- [x] 5.6 Add tests proving user-facing job log tails remain concise while diagnostic job events remain structured.
- [x] 5.7 Add tests or widget coverage for preview/image asset load success and failure diagnostics.
