import 'dart:async';

import 'diagnostic_logger.dart';
import 'logging_schema.dart';

class DebugSession {
  DebugSession({
    this.duration = const Duration(minutes: 15),
    this.minimumLevel = LogLevel.debug,
  });

  final Duration duration;
  final LogLevel minimumLevel;

  bool get isActive => _timer != null;

  Timer? _timer;

  void activate() {
    if (_timer != null) return;
    final log = createComponentLogger(Components.frontend);
    log.info(EventNames.workflowAction, 'Debug session activated.', context: {
      'duration_seconds': duration.inSeconds,
      'minimum_level': minimumLevel.value,
    });
    _timer = Timer(duration, deactivate);
  }

  void deactivate() {
    _timer?.cancel();
    _timer = null;
    final log = createComponentLogger(Components.frontend);
    log.info(EventNames.workflowAction, 'Debug session deactivated.');
  }

  LogLevel effectiveMinimum([LogLevel fallback = LogLevel.info]) {
    return isActive ? minimumLevel : fallback;
  }
}
