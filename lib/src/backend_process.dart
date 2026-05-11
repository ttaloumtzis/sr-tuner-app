import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'app_config.dart';
import 'backend_client.dart';

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
  Process? _process;
  final List<String> _log = [];

  String get statusLog => _log.take(20).join('\n');

  Future<void> ensureStarted() async {
    if (await _isHealthy()) {
      return;
    }
    if (_mode == BackendLauncherMode.remote) {
      throw ApiException(
        'Remote backend mode is not configured yet.',
        code: 'remote_backend_unavailable',
      );
    }
    if (_process == null) {
      final root = _repoRoot();
      final command = _command(root);
      _process = await Process.start(
        command.executable,
        command.arguments,
        workingDirectory: root.path,
        environment: {'SR_TUNER_SESSION_TOKEN': _sessionToken},
      );
      _process!.stdout.transform(SystemEncoding().decoder).listen(_record);
      _process!.stderr.transform(SystemEncoding().decoder).listen(_record);
    }

    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (DateTime.now().isBefore(deadline)) {
      if (await _isHealthy()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
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
        const Duration(milliseconds: 600),
      );
      return response['status'] == 'ok';
    } catch (_) {
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
        _log.add(line.trim());
      }
    }
  }

  Future<void> dispose() async {
    _process?.kill();
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
