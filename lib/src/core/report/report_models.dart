import '../eval/eval_result_filter.dart';
import '../model/annotation.dart';
import '../model/bbox.dart';
import '../model/coco_dataset.dart';
import '../model/detection_match.dart';
import '../model/eval_result.dart';
import '../model/model_run.dart';
import '../model/prediction.dart';

/// Which slice of the evaluation a report should describe.
enum ReportScope {
  fullEvaluation,
  filteredView,
}

/// Section options for the PDF executive report.
class PdfReportOptions {
  const PdfReportOptions({
    this.includeRecommendations = true,
    this.includeWorstCases = true,
    this.includeComparison = true,
    this.includeHealth = true,
    this.includeConfusion = true,
  });

  final bool includeRecommendations;
  final bool includeWorstCases;
  final bool includeComparison;
  final bool includeHealth;
  final bool includeConfusion;

  PdfReportOptions copyWith({
    bool? includeRecommendations,
    bool? includeWorstCases,
    bool? includeComparison,
    bool? includeHealth,
    bool? includeConfusion,
  }) {
    return PdfReportOptions(
      includeRecommendations:
          includeRecommendations ?? this.includeRecommendations,
      includeWorstCases: includeWorstCases ?? this.includeWorstCases,
      includeComparison: includeComparison ?? this.includeComparison,
      includeHealth: includeHealth ?? this.includeHealth,
      includeConfusion: includeConfusion ?? this.includeConfusion,
    );
  }
}

/// Which artifacts to include in a [ReportBundle].
class ReportComponents {
  const ReportComponents({
    this.includeHtml = true,
    this.includePerClassMetricsCsv = true,
    this.includeImageErrorsCsv = true,
    this.includeMatchesCsv = true,
    this.includeSmallObjectStatsCsv = false,
    this.includeConfusionMatrixCsv = false,
    this.includeConfusionPairsCsv = false,
    this.includeDatasetHealthCsv = false,
    this.includeWorstCasesCsv = false,
    this.includeRecommendationsCsv = false,
    this.includeXlsxWorkbook = false,
    this.includePdfReport = false,
    this.pdfOptions = const PdfReportOptions(),
    this.includeApInHtml = true,
    this.includePerClassAp = true,
    this.includeApInXlsx = true,
    this.includeApInPdf = true,
    this.includeApMetricsCsv = false,
    this.includePerClassApCsv = false,
  });

  final bool includeHtml;
  final bool includePerClassMetricsCsv;
  final bool includeImageErrorsCsv;
  final bool includeMatchesCsv;
  final bool includeSmallObjectStatsCsv;
  final bool includeConfusionMatrixCsv;
  final bool includeConfusionPairsCsv;
  final bool includeDatasetHealthCsv;
  final bool includeWorstCasesCsv;
  final bool includeRecommendationsCsv;
  final bool includeXlsxWorkbook;
  final bool includePdfReport;
  final PdfReportOptions pdfOptions;
  final bool includeApInHtml;
  final bool includePerClassAp;
  final bool includeApInXlsx;
  final bool includeApInPdf;
  final bool includeApMetricsCsv;
  final bool includePerClassApCsv;

  ReportComponents copyWith({
    bool? includeHtml,
    bool? includePerClassMetricsCsv,
    bool? includeImageErrorsCsv,
    bool? includeMatchesCsv,
    bool? includeSmallObjectStatsCsv,
    bool? includeConfusionMatrixCsv,
    bool? includeConfusionPairsCsv,
    bool? includeDatasetHealthCsv,
    bool? includeWorstCasesCsv,
    bool? includeRecommendationsCsv,
    bool? includeXlsxWorkbook,
    bool? includePdfReport,
    PdfReportOptions? pdfOptions,
    bool? includeApInHtml,
    bool? includePerClassAp,
    bool? includeApInXlsx,
    bool? includeApInPdf,
    bool? includeApMetricsCsv,
    bool? includePerClassApCsv,
  }) {
    return ReportComponents(
      includeHtml: includeHtml ?? this.includeHtml,
      includePerClassMetricsCsv:
          includePerClassMetricsCsv ?? this.includePerClassMetricsCsv,
      includeImageErrorsCsv:
          includeImageErrorsCsv ?? this.includeImageErrorsCsv,
      includeMatchesCsv: includeMatchesCsv ?? this.includeMatchesCsv,
      includeSmallObjectStatsCsv:
          includeSmallObjectStatsCsv ?? this.includeSmallObjectStatsCsv,
      includeConfusionMatrixCsv:
          includeConfusionMatrixCsv ?? this.includeConfusionMatrixCsv,
      includeConfusionPairsCsv:
          includeConfusionPairsCsv ?? this.includeConfusionPairsCsv,
      includeDatasetHealthCsv:
          includeDatasetHealthCsv ?? this.includeDatasetHealthCsv,
      includeWorstCasesCsv: includeWorstCasesCsv ?? this.includeWorstCasesCsv,
      includeRecommendationsCsv:
          includeRecommendationsCsv ?? this.includeRecommendationsCsv,
      includeXlsxWorkbook: includeXlsxWorkbook ?? this.includeXlsxWorkbook,
      includePdfReport: includePdfReport ?? this.includePdfReport,
      pdfOptions: pdfOptions ?? this.pdfOptions,
      includeApInHtml: includeApInHtml ?? this.includeApInHtml,
      includePerClassAp: includePerClassAp ?? this.includePerClassAp,
      includeApInXlsx: includeApInXlsx ?? this.includeApInXlsx,
      includeApInPdf: includeApInPdf ?? this.includeApInPdf,
      includeApMetricsCsv: includeApMetricsCsv ?? this.includeApMetricsCsv,
      includePerClassApCsv: includePerClassApCsv ?? this.includePerClassApCsv,
    );
  }
}

