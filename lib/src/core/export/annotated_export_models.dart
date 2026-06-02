/// Which set of images an annotated-image export should cover.
enum AnnotatedExportScope {
  currentImage,
  currentFilteredImages,
  falsePositiveImages,
  falseNegativeImages,
  classConfusionImages,
  worstImages,
  comparisonFixedImages,
  comparisonBrokenImages,
  comparisonImprovedImages,
  comparisonRegressedImages,
}

extension AnnotatedExportScopeLabel on AnnotatedExportScope {
  String get label => switch (this) {
        AnnotatedExportScope.currentImage => 'Current image',
        AnnotatedExportScope.currentFilteredImages => 'Current filtered images',
        AnnotatedExportScope.falsePositiveImages => 'False positives',
        AnnotatedExportScope.falseNegativeImages => 'False negatives',
        AnnotatedExportScope.classConfusionImages => 'Class confusion',
        AnnotatedExportScope.worstImages => 'Worst images',
        AnnotatedExportScope.comparisonFixedImages => 'Comparison: fixed',
        AnnotatedExportScope.comparisonBrokenImages => 'Comparison: broken',
        AnnotatedExportScope.comparisonImprovedImages => 'Comparison: improved',
        AnnotatedExportScope.comparisonRegressedImages =>
          'Comparison: regressed',
      };

  bool get isComparisonScope =>
      this == AnnotatedExportScope.comparisonFixedImages ||
      this == AnnotatedExportScope.comparisonBrokenImages ||
      this == AnnotatedExportScope.comparisonImprovedImages ||
      this == AnnotatedExportScope.comparisonRegressedImages;
}

/// User-configurable options for an annotated-image export.
class AnnotatedImageExportConfig {
  const AnnotatedImageExportConfig({
    this.scope = AnnotatedExportScope.currentImage,
    this.includeGt = true,
    this.includePredictions = true,
    this.includeTp = true,
    this.includeFp = true,
    this.includeFn = true,
    this.includeLabels = true,
    this.includeScores = true,
    this.includeIou = true,
    this.maxImages = 100,
    this.outputScale = 1.0,
    this.fileNameTemplate = '{index}_{status}_{fileName}',
  });

  final AnnotatedExportScope scope;
  final bool includeGt;
  final bool includePredictions;
  final bool includeTp;
  final bool includeFp;
  final bool includeFn;
  final bool includeLabels;
  final bool includeScores;
  final bool includeIou;
  final int maxImages;
  final double outputScale;
  final String fileNameTemplate;

  AnnotatedImageExportConfig copyWith({
    AnnotatedExportScope? scope,
    bool? includeGt,
    bool? includePredictions,
    bool? includeTp,
    bool? includeFp,
    bool? includeFn,
    bool? includeLabels,
    bool? includeScores,
    bool? includeIou,
    int? maxImages,
    double? outputScale,
    String? fileNameTemplate,
  }) {
    return AnnotatedImageExportConfig(
      scope: scope ?? this.scope,
      includeGt: includeGt ?? this.includeGt,
      includePredictions: includePredictions ?? this.includePredictions,
      includeTp: includeTp ?? this.includeTp,
      includeFp: includeFp ?? this.includeFp,
      includeFn: includeFn ?? this.includeFn,
      includeLabels: includeLabels ?? this.includeLabels,
      includeScores: includeScores ?? this.includeScores,
      includeIou: includeIou ?? this.includeIou,
      maxImages: maxImages ?? this.maxImages,
      outputScale: outputScale ?? this.outputScale,
      fileNameTemplate: fileNameTemplate ?? this.fileNameTemplate,
    );
  }
}

/// One image scheduled for annotated export.
class AnnotatedExportTarget {
  const AnnotatedExportTarget({
    required this.imageId,
    required this.fileName,
    required this.status,
    required this.index,
    required this.outputFileName,
  });

  final int imageId;
  final String fileName;

  /// Short status tag for the file name template (e.g. "fp", "worst").
  final String status;
  final int index;
  final String outputFileName;
}
