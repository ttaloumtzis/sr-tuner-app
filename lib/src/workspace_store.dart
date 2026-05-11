import 'dart:convert';
import 'dart:io';

class WorkspaceStore {
  File get _file {
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    final dir = Directory('$home/.config/sr-tuner');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File('${dir.path}/workspace.json');
  }

  Future<String?> readLastProjectPath() async {
    final file = _file;
    if (!await file.exists()) {
      return null;
    }
    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return decoded['last_project_path'] as String?;
  }

  Future<void> saveLastProjectPath(String path) async {
    await _file.writeAsString(
      jsonEncode({'last_project_path': path}),
      flush: true,
    );
  }
}
