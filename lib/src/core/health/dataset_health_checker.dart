import '../model/annotation.dart';
import '../model/bbox.dart';
import '../model/category.dart';
import '../model/coco_dataset.dart';
import '../model/image_record.dart';
import '../model/prediction.dart';
import 'dataset_health_models.dart';

/// Analyses a [CocoDataset] together with a model run's predictions for
/// dataset- and input-file quality problems (as opposed to model accuracy).
///
/// Pure Dart: no platform or Flutter imports. Image availability is supplied as
/// a plain [DatasetImageAvailability] value object so the core stays testable
/// and platform independent.
class DatasetHealthChecker {
  const DatasetHealthChecker();

  DatasetHealthReport check({
    required CocoDataset dataset,
    required List<Prediction> predictions,
    DatasetImageAvailability imageAvailability = DatasetImageAvailability.none,
    DatasetHealthConfig config = const DatasetHealthConfig(),
    DateTime? generatedAt,
  }) {
    final List<DatasetHealthIssue> issues = [];

    final Map<int, int> gtCountByClass = {
      for (final int id in dataset.categoriesById.keys) id: 0,
    };
    int validGtTotal = 0;

    // ── Annotations ──────────────────────────────────────────────────────────
    final Set<int> seenAnnotationIds = {};
    for (final GroundTruthAnnotation annotation in dataset.annotations) {
      final ImageRecord? image = dataset.imagesById[annotation.imageId];
      final bool knownImage = image != null;
      final bool knownCategory =
          dataset.categoriesById.containsKey(annotation.categoryId);

      if (!knownImage) {
        issues.add(
          DatasetHealthIssue(
            severity: DatasetIssueSeverity.error,
            type: DatasetIssueType.unknownAnnotationImageId,
            title: 'Annotation references unknown image',
            message: 'Annotation ${annotation.id} references image_id '
                '${annotation.imageId}, which is not in the dataset.',
            annotationId: annotation.id,
            imageId: annotation.imageId,
            recommendation: 'Remove the annotation or add the missing image '
                'record.',
          ),
        );
      }
      if (!knownCategory) {
        issues.add(
          DatasetHealthIssue(
            severity: DatasetIssueSeverity.error,
            type: DatasetIssueType.unknownAnnotationCategoryId,
            title: 'Annotation references unknown category',
            message: 'Annotation ${annotation.id} references category_id '
                '${annotation.categoryId}, which is not declared.',
            annotationId: annotation.id,
            imageId: knownImage ? annotation.imageId : null,
            categoryId: annotation.categoryId,
            recommendation: 'Add the category to "categories" or fix the '
                'annotation.',
          ),
        );
      } else {
        gtCountByClass[annotation.categoryId] =
            (gtCountByClass[annotation.categoryId] ?? 0) + 1;
        validGtTotal += 1;
      }

      if (!seenAnnotationIds.add(annotation.id)) {
        issues.add(
          DatasetHealthIssue(
            severity: DatasetIssueSeverity.warning,
            type: DatasetIssueType.duplicateAnnotationId,
            title: 'Duplicate annotation id',
            message: 'Annotation id ${annotation.id} appears more than once.',
            annotationId: annotation.id,
            imageId: knownImage ? annotation.imageId : null,
            recommendation: 'Make annotation ids unique.',
          ),
        );
      }

      issues.addAll(
        _checkBbox(
          bbox: annotation.bbox,
          image: image,
          config: config,
          imageId: knownImage ? annotation.imageId : null,
          fileName: image?.fileName,
          annotationId: annotation.id,
          categoryId: annotation.categoryId,
          categoryName: dataset.categoriesById[annotation.categoryId]?.name,
          origin: 'Annotation ${annotation.id}',
        ),
      );
    }

    // ── Duplicate file names ──────────────────────────────────────────────────
    final Map<String, List<int>> imageIdsByFileName = {};
    for (final ImageRecord image in dataset.imagesById.values) {
      imageIdsByFileName.putIfAbsent(image.fileName, () => []).add(image.id);
    }
    for (final MapEntry<String, List<int>> entry
        in imageIdsByFileName.entries) {
      if (entry.value.length > 1) {
        issues.add(
          DatasetHealthIssue(
            severity: DatasetIssueSeverity.warning,
            type: DatasetIssueType.duplicateFileName,
            title: 'Duplicate file name',
            message: 'file_name "${entry.key}" is shared by image ids '
                '${(entry.value..sort()).join(', ')}.',
            fileName: entry.key,
            details: {'imageIds': entry.value},
            recommendation: 'Ensure each image record has a unique file_name.',
          ),
        );
      }
    }

    // ── Images without GT ─────────────────────────────────────────────────────
    int imageWithoutGtCount = 0;
    for (final ImageRecord image in dataset.imagesById.values) {
      final List<GroundTruthAnnotation> anns =
          dataset.annotationsByImageId[image.id] ??
              const <GroundTruthAnnotation>[];
      if (anns.isEmpty) {
        imageWithoutGtCount += 1;
        issues.add(
          DatasetHealthIssue(
            severity: DatasetIssueSeverity.info,
            type: DatasetIssueType.imageWithoutGroundTruth,
            title: 'Image without ground truth',
            message: 'Image "${image.fileName}" (id ${image.id}) has no '
                'annotations.',
            imageId: image.id,
            fileName: image.fileName,
            recommendation: 'Confirm the image is intentionally a negative '
                'sample.',
          ),
        );
      }
    }

    // ── Predictions ────────────────────────────────────────────────────────────
    int invalidPredictionCount = 0;
    int predictionIndex = -1;
    for (final Prediction prediction in predictions) {
      predictionIndex += 1;
      final ImageRecord? image = dataset.imagesById[prediction.imageId];
      final bool knownImage = image != null;
      final bool knownCategory =
          dataset.categoriesById.containsKey(prediction.categoryId);

      if (!knownImage) {
        invalidPredictionCount += 1;
        issues.add(
          DatasetHealthIssue(
            severity: DatasetIssueSeverity.error,
            type: DatasetIssueType.unknownPredictionImageId,
            title: 'Prediction references unknown image',
            message: 'A prediction references image_id ${prediction.imageId}, '
                'which is not in the dataset.',
            imageId: prediction.imageId,
            categoryId: prediction.categoryId,
            details: {'predictionIndex': predictionIndex},
            recommendation: 'Check that predictions and annotations use the '
                'same image ids / file names.',
          ),
        );
      }
      if (!knownCategory) {
        invalidPredictionCount += 1;
        issues.add(
          DatasetHealthIssue(
            severity: DatasetIssueSeverity.error,
            type: DatasetIssueType.unknownPredictionCategoryId,
            title: 'Prediction references unknown category',
            message: 'A prediction references category_id '
                '${prediction.categoryId}, which is not declared.',
            imageId: knownImage ? prediction.imageId : null,
            categoryId: prediction.categoryId,
            details: {'predictionIndex': predictionIndex},
            recommendation: 'Align prediction category ids with the dataset '
                'categories.',
          ),
        );
      }

      if (prediction.bbox.width <= 0 || prediction.bbox.height <= 0) {
        invalidPredictionCount += 1;
        issues.add(
          DatasetHealthIssue(
            severity: DatasetIssueSeverity.warning,
            type: DatasetIssueType.invalidBbox,
            title: 'Prediction has invalid bbox',
            message: 'A prediction on image_id ${prediction.imageId} has a '
                'non-positive width/height bbox.',
            imageId: knownImage ? prediction.imageId : null,
            categoryId: prediction.categoryId,
            details: {'predictionIndex': predictionIndex},
            recommendation: 'Filter out degenerate prediction boxes.',
          ),
        );
      }
    }

    // Predictions grouped by image for "without GT" detection.
    final Map<int, int> predCountByImage = {};
    for (final Prediction prediction in predictions) {
      if (dataset.imagesById.containsKey(prediction.imageId)) {
        predCountByImage[prediction.imageId] =
            (predCountByImage[prediction.imageId] ?? 0) + 1;
      }
    }
    for (final MapEntry<int, int> entry in predCountByImage.entries) {
      final List<GroundTruthAnnotation> anns =
          dataset.annotationsByImageId[entry.key] ??
              const <GroundTruthAnnotation>[];
      if (anns.isEmpty) {
        final ImageRecord image = dataset.imagesById[entry.key]!;
        issues.add(
          DatasetHealthIssue(
            severity: DatasetIssueSeverity.info,
            type: DatasetIssueType.predictionOnImageWithoutGroundTruth,
            title: 'Predictions on image without ground truth',
            message: 'Image "${image.fileName}" has ${entry.value} '
                'prediction(s) but no ground truth.',
            imageId: image.id,
            fileName: image.fileName,
            details: {'predictionCount': entry.value},
            recommendation: 'These predictions can only be false positives; '
                'verify the GT is complete.',
          ),
        );
      }
    }

    // ── Class-level checks (rare / empty / imbalance) ──────────────────────────
    int rareClassCount = 0;
    final Map<int, double> gtPercentByClass = {};
    for (final CategoryRecord category in dataset.categoriesById.values) {
      final int count = gtCountByClass[category.id] ?? 0;
      final double percent = validGtTotal == 0 ? 0 : count / validGtTotal;
      gtPercentByClass[category.id] = percent;

      if (count == 0) {
        issues.add(
          DatasetHealthIssue(
            severity: DatasetIssueSeverity.warning,
            type: DatasetIssueType.classWithoutGroundTruth,
            title: 'Class without ground truth',
            message: 'Class "${category.name}" (id ${category.id}) has no GT '
                'objects.',
            categoryId: category.id,
            categoryName: category.name,
            recommendation: 'Remove the unused class or add training data for '
                'it.',
          ),
        );
      } else {
        if (count < config.rareClassThreshold) {
          rareClassCount += 1;
          issues.add(
            DatasetHealthIssue(
              severity: DatasetIssueSeverity.warning,
              type: DatasetIssueType.rareClass,
              title: 'Rare class',
              message: 'Class "${category.name}" has only $count GT objects.',
              categoryId: category.id,
              categoryName: category.name,
              details: {'gtCount': count},
              recommendation: 'Collect more samples for this class.',
            ),
          );
        }
        if (validGtTotal > 0 &&
            percent < config.imbalanceWarningRatio &&
            dataset.categoriesById.length > 1) {
          issues.add(
            DatasetHealthIssue(
              severity: DatasetIssueSeverity.info,
              type: DatasetIssueType.classImbalance,
              title: 'Class imbalance',
              message: 'Class "${category.name}" accounts for only '
                  '${(percent * 100).toStringAsFixed(1)}% of GT objects.',
              categoryId: category.id,
              categoryName: category.name,
              details: {'percent': percent, 'gtCount': count},
              recommendation: 'Consider rebalancing the dataset or using class '
                  'weights.',
            ),
          );
        }
      }
    }

    // ── Image availability (missing / unused files) ────────────────────────────
    int missingImageCount = 0;
    int unusedImageFileCount = 0;
    if (imageAvailability.available) {
      for (final ImageRecord image in dataset.imagesById.values) {
        if (imageAvailability.missingFileNames.contains(image.fileName)) {
          missingImageCount += 1;
          issues.add(
            DatasetHealthIssue(
              severity: DatasetIssueSeverity.error,
              type: DatasetIssueType.missingImageFile,
              title: 'Missing image file',
              message: 'Image "${image.fileName}" (id ${image.id}) is '
                  'referenced by COCO but was not found.',
              imageId: image.id,
              fileName: image.fileName,
              recommendation: 'Add the file or fix the file_name path.',
            ),
          );
        }
      }
      for (final String fileName in imageAvailability.unusedFileNames) {
        unusedImageFileCount += 1;
        issues.add(
          DatasetHealthIssue(
            severity: DatasetIssueSeverity.info,
            type: DatasetIssueType.unusedImageFile,
            title: 'Unused image file',
            message: 'File "$fileName" is present but not referenced by the '
                'dataset.',
            fileName: fileName,
            recommendation: 'Remove the file or add an image record for it.',
          ),
        );
      }
    }

    final int errorCount =
        issues.where((i) => i.severity == DatasetIssueSeverity.error).length;
    final int warningCount =
        issues.where((i) => i.severity == DatasetIssueSeverity.warning).length;
    final int infoCount =
        issues.where((i) => i.severity == DatasetIssueSeverity.info).length;
    final int invalidAnnotationCount = issues
        .where(
          (i) =>
              i.annotationId != null &&
              (i.type == DatasetIssueType.invalidBbox ||
                  i.type == DatasetIssueType.bboxOutsideImage ||
                  i.type == DatasetIssueType.unknownAnnotationImageId ||
                  i.type == DatasetIssueType.unknownAnnotationCategoryId),
        )
        .length;

    return DatasetHealthReport(
      issues: issues,
      errorCount: errorCount,
      warningCount: warningCount,
      infoCount: infoCount,
      missingImageCount: missingImageCount,
      invalidAnnotationCount: invalidAnnotationCount,
      invalidPredictionCount: invalidPredictionCount,
      imageWithoutGtCount: imageWithoutGtCount,
      unusedImageFileCount: unusedImageFileCount,
      rareClassCount: rareClassCount,
      gtCountByClass: gtCountByClass,
      gtPercentByClass: gtPercentByClass,
      generatedAt: generatedAt ?? DateTime.now(),
    );
  }

