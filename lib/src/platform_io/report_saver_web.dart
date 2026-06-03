export 'report_saver_stub.dart'
    show ReportSaver, ReportSaveResult, ReportSaveStatus;

import 'dart:convert';
// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../core/report/report_bundle.dart';
import 'report_saver_stub.dart';

ReportSaver createReportSaver() => const WebReportSaver();

const String _zipFileName = 'cv_model_lab_report.zip';

class WebReportSaver implements ReportSaver {
  const WebReportSaver();

  @override
  Future<ReportSaveResult> save(
    ReportBundle bundle, {
    String? initialDirectory,
  }) async {
    final Archive archive = Archive();
    void addFile(String name, String content) {
      final List<int> bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    if (bundle.hasHtml) {
      addFile(ReportFileNames.html, bundle.htmlReport);
    }
    bundle.csvFiles.forEach(addFile);
    for (final MapEntry<String, List<int>> entry
        in bundle.binaryFiles.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }

    final List<int> zipBytes = ZipEncoder().encode(archive);

    _triggerDownload(
      _zipFileName,
      Uint8List.fromList(zipBytes),
      'application/zip',
    );

    return ReportSaveResult(
      status: ReportSaveStatus.downloadStarted,
      fileNames: bundle.fileNames,
      location: _zipFileName,
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
