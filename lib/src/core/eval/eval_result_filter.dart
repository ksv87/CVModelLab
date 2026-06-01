import '../model/annotation.dart';
import '../model/coco_dataset.dart';
import '../model/detection_match.dart';
import '../model/eval_result.dart';
import '../model/eval_view_filter.dart';
import '../model/image_record.dart';
import '../model/model_run.dart';
import '../model/prediction.dart';
import 'iou.dart';
import 'small_object_stats.dart';

class FilteredImageSummary {
  const FilteredImageSummary({
    required this.imageId,
    required this.fileName,
    required this.tp,
    required this.fp,
    required this.fn,
    required this.hasError,
    required this.isMissingImage,
    required this.hasClassConfusion,
    required this.hasSmallObject,
    required this.hasHighConfidenceFp,
    required this.hasLowIouTp,
  });

  final int imageId;
  final String fileName;
  final int tp;
  final int fp;
  final int fn;
  final bool hasError;
  final bool isMissingImage;
  final bool hasClassConfusion;
  final bool hasSmallObject;
  final bool hasHighConfidenceFp;
  final bool hasLowIouTp;
}

class FilteredEvalView {
  const FilteredEvalView({
    required this.filteredImageIds,
    required this.imageSummaries,
    required this.matchesByImageId,
    required this.filterCounts,
  });

  final List<int> filteredImageIds;
  final Map<int, FilteredImageSummary> imageSummaries;
  final Map<int, List<DetectionMatch>> matchesByImageId;
  final Map<EvalImageFilter, int> filterCounts;

  List<DetectionMatch> visibleMatchesForImage(int imageId) {
    return matchesByImageId[imageId] ?? const <DetectionMatch>[];
  }
}

class EvalResultFilter {
  const EvalResultFilter();

  FilteredEvalView apply({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required EvalResult evalResult,
    required Set<String> missingImageFileNames,
    required EvalViewFilter filter,
  }) {
    final Map<int, List<DetectionMatch>> allVisibleMatches = {};
    final Map<int, FilteredImageSummary> summaries = {};
    final List<int> allImageIds = dataset.imagesById.keys.toList()..sort();

    // Group matches by image once (O(matches)) instead of re-scanning the full
    // match list for every image (which is O(images * matches)).
    final Map<int, List<DetectionMatch>> matchesByImageId = {};
    for (final DetectionMatch match in evalResult.matches) {
      (matchesByImageId[match.imageId] ??= <DetectionMatch>[]).add(match);
    }

    for (final int imageId in allImageIds) {
      final ImageRecord image = dataset.imagesById[imageId]!;
      final List<DetectionMatch> rawMatches =
          matchesByImageId[imageId] ?? const <DetectionMatch>[];
      final List<DetectionMatch> visibleMatches = rawMatches
          .where((DetectionMatch match) => _matchesViewFilter(match, filter))
          .toList();
      allVisibleMatches[imageId] = visibleMatches;
      summaries[imageId] = _buildSummary(
        image: image,
        visibleMatches: visibleMatches,
        dataset: dataset,
        modelRun: modelRun,
        evalResult: evalResult,
        missingImageFileNames: missingImageFileNames,
        filter: filter,
      );
    }

    final Map<EvalImageFilter, int> counts = {
      for (final EvalImageFilter imageFilter in EvalImageFilter.values)
        imageFilter: summaries.values
            .where(
              (FilteredImageSummary summary) =>
                  _matchesImageFilter(summary, imageFilter),
            )
            .length,
    };

    final List<int> filteredImageIds = [
      for (final int imageId in allImageIds)
        if (_matchesActiveFilters(summaries[imageId]!, filter)) imageId,
    ];

    return FilteredEvalView(
      filteredImageIds: filteredImageIds,
      imageSummaries: summaries,
      matchesByImageId: allVisibleMatches,
      filterCounts: counts,
    );
  }

