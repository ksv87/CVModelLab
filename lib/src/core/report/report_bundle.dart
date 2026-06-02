import '../eval/confusion_details.dart';
import '../eval/eval_result_filter.dart';
import '../health/dataset_health_checker.dart';
import '../health/dataset_health_models.dart';
import '../model/coco_dataset.dart';
import '../model/eval_config.dart';
import '../model/eval_result.dart';
import '../model/eval_view_filter.dart';
import '../model/model_run.dart';
import '../worst_cases/worst_case_miner.dart';
import '../worst_cases/worst_case_models.dart';
import 'csv_exporter.dart';
import 'html_report_builder.dart';
import 'report_models.dart';

/// Canonical file names used when persisting a [ReportBundle].
class ReportFileNames {
  static const String html = 'cv_model_lab_report.html';
  static const String perClassMetrics = 'per_class_metrics.csv';
  static const String imageErrors = 'image_errors.csv';
  static const String matches = 'matches.csv';
  static const String smallObjectStats = 'small_object_stats.csv';
  static const String confusionMatrix = 'confusion_matrix.csv';
  static const String confusionPairs = 'confusion_pairs.csv';
  static const String datasetHealth = 'dataset_health_report.csv';
  static const String worstCases = 'worst_cases.csv';
}

/// An in-memory, platform-agnostic export result. Platform savers turn this
/// into files (desktop) or a download (web).
class ReportBundle {
  const ReportBundle({
    required this.projectName,
    required this.modelRunName,
    required this.generatedAt,
    required this.evalConfig,
    required this.htmlReport,
    required this.csvFiles,
  });

  final String projectName;
  final String modelRunName;
  final DateTime generatedAt;
  final EvalConfig evalConfig;

  /// The full HTML document, or empty if HTML was not requested.
  final String htmlReport;

  /// CSV files keyed by file name.
  final Map<String, String> csvFiles;

  bool get hasHtml => htmlReport.isNotEmpty;

  /// File names in the order they should be presented to the user.
  List<String> get fileNames => [
        if (hasHtml) ReportFileNames.html,
        ...csvFiles.keys,
      ];
}

/// Assembles a [ReportBundle] from already-computed evaluation data. This layer
/// only formats data; it never recomputes metrics.
class ReportBundleBuilder {
  const ReportBundleBuilder({
    this.htmlBuilder = const HtmlReportBuilder(),
    this.csvExporter = const CsvExporter(),
  });

  final HtmlReportBuilder htmlBuilder;
  final CsvExporter csvExporter;

  ReportBundle build({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required EvalConfig evalConfig,
    required EvalResult evalResult,
    required ReportComponents components,
    EvalViewFilter? activeFilter,
    FilteredEvalView? filteredView,
    ReportScope scope = ReportScope.fullEvaluation,
    String? projectName,
    String? modelRunName,
    Set<String> missingImageFileNames = const <String>{},
    DatasetImageAvailability? imageAvailability,
    DateTime? generatedAt,
  }) {
    final DateTime timestamp = generatedAt ?? DateTime.now();
    final List<int> imageIds = imageIdsForScope(
      dataset: dataset,
      scope: scope,
      filteredView: filteredView,
    );
    final List<ReportMatchRow> matchRows = buildMatchRows(
      dataset: dataset,
      modelRun: modelRun,
      matches: matchesForScope(
        evalResult: evalResult,
        scope: scope,
        filteredView: filteredView,
      ),
    );

    // Optional derived analytics, computed once and shared by HTML + CSV.
    final bool needsHealth = components.includeDatasetHealthCsv;
    final bool needsWorst = components.includeWorstCasesCsv;
    final bool needsConfusionPairs = components.includeConfusionPairsCsv;

    final DatasetHealthReport? healthReport = needsHealth
        ? const DatasetHealthChecker().check(
            dataset: dataset,
            predictions: modelRun.predictions,
            imageAvailability: imageAvailability ??
                DatasetImageAvailability(
                  missingFileNames: missingImageFileNames,
                  available: missingImageFileNames.isNotEmpty,
                ),
            generatedAt: timestamp,
          )
        : null;
    final WorstCasesResult? worstCases = needsWorst
        ? const WorstCaseMiner().mine(
            dataset: dataset,
            modelRun: modelRun,
            evalResult: evalResult,
            evalConfig: evalConfig,
          )
        : null;
    final ConfusionMatrixDetails? confusionDetails = needsConfusionPairs
        ? const ConfusionMatrixDetailBuilder().build(
            dataset: dataset,
            modelRun: modelRun,
            config: evalConfig,
          )
        : null;

    final String html = components.includeHtml
        ? htmlBuilder.build(
            dataset: dataset,
            modelRun: modelRun,
            evalConfig: evalConfig,
            evalResult: evalResult,
            activeFilter: activeFilter,
            filteredView: filteredView,
            scope: scope,
            projectName: projectName,
            modelRunName: modelRunName,
            generatedAt: timestamp,
            missingImageFileNames: missingImageFileNames,
            healthReport: healthReport,
            worstCases: worstCases,
            confusionDetails: confusionDetails,
          )
        : '';

    final Map<String, String> csvFiles = {};
    if (components.includePerClassMetricsCsv) {
      csvFiles[ReportFileNames.perClassMetrics] =
          csvExporter.buildPerClassMetricsCsv(evalResult.perClassStats);
    }
    if (components.includeImageErrorsCsv) {
      csvFiles[ReportFileNames.imageErrors] = csvExporter.buildImageErrorsCsv(
        dataset: dataset,
        modelRun: modelRun,
        evalConfig: evalConfig,
        evalResult: evalResult,
        imageIds: imageIds,
        missingImageFileNames: missingImageFileNames,
      );
    }
    if (components.includeMatchesCsv) {
      csvFiles[ReportFileNames.matches] =
          csvExporter.buildMatchesCsv(matchRows);
    }
    if (components.includeSmallObjectStatsCsv &&
        evalResult.smallObjectStats.isNotEmpty) {
      csvFiles[ReportFileNames.smallObjectStats] =
          csvExporter.buildSmallObjectStatsCsv(
        dataset: dataset,
        smallObjectStats: evalResult.smallObjectStats,
      );
    }
    if (components.includeConfusionMatrixCsv &&
        evalResult.confusionMatrix.counts.isNotEmpty) {
      csvFiles[ReportFileNames.confusionMatrix] =
          csvExporter.buildConfusionMatrixCsv(evalResult.confusionMatrix);
    }
    if (needsConfusionPairs && confusionDetails != null) {
      csvFiles[ReportFileNames.confusionPairs] =
          csvExporter.buildConfusionPairsCsv(confusionDetails);
    }
    if (needsHealth && healthReport != null) {
      csvFiles[ReportFileNames.datasetHealth] =
          csvExporter.buildDatasetHealthCsv(healthReport);
    }
    if (needsWorst && worstCases != null) {
      csvFiles[ReportFileNames.worstCases] =
          csvExporter.buildWorstCasesCsv(worstCases);
    }

    return ReportBundle(
      projectName: projectName ?? 'Untitled project',
      modelRunName: modelRunName ?? modelRun.name,
      generatedAt: timestamp,
      evalConfig: evalConfig,
      htmlReport: html,
      csvFiles: csvFiles,
    );
  }
}
