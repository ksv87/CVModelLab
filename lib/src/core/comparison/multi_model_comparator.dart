import '../ap_eval/ap_eval_models.dart';
import '../eval/class_stats.dart';
import '../eval/small_object_stats.dart';
import '../model/coco_dataset.dart';
import '../model/detection_match.dart';
import '../model/eval_config.dart';
import '../model/eval_result.dart';
import '../model/model_run.dart';
import 'comparison_models.dart';
import 'model_comparator.dart';
import 'multi_model_comparison_models.dart';

/// Error spread (max error count − min error count) at or above which an image
/// is flagged as [ImageDisagreementType.largeErrorSpread].
const int kLargeErrorSpreadThreshold = 3;

/// Prediction-count spread (max − min predicted objects across models) at or
/// above which an image is flagged as
/// [ImageDisagreementType.predictionCountDisagreement].
const int kPredictionCountSpreadThreshold = 3;

/// Score at or above which a false positive is considered high-confidence.
const double kHighConfidenceFpThreshold = 0.5;

/// Compares three or more model runs over the same dataset and produces a
/// [MultiModelComparisonResult] (leaderboard, per-class ranking, image
/// disagreement, pairwise regression matrix and consensus summary).
///
/// This service never re-runs detection matching: it consumes the already
/// computed [EvalResult]s and optional [ApEvalResult]s and only aggregates and
/// sorts them. All output is deterministic for stable inputs.
class MultiModelComparator {
  const MultiModelComparator({this.pairwiseComparator = const ModelComparator()});

  final ModelComparator pairwiseComparator;

  MultiModelComparisonResult compare({
    required CocoDataset dataset,
    required List<ModelRun> modelRuns,
    required Map<String, EvalResult> evalResultsByRunId,
    required EvalConfig evalConfig,
    Map<String, ApEvalResult>? apResultsByRunId,
    MultiModelComparisonConfig config =
        const MultiModelComparisonConfig.defaults(),
    DateTime? generatedAt,
  }) {
    final DateTime timestamp = generatedAt ?? DateTime.now();

    // Keep only runs that have an EvalResult, preserving input order.
    final List<ModelRun> runs = [
      for (final ModelRun run in modelRuns)
        if (evalResultsByRunId.containsKey(run.id)) run,
    ];

    if (runs.length < 2) {
      return MultiModelComparisonResult.empty(
        config: config,
        generatedAt: timestamp,
      );
    }

    final Map<String, ApEvalResult> apByRun =
        (config.includeApMetrics ? apResultsByRunId : null) ?? const {};

    // Group matches by image for each run once (used by disagreement analysis).
    final Map<String, Map<int, List<DetectionMatch>>> matchesByRunImage = {
      for (final ModelRun run in runs)
        run.id: _groupMatchesByImage(evalResultsByRunId[run.id]!.matches),
    };

    final List<ModelRunLeaderboardEntry> leaderboard = _buildLeaderboard(
      runs: runs,
      evalResultsByRunId: evalResultsByRunId,
      apByRun: apByRun,
      config: config,
    );

    final List<ClassModelRanking> perClassRankings = config.includePerClassRanking
        ? _buildPerClassRankings(
            dataset: dataset,
            runs: runs,
            evalResultsByRunId: evalResultsByRunId,
            apByRun: apByRun,
          )
        : const [];

    final List<ImageModelDisagreement> imageDisagreements =
        config.includeImageDisagreement
            ? _buildImageDisagreements(
                dataset: dataset,
                runs: runs,
                matchesByRunImage: matchesByRunImage,
              )
            : const [];

    final List<PairwiseRegressionSummary> regressionMatrix =
        _buildRegressionMatrix(
      dataset: dataset,
      runs: runs,
      evalResultsByRunId: evalResultsByRunId,
      apByRun: apByRun,
      evalConfig: evalConfig,
    );

    final List<ModelConsensusSummary> consensus = _buildConsensus(
      dataset: dataset,
      runs: runs,
      matchesByRunImage: matchesByRunImage,
    );

    return MultiModelComparisonResult(
      leaderboard: leaderboard,
      perClassRankings: perClassRankings,
      imageDisagreements: imageDisagreements,
      pairwiseRegressionMatrix: regressionMatrix,
      consensusSummary: consensus,
      config: config,
      generatedAt: timestamp,
    );
  }

  // ── Leaderboard ───────────────────────────────────────────────────────────

