import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

CocoDataset _dataset() {
  return CocoDataset(
    imagesById: const {
      1: ImageRecord(id: 1, fileName: 'i1.jpg', width: 200, height: 200),
      2: ImageRecord(id: 2, fileName: 'i2.jpg', width: 200, height: 200),
      3: ImageRecord(id: 3, fileName: 'i3.jpg', width: 200, height: 200),
      4: ImageRecord(id: 4, fileName: 'i4.jpg', width: 200, height: 200),
    },
    categoriesById: const {
      1: CategoryRecord(id: 1, name: 'red'),
      2: CategoryRecord(id: 2, name: 'green'),
    },
    annotations: const [
      GroundTruthAnnotation(
        id: 1,
        imageId: 1,
        categoryId: 1,
        bbox: BBox(x: 0, y: 0, width: 50, height: 50),
      ),
      GroundTruthAnnotation(
        id: 2,
        imageId: 2,
        categoryId: 1,
        bbox: BBox(x: 0, y: 0, width: 50, height: 50),
      ),
      GroundTruthAnnotation(
        id: 3,
        imageId: 2,
        categoryId: 1,
        bbox: BBox(x: 60, y: 0, width: 50, height: 50),
      ),
      GroundTruthAnnotation(
        id: 4,
        imageId: 4,
        categoryId: 2,
        bbox: BBox(x: 0, y: 0, width: 80, height: 80),
      ),
    ],
  );
}

ModelRun _modelRun() {
  return ModelRun(
    id: 'run',
    name: 'run',
    predictions: const [
      // img1: one TP, one high-confidence FP.
      Prediction(
        imageId: 1,
        categoryId: 1,
        bbox: BBox(x: 0, y: 0, width: 50, height: 50),
        score: 0.9,
      ),
      Prediction(
        imageId: 1,
        categoryId: 1,
        bbox: BBox(x: 100, y: 100, width: 20, height: 20),
        score: 0.95,
      ),
      // img3: two FPs (no GT).
      Prediction(
        imageId: 3,
        categoryId: 2,
        bbox: BBox(x: 0, y: 0, width: 30, height: 30),
        score: 0.8,
      ),
      Prediction(
        imageId: 3,
        categoryId: 2,
        bbox: BBox(x: 40, y: 40, width: 30, height: 30),
        score: 0.6,
      ),
    ],
  );
}

void main() {
  final CocoDataset dataset = _dataset();
  final ModelRun modelRun = _modelRun();
  final EvalResult evalResult = const MetricsCalculator().evaluate(
    dataset: dataset,
    modelRun: modelRun,
    config: const EvalConfig(),
  );
  final WorstCasesResult result = const WorstCaseMiner().mine(
    dataset: dataset,
    modelRun: modelRun,
    evalResult: evalResult,
    evalConfig: const EvalConfig(),
  );

  test('most errors ranked by fp+fn descending', () {
    expect(
      result.mostErrors.map((WorstCaseItem i) => i.imageId).toList(),
      [2, 3, 1, 4],
    );
  });

  test('most false positives ranked by fp descending', () {
    expect(
      result.mostFalsePositives.map((WorstCaseItem i) => i.imageId).toList(),
      [3, 1],
    );
  });

  test('most false negatives ranked by fn descending', () {
    expect(
      result.mostFalseNegatives.map((WorstCaseItem i) => i.imageId).toList(),
      [2, 4],
    );
  });

  test('high confidence FP ranked by max FP score descending', () {
    expect(
      result.highConfidenceFalsePositives
          .map((WorstCaseItem i) => i.imageId)
          .toList(),
      [1, 3],
    );
  });

  test('images without GT but with predictions', () {
    expect(
      result.imagesWithoutGtButWithPredictions
          .map((WorstCaseItem i) => i.imageId)
          .toList(),
      [3],
    );
  });

  test('images with GT but no predictions ranked by gt count descending', () {
    expect(
      result.imagesWithGtButNoPredictions
          .map((WorstCaseItem i) => i.imageId)
          .toList(),
      [2, 4],
    );
  });

  test('comparison categories are populated when a comparison is supplied', () {
    final EvalResult candidateEval = const MetricsCalculator().evaluate(
      dataset: dataset,
      // Candidate fixes image 3 by emitting no predictions there.
      modelRun: ModelRun(
        id: 'cand',
        name: 'cand',
        predictions: const [
          Prediction(
            imageId: 1,
            categoryId: 1,
            bbox: BBox(x: 0, y: 0, width: 50, height: 50),
            score: 0.9,
          ),
        ],
      ),
      config: const EvalConfig(),
    );
    final ModelComparisonResult comparison = const ModelComparator().compare(
      dataset: dataset,
      baseRun: modelRun,
      baseEval: evalResult,
      candidateRun: ModelRun(id: 'cand', name: 'cand', predictions: const []),
      candidateEval: candidateEval,
      evalConfig: const EvalConfig(),
    );
    final WorstCasesResult withComparison = const WorstCaseMiner().mine(
      dataset: dataset,
      modelRun: modelRun,
      evalResult: evalResult,
      evalConfig: const EvalConfig(),
      comparison: comparison,
    );
    expect(
      withComparison.fixedByCandidate.map((WorstCaseItem i) => i.imageId),
      contains(3),
    );
  });
}