  FilteredImageSummary _buildSummary({
    required ImageRecord image,
    required List<DetectionMatch> visibleMatches,
    required CocoDataset dataset,
    required ModelRun modelRun,
    required EvalResult evalResult,
    required Set<String> missingImageFileNames,
    required EvalViewFilter filter,
  }) {
    final int tp = visibleMatches.where(_isTp).length;
    final int fp = visibleMatches.where(_isFp).length;
    final int fn = visibleMatches.where(_isFn).length;
    final bool hasClassConfusion = _imageHasClassConfusion(
      image.id,
      dataset,
      modelRun,
      evalResult,
      filter,
    );
    final bool hasSmallObject = _imageHasSmallObject(
      image.id,
      dataset,
      modelRun,
      filter,
    );
    final bool hasHighConfidenceFp = visibleMatches.any(
      (DetectionMatch match) =>
          _isFp(match) &&
          match.prediction != null &&
          match.prediction!.score >= filter.highConfidenceFpThreshold,
    );
    final bool hasLowIouTp = visibleMatches.any(
      (DetectionMatch match) =>
          _isTp(match) &&
          match.iou != null &&
          match.iou! <= filter.lowIouTpThreshold,
    );
    final bool hasClassContent = !filter.hasClassFilter ||
        visibleMatches.isNotEmpty ||
        _annotationsForImage(dataset, image.id).any(
          (GroundTruthAnnotation annotation) =>
              filter.selectedClassIds.contains(annotation.categoryId),
        ) ||
        _predictionsForImage(modelRun, image.id).any(
          (Prediction prediction) =>
              filter.selectedClassIds.contains(prediction.categoryId),
        );

    return FilteredImageSummary(
      imageId: image.id,
      fileName: image.fileName,
      tp: hasClassContent ? tp : 0,
      fp: hasClassContent ? fp : 0,
      fn: hasClassContent ? fn : 0,
      hasError: hasClassContent && (fp > 0 || fn > 0),
      isMissingImage: missingImageFileNames.contains(image.fileName),
      hasClassConfusion: hasClassContent && hasClassConfusion,
      hasSmallObject: hasClassContent && hasSmallObject,
      hasHighConfidenceFp: hasClassContent && hasHighConfidenceFp,
      hasLowIouTp: hasClassContent && hasLowIouTp,
    );
  }

  bool _matchesActiveFilters(
    FilteredImageSummary summary,
    EvalViewFilter filter,
  ) {
    if (!_matchesImageFilter(summary, filter.imageFilter)) {
      return false;
    }
    if (filter.onlyImagesWithErrors && !summary.hasError) {
      return false;
    }
    if (filter.onlyImagesWithClassConfusion && !summary.hasClassConfusion) {
      return false;
    }
    if (filter.onlyMissingImages && !summary.isMissingImage) {
      return false;
    }
    return true;
  }

  bool _matchesImageFilter(
    FilteredImageSummary summary,
    EvalImageFilter imageFilter,
  ) {
    return switch (imageFilter) {
      EvalImageFilter.all => true,
      EvalImageFilter.anyError => summary.hasError,
      EvalImageFilter.falsePositive => summary.fp > 0,
      EvalImageFilter.falseNegative => summary.fn > 0,
      EvalImageFilter.falsePositiveAndFalseNegative =>
        summary.fp > 0 && summary.fn > 0,
      EvalImageFilter.classConfusion => summary.hasClassConfusion,
      EvalImageFilter.highConfidenceFalsePositive =>
        summary.hasHighConfidenceFp,
      EvalImageFilter.lowIouTruePositive => summary.hasLowIouTp,
      EvalImageFilter.smallObjects => summary.hasSmallObject,
      EvalImageFilter.missingImages => summary.isMissingImage,
    };
  }