  List<ModelRunLeaderboardEntry> _buildLeaderboard({
    required List<ModelRun> runs,
    required Map<String, EvalResult> evalResultsByRunId,
    required Map<String, ApEvalResult> apByRun,
    required MultiModelComparisonConfig config,
  }) {
    final List<ModelRunLeaderboardEntry> rows = [];
    for (final ModelRun run in runs) {
      final EvalResult eval = evalResultsByRunId[run.id]!;
      final OverallStats overall = eval.overall;
      final ApEvalResult? ap = apByRun[run.id];
      final ({double? small, double? medium, double? large}) sizeRecall =
          _sizeRecall(eval.smallObjectStats);

      rows.add(
        ModelRunLeaderboardEntry(
          modelRunId: run.id,
          modelRunName: run.name,
          totalTp: overall.totalTp,
          totalFp: overall.totalFp,
          totalFn: overall.totalFn,
          imagesWithErrors: overall.imagesWithAnyError,
          precision: overall.microPrecision,
          recall: overall.microRecall,
          f1: overall.microF1,
          ap: ap?.ap,
          ap50: ap?.ap50,
          ap75: ap?.ap75,
          apSmall: ap?.apSmall,
          apMedium: ap?.apMedium,
          apLarge: ap?.apLarge,
          smallObjectRecall:
              config.includeSmallObjectMetrics ? sizeRecall.small : null,
          mediumObjectRecall:
              config.includeSmallObjectMetrics ? sizeRecall.medium : null,
          largeObjectRecall:
              config.includeSmallObjectMetrics ? sizeRecall.large : null,
          rank: 0,
          score: 0,
        ),
      );
    }

    rows.sort((a, b) => _compareForRanking(a, b, config));

    // Assign ranks and the primary-metric score.
    final List<ModelRunLeaderboardEntry> ranked = [];
    for (int i = 0; i < rows.length; i++) {
      final ModelRunLeaderboardEntry e = rows[i];
      ranked.add(
        ModelRunLeaderboardEntry(
          modelRunId: e.modelRunId,
          modelRunName: e.modelRunName,
          totalTp: e.totalTp,
          totalFp: e.totalFp,
          totalFn: e.totalFn,
          imagesWithErrors: e.imagesWithErrors,
          precision: e.precision,
          recall: e.recall,
          f1: e.f1,
          ap: e.ap,
          ap50: e.ap50,
          ap75: e.ap75,
          apSmall: e.apSmall,
          apMedium: e.apMedium,
          apLarge: e.apLarge,
          smallObjectRecall: e.smallObjectRecall,
          mediumObjectRecall: e.mediumObjectRecall,
          largeObjectRecall: e.largeObjectRecall,
          rank: i + 1,
          score: _metricValue(e, config.primaryMetric) ?? 0,
        ),
      );
    }
    return ranked;
  }

  int _compareForRanking(
    ModelRunLeaderboardEntry a,
    ModelRunLeaderboardEntry b,
    MultiModelComparisonConfig config,
  ) {
    final int primary = _compareByMetric(a, b, config.primaryMetric);
    final int directed =
        config.sortDirection == SortDirection.descending ? primary : -primary;
    if (directed != 0) {
      return directed;
    }
    // Fixed tie-breakers (independent of sort direction).
    final int byRecall = b.recall.compareTo(a.recall);
    if (byRecall != 0) return byRecall;
    final int byPrecision = b.precision.compareTo(a.precision);
    if (byPrecision != 0) return byPrecision;
    final int byFp = a.totalFp.compareTo(b.totalFp);
    if (byFp != 0) return byFp;
    final int byFn = a.totalFn.compareTo(b.totalFn);
    if (byFn != 0) return byFn;
    final int byName = a.modelRunName.compareTo(b.modelRunName);
    if (byName != 0) return byName;
    return a.modelRunId.compareTo(b.modelRunId);
  }

  /// Returns a negative value when [a] ranks ahead of [b] for [metric] in the
  /// "best first" sense (higher-is-better metrics put larger values first;
  /// lower-is-better metrics put smaller values first). Missing values rank
  /// last.
  int _compareByMetric(
    ModelRunLeaderboardEntry a,
    ModelRunLeaderboardEntry b,
    MultiModelRankingMetric metric,
  ) {
    final double? va = _metricValue(a, metric);
    final double? vb = _metricValue(b, metric);
    if (va == null && vb == null) return 0;
    if (va == null) return 1; // a after b
    if (vb == null) return -1; // a before b
    return isHigherBetter(metric) ? vb.compareTo(va) : va.compareTo(vb);
  }

