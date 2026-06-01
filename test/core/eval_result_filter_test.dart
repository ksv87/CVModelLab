import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filters images with FP', () {
    final fixture = _fixture();
    final view = _filter(
      fixture,
      const EvalViewFilter(imageFilter: EvalImageFilter.falsePositive),
    );

    expect(view.filteredImageIds, containsAll(<int>[2, 3, 5]));
    expect(view.filteredImageIds, isNot(contains(1)));
  });

  test('filters images with FN', () {
    final fixture = _fixture();
    final view = _filter(
      fixture,
      const EvalViewFilter(imageFilter: EvalImageFilter.falseNegative),
    );

    expect(view.filteredImageIds, containsAll(<int>[3, 4]));
    expect(view.filteredImageIds, isNot(contains(2)));
  });

  test('filters images with any error', () {
    final fixture = _fixture();
    final view = _filter(
      fixture,
      const EvalViewFilter(imageFilter: EvalImageFilter.anyError),
    );

    expect(view.filteredImageIds, containsAll(<int>[2, 3, 4, 5]));
    expect(view.filteredImageIds, isNot(contains(1)));
  });

  test('filters by class', () {
    final fixture = _fixture();
    final view = _filter(
      fixture,
      const EvalViewFilter(
        imageFilter: EvalImageFilter.anyError,
        selectedClassIds: <int>{2},
      ),
    );

    expect(view.filteredImageIds, containsAll(<int>[3, 4]));
    expect(view.filteredImageIds, isNot(contains(2)));
  });

  test('filters by small objects', () {
    final fixture = _fixture();
    final view = _filter(
      fixture,
      const EvalViewFilter(imageFilter: EvalImageFilter.smallObjects),
    );

    expect(view.filteredImageIds, contains(4));
    expect(view.imageSummaries[4]!.hasSmallObject, isTrue);
  });

  test('filters high confidence FP', () {
    final fixture = _fixture();
    final view = _filter(
      fixture,
      const EvalViewFilter(
        imageFilter: EvalImageFilter.highConfidenceFalsePositive,
      ),
    );

    expect(view.filteredImageIds, contains(2));
    expect(view.filteredImageIds, isNot(contains(5)));
  });

  test('filters low IoU TP', () {
    final fixture = _fixture();
    final view = _filter(
      fixture,
      const EvalViewFilter(imageFilter: EvalImageFilter.lowIouTruePositive),
    );

    expect(view.filteredImageIds, contains(6));
  });

  test('filters missing images', () {
    final fixture = _fixture();
    final view = _filter(
      fixture,
      const EvalViewFilter(imageFilter: EvalImageFilter.missingImages),
      missing: <String>{'missing.jpg'},
    );

    expect(view.filteredImageIds, <int>[4]);
  });

  test('threshold change affects EvalResult', () {
    final fixture = _fixture();
    final loose = const MetricsCalculator().evaluate(
      dataset: fixture.dataset,
      modelRun: fixture.modelRun,
      config: const EvalConfig(iouThreshold: 0.4),
    );
    final strict = const MetricsCalculator().evaluate(
      dataset: fixture.dataset,
      modelRun: fixture.modelRun,
      config: const EvalConfig(iouThreshold: 0.9),
    );

    expect(loose.overall.totalTp, greaterThan(strict.overall.totalTp));
    expect(strict.overall.totalFn, greaterThan(loose.overall.totalFn));
  });

  test('view filter does not require recomputing matcher', () {
    final fixture = _fixture();
    final before = fixture.evalResult.matches;
    final view = _filter(
      fixture,
      const EvalViewFilter(
        enabledMatchTypes: <DetectionMatchType>{
          DetectionMatchType.falsePositive,
        },
      ),
    );

    expect(identical(before, fixture.evalResult.matches), isTrue);
    expect(view.visibleMatchesForImage(1), isEmpty);
    expect(
      view
          .visibleMatchesForImage(2)
          .every((match) => match.type == DetectionMatchType.falsePositive),
      isTrue,
    );
  });
}

FilteredEvalView _filter(
  _Fixture fixture,
  EvalViewFilter filter, {
  Set<String> missing = const <String>{},
}) {
  return const EvalResultFilter().apply(
    dataset: fixture.dataset,
    modelRun: fixture.modelRun,
    evalResult: fixture.evalResult,
    missingImageFileNames: missing,
    filter: filter,
  );
}

_Fixture _fixture() {
  final dataset = CocoDataset(
    imagesById: const {
      1: ImageRecord(id: 1, fileName: 'tp.jpg', width: 200, height: 200),
      2: ImageRecord(id: 2, fileName: 'fp.jpg', width: 200, height: 200),
      3: ImageRecord(id: 3, fileName: 'confusion.jpg', width: 200, height: 200),
      4: ImageRecord(id: 4, fileName: 'missing.jpg', width: 200, height: 200),
      5: ImageRecord(id: 5, fileName: 'duplicate.jpg', width: 200, height: 200),
      6: ImageRecord(id: 6, fileName: 'low_iou.jpg', width: 200, height: 200),
    },
    categoriesById: const {
      1: CategoryRecord(id: 1, name: 'red'),
      2: CategoryRecord(id: 2, name: 'yellow'),
    },
    annotations: <GroundTruthAnnotation>[
      _gt(1, imageId: 1, categoryId: 1, x: 0, y: 0, w: 100, h: 100),
      _gt(2, imageId: 3, categoryId: 2, x: 0, y: 0, w: 100, h: 100),
      _gt(3, imageId: 4, categoryId: 2, x: 10, y: 10, w: 20, h: 20),
      _gt(4, imageId: 5, categoryId: 1, x: 0, y: 0, w: 100, h: 100),
      _gt(5, imageId: 6, categoryId: 1, x: 0, y: 0, w: 100, h: 100),
    ],
  );
  final run = ModelRun(
    id: 'run',
    name: 'Run',
    predictions: <Prediction>[
      _pred(imageId: 1, categoryId: 1, score: 0.9, x: 0, y: 0, w: 100, h: 100),
      _pred(imageId: 2, categoryId: 1, score: 0.95, x: 0, y: 0, w: 50, h: 50),
      _pred(imageId: 3, categoryId: 1, score: 0.9, x: 0, y: 0, w: 100, h: 100),
      _pred(imageId: 5, categoryId: 1, score: 0.9, x: 0, y: 0, w: 100, h: 100),
      _pred(imageId: 5, categoryId: 1, score: 0.6, x: 1, y: 1, w: 100, h: 100),
      _pred(
        imageId: 6,
        categoryId: 1,
        score: 0.9,
        x: 20,
        y: 20,
        w: 100,
        h: 100,
      ),
    ],
  );
  final evalResult = const MetricsCalculator().evaluate(
    dataset: dataset,
    modelRun: run,
    config: const EvalConfig(iouThreshold: 0.45),
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
