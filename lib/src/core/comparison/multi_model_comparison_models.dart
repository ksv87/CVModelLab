/// Data models for multi-model (3+) comparison.
///
/// These types are produced by [MultiModelComparator] and consumed by the UI
/// and report exporters. They are pure data and contain no platform, Flutter or
/// colour logic.
library;

/// A metric the leaderboard can be ranked by.
enum MultiModelRankingMetric {
  ap,
  ap50,
  ap75,
  precision,
  recall,
  f1,
  tp,
  fp,
  fn,
  imagesWithErrors,
  smallObjectRecall,
}

enum SortDirection {
  ascending,
  descending,
}

/// Returns true when a higher value of [metric] is better.
///
/// `tp` and all precision-like / recall-like / AP metrics are higher-is-better;
/// `fp`, `fn` and `imagesWithErrors` are lower-is-better.
bool isHigherBetter(MultiModelRankingMetric metric) {
  switch (metric) {
    case MultiModelRankingMetric.ap:
    case MultiModelRankingMetric.ap50:
    case MultiModelRankingMetric.ap75:
    case MultiModelRankingMetric.precision:
    case MultiModelRankingMetric.recall:
    case MultiModelRankingMetric.f1:
    case MultiModelRankingMetric.tp:
    case MultiModelRankingMetric.smallObjectRecall:
      return true;
    case MultiModelRankingMetric.fp:
    case MultiModelRankingMetric.fn:
    case MultiModelRankingMetric.imagesWithErrors:
      return false;
  }
}

/// Configuration controlling which analyses to run and how to rank models.
class MultiModelComparisonConfig {
  const MultiModelComparisonConfig({
    this.primaryMetric = MultiModelRankingMetric.f1,
    this.sortDirection = SortDirection.descending,
    this.includeApMetrics = true,
    this.includeSmallObjectMetrics = true,
    this.includeImageDisagreement = true,
    this.includePerClassRanking = true,
  });

  /// Convenience alias for the documented `const MultiModelComparisonConfig.defaults()`.
  const MultiModelComparisonConfig.defaults()
      : primaryMetric = MultiModelRankingMetric.f1,
        sortDirection = SortDirection.descending,
        includeApMetrics = true,
        includeSmallObjectMetrics = true,
        includeImageDisagreement = true,
        includePerClassRanking = true;

  final MultiModelRankingMetric primaryMetric;
  final SortDirection sortDirection;
  final bool includeApMetrics;
  final bool includeSmallObjectMetrics;
  final bool includeImageDisagreement;
  final bool includePerClassRanking;

  MultiModelComparisonConfig copyWith({
    MultiModelRankingMetric? primaryMetric,
    SortDirection? sortDirection,
    bool? includeApMetrics,
    bool? includeSmallObjectMetrics,
    bool? includeImageDisagreement,
    bool? includePerClassRanking,
  }) {
    return MultiModelComparisonConfig(
      primaryMetric: primaryMetric ?? this.primaryMetric,
      sortDirection: sortDirection ?? this.sortDirection,
      includeApMetrics: includeApMetrics ?? this.includeApMetrics,
      includeSmallObjectMetrics:
          includeSmallObjectMetrics ?? this.includeSmallObjectMetrics,
      includeImageDisagreement:
          includeImageDisagreement ?? this.includeImageDisagreement,
      includePerClassRanking:
          includePerClassRanking ?? this.includePerClassRanking,
    );
  }
}

/// The full result of a multi-model comparison.
class MultiModelComparisonResult {
  const MultiModelComparisonResult({
    required this.leaderboard,
    required this.perClassRankings,
    required this.imageDisagreements,
    required this.pairwiseRegressionMatrix,
    required this.consensusSummary,
    required this.config,
    required this.generatedAt,
  });

  /// An empty result, used when fewer than two model runs are supplied.
  MultiModelComparisonResult.empty({
    required this.config,
    required this.generatedAt,
  })  : leaderboard = const [],
        perClassRankings = const [],
        imageDisagreements = const [],
        pairwiseRegressionMatrix = const [],
        consensusSummary = const [];

  final List<ModelRunLeaderboardEntry> leaderboard;
  final List<ClassModelRanking> perClassRankings;
  final List<ImageModelDisagreement> imageDisagreements;
  final List<PairwiseRegressionSummary> pairwiseRegressionMatrix;
  final List<ModelConsensusSummary> consensusSummary;
  final MultiModelComparisonConfig config;
  final DateTime generatedAt;

  bool get isEmpty => leaderboard.isEmpty;
}

/// A single leaderboard row describing one model run.
class ModelRunLeaderboardEntry {
  const ModelRunLeaderboardEntry({
    required this.modelRunId,
    required this.modelRunName,
    required this.totalTp,
    required this.totalFp,
    required this.totalFn,
    required this.imagesWithErrors,
    required this.precision,
    required this.recall,
    required this.f1,
    this.ap,
    this.ap50,
    this.ap75,
    this.apSmall,
    this.apMedium,
    this.apLarge,
    this.smallObjectRecall,
    this.mediumObjectRecall,
    this.largeObjectRecall,
    required this.rank,
    required this.score,
  });

  final String modelRunId;
  final String modelRunName;

  final int totalTp;
  final int totalFp;
  final int totalFn;
  final int imagesWithErrors;

  final double precision;
  final double recall;
  final double f1;

