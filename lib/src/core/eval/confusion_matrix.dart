import '../model/annotation.dart';
import '../model/coco_dataset.dart';
import '../model/eval_config.dart';
import '../model/model_run.dart';
import '../model/prediction.dart';
import 'iou.dart';

const String missedColumn = '__missed__';
const String backgroundFpRow = '__background_fp__';

class ConfusionMatrix {
  const ConfusionMatrix(this.counts);

  final Map<String, Map<String, int>> counts;

  int count(String row, String column) {
    return counts[row]?[column] ?? 0;
  }
}

class ConfusionMatrixBuilder {
  ConfusionMatrix build({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required EvalConfig config,
  }) {
    final Map<String, Map<String, int>> counts = {};
    void increment(String row, String column) {
      counts.putIfAbsent(row, () => {});
      counts[row]![column] = (counts[row]![column] ?? 0) + 1;
    }

    final Set<int> imageIds = {
      ...dataset.imagesById.keys,
      ...modelRun.predictionsByImageId.keys,
    };

    for (final int imageId in imageIds) {
      final List<GroundTruthAnnotation> groundTruths = (dataset
                  .annotationsByImageId[imageId] ??
              const <GroundTruthAnnotation>[])
          .where(
            (GroundTruthAnnotation gt) => !(config.ignoreCrowd && gt.isCrowd),
          )
          .toList();
      final List<Prediction> predictions = (modelRun
                  .predictionsByImageId[imageId] ??
              const <Prediction>[])
          .where((Prediction pred) => pred.score >= config.confidenceThreshold)
          .toList()
        ..sort(_comparePredictions);
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
        final String predName =
            dataset.categoriesById[prediction.categoryId]!.name;
        if (bestIndex != -1 && bestIou >= config.iouThreshold) {
          matchedGtIndexes.add(bestIndex);
          final String gtName =
              dataset.categoriesById[groundTruths[bestIndex].categoryId]!.name;
          increment(gtName, predName);
        } else {
          increment(backgroundFpRow, predName);
        }
      }

      for (var gtIndex = 0; gtIndex < groundTruths.length; gtIndex += 1) {
        if (!matchedGtIndexes.contains(gtIndex)) {
          final String gtName =
              dataset.categoriesById[groundTruths[gtIndex].categoryId]!.name;
          increment(gtName, missedColumn);
        }
      }
    }

    return ConfusionMatrix(counts);
  }
}

int _comparePredictions(Prediction a, Prediction b) {
  final int scoreCompare = b.score.compareTo(a.score);
  if (scoreCompare != 0) {
    return scoreCompare;
  }
  return a.categoryId.compareTo(b.categoryId);
}
