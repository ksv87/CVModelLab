export 'platform_file_picker_stub.dart' show PlatformFilePicker;
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'file_pick_result.dart';
import 'image_file_index.dart';
import 'image_source.dart';
import 'platform_file_picker_stub.dart';

PlatformFilePicker createPlatformFilePicker() {
  return const DesktopPlatformFilePicker();
}

class DesktopPlatformFilePicker implements PlatformFilePicker {
  const DesktopPlatformFilePicker();

  @override
  Future<PickedDataFile?> pickAnnotationsJson() {
    return _pickJsonFile('Pick annotations.json');
  }

  @override
  Future<PickedDataFile?> pickPredictionsJson() {
    return _pickJsonFile('Pick predictions.json');
  }

  @override
  Future<ImageSource?> pickImages() async {
    final String? directoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pick images directory',
    );
    if (directoryPath == null) {
      return null;
    }
    return DesktopDirectoryImageSource.scan(directoryPath);
  }

  Future<PickedDataFile?> _pickJsonFile(String dialogTitle) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final PlatformFile picked = result.files.single;
    final String? path = picked.path;
    if (path == null) {
      return null;
    }
    return PickedDataFile(
      name: picked.name,
      path: path,
      bytes: await File(path).readAsBytes(),
    );
  }
}

class DesktopDirectoryImageSource implements ImageSource {
  DesktopDirectoryImageSource._({
    required this.rootPath,
    required ImageFileIndex<String> index,
    Iterable<String> expectedFileNames = const <String>[],
  })  : _index = index,
        _expectedFileNames = List<String>.unmodifiable(expectedFileNames);

  final String rootPath;
  final ImageFileIndex<String> _index;
  final List<String> _expectedFileNames;

  static Future<DesktopDirectoryImageSource> scan(String rootPath) async {
    final Directory root = Directory(rootPath);
    final List<ImageFileEntry<String>> entries = [];
    if (await root.exists()) {
      await for (final FileSystemEntity entity in root.list(recursive: true)) {
        if (entity is! File || !_isImagePath(entity.path)) {
          continue;
        }
        entries.add(
          ImageFileEntry<String>(
            relativePath: _relativePath(root.path, entity.path),
            value: entity.path,
          ),
        );
      }
    }
    return DesktopDirectoryImageSource._(
      rootPath: rootPath,
      index: ImageFileIndex<String>(entries),
    );
  }

  @override
  ImageSource bindExpectedImages(Iterable<String> cocoFileNames) {
    return DesktopDirectoryImageSource._(
      rootPath: rootPath,
      index: _index,
      expectedFileNames: cocoFileNames,
    );
  }

  @override
  Future<bool> exists(String cocoFileName) async {
    return _index.exists(cocoFileName);
  }

  @override
  List<String> missingImages() {
    return _index.missingImages(_expectedFileNames);
  }

  @override
  Future<Uint8List?> readImageBytes(String cocoFileName) async {
    final String? path = _index.resolve(cocoFileName);
    if (path == null) {
      return null;
    }
    final File file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }
}

bool _isImagePath(String path) {
  final String lower = path.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.bmp') ||
      lower.endsWith('.gif');
}

String _relativePath(String rootPath, String filePath) {
  final String root = normalizeImagePath(rootPath);
  final String file = normalizeImagePath(filePath);
  if (file == root) {
    return basename(file);
  }
  if (file.startsWith('$root/')) {
    return file.substring(root.length + 1);
  }
  return basename(file);
}
