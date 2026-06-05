export 'report_saver_stub.dart'
    show ReportSaver, ReportSaveResult, ReportSaveStatus;

import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../core/report/report_bundle.dart';
import 'report_saver_stub.dart';

ReportSaver createReportSaver() {
  if (Platform.isAndroid || Platform.isIOS) {
    return const UnsupportedReportSaver();
  }
  return const DesktopReportSaver();
}

class DesktopReportSaver implements ReportSaver {
  const DesktopReportSaver();

  @override
  Future<ReportSaveResult> save(
    ReportBundle bundle, {
    String? initialDirectory,
  }) async {
    final String? directoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose a folder to export the report',
      initialDirectory: initialDirectory,
    );
    if (directoryPath == null) {
      return const ReportSaveResult.cancelled();
    }

    final List<String> written = [];
    if (bundle.hasHtml) {
      await File(_join(directoryPath, ReportFileNames.html))
          .writeAsString(bundle.htmlReport);
      written.add(ReportFileNames.html);
    }
    for (final MapEntry<String, String> entry in bundle.csvFiles.entries) {
      await File(_join(directoryPath, entry.key)).writeAsString(entry.value);
      written.add(entry.key);
    }
    for (final MapEntry<String, List<int>> entry
        in bundle.binaryFiles.entries) {
      await File(_join(directoryPath, entry.key)).writeAsBytes(entry.value);
      written.add(entry.key);
    }

    return ReportSaveResult(
      status: ReportSaveStatus.savedToDirectory,
      fileNames: written,
      location: directoryPath,
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
