import '../model/coco_dataset.dart';
import '../model/detection_match.dart';
import '../model/eval_config.dart';
import '../model/eval_result.dart';
import '../model/model_run.dart';
import '../model/prediction.dart';
import 'confusion_matrix.dart';
import 'detection_matcher.dart';
import 'small_object_stats.dart';

class ClassStats {
  const ClassStats({
    required this.categoryId,
    required this.categoryName,
    required this.gtCount,
    required this.predCount,
    required this.tp,
    required this.fp,
    required this.fn,
    required this.precision,
    required this.recall,
    required this.f1,
  });

  final int categoryId;
  final String categoryName;
  final int gtCount;
  final int predCount;
  final int tp;
  final int fp;
  final int fn;
  final double precision;
  final double recall;
  final double f1;
}

class MetricsCalculator {
  const MetricsCalculator({
    this.matcher = const DetectionMatcher(),
  });

  final DetectionMatcher matcher;

  EvalResult evaluate({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required EvalConfig config,
  }) {
    final List<DetectionMatch> matches = matcher.match(
      dataset: dataset,
      modelRun: modelRun,
      config: config,
    );
    final Map<int, ClassStats> perClassStats = buildPerClassStats(
      dataset: dataset,
      modelRun: modelRun,
      matches: matches,
      config: config,
    );
    final Map<int, ImageEvalSummary> imageSummaries = _buildImageSummaries(
      dataset: dataset,
      modelRun: modelRun,
      matches: matches,
      config: config,
    );
    return EvalResult(
      matches: matches,
      overall: _buildOverallStats(
        dataset: dataset,
        modelRun: modelRun,
        config: config,
        matches: matches,
        perClassStats: perClassStats,
        imageSummaries: imageSummaries,
      ),
      perClassStats: perClassStats,
      imageSummaries: imageSummaries,
      confusionMatrix: ConfusionMatrixBuilder().build(
        dataset: dataset,
        modelRun: modelRun,
        config: config,
      ),
      smallObjectStats: SmallObjectStatsBuilder().build(
        dataset: dataset,
        matches: matches,
        config: config,
      ),
      config: config,
    );
  }

  Map<int, ClassStats> buildPerClassStats({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required List<DetectionMatch> matches,
    required EvalConfig config,
  }) {
    final Map<int, _MutableClassStats> mutable = {
      for (final category in dataset.categoriesById.values)
        category.id: _MutableClassStats(),
    };

    for (final annotation in dataset.annotations) {
      if (config.ignoreCrowd && annotation.isCrowd) {
        continue;
      }
      mutable[annotation.categoryId]?.gtCount += 1;
    }
    for (final Prediction prediction in modelRun.predictions) {
      if (prediction.score >= config.confidenceThreshold) {
        mutable[prediction.categoryId]?.predCount += 1;
      }
    }
    for (final DetectionMatch match in matches) {
      final int? categoryId = match.categoryId;
      if (categoryId == null || !mutable.containsKey(categoryId)) {
        continue;
      }
      switch (match.type) {
        case DetectionMatchType.truePositive:
          mutable[categoryId]!.tp += 1;
        case DetectionMatchType.falsePositive:
          mutable[categoryId]!.fp += 1;
        case DetectionMatchType.falseNegative:
          mutable[categoryId]!.fn += 1;
        case DetectionMatchType.ignored:
          break;
      }
    }

    return {
      for (final entry in mutable.entries)
        entry.key: _toClassStats(
          categoryId: entry.key,
          categoryName: dataset.categoriesById[entry.key]!.name,
          value: entry.value,
        ),
    };
  }

