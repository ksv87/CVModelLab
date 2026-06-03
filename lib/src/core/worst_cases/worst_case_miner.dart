import '../comparison/comparison_models.dart';
import '../eval/iou.dart';
import '../eval/small_object_stats.dart';
import '../model/annotation.dart';
import '../model/coco_dataset.dart';
import '../model/detection_match.dart';
import '../model/eval_config.dart';
import '../model/eval_result.dart';
import '../model/model_run.dart';
import '../model/prediction.dart';
import 'worst_case_models.dart';

/// Ranks images by how useful they are to review, across several failure modes.
///
/// Pure Dart, fully testable: it reads an already-computed [EvalResult] and the
/// raw dataset / model run, and never touches the UI or platform layers.
class WorstCaseMiner {
  const WorstCaseMiner({this.limitPerCategory = 200});

  /// Cap on how many items each category retains. The UI applies its own
  /// top-N selector on top of this.
  final int limitPerCategory;

  WorstCasesResult mine({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required EvalResult evalResult,
    required EvalConfig evalConfig,
    ModelComparisonResult? comparison,
    double highConfidenceFpThreshold = 0.7,
    double lowIouTpThreshold = 0.55,
  }) {
    final Map<int, List<DetectionMatch>> matchesByImage = {};
    for (final DetectionMatch match in evalResult.matches) {
      (matchesByImage[match.imageId] ??= <DetectionMatch>[]).add(match);
    }

    final List<int> imageIds = dataset.imagesById.keys.toList()..sort();

    String fileNameFor(int imageId) =>
        dataset.imagesById[imageId]?.fileName ?? '$imageId';

    final List<WorstCaseItem> mostErrors = [];
    final List<WorstCaseItem> mostFp = [];
    final List<WorstCaseItem> mostFn = [];
    final List<WorstCaseItem> highConfFp = [];
    final List<WorstCaseItem> lowIouTp = [];
    final List<WorstCaseItem> classConfusions = [];
    final List<WorstCaseItem> smallMissed = [];
    final List<WorstCaseItem> noGtWithPred = [];
    final List<WorstCaseItem> gtNoPred = [];

    for (final int imageId in imageIds) {
      final String fileName = fileNameFor(imageId);
      final ImageEvalSummary? summary = evalResult.imageSummaries[imageId];
      final int tp = summary?.tp ?? 0;
      final int fp = summary?.fp ?? 0;
      final int fn = summary?.fn ?? 0;
      final List<DetectionMatch> matches =
          matchesByImage[imageId] ?? const <DetectionMatch>[];

      final int gtCount = (dataset.annotationsByImageId[imageId] ??
              const <GroundTruthAnnotation>[])
          .where(
            (GroundTruthAnnotation a) => !(evalConfig.ignoreCrowd && a.isCrowd),
          )
          .length;
      final int predCount = (modelRun.predictionsByImageId[imageId] ??
              const <Prediction>[])
          .where((Prediction p) => p.score >= evalConfig.confidenceThreshold)
          .length;

      if (fp + fn > 0) {
        mostErrors.add(
          WorstCaseItem(
            imageId: imageId,
            fileName: fileName,
            category: 'most_errors',
            title: 'Most errors',
            reason: '$fp FP + $fn FN',
            tp: tp,
            fp: fp,
            fn: fn,
            severityScore: (fp + fn).toDouble(),
          ),
        );
      }
      if (fp > 0) {
        mostFp.add(
          WorstCaseItem(
            imageId: imageId,
            fileName: fileName,
            category: 'most_fp',
            title: 'Most false positives',
            reason: '$fp false positives',
            tp: tp,
            fp: fp,
            fn: fn,
            severityScore: fp.toDouble(),
          ),
        );
      }
      if (fn > 0) {
        mostFn.add(
          WorstCaseItem(
            imageId: imageId,
            fileName: fileName,
            category: 'most_fn',
            title: 'Most false negatives',
            reason: '$fn missed objects',
            tp: tp,
            fp: fp,
            fn: fn,
            severityScore: fn.toDouble(),
          ),
        );
      }

      // High confidence FP.
      double maxFpScore = -1;
      for (final DetectionMatch match in matches) {
        if (match.type == DetectionMatchType.falsePositive &&
            match.prediction != null &&
            match.prediction!.score > maxFpScore) {
          maxFpScore = match.prediction!.score;
        }
      }
      if (maxFpScore >= highConfidenceFpThreshold) {
        highConfFp.add(
          WorstCaseItem(
            imageId: imageId,
            fileName: fileName,
            category: 'high_conf_fp',
            title: 'High confidence FP',
            reason: 'FP at score ${maxFpScore.toStringAsFixed(2)}',
            tp: tp,
            fp: fp,
            fn: fn,
            score: maxFpScore,
            severityScore: maxFpScore,
          ),
        );
      }

      // Low IoU TP.
      double minTpIou = double.infinity;
      for (final DetectionMatch match in matches) {
        if (match.type == DetectionMatchType.truePositive &&
            match.iou != null &&
            match.iou! < minTpIou) {
          minTpIou = match.iou!;
        }
      }
      if (minTpIou.isFinite && minTpIou <= lowIouTpThreshold) {
        lowIouTp.add(
          WorstCaseItem(
            imageId: imageId,
            fileName: fileName,
            category: 'low_iou_tp',
            title: 'Low IoU TP',
            reason: 'TP at IoU ${minTpIou.toStringAsFixed(2)}',
            tp: tp,
            fp: fp,
            fn: fn,
            iou: minTpIou,
            // Lower IoU is worse → invert so a higher severity sorts first.
            severityScore: 1 - minTpIou,
          ),
        );
      }

      // Class confusion count (class-agnostic cross-class overlaps).
      final int confusionCount = _classConfusionCount(
        dataset: dataset,
        modelRun: modelRun,
        imageId: imageId,
        config: evalConfig,
      );
      if (confusionCount > 0) {
        classConfusions.add(
          WorstCaseItem(
            imageId: imageId,
            fileName: fileName,
            category: 'class_confusion',
            title: 'Class confusion',
            reason: '$confusionCount confused object(s)',
            tp: tp,
            fp: fp,
            fn: fn,
            severityScore: confusionCount.toDouble(),
          ),
        );
      }

      // Small missed objects.
      int smallMissedCount = 0;
      for (final DetectionMatch match in matches) {
        if (match.type == DetectionMatchType.falseNegative &&
            match.groundTruth != null &&
            smallObjectBucket(match.groundTruth!.effectiveArea) ==
                ObjectSizeBucket.small) {
          smallMissedCount += 1;
        }
      }
      if (smallMissedCount > 0) {
        smallMissed.add(
          WorstCaseItem(
            imageId: imageId,
            fileName: fileName,
            category: 'small_missed',
            title: 'Small missed objects',
            reason: '$smallMissedCount small object(s) missed',
            tp: tp,
            fp: fp,
            fn: fn,
            severityScore: smallMissedCount.toDouble(),
          ),
        );
      }

      // No GT but predictions / GT but no predictions.
      if (gtCount == 0 && predCount > 0) {
        noGtWithPred.add(
          WorstCaseItem(
            imageId: imageId,
            fileName: fileName,
            category: 'no_gt_with_pred',
            title: 'No GT but predictions',
            reason: '$predCount prediction(s), no GT',
            tp: tp,
            fp: fp,
            fn: fn,
            severityScore: predCount.toDouble(),
          ),
        );
      }
      if (gtCount > 0 && predCount == 0) {
        gtNoPred.add(
          WorstCaseItem(
            imageId: imageId,
            fileName: fileName,
            category: 'gt_no_pred',
            title: 'GT but no predictions',
            reason: '$gtCount GT object(s), no predictions',
            tp: tp,
            fp: fp,
            fn: fn,
            severityScore: gtCount.toDouble(),
          ),
        );
      }
    }

    List<WorstCaseItem> finalize(List<WorstCaseItem> items) {
      items.sort((WorstCaseItem a, WorstCaseItem b) {
        final int bySeverity = b.severityScore.compareTo(a.severityScore);
        if (bySeverity != 0) {
          return bySeverity;
        }
        return a.imageId.compareTo(b.imageId);
      });
      if (items.length > limitPerCategory) {
        return items.sublist(0, limitPerCategory);
      }
      return items;
    }

    final WorstCasesResult base = WorstCasesResult(
      mostErrors: finalize(mostErrors),
      mostFalsePositives: finalize(mostFp),
      mostFalseNegatives: finalize(mostFn),
      highConfidenceFalsePositives: finalize(highConfFp),
      lowIouTruePositives: finalize(lowIouTp),
      classConfusions: finalize(classConfusions),
      smallMissedObjects: finalize(smallMissed),
      imagesWithoutGtButWithPredictions: finalize(noGtWithPred),
      imagesWithGtButNoPredictions: finalize(gtNoPred),
    );

    if (comparison == null) {
      return base;
    }

    return WorstCasesResult(
      mostErrors: base.mostErrors,
      mostFalsePositives: base.mostFalsePositives,
      mostFalseNegatives: base.mostFalseNegatives,
      highConfidenceFalsePositives: base.highConfidenceFalsePositives,
      lowIouTruePositives: base.lowIouTruePositives,
      classConfusions: base.classConfusions,
      smallMissedObjects: base.smallMissedObjects,
      imagesWithoutGtButWithPredictions: base.imagesWithoutGtButWithPredictions,
      imagesWithGtButNoPredictions: base.imagesWithGtButNoPredictions,
      fixedByCandidate: _comparisonItems(
        comparison.fixedImageIds,
        comparison,
        'fixed',
        'Fixed by candidate',
      ),
      brokenByCandidate: _comparisonItems(
        comparison.brokenImageIds,
        comparison,
        'broken',
        'Broken by candidate',
      ),
      improvedByCandidate: _comparisonItems(
        comparison.improvedImageIds,
        comparison,
        'improved',
        'Improved by candidate',
      ),
      regressedByCandidate: _comparisonItems(
        comparison.regressedImageIds,
        comparison,
        'regressed',
        'Regressed by candidate',
      ),
    );
  }

