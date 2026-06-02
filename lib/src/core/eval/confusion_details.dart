import '../model/annotation.dart';
import '../model/bbox.dart';
import '../model/coco_dataset.dart';
import '../model/eval_config.dart';
import '../model/model_run.dart';
import '../model/prediction.dart';
import 'confusion_matrix.dart';
import 'iou.dart';

/// A single concrete object behind one confusion-matrix cell, used to populate
/// the clickable cell drill-down and `confusion_pairs.csv`.
class ConfusionCellExample {
  const ConfusionCellExample({
    required this.imageId,
    required this.fileName,
    required this.gtClass,
    required this.predClass,
    this.gtCategoryId,
    this.predCategoryId,
    this.score,
    this.iou,
    this.gtBbox,
    this.predBbox,
  });

  final int imageId;
  final String fileName;

  /// Row label: a category name or [backgroundFpRow].
  final String gtClass;

  /// Column label: a category name or [missedColumn].
  final String predClass;

  final int? gtCategoryId;
  final int? predCategoryId;
  final double? score;
  final double? iou;
  final BBox? gtBbox;
  final BBox? predBbox;
}

/// One (GT class → Pred class) cell aggregated, with example image ids.
class ConfusionPair {
  const ConfusionPair({
    required this.gtClass,
    required this.predClass,
    required this.count,
    required this.rowPercent,
    required this.exampleImageIds,
    this.gtCategoryId,
    this.predCategoryId,
  });

  final String gtClass;
  final String predClass;
  final int? gtCategoryId;
  final int? predCategoryId;
  final int count;
  final double rowPercent;
  final List<int> exampleImageIds;

  bool get isDiagonal =>
      gtClass == predClass &&
      gtClass != backgroundFpRow &&
      predClass != missedColumn;

  bool get isError => !isDiagonal;
}

/// The confusion matrix plus per-cell example objects.
class ConfusionMatrixDetails {
  const ConfusionMatrixDetails({
    required this.matrix,
    required this.examplesByCell,
  });

  final ConfusionMatrix matrix;

  /// `examplesByCell[row][column]` → the objects in that cell.
  final Map<String, Map<String, List<ConfusionCellExample>>> examplesByCell;

  List<ConfusionCellExample> examples(String row, String column) {
    return examplesByCell[row]?[column] ?? const <ConfusionCellExample>[];
  }

  /// Total count for a matrix row, used for row-percent normalisation.
  ///
  /// A row aggregates one ground-truth class across all predicted columns, so
  /// the diagonal cell divided by [rowTotal] is that class's recall.
  int rowTotal(String row) {
    final Map<String, int>? columns = matrix.counts[row];
    if (columns == null) {
      return 0;
    }
    return columns.values.fold(0, (int sum, int value) => sum + value);
  }

  /// Total count for a matrix column, used for column-percent normalisation.
  ///
  /// A column aggregates one predicted class across all ground-truth rows, so
  /// the diagonal cell divided by [columnTotal] is that class's precision.
  int columnTotal(String column) {
    int sum = 0;
    for (final Map<String, int> row in matrix.counts.values) {
      sum += row[column] ?? 0;
    }
    return sum;
  }

  /// Flattened, sorted list of cells. By default the diagonal (correct
  /// predictions) is excluded and pairs are ordered by descending count.
  List<ConfusionPair> pairs({bool includeDiagonal = false}) {
    final List<ConfusionPair> result = [];
    for (final MapEntry<String, Map<String, List<ConfusionCellExample>>> row
        in examplesByCell.entries) {
      final int total = rowTotal(row.key);
      for (final MapEntry<String, List<ConfusionCellExample>> cell
          in row.value.entries) {
        final int count = cell.value.length;
        if (count == 0) {
          continue;
        }
        final ConfusionPair pair = ConfusionPair(
          gtClass: row.key,
          predClass: cell.key,
          gtCategoryId: cell.value.first.gtCategoryId,
          predCategoryId: cell.value.first.predCategoryId,
          count: count,
          rowPercent: total == 0 ? 0 : count / total,
          exampleImageIds: [
            for (final ConfusionCellExample e in cell.value) e.imageId,
          ],
        );
        if (!includeDiagonal && pair.isDiagonal) {
          continue;
        }
        result.add(pair);
      }
    }
    result.sort((ConfusionPair a, ConfusionPair b) {
      final int byCount = b.count.compareTo(a.count);
      if (byCount != 0) {
        return byCount;
      }
      final int byRow = a.gtClass.compareTo(b.gtClass);
      if (byRow != 0) {
        return byRow;
      }
      return a.predClass.compareTo(b.predClass);
    });
    return result;
  }
}

