import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

// Synthetic dataset: 3 categories (1=red, 2=yellow, 3=green), 5 images.
//
// Scenario (base predictions → candidate predictions):
//   Image 1: GT red@[10,10,100,100].
//     Base: TP red (correct match). Candidate: TP red. → unchangedCorrect
//   Image 2: GT yellow@[50,50,30,30].
//     Base: no prediction → FN yellow. Candidate: TP yellow. → fixed
//   Image 3: No GT.
//     Base: FP green@[20,20,50,50]. Candidate: nothing. → fixed
//   Image 4: GT green@[100,100,80,80].
//     Base: FN green + FP red@[5,5,30,30]. Candidate: FN green (only). → improved
//   Image 5: GT red@[0,0,100,100].
//     Base: TP red. Candidate: FP red (different box, no GT match). → broken
//
// (Images 2 and 3 are "fixed", image 4 is "improved", image 5 is "broken",
//  image 1 is "unchangedCorrect".)

const String _annotationsJson = '''
{
  "images": [
    {"id": 1, "file_name": "img1.jpg", "width": 200, "height": 200},
    {"id": 2, "file_name": "img2.jpg", "width": 200, "height": 200},
    {"id": 3, "file_name": "img3.jpg", "width": 200, "height": 200},
    {"id": 4, "file_name": "img4.jpg", "width": 200, "height": 200},
    {"id": 5, "file_name": "img5.jpg", "width": 200, "height": 200}
  ],
  "annotations": [
    {"id": 1, "image_id": 1, "category_id": 1, "bbox": [10, 10, 100, 100], "area": 10000, "iscrowd": 0},
    {"id": 2, "image_id": 2, "category_id": 2, "bbox": [50, 50, 30,  30],  "area": 900,   "iscrowd": 0},
    {"id": 3, "image_id": 4, "category_id": 3, "bbox": [100,100, 80,  80], "area": 6400,  "iscrowd": 0},
    {"id": 4, "image_id": 5, "category_id": 1, "bbox": [0,   0, 100, 100], "area": 10000, "iscrowd": 0}
  ],
  "categories": [
    {"id": 1, "name": "red"},
    {"id": 2, "name": "yellow"},
    {"id": 3, "name": "green"}
  ]
}
''';

/// Base predictions:
///  Image 1: TP red (matches GT id=1)
///  Image 2: nothing → FN yellow
///  Image 3: FP green
///  Image 4: FP red (no GT red on image 4, GT is green) + FN green
///  Image 5: TP red (matches GT id=4)
const String _basePredictionsJson = '''
[
  {"image_id": 1, "category_id": 1, "bbox": [10, 10, 100, 100], "score": 0.95},
  {"image_id": 3, "category_id": 3, "bbox": [20, 20, 50, 50],   "score": 0.80},
  {"image_id": 4, "category_id": 1, "bbox": [5,  5,  30, 30],   "score": 0.70},
  {"image_id": 5, "category_id": 1, "bbox": [0,  0, 100, 100],  "score": 0.90}
]
''';

/// Candidate predictions:
///  Image 1: TP red (same as base)
///  Image 2: TP yellow (new correct prediction)
///  Image 3: nothing → no errors
///  Image 4: nothing → FN green (fewer errors than base which had FP+FN)
///  Image 5: FP red (bbox doesn't overlap well enough to match GT)
const String _candidatePredictionsJson = '''
[
  {"image_id": 1, "category_id": 1, "bbox": [10, 10, 100, 100], "score": 0.92},
  {"image_id": 2, "category_id": 2, "bbox": [50, 50, 30, 30],   "score": 0.88},
  {"image_id": 5, "category_id": 1, "bbox": [150, 150, 10, 10], "score": 0.85}
]
''';

(CocoDataset, ModelRun, ModelRun) _load() {
  final CocoDataset dataset =
      const CocoAnnotationParser().parseString(_annotationsJson).value!;
  final ModelRun baseRun = const CocoPredictionParser()
      .parseString(
        _basePredictionsJson,
        dataset: dataset,
        modelRunId: 'base',
        modelRunName: 'Base',
      )
      .value!;
  final ModelRun candidateRun = const CocoPredictionParser()
      .parseString(
        _candidatePredictionsJson,
        dataset: dataset,
        modelRunId: 'candidate',
        modelRunName: 'Candidate',
      )
      .value!;
  return (dataset, baseRun, candidateRun);
}