  double? _metricValue(
    ModelRunLeaderboardEntry e,
    MultiModelRankingMetric metric,
  ) {
    switch (metric) {
      case MultiModelRankingMetric.ap:
        return e.ap;
      case MultiModelRankingMetric.ap50:
        return e.ap50;
      case MultiModelRankingMetric.ap75:
        return e.ap75;
      case MultiModelRankingMetric.precision:
        return e.precision;
      case MultiModelRankingMetric.recall:
        return e.recall;
      case MultiModelRankingMetric.f1:
        return e.f1;
      case MultiModelRankingMetric.tp:
        return e.totalTp.toDouble();
      case MultiModelRankingMetric.fp:
        return e.totalFp.toDouble();
      case MultiModelRankingMetric.fn:
        return e.totalFn.toDouble();
      case MultiModelRankingMetric.imagesWithErrors:
        return e.imagesWithErrors.toDouble();
      case MultiModelRankingMetric.smallObjectRecall:
        return e.smallObjectRecall;
    }
  }

  ({double? small, double? medium, double? large}) _sizeRecall(
    Map<int, Map<ObjectSizeBucket, SmallObjectClassStats>> stats,
  ) {
    int smallGt = 0, smallTp = 0;
    int mediumGt = 0, mediumTp = 0;
    int largeGt = 0, largeTp = 0;
    for (final Map<ObjectSizeBucket, SmallObjectClassStats> buckets
        in stats.values) {
      final SmallObjectClassStats? s = buckets[ObjectSizeBucket.small];
      final SmallObjectClassStats? m = buckets[ObjectSizeBucket.medium];
      final SmallObjectClassStats? l = buckets[ObjectSizeBucket.large];
      if (s != null) {
        smallGt += s.gtCount;
        smallTp += s.tp;
      }
      if (m != null) {
        mediumGt += m.gtCount;
        mediumTp += m.tp;
      }
      if (l != null) {
        largeGt += l.gtCount;
        largeTp += l.tp;
      }
    }
    return (
      small: smallGt == 0 ? null : smallTp / smallGt,
      medium: mediumGt == 0 ? null : mediumTp / mediumGt,
      large: largeGt == 0 ? null : largeTp / largeGt,
    );
  }

  // ── Per-class ranking ───────────────────────────────────────────────────

  List<ClassModelRanking> _buildPerClassRankings({
    required CocoDataset dataset,
    required List<ModelRun> runs,
    required Map<String, EvalResult> evalResultsByRunId,
    required Map<String, ApEvalResult> apByRun,
  }) {
    final Set<int> categoryIds = <int>{};
    for (final ModelRun run in runs) {
      categoryIds.addAll(evalResultsByRunId[run.id]!.perClassStats.keys);
    }

    final List<ClassModelRanking> rankings = [];
    for (final int categoryId in categoryIds) {
      final List<ClassModelMetricEntry> entries = [];
      for (final ModelRun run in runs) {
        final ClassStats? stats =
            evalResultsByRunId[run.id]!.perClassStats[categoryId];
        if (stats == null) {
          continue;
        }
        final ClassApMetric? ap = _classAp(apByRun[run.id], categoryId);
        entries.add(
          ClassModelMetricEntry(
            modelRunId: run.id,
            modelRunName: run.name,
            gtCount: stats.gtCount,
            predCount: stats.predCount,
            tp: stats.tp,
            fp: stats.fp,
            fn: stats.fn,
            precision: stats.precision,
            recall: stats.recall,
            f1: stats.f1,
            ap: ap?.ap,
            ap50: ap?.ap50,
            ap75: ap?.ap75,
            ar: ap?.ar,
          ),
        );
      }
      if (entries.isEmpty) {
        continue;
      }

      final String categoryName =
          dataset.categoriesById[categoryId]?.name ?? '$categoryId';

      // Best/worst by F1 (best = max, worst = min). Deterministic because
      // entries follow the input run order and ties keep the first occurrence.
      ClassModelMetricEntry best = entries.first;
      ClassModelMetricEntry worst = entries.first;
      for (final ClassModelMetricEntry e in entries) {
        if (e.f1 > best.f1) best = e;
        if (e.f1 < worst.f1) worst = e;
      }

      final List<ClassModelMetricEntry> withAp =
          entries.where((e) => e.ap != null).toList();
      double? bestAp;
      double? worstAp;
      if (withAp.isNotEmpty) {
        bestAp = withAp.first.ap;
        worstAp = withAp.first.ap;
        for (final ClassModelMetricEntry e in withAp) {
          if (e.ap! > bestAp!) bestAp = e.ap;
          if (e.ap! < worstAp!) worstAp = e.ap;
        }
      }

      rankings.add(
        ClassModelRanking(
          categoryId: categoryId,
          categoryName: categoryName,
          bestModelRunId: best.modelRunId,
          worstModelRunId: worst.modelRunId,
          bestF1: best.f1,
          worstF1: worst.f1,
          bestRecall: _maxOf(entries, (e) => e.recall),
          worstRecall: _minOf(entries, (e) => e.recall),
          bestPrecision: _maxOf(entries, (e) => e.precision),
          worstPrecision: _minOf(entries, (e) => e.precision),
          bestAp: bestAp,
          worstAp: worstAp,
          entries: entries,
        ),
      );
    }

    rankings.sort((a, b) {
      final int byF1Spread = b.f1Spread.compareTo(a.f1Spread);
      if (byF1Spread != 0) return byF1Spread;
      final int byRecallSpread = b.recallSpread.compareTo(a.recallSpread);
      if (byRecallSpread != 0) return byRecallSpread;
      final int byName = a.categoryName.compareTo(b.categoryName);
      if (byName != 0) return byName;
      return a.categoryId.compareTo(b.categoryId);
    });
    return rankings;
  }

