import '../model/annotation.dart';
import '../model/coco_dataset.dart';
import '../model/detection_match.dart';
import '../model/eval_config.dart';
import '../model/model_run.dart';
import '../model/prediction.dart';
import 'iou.dart';

class DetectionMatcher {
  const DetectionMatcher();

  List<DetectionMatch> match({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required EvalConfig config,
  }) {
    if (!config.classAwareMatching) {
      return _matchClassAgnostic(
        dataset: dataset,
        modelRun: modelRun,
        config: config,
      );
    }

    final List<DetectionMatch> matches = [];
    for (final int imageId in _allImageIds(dataset, modelRun)) {
      final List<GroundTruthAnnotation> groundTruths = _filteredGroundTruths(
        dataset.annotationsByImageId[imageId] ??
            const <GroundTruthAnnotation>[],
        config,
        matches,
      );
      final List<Prediction> predictions = _filteredPredictions(
        modelRun.predictionsByImageId[imageId] ?? const <Prediction>[],
        config,
      );

      final Set<int> categoryIds = {
        ...groundTruths.map((GroundTruthAnnotation gt) => gt.categoryId),
        ...predictions.map((Prediction pred) => pred.categoryId),
      };

      for (final int categoryId in categoryIds.toList()..sort()) {
        matches.addAll(
          _matchCategory(
            imageId: imageId,
            categoryId: categoryId,
            groundTruths: groundTruths
                .where(
                  (GroundTruthAnnotation gt) => gt.categoryId == categoryId,
                )
                .toList(),
            predictions: predictions
                .where((Prediction pred) => pred.categoryId == categoryId)
                .toList(),
            config: config,
          ),
        );
      }
    }
    return matches;
  }

  List<DetectionMatch> _matchCategory({
    required int imageId,
    required int categoryId,
    required List<GroundTruthAnnotation> groundTruths,
    required List<Prediction> predictions,
    required EvalConfig config,
  }) {
    final List<DetectionMatch> matches = [];
    final Set<int> matchedGtIndexes = {};
    final List<Prediction> sortedPredictions = [...predictions]
      ..sort(_comparePredictions);

    for (final Prediction prediction in sortedPredictions) {
      var bestUnmatchedIndex = -1;
      var bestUnmatchedIou = 0.0;
      var bestAnyMatched = false;
      var bestAnyIou = 0.0;

      for (var gtIndex = 0; gtIndex < groundTruths.length; gtIndex += 1) {
        final double iou =
            calculateIoU(prediction.bbox, groundTruths[gtIndex].bbox);
        if (iou > bestAnyIou) {
          bestAnyIou = iou;
          bestAnyMatched = matchedGtIndexes.contains(gtIndex);
        }
        if (!matchedGtIndexes.contains(gtIndex) && iou > bestUnmatchedIou) {
          bestUnmatchedIou = iou;
          bestUnmatchedIndex = gtIndex;
        }
      }

      if (bestUnmatchedIndex != -1 && bestUnmatchedIou >= config.iouThreshold) {
        matchedGtIndexes.add(bestUnmatchedIndex);
        matches.add(
          DetectionMatch(
            type: DetectionMatchType.truePositive,
            imageId: imageId,
            categoryId: categoryId,
            groundTruth: groundTruths[bestUnmatchedIndex],
            prediction: prediction,
            iou: bestUnmatchedIou,
            reason: DetectionMatchReason.matched,
          ),
        );
        continue;
      }

      final String reason = bestAnyMatched && bestAnyIou >= config.iouThreshold
          ? DetectionMatchReason.duplicatePrediction
          : (groundTruths.isEmpty
              ? DetectionMatchReason.noMatchingGroundTruth
              : DetectionMatchReason.lowIou);
      matches.add(
        DetectionMatch(
          type: DetectionMatchType.falsePositive,
          imageId: imageId,
          categoryId: categoryId,
          prediction: prediction,
          iou: bestAnyIou == 0 ? null : bestAnyIou,
          reason: reason,
        ),
      );
    }

    for (var gtIndex = 0; gtIndex < groundTruths.length; gtIndex += 1) {
      if (!matchedGtIndexes.contains(gtIndex)) {
        matches.add(
          DetectionMatch(
            type: DetectionMatchType.falseNegative,
            imageId: imageId,
            categoryId: categoryId,
            groundTruth: groundTruths[gtIndex],
            reason: DetectionMatchReason.missedGroundTruth,
          ),
        );
      }
    }
    return matches;
  }

