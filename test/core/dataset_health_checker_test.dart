import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

CocoDataset _dataset() {
  return CocoDataset(
    imagesById: const {
      1: ImageRecord(id: 1, fileName: 'a.jpg', width: 100, height: 100),
      2: ImageRecord(id: 2, fileName: 'b.jpg', width: 100, height: 100),
      3: ImageRecord(id: 3, fileName: 'b.jpg', width: 100, height: 100),
    },
    categoriesById: const {
      1: CategoryRecord(id: 1, name: 'red'),
      2: CategoryRecord(id: 2, name: 'yellow'),
      3: CategoryRecord(id: 3, name: 'green'),
    },
    annotations: const [
      // valid box on image 1
      GroundTruthAnnotation(
        id: 101,
        imageId: 1,
        categoryId: 1,
        bbox: BBox(x: 10, y: 10, width: 50, height: 50),
      ),
      // invalid (zero height) box
      GroundTruthAnnotation(
        id: 102,
        imageId: 1,
        categoryId: 1,
        bbox: BBox(x: 0, y: 0, width: 10, height: 0),
      ),
      // tiny box
      GroundTruthAnnotation(
        id: 103,
        imageId: 2,
        categoryId: 2,
        bbox: BBox(x: 1, y: 1, width: 3, height: 3),
      ),
      // box partially outside image 1 (100x100)
      GroundTruthAnnotation(
        id: 104,
        imageId: 1,
        categoryId: 1,
        bbox: BBox(x: 80, y: 80, width: 40, height: 40),
      ),
      // unknown image id
      GroundTruthAnnotation(
        id: 105,
        imageId: 999,
        categoryId: 1,
        bbox: BBox(x: 0, y: 0, width: 10, height: 10),
      ),
      // unknown category id
      GroundTruthAnnotation(
        id: 106,
        imageId: 2,
        categoryId: 42,
        bbox: BBox(x: 0, y: 0, width: 10, height: 10),
      ),
    ],
  );
}

void main() {
  const DatasetHealthChecker checker = DatasetHealthChecker();

  test('detects unknown image and category ids', () {
    final DatasetHealthReport report = checker.check(
      dataset: _dataset(),
      predictions: const [],
    );
    expect(
      report.issuesOfType(DatasetIssueType.unknownAnnotationImageId).length,
      1,
    );
    expect(
      report.issuesOfType(DatasetIssueType.unknownAnnotationCategoryId).length,
      1,
    );
  });

  test('detects invalid, tiny and partially-outside boxes', () {
    final DatasetHealthReport report = checker.check(
      dataset: _dataset(),
      predictions: const [],
    );
    expect(report.issuesOfType(DatasetIssueType.invalidBbox).length, 1);
    expect(report.issuesOfType(DatasetIssueType.tinyBbox).length, 1);
    expect(
      report.issuesOfType(DatasetIssueType.bboxPartiallyOutsideImage).length,
      1,
    );
  });

  test('detects duplicate file names', () {
    final DatasetHealthReport report = checker.check(
      dataset: _dataset(),
      predictions: const [],
    );
    final issues =
        report.issuesOfType(DatasetIssueType.duplicateFileName).toList();
    expect(issues.length, 1);
    expect(issues.single.fileName, 'b.jpg');
  });

  test('detects rare and empty classes', () {
    final DatasetHealthReport report = checker.check(
      dataset: _dataset(),
      predictions: const [],
      config: const DatasetHealthConfig(rareClassThreshold: 5),
    );
    // category 3 (green) has no valid GT.
    expect(
      report
          .issuesOfType(DatasetIssueType.classWithoutGroundTruth)
          .map((i) => i.categoryId),
      contains(3),
    );
    // category 1 (red) has 2 valid GT < 5 → rare.
    expect(
      report.issuesOfType(DatasetIssueType.rareClass).map((i) => i.categoryId),
      contains(1),
    );
  });

  test('detects unknown prediction image and category ids', () {
    final DatasetHealthReport report = checker.check(
      dataset: _dataset(),
      predictions: const [
        Prediction(
          imageId: 777,
          categoryId: 1,
          bbox: BBox(x: 0, y: 0, width: 5, height: 5),
          score: 0.9,
        ),
        Prediction(
          imageId: 1,
          categoryId: 88,
          bbox: BBox(x: 0, y: 0, width: 5, height: 5),
          score: 0.9,
        ),
      ],
    );
    expect(
      report.issuesOfType(DatasetIssueType.unknownPredictionImageId).length,
      1,
    );
    expect(
      report.issuesOfType(DatasetIssueType.unknownPredictionCategoryId).length,
      1,
    );
    expect(report.invalidPredictionCount, greaterThanOrEqualTo(2));
  });

  test('detects missing image files only when an image source is available',
      () {
    final CocoDataset dataset = _dataset();
    final DatasetHealthReport without = checker.check(
      dataset: dataset,
      predictions: const [],
    );
    expect(without.missingImageCount, 0);

    final DatasetHealthReport withSource = checker.check(
      dataset: dataset,
      predictions: const [],
      imageAvailability: const DatasetImageAvailability(
        missingFileNames: {'a.jpg'},
        unusedFileNames: {'orphan.jpg'},
      ),
    );
    expect(withSource.missingImageCount, 1);
    expect(withSource.unusedImageFileCount, 1);
    expect(
      withSource
          .issuesOfType(DatasetIssueType.missingImageFile)
          .single
          .fileName,
      'a.jpg',
    );
  });

  test('aggregate counts are consistent with issue list', () {
    final DatasetHealthReport report = checker.check(
      dataset: _dataset(),
      predictions: const [],
    );
    expect(
      report.errorCount + report.warningCount + report.infoCount,
      report.issues.length,
    );
  });
}
