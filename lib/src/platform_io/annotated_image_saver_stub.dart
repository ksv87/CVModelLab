import 'dart:typed_data';

enum AnnotatedImageSaveStatus {
  cancelled,
  downloadStarted,
  savedToDirectory,
}

class AnnotatedImageSaveResult {
  const AnnotatedImageSaveResult({
    required this.status,
    this.location,
    this.fileNames = const <String>[],
  });

  const AnnotatedImageSaveResult.cancelled()
      : status = AnnotatedImageSaveStatus.cancelled,
        location = null,
        fileNames = const <String>[];

  final AnnotatedImageSaveStatus status;
  final String? location;
  final List<String> fileNames;
}

abstract interface class AnnotatedImageSaver {
  Future<AnnotatedImageSaveResult> save(Map<String, Uint8List> pngFiles);
}

AnnotatedImageSaver createAnnotatedImageSaver() =>
    const StubAnnotatedImageSaver();

class StubAnnotatedImageSaver implements AnnotatedImageSaver {
  const StubAnnotatedImageSaver();

  @override
  Future<AnnotatedImageSaveResult> save(Map<String, Uint8List> pngFiles) async {
    return const AnnotatedImageSaveResult.cancelled();
  }
}
