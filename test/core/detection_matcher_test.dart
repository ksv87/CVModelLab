import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const DetectionMatcher matcher = DetectionMatcher();

  test('one GT and one correct prediction produces TP', () {
    final dataset = _dataset(
      annotations: [
        _gt(1, imageId: 1, categoryId: 1),
      ],
    );
    final run = _run([
      _pred(imageId: 1, categoryId: 1, score: 0.9),
    ]);

    final matches = matcher.match(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );

    expect(matches.where(_isTp), hasLength(1));
    expect(matches.single.reason, DetectionMatchReason.matched);
  });

  test('one GT and no prediction produces FN', () {
    final dataset = _dataset(
      annotations: [
        _gt(1, imageId: 1, categoryId: 1),
      ],
    );
    final run = _run([]);

    final matches = matcher.match(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );

    expect(matches.where(_isFn), hasLength(1));
    expect(matches.single.reason, DetectionMatchReason.missedGroundTruth);
  });

  test('no GT and one prediction produces FP', () {
    final dataset = _dataset(annotations: []);
    final run = _run([
      _pred(imageId: 1, categoryId: 1, score: 0.9),
    ]);

    final matches = matcher.match(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );

    expect(matches.where(_isFp), hasLength(1));
    expect(matches.single.reason, DetectionMatchReason.noMatchingGroundTruth);
  });

  test('duplicate predictions produce one TP and one duplicate FP', () {
    final dataset = _dataset(
      annotations: [
        _gt(1, imageId: 1, categoryId: 1),
      ],
    );
    final run = _run([
      _pred(imageId: 1, categoryId: 1, score: 0.9),
      _pred(imageId: 1, categoryId: 1, score: 0.8, x: 1, y: 1),
    ]);

    final matches = matcher.match(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );

    expect(matches.where(_isTp), hasLength(1));
    expect(matches.where(_isFp), hasLength(1));
    expect(
      matches.where(_isFp).single.reason,
      DetectionMatchReason.duplicatePrediction,
    );
  });

  test('wrong class prediction is class-aware FP plus FN', () {
    final dataset = _dataset(
      annotations: [
        _gt(1, imageId: 1, categoryId: 2),
      ],
    );
    final run = _run([
      _pred(imageId: 1, categoryId: 1, score: 0.9),
    ]);

    final matches = matcher.match(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );

    expect(matches.where(_isFp), hasLength(1));
    expect(matches.where(_isFn), hasLength(1));
  });

  test('prediction below confidence threshold is ignored', () {
    final dataset = _dataset(
      annotations: [
        _gt(1, imageId: 1, categoryId: 1),
      ],
    );
    final run = _run([
      _pred(imageId: 1, categoryId: 1, score: 0.1),
    ]);

    final matches = matcher.match(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );

    expect(matches.where(_isTp), isEmpty);
    expect(matches.where(_isFp), isEmpty);
    expect(matches.where(_isFn), hasLength(1));
  });

  test('different IoU thresholds change result', () {
    final dataset = _dataset(
      annotations: [
        _gt(1, imageId: 1, categoryId: 1),
      ],
    );
    final run = _run([
      _pred(imageId: 1, categoryId: 1, score: 0.9, x: 20, y: 20),
    ]);

    final loose = matcher.match(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(iouThreshold: 0.45),
    );
    final strict = matcher.match(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(iouThreshold: 0.5),
    );

    expect(loose.where(_isTp), hasLength(1));
    expect(strict.where(_isTp), isEmpty);
    expect(strict.where(_isFp), hasLength(1));
    expect(strict.where(_isFn), hasLength(1));
  });
}

CocoDataset _dataset({required List<GroundTruthAnnotation> annotations}) {
  return CocoDataset(
    imagesById: {
      1: const ImageRecord(id: 1, fileName: 'image.jpg'),
    },
    categoriesById: {
      1: const CategoryRecord(id: 1, name: 'red'),
      2: const CategoryRecord(id: 2, name: 'yellow'),
    },
    annotations: annotations,
  );
}

ModelRun _run(List<Prediction> predictions) {
  return ModelRun(id: 'run', name: 'Run', predictions: predictions);
}

GroundTruthAnnotation _gt(
  int id, {
  required int imageId,
  required int categoryId,
}) {
  return GroundTruthAnnotation(
    id: id,
    imageId: imageId,
    categoryId: categoryId,
    bbox: const BBox(x: 0, y: 0, width: 100, height: 100),
  );
}

Prediction _pred({
  required int imageId,
  required int categoryId,
  required double score,
  double x = 0,
  double y = 0,
}) {
  return Prediction(
    imageId: imageId,
    categoryId: categoryId,
    bbox: BBox(x: x, y: y, width: 100, height: 100),
    score: score,
  );
}

bool _isTp(DetectionMatch match) =>
    match.type == DetectionMatchType.truePositive;
bool _isFp(DetectionMatch match) =>
    match.type == DetectionMatchType.falsePositive;
bool _isFn(DetectionMatch match) =>
    match.type == DetectionMatchType.falseNegative;