  ClassApMetric? _classAp(ApEvalResult? ap, int categoryId) {
    if (ap == null) return null;
    for (final ClassApMetric c in ap.perClass) {
      if (c.categoryId == categoryId) return c;
    }
    return null;
  }

  double _maxOf(
    List<ClassModelMetricEntry> entries,
    double Function(ClassModelMetricEntry) get,
  ) {
    double m = get(entries.first);
    for (final e in entries) {
      final double v = get(e);
      if (v > m) m = v;
    }
    return m;
  }

  double _minOf(
    List<ClassModelMetricEntry> entries,
    double Function(ClassModelMetricEntry) get,
  ) {
    double m = get(entries.first);
    for (final e in entries) {
      final double v = get(e);
      if (v < m) m = v;
    }
    return m;
  }

  // ── Image disagreement ────────────────────────────────────────────────────

  List<ImageModelDisagreement> _buildImageDisagreements({
    required CocoDataset dataset,
    required List<ModelRun> runs,
    required Map<String, Map<int, List<DetectionMatch>>> matchesByRunImage,
  }) {
    final List<int> imageIds = dataset.imagesById.keys.toList()..sort();
    final List<ImageModelDisagreement> disagreements = [];

    for (final int imageId in imageIds) {
      final List<ImageModelStatus> statuses = [
        for (final ModelRun run in runs)
          _imageStatus(
            run: run,
            matches: matchesByRunImage[run.id]![imageId] ?? const [],
            dataset: dataset,
          ),
      ];

      final int correctCount =
          statuses.where((s) => !s.hasError).length;
      final int wrongCount = statuses.length - correctCount;
      final List<int> errorCounts =
          statuses.map((s) => s.errorCount).toList();
      final int bestError =
          errorCounts.reduce((a, b) => a < b ? a : b);
      final int worstError =
          errorCounts.reduce((a, b) => a > b ? a : b);
      final int errorSpread = worstError - bestError;

      final List<int> predCounts =
          statuses.map((s) => s.tp + s.fp).toList();
      final int predSpread =
          predCounts.reduce((a, b) => a > b ? a : b) -
              predCounts.reduce((a, b) => a < b ? a : b);

      final bool anyConfusion = statuses.any((s) => s.hasClassConfusion);
      final bool allConfusion = statuses.every((s) => s.hasClassConfusion);
      final bool classDisagreement = anyConfusion && !allConfusion;

      final ImageDisagreementType type = _disagreementType(
        correctCount: correctCount,
        wrongCount: wrongCount,
        errorSpread: errorSpread,
        predSpread: predSpread,
        classDisagreement: classDisagreement,
      );

      disagreements.add(
        ImageModelDisagreement(
          imageId: imageId,
          fileName: dataset.imagesById[imageId]?.fileName ?? '$imageId',
          type: type,
          modelsCorrectCount: correctCount,
          modelsWrongCount: wrongCount,
          bestErrorCount: bestError,
          worstErrorCount: worstError,
          errorSpread: errorSpread,
          modelStatuses: statuses,
        ),
      );
    }

    disagreements.sort((a, b) {
      final int bySeverity =
          _typeSeverity(a.type).compareTo(_typeSeverity(b.type));
      if (bySeverity != 0) return bySeverity;
      final int bySpread = b.errorSpread.compareTo(a.errorSpread);
      if (bySpread != 0) return bySpread;
      return a.imageId.compareTo(b.imageId);
    });
    return disagreements;
  }