  List<DetectionMatch> _matchClassAgnostic({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required EvalConfig config,
  }) {
    final List<DetectionMatch> matches = [];
    for (final int imageId in _allImageIds(dataset, modelRun)) {
      final List<GroundTruthAnnotation> groundTruths = _filteredGroundTruths(
        dataset.annotationsByImageId[imageId] ??
            const <GroundTruthAnnotation>[],
        config,
        matches,
      );
      final List<Prediction> predictions = _filteredPredictions(
        modelRun.predictionsByImageId[imageId] ?? const <Prediction>[],
        config,
      )..sort(_comparePredictions);
      final Set<int> matchedGtIndexes = {};

      for (final Prediction prediction in predictions) {
        var bestIndex = -1;
        var bestIou = 0.0;
        for (var gtIndex = 0; gtIndex < groundTruths.length; gtIndex += 1) {
          if (matchedGtIndexes.contains(gtIndex)) {
            continue;
          }
          final double iou =
              calculateIoU(prediction.bbox, groundTruths[gtIndex].bbox);
          if (iou > bestIou) {
            bestIou = iou;
            bestIndex = gtIndex;
          }
        }
        if (bestIndex == -1 || bestIou < config.iouThreshold) {
          matches.add(
            DetectionMatch(
              type: DetectionMatchType.falsePositive,
              imageId: imageId,
              categoryId: prediction.categoryId,
              prediction: prediction,
              iou: bestIou == 0 ? null : bestIou,
              reason: DetectionMatchReason.noMatchingGroundTruth,
            ),
          );
          continue;
        }
        matchedGtIndexes.add(bestIndex);
        final GroundTruthAnnotation gt = groundTruths[bestIndex];
        matches.add(
          DetectionMatch(
            type: prediction.categoryId == gt.categoryId
                ? DetectionMatchType.truePositive
                : DetectionMatchType.falsePositive,
            imageId: imageId,
            categoryId: gt.categoryId,
            groundTruth: gt,
            prediction: prediction,
            iou: bestIou,
            reason: prediction.categoryId == gt.categoryId
                ? DetectionMatchReason.matched
                : DetectionMatchReason.wrongClass,
          ),
        );
      }

      for (var gtIndex = 0; gtIndex < groundTruths.length; gtIndex += 1) {
        if (!matchedGtIndexes.contains(gtIndex)) {
          matches.add(
            DetectionMatch(
              type: DetectionMatchType.falseNegative,
              imageId: imageId,
              categoryId: groundTruths[gtIndex].categoryId,
              groundTruth: groundTruths[gtIndex],
              reason: DetectionMatchReason.missedGroundTruth,
            ),
          );
        }
      }
    }
    return matches;
  }

  List<GroundTruthAnnotation> _filteredGroundTruths(
    List<GroundTruthAnnotation> groundTruths,
    EvalConfig config,
    List<DetectionMatch> matches,
  ) {
    if (!config.ignoreCrowd) {
      return [...groundTruths];
    }
    return groundTruths.where((GroundTruthAnnotation gt) {
      if (!gt.isCrowd) {
        return true;
      }
      matches.add(
        DetectionMatch(
          type: DetectionMatchType.ignored,
          imageId: gt.imageId,
          categoryId: gt.categoryId,
          groundTruth: gt,
          reason: DetectionMatchReason.ignoredCrowd,
        ),
      );
      return false;
    }).toList();
  }

  List<Prediction> _filteredPredictions(
    List<Prediction> predictions,
    EvalConfig config,
  ) {
    return predictions
        .where(
          (Prediction prediction) =>
              prediction.score >= config.confidenceThreshold,
        )
        .toList();
  }

  Set<int> _allImageIds(CocoDataset dataset, ModelRun modelRun) {
    return {
      ...dataset.imagesById.keys,
      ...modelRun.predictionsByImageId.keys,
    };
  }
}

int _comparePredictions(Prediction a, Prediction b) {
  final int scoreCompare = b.score.compareTo(a.score);
  if (scoreCompare != 0) {
    return scoreCompare;
  }
  final int categoryCompare = a.categoryId.compareTo(b.categoryId);
  if (categoryCompare != 0) {
    return categoryCompare;
  }
  final int xCompare = a.bbox.x.compareTo(b.bbox.x);
  if (xCompare != 0) {
    return xCompare;
  }
  final int yCompare = a.bbox.y.compareTo(b.bbox.y);
  if (yCompare != 0) {
    return yCompare;
  }
  final int widthCompare = a.bbox.width.compareTo(b.bbox.width);
  if (widthCompare != 0) {
    return widthCompare;
  }
  return a.bbox.height.compareTo(b.bbox.height);
}
