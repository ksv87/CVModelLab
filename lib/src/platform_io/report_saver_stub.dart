import '../core/report/report_bundle.dart';

enum ReportSaveStatus {
  savedToDirectory,
  downloadStarted,
  cancelled,
}

class ReportSaveResult {
  const ReportSaveResult({
    required this.status,
    this.fileNames = const <String>[],
    this.location,
  });

  const ReportSaveResult.cancelled()
      : status = ReportSaveStatus.cancelled,
        fileNames = const <String>[],
        location = null;

  final ReportSaveStatus status;
  final List<String> fileNames;

  /// Directory path on desktop, file name on web, null when cancelled.
  final String? location;
}

abstract interface class ReportSaver {
  Future<ReportSaveResult> save(
    ReportBundle bundle, {
    String? initialDirectory,
  });
}

ReportSaver createReportSaver() => const UnsupportedReportSaver();

class UnsupportedReportSaver implements ReportSaver {
  const UnsupportedReportSaver();

  @override
  Future<ReportSaveResult> save(
    ReportBundle bundle, {
    String? initialDirectory,
  }) {
    throw UnsupportedError('Report saving is not available on this platform.');
  }
}