/// Builds a [ConfusionMatrixDetails] using the same class-agnostic matching
/// pass as [ConfusionMatrixBuilder], but additionally records the concrete
/// objects behind each cell so the UI can drill down into them.
class ConfusionMatrixDetailBuilder {
  const ConfusionMatrixDetailBuilder();

  ConfusionMatrixDetails build({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required EvalConfig config,
  }) {
    final Map<String, Map<String, List<ConfusionCellExample>>> examples = {};
    final Map<String, Map<String, int>> counts = {};
    final List<String> categoryNames = dataset.categoriesById.values
        .map((category) => category.name)
        .toList()
      ..sort();

    for (final String gtName in categoryNames) {
      counts[gtName] = {
        for (final String predName in categoryNames) predName: 0,
        missedColumn: 0,
      };
    }
    counts[backgroundFpRow] = {
      for (final String predName in categoryNames) predName: 0,
    };

    void record(ConfusionCellExample example) {
      examples
          .putIfAbsent(example.gtClass, () => {})
          .putIfAbsent(example.predClass, () => [])
          .add(example);
      counts.putIfAbsent(example.gtClass, () => {});
      counts[example.gtClass]!.putIfAbsent(example.predClass, () => 0);
      counts[example.gtClass]![example.predClass] =
          (counts[example.gtClass]![example.predClass] ?? 0) + 1;
    }

    final Set<int> imageIds = {
      ...dataset.imagesById.keys,
      ...modelRun.predictionsByImageId.keys,
    };

    for (final int imageId in imageIds) {
      final String fileName =
          dataset.imagesById[imageId]?.fileName ?? '$imageId';
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
            dataset.categoriesById[prediction.categoryId]?.name ??
                '${prediction.categoryId}';
        if (bestIndex != -1 && bestIou >= config.iouThreshold) {
          matchedGtIndexes.add(bestIndex);
          final GroundTruthAnnotation gt = groundTruths[bestIndex];
          final String gtName =
              dataset.categoriesById[gt.categoryId]?.name ?? '${gt.categoryId}';
          record(
            ConfusionCellExample(
              imageId: imageId,
              fileName: fileName,
              gtClass: gtName,
              predClass: predName,
              gtCategoryId: gt.categoryId,
              predCategoryId: prediction.categoryId,
              score: prediction.score,
              iou: bestIou,
              gtBbox: gt.bbox,
              predBbox: prediction.bbox,
            ),
          );
        } else {
          record(
            ConfusionCellExample(
              imageId: imageId,
              fileName: fileName,
              gtClass: backgroundFpRow,
              predClass: predName,
              predCategoryId: prediction.categoryId,
              score: prediction.score,
              iou: bestIou == 0 ? null : bestIou,
              predBbox: prediction.bbox,
            ),
          );
        }
      }

      for (var gtIndex = 0; gtIndex < groundTruths.length; gtIndex += 1) {
        if (!matchedGtIndexes.contains(gtIndex)) {
          final GroundTruthAnnotation gt = groundTruths[gtIndex];
          final String gtName =
              dataset.categoriesById[gt.categoryId]?.name ?? '${gt.categoryId}';
          record(
            ConfusionCellExample(
              imageId: imageId,
              fileName: fileName,
              gtClass: gtName,
              predClass: missedColumn,
              gtCategoryId: gt.categoryId,
              gtBbox: gt.bbox,
            ),
          );
        }
      }
    }

    return ConfusionMatrixDetails(
      matrix: ConfusionMatrix(counts),
      examplesByCell: examples,
    );
  }
}

int _comparePredictions(Prediction a, Prediction b) {
  final int scoreCompare = b.score.compareTo(a.score);
  if (scoreCompare != 0) {
    return scoreCompare;
  }
  return a.categoryId.compareTo(b.categoryId);
}
