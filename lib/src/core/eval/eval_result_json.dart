import '../model/detection_match.dart';
import '../model/eval_config.dart';
import '../model/eval_result.dart';
import 'class_stats.dart';
import 'confusion_matrix.dart';
import 'small_object_stats.dart';

/// Canonical, compact JSON contract for an [EvalResult], shared with the
/// Python server (`server/cvmlab_server/core/serialization.py`).
///
/// The compact form intentionally omits the per-detection match list, which can
/// be very large; remote mode fetches per-image match detail lazily. When
/// rehydrating on the client, [evalResultFromCompactJson] sets `matches` to an
/// empty list.

Map<String, dynamic> evalConfigToCompactJson(EvalConfig config) {
  return <String, dynamic>{
    'iou_threshold': config.iouThreshold,
    'confidence_threshold': config.confidenceThreshold,
    'class_aware_matching': config.classAwareMatching,
    'ignore_crowd': config.ignoreCrowd,
    'small_object_mode': _smallObjectModeName(config.smallObjectMode),
  };
}

EvalConfig evalConfigFromCompactJson(Map<String, dynamic> map) {
  return EvalConfig(
    iouThreshold: (map['iou_threshold'] as num?)?.toDouble() ?? 0.5,
    confidenceThreshold: (map['confidence_threshold'] as num?)?.toDouble() ?? 0.25,
    classAwareMatching: map['class_aware_matching'] as bool? ?? true,
    ignoreCrowd: map['ignore_crowd'] as bool? ?? true,
    smallObjectMode: SmallObjectMode.coco,
  );
}

Map<String, dynamic> evalResultToCompactJson(EvalResult result) {
  final List<ClassStats> sortedClasses = result.perClassStats.values.toList()
    ..sort((ClassStats a, ClassStats b) => a.categoryId.compareTo(b.categoryId));
  final List<ImageEvalSummary> sortedImages =
      result.imageSummaries.values.toList()
        ..sort(
          (ImageEvalSummary a, ImageEvalSummary b) =>
              a.imageId.compareTo(b.imageId),
        );
  final List<int> sortedSmallObjectKeys = result.smallObjectStats.keys.toList()
    ..sort();

  return <String, dynamic>{
    'config': evalConfigToCompactJson(result.config),
    'overall': _overallToJson(result.overall),
    'per_class': [
      for (final ClassStats stat in sortedClasses) _classStatsToJson(stat),
    ],
    'image_summaries': [
      for (final ImageEvalSummary summary in sortedImages)
        _imageSummaryToJson(summary),
    ],
    'confusion': <String, dynamic>{'counts': _confusionToJson(result.confusionMatrix)},
    'small_object': [
      for (final int categoryId in sortedSmallObjectKeys)
        <String, dynamic>{
          'category_id': categoryId,
          'buckets': _bucketsToJson(result.smallObjectStats[categoryId]!),
        },
    ],
  };
}

EvalResult evalResultFromCompactJson(
  Map<String, dynamic> map, {
  List<DetectionMatch> matches = const <DetectionMatch>[],
}) {
  final EvalConfig config =
      evalConfigFromCompactJson(map['config'] as Map<String, dynamic>);
  final Map<int, ClassStats> perClass = {
    for (final dynamic item in (map['per_class'] as List<dynamic>))
      (item as Map<String, dynamic>)['category_id'] as int:
          _classStatsFromJson(item),
  };
  final Map<int, ImageEvalSummary> imageSummaries = {
    for (final dynamic item in (map['image_summaries'] as List<dynamic>))
      (item as Map<String, dynamic>)['image_id'] as int:
          _imageSummaryFromJson(item),
  };
  final Map<int, Map<ObjectSizeBucket, SmallObjectClassStats>> smallObject = {
    for (final dynamic item in (map['small_object'] as List<dynamic>))
      (item as Map<String, dynamic>)['category_id'] as int:
          _bucketsFromJson(item['buckets'] as Map<String, dynamic>),
  };
  return EvalResult(
    matches: matches,
    overall: _overallFromJson(map['overall'] as Map<String, dynamic>),
    perClassStats: perClass,
    imageSummaries: imageSummaries,
    confusionMatrix: _confusionFromJson(
      (map['confusion'] as Map<String, dynamic>)['counts']
          as Map<String, dynamic>,
    ),
    smallObjectStats: smallObject,
    config: config,
  );
}

// --- helpers ---

String _smallObjectModeName(SmallObjectMode mode) {
  switch (mode) {
    case SmallObjectMode.coco:
      return 'coco';
  }
}

Map<String, dynamic> _overallToJson(OverallStats o) => <String, dynamic>{
      'total_images': o.totalImages,
      'total_gt': o.totalGt,
      'total_predictions_before_threshold': o.totalPredictionsBeforeThreshold,
      'total_predictions_after_threshold': o.totalPredictionsAfterThreshold,
      'total_tp': o.totalTp,
      'total_fp': o.totalFp,
      'total_fn': o.totalFn,
      'micro_precision': o.microPrecision,
      'micro_recall': o.microRecall,
      'micro_f1': o.microF1,
      'macro_precision': o.macroPrecision,
      'macro_recall': o.macroRecall,
      'macro_f1': o.macroF1,
      'images_with_any_error': o.imagesWithAnyError,
      'images_with_fp': o.imagesWithFp,
      'images_with_fn': o.imagesWithFn,
    };

