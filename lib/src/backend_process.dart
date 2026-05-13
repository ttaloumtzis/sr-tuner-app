import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'app_config.dart';
import 'backend_client.dart';
import 'cause_codes.dart';
import 'diagnostic_logger.dart';
import 'logging_schema.dart';

enum BackendLauncherMode { dev, packaged, remote }

class BackendProcess {
  BackendProcess(
    this._client, {
    BackendLauncherMode mode = BackendLauncherMode.dev,
  }) : _mode = mode {
    _client.sessionToken = _sessionToken;
  }

  final BackendClient _client;
  final BackendLauncherMode _mode;
  final String _sessionToken = _generateSessionToken();
  final _log = DiagnosticLogger(component: Components.startup, minimumLevel: LogLevel.info);
  Process? _process;
  Future<void>? _disposeFuture;
  final List<String> _processLog = [];
  int? _processExitCode;
  Future<void>? _streamsClosed;

  String get statusLog => _processLog.length > 20
      ? _processLog.sublist(_processLog.length - 20).join('\n')
      : _processLog.join('\n');

  Future<void> ensureStarted() async {
    if (await _isHealthy()) {
      return;
    }
    if (_mode == BackendLauncherMode.remote) {
      _log.error(EventNames.backendStartupFailure, 'Remote backend mode not configured.', context: {
        'cause_code': CauseCodes.startupConfigInvalid,
      });
      throw ApiException(
        'Remote backend mode is not configured yet.',
        code: 'remote_backend_unavailable',
      );
    }
    if (_process == null) {
      final root = _repoRoot();
      final command = _command(root);
      _log.info(EventNames.backendStart, 'Starting backend process.', context: {
        'executable': command.executable,
        'arguments': command.arguments,
        'working_directory': root.path,
        'mode': _mode.name,
      });

      // Free port 8765 if a stale backend from a previous session is still running.
      try {
        final result = await Process.run('lsof', ['-ti', ':8765']);
        if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
          final pids = result.stdout.toString().trim().split('\n');
          for (final pid in pids) {
            await Process.run('kill', ['-9', pid.trim()]);
          }
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      } catch (_) {
        // lsof may not be available; proceed anyway.
      }

      _process = await Process.start(
        command.executable,
        command.arguments,
        workingDirectory: root.path,
        environment: {
          'SR_TUNER_SESSION_TOKEN': _sessionToken,
          'SR_TUNER_PARENT_PID': pid.toString(),
        },
      );
      final proc = _process!;
      _streamsClosed = Future.wait([
        proc.stdout.transform(SystemEncoding().decoder).listen(_record).asFuture<void>(),
        proc.stderr.transform(SystemEncoding().decoder).listen(_record).asFuture<void>(),
      ]);
      proc.exitCode.then((code) async {
        // Wait for stdout/stderr streams to finish delivering data.
        // Without this, _processLog may be empty when the process exits fast.
        await _streamsClosed;
        _processExitCode = code;
        _log.error(EventNames.backendStartupFailure, 'Backend process exited prematurely.', context: {
          'cause_code': CauseCodes.startupUnexpectedExit,
          'exit_code': code,
        });
      });
    }

    var attemptCount = 0;
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      if (_processExitCode != null) {
        _log.error(EventNames.backendStartupFailure, 'Backend process exited before becoming healthy.', context: {
          'cause_code': CauseCodes.startupUnexpectedExit,
          'exit_code': _processExitCode,
          'attempts': attemptCount,
          'process_log_tail': _processLog.take(20).join('\n'),
        });
        final root = _repoRoot();
        final cmd = _command(root);
        throw ApiException(
          'Backend process exited with code $_processExitCode before becoming healthy.\n\n'
          '$statusLog\n\n'
          'To debug, run manually:\n'
          '  ${cmd.executable} ${cmd.arguments.join(' ')}',
          code: 'backend_process_exited',
        );
      }
      final healthy = await _isHealthy();
      attemptCount++;
      if (healthy) {
        _log.info(EventNames.backendStart, 'Backend became healthy after $attemptCount attempts.', context: {
          'attempts': attemptCount,
        });
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    _log.error(EventNames.backendStartupFailure, 'Backend did not become healthy within timeout.', context: {
      'cause_code': CauseCodes.startupHealthTimeout,
      'attempts': attemptCount,
      'process_log_tail': _processLog.take(20).join('\n'),
    });
    throw ApiException(
      'Backend did not become healthy on ${AppConfig.backendHost}:${AppConfig.backendPort}.\n$statusLog',
    );
  }

  _BackendCommand _command(Directory root) {
    return switch (_mode) {
      BackendLauncherMode.dev => _BackendCommand('uv', [
        'run',
        '--project',
        'backend',
        'uvicorn',
        'sr_tuner_api.main:app',
        '--app-dir',
        '${root.path}/backend/src',
        '--host',
        AppConfig.backendHost,
        '--port',
        AppConfig.backendPort.toString(),
      ]),
      BackendLauncherMode.packaged => _BackendCommand('python', [
        '-m',
        'uvicorn',
        'sr_tuner_api.main:app',
        '--host',
        AppConfig.backendHost,
        '--port',
        AppConfig.backendPort.toString(),
      ]),
      BackendLauncherMode.remote => throw StateError(
        'Remote mode has no local command.',
      ),
    };
  }

  Future<bool> _isHealthy() async {
    try {
      final response = await _client.health().timeout(
        const Duration(seconds: 2),
      );
      return response['status'] == 'ok';
    } catch (e) {
      return false;
    }
  }

  Directory _repoRoot() {
    var dir = Directory.current;
    for (var i = 0; i < 6; i += 1) {
      if (Directory('${dir.path}/backend/src').existsSync()) {
        return dir;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) {
        break;
      }
      dir = parent;
    }
    return Directory.current;
  }

  void _record(String value) {
    for (final line in value.trim().split('\n')) {
      if (line.trim().isNotEmpty) {
        _processLog.add(line.trim());
      }
    }
  }

  void killSync() {
    final process = _process;
    if (process == null) return;
    try {
      process.kill(ProcessSignal.sigterm);
    } catch (_) {}
    _process = null;
  }

  Future<void> dispose() async {
    final existing = _disposeFuture;
    if (existing != null) {
      return existing;
    }
    final future = _dispose();
    _disposeFuture = future;
    return future;
  }

  Future<void> _dispose() async {
    final process = _process;
    if (process == null) {
      return;
    }
    killSync();
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {
      process.kill(ProcessSignal.sigkill);
    }
    _process = null;
  }
}

class _BackendCommand {
  const _BackendCommand(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;
}

String _generateSessionToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
