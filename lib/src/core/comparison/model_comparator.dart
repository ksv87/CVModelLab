import '../eval/class_stats.dart';
import '../model/coco_dataset.dart';
import '../model/eval_config.dart';
import '../model/eval_result.dart';
import '../model/model_run.dart';
import 'comparison_models.dart';

class ModelComparator {
  const ModelComparator();

  ModelComparisonResult compare({
    required CocoDataset dataset,
    required ModelRun baseRun,
    required EvalResult baseEval,
    required ModelRun candidateRun,
    required EvalResult candidateEval,
    required EvalConfig evalConfig,
  }) {
    // Build per-image summaries.
    final Set<int> allImageIds = {
      ...dataset.imagesById.keys,
      ...baseEval.imageSummaries.keys,
      ...candidateEval.imageSummaries.keys,
    };

    final List<ImageComparisonSummary> imageSummaries = [];
    final List<int> fixedImageIds = [];
    final List<int> brokenImageIds = [];
    final List<int> improvedImageIds = [];
    final List<int> regressedImageIds = [];
    final List<int> unchangedCorrectImageIds = [];
    final List<int> unchangedWrongImageIds = [];

    for (final int imageId in allImageIds..toList().sort()) {
      final baseSummary = baseEval.imageSummaries[imageId];
      final candidateSummary = candidateEval.imageSummaries[imageId];
      final int baseTp = baseSummary?.tp ?? 0;
      final int baseFp = baseSummary?.fp ?? 0;
      final int baseFn = baseSummary?.fn ?? 0;
      final int candidateTp = candidateSummary?.tp ?? 0;
      final int candidateFp = candidateSummary?.fp ?? 0;
      final int candidateFn = candidateSummary?.fn ?? 0;
      final bool baseHasError = baseFp > 0 || baseFn > 0;
      final bool candidateHasError = candidateFp > 0 || candidateFn > 0;

      final ImageComparisonStatus status;
      if (baseHasError && !candidateHasError) {
        status = ImageComparisonStatus.fixed;
        fixedImageIds.add(imageId);
      } else if (!baseHasError && candidateHasError) {
        status = ImageComparisonStatus.broken;
        brokenImageIds.add(imageId);
      } else if (!baseHasError && !candidateHasError) {
        status = ImageComparisonStatus.unchangedCorrect;
        unchangedCorrectImageIds.add(imageId);
      } else {
        // Both have errors.
        final int baseErrors = baseFp + baseFn;
        final int candidateErrors = candidateFp + candidateFn;
        if (candidateErrors < baseErrors) {
          status = ImageComparisonStatus.improved;
          improvedImageIds.add(imageId);
        } else if (candidateErrors > baseErrors) {
          status = ImageComparisonStatus.regressed;
          regressedImageIds.add(imageId);
        } else {
          status = ImageComparisonStatus.unchangedWrong;
          unchangedWrongImageIds.add(imageId);
        }
      }

      final String fileName =
          dataset.imagesById[imageId]?.fileName ?? '$imageId';
      imageSummaries.add(
        ImageComparisonSummary(
          imageId: imageId,
          fileName: fileName,
          baseTp: baseTp,
          baseFp: baseFp,
          baseFn: baseFn,
          candidateTp: candidateTp,
          candidateFp: candidateFp,
          candidateFn: candidateFn,
          deltaTp: candidateTp - baseTp,
          deltaFp: candidateFp - baseFp,
          deltaFn: candidateFn - baseFn,
          baseHasError: baseHasError,
          candidateHasError: candidateHasError,
          status: status,
        ),
      );
    }

    // Overall diff.
    final MetricsDiff overallDiff = _buildOverallDiff(baseEval, candidateEval);

    // Per-class diffs.
    final List<ClassMetricsDiff> perClassDiffs =
        _buildPerClassDiffs(dataset, baseEval, candidateEval);

    // Sort per-class diffs: worst deltaF1 ascending, then worst deltaRecall
    // ascending, then categoryName.
    perClassDiffs.sort((ClassMetricsDiff a, ClassMetricsDiff b) {
      final int byF1 = a.diff.deltaF1.compareTo(b.diff.deltaF1);
      if (byF1 != 0) {
        return byF1;
      }
      final int byRecall = a.diff.deltaRecall.compareTo(b.diff.deltaRecall);
      if (byRecall != 0) {
        return byRecall;
      }
      return a.categoryName.compareTo(b.categoryName);
    });

    return ModelComparisonResult(
      baseRunId: baseRun.id,
      candidateRunId: candidateRun.id,
      overallDiff: overallDiff,
      perClassDiffs: perClassDiffs,
      imageSummaries: imageSummaries,
      fixedImageIds: fixedImageIds,
      brokenImageIds: brokenImageIds,
      improvedImageIds: improvedImageIds,
      regressedImageIds: regressedImageIds,
      unchangedCorrectImageIds: unchangedCorrectImageIds,
      unchangedWrongImageIds: unchangedWrongImageIds,
    );
  }

