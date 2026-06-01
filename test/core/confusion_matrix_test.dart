import 'dart:io';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds class-agnostic confusion matrix on mini dataset', () {
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

    final ConfusionMatrix matrix = ConfusionMatrixBuilder().build(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );

    expect(matrix.count('red', 'red'), 2);
    expect(matrix.count('green', 'red'), 1);
    expect(matrix.count('yellow', missedColumn), 1);
    expect(matrix.count('green', missedColumn), 1);
    expect(matrix.count(backgroundFpRow, 'green'), 1);
    expect(matrix.count(backgroundFpRow, 'red'), 1);
  });
}
