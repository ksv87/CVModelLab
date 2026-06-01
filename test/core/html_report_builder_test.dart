import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = HtmlReportBuilder();

  String buildFor(_Fixture fixture, {Set<String> missing = const <String>{}}) {
    return builder.build(
      dataset: fixture.dataset,
      modelRun: fixture.modelRun,
      evalConfig: fixture.evalResult.config,
      evalResult: fixture.evalResult,
      projectName: 'Demo project',
      modelRunName: 'Demo run',
      generatedAt: DateTime.utc(2026, 6, 1, 12),
      missingImageFileNames: missing,
    );
  }

  test('contains project and model run names', () {
    final html = buildFor(_fixture());
    expect(html, contains('Demo project'));
    expect(html, contains('Demo run'));
  });

  test('contains IoU and confidence thresholds', () {
    final fixture = _fixture(
      config: const EvalConfig(iouThreshold: 0.5, confidenceThreshold: 0.25),
    );
    final html = buildFor(fixture);
    expect(html, contains('IoU threshold'));
    expect(html, contains('0.5'));
    expect(html, contains('Confidence threshold'));
    expect(html, contains('0.25'));
  });

  test('contains overall metrics and per-class table', () {
    final html = buildFor(_fixture());
    expect(html, contains('Overall metrics'));
    expect(html, contains('Per-class metrics'));
    expect(html, contains('Precision'));
    expect(html, contains('Recall'));
    expect(html, contains('<table'));
  });

  test('highlights a weak class', () {
    // "yellow" has GT but no predictions -> recall 0 -> highlighted as weak.
    final html = buildFor(_fixture());
    expect(html, contains('yellow'));
    expect(html, contains('class="weak"'));
  });

  test('does not crash on empty predictions', () {
    final fixture = _fixture(withPredictions: false);
    expect(() => buildFor(fixture), returnsNormally);
    final html = buildFor(fixture);
    expect(html, contains('CV Model Lab Report'));
  });

  test('does not crash on missing images', () {
    final fixture = _fixture();
    final html = buildFor(fixture, missing: <String>{'missing.jpg'});
    expect(html, contains('Missing image files'));
  });

  test('escapes html in category names', () {
    final fixture = _fixture(redName: '<b>red</b>');
    final html = buildFor(fixture);
    expect(html, contains('&lt;b&gt;red'));
    expect(html, isNot(contains('<b>red</b>')));
  });
}

_Fixture _fixture({
  String redName = 'red',
  bool withPredictions = true,
  EvalConfig config = const EvalConfig(iouThreshold: 0.5),
}) {
  final dataset = CocoDataset(
    imagesById: const {
      1: ImageRecord(id: 1, fileName: 'tp.jpg', width: 200, height: 200),
      2: ImageRecord(id: 2, fileName: 'fp.jpg', width: 200, height: 200),
      3: ImageRecord(id: 3, fileName: 'missing.jpg', width: 200, height: 200),
    },
    categoriesById: {
      1: CategoryRecord(id: 1, name: redName),
      2: const CategoryRecord(id: 2, name: 'yellow'),
    },
    annotations: <GroundTruthAnnotation>[
      _gt(1, imageId: 1, categoryId: 1, x: 0, y: 0, w: 100, h: 100),
      _gt(2, imageId: 3, categoryId: 2, x: 0, y: 0, w: 100, h: 100),
    ],
  );
  final run = ModelRun(
    id: 'run',
    name: 'Run',
    predictions: withPredictions
        ? <Prediction>[
            _pred(
              imageId: 1,
              categoryId: 1,
              score: 0.9,
              x: 0,
              y: 0,
              w: 100,
              h: 100,
            ),
            _pred(
              imageId: 2,
              categoryId: 1,
              score: 0.95,
              x: 0,
              y: 0,
              w: 50,
              h: 50,
            ),
          ]
        : const <Prediction>[],
  );
  final evalResult = const MetricsCalculator().evaluate(
    dataset: dataset,
    modelRun: run,
    config: config,
  );
  return _Fixture(dataset, run, evalResult);
}

GroundTruthAnnotation _gt(
  int id, {
  required int imageId,
  required int categoryId,
  required double x,
  required double y,
  required double w,
  required double h,
}) {
  return GroundTruthAnnotation(
    id: id,
    imageId: imageId,
    categoryId: categoryId,
    bbox: BBox(x: x, y: y, width: w, height: h),
  );
}

Prediction _pred({
  required int imageId,
  required int categoryId,
  required double score,
  required double x,
  required double y,
  required double w,
  required double h,
}) {
  return Prediction(
    imageId: imageId,
    categoryId: categoryId,
    bbox: BBox(x: x, y: y, width: w, height: h),
    score: score,
  );
}

class _Fixture {
  const _Fixture(this.dataset, this.modelRun, this.evalResult);

  final CocoDataset dataset;
  final ModelRun modelRun;
  final EvalResult evalResult;
}
