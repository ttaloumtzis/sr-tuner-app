# Debug & Troubleshooting Guide

## Enabling Debug Logging

The application supports scoped debug sessions that increase log verbosity for a
configurable duration without requiring an application restart.

### Starting a Debug Session

In the frontend, create a `DebugSession` with the desired duration and log level:

```dart
final session = DebugSession(
  duration: Duration(minutes: 15),
  minimumLevel: LogLevel.debug,
);
session.activate();
```

While active, `DiagnosticLogger` instances operating within the session scope
will emit `debug` and `trace` events in addition to the normal `info`, `warn`,
and `error` events.

### Log Output Locations

| Environment | Log target | How to view |
|---|---|---|
| Dev (Flutter run) | stdout/stderr | Terminal running `flutter run` or `dev_frontend.sh` |
| Dev (backend) | stderr (structured JSON) | Terminal running `uvicorn` or `dev_backend.sh` |
| Packaged desktop | stdout/stderr | Captured by launcher or visible in terminal |
| CI | stdout/stderr | CI job log output |

### Filtering Logs by Correlation ID

Every user-triggered action (project open, inference submit, etc.) generates a
correlation ID that propagates through API requests to backend logs. To filter
for a single user action:

1. Identify the correlation ID from the frontend log output
2. Search both frontend and backend logs for that ID
3. Reconstruct the full request lifecycle from the matched events

### Collecting Logs for a Specific Issue

1. Activate a debug session before reproducing the issue
2. Reproduce the issue
3. Collect log output (from terminal or launcher output)
4. Filter by workflow action event names or correlation IDs
5. Check for diagnostic cause codes (see `cause_codes.dart` / `cause_codes.py`)

### Diagnostic Cause Codes Reference

| Category | Code | Meaning |
|---|---|---|
| Startup | `startup_health_timeout` | Backend did not become healthy in time |
| Startup | `startup_health_refused` | Backend health endpoint refused connection |
| Transport | `transport_timeout` | Frontend request timed out |
| Transport | `transport_connection_refused` | Backend not reachable |
| Poll | `poll_timeout` | Metrics poll timed out |
| Poll | `poll_server_error` | Backend returned error during poll |
| Telemetry | `telemetry_cuda_unavailable` | CUDA device not available |
| Telemetry | `telemetry_rocm_unavailable` | ROCm device not available |
| Telemetry | `telemetry_temperature_unsupported` | Temperature not available for device |
| Telemetry | `telemetry_utilization_unsupported` | Utilization not available for device |
| Redaction | `redaction_sensitive_key` | A sensitive-key field was redacted |
| Validation | `validation_missing_field` | Required field missing from request |
| Workflow | `workflow_run_failed` | Training run failed |
| Workflow | `workflow_inference_failed` | Inference execution failed |

### Default Log Levels

- Frontend: `info` minimum (production-safe)
- Backend: `info` minimum (production-safe)
- Debug session: automatically expires after configured duration

### Verifying Redaction

To verify that sensitive fields are not leaked in logs, search log output for
the `[REDACTED]` placeholder. If you see raw token or secret values in logs,
report this as a bug.
