from __future__ import annotations


class CauseCodes:
    STARTUP_PROCESS_EXIT = "startup_process_exit"
    STARTUP_HEALTH_TIMEOUT = "startup_health_timeout"
    STARTUP_HEALTH_REFUSED = "startup_health_refused"
    STARTUP_UNEXPECTED_EXIT = "startup_unexpected_exit"
    STARTUP_DEPS_MISSING = "startup_deps_missing"
    STARTUP_CONFIG_INVALID = "startup_config_invalid"

    TRANSPORT_CONNECTION_REFUSED = "transport_connection_refused"
    TRANSPORT_TIMEOUT = "transport_timeout"
    TRANSPORT_DNS_FAILURE = "transport_dns_failure"
    TRANSPORT_TLS_ERROR = "transport_tls_error"
    TRANSPORT_RETRY_EXHAUSTED = "transport_retry_exhausted"

    POLL_TIMEOUT = "poll_timeout"
    POLL_TRANSPORT_FAILURE = "poll_transport_failure"
    POLL_SERVER_ERROR = "poll_server_error"
    POLL_RECOVERY = "poll_recovery"

    TELEMETRY_CUDA_UNAVAILABLE = "telemetry_cuda_unavailable"
    TELEMETRY_ROCM_UNAVAILABLE = "telemetry_rocm_unavailable"
    TELEMETRY_VENDOR_TOOLING_MISSING = "telemetry_vendor_tooling_missing"
    TELEMETRY_TEMPERATURE_UNSUPPORTED = "telemetry_temperature_unsupported"
    TELEMETRY_UTILIZATION_UNSUPPORTED = "telemetry_utilization_unsupported"
    TELEMETRY_SPEED_UNSUPPORTED = "telemetry_speed_unsupported"
    TELEMETRY_STREAM_INTERRUPTED = "telemetry_stream_interrupted"

    REDACTION_SENSITIVE_KEY = "redaction_sensitive_key"
    REDACTION_BINARY_PAYLOAD = "redaction_binary_payload"
    REDACTION_ENV_SECRET = "redaction_env_secret"

    VALIDATION_MISSING_FIELD = "validation_missing_field"
    VALIDATION_INVALID_VALUE = "validation_invalid_value"
    VALIDATION_TYPE_ERROR = "validation_type_error"

    WORKFLOW_PROJECT_NOT_FOUND = "workflow_project_not_found"
    WORKFLOW_RUN_FAILED = "workflow_run_failed"
    WORKFLOW_INFERENCE_FAILED = "workflow_inference_failed"
    WORKFLOW_CHECKPOINT_FAILED = "workflow_checkpoint_failed"
    WORKFLOW_DATASET_FAILED = "workflow_dataset_failed"

    CORRELATION_MISSING = "correlation_missing"
    CORRELATION_FALLBACK_GENERATED = "correlation_fallback_generated"
