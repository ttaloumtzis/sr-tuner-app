class CauseCodes {
  static const startupProcessExit = 'startup_process_exit';
  static const startupHealthTimeout = 'startup_health_timeout';
  static const startupHealthRefused = 'startup_health_refused';
  static const startupUnexpectedExit = 'startup_unexpected_exit';
  static const startupDepsMissing = 'startup_deps_missing';
  static const startupConfigInvalid = 'startup_config_invalid';

  static const transportConnectionRefused = 'transport_connection_refused';
  static const transportTimeout = 'transport_timeout';
  static const transportDnsFailure = 'transport_dns_failure';
  static const transportTlsError = 'transport_tls_error';
  static const transportRetryExhausted = 'transport_retry_exhausted';

  static const pollTimeout = 'poll_timeout';
  static const pollTransportFailure = 'poll_transport_failure';
  static const pollServerError = 'poll_server_error';
  static const pollRecovery = 'poll_recovery';

  static const telemetryCudaUnavailable = 'telemetry_cuda_unavailable';
  static const telemetryRocmUnavailable = 'telemetry_rocm_unavailable';
  static const telemetryVendorToolingMissing = 'telemetry_vendor_tooling_missing';
  static const telemetryTemperatureUnsupported = 'telemetry_temperature_unsupported';
  static const telemetryUtilizationUnsupported = 'telemetry_utilization_unsupported';
  static const telemetrySpeedUnsupported = 'telemetry_speed_unsupported';
  static const telemetryStreamInterrupted = 'telemetry_stream_interrupted';

  static const redactionSensitiveKey = 'redaction_sensitive_key';
  static const redactionBinaryPayload = 'redaction_binary_payload';
  static const redactionEnvSecret = 'redaction_env_secret';

  static const validationMissingField = 'validation_missing_field';
  static const validationInvalidValue = 'validation_invalid_value';
  static const validationTypeError = 'validation_type_error';

  static const workflowProjectNotFound = 'workflow_project_not_found';
  static const workflowRunFailed = 'workflow_run_failed';
  static const workflowInferenceFailed = 'workflow_inference_failed';
  static const workflowCheckpointFailed = 'workflow_checkpoint_failed';
  static const workflowDatasetFailed = 'workflow_dataset_failed';

  static const correlationMissing = 'correlation_missing';
  static const correlationFallbackGenerated = 'correlation_fallback_generated';
}
