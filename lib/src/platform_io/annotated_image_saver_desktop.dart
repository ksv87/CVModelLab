export 'annotated_image_saver_stub.dart'
    show
        AnnotatedImageSaver,
        AnnotatedImageSaveResult,
        AnnotatedImageSaveStatus;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'annotated_image_saver_stub.dart';

AnnotatedImageSaver createAnnotatedImageSaver() {
  if (Platform.isAndroid || Platform.isIOS) {
    return const StubAnnotatedImageSaver();
  }
  return const DesktopAnnotatedImageSaver();
}

class DesktopAnnotatedImageSaver implements AnnotatedImageSaver {
  const DesktopAnnotatedImageSaver();

  @override
  Future<AnnotatedImageSaveResult> save(Map<String, Uint8List> pngFiles) async {
    final String? directoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose a folder for annotated images',
    );
    if (directoryPath == null) {
      return const AnnotatedImageSaveResult.cancelled();
    }

    final Directory outputDir = Directory(_join(directoryPath, 'annotated'));
    await outputDir.create(recursive: true);

    final List<String> written = [];
    for (final MapEntry<String, Uint8List> entry in pngFiles.entries) {
      final File file = File(_join(outputDir.path, entry.key));
      await file.writeAsBytes(entry.value, flush: true);
      written.add(entry.key);
    }

    return AnnotatedImageSaveResult(
      status: AnnotatedImageSaveStatus.savedToDirectory,
      location: outputDir.path,
      fileNames: written,
    );
  }

  String _join(String directory, String fileName) {
    final String separator = Platform.pathSeparator;
    if (directory.endsWith(separator)) {
      return '$directory$fileName';
    }
    return '$directory$separator$fileName';
  }
}