  OverallStats _buildOverallStats({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required EvalConfig config,
    required List<DetectionMatch> matches,
    required Map<int, ClassStats> perClassStats,
    required Map<int, ImageEvalSummary> imageSummaries,
  }) {
    final int totalTp = matches.where(_isTp).length;
    final int totalFp = matches.where(_isFp).length;
    final int totalFn = matches.where(_isFn).length;
    final double microPrecision = _safeRatio(totalTp, totalTp + totalFp);
    final double microRecall = _safeRatio(totalTp, totalTp + totalFn);
    final double microF1 = _f1(microPrecision, microRecall);
    final Iterable<ClassStats> stats = perClassStats.values;

    return OverallStats(
      totalImages: dataset.imagesById.length,
      totalGt: dataset.annotations
          .where((annotation) => !(config.ignoreCrowd && annotation.isCrowd))
          .length,
      totalPredictionsBeforeThreshold: modelRun.predictions.length,
      totalPredictionsAfterThreshold: modelRun.predictions
          .where(
            (Prediction prediction) =>
                prediction.score >= config.confidenceThreshold,
          )
          .length,
      totalTp: totalTp,
      totalFp: totalFp,
      totalFn: totalFn,
      microPrecision: microPrecision,
      microRecall: microRecall,
      microF1: microF1,
      macroPrecision: _average(stats.map((ClassStats stat) => stat.precision)),
      macroRecall: _average(stats.map((ClassStats stat) => stat.recall)),
      macroF1: _average(stats.map((ClassStats stat) => stat.f1)),
      imagesWithAnyError: imageSummaries.values
          .where((ImageEvalSummary summary) => summary.hasFp || summary.hasFn)
          .length,
      imagesWithFp: imageSummaries.values
          .where((ImageEvalSummary summary) => summary.hasFp)
          .length,
      imagesWithFn: imageSummaries.values
          .where((ImageEvalSummary summary) => summary.hasFn)
          .length,
    );
  }

  Map<int, ImageEvalSummary> _buildImageSummaries({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required List<DetectionMatch> matches,
    required EvalConfig config,
  }) {
    final Set<int> imageIds = {
      ...dataset.imagesById.keys,
      ...modelRun.predictionsByImageId.keys,
    };
    final Map<int, ImageEvalSummary> summaries = {};
    for (final int imageId in imageIds) {
      final List<DetectionMatch> imageMatches = matches
          .where((DetectionMatch match) => match.imageId == imageId)
          .toList();
      final int tp = imageMatches.where(_isTp).length;
      final int fp = imageMatches.where(_isFp).length;
      final int fn = imageMatches.where(_isFn).length;
      final bool hasSmallObject =
          (dataset.annotationsByImageId[imageId] ?? const []).any(
        (annotation) =>
            smallObjectBucket(annotation.effectiveArea) ==
            ObjectSizeBucket.small,
      );
      summaries[imageId] = ImageEvalSummary(
        imageId: imageId,
        tp: tp,
        fp: fp,
        fn: fn,
        hasTp: tp > 0,
        hasFp: fp > 0,
        hasFn: fn > 0,
        hasClassConfusion: imageMatches.any(
          (DetectionMatch match) =>
              match.reason == DetectionMatchReason.wrongClass,
        ),
        hasSmallObject: hasSmallObject,
        hasOnlyBackgroundFp: fp > 0 && tp == 0 && fn == 0,
        hasMissedObjects: fn > 0,
      );
    }
    return summaries;
  }
}

class _MutableClassStats {
  int gtCount = 0;
  int predCount = 0;
  int tp = 0;
  int fp = 0;
  int fn = 0;
}

ClassStats _toClassStats({
  required int categoryId,
  required String categoryName,
  required _MutableClassStats value,
}) {
  final double precision = _safeRatio(value.tp, value.tp + value.fp);
  final double recall = _safeRatio(value.tp, value.tp + value.fn);
  return ClassStats(
    categoryId: categoryId,
    categoryName: categoryName,
    gtCount: value.gtCount,
    predCount: value.predCount,
    tp: value.tp,
    fp: value.fp,
    fn: value.fn,
    precision: precision,
    recall: recall,
    f1: _f1(precision, recall),
  );
}

bool _isTp(DetectionMatch match) =>
    match.type == DetectionMatchType.truePositive;
bool _isFp(DetectionMatch match) =>
    match.type == DetectionMatchType.falsePositive;
bool _isFn(DetectionMatch match) =>
    match.type == DetectionMatchType.falseNegative;

double _safeRatio(int numerator, int denominator) {
  return denominator == 0 ? 0 : numerator / denominator;
}

double _f1(double precision, double recall) {
  return precision + recall == 0
      ? 0
      : 2 * precision * recall / (precision + recall);
}

double _average(Iterable<double> values) {
  final List<double> list = values.toList();
  if (list.isEmpty) {
    return 0;
  }
  return list.reduce((double a, double b) => a + b) / list.length;
}
