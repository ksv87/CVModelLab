import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

// Synthetic dataset: 3 categories (1=red, 2=yellow, 3=green), 6 images, one GT
// box per image. Four model runs (A, B, C, D) with hand-crafted predictions so
// that every image-disagreement type is exercised:
//
//   img1 (GT red):    A,B,C,D all correct            → allCorrect
//   img2 (GT yellow): only A correct                 → onlyOneModelCorrect
//   img3 (GT green):  A,B,C correct, D wrong         → onlyOneModelWrong
//   img4 (GT red):    A,B correct, C,D wrong         → someModelsWrong
//   img5 (GT red):    all wrong, B has 4 extra FPs   → largeErrorSpread
//   img6 (GT red):    all wrong (only FN)            → allWrong
//
// Overall F1 ranking: A (0.8) > C (0.5) > B (0.46) > D (0.29).

const String _annotationsJson = '''
{
  "images": [
    {"id": 1, "file_name": "img1.jpg", "width": 2000, "height": 2000},
    {"id": 2, "file_name": "img2.jpg", "width": 2000, "height": 2000},
    {"id": 3, "file_name": "img3.jpg", "width": 2000, "height": 2000},
    {"id": 4, "file_name": "img4.jpg", "width": 2000, "height": 2000},
    {"id": 5, "file_name": "img5.jpg", "width": 2000, "height": 2000},
    {"id": 6, "file_name": "img6.jpg", "width": 2000, "height": 2000}
  ],
  "annotations": [
    {"id": 1, "image_id": 1, "category_id": 1, "bbox": [10, 10, 100, 100], "area": 10000, "iscrowd": 0},
    {"id": 2, "image_id": 2, "category_id": 2, "bbox": [10, 10, 100, 100], "area": 10000, "iscrowd": 0},
    {"id": 3, "image_id": 3, "category_id": 3, "bbox": [10, 10, 100, 100], "area": 10000, "iscrowd": 0},
    {"id": 4, "image_id": 4, "category_id": 1, "bbox": [10, 10, 100, 100], "area": 10000, "iscrowd": 0},
    {"id": 5, "image_id": 5, "category_id": 1, "bbox": [10, 10, 100, 100], "area": 10000, "iscrowd": 0},
    {"id": 6, "image_id": 6, "category_id": 1, "bbox": [10, 10, 100, 100], "area": 10000, "iscrowd": 0}
  ],
  "categories": [
    {"id": 1, "name": "red"},
    {"id": 2, "name": "yellow"},
    {"id": 3, "name": "green"}
  ]
}
''';

const String _predsA = '''
[
  {"image_id": 1, "category_id": 1, "bbox": [10, 10, 100, 100], "score": 0.9},
  {"image_id": 2, "category_id": 2, "bbox": [10, 10, 100, 100], "score": 0.9},
  {"image_id": 3, "category_id": 3, "bbox": [10, 10, 100, 100], "score": 0.9},
  {"image_id": 4, "category_id": 1, "bbox": [10, 10, 100, 100], "score": 0.9}
]
''';

const String _predsB = '''
[
  {"image_id": 1, "category_id": 1, "bbox": [10, 10, 100, 100], "score": 0.9},
  {"image_id": 3, "category_id": 3, "bbox": [10, 10, 100, 100], "score": 0.9},
  {"image_id": 4, "category_id": 1, "bbox": [10, 10, 100, 100], "score": 0.9},
  {"image_id": 5, "category_id": 1, "bbox": [500, 500, 10, 10], "score": 0.9},
  {"image_id": 5, "category_id": 1, "bbox": [520, 520, 10, 10], "score": 0.9},
  {"image_id": 5, "category_id": 1, "bbox": [540, 540, 10, 10], "score": 0.9},
  {"image_id": 5, "category_id": 1, "bbox": [560, 560, 10, 10], "score": 0.9}
]
''';

const String _predsC = '''
[
  {"image_id": 1, "category_id": 1, "bbox": [10, 10, 100, 100], "score": 0.9},
  {"image_id": 3, "category_id": 3, "bbox": [10, 10, 100, 100], "score": 0.9}
]
''';

const String _predsD = '''
[
  {"image_id": 1, "category_id": 1, "bbox": [10, 10, 100, 100], "score": 0.9}
]
''';

CocoDataset _dataset() =>
    const CocoAnnotationParser().parseString(_annotationsJson).value!;

ModelRun _run(CocoDataset dataset, String id, String name, String json) {
  return const CocoPredictionParser()
      .parseString(
        json,
        dataset: dataset,
        modelRunId: id,
        modelRunName: name,
      )
      .value!;
}