  List<WorstCaseItem> _comparisonItems(
    List<int> imageIds,
    ModelComparisonResult comparison,
    String category,
    String title,
  ) {
    final Map<int, ImageComparisonSummary> byId = {
      for (final ImageComparisonSummary s in comparison.imageSummaries)
        s.imageId: s,
    };
    final List<WorstCaseItem> items = [
      for (final int imageId in imageIds)
        if (byId[imageId] != null)
          _comparisonItem(byId[imageId]!, category, title),
    ];
    items.sort((WorstCaseItem a, WorstCaseItem b) {
      final int bySeverity = b.severityScore.compareTo(a.severityScore);
      if (bySeverity != 0) {
        return bySeverity;
      }
      return a.imageId.compareTo(b.imageId);
    });
    return items;
  }

  WorstCaseItem _comparisonItem(
    ImageComparisonSummary s,
    String category,
    String title,
  ) {
    final int errorDelta =
        (s.candidateFp + s.candidateFn) - (s.baseFp + s.baseFn);
    return WorstCaseItem(
      imageId: s.imageId,
      fileName: s.fileName,
      category: category,
      title: title,
      reason: 'base ${s.baseFp + s.baseFn} err → '
          'candidate ${s.candidateFp + s.candidateFn} err',
      tp: s.candidateTp,
      fp: s.candidateFp,
      fn: s.candidateFn,
      severityScore: errorDelta.abs().toDouble(),
    );
  }

  int _classConfusionCount({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required int imageId,
    required EvalConfig config,
  }) {
    final List<GroundTruthAnnotation> groundTruths = (dataset
                .annotationsByImageId[imageId] ??
            const <GroundTruthAnnotation>[])
        .where((GroundTruthAnnotation a) => !(config.ignoreCrowd && a.isCrowd))
        .toList();
    final List<Prediction> predictions =
        (modelRun.predictionsByImageId[imageId] ?? const <Prediction>[])
            .where((Prediction p) => p.score >= config.confidenceThreshold)
            .toList();
    int count = 0;
    for (final Prediction prediction in predictions) {
      for (final GroundTruthAnnotation gt in groundTruths) {
        if (prediction.categoryId == gt.categoryId) {
          continue;
        }
        if (calculateIoU(prediction.bbox, gt.bbox) >= config.iouThreshold) {
          count += 1;
          break;
        }
      }
    }
    return count;
  }
}