  ImageModelStatus _imageStatus({
    required ModelRun run,
    required List<DetectionMatch> matches,
    required CocoDataset dataset,
  }) {
    int tp = 0, fp = 0, fn = 0;
    bool hasClassConfusion = false;
    bool hasHighConfidenceFp = false;
    bool hasMissedSmallObject = false;
    double? maxFpScore;
    double? minTpIou;

    for (final DetectionMatch m in matches) {
      switch (m.type) {
        case DetectionMatchType.truePositive:
          tp += 1;
          final double? iou = m.iou;
          if (iou != null && (minTpIou == null || iou < minTpIou)) {
            minTpIou = iou;
          }
        case DetectionMatchType.falsePositive:
          fp += 1;
          final double? score = m.prediction?.score;
          if (score != null) {
            if (maxFpScore == null || score > maxFpScore) {
              maxFpScore = score;
            }
            if (score >= kHighConfidenceFpThreshold) {
              hasHighConfidenceFp = true;
            }
          }
        case DetectionMatchType.falseNegative:
          fn += 1;
          final gt = m.groundTruth;
          if (gt != null &&
              smallObjectBucket(gt.effectiveArea) == ObjectSizeBucket.small) {
            hasMissedSmallObject = true;
          }
        case DetectionMatchType.ignored:
          break;
      }
      if (m.reason == DetectionMatchReason.wrongClass) {
        hasClassConfusion = true;
      }
    }

    final int errorCount = fp + fn;
    return ImageModelStatus(
      modelRunId: run.id,
      modelRunName: run.name,
      tp: tp,
      fp: fp,
      fn: fn,
      errorCount: errorCount,
      hasError: errorCount > 0,
      hasClassConfusion: hasClassConfusion,
      hasHighConfidenceFp: hasHighConfidenceFp,
      hasMissedSmallObject: hasMissedSmallObject,
      maxFpScore: maxFpScore,
      minTpIou: minTpIou,
    );
  }

  ImageDisagreementType _disagreementType({
    required int correctCount,
    required int wrongCount,
    required int errorSpread,
    required int predSpread,
    required bool classDisagreement,
  }) {
    if (wrongCount == 0) {
      return ImageDisagreementType.allCorrect;
    }
    if (correctCount == 0) {
      // Every model is wrong: surface very uneven cases as a large spread.
      if (errorSpread >= kLargeErrorSpreadThreshold) {
        return ImageDisagreementType.largeErrorSpread;
      }
      return ImageDisagreementType.allWrong;
    }
    // Mixed: at least one correct and at least one wrong.
    if (correctCount == 1) {
      return ImageDisagreementType.onlyOneModelCorrect;
    }
    if (wrongCount == 1) {
      return ImageDisagreementType.onlyOneModelWrong;
    }
    if (errorSpread >= kLargeErrorSpreadThreshold) {
      return ImageDisagreementType.largeErrorSpread;
    }
    if (classDisagreement) {
      return ImageDisagreementType.classDisagreement;
    }
    if (predSpread >= kPredictionCountSpreadThreshold) {
      return ImageDisagreementType.predictionCountDisagreement;
    }
    return ImageDisagreementType.someModelsWrong;
  }

  /// Severity order used to sort disagreements (lower sorts first / more
  /// severe).
  int _typeSeverity(ImageDisagreementType type) {
    switch (type) {
      case ImageDisagreementType.onlyOneModelCorrect:
        return 0;
      case ImageDisagreementType.onlyOneModelWrong:
        return 1;
      case ImageDisagreementType.largeErrorSpread:
        return 2;
      case ImageDisagreementType.classDisagreement:
        return 3;
      case ImageDisagreementType.predictionCountDisagreement:
        return 4;
      case ImageDisagreementType.someModelsWrong:
        return 5;
      case ImageDisagreementType.allWrong:
        return 6;
      case ImageDisagreementType.allCorrect:
        return 7;
    }
  }

