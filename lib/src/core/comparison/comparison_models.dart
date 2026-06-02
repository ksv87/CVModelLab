enum ImageComparisonStatus {
  fixed,
  broken,
  improved,
  regressed,
  unchangedCorrect,
  unchangedWrong,
}

class ModelComparisonResult {
  const ModelComparisonResult({
    required this.baseRunId,
    required this.candidateRunId,
    required this.overallDiff,
    required this.perClassDiffs,
    required this.imageSummaries,
    required this.fixedImageIds,
    required this.brokenImageIds,
    required this.improvedImageIds,
    required this.regressedImageIds,
    required this.unchangedCorrectImageIds,
    required this.unchangedWrongImageIds,
  });

  final String baseRunId;
  final String candidateRunId;
  final MetricsDiff overallDiff;
  final List<ClassMetricsDiff> perClassDiffs;
  final List<ImageComparisonSummary> imageSummaries;
  final List<int> fixedImageIds;
  final List<int> brokenImageIds;
  final List<int> improvedImageIds;
  final List<int> regressedImageIds;
  final List<int> unchangedCorrectImageIds;
  final List<int> unchangedWrongImageIds;
}

class MetricsDiff {
  const MetricsDiff({
    required this.basePrecision,
    required this.candidatePrecision,
    required this.deltaPrecision,
    required this.baseRecall,
    required this.candidateRecall,
    required this.deltaRecall,
    required this.baseF1,
    required this.candidateF1,
    required this.deltaF1,
    required this.baseTp,
    required this.candidateTp,
    required this.deltaTp,
    required this.baseFp,
    required this.candidateFp,
    required this.deltaFp,
    required this.baseFn,
    required this.candidateFn,
    required this.deltaFn,
    required this.baseImagesWithErrors,
    required this.candidateImagesWithErrors,
    required this.deltaImagesWithErrors,
  });

  final double basePrecision;
  final double candidatePrecision;
  final double deltaPrecision;
  final double baseRecall;
  final double candidateRecall;
  final double deltaRecall;
  final double baseF1;
  final double candidateF1;
  final double deltaF1;
  final int baseTp;
  final int candidateTp;
  final int deltaTp;
  final int baseFp;
  final int candidateFp;
  final int deltaFp;
  final int baseFn;
  final int candidateFn;
  final int deltaFn;
  final int baseImagesWithErrors;
  final int candidateImagesWithErrors;
  final int deltaImagesWithErrors;
}

class ClassMetricsDiff {
  const ClassMetricsDiff({
    required this.categoryId,
    required this.categoryName,
    required this.diff,
  });

  final int categoryId;
  final String categoryName;
  final MetricsDiff diff;
}

class ImageComparisonSummary {
  const ImageComparisonSummary({
    required this.imageId,
    required this.fileName,
    required this.baseTp,
    required this.baseFp,
    required this.baseFn,
    required this.candidateTp,
    required this.candidateFp,
    required this.candidateFn,
    required this.deltaTp,
    required this.deltaFp,
    required this.deltaFn,
    required this.baseHasError,
    required this.candidateHasError,
    required this.status,
  });

  final int imageId;
  final String fileName;
  final int baseTp;
  final int baseFp;
  final int baseFn;
  final int candidateTp;
  final int candidateFp;
  final int candidateFn;
  final int deltaTp;
  final int deltaFp;
  final int deltaFn;
  final bool baseHasError;
  final bool candidateHasError;
  final ImageComparisonStatus status;
}
