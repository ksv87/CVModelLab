import 'dart:io';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CocoDataset dataset;

  setUp(() {
    final String annotations =
        File('test_data/mini_coco/annotations.json').readAsStringSync();
    dataset = CocoAnnotationParser().parseString(annotations).value!;
  });

  test('parses predictions and groups by image', () {
    final String json =
        File('test_data/mini_coco/predictions.json').readAsStringSync();
    final result = CocoPredictionParser().parseString(
      json,
      dataset: dataset,
      modelRunId: 'run-1',
      modelRunName: 'Run 1',
    );

    expect(result.value, isNotNull);
    final ModelRun run = result.value!;
    expect(run.predictions.length, 6);
    expect(run.predictionsByImageId[5], hasLength(3));
    expect(
      result.issues.any((issue) => issue.message.contains('basename fallback')),
      isTrue,
    );
    expect(
      result.issues.any((issue) => issue.message.contains('unknown image_id')),
      isTrue,
    );
  });

  test('image_id takes priority over file_name', () {
    const String json = '''
[
  {
    "image_id": 1,
    "file_name": "nested/image_005.jpg",
    "category_id": 1,
    "bbox": [0, 0, 10, 10],
    "score": 0.9
  }
]
''';
    final result = CocoPredictionParser().parseString(
      json,
      dataset: dataset,
      modelRunId: 'run-1',
      modelRunName: 'Run 1',
    );

    expect(result.value!.predictions.single.imageId, 1);
  });

  test('invalid predictions produce warnings and skip bad objects', () {
    const String json = '''
[
  {"image_id": 1, "category_id": 99, "bbox": [0, 0, 10, 10], "score": 0.9},
  {"image_id": 1, "category_id": 1, "bbox": [0, 0, 0, 10], "score": 0.9},
  {"image_id": 1, "category_id": 1, "bbox": [0, 0, 10, 10], "score": 2.0}
]
''';

    final result = CocoPredictionParser().parseString(
      json,
      dataset: dataset,
      modelRunId: 'run-1',
      modelRunName: 'Run 1',
    );

    expect(result.value!.predictions.length, 1);
    expect(result.issues.length, 3);
    expect(
      result.issues.any((issue) => issue.message.contains('0..1')),
      isTrue,
    );
  });
}
