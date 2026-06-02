export 'annotated_image_saver_stub.dart'
    show
        AnnotatedImageSaver,
        AnnotatedImageSaveResult,
        AnnotatedImageSaveStatus;

import 'dart:typed_data';

import 'package:archive/archive.dart';
// ignore: deprecated_member_use
import 'dart:html' as html;

import 'annotated_image_saver_stub.dart';

AnnotatedImageSaver createAnnotatedImageSaver() =>
    const WebAnnotatedImageSaver();

class WebAnnotatedImageSaver implements AnnotatedImageSaver {
  const WebAnnotatedImageSaver();

  @override
  Future<AnnotatedImageSaveResult> save(Map<String, Uint8List> pngFiles) async {
    final Archive archive = Archive();
    for (final MapEntry<String, Uint8List> entry in pngFiles.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    final List<int> zipBytes = ZipEncoder().encode(archive);
    _triggerDownload(
      'cv_model_lab_annotated_images.zip',
      Uint8List.fromList(zipBytes),
      'application/zip',
    );
    return AnnotatedImageSaveResult(
      status: AnnotatedImageSaveStatus.downloadStarted,
      location: 'cv_model_lab_annotated_images.zip',
      fileNames: pngFiles.keys.toList(),
    );
  }

  void _triggerDownload(String fileName, Uint8List bytes, String mimeType) {
    final html.Blob blob = html.Blob(<Uint8List>[bytes], mimeType);
    final String url = html.Url.createObjectUrlFromBlob(blob);
    final html.AnchorElement anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}