  // ── Pairwise regression matrix ──────────────────────────────────────────

  List<PairwiseRegressionSummary> _buildRegressionMatrix({
    required CocoDataset dataset,
    required List<ModelRun> runs,
    required Map<String, EvalResult> evalResultsByRunId,
    required Map<String, ApEvalResult> apByRun,
    required EvalConfig evalConfig,
  }) {
    final List<PairwiseRegressionSummary> matrix = [];
    for (int i = 0; i < runs.length; i++) {
      for (int j = 0; j < runs.length; j++) {
        if (i == j) {
          continue; // diagonal is empty
        }
        final ModelRun base = runs[i];
        final ModelRun candidate = runs[j];
        final ModelComparisonResult cmp = pairwiseComparator.compare(
          dataset: dataset,
          baseRun: base,
          baseEval: evalResultsByRunId[base.id]!,
          candidateRun: candidate,
          candidateEval: evalResultsByRunId[candidate.id]!,
          evalConfig: evalConfig,
        );
        final double? baseAp = apByRun[base.id]?.ap;
        final double? candAp = apByRun[candidate.id]?.ap;
        matrix.add(
          PairwiseRegressionSummary(
            baseModelRunId: base.id,
            candidateModelRunId: candidate.id,
            fixedImages: cmp.fixedImageIds.length,
            brokenImages: cmp.brokenImageIds.length,
            improvedImages: cmp.improvedImageIds.length,
            regressedImages: cmp.regressedImageIds.length,
            deltaTp: cmp.overallDiff.deltaTp,
            deltaFp: cmp.overallDiff.deltaFp,
            deltaFn: cmp.overallDiff.deltaFn,
            deltaPrecision: cmp.overallDiff.deltaPrecision,
            deltaRecall: cmp.overallDiff.deltaRecall,
            deltaF1: cmp.overallDiff.deltaF1,
            deltaAp: (baseAp == null || candAp == null) ? null : candAp - baseAp,
          ),
        );
      }
    }
    return matrix;
  }

  // ── Consensus ─────────────────────────────────────────────────────────────

  List<ModelConsensusSummary> _buildConsensus({
    required CocoDataset dataset,
    required List<ModelRun> runs,
    required Map<String, Map<int, List<DetectionMatch>>> matchesByRunImage,
  }) {
    final List<int> imageIds = dataset.imagesById.keys.toList();
    final int modelCount = runs.length;
    int allCorrect = 0;
    int allWrong = 0;
    int someWrong = 0;
    int onlyOneCorrect = 0;
    int onlyOneWrong = 0;

    for (final int imageId in imageIds) {
      int correct = 0;
      for (final ModelRun run in runs) {
        final List<DetectionMatch> matches =
            matchesByRunImage[run.id]![imageId] ?? const [];
        final int fp = matches
            .where((m) => m.type == DetectionMatchType.falsePositive)
            .length;
        final int fn = matches
            .where((m) => m.type == DetectionMatchType.falseNegative)
            .length;
        if (fp + fn == 0) correct += 1;
      }
      final int wrong = modelCount - correct;
      if (wrong == 0) {
        allCorrect += 1;
      } else if (correct == 0) {
        allWrong += 1;
      } else {
        someWrong += 1;
      }
      if (correct == 1) onlyOneCorrect += 1;
      if (wrong == 1) onlyOneWrong += 1;
    }

    return [
      ModelConsensusSummary(
        totalImages: imageIds.length,
        allModelsCorrect: allCorrect,
        allModelsWrong: allWrong,
        someModelsWrong: someWrong,
        onlyOneModelCorrect: onlyOneCorrect,
        onlyOneModelWrong: onlyOneWrong,
      ),
    ];
  }

  Map<int, List<DetectionMatch>> _groupMatchesByImage(
    List<DetectionMatch> matches,
  ) {
    final Map<int, List<DetectionMatch>> grouped = {};
    for (final DetectionMatch m in matches) {
      grouped.putIfAbsent(m.imageId, () => []).add(m);
    }
    return grouped;
  }
}
