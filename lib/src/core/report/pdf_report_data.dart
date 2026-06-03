import '../ap_eval/ap_eval_models.dart';
import '../comparison/comparison_models.dart';
import '../eval/class_stats.dart';
import '../eval/confusion_details.dart';
import '../health/dataset_health_models.dart';
import '../i18n/message_key.dart';
import '../model/eval_config.dart';
import '../recommendation/recommendation_models.dart';
import '../worst_cases/worst_case_models.dart';
import 'report_models.dart';

/// Pre-extracted data for a PDF report. Keeps the builder stateless.
class PdfReportData {
  const PdfReportData({
    required this.projectName,
    required this.modelRunName,
    required this.generatedAt,
    required this.evalConfig,
    required this.totalImages,
    required this.totalGt,
    required this.totalPredictions,
    required this.predictionsAfterThreshold,
    required this.tp,
    required this.fp,
    required this.fn,
    required this.precision,
    required this.recall,
    required this.f1,
    required this.microPrecision,
    required this.microRecall,
    required this.microF1,
    required this.macroPrecision,
    required this.macroRecall,
    required this.macroF1,
    required this.imagesWithErrors,
    required this.totalCategories,
    required this.perClassStats,
    required this.matchRows,
    this.missingImageFileNames = const <String>{},
    this.healthReport,
    this.worstCases,
    this.confusionDetails,
    this.comparison,
    this.recommendations = const <Recommendation>[],
    this.apEvalResult,
    this.locale = AppLocale.en,
  });

  final String projectName;
  final String modelRunName;
  final DateTime generatedAt;
  final EvalConfig evalConfig;

  final int totalImages;
  final int totalGt;
  final int totalPredictions;
  final int predictionsAfterThreshold;
  final int tp;
  final int fp;
  final int fn;
  final double precision;
  final double recall;
  final double f1;
  final double microPrecision;
  final double microRecall;
  final double microF1;
  final double macroPrecision;
  final double macroRecall;
  final double macroF1;
  final int imagesWithErrors;
  final int totalCategories;

  final List<ClassStats> perClassStats;
  final List<ReportMatchRow> matchRows;
  final Set<String> missingImageFileNames;

  final DatasetHealthReport? healthReport;
  final WorstCasesResult? worstCases;
  final ConfusionMatrixDetails? confusionDetails;
  final ModelComparisonResult? comparison;
  final List<Recommendation> recommendations;
  final ApEvalResult? apEvalResult;
  final AppLocale locale;
}