/// A flattened view of a [DetectionMatch] used by both CSV export and the HTML
/// error-example tables, so the two never re-derive match data differently.
class ReportMatchRow {
  const ReportMatchRow({
    required this.imageId,
    required this.fileName,
    required this.matchType,
    required this.categoryId,
    required this.categoryName,
    required this.score,
    required this.iou,
    required this.reason,
    required this.bbox,
    required this.gtAnnotationId,
    required this.predictionIndex,
  });

  final int imageId;
  final String fileName;
  final String matchType;
  final int? categoryId;
  final String categoryName;
  final double? score;
  final double? iou;
  final String? reason;
  final BBox? bbox;
  final int? gtAnnotationId;
  final int? predictionIndex;
}

String matchTypeLabel(DetectionMatchType type) {
  return switch (type) {
    DetectionMatchType.truePositive => 'TP',
    DetectionMatchType.falsePositive => 'FP',
    DetectionMatchType.falseNegative => 'FN',
    DetectionMatchType.ignored => 'ignored',
  };
}

/// Builds [ReportMatchRow]s from raw matches, resolving category names, GT
/// annotation ids and the prediction's index within its image.
List<ReportMatchRow> buildMatchRows({
  required CocoDataset dataset,
  required ModelRun modelRun,
  required List<DetectionMatch> matches,
}) {
  final List<ReportMatchRow> rows = [];
  for (final DetectionMatch match in matches) {
    if (match.type == DetectionMatchType.ignored) {
      continue;
    }
    final String fileName = dataset.imagesById[match.imageId]?.fileName ?? '';
    final bool isFn = match.type == DetectionMatchType.falseNegative;
    final Prediction? prediction = match.prediction;
    final GroundTruthAnnotation? groundTruth = match.groundTruth;
    final BBox? bbox =
        isFn ? groundTruth?.bbox : (prediction?.bbox ?? groundTruth?.bbox);
    final int? categoryId = match.categoryId ??
        (isFn ? groundTruth?.categoryId : prediction?.categoryId);

    rows.add(
      ReportMatchRow(
        imageId: match.imageId,
        fileName: fileName,
        matchType: matchTypeLabel(match.type),
        categoryId: categoryId,
        categoryName: categoryId == null
            ? ''
            : (dataset.categoriesById[categoryId]?.name ?? '$categoryId'),
        score: isFn ? null : prediction?.score,
        iou: match.iou,
        reason: match.reason,
        bbox: bbox,
        gtAnnotationId: groundTruth?.id,
        predictionIndex: prediction == null
            ? null
            : _predictionIndex(modelRun, match.imageId, prediction),
      ),
    );
  }
  return rows;
}

int? _predictionIndex(ModelRun modelRun, int imageId, Prediction prediction) {
  final List<Prediction> predictions =
      modelRun.predictionsByImageId[imageId] ?? const <Prediction>[];
  final int index =
      predictions.indexWhere((Prediction p) => identical(p, prediction));
  return index == -1 ? null : index;
}

/// Resolves the set of matches a report covers, honouring [scope].
List<DetectionMatch> matchesForScope({
  required EvalResult evalResult,
  required ReportScope scope,
  FilteredEvalView? filteredView,
}) {
  if (scope == ReportScope.filteredView && filteredView != null) {
    return [
      for (final int imageId in filteredView.filteredImageIds)
        ...filteredView.visibleMatchesForImage(imageId),
    ];
  }
  return evalResult.matches;
}

/// Resolves the ordered image ids a report covers, honouring [scope].
List<int> imageIdsForScope({
  required CocoDataset dataset,
  required ReportScope scope,
  FilteredEvalView? filteredView,
}) {
  if (scope == ReportScope.filteredView && filteredView != null) {
    return List<int>.unmodifiable(filteredView.filteredImageIds);
  }
  return dataset.imagesById.keys.toList()..sort();
}
