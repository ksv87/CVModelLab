import 'package:pdf/widgets.dart' as pw;

import '../ap_eval/ap_eval_models.dart';
import '../eval/confusion_details.dart';
import '../eval/eval_result_filter.dart';
import '../comparison/comparison_models.dart';
import '../comparison/multi_model_comparison_models.dart';
import '../health/dataset_health_checker.dart';
import '../health/dataset_health_models.dart';
import '../i18n/message_key.dart';
import '../model/coco_dataset.dart';
import '../model/eval_config.dart';
import '../model/eval_result.dart';
import '../model/eval_view_filter.dart';
import '../model/model_run.dart';
import '../recommendation/recommendation_models.dart';
import '../recommendation/rule_based_recommendation_engine.dart';
import '../worst_cases/worst_case_miner.dart';
import '../worst_cases/worst_case_models.dart';
import 'csv_exporter.dart';
import 'html_report_builder.dart';
import 'pdf_report_builder.dart';
import 'report_models.dart';
import 'xlsx_report_builder.dart';
import '../../ui/l10n/app_localizations.dart';

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
  static const String recommendations = 'recommendations.csv';
  static const String apMetrics = 'ap_metrics.csv';
  static const String perClassAp = 'per_class_ap.csv';
  static const String xlsx = 'cv_model_lab_report.xlsx';
  static const String pdf = 'cv_model_lab_report.pdf';
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
    required this.binaryFiles,
  });

  final String projectName;
  final String modelRunName;
  final DateTime generatedAt;
  final EvalConfig evalConfig;

  /// The full HTML document, or empty if HTML was not requested.
  final String htmlReport;

  /// CSV files keyed by file name.
  final Map<String, String> csvFiles;

  /// Binary files keyed by file name.
  final Map<String, List<int>> binaryFiles;

  bool get hasHtml => htmlReport.isNotEmpty;

  /// File names in the order they should be presented to the user.
  List<String> get fileNames => [
        if (hasHtml) ReportFileNames.html,
        ...csvFiles.keys,
        ...binaryFiles.keys,
      ];
}

/// Assembles a [ReportBundle] from already-computed evaluation data. This layer
/// only formats data; it never recomputes metrics.
class ReportBundleBuilder {
  const ReportBundleBuilder({
    this.htmlBuilder = const HtmlReportBuilder(),
    this.csvExporter = const CsvExporter(),
    this.xlsxBuilder = const XlsxReportBuilder(),
    this.pdfBuilder = const PdfReportBuilder(),
  });

  final HtmlReportBuilder htmlBuilder;
  final CsvExporter csvExporter;
  final XlsxReportBuilder xlsxBuilder;
  final PdfReportBuilder pdfBuilder;

  Future<ReportBundle> build({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required EvalConfig evalConfig,
    required EvalResult evalResult,
    required ReportComponents components,
    EvalViewFilter? activeFilter,
    FilteredEvalView? filteredView,
    ReportScope scope = ReportScope.fullEvaluation,
    AppLocale locale = AppLocale.en,
    String? projectName,
    String? modelRunName,
    Set<String> missingImageFileNames = const <String>{},
    DatasetImageAvailability? imageAvailability,
    ModelComparisonResult? comparison,
    MultiModelComparisonResult? multiComparison,
    DateTime? generatedAt,
    ApEvalResult? apEvalResult,
    pw.ThemeData? pdfTheme,
  }) async {
    final DateTime timestamp = generatedAt ?? DateTime.now();
    final String resolvedProject = projectName ?? 'Untitled project';
    final String resolvedRun = modelRunName ?? modelRun.name;
    final AppLocalizations localizations = AppLocalizations.forLocale(locale);

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

    // Determine which optional analytics need to be computed.
    // Separate "needs computation" from "export as CSV" — fixes the bug where
    // enabling XLSX caused health/worst/confusion CSVs to be added silently.
    final bool pdfNeedsHealth =
        components.includePdfReport && components.pdfOptions.includeHealth;
    final bool pdfNeedsWorst =
        components.includePdfReport && components.pdfOptions.includeWorstCases;
    final bool pdfNeedsConfusion =
        components.includePdfReport && components.pdfOptions.includeConfusion;
    final bool pdfNeedsRecs = components.includePdfReport &&
        components.pdfOptions.includeRecommendations;

    final bool computeHealth = components.includeDatasetHealthCsv ||
        components.includeXlsxWorkbook ||
        components.includeHtml ||
        components.includeRecommendationsCsv ||
        pdfNeedsHealth ||
        pdfNeedsRecs;
    final bool computeWorst = components.includeWorstCasesCsv ||
        components.includeXlsxWorkbook ||
        components.includeHtml ||
        components.includeRecommendationsCsv ||
        pdfNeedsWorst ||
        pdfNeedsRecs;
    final bool computeConfusion = components.includeConfusionPairsCsv ||
        components.includeXlsxWorkbook ||
        components.includeHtml ||
        components.includeRecommendationsCsv ||
        pdfNeedsConfusion ||
        pdfNeedsRecs;
    final bool computeRecs = components.includeHtml ||
        components.includeRecommendationsCsv ||
        components.includeXlsxWorkbook ||
        pdfNeedsRecs;

    final DatasetHealthReport? healthReport = computeHealth
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
    final WorstCasesResult? worstCases = computeWorst
        ? const WorstCaseMiner().mine(
            dataset: dataset,
            modelRun: modelRun,
            evalResult: evalResult,
            evalConfig: evalConfig,
          )
        : null;
    final ConfusionMatrixDetails? confusionDetails = computeConfusion
        ? const ConfusionMatrixDetailBuilder().build(
            dataset: dataset,
            modelRun: modelRun,
            config: evalConfig,
          )
        : null;
    final List<Recommendation> recommendations = computeRecs
        ? const RuleBasedRecommendationEngine().build(
            dataset: dataset,
            modelRun: modelRun,
            evalResult: evalResult,
            evalConfig: evalConfig,
            healthReport: healthReport,
            worstCases: worstCases,
            comparison: comparison,
          )
        : const <Recommendation>[];

    // ── HTML ──────────────────────────────────────────────────────────────────
    final ApEvalResult? htmlApEvalResult =
        components.includeApInHtml ? apEvalResult : null;
    final ApEvalResult? xlsxApEvalResult =
        components.includeApInXlsx ? apEvalResult : null;
    final ApEvalResult? pdfApEvalResult =
        components.includeApInPdf ? apEvalResult : null;

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
            recommendations: recommendations,
            apEvalResult: htmlApEvalResult,
            locale: locale,
          )
        : '';

