import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

CocoDataset _dataset() {
  return CocoDataset(
    imagesById: const {
      1: ImageRecord(id: 1, fileName: 'a/i1.jpg', width: 100, height: 100),
      2: ImageRecord(id: 2, fileName: 'i2.png', width: 100, height: 100),
      3: ImageRecord(id: 3, fileName: 'i3.jpg', width: 100, height: 100),
    },
    categoriesById: const {1: CategoryRecord(id: 1, name: 'red')},
    annotations: const [
      GroundTruthAnnotation(
        id: 1,
        imageId: 1,
        categoryId: 1,
        bbox: BBox(x: 0, y: 0, width: 10, height: 10),
      ),
      GroundTruthAnnotation(
        id: 2,
        imageId: 3,
        categoryId: 1,
        bbox: BBox(x: 0, y: 0, width: 10, height: 10),
      ),
    ],
  );
}

ModelRun _modelRun() {
  return ModelRun(
    id: 'r',
    name: 'r',
    predictions: const [
      // image 1: TP (matches GT).
      Prediction(
        imageId: 1,
        categoryId: 1,
        bbox: BBox(x: 0, y: 0, width: 10, height: 10),
        score: 0.9,
      ),
      // image 2: FP (no GT).
      Prediction(
        imageId: 2,
        categoryId: 1,
        bbox: BBox(x: 0, y: 0, width: 10, height: 10),
        score: 0.9,
      ),
      // image 2: a second FP so it outranks others by fp count.
      Prediction(
        imageId: 2,
        categoryId: 1,
        bbox: BBox(x: 50, y: 50, width: 10, height: 10),
        score: 0.8,
      ),
      // image 3: GT exists, no matching prediction → FN.
    ],
  );
}

void main() {
  const AnnotatedExportSelector selector = AnnotatedExportSelector();
  final CocoDataset dataset = _dataset();
  final EvalResult evalResult = const MetricsCalculator().evaluate(
    dataset: dataset,
    modelRun: _modelRun(),
    config: const EvalConfig(),
  );

  test('current image scope returns only the selected image', () {
    final List<int> ids = selector.selectImageIds(
      config: const AnnotatedImageExportConfig(),
      evalResult: evalResult,
      currentImageId: 2,
    );
    expect(ids, [2]);
  });

  test('false positive scope selects images with FP sorted by fp count', () {
    final List<int> ids = selector.selectImageIds(
      config: const AnnotatedImageExportConfig(
        scope: AnnotatedExportScope.falsePositiveImages,
      ),
      evalResult: evalResult,
    );
    expect(ids.first, 2); // image 2 has the most FPs
    expect(ids, isNot(contains(1))); // image 1 is a clean TP
  });

  test('false negative scope selects images with FN', () {
    final List<int> ids = selector.selectImageIds(
      config: const AnnotatedImageExportConfig(
        scope: AnnotatedExportScope.falseNegativeImages,
      ),
      evalResult: evalResult,
    );
    expect(ids, contains(3));
  });

  test('filtered scope passes through the supplied filtered ids', () {
    final List<int> ids = selector.selectImageIds(
      config: const AnnotatedImageExportConfig(
        scope: AnnotatedExportScope.currentFilteredImages,
      ),
      evalResult: evalResult,
      filteredImageIds: const [3, 1],
    );
    expect(ids, [3, 1]);
  });

  test('maxImages caps the number of resolved targets', () {
    final List<AnnotatedExportTarget> targets = selector.resolveTargets(
      config: const AnnotatedImageExportConfig(
        scope: AnnotatedExportScope.currentFilteredImages,
        maxImages: 2,
      ),
      dataset: dataset,
      evalResult: evalResult,
      filteredImageIds: const [1, 2, 3],
    );
    expect(targets.length, 2);
    expect(targets.map((AnnotatedExportTarget t) => t.imageId), [1, 2]);
  });

  test('file name template is expanded and sanitized to a safe png name', () {
    final String name = AnnotatedExportSelector.buildFileName(
      template: '{index}_{status}_{fileName}',
      index: 0,
      status: 'fp',
      fileName: 'a/sub dir/img 01.jpg',
      imageId: 7,
    );
    expect(name, '0_fp_img_01.png');
    expect(name.contains('/'), isFalse);
    expect(name.contains(' '), isFalse);
  });

  test('comparison scope returns empty when no comparison is supplied', () {
    final List<int> ids = selector.selectImageIds(
      config: const AnnotatedImageExportConfig(
        scope: AnnotatedExportScope.comparisonFixedImages,
      ),
      evalResult: evalResult,
    );
    expect(ids, isEmpty);
  });
}