ApEvalResult _ap(double ap) => ApEvalResult(
      ap: ap,
      ap50: ap,
      ap75: ap,
      evaluatorName: 'test',
      generatedAt: DateTime.utc(2026, 1, 1),
      perClass: const [],
    );

void main() {
  const MultiModelComparator comparator = MultiModelComparator();
  const MetricsCalculator calc = MetricsCalculator();
  const EvalConfig config = EvalConfig();
  final DateTime fixedTime = DateTime.utc(2026, 1, 1);

  late CocoDataset dataset;
  late List<ModelRun> runs;
  late Map<String, EvalResult> evals;

  setUp(() {
    dataset = _dataset();
    runs = [
      _run(dataset, 'A', 'Model A', _predsA),
      _run(dataset, 'B', 'Model B', _predsB),
      _run(dataset, 'C', 'Model C', _predsC),
      _run(dataset, 'D', 'Model D', _predsD),
    ];
    evals = {
      for (final run in runs)
        run.id: calc.evaluate(dataset: dataset, modelRun: run, config: config),
    };
  });

  MultiModelComparisonResult run({
    Map<String, ApEvalResult>? ap,
    MultiModelComparisonConfig cfg = const MultiModelComparisonConfig.defaults(),
  }) {
    return comparator.compare(
      dataset: dataset,
      modelRuns: runs,
      evalResultsByRunId: evals,
      evalConfig: config,
      apResultsByRunId: ap,
      config: cfg,
      generatedAt: fixedTime,
    );
  }

  group('empty result', () {
    test('fewer than two runs returns an empty result', () {
      final MultiModelComparisonResult result = comparator.compare(
        dataset: dataset,
        modelRuns: [runs.first],
        evalResultsByRunId: {runs.first.id: evals[runs.first.id]!},
        evalConfig: config,
        generatedAt: fixedTime,
      );
      expect(result.isEmpty, isTrue);
      expect(result.leaderboard, isEmpty);
    });
  });

  group('leaderboard', () {
    test('sorts by F1 descending by default (A, C, B, D)', () {
      final List<String> order =
          run().leaderboard.map((e) => e.modelRunId).toList();
      expect(order, ['A', 'C', 'B', 'D']);
      // Monotonically non-increasing F1.
      final List<double> f1s = run().leaderboard.map((e) => e.f1).toList();
      for (int i = 0; i < f1s.length - 1; i++) {
        expect(f1s[i], greaterThanOrEqualTo(f1s[i + 1]));
      }
    });

    test('assigns ranks 1..n in order', () {
      final List<int> ranks =
          run().leaderboard.map((e) => e.rank).toList();
      expect(ranks, [1, 2, 3, 4]);
    });

    test('sorts by AP when primaryMetric is ap', () {
      final result = run(
        ap: {'A': _ap(0.9), 'B': _ap(0.8), 'C': _ap(0.7), 'D': _ap(0.6)},
        cfg: const MultiModelComparisonConfig(
          primaryMetric: MultiModelRankingMetric.ap,
        ),
      );
      expect(
        result.leaderboard.map((e) => e.modelRunId).toList(),
        ['A', 'B', 'C', 'D'],
      );
      expect(result.leaderboard.first.ap, 0.9);
    });

    test('handles missing AP metrics without crashing', () {
      final result = run(
        cfg: const MultiModelComparisonConfig(
          primaryMetric: MultiModelRankingMetric.ap,
        ),
      );
      expect(result.leaderboard.length, 4);
      expect(result.leaderboard.every((e) => e.ap == null), isTrue);
    });

    test('counts TP/FP/FN correctly for model A', () {
      final entry =
          run().leaderboard.firstWhere((e) => e.modelRunId == 'A');
      expect(entry.totalTp, 4);
      expect(entry.totalFp, 0);
      expect(entry.totalFn, 2);
    });
  });

  group('isHigherBetter helper', () {
    test('quality metrics higher is better, error metrics lower is better', () {
      expect(isHigherBetter(MultiModelRankingMetric.f1), isTrue);
      expect(isHigherBetter(MultiModelRankingMetric.ap), isTrue);
      expect(isHigherBetter(MultiModelRankingMetric.tp), isTrue);
      expect(isHigherBetter(MultiModelRankingMetric.fp), isFalse);
      expect(isHigherBetter(MultiModelRankingMetric.fn), isFalse);
      expect(isHigherBetter(MultiModelRankingMetric.imagesWithErrors), isFalse);
    });
  });

  group('per-class ranking', () {
    test('detects best/worst model for class red', () {
      final result = run();
      final ClassModelRanking red =
          result.perClassRankings.firstWhere((r) => r.categoryId == 1);
      expect(red.bestModelRunId, 'A');
      expect(red.bestF1, greaterThan(red.worstF1!));
      expect(red.entries.length, 4);
    });

    test('sorts class rankings by F1 spread descending', () {
      final List<double> spreads =
          run().perClassRankings.map((r) => r.f1Spread).toList();
      for (int i = 0; i < spreads.length - 1; i++) {
        expect(spreads[i], greaterThanOrEqualTo(spreads[i + 1]));
      }
    });
  });

  group('image disagreement', () {
    ImageModelDisagreement forImage(int id) =>
        run().imageDisagreements.firstWhere((d) => d.imageId == id);

    test('img1 allCorrect', () {
      expect(forImage(1).type, ImageDisagreementType.allCorrect);
      expect(forImage(1).modelsCorrectCount, 4);
    });

    test('img2 onlyOneModelCorrect', () {
      expect(forImage(2).type, ImageDisagreementType.onlyOneModelCorrect);
      expect(forImage(2).modelsCorrectCount, 1);
    });

    test('img3 onlyOneModelWrong', () {
      expect(forImage(3).type, ImageDisagreementType.onlyOneModelWrong);
      expect(forImage(3).modelsWrongCount, 1);
    });

    test('img4 someModelsWrong', () {
      expect(forImage(4).type, ImageDisagreementType.someModelsWrong);
      expect(forImage(4).modelsCorrectCount, 2);
      expect(forImage(4).modelsWrongCount, 2);
    });

    test('img5 largeErrorSpread', () {
      final d = forImage(5);
      expect(d.type, ImageDisagreementType.largeErrorSpread);
      expect(d.errorSpread, greaterThanOrEqualTo(3));
    });

    test('img6 allWrong', () {
      expect(forImage(6).type, ImageDisagreementType.allWrong);
      expect(forImage(6).modelsCorrectCount, 0);
    });

    test('per-model status records FPs and FNs', () {
      final d = forImage(5);
      final ImageModelStatus b =
          d.modelStatuses.firstWhere((s) => s.modelRunId == 'B');
      expect(b.fp, 4);
      expect(b.fn, 1);
      expect(b.hasHighConfidenceFp, isTrue);
      expect(b.maxFpScore, 0.9);
    });
  });

  group('pairwise regression matrix', () {
    test('contains all non-diagonal ordered pairs', () {
      final result = run();
      expect(result.pairwiseRegressionMatrix.length, 4 * 3);
      for (final p in result.pairwiseRegressionMatrix) {
        expect(p.baseModelRunId, isNot(p.candidateModelRunId));
      }
      final Set<String> pairs = {
        for (final p in result.pairwiseRegressionMatrix)
          '${p.baseModelRunId}->${p.candidateModelRunId}',
      };
      expect(pairs, contains('A->D'));
      expect(pairs, contains('D->A'));
      expect(pairs.length, 12);
    });

    test('delta values are correct (A base, D candidate)', () {
      final result = run();
      final p = result.pairwiseRegressionMatrix.firstWhere(
        (e) => e.baseModelRunId == 'A' && e.candidateModelRunId == 'D',
      );
      // A has 4 TP, D has 1 TP → delta = -3.
      expect(p.deltaTp, -3);
      expect(p.deltaF1, lessThan(0));
    });

    test('deltaAp present only when both runs have AP', () {
      final result = run(ap: {'A': _ap(0.9), 'D': _ap(0.6)});
      final ad = result.pairwiseRegressionMatrix.firstWhere(
        (e) => e.baseModelRunId == 'A' && e.candidateModelRunId == 'D',
      );
      expect(ad.deltaAp, closeTo(-0.3, 1e-9));
      final bc = result.pairwiseRegressionMatrix.firstWhere(
        (e) => e.baseModelRunId == 'B' && e.candidateModelRunId == 'C',
      );
      expect(bc.deltaAp, isNull);
    });
  });

  group('consensus summary', () {
    test('aggregates image-level agreement counts', () {
      final ModelConsensusSummary c = run().consensusSummary.single;
      expect(c.totalImages, 6);
      expect(c.allModelsCorrect, 1);
      expect(c.allModelsWrong, 2);
      expect(c.someModelsWrong, 3);
      expect(c.onlyOneModelCorrect, 1);
      expect(c.onlyOneModelWrong, 1);
    });
  });

  group('determinism', () {
    test('produces identical leaderboard order on repeated runs', () {
      final first = run().leaderboard.map((e) => e.modelRunId).toList();
      final second = run().leaderboard.map((e) => e.modelRunId).toList();
      expect(first, second);
    });
  });
}
