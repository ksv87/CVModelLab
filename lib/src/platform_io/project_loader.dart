import 'package:cv_model_lab/cv_model_lab.dart';

import 'file_pick_result.dart';
import 'image_source.dart';

class ProjectLoader {
  const ProjectLoader({
    this.annotationParser = const CocoAnnotationParser(),
    this.predictionParser = const CocoPredictionParser(),
    this.metricsCalculator = const MetricsCalculator(),
  });

  final CocoAnnotationParser annotationParser;
  final CocoPredictionParser predictionParser;
  final MetricsCalculator metricsCalculator;

  ProjectLoadResult load({
    required PickedDataFile annotationsFile,
    required PickedDataFile predictionsFile,
    required ImageSource imageSource,
    required String projectName,
    required String modelRunName,
    EvalConfig config = const EvalConfig(),
  }) {
    final ParseResult<CocoDataset> annotationResult =
        annotationParser.parseString(
      annotationsFile.readAsString(),
    );
    final CocoDataset? dataset = annotationResult.value;
    if (dataset == null) {
      return ProjectLoadResult.failure(
        projectName: projectName,
        issues: annotationResult.issues,
      );
    }

    final ParseResult<ModelRun> predictionResult = predictionParser.parseString(
      predictionsFile.readAsString(),
      dataset: dataset,
      modelRunId: 'run-1',
      modelRunName:
          modelRunName.trim().isEmpty ? 'Model run' : modelRunName.trim(),
    );
    final ModelRun? modelRun = predictionResult.value;
    final List<ParseIssue> issues = [
      ...annotationResult.issues,
      ...predictionResult.issues,
    ];
    final ImageSource resolvedImageSource = imageSource.bindExpectedImages(
      dataset.imagesById.values.map((ImageRecord image) => image.fileName),
    );
    final List<String> missingImages = resolvedImageSource.missingImages();
    final List<ParseIssue> allIssues = [
      ...issues,
      for (final String fileName in missingImages.take(20))
        ParseIssue(
          severity: ParseIssueSeverity.warning,
          message: 'missing image file',
          path: fileName,
        ),
      if (missingImages.length > 20)
        ParseIssue(
          severity: ParseIssueSeverity.warning,
          message: '${missingImages.length - 20} more image files are missing',
        ),
    ];

    final PreflightSummary summary = PreflightSummary(
      imageCount: dataset.imagesById.length,
      annotationCount: dataset.annotations.length,
      categoryCount: dataset.categoriesById.length,
      predictionCount: modelRun?.predictions.length ?? 0,
      matchedImageFileCount: dataset.imagesById.length - missingImages.length,
      missingImageFileCount: missingImages.length,
      warningCount: allIssues
          .where(
            (ParseIssue issue) => issue.severity == ParseIssueSeverity.warning,
          )
          .length,
      errorCount: allIssues
          .where(
            (ParseIssue issue) => issue.severity == ParseIssueSeverity.error,
          )
          .length,
    );

    if (modelRun == null) {
      return ProjectLoadResult.failure(
        projectName: projectName,
        issues: allIssues,
        preflightSummary: summary,
      );
    }

    final EvalResult evalResult = metricsCalculator.evaluate(
      dataset: dataset,
      modelRun: modelRun,
      config: config,
    );
    return ProjectLoadResult(
      projectName: projectName,
      dataset: dataset,
      modelRun: modelRun,
      imageSource: resolvedImageSource,
      evalResult: evalResult,
      issues: allIssues,
      preflightSummary: summary,
    );
  }
}

class ProjectLoadResult {
  const ProjectLoadResult({
    required this.projectName,
    required this.dataset,
    required this.modelRun,
    required this.imageSource,
    required this.evalResult,
    required this.issues,
    required this.preflightSummary,
  });

  factory ProjectLoadResult.failure({
    required String projectName,
    required List<ParseIssue> issues,
    PreflightSummary? preflightSummary,
  }) {
    return ProjectLoadResult(
      projectName: projectName,
      dataset: null,
      modelRun: null,
      imageSource: null,
      evalResult: null,
      issues: issues,
      preflightSummary: preflightSummary,
    );
  }

  final String projectName;
  final CocoDataset? dataset;
  final ModelRun? modelRun;
  final ImageSource? imageSource;
  final EvalResult? evalResult;
  final List<ParseIssue> issues;
  final PreflightSummary? preflightSummary;

  bool get canOpen {
    return dataset != null &&
        modelRun != null &&
        imageSource != null &&
        evalResult != null;
  }
}

class PreflightSummary {
  const PreflightSummary({
    required this.imageCount,
    required this.annotationCount,
    required this.categoryCount,
    required this.predictionCount,
    required this.matchedImageFileCount,
    required this.missingImageFileCount,
    required this.warningCount,
    required this.errorCount,
  });

  final int imageCount;
  final int annotationCount;
  final int categoryCount;
  final int predictionCount;
  final int matchedImageFileCount;
  final int missingImageFileCount;
  final int warningCount;
  final int errorCount;
}
