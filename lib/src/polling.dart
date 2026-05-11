import 'dart:async';

class BoundedPoller<T> {
  BoundedPoller({
    required this.fetch,
    required this.onData,
    this.interval = const Duration(seconds: 1),
    this.onError,
  });

  final Future<T> Function() fetch;
  final void Function(T value) onData;
  final void Function(Object error)? onError;
  final Duration interval;

  Timer? _timer;
  bool _running = false;

  void start() {
    _timer ??= Timer.periodic(interval, (_) => _tick());
    _tick();
  }

  Future<void> _tick() async {
    if (_running) {
      return;
    }
    _running = true;
    try {
      onData(await fetch());
    } catch (error) {
      onError?.call(error);
    } finally {
      _running = false;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
