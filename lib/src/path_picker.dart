import 'package:file_selector/file_selector.dart';

class PathPicker {
  const PathPicker();

  Future<String?> pickFolder({String? confirmButtonText}) async {
    return getDirectoryPath(confirmButtonText: confirmButtonText);
  }

  Future<String?> pickFile({
    List<XTypeGroup> acceptedTypeGroups = const [],
    String? confirmButtonText,
  }) async {
    final file = await openFile(
      acceptedTypeGroups: acceptedTypeGroups,
      confirmButtonText: confirmButtonText,
    );
    return file?.path;
  }
}
