import 'dart:async';

import 'cause_codes.dart';
import 'diagnostic_logger.dart';
import 'logging_schema.dart';

class BoundedPoller<T> {
  BoundedPoller({
    required this.fetch,
    required this.onData,
    this.interval = const Duration(seconds: 1),
    this.onError,
    this.pollLabel = '',
  });

  final Future<T> Function() fetch;
  final void Function(T value) onData;
  final void Function(Object error)? onError;
  final Duration interval;
  final String pollLabel;

  final _log = DiagnosticLogger(component: Components.metrics, minimumLevel: LogLevel.info);
  Timer? _timer;
  bool _running = false;
  Stopwatch? _lastElapsed;

  void start() {
    _log.info(EventNames.metricsPollStart, 'Polling started.', context: {
      'label': pollLabel,
      'interval_ms': interval.inMilliseconds,
    });
    _timer ??= Timer.periodic(interval, (_) => _tick());
    _tick();
  }

  Future<void> _tick() async {
    if (_running) {
      return;
    }
    _running = true;
    final stopwatch = Stopwatch()..start();
    try {
      final data = await fetch();
      _lastElapsed = stopwatch;
      onData(data);
      _log.info(EventNames.metricsPollComplete, 'Poll completed.', context: {
        'label': pollLabel,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      });
    } catch (error) {
      _log.warn(EventNames.metricsPollInterrupted, 'Poll interrupted.', context: {
        'label': pollLabel,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
        'cause_code': CauseCodes.pollTimeout,
        'error': error.toString(),
      });
      onError?.call(error);
    } finally {
      _running = false;
    }
  }

  void stop() {
    _log.info(EventNames.metricsPollComplete, 'Polling stopped.', context: {
      'label': pollLabel,
      'last_elapsed_ms': _lastElapsed?.elapsedMilliseconds,
    });
    _timer?.cancel();
    _timer = null;
  }
}
