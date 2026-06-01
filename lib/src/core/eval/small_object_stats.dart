import '../model/coco_dataset.dart';
import '../model/detection_match.dart';
import '../model/eval_config.dart';

enum ObjectSizeBucket {
  small,
  medium,
  large,
}

class SmallObjectClassStats {
  const SmallObjectClassStats({
    required this.gtCount,
    required this.tp,
    required this.fn,
    required this.recall,
  });

  final int gtCount;
  final int tp;
  final int fn;
  final double recall;
}

ObjectSizeBucket smallObjectBucket(double area) {
  if (area < 32 * 32) {
    return ObjectSizeBucket.small;
  }
  if (area < 96 * 96) {
    return ObjectSizeBucket.medium;
  }
  return ObjectSizeBucket.large;
}

class SmallObjectStatsBuilder {
  Map<int, Map<ObjectSizeBucket, SmallObjectClassStats>> build({
    required CocoDataset dataset,
    required List<DetectionMatch> matches,
    required EvalConfig config,
  }) {
    final Map<int, Map<ObjectSizeBucket, _MutableSmallStats>> mutable = {};
    for (final categoryId in dataset.categoriesById.keys) {
      mutable[categoryId] = {
        for (final ObjectSizeBucket bucket in ObjectSizeBucket.values)
          bucket: _MutableSmallStats(),
      };
    }

    for (final annotation in dataset.annotations) {
      if (config.ignoreCrowd && annotation.isCrowd) {
        continue;
      }
      final ObjectSizeBucket bucket =
          smallObjectBucket(annotation.effectiveArea);
      mutable[annotation.categoryId]![bucket]!.gtCount += 1;
    }

    for (final DetectionMatch match in matches) {
      final annotation = match.groundTruth;
      if (annotation == null ||
          match.type == DetectionMatchType.falsePositive) {
        continue;
      }
      final ObjectSizeBucket bucket =
          smallObjectBucket(annotation.effectiveArea);
      final _MutableSmallStats stat = mutable[annotation.categoryId]![bucket]!;
      if (match.type == DetectionMatchType.truePositive) {
        stat.tp += 1;
      } else if (match.type == DetectionMatchType.falseNegative) {
        stat.fn += 1;
      }
    }

    return {
      for (final classEntry in mutable.entries)
        classEntry.key: {
          for (final bucketEntry in classEntry.value.entries)
            bucketEntry.key: SmallObjectClassStats(
              gtCount: bucketEntry.value.gtCount,
              tp: bucketEntry.value.tp,
              fn: bucketEntry.value.fn,
              recall: bucketEntry.value.gtCount == 0
                  ? 0
                  : bucketEntry.value.tp / bucketEntry.value.gtCount,
            ),
        },
    };
  }
}

class _MutableSmallStats {
  int gtCount = 0;
  int tp = 0;
  int fn = 0;
}
