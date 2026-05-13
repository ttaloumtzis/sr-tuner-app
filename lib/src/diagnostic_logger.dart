import 'dart:convert';

import 'logging_schema.dart';

typedef LogSink = void Function(Map<String, dynamic> event);

final List<LogSink> _sinks = [];

// Event sink strategy:
// - Default sink: structured JSON via print() (visible in dev and packaged runs)
// - Additional in-memory or file sinks registered via addLogSink() for
//   scoped debug sessions or UI troubleshooting panels
// - Retention bounds: each sink decides its own retention; no indefinite buffering
// - No file rotation in this phase (deferred to follow-up; see design.md Open Questions)
// - Packaged desktop runs: stderr/stdout from the Dart VM is visible in terminal logs

class DiagnosticLogger {
  DiagnosticLogger({
    required this.component,
    this.sessionId = '',
    this.requestId = '',
    this.correlationId = '',
    this.minimumLevel = LogLevel.info,
  });

  final String component;
  String sessionId;
  String requestId;
  String correlationId;
  LogLevel minimumLevel;

  DiagnosticLogger scoped({String? requestId, String? correlationId}) {
    return DiagnosticLogger(
      component: component,
      sessionId: sessionId,
      requestId: requestId ?? this.requestId,
      correlationId: correlationId ?? this.correlationId,
      minimumLevel: minimumLevel,
    );
  }

  DiagnosticLogger withCorrelation(String correlationId) {
    return DiagnosticLogger(
      component: component,
      sessionId: sessionId,
      requestId: requestId,
      correlationId: correlationId,
      minimumLevel: minimumLevel,
    );
  }

  void trace(String event, String message, {Map<String, dynamic>? context}) {
    _log(LogLevel.trace, event, message, context: context);
  }

  void debug(String event, String message, {Map<String, dynamic>? context}) {
    _log(LogLevel.debug, event, message, context: context);
  }

  void info(String event, String message, {Map<String, dynamic>? context}) {
    _log(LogLevel.info, event, message, context: context);
  }

  void warn(String event, String message, {Map<String, dynamic>? context}) {
    _log(LogLevel.warn, event, message, context: context);
  }

  void error(String event, String message, {Map<String, dynamic>? context}) {
    _log(LogLevel.error, event, message, context: context);
  }

  void fatal(String event, String message, {Map<String, dynamic>? context}) {
    _log(LogLevel.fatal, event, message, context: context);
  }

  void _log(LogLevel level, String event, String message, {Map<String, dynamic>? context}) {
    if (!level.isEnabled(minimumLevel)) return;

    final logEvent = LogEvent(
      level: level,
      component: component,
      event: event,
      message: message,
      sessionId: sessionId,
      requestId: requestId,
      correlationId: correlationId,
      context: context,
    );

    final data = logEvent.toMap(redact: true);
    final line = const JsonEncoder.withIndent(null).convert(data);

    for (final sink in _sinks) {
      sink(data);
    }

    print(line);
  }
}

void addLogSink(LogSink sink) {
  _sinks.add(sink);
}

void removeLogSink(LogSink sink) {
  _sinks.remove(sink);
}

DiagnosticLogger createComponentLogger(String component, {String? sessionId}) {
  return DiagnosticLogger(component: component, sessionId: sessionId ?? '');
}
