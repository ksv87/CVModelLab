import 'dart:io';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses mini COCO annotations', () {
    final String json =
        File('test_data/mini_coco/annotations.json').readAsStringSync();
    final result = CocoAnnotationParser().parseString(json);

    expect(result.value, isNotNull);
    final CocoDataset dataset = result.value!;
    expect(dataset.imagesById.length, 5);
    expect(dataset.categoriesById.length, 3);
    expect(dataset.annotations.length, 5);
    expect(dataset.annotationsByImageId[5], hasLength(2));
    expect(dataset.categoriesById[1]?.name, 'red');
  });

  test('invalid annotations produce warnings and skip bad objects', () {
    const String json = '''
{
  "images": [
    {"id": 1, "file_name": "ok.jpg"},
    {"id": 1, "file_name": "duplicate.jpg"}
  ],
  "annotations": [
    {"id": 1, "image_id": 1, "category_id": 1, "bbox": [0, 0, 10, 10]},
    {"id": 2, "image_id": 99, "category_id": 1, "bbox": [0, 0, 10, 10]},
    {"id": 3, "image_id": 1, "category_id": 1, "bbox": [0, 0, -1, 10]}
  ],
  "categories": [
    {"id": 1, "name": "red"}
  ]
}
''';

    final result = CocoAnnotationParser().parseString(json);

    expect(result.value, isNotNull);
    expect(result.value!.imagesById.length, 1);
    expect(result.value!.annotations.length, 1);
    expect(result.issues.length, greaterThanOrEqualTo(2));
    expect(
      result.issues.any((issue) => issue.message.contains('duplicate image')),
      isTrue,
    );
    expect(
      result.issues.any((issue) => issue.message.contains('positive')),
      isTrue,
    );
  });
}