    // ── CSV (each flag is independent) ───────────────────────────────────────
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
    if (components.includeConfusionPairsCsv && confusionDetails != null) {
      csvFiles[ReportFileNames.confusionPairs] =
          csvExporter.buildConfusionPairsCsv(confusionDetails);
    }
    if (components.includeDatasetHealthCsv && healthReport != null) {
      csvFiles[ReportFileNames.datasetHealth] =
          csvExporter.buildDatasetHealthCsv(healthReport);
    }
    if (components.includeWorstCasesCsv && worstCases != null) {
      csvFiles[ReportFileNames.worstCases] =
          csvExporter.buildWorstCasesCsv(worstCases);
    }
    if (components.includeRecommendationsCsv) {
      csvFiles[ReportFileNames.recommendations] =
          csvExporter.buildRecommendationsCsv(recommendations);
    }
    if (components.includeApMetricsCsv && apEvalResult != null) {
      csvFiles[ReportFileNames.apMetrics] =
          csvExporter.buildApMetricsCsv(apEvalResult);
    }
    if (components.includePerClassApCsv &&
        components.includePerClassAp &&
        apEvalResult != null &&
        apEvalResult.perClass.isNotEmpty) {
      csvFiles[ReportFileNames.perClassAp] =
          csvExporter.buildPerClassApCsv(apEvalResult);
    }

    // ── binary (XLSX, PDF) ────────────────────────────────────────────────────
    final Map<String, List<int>> binaryFiles = {};
    if (components.includeXlsxWorkbook) {
      binaryFiles[ReportFileNames.xlsx] = xlsxBuilder.buildWorkbook(
        xlsxBuilder.buildData(
          dataset: dataset,
          modelRun: modelRun,
          evalConfig: evalConfig,
          evalResult: evalResult,
          projectName: resolvedProject,
          modelRunName: resolvedRun,
          generatedAt: timestamp,
          matchRows: matchRows,
          imageIds: imageIds,
          missingImageFileNames: missingImageFileNames,
          healthReport: healthReport,
          worstCases: worstCases,
          recommendations: recommendations,
          confusionDetails: confusionDetails,
          comparison: comparison,
          apEvalResult: xlsxApEvalResult,
          localizations: localizations,
        ),
      );
    }
    if (components.includePdfReport) {
      final pdfData = pdfBuilder.buildData(
        dataset: dataset,
        modelRun: modelRun,
        evalConfig: evalConfig,
        evalResult: evalResult,
        projectName: resolvedProject,
        modelRunName: resolvedRun,
        generatedAt: timestamp,
        matchRows: matchRows,
        missingImageFileNames: missingImageFileNames,
        healthReport: pdfNeedsHealth ? healthReport : null,
        worstCases: pdfNeedsWorst ? worstCases : null,
        confusionDetails: pdfNeedsConfusion ? confusionDetails : null,
        comparison: multiComparison == null &&
                (pdfNeedsRecs || components.pdfOptions.includeComparison)
            ? comparison
            : null,
        multiComparison:
            components.pdfOptions.includeComparison ? multiComparison : null,
        recommendations:
            pdfNeedsRecs ? recommendations : const <Recommendation>[],
        apEvalResult: pdfApEvalResult,
        locale: locale,
      );
      binaryFiles[ReportFileNames.pdf] =
          await pdfBuilder.buildPdf(pdfData, theme: pdfTheme);
    }

    return ReportBundle(
      projectName: resolvedProject,
      modelRunName: resolvedRun,
      generatedAt: timestamp,
      evalConfig: evalConfig,
      htmlReport: html,
      csvFiles: csvFiles,
      binaryFiles: binaryFiles,
    );
  }
}
