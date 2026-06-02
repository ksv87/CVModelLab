import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const RecommendationConfig config = RecommendationConfig(
    lowRecallThreshold: 0.5,
    lowPrecisionThreshold: 0.5,
    rareClassThreshold: 3,
    classImbalancePercentThreshold: 0.05,
    highConfidenceFpThreshold: 0.7,
    smallObjectRecallGapThreshold: 0.25,
    minIssueCountForCritical: 3,
  );

  test('low recall produces recommendation', () {
    final CocoDataset dataset = _dataset(
      annotations: [
        _gt(1, 1, 1, _box()),
        _gt(2, 2, 1, _box()),
        _gt(3, 3, 1, _box()),
      ],
    );
    final EvalResult evalResult = _evaluate(dataset, _run([]));

    final List<Recommendation> recommendations = _build(
      dataset,
      _run([]),
      evalResult,
      config,
    );

    expect(
      recommendations.any(
        (Recommendation r) =>
            r.title == 'Low recall for class "red"' &&
            r.category == RecommendationCategory.falseNegatives,
      ),
      isTrue,
    );
  });

  test('low precision produces recommendation', () {
    final CocoDataset dataset = _dataset();
    final ModelRun run = _run([
      _pred(1, 1, _box(x: 100), score: 0.9),
      _pred(2, 1, _box(x: 100), score: 0.8),
    ]);
    final EvalResult evalResult = _evaluate(dataset, run);

    final List<Recommendation> recommendations = _build(
      dataset,
      run,
      evalResult,
      config,
    );

    expect(
      recommendations.any(
        (Recommendation r) =>
            r.title == 'Low precision for class "red"' &&
            r.category == RecommendationCategory.falsePositives,
      ),
      isTrue,
    );
  });

  test('rare class produces recommendation', () {
    final CocoDataset dataset = _dataset(
      annotations: [_gt(1, 1, 1, _box())],
    );
    final ModelRun run = _run([_pred(1, 1, _box())]);
    final EvalResult evalResult = _evaluate(dataset, run);

    final List<Recommendation> recommendations = _build(
      dataset,
      run,
      evalResult,
      config,
    );

    expect(
      recommendations.any((Recommendation r) => r.title == 'Rare class "red"'),
      isTrue,
    );
  });

  test('class imbalance produces recommendation', () {
    final List<GroundTruthAnnotation> annotations = [
      _gt(1, 1, 1, _box()),
      for (int i = 0; i < 40; i += 1) _gt(100 + i, 2 + i, 2, _box()),
    ];
    final CocoDataset dataset = _dataset(
      imageCount: 50,
      categories: const {
        1: CategoryRecord(id: 1, name: 'red'),
        2: CategoryRecord(id: 2, name: 'yellow'),
      },
      annotations: annotations,
    );
    final ModelRun run = _run([]);
    final EvalResult evalResult = _evaluate(dataset, run);

    final List<Recommendation> recommendations = _build(
      dataset,
      run,
      evalResult,
      config,
    );

    expect(
      recommendations.any(
        (Recommendation r) =>
            r.category == RecommendationCategory.classImbalance,
      ),
      isTrue,
    );
  });

  test('small object gap produces recommendation', () {
    final CocoDataset dataset = _dataset(
      imageCount: 2,
      annotations: [
        _gt(1, 1, 1, _box(width: 10, height: 10), area: 100),
        _gt(2, 2, 1, _box(width: 50, height: 50), area: 2500),
      ],
    );
    final ModelRun run = _run([
      _pred(2, 1, _box(width: 50, height: 50), score: 0.9),
    ]);
    final EvalResult evalResult = _evaluate(dataset, run);

    final List<Recommendation> recommendations = _build(
      dataset,
      run,
      evalResult,
      config,
    );

    expect(
      recommendations.any(
        (Recommendation r) =>
            r.category == RecommendationCategory.smallObjects,
      ),
      isTrue,
    );
  });

  test('high confidence FP produces recommendation', () {
    final CocoDataset dataset = _dataset();
    final ModelRun run = _run([
      _pred(1, 1, _box(x: 120), score: 0.95),
    ]);
    final EvalResult evalResult = _evaluate(dataset, run);

    final List<Recommendation> recommendations = _build(
      dataset,
      run,
      evalResult,
      config,
    );

    expect(
      recommendations.any(
        (Recommendation r) =>
            r.title == 'High-confidence false positives' &&
            r.category == RecommendationCategory.scoreCalibration,
      ),
      isTrue,
    );
  });

  test('class confusion produces recommendation', () {
    final CocoDataset dataset = _dataset(
      categories: const {
        1: CategoryRecord(id: 1, name: 'red'),
        2: CategoryRecord(id: 2, name: 'green'),
      },
      annotations: [_gt(1, 1, 1, _box())],
    );
    final ModelRun run = _run([
      _pred(1, 2, _box(), score: 0.9),
    ]);
    final EvalResult evalResult = _evaluate(dataset, run);

    final List<Recommendation> recommendations = _build(
      dataset,
      run,
      evalResult,
      config,
    );

    expect(
      recommendations.any(
        (Recommendation r) =>
            r.title == 'Class confusion: "red" predicted as "green"',
      ),
      isTrue,
    );
  });

  test('dataset health errors produce recommendation', () {
    final CocoDataset dataset = _dataset();
    final ModelRun run = _run([]);
    final EvalResult evalResult = _evaluate(dataset, run);
    final DatasetHealthReport report = DatasetHealthReport(
      issues: const [
        DatasetHealthIssue(
          severity: DatasetIssueSeverity.error,
          type: DatasetIssueType.missingImageFile,
          title: 'Missing image',
          message: 'image_001.png is missing',
          imageId: 1,
          fileName: 'image_001.png',
        ),
      ],
      errorCount: 1,
      warningCount: 0,
      infoCount: 0,
      missingImageCount: 1,
      invalidAnnotationCount: 0,
      invalidPredictionCount: 0,
      imageWithoutGtCount: 0,
      unusedImageFileCount: 0,
      rareClassCount: 0,
      gtCountByClass: const {},
      gtPercentByClass: const {},
      generatedAt: DateTime(2026),
    );

    final List<Recommendation> recommendations = _build(
      dataset,
      run,
      evalResult,
      config,
      healthReport: report,
    );

    expect(
      recommendations.any(
        (Recommendation r) =>
            r.category == RecommendationCategory.datasetHealth &&
            r.severity == RecommendationSeverity.critical,
      ),
      isTrue,
    );
  });

  test('candidate regression produces recommendation', () {
    final CocoDataset dataset = _dataset();
    final ModelRun run = _run([]);
    final EvalResult evalResult = _evaluate(dataset, run);
    final ModelComparisonResult comparison = ModelComparisonResult(
      baseRunId: 'base',
      candidateRunId: 'candidate',
      overallDiff: _diff(),
      perClassDiffs: const [],
      imageSummaries: const [],
      fixedImageIds: const [],
      brokenImageIds: const [1],
      improvedImageIds: const [],
      regressedImageIds: const [2],
      unchangedCorrectImageIds: const [],
      unchangedWrongImageIds: const [],
    );

    final List<Recommendation> recommendations = _build(
      dataset,
      run,
      evalResult,
      config,
      comparison: comparison,
    );

    expect(
      recommendations.any(
        (Recommendation r) =>
            r.category == RecommendationCategory.modelComparison,
      ),
      isTrue,
    );
  });

  test('clean synthetic dataset does not produce critical recommendations', () {
    final CocoDataset dataset = _dataset(
      annotations: [_gt(1, 1, 1, _box())],
    );
    final ModelRun run = _run([_pred(1, 1, _box(), score: 0.9)]);
    final EvalResult evalResult = _evaluate(dataset, run);

    final List<Recommendation> recommendations = _build(
      dataset,
      run,
      evalResult,
      config,
    );

    expect(
      recommendations.where(
        (Recommendation r) => r.severity == RecommendationSeverity.critical,
      ),
      isEmpty,
    );
  });
}