  final double? ap;
  final double? ap50;
  final double? ap75;
  final double? apSmall;
  final double? apMedium;
  final double? apLarge;

  final double? smallObjectRecall;
  final double? mediumObjectRecall;
  final double? largeObjectRecall;

  final int rank;
  final double score;

  bool get hasAp => ap != null || ap50 != null || ap75 != null;
}

/// Per-class ranking of all models for a single category.
class ClassModelRanking {
  const ClassModelRanking({
    required this.categoryId,
    required this.categoryName,
    this.bestModelRunId,
    this.worstModelRunId,
    this.bestF1,
    this.worstF1,
    this.bestRecall,
    this.worstRecall,
    this.bestPrecision,
    this.worstPrecision,
    this.bestAp,
    this.worstAp,
    required this.entries,
  });

  final int categoryId;
  final String categoryName;

  final String? bestModelRunId;
  final String? worstModelRunId;

  final double? bestF1;
  final double? worstF1;
  final double? bestRecall;
  final double? worstRecall;
  final double? bestPrecision;
  final double? worstPrecision;
  final double? bestAp;
  final double? worstAp;

  final List<ClassModelMetricEntry> entries;

  double get f1Spread =>
      (bestF1 == null || worstF1 == null) ? 0 : bestF1! - worstF1!;
  double get recallSpread =>
      (bestRecall == null || worstRecall == null) ? 0 : bestRecall! - worstRecall!;
  double? get apSpread =>
      (bestAp == null || worstAp == null) ? null : bestAp! - worstAp!;
}

/// One model's metrics for one class.
class ClassModelMetricEntry {
  const ClassModelMetricEntry({
    required this.modelRunId,
    required this.modelRunName,
    required this.gtCount,
    required this.predCount,
    required this.tp,
    required this.fp,
    required this.fn,
    required this.precision,
    required this.recall,
    required this.f1,
    this.ap,
    this.ap50,
    this.ap75,
    this.ar,
  });

  final String modelRunId;
  final String modelRunName;

  final int gtCount;
  final int predCount;
  final int tp;
  final int fp;
  final int fn;

  final double precision;
  final double recall;
  final double f1;

  final double? ap;
  final double? ap50;
  final double? ap75;
  final double? ar;
}

enum ImageDisagreementType {
  allCorrect,
  allWrong,
  someModelsWrong,
  onlyOneModelCorrect,
  onlyOneModelWrong,
  predictionCountDisagreement,
  classDisagreement,
  largeErrorSpread,
}

/// How models disagree on a single image.
class ImageModelDisagreement {
  const ImageModelDisagreement({
    required this.imageId,
    required this.fileName,
    required this.type,
    required this.modelsCorrectCount,
    required this.modelsWrongCount,
    required this.bestErrorCount,
    required this.worstErrorCount,
    required this.errorSpread,
    required this.modelStatuses,
  });

  final int imageId;
  final String fileName;
  final ImageDisagreementType type;

  final int modelsCorrectCount;
  final int modelsWrongCount;
  final int bestErrorCount;
  final int worstErrorCount;
  final int errorSpread;

  final List<ImageModelStatus> modelStatuses;
}

/// One model's per-image status used by image-disagreement analysis.
class ImageModelStatus {
  const ImageModelStatus({
    required this.modelRunId,
    required this.modelRunName,
    required this.tp,
    required this.fp,
    required this.fn,
    required this.errorCount,
    required this.hasError,
    required this.hasClassConfusion,
    required this.hasHighConfidenceFp,
    required this.hasMissedSmallObject,
    this.maxFpScore,
    this.minTpIou,
  });

  final String modelRunId;
  final String modelRunName;

  final int tp;
  final int fp;
  final int fn;
  final int errorCount;

  final bool hasError;
  final bool hasClassConfusion;
  final bool hasHighConfidenceFp;
  final bool hasMissedSmallObject;

  final double? maxFpScore;
  final double? minTpIou;
}

/// A directional (base → candidate) pairwise summary for the regression matrix.
class PairwiseRegressionSummary {
  const PairwiseRegressionSummary({
    required this.baseModelRunId,
    required this.candidateModelRunId,
    required this.fixedImages,
    required this.brokenImages,
    required this.improvedImages,
    required this.regressedImages,
    required this.deltaTp,
    required this.deltaFp,
    required this.deltaFn,
    required this.deltaPrecision,
    required this.deltaRecall,
    required this.deltaF1,
    this.deltaAp,
  });

  final String baseModelRunId;
  final String candidateModelRunId;

  final int fixedImages;
  final int brokenImages;
  final int improvedImages;
  final int regressedImages;

  final int deltaTp;
  final int deltaFp;
  final int deltaFn;
  final double deltaPrecision;
  final double deltaRecall;
  final double deltaF1;
  final double? deltaAp;
}

/// Aggregate consensus counts across all images and models.
class ModelConsensusSummary {
  const ModelConsensusSummary({
    required this.totalImages,
    required this.allModelsCorrect,
    required this.allModelsWrong,
    required this.someModelsWrong,
    required this.onlyOneModelCorrect,
    required this.onlyOneModelWrong,
  });

  final int totalImages;
  final int allModelsCorrect;
  final int allModelsWrong;
  final int someModelsWrong;
  final int onlyOneModelCorrect;
  final int onlyOneModelWrong;
}
