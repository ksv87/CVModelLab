import '../eval/class_stats.dart';
import '../eval/confusion_matrix.dart';
import '../eval/small_object_stats.dart';
import 'detection_match.dart';
import 'eval_config.dart';

class ImageEvalSummary {
  const ImageEvalSummary({
    required this.imageId,
    required this.tp,
    required this.fp,
    required this.fn,
    required this.hasTp,
    required this.hasFp,
    required this.hasFn,
    required this.hasClassConfusion,
    required this.hasSmallObject,
    required this.hasOnlyBackgroundFp,
    required this.hasMissedObjects,
  });

  final int imageId;
  final int tp;
  final int fp;
  final int fn;
  final bool hasTp;
  final bool hasFp;
  final bool hasFn;
  final bool hasClassConfusion;
  final bool hasSmallObject;
  final bool hasOnlyBackgroundFp;
  final bool hasMissedObjects;
}

class OverallStats {
  const OverallStats({
    required this.totalImages,
    required this.totalGt,
    required this.totalPredictionsBeforeThreshold,
    required this.totalPredictionsAfterThreshold,
    required this.totalTp,
    required this.totalFp,
    required this.totalFn,
    required this.microPrecision,
    required this.microRecall,
    required this.microF1,
    required this.macroPrecision,
    required this.macroRecall,
    required this.macroF1,
    required this.imagesWithAnyError,
    required this.imagesWithFp,
    required this.imagesWithFn,
  });

  final int totalImages;
  final int totalGt;
  final int totalPredictionsBeforeThreshold;
  final int totalPredictionsAfterThreshold;
  final int totalTp;
  final int totalFp;
  final int totalFn;
  final double microPrecision;
  final double microRecall;
  final double microF1;
  final double macroPrecision;
  final double macroRecall;
  final double macroF1;
  final int imagesWithAnyError;
  final int imagesWithFp;
  final int imagesWithFn;
}

class EvalResult {
  const EvalResult({
    required this.matches,
    required this.overall,
    required this.perClassStats,
    required this.imageSummaries,
    required this.confusionMatrix,
    required this.smallObjectStats,
    required this.config,
  });

  final List<DetectionMatch> matches;
  final OverallStats overall;
  final Map<int, ClassStats> perClassStats;
  final Map<int, ImageEvalSummary> imageSummaries;
  final ConfusionMatrix confusionMatrix;
  final Map<int, Map<ObjectSizeBucket, SmallObjectClassStats>> smallObjectStats;
  final EvalConfig config;
}
