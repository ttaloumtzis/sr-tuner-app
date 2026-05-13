enum LogLevel {
  trace('trace'),
  debug('debug'),
  info('info'),
  warn('warn'),
  error('error'),
  fatal('fatal');

  const LogLevel(this.value);
  final String value;

  static const minimum = LogLevel.info;
  static const _order = [LogLevel.trace, LogLevel.debug, LogLevel.info, LogLevel.warn, LogLevel.error, LogLevel.fatal];

  bool isEnabled([LogLevel? minimumLevel]) {
    final min = minimumLevel ?? minimum;
    return _order.indexOf(this) >= _order.indexOf(min);
  }
}

const String _eventPrefix = 'sr.';

String eventName(String category, String action) => '$_eventPrefix$category.$action';

class EventNames {
  static const backendStart = 'sr.backend.start';
  static const backendHealthCheck = 'sr.backend.health_check';
  static const backendStartupFailure = 'sr.backend.startup_failure';
  static const backendShutdown = 'sr.backend.shutdown';

  static const requestIngress = 'sr.request.ingress';
  static const requestComplete = 'sr.request.complete';
  static const requestValidationFailure = 'sr.request.validation_failure';
  static const requestServiceError = 'sr.request.service_error';

  static const jobQueued = 'sr.job.queued';
  static const jobRunning = 'sr.job.running';
  static const jobCanceling = 'sr.job.canceling';
  static const jobCanceled = 'sr.job.canceled';
  static const jobCompleted = 'sr.job.completed';
  static const jobFailed = 'sr.job.failed';

  static const metricsIngest = 'sr.metrics.ingest';
  static const metricsPollStart = 'sr.metrics.poll_start';
  static const metricsPollComplete = 'sr.metrics.poll_complete';
  static const metricsPollInterrupted = 'sr.metrics.poll_interrupted';
  static const metricsRenderLatency = 'sr.metrics.render_latency';

  static const inferenceSubmit = 'sr.inference.submit';
  static const inferenceStart = 'sr.inference.start';
  static const inferenceComplete = 'sr.inference.complete';
  static const inferenceFailed = 'sr.inference.failed';
  static const inferenceBatchSummary = 'sr.inference.batch_summary';

  static const telemetryUpdate = 'sr.telemetry.update';
  static const telemetryUnavailable = 'sr.telemetry.unavailable';

  static const correlationFallback = 'sr.correlation.fallback_generated';

  static const redactionApplied = 'sr.redaction.applied';

  static const assetLoadStart = 'sr.asset.load_start';
  static const assetLoadComplete = 'sr.asset.load_complete';
  static const assetLoadFailed = 'sr.asset.load_failed';

  static const workflowAction = 'sr.workflow.action';
  static const workflowError = 'sr.workflow.error';

  static const parentWatchdog = 'sr.watchdog.parent_process_check';
}

class Components {
  static const frontend = 'frontend';
  static const backend = 'backend';
  static const api = 'api';
  static const job = 'job';
  static const inference = 'inference';
  static const metrics = 'metrics';
  static const telemetry = 'telemetry';
  static const watchdog = 'watchdog';
  static const startup = 'startup';
}

const String redactedPlaceholder = '[REDACTED]';

const Set<String> sensitiveKeys = {
  'token',
  'secret',
  'password',
  'credential',
  'authorization',
  'x-sr-tuner-token',
  'session_token',
  'private_key',
};

bool shouldRedact(String key) {
  final lower = key.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  return sensitiveKeys.any((s) => lower.contains(s));
}

class LogEvent {
  LogEvent({
    DateTime? timestamp,
    this.level = LogLevel.info,
    this.component = '',
    this.event = '',
    this.message = '',
    this.sessionId = '',
    this.requestId = '',
    this.correlationId = '',
    Map<String, dynamic>? context,
  })  : timestamp = (timestamp ?? DateTime.now()).toIso8601String(),
        context = context ?? {};

  final String timestamp;
  final LogLevel level;
  final String component;
  final String event;
  final String message;
  final String sessionId;
  final String requestId;
  final String correlationId;
  final Map<String, dynamic> context;

  Map<String, dynamic> toMap({bool redact = true}) {
    final ctx = redact ? _redactMap(context) : Map<String, dynamic>.from(context);
    return {
      'timestamp': timestamp,
      'level': level.value,
      'component': component,
      'event': event,
      'message': message,
      'session_id': sessionId,
      'request_id': requestId,
      'correlation_id': correlationId,
      'context': ctx,
    };
  }
}

Map<String, dynamic> _redactMap(Map<String, dynamic> map, [String parentKey = '']) {
  final result = <String, dynamic>{};
  for (final entry in map.entries) {
    final combinedKey = parentKey.isEmpty ? entry.key : '$parentKey.${entry.key}';
    if (shouldRedact(combinedKey)) {
      result[entry.key] = redactedPlaceholder;
    } else if (entry.value is Map<String, dynamic>) {
      result[entry.key] = _redactMap(entry.value as Map<String, dynamic>, combinedKey);
    } else if (entry.value is List<int> || (entry.value is String && _isBinaryLike(entry.value as String))) {
      result[entry.key] = _redactBinary(entry.value);
    } else {
      result[entry.key] = entry.value;
    }
  }
  return result;
}

bool _isBinaryLike(String value) {
  if (value.length < 1024) return false;
  var controlCount = 0;
  for (var i = 0; i < value.length; i++) {
    final c = value.codeUnitAt(i);
    if (c < 32 && c != 10 && c != 13 && c != 9) controlCount++;
  }
  return controlCount > value.length * 0.1;
}

String _redactBinary(dynamic value) {
  if (value is List<int>) return '[BINARY ${value.length} bytes]';
  if (value is String) return '[TEXT ${value.length} chars]';
  return redactedPlaceholder;
}