OverallStats _overallFromJson(Map<String, dynamic> m) => OverallStats(
      totalImages: m['total_images'] as int,
      totalGt: m['total_gt'] as int,
      totalPredictionsBeforeThreshold:
          m['total_predictions_before_threshold'] as int,
      totalPredictionsAfterThreshold:
          m['total_predictions_after_threshold'] as int,
      totalTp: m['total_tp'] as int,
      totalFp: m['total_fp'] as int,
      totalFn: m['total_fn'] as int,
      microPrecision: (m['micro_precision'] as num).toDouble(),
      microRecall: (m['micro_recall'] as num).toDouble(),
      microF1: (m['micro_f1'] as num).toDouble(),
      macroPrecision: (m['macro_precision'] as num).toDouble(),
      macroRecall: (m['macro_recall'] as num).toDouble(),
      macroF1: (m['macro_f1'] as num).toDouble(),
      imagesWithAnyError: m['images_with_any_error'] as int,
      imagesWithFp: m['images_with_fp'] as int,
      imagesWithFn: m['images_with_fn'] as int,
    );

Map<String, dynamic> _classStatsToJson(ClassStats s) => <String, dynamic>{
      'category_id': s.categoryId,
      'category_name': s.categoryName,
      'gt_count': s.gtCount,
      'pred_count': s.predCount,
      'tp': s.tp,
      'fp': s.fp,
      'fn': s.fn,
      'precision': s.precision,
      'recall': s.recall,
      'f1': s.f1,
    };

ClassStats _classStatsFromJson(Map<String, dynamic> m) => ClassStats(
      categoryId: m['category_id'] as int,
      categoryName: m['category_name'] as String,
      gtCount: m['gt_count'] as int,
      predCount: m['pred_count'] as int,
      tp: m['tp'] as int,
      fp: m['fp'] as int,
      fn: m['fn'] as int,
      precision: (m['precision'] as num).toDouble(),
      recall: (m['recall'] as num).toDouble(),
      f1: (m['f1'] as num).toDouble(),
    );

Map<String, dynamic> _imageSummaryToJson(ImageEvalSummary s) => <String, dynamic>{
      'image_id': s.imageId,
      'tp': s.tp,
      'fp': s.fp,
      'fn': s.fn,
      'has_tp': s.hasTp,
      'has_fp': s.hasFp,
      'has_fn': s.hasFn,
      'has_class_confusion': s.hasClassConfusion,
      'has_small_object': s.hasSmallObject,
      'has_only_background_fp': s.hasOnlyBackgroundFp,
      'has_missed_objects': s.hasMissedObjects,
    };

ImageEvalSummary _imageSummaryFromJson(Map<String, dynamic> m) => ImageEvalSummary(
      imageId: m['image_id'] as int,
      tp: m['tp'] as int,
      fp: m['fp'] as int,
      fn: m['fn'] as int,
      hasTp: m['has_tp'] as bool,
      hasFp: m['has_fp'] as bool,
      hasFn: m['has_fn'] as bool,
      hasClassConfusion: m['has_class_confusion'] as bool,
      hasSmallObject: m['has_small_object'] as bool,
      hasOnlyBackgroundFp: m['has_only_background_fp'] as bool,
      hasMissedObjects: m['has_missed_objects'] as bool,
    );

Map<String, dynamic> _confusionToJson(ConfusionMatrix matrix) {
  return <String, dynamic>{
    for (final MapEntry<String, Map<String, int>> row in matrix.counts.entries)
      row.key: <String, dynamic>{
        for (final MapEntry<String, int> col in row.value.entries)
          col.key: col.value,
      },
  };
}

ConfusionMatrix _confusionFromJson(Map<String, dynamic> map) {
  final Map<String, Map<String, int>> counts = {
    for (final MapEntry<String, dynamic> row in map.entries)
      row.key: {
        for (final MapEntry<String, dynamic> col
            in (row.value as Map<String, dynamic>).entries)
          col.key: (col.value as num).toInt(),
      },
  };
  return ConfusionMatrix(counts);
}

Map<String, dynamic> _bucketsToJson(
  Map<ObjectSizeBucket, SmallObjectClassStats> buckets,
) {
  return <String, dynamic>{
    for (final ObjectSizeBucket bucket in ObjectSizeBucket.values)
      _bucketName(bucket): _smallStatsToJson(buckets[bucket]!),
  };
}

Map<ObjectSizeBucket, SmallObjectClassStats> _bucketsFromJson(
  Map<String, dynamic> map,
) {
  return <ObjectSizeBucket, SmallObjectClassStats>{
    for (final ObjectSizeBucket bucket in ObjectSizeBucket.values)
      bucket: _smallStatsFromJson(map[_bucketName(bucket)] as Map<String, dynamic>),
  };
}

String _bucketName(ObjectSizeBucket bucket) {
  switch (bucket) {
    case ObjectSizeBucket.small:
      return 'small';
    case ObjectSizeBucket.medium:
      return 'medium';
    case ObjectSizeBucket.large:
      return 'large';
  }
}

Map<String, dynamic> _smallStatsToJson(SmallObjectClassStats s) => <String, dynamic>{
      'gt_count': s.gtCount,
      'tp': s.tp,
      'fn': s.fn,
      'recall': s.recall,
    };

SmallObjectClassStats _smallStatsFromJson(Map<String, dynamic> m) =>
    SmallObjectClassStats(
      gtCount: m['gt_count'] as int,
      tp: m['tp'] as int,
      fn: m['fn'] as int,
      recall: (m['recall'] as num).toDouble(),
    );
