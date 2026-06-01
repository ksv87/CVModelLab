import 'dart:io';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates per-class and overall stats on mini dataset', () {
    final CocoDataset dataset = CocoAnnotationParser()
        .parseString(
          File('test_data/mini_coco/annotations.json').readAsStringSync(),
        )
        .value!;
    final ModelRun run = CocoPredictionParser()
        .parseString(
          File('test_data/mini_coco/predictions.json').readAsStringSync(),
          dataset: dataset,
          modelRunId: 'run-1',
          modelRunName: 'Run 1',
        )
        .value!;

    final EvalResult result = const MetricsCalculator().evaluate(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );

    expect(result.overall.totalImages, 5);
    expect(result.overall.totalGt, 5);
    expect(result.overall.totalPredictionsBeforeThreshold, 6);
    expect(result.overall.totalPredictionsAfterThreshold, 5);
    expect(result.overall.totalTp, 2);
    expect(result.overall.totalFp, 3);
    expect(result.overall.totalFn, 3);
    expect(result.overall.microPrecision, closeTo(2 / 5, 1e-6));
    expect(result.overall.microRecall, closeTo(2 / 5, 1e-6));

    final ClassStats red = result.perClassStats[1]!;
    expect(red.gtCount, 2);
    expect(red.predCount, 4);
    expect(red.tp, 2);
    expect(red.fp, 2);
    expect(red.fn, 0);
    expect(red.precision, closeTo(0.5, 1e-6));
    expect(red.recall, closeTo(1, 1e-6));

    final ClassStats yellow = result.perClassStats[2]!;
    expect(yellow.gtCount, 1);
    expect(yellow.predCount, 0);
    expect(yellow.tp, 0);
    expect(yellow.fn, 1);

    final ClassStats green = result.perClassStats[3]!;
    expect(green.gtCount, 2);
    expect(green.predCount, 1);
    expect(green.tp, 0);
    expect(green.fp, 1);
    expect(green.fn, 2);
  });
}