List<Recommendation> _build(
  CocoDataset dataset,
  ModelRun run,
  EvalResult evalResult,
  RecommendationConfig config, {
  DatasetHealthReport? healthReport,
  ModelComparisonResult? comparison,
}) {
  return const RuleBasedRecommendationEngine().build(
    dataset: dataset,
    modelRun: run,
    evalResult: evalResult,
    evalConfig: const EvalConfig(),
    config: config,
    healthReport: healthReport,
    comparison: comparison,
  );
}

CocoDataset _dataset({
  int imageCount = 3,
  Map<int, CategoryRecord> categories = const {
    1: CategoryRecord(id: 1, name: 'red'),
  },
  List<GroundTruthAnnotation>? annotations,
}) {
  return CocoDataset(
    imagesById: {
      for (int i = 1; i <= imageCount; i += 1)
        i: ImageRecord(id: i, fileName: 'image_$i.png', width: 200, height: 200),
    },
    categoriesById: categories,
    annotations: annotations ?? const <GroundTruthAnnotation>[],
  );
}

ModelRun _run(List<Prediction> predictions) {
  return ModelRun(id: 'run', name: 'Run', predictions: predictions);
}

EvalResult _evaluate(CocoDataset dataset, ModelRun run) {
  return const MetricsCalculator().evaluate(
    dataset: dataset,
    modelRun: run,
    config: const EvalConfig(),
  );
}

GroundTruthAnnotation _gt(
  int id,
  int imageId,
  int categoryId,
  BBox bbox, {
  double? area,
}) {
  return GroundTruthAnnotation(
    id: id,
    imageId: imageId,
    categoryId: categoryId,
    bbox: bbox,
    area: area,
  );
}

Prediction _pred(
  int imageId,
  int categoryId,
  BBox bbox, {
  double score = 0.9,
}) {
  return Prediction(
    imageId: imageId,
    categoryId: categoryId,
    bbox: bbox,
    score: score,
  );
}

BBox _box({
  double x = 10,
  double y = 10,
  double width = 30,
  double height = 30,
}) {
  return BBox(x: x, y: y, width: width, height: height);
}

MetricsDiff _diff() {
  return const MetricsDiff(
    basePrecision: 1,
    candidatePrecision: 0.5,
    deltaPrecision: -0.5,
    baseRecall: 1,
    candidateRecall: 0.5,
    deltaRecall: -0.5,
    baseF1: 1,
    candidateF1: 0.5,
    deltaF1: -0.5,
    baseTp: 2,
    candidateTp: 1,
    deltaTp: -1,
    baseFp: 0,
    candidateFp: 1,
    deltaFp: 1,
    baseFn: 0,
    candidateFn: 1,
    deltaFn: 1,
    baseImagesWithErrors: 0,
    candidateImagesWithErrors: 2,
    deltaImagesWithErrors: 2,
  );
}
