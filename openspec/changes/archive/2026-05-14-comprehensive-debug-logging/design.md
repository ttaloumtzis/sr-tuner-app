## Context

The current system spans a Flutter desktop frontend and a local FastAPI backend with several long-running workflows (training, checkpointing, inference, metrics polling). Debugging failures is difficult because logs are inconsistent across tiers, request context is not reliably correlated, and frontend API failures are not captured with enough structured detail to map user actions to backend behavior. This change introduces a unified observability contract for diagnostic logging without changing core product workflows.

## Goals / Non-Goals

**Goals:**
- Define a shared structured logging schema for frontend and backend with mandatory correlation fields.
- Ensure every frontend API call and backend request lifecycle event can be traced end-to-end for a single user action.
- Ensure direct network paths outside the main API client, such as preview/image asset loads, have diagnostic coverage.
- Attach correlation identifiers to structured API errors returned to the Flutter client.
- Provide deterministic handling of verbosity levels and scoped debug sessions.
- Preserve security and privacy through explicit redaction requirements.
- Preserve concise user-facing job progress logs while adding machine-readable diagnostic logs.
- Make logs operationally useful for local development, packaged desktop runs, and CI diagnostics.

**Non-Goals:**
- Introducing distributed tracing infrastructure (e.g., OpenTelemetry exporters, external SaaS collectors) in this phase.
- Replacing existing business metrics or training metrics storage with log data.
- Capturing full payload bodies by default for every request.
- Building a remote centralized log aggregation service.

## Decisions

1. Unified structured event schema
   - Decision: All new diagnostic logs use a structured JSON shape with required fields: `timestamp`, `level`, `component`, `event`, `message`, `session_id`, `request_id`, `correlation_id`, and `context`.
   - Rationale: A consistent schema enables cross-tier filtering and future tooling with minimal parser complexity.
   - Alternative considered: Keep free-form text logs and rely on regex parsing. Rejected because it is brittle and expensive to maintain.

2. Correlation propagation from frontend through backend
   - Decision: The frontend generates correlation identifiers for user-triggered flows and attaches them to API requests; backend logs must include and propagate those IDs through service and job layers.
   - Rationale: Correlation is the shortest path to isolate failures that cross UI, API transport, and backend execution.
   - Alternative considered: Backend-only request IDs. Rejected because it does not map reliably to UI actions or chained calls.

3. Tier-specific instrumentation boundaries
   - Decision: Frontend logs at user-action, request dispatch, response/error, retry, and timeout boundaries; backend logs at ingress, validation, service execution boundaries, external IO, completion, and exception boundaries.
   - Rationale: These boundaries create enough visibility to reconstruct failures without high-volume internal noise.
   - Alternative considered: Deep per-function tracing. Rejected for high noise and performance overhead.

4. Runtime-configurable verbosity with scoped sessions
   - Decision: Default logging remains production-safe (`info` baseline), with temporary scoped `debug`/`trace` sessions that can be enabled per run/session and automatically expire.
   - Rationale: Avoids permanent noisy logs while enabling targeted diagnosis.
   - Alternative considered: Global always-on debug mode. Rejected due to log volume and potential sensitive data exposure.

5. Redaction-first policy
   - Decision: Sensitive fields (tokens, filesystem secrets, private env values, and raw binary/image data) are excluded or redacted before serialization.
   - Rationale: Diagnostic utility must not compromise local security or privacy.
   - Alternative considered: Log everything in debug mode. Rejected due to avoidable data leakage risk.

6. Separate user-facing job logs from diagnostic events
   - Decision: Keep existing `Job.logs` as concise human-facing progress text and introduce a separate structured diagnostic stream/helper for request, job, and workflow events.
   - Rationale: UI progress needs short readable messages, while diagnostics need event names, severity, timestamps, durations, and correlation context.
   - Alternative considered: Convert `Job.logs` directly to structured events. Rejected because it would either break current UI expectations or force diagnostic noise into user-facing panels.

7. Correlation ID format
   - Decision: Use standard UUID values generated with platform libraries for `correlation_id` and `request_id`.
   - Rationale: UUID generation is available in both tiers without adding new infrastructure, is familiar in logs, and avoids depending on sortable UUIDv7 support.
   - Alternative considered: UUIDv7. Deferred because it may require extra dependencies and log sorting already has timestamps.

8. Scoped debug session storage
   - Decision: Store scoped debug session state in runtime memory for this change; do not persist it into project metadata.
   - Rationale: Debug sessions are temporary operational controls and should not become durable project behavior.
   - Alternative considered: Persist debug state in `sr-tuner.project.json`. Rejected because it could accidentally enable noisy or sensitive diagnostics on reopen.

9. Startup failure log tail
   - Decision: Backend startup diagnostics should retain bounded process output and expose the most recent lines when startup fails.
   - Rationale: Startup failures are usually explained by the latest stderr/stdout lines, not the first lines of process output.
   - Alternative considered: Keep current first-lines behavior. Rejected because it can hide the actionable failure.

## Risks / Trade-offs

- [High log volume in debug/trace] → Mitigation: Use level gating, scoped session activation, and bounded log tails for UI surfaces.
- [Partial correlation coverage during rollout] → Mitigation: Add conformance checks in tests and fallback generation when inbound correlation is missing.
- [Performance regression from excessive serialization] → Mitigation: Avoid large payload logging, use lazy formatting, and sample repetitive events where needed.
- [Developer inconsistency in event naming] → Mitigation: Define stable naming conventions and require shared helpers for event emission.
- [Diagnostic logs expose local paths or tokens] → Mitigation: Centralize redaction, forbid request body dumps by default, and add tests for tokens, env values, file paths marked private, and binary/image payloads.
- [Direct asset requests remain invisible] → Mitigation: Wrap image/preview loading through diagnostic-aware helpers or explicitly instrument load/error callbacks with correlation context.

## Migration Plan

1. Introduce shared logging schema/constants and helper APIs in frontend and backend.
2. Instrument API client/server middleware to establish request/correlation propagation.
3. Extend structured API error payloads and frontend exceptions with correlation IDs.
4. Add boundary logs in key workflows (project open, backend startup, training control, inference, metrics polling, job management, preview asset loading).
5. Add redaction layer and test fixtures validating sensitive-field suppression.
6. Roll out runtime-only debug-session controls and documentation for troubleshooting playbooks.
7. Validate with integration scenarios that reconstruct a failure from frontend action to backend error using a single correlation ID.
8. Keep user-facing job log tails intact, then deprecate duplicate unstructured diagnostic logs once parity is confirmed.

## Open Questions

- Do we need optional file-based log rotation policies in this change or a follow-up?