  bool _matchesViewFilter(DetectionMatch match, EvalViewFilter filter) {
    if (!filter.enabledMatchTypes.contains(match.type)) {
      return false;
    }
    if (filter.hasClassFilter &&
        !_matchHasSelectedClass(match, filter.selectedClassIds)) {
      return false;
    }
    if (filter.objectSizeFilter != ObjectSizeFilter.all &&
        _objectSizeForMatch(match) != filter.objectSizeFilter) {
      return false;
    }
    return true;
  }

  bool _matchHasSelectedClass(DetectionMatch match, Set<int> selectedClassIds) {
    final int? categoryId = match.categoryId ?? match.prediction?.categoryId;
    return categoryId != null && selectedClassIds.contains(categoryId);
  }

  bool _imageHasClassConfusion(
    int imageId,
    CocoDataset dataset,
    ModelRun modelRun,
    EvalResult evalResult,
    EvalViewFilter filter,
  ) {
    bool selectedClass(int categoryId) {
      return !filter.hasClassFilter ||
          filter.selectedClassIds.contains(categoryId);
    }

    final List<GroundTruthAnnotation> groundTruths =
        _annotationsForImage(dataset, imageId)
            .where(
              (GroundTruthAnnotation annotation) =>
                  !(evalResult.config.ignoreCrowd && annotation.isCrowd) &&
                  selectedClass(annotation.categoryId),
            )
            .toList();
    final List<Prediction> predictions = _predictionsForImage(modelRun, imageId)
        .where(
          (Prediction prediction) =>
              prediction.score >= evalResult.config.confidenceThreshold &&
              selectedClass(prediction.categoryId),
        )
        .toList();

    for (final Prediction prediction in predictions) {
      for (final GroundTruthAnnotation annotation in groundTruths) {
        if (prediction.categoryId == annotation.categoryId) {
          continue;
        }
        if (calculateIoU(prediction.bbox, annotation.bbox) >=
            evalResult.config.iouThreshold) {
          return true;
        }
      }
    }
    return false;
  }

  bool _imageHasSmallObject(
    int imageId,
    CocoDataset dataset,
    ModelRun modelRun,
    EvalViewFilter filter,
  ) {
    bool selectedClass(int categoryId) {
      return !filter.hasClassFilter ||
          filter.selectedClassIds.contains(categoryId);
    }

    return _annotationsForImage(dataset, imageId).any(
          (GroundTruthAnnotation annotation) =>
              selectedClass(annotation.categoryId) &&
              smallObjectBucket(annotation.effectiveArea) ==
                  ObjectSizeBucket.small,
        ) ||
        _predictionsForImage(modelRun, imageId).any(
          (Prediction prediction) =>
              selectedClass(prediction.categoryId) &&
              smallObjectBucket(prediction.bbox.area) == ObjectSizeBucket.small,
        );
  }

  ObjectSizeFilter _objectSizeForMatch(DetectionMatch match) {
    final GroundTruthAnnotation? annotation = match.groundTruth;
    if (annotation != null) {
      return objectSizeFilterForBucket(
        smallObjectBucket(annotation.effectiveArea),
      );
    }
    final Prediction? prediction = match.prediction;
    if (prediction != null) {
      return objectSizeFilterForBucket(smallObjectBucket(prediction.bbox.area));
    }
    return ObjectSizeFilter.all;
  }

  List<GroundTruthAnnotation> _annotationsForImage(
    CocoDataset dataset,
    int imageId,
  ) {
    return dataset.annotationsByImageId[imageId] ??
        const <GroundTruthAnnotation>[];
  }

  List<Prediction> _predictionsForImage(ModelRun modelRun, int imageId) {
    return modelRun.predictionsByImageId[imageId] ?? const <Prediction>[];
  }
}

bool _isTp(DetectionMatch match) =>
    match.type == DetectionMatchType.truePositive;
bool _isFp(DetectionMatch match) =>
    match.type == DetectionMatchType.falsePositive;
bool _isFn(DetectionMatch match) =>
    match.type == DetectionMatchType.falseNegative;
