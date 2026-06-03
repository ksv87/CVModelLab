/// Severity of a single [DatasetHealthIssue].
enum DatasetIssueSeverity {
  info,
  warning,
  error,
}

/// The kind of problem a [DatasetHealthIssue] describes.
enum DatasetIssueType {
  missingImageFile,
  unusedImageFile,
  unknownAnnotationImageId,
  unknownAnnotationCategoryId,
  unknownPredictionImageId,
  unknownPredictionCategoryId,
  invalidBbox,
  bboxOutsideImage,
  bboxPartiallyOutsideImage,
  extremeAspectRatio,
  tinyBbox,
  imageWithoutGroundTruth,
  classWithoutGroundTruth,
  rareClass,
  duplicateImageId,
  duplicateFileName,
  duplicateAnnotationId,
  hugeBbox,
  predictionWithoutImage,
  predictionOnImageWithoutGroundTruth,
  classImbalance,
}

/// A single problem found while checking dataset / input-file quality.
class DatasetHealthIssue {
  const DatasetHealthIssue({
    required this.severity,
    required this.type,
    this.title = '',
    this.message = '',
    this.imageId,
    this.fileName,
    this.annotationId,
    this.categoryId,
    this.categoryName,
    this.recommendation,
    this.details = const <String, Object?>{},
    this.technicalDetails,
  });

  final DatasetIssueSeverity severity;
  final DatasetIssueType type;

  final int? imageId;
  final String? fileName;
  final int? annotationId;
  final int? categoryId;
  final String? categoryName;

  final String title;
  final String message;
  final String? recommendation;

  final Map<String, Object?> details;
  final String? technicalDetails;
}

/// Aggregated result of a [DatasetHealthChecker] run.
class DatasetHealthReport {
  const DatasetHealthReport({
    required this.issues,
    required this.errorCount,
    required this.warningCount,
    required this.infoCount,
    required this.missingImageCount,
    required this.invalidAnnotationCount,
    required this.invalidPredictionCount,
    required this.imageWithoutGtCount,
    required this.unusedImageFileCount,
    required this.rareClassCount,
    required this.gtCountByClass,
    required this.gtPercentByClass,
    required this.generatedAt,
  });

  final List<DatasetHealthIssue> issues;

  final int errorCount;
  final int warningCount;
  final int infoCount;

  final int missingImageCount;
  final int invalidAnnotationCount;
  final int invalidPredictionCount;
  final int imageWithoutGtCount;
  final int unusedImageFileCount;
  final int rareClassCount;

  final Map<int, int> gtCountByClass;
  final Map<int, double> gtPercentByClass;

  final DateTime generatedAt;

  bool get isEmpty => issues.isEmpty;

  Iterable<DatasetHealthIssue> issuesOfType(DatasetIssueType type) {
    return issues.where((DatasetHealthIssue issue) => issue.type == type);
  }

  Iterable<DatasetHealthIssue> issuesOfSeverity(DatasetIssueSeverity severity) {
    return issues.where(
      (DatasetHealthIssue issue) => issue.severity == severity,
    );
  }
}

/// Thresholds controlling which dataset conditions are flagged.
class DatasetHealthConfig {
  const DatasetHealthConfig({
    this.tinyBboxAreaThreshold = 16.0,
    this.extremeAspectRatioThreshold = 10.0,
    this.hugeBboxImageAreaRatioThreshold = 0.8,
    this.rareClassThreshold = 10,
    this.imbalanceWarningRatio = 0.05,
  });

  /// A bbox whose area is below this value (in px²) is flagged as tiny.
  final double tinyBboxAreaThreshold;

  /// A bbox whose w/h or h/w ratio exceeds this value is flagged.
  final double extremeAspectRatioThreshold;

  /// A bbox covering at least this fraction of the image area is flagged.
  final double hugeBboxImageAreaRatioThreshold;

  /// Classes with fewer than this many GT objects (but > 0) are flagged rare.
  final int rareClassThreshold;

  /// Classes whose GT share of the dataset is below this ratio are flagged
  /// as imbalanced.
  final double imbalanceWarningRatio;
}

/// Pure-Dart description of which image files are present or missing relative
/// to the dataset's COCO `file_name` references. The UI builds this from a
/// platform [ImageSource]; the core never imports the platform layer.
class DatasetImageAvailability {
  const DatasetImageAvailability({
    this.missingFileNames = const <String>{},
    this.unusedFileNames = const <String>{},
    this.available = true,
  });

  /// `file_name`s referenced by COCO images but not found on disk / in the
  /// selected files.
  final Set<String> missingFileNames;

  /// Files that exist in the selected image source but are not referenced by
  /// any COCO image record.
  final Set<String> unusedFileNames;

  /// Whether an image source was actually provided. When false, missing/unused
  /// checks are skipped so projects opened without images are not spammed with
  /// "missing image" errors.
  final bool available;

  static const DatasetImageAvailability none =
      DatasetImageAvailability(available: false);
}
