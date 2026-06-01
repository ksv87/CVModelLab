import 'dart:io';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates small object recall by class and size bucket', () {
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

    final SmallObjectClassStats yellowSmall =
        result.smallObjectStats[2]![ObjectSizeBucket.small]!;
    expect(yellowSmall.gtCount, 1);
    expect(yellowSmall.tp, 0);
    expect(yellowSmall.fn, 1);
    expect(yellowSmall.recall, 0);

    final SmallObjectClassStats greenSmall =
        result.smallObjectStats[3]![ObjectSizeBucket.small]!;
    expect(greenSmall.gtCount, 1);
    expect(greenSmall.tp, 0);
    expect(greenSmall.fn, 1);
  });
}