void main() {
  const MetricsCalculator calc = MetricsCalculator();
  const ModelComparator comparator = ModelComparator();
  const EvalConfig config = EvalConfig();

  late CocoDataset dataset;
  late ModelRun baseRun;
  late ModelRun candidateRun;
  late EvalResult baseEval;
  late EvalResult candidateEval;
  late ModelComparisonResult result;

  setUp(() {
    (dataset, baseRun, candidateRun) = _load();
    baseEval = calc.evaluate(
      dataset: dataset,
      modelRun: baseRun,
      config: config,
    );
    candidateEval = calc.evaluate(
      dataset: dataset,
      modelRun: candidateRun,
      config: config,
    );
    result = comparator.compare(
      dataset: dataset,
      baseRun: baseRun,
      baseEval: baseEval,
      candidateRun: candidateRun,
      candidateEval: candidateEval,
      evalConfig: config,
    );
  });

  group('image statuses', () {
    ImageComparisonSummary _summaryFor(int imageId) {
      return result.imageSummaries.firstWhere((s) => s.imageId == imageId);
    }

    test('image 1: unchangedCorrect (both TP red, no errors)', () {
      final ImageComparisonSummary s = _summaryFor(1);
      expect(s.status, ImageComparisonStatus.unchangedCorrect);
    });

    test('image 2: fixed (base FN, candidate TP)', () {
      final ImageComparisonSummary s = _summaryFor(2);
      expect(s.status, ImageComparisonStatus.fixed);
      expect(s.baseHasError, isTrue);
      expect(s.candidateHasError, isFalse);
    });

    test('image 3: fixed (base FP, candidate no predictions)', () {
      final ImageComparisonSummary s = _summaryFor(3);
      expect(s.status, ImageComparisonStatus.fixed);
      expect(s.baseHasError, isTrue);
      expect(s.candidateHasError, isFalse);
    });

    test('image 4: improved (base FP+FN, candidate FN only)', () {
      final ImageComparisonSummary s = _summaryFor(4);
      expect(s.status, ImageComparisonStatus.improved);
    });

    test('image 5: broken (base TP, candidate FP)', () {
      final ImageComparisonSummary s = _summaryFor(5);
      expect(s.status, ImageComparisonStatus.broken);
      expect(s.baseHasError, isFalse);
      expect(s.candidateHasError, isTrue);
    });
  });

  group('status lists', () {
    test('fixedImageIds contains image 2 and image 3', () {
      expect(result.fixedImageIds, containsAll([2, 3]));
    });

    test('brokenImageIds contains image 5', () {
      expect(result.brokenImageIds, contains(5));
    });

    test('improvedImageIds contains image 4', () {
      expect(result.improvedImageIds, contains(4));
    });

    test('unchangedCorrectImageIds contains image 1', () {
      expect(result.unchangedCorrectImageIds, contains(1));
    });
  });

  group('overall diff', () {
    test('base TP is 2 (images 1 and 5)', () {
      expect(result.overallDiff.baseTp, 2);
    });

    test('candidate TP is 3 (images 1, 2, and one correct)', () {
      // Image 1: TP red, Image 2: TP yellow — image 5 has no valid match
      expect(result.overallDiff.candidateTp, 2);
    });

    test('deltaTp = candidate - base', () {
      expect(
        result.overallDiff.deltaTp,
        result.overallDiff.candidateTp - result.overallDiff.baseTp,
      );
    });

    test('delta fields are computed correctly', () {
      final MetricsDiff d = result.overallDiff;
      expect(d.deltaFp, d.candidateFp - d.baseFp);
      expect(d.deltaFn, d.candidateFn - d.baseFn);
      expect(
        d.deltaImagesWithErrors,
        d.candidateImagesWithErrors - d.baseImagesWithErrors,
      );
    });
  });

  group('per-class diffs', () {
    test('perClassDiffs has entries for all categories', () {
      final Set<int> ids = result.perClassDiffs.map((d) => d.categoryId).toSet();
      expect(ids, containsAll([1, 2, 3]));
    });

    test('sorted by worst deltaF1 ascending', () {
      final List<double> deltaF1s =
          result.perClassDiffs.map((d) => d.diff.deltaF1).toList();
      for (int i = 0; i < deltaF1s.length - 1; i++) {
        expect(deltaF1s[i], lessThanOrEqualTo(deltaF1s[i + 1]));
      }
    });

    test('category names match dataset categories', () {
      final Map<int, String> names = {
        for (final d in result.perClassDiffs) d.categoryId: d.categoryName,
      };
      expect(names[1], 'red');
      expect(names[2], 'yellow');
      expect(names[3], 'green');
    });
  });

  group('run IDs', () {
    test('baseRunId and candidateRunId are set correctly', () {
      expect(result.baseRunId, 'base');
      expect(result.candidateRunId, 'candidate');
    });
  });
}