  MetricsDiff _buildOverallDiff(EvalResult baseEval, EvalResult candidateEval) {
    final int baseTp = baseEval.overall.totalTp;
    final int baseFp = baseEval.overall.totalFp;
    final int baseFn = baseEval.overall.totalFn;
    final int candidateTp = candidateEval.overall.totalTp;
    final int candidateFp = candidateEval.overall.totalFp;
    final int candidateFn = candidateEval.overall.totalFn;

    final double basePrecision = _safeRatio(baseTp, baseTp + baseFp);
    final double baseRecall = _safeRatio(baseTp, baseTp + baseFn);
    final double baseF1 = _f1(basePrecision, baseRecall);
    final double candidatePrecision =
        _safeRatio(candidateTp, candidateTp + candidateFp);
    final double candidateRecall =
        _safeRatio(candidateTp, candidateTp + candidateFn);
    final double candidateF1 = _f1(candidatePrecision, candidateRecall);

    final int baseImagesWithErrors = baseEval.overall.imagesWithAnyError;
    final int candidateImagesWithErrors =
        candidateEval.overall.imagesWithAnyError;

    return MetricsDiff(
      basePrecision: basePrecision,
      candidatePrecision: candidatePrecision,
      deltaPrecision: candidatePrecision - basePrecision,
      baseRecall: baseRecall,
      candidateRecall: candidateRecall,
      deltaRecall: candidateRecall - baseRecall,
      baseF1: baseF1,
      candidateF1: candidateF1,
      deltaF1: candidateF1 - baseF1,
      baseTp: baseTp,
      candidateTp: candidateTp,
      deltaTp: candidateTp - baseTp,
      baseFp: baseFp,
      candidateFp: candidateFp,
      deltaFp: candidateFp - baseFp,
      baseFn: baseFn,
      candidateFn: candidateFn,
      deltaFn: candidateFn - baseFn,
      baseImagesWithErrors: baseImagesWithErrors,
      candidateImagesWithErrors: candidateImagesWithErrors,
      deltaImagesWithErrors: candidateImagesWithErrors - baseImagesWithErrors,
    );
  }

  List<ClassMetricsDiff> _buildPerClassDiffs(
    CocoDataset dataset,
    EvalResult baseEval,
    EvalResult candidateEval,
  ) {
    final Set<int> allCategoryIds = {
      ...baseEval.perClassStats.keys,
      ...candidateEval.perClassStats.keys,
    };

    final List<ClassMetricsDiff> diffs = [];
    for (final int categoryId in allCategoryIds) {
      final ClassStats? baseStats = baseEval.perClassStats[categoryId];
      final ClassStats? candidateStats =
          candidateEval.perClassStats[categoryId];

      final int baseTp = baseStats?.tp ?? 0;
      final int baseFp = baseStats?.fp ?? 0;
      final int baseFn = baseStats?.fn ?? 0;
      final int candidateTp = candidateStats?.tp ?? 0;
      final int candidateFp = candidateStats?.fp ?? 0;
      final int candidateFn = candidateStats?.fn ?? 0;

      final double basePrecision =
          baseStats?.precision ?? _safeRatio(baseTp, baseTp + baseFp);
      final double baseRecall =
          baseStats?.recall ?? _safeRatio(baseTp, baseTp + baseFn);
      final double baseF1 = baseStats?.f1 ?? _f1(basePrecision, baseRecall);
      final double candidatePrecision = candidateStats?.precision ??
          _safeRatio(candidateTp, candidateTp + candidateFp);
      final double candidateRecall = candidateStats?.recall ??
          _safeRatio(candidateTp, candidateTp + candidateFn);
      final double candidateF1 =
          candidateStats?.f1 ?? _f1(candidatePrecision, candidateRecall);

      final String categoryName = dataset.categoriesById[categoryId]?.name ??
          baseStats?.categoryName ??
          candidateStats?.categoryName ??
          '$categoryId';

      // For per-class imagesWithErrors we don't have per-class data readily,
      // so use 0 for those fields.
      diffs.add(
        ClassMetricsDiff(
          categoryId: categoryId,
          categoryName: categoryName,
          diff: MetricsDiff(
            basePrecision: basePrecision,
            candidatePrecision: candidatePrecision,
            deltaPrecision: candidatePrecision - basePrecision,
            baseRecall: baseRecall,
            candidateRecall: candidateRecall,
            deltaRecall: candidateRecall - baseRecall,
            baseF1: baseF1,
            candidateF1: candidateF1,
            deltaF1: candidateF1 - baseF1,
            baseTp: baseTp,
            candidateTp: candidateTp,
            deltaTp: candidateTp - baseTp,
            baseFp: baseFp,
            candidateFp: candidateFp,
            deltaFp: candidateFp - baseFp,
            baseFn: baseFn,
            candidateFn: candidateFn,
            deltaFn: candidateFn - baseFn,
            baseImagesWithErrors: 0,
            candidateImagesWithErrors: 0,
            deltaImagesWithErrors: 0,
          ),
        ),
      );
    }
    return diffs;
  }
}

double _safeRatio(int numerator, int denominator) {
  return denominator == 0 ? 0 : numerator / denominator;
}

double _f1(double precision, double recall) {
  return precision + recall == 0
      ? 0
      : 2 * precision * recall / (precision + recall);
}
