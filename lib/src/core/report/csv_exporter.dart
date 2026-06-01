import '../eval/class_stats.dart';
import '../eval/confusion_matrix.dart';
import '../eval/small_object_stats.dart';
import '../model/annotation.dart';
import '../model/coco_dataset.dart';
import '../model/eval_config.dart';
import '../model/eval_result.dart';
import '../model/model_run.dart';
import '../model/prediction.dart';
import 'report_models.dart';

/// Escapes a single CSV field.
///
/// Rules:
/// * `null` -> empty field
/// * `bool` -> `true` / `false`
/// * `num` -> invariant culture (dot decimal separator), no thousands sep
/// * `String` containing a comma, quote, CR or LF -> wrapped in double quotes
///   with inner quotes doubled
String csvEscape(Object? value) {
  if (value == null) {
    return '';
  }
  final String text;
  if (value is bool) {
    text = value ? 'true' : 'false';
  } else if (value is num) {
    // Dart's num.toString() is locale-independent and uses '.' for decimals.
    text = value.toString();
  } else {
    text = value.toString();
  }
  if (text.contains(',') ||
      text.contains('"') ||
      text.contains('\n') ||
      text.contains('\r')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

class CsvExporter {
  const CsvExporter();

  static const String _lineEnding = '\n';

  String buildPerClassMetricsCsv(Map<int, ClassStats> perClassStats) {
    final List<List<Object?>> rows = [
      const [
        'class_id',
        'class_name',
        'gt_count',
        'pred_count',
        'tp',
        'fp',
        'fn',
        'precision',
        'recall',
        'f1',
      ],
    ];
    final List<ClassStats> stats = perClassStats.values.toList()
      ..sort((ClassStats a, ClassStats b) => a.categoryId.compareTo(b.categoryId));
    for (final ClassStats stat in stats) {
      rows.add([
        stat.categoryId,
        stat.categoryName,
        stat.gtCount,
        stat.predCount,
        stat.tp,
        stat.fp,
        stat.fn,
        stat.precision,
        stat.recall,
        stat.f1,
      ]);
    }
    return _render(rows);
  }

  String buildImageErrorsCsv({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required EvalConfig evalConfig,
    required EvalResult evalResult,
    required List<int> imageIds,
    required Set<String> missingImageFileNames,
  }) {
    final List<List<Object?>> rows = [
      const [
        'image_id',
        'file_name',
        'gt_count',
        'pred_count',
        'tp',
        'fp',
        'fn',
        'has_error',
        'has_fp',
        'has_fn',
        'has_class_confusion',
        'has_small_object',
        'missing_image',
      ],
    ];
    for (final int imageId in imageIds) {
      final ImageEvalSummary? summary = evalResult.imageSummaries[imageId];
      final String fileName = dataset.imagesById[imageId]?.fileName ?? '';
      final int gtCount = _gtCount(dataset, evalConfig, imageId);
      final int predCount = _predCount(modelRun, evalConfig, imageId);
      final int tp = summary?.tp ?? 0;
      final int fp = summary?.fp ?? 0;
      final int fn = summary?.fn ?? 0;
      rows.add([
        imageId,
        fileName,
        gtCount,
        predCount,
        tp,
        fp,
        fn,
        fp > 0 || fn > 0,
        fp > 0,
        fn > 0,
        summary?.hasClassConfusion ?? false,
        summary?.hasSmallObject ?? false,
        missingImageFileNames.contains(fileName),
      ]);
    }
    return _render(rows);
  }

  String buildMatchesCsv(List<ReportMatchRow> matchRows) {
    final List<List<Object?>> rows = [
      const [
        'image_id',
        'file_name',
        'match_type',
        'category_id',
        'category_name',
        'score',
        'iou',
        'reason',
        'bbox_x',
        'bbox_y',
        'bbox_w',
        'bbox_h',
        'gt_annotation_id',
        'prediction_index',
      ],
    ];
    for (final ReportMatchRow row in matchRows) {
      rows.add([
        row.imageId,
        row.fileName,
        row.matchType,
        row.categoryId,
        row.categoryName,
        row.score,
        row.iou,
        row.reason,
        row.bbox?.x,
        row.bbox?.y,
        row.bbox?.width,
        row.bbox?.height,
        row.gtAnnotationId,
        row.predictionIndex,
      ]);
    }
    return _render(rows);
  }

  String buildSmallObjectStatsCsv({
    required CocoDataset dataset,
    required Map<int, Map<ObjectSizeBucket, SmallObjectClassStats>>
        smallObjectStats,
  }) {
    final List<List<Object?>> rows = [
      const [
        'class_id',
        'class_name',
        'size_bucket',
        'gt_count',
        'tp',
        'fn',
        'recall',
      ],
    ];
    final List<int> classIds = smallObjectStats.keys.toList()..sort();
    for (final int classId in classIds) {
      final String className = dataset.categoriesById[classId]?.name ?? '$classId';
      final Map<ObjectSizeBucket, SmallObjectClassStats> buckets =
          smallObjectStats[classId]!;
      for (final ObjectSizeBucket bucket in ObjectSizeBucket.values) {
        final SmallObjectClassStats? stat = buckets[bucket];
        if (stat == null) {
          continue;
        }
        rows.add([
          classId,
          className,
          bucket.name,
          stat.gtCount,
          stat.tp,
          stat.fn,
          stat.recall,
        ]);
      }
    }
    return _render(rows);
  }

  String buildConfusionMatrixCsv(ConfusionMatrix confusionMatrix) {
    final List<List<Object?>> rows = [
      const ['gt_class', 'pred_class', 'count'],
    ];
    final List<String> gtClasses = confusionMatrix.counts.keys.toList()..sort();
    for (final String gtClass in gtClasses) {
      final Map<String, int> columns = confusionMatrix.counts[gtClass]!;
      final List<String> predClasses = columns.keys.toList()..sort();
      for (final String predClass in predClasses) {
        rows.add([gtClass, predClass, columns[predClass] ?? 0]);
      }
    }
    return _render(rows);
  }

  int _gtCount(CocoDataset dataset, EvalConfig config, int imageId) {
    final List<GroundTruthAnnotation> annotations =
        dataset.annotationsByImageId[imageId] ??
            const <GroundTruthAnnotation>[];
    if (!config.ignoreCrowd) {
      return annotations.length;
    }
    return annotations
        .where((GroundTruthAnnotation a) => !a.isCrowd)
        .length;
  }

  int _predCount(ModelRun modelRun, EvalConfig config, int imageId) {
    final List<Prediction> predictions =
        modelRun.predictionsByImageId[imageId] ?? const <Prediction>[];
    return predictions
        .where((Prediction p) => p.score >= config.confidenceThreshold)
        .length;
  }

  String _render(List<List<Object?>> rows) {
    final StringBuffer buffer = StringBuffer();
    for (final List<Object?> row in rows) {
      buffer.write(row.map(csvEscape).join(','));
      buffer.write(_lineEnding);
    }
    return buffer.toString();
  }
}
