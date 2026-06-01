import '../eval/small_object_stats.dart';
import 'detection_match.dart';

enum EvalImageFilter {
  all,
  anyError,
  falsePositive,
  falseNegative,
  falsePositiveAndFalseNegative,
  classConfusion,
  highConfidenceFalsePositive,
  lowIouTruePositive,
  smallObjects,
  missingImages,
}

enum ObjectSizeFilter {
  all,
  small,
  medium,
  large,
}

class EvalViewFilter {
  const EvalViewFilter({
    this.imageFilter = EvalImageFilter.all,
    this.selectedClassIds = const <int>{},
    this.enabledMatchTypes = const {
      DetectionMatchType.truePositive,
      DetectionMatchType.falsePositive,
      DetectionMatchType.falseNegative,
    },
    this.objectSizeFilter = ObjectSizeFilter.all,
    this.onlyImagesWithErrors = false,
    this.onlyImagesWithClassConfusion = false,
    this.onlyMissingImages = false,
    this.highConfidenceFpThreshold = 0.7,
    this.lowIouTpThreshold = 0.55,
  });

  final EvalImageFilter imageFilter;
  final Set<int> selectedClassIds;
  final Set<DetectionMatchType> enabledMatchTypes;
  final ObjectSizeFilter objectSizeFilter;
  final bool onlyImagesWithErrors;
  final bool onlyImagesWithClassConfusion;
  final bool onlyMissingImages;
  final double highConfidenceFpThreshold;
  final double lowIouTpThreshold;

  bool get hasClassFilter => selectedClassIds.isNotEmpty;

  EvalViewFilter copyWith({
    EvalImageFilter? imageFilter,
    Set<int>? selectedClassIds,
    Set<DetectionMatchType>? enabledMatchTypes,
    ObjectSizeFilter? objectSizeFilter,
    bool? onlyImagesWithErrors,
    bool? onlyImagesWithClassConfusion,
    bool? onlyMissingImages,
    double? highConfidenceFpThreshold,
    double? lowIouTpThreshold,
  }) {
    return EvalViewFilter(
      imageFilter: imageFilter ?? this.imageFilter,
      selectedClassIds: selectedClassIds ?? this.selectedClassIds,
      enabledMatchTypes: enabledMatchTypes ?? this.enabledMatchTypes,
      objectSizeFilter: objectSizeFilter ?? this.objectSizeFilter,
      onlyImagesWithErrors: onlyImagesWithErrors ?? this.onlyImagesWithErrors,
      onlyImagesWithClassConfusion:
          onlyImagesWithClassConfusion ?? this.onlyImagesWithClassConfusion,
      onlyMissingImages: onlyMissingImages ?? this.onlyMissingImages,
      highConfidenceFpThreshold:
          highConfidenceFpThreshold ?? this.highConfidenceFpThreshold,
      lowIouTpThreshold: lowIouTpThreshold ?? this.lowIouTpThreshold,
    );
  }
}

ObjectSizeFilter objectSizeFilterForBucket(ObjectSizeBucket bucket) {
  return switch (bucket) {
    ObjectSizeBucket.small => ObjectSizeFilter.small,
    ObjectSizeBucket.medium => ObjectSizeFilter.medium,
    ObjectSizeBucket.large => ObjectSizeFilter.large,
  };
}
