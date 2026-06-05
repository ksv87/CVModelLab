export 'project_file_io_stub.dart' show ProjectFileIo;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'file_pick_result.dart';
import 'image_source.dart';
import 'platform_file_picker_desktop.dart' show DesktopDirectoryImageSource;
import 'project_file_io_stub.dart';

ProjectFileIo createProjectFileIo() {
  if (Platform.isAndroid || Platform.isIOS) {
    return const UnsupportedProjectFileIo();
  }
  return const DesktopProjectFileIo();
}

class DesktopProjectFileIo implements ProjectFileIo {
  const DesktopProjectFileIo();

  @override
  Future<PickedDataFile?> openProject({String? initialDirectory}) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Open CV Model Lab project',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: false,
      initialDirectory: initialDirectory,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final PlatformFile picked = result.files.single;
    final String? path = picked.path;
    if (path == null) {
      return null;
    }
    final Uint8List bytes = await File(path).readAsBytes();
    return PickedDataFile(name: picked.name, path: path, bytes: bytes);
  }

  @override
  Future<String?> saveProjectAs(
    String jsonContent,
    String suggestedName, {
    String? initialDirectory,
  }) async {
    String? path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CV Model Lab project',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      initialDirectory: initialDirectory,
    );
    if (path == null) {
      return null;
    }
    if (!path.toLowerCase().endsWith('.json')) {
      path = '$path.json';
    }
    await File(path).writeAsString(jsonContent);
    return path;
  }

  @override
  Future<bool> saveProjectToPath(String path, String jsonContent) async {
    try {
      await File(path).writeAsString(jsonContent);
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<PickedDataFile?> readFileAtPath(String path) async {
    final File file = File(path);
    if (!await file.exists()) {
      return null;
    }
    final Uint8List bytes = await file.readAsBytes();
    return PickedDataFile(
      name: file.uri.pathSegments.last,
      path: path,
      bytes: bytes,
    );
  }

  @override
  Future<ImageSource?> openImageSourceAtPath(String path) async {
    final Directory dir = Directory(path);
    if (!await dir.exists()) {
      return null;
    }
    return DesktopDirectoryImageSource.scan(path);
  }
}
