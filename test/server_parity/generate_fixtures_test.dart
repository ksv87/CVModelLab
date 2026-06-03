@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

/// Generates parity fixtures consumed by the Python backend tests
/// (`server/tests/test_parity.py`). Each fixture records the source dataset,
/// the evaluation config, and the Dart-computed compact [EvalResult] JSON. The
/// Python port must reproduce `expected` byte-for-byte (within float tolerance).
///
/// Run with: `flutter test test/server_parity/generate_fixtures_test.dart`.
void main() {
  const annotationParser = CocoAnnotationParser();
  const predictionParser = CocoPredictionParser();
  const calculator = MetricsCalculator();

  final Directory outDir = Directory('server/tests/fixtures');

  EvalResult evaluate(
    String annotationsPath,
    String predictionsPath,
    EvalConfig config,
  ) {
    final dataset = annotationParser
        .parseString(File(annotationsPath).readAsStringSync())
        .value!;
    final run = predictionParser
        .parseString(
          File(predictionsPath).readAsStringSync(),
          dataset: dataset,
          modelRunId: 'run',
          modelRunName: 'run',
        )
        .value!;
    return calculator.evaluate(dataset: dataset, modelRun: run, config: config);
  }

  void writeFixture(
    String name,
    String annotationsPath,
    String predictionsPath,
    EvalConfig config,
  ) {
    final EvalResult result =
        evaluate(annotationsPath, predictionsPath, config);
    final Map<String, dynamic> fixture = <String, dynamic>{
      'source': <String, dynamic>{
        'annotations': annotationsPath,
        'predictions': predictionsPath,
      },
      'config': evalConfigToCompactJson(config),
      'expected': evalResultToCompactJson(result),
    };
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
    File('${outDir.path}/$name.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(fixture));
  }

  const EvalConfig defaultConfig = EvalConfig();
  const EvalConfig classAgnostic = EvalConfig(classAwareMatching: false);
  const EvalConfig strict =
      EvalConfig(iouThreshold: 0.75, confidenceThreshold: 0.5);

  test('generate mini_coco fixtures', () {
    writeFixture(
      'mini_coco_default',
      'test_data/mini_coco/annotations.json',
      'test_data/mini_coco/predictions.json',
      defaultConfig,
    );
    writeFixture(
      'mini_coco_class_agnostic',
      'test_data/mini_coco/annotations.json',
      'test_data/mini_coco/predictions.json',
      classAgnostic,
    );
    writeFixture(
      'mini_coco_strict',
      'test_data/mini_coco/annotations.json',
      'test_data/mini_coco/predictions.json',
      strict,
    );
  });

  test('generate showcase fixtures', () {
    for (final String model in <String>['a', 'b', 'c']) {
      writeFixture(
        'showcase_model_${model}_default',
        'demo/showcase_coco/annotations.json',
        'demo/showcase_coco/predictions_model_$model.json',
        defaultConfig,
      );
    }
    writeFixture(
      'showcase_model_b_class_agnostic',
      'demo/showcase_coco/annotations.json',
      'demo/showcase_coco/predictions_model_b.json',
      classAgnostic,
    );
  });
}