  List<DatasetHealthIssue> _checkBbox({
    required BBox bbox,
    required ImageRecord? image,
    required DatasetHealthConfig config,
    required int? imageId,
    required String? fileName,
    required int annotationId,
    required int categoryId,
    required String? categoryName,
    required String origin,
  }) {
    final List<DatasetHealthIssue> issues = [];

    if (bbox.width <= 0 || bbox.height <= 0) {
      issues.add(
        DatasetHealthIssue(
          severity: DatasetIssueSeverity.error,
          type: DatasetIssueType.invalidBbox,
          title: 'Invalid bbox',
          message: '$origin has a non-positive width/height bbox '
              '(${_fmt(bbox.width)} x ${_fmt(bbox.height)}).',
          imageId: imageId,
          fileName: fileName,
          annotationId: annotationId,
          categoryId: categoryId,
          categoryName: categoryName,
          recommendation: 'Remove or fix the degenerate box.',
        ),
      );
      // A degenerate box makes the remaining geometric checks meaningless.
      return issues;
    }

    final double area = bbox.area;
    if (area < config.tinyBboxAreaThreshold) {
      issues.add(
        DatasetHealthIssue(
          severity: DatasetIssueSeverity.warning,
          type: DatasetIssueType.tinyBbox,
          title: 'Tiny bbox',
          message: '$origin has a tiny box (area ${_fmt(area)} px²).',
          imageId: imageId,
          fileName: fileName,
          annotationId: annotationId,
          categoryId: categoryId,
          categoryName: categoryName,
          details: {'area': area},
          recommendation: 'Verify the annotation is not a labelling error.',
        ),
      );
    }

    final double ratio = bbox.width / bbox.height;
    final double extreme = config.extremeAspectRatioThreshold;
    if (ratio > extreme || ratio < 1 / extreme) {
      issues.add(
        DatasetHealthIssue(
          severity: DatasetIssueSeverity.warning,
          type: DatasetIssueType.extremeAspectRatio,
          title: 'Extreme aspect ratio',
          message: '$origin has an extreme aspect ratio '
              '(${_fmt(ratio)}:1).',
          imageId: imageId,
          fileName: fileName,
          annotationId: annotationId,
          categoryId: categoryId,
          categoryName: categoryName,
          details: {'aspectRatio': ratio},
          recommendation: 'Check for a malformed box.',
        ),
      );
    }

    if (image != null && image.width != null && image.height != null) {
      final double iw = image.width!.toDouble();
      final double ih = image.height!.toDouble();
      final bool fullyOutside =
          bbox.x2 <= 0 || bbox.y2 <= 0 || bbox.x1 >= iw || bbox.y1 >= ih;
      final bool partiallyOutside =
          bbox.x1 < 0 || bbox.y1 < 0 || bbox.x2 > iw || bbox.y2 > ih;
      if (fullyOutside) {
        issues.add(
          DatasetHealthIssue(
            severity: DatasetIssueSeverity.error,
            type: DatasetIssueType.bboxOutsideImage,
            title: 'BBox outside image',
            message: '$origin lies entirely outside the image bounds '
                '(${iw.toStringAsFixed(0)} x ${ih.toStringAsFixed(0)}).',
            imageId: imageId,
            fileName: fileName,
            annotationId: annotationId,
            categoryId: categoryId,
            categoryName: categoryName,
            recommendation: 'Fix the bbox coordinates.',
          ),
        );
      } else if (partiallyOutside) {
        issues.add(
          DatasetHealthIssue(
            severity: DatasetIssueSeverity.warning,
            type: DatasetIssueType.bboxPartiallyOutsideImage,
            title: 'BBox partially outside image',
            message: '$origin extends past the image bounds.',
            imageId: imageId,
            fileName: fileName,
            annotationId: annotationId,
            categoryId: categoryId,
            categoryName: categoryName,
            recommendation: 'Clamp the bbox to the image.',
          ),
        );
      }

      final double imageArea = iw * ih;
      if (imageArea > 0 &&
          area >= config.hugeBboxImageAreaRatioThreshold * imageArea) {
        issues.add(
          DatasetHealthIssue(
            severity: DatasetIssueSeverity.info,
            type: DatasetIssueType.hugeBbox,
            title: 'Huge bbox',
            message: '$origin covers '
                '${(area / imageArea * 100).toStringAsFixed(0)}% of the image.',
            imageId: imageId,
            fileName: fileName,
            annotationId: annotationId,
            categoryId: categoryId,
            categoryName: categoryName,
            details: {'coverage': area / imageArea},
            recommendation: 'Confirm the box is intentional.',
          ),
        );
      }
    }

    return issues;
  }

  static String _fmt(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}
