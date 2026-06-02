import 'dart:io';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CocoDataset dataset;
  late ModelRun run;

  setUp(() {
    dataset = const CocoAnnotationParser()
        .parseString(
          File('test_data/mini_coco/annotations.json').readAsStringSync(),
        )
        .value!;
    run = const CocoPredictionParser()
        .parseString(
          File('test_data/mini_coco/predictions.json').readAsStringSync(),
          dataset: dataset,
          modelRunId: 'run-1',
          modelRunName: 'Run 1',
        )
        .value!;
  });

  test('detail counts match the plain confusion matrix', () {
    final ConfusionMatrixDetails details =
        const ConfusionMatrixDetailBuilder().build(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );
    expect(details.matrix.count('red', 'red'), 2);
    expect(details.matrix.count('green', 'red'), 1);
    expect(details.matrix.count('yellow', missedColumn), 1);
    expect(details.matrix.count(backgroundFpRow, 'green'), 1);
  });

  test('cell examples expose the image ids behind a confusion', () {
    final ConfusionMatrixDetails details =
        const ConfusionMatrixDetailBuilder().build(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );
    // GT green confused as Pred red happens on image 4.
    final List<ConfusionCellExample> greenAsRed =
        details.examples('green', 'red');
    expect(greenAsRed.map((ConfusionCellExample e) => e.imageId), contains(4));

    // Missed yellow is on image 2.
    final List<ConfusionCellExample> missedYellow =
        details.examples('yellow', missedColumn);
    expect(
      missedYellow.map((ConfusionCellExample e) => e.imageId),
      contains(2),
    );
  });

  test('pairs() hides the diagonal and sorts by count', () {
    final ConfusionMatrixDetails details =
        const ConfusionMatrixDetailBuilder().build(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );
    final List<ConfusionPair> errors = details.pairs();
    expect(errors.every((ConfusionPair p) => p.isError), isTrue);
    expect(
      errors
          .any((ConfusionPair p) => p.gtClass == 'red' && p.predClass == 'red'),
      isFalse,
    );
    // Counts must be non-increasing.
    for (int i = 1; i < errors.length; i++) {
      expect(errors[i - 1].count >= errors[i].count, isTrue);
    }

    final List<ConfusionPair> withDiagonal =
        details.pairs(includeDiagonal: true);
    expect(
      withDiagonal
          .any((ConfusionPair p) => p.gtClass == 'red' && p.predClass == 'red'),
      isTrue,
    );
  });

  test('row percent is relative to the GT row total', () {
    final ConfusionMatrixDetails details =
        const ConfusionMatrixDetailBuilder().build(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );
    // green row: green→red (1) + green→missed (1) = 2 total.
    final ConfusionPair greenAsRed = details.pairs().firstWhere(
          (ConfusionPair p) => p.gtClass == 'green' && p.predClass == 'red',
        );
    expect(greenAsRed.rowPercent, closeTo(0.5, 1e-9));
  });

  test('row total is recall direction, column total is precision direction',
      () {
    final ConfusionMatrixDetails details =
        const ConfusionMatrixDetailBuilder().build(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );

    // rowTotal / columnTotal must equal the manual sums over the matrix.
    for (final String row in details.matrix.counts.keys) {
      final int manualRow = details.matrix.counts[row]!.values
          .fold(0, (int sum, int v) => sum + v);
      expect(details.rowTotal(row), manualRow);
    }
    for (final String column in {
      for (final Map<String, int> r in details.matrix.counts.values) ...r.keys,
    }) {
      int manualColumn = 0;
      for (final Map<String, int> r in details.matrix.counts.values) {
        manualColumn += r[column] ?? 0;
      }
      expect(details.columnTotal(column), manualColumn);
    }

    // 'red' column receives red→red (2) and green→red (1): precision = 2/3,
    // distinct from red recall (red row total includes the missed column).
    expect(details.columnTotal('red'), greaterThanOrEqualTo(3));
    final double precisionRed =
        details.matrix.count('red', 'red') / details.columnTotal('red');
    expect(
      precisionRed,
      closeTo(2 / details.columnTotal('red'), 1e-9),
    );
  });

  test(
      'includes dataset classes as prediction columns even with zero predictions',
      () {
    final ConfusionMatrixDetails details =
        const ConfusionMatrixDetailBuilder().build(
      dataset: dataset,
      modelRun: ModelRun(
        id: 'empty',
        name: 'empty',
        predictions: const [],
      ),
      config: const EvalConfig(),
    );

    for (final CategoryRecord category in dataset.categoriesById.values) {
      expect(details.matrix.counts['red']!.containsKey(category.name), isTrue);
      expect(
        details.matrix.counts['yellow']!.containsKey(category.name),
        isTrue,
      );
      expect(
        details.matrix.counts['green']!.containsKey(category.name),
        isTrue,
      );
    }
  });
}
