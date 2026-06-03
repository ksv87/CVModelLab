import 'dart:convert';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ApEvalResultParser parser = ApEvalResultParser();

  final Map<String, dynamic> _fullJson = {
    'evaluator_name': 'pycocotools',
    'generated_at': '2026-06-02T10:00:00.000Z',
    'ap': 0.458,
    'ap50': 0.621,
    'ap75': 0.512,
    'ap_small': 0.312,
    'ap_medium': 0.489,
    'ap_large': 0.553,
    'ar1': 0.371,
    'ar10': 0.491,
    'ar100': 0.502,
    'ar_small': 0.389,
    'ar_medium': 0.512,
    'ar_large': 0.589,
    'per_class': [
      {
        'category_id': 1,
        'category_name': 'person',
        'ap': 0.412,
        'ap50': 0.598,
        'ap75': 0.441,
        'ar': 0.478,
      },
      {
        'category_id': 2,
        'category_name': 'car',
        'ap': 0.503,
        'ap50': 0.644,
        'ap75': 0.583,
        'ar': 0.527,
      },
    ],
    'warnings': ['Sample warning'],
  };

  test('parse full JSON sets all scalar fields correctly', () {
    final ApEvalResult result = parser.fromJson(_fullJson);
    expect(result.evaluatorName, 'pycocotools');
    expect(result.ap, closeTo(0.458, 1e-9));
    expect(result.ap50, closeTo(0.621, 1e-9));
    expect(result.ap75, closeTo(0.512, 1e-9));
    expect(result.apSmall, closeTo(0.312, 1e-9));
    expect(result.apMedium, closeTo(0.489, 1e-9));
    expect(result.apLarge, closeTo(0.553, 1e-9));
    expect(result.ar1, closeTo(0.371, 1e-9));
    expect(result.ar10, closeTo(0.491, 1e-9));
    expect(result.ar100, closeTo(0.502, 1e-9));
    expect(result.arSmall, closeTo(0.389, 1e-9));
    expect(result.arMedium, closeTo(0.512, 1e-9));
    expect(result.arLarge, closeTo(0.589, 1e-9));
    expect(result.generatedAt.isUtc, isTrue);
  });

  test('per_class is parsed correctly', () {
    final ApEvalResult result = parser.fromJson(_fullJson);
    expect(result.perClass, hasLength(2));
    final ClassApMetric first = result.perClass[0];
    expect(first.categoryId, 1);
    expect(first.categoryName, 'person');
    expect(first.ap, closeTo(0.412, 1e-9));
    expect(first.ap50, closeTo(0.598, 1e-9));
    expect(first.ap75, closeTo(0.441, 1e-9));
    expect(first.ar, closeTo(0.478, 1e-9));
  });

  test('warnings are parsed correctly', () {
    final ApEvalResult result = parser.fromJson(_fullJson);
    expect(result.warnings, ['Sample warning']);
  });

  test('parse JSON with null optional fields returns nulls', () {
    final Map<String, dynamic> json = {
      'evaluator_name': 'test',
      'generated_at': '2026-01-01T00:00:00Z',
      'per_class': <dynamic>[],
      'warnings': <dynamic>[],
    };
    final ApEvalResult result = parser.fromJson(json);
    expect(result.ap, isNull);
    expect(result.ap50, isNull);
    expect(result.apSmall, isNull);
    expect(result.ar100, isNull);
    expect(result.perClass, isEmpty);
  });

  test('parse JSON with missing optional fields does not crash', () {
    final Map<String, dynamic> minimal = {
      'evaluator_name': 'x',
      'generated_at': '2026-01-01T00:00:00Z',
    };
    final ApEvalResult result = parser.fromJson(minimal);
    expect(result.evaluatorName, 'x');
    expect(result.perClass, isEmpty);
    expect(result.warnings, isEmpty);
  });

  test('unknown keys in JSON are ignored', () {
    final Map<String, dynamic> json = {
      'evaluator_name': 'test',
      'generated_at': '2026-01-01T00:00:00Z',
      'unknown_field': 42,
      'another_unknown': 'hello',
    };
    expect(() => parser.fromJson(json), returnsNormally);
  });

  test('toJson round-trips all fields correctly', () {
    final ApEvalResult original = parser.fromJson(_fullJson);
    final Map<String, dynamic> json = parser.toJson(original);
    final ApEvalResult roundTripped = parser.fromJson(json);

    expect(roundTripped.evaluatorName, original.evaluatorName);
    expect(roundTripped.ap, original.ap);
    expect(roundTripped.ap50, original.ap50);
    expect(roundTripped.ap75, original.ap75);
    expect(roundTripped.apSmall, original.apSmall);
    expect(roundTripped.apMedium, original.apMedium);
    expect(roundTripped.apLarge, original.apLarge);
    expect(roundTripped.ar1, original.ar1);
    expect(roundTripped.ar10, original.ar10);
    expect(roundTripped.ar100, original.ar100);
    expect(roundTripped.arSmall, original.arSmall);
    expect(roundTripped.arMedium, original.arMedium);
    expect(roundTripped.arLarge, original.arLarge);
    expect(roundTripped.warnings, original.warnings);
    expect(roundTripped.perClass, hasLength(original.perClass.length));
    for (int i = 0; i < original.perClass.length; i++) {
      expect(
        roundTripped.perClass[i].categoryId,
        original.perClass[i].categoryId,
      );
      expect(
        roundTripped.perClass[i].categoryName,
        original.perClass[i].categoryName,
      );
      expect(roundTripped.perClass[i].ap, original.perClass[i].ap);
      expect(roundTripped.perClass[i].ap50, original.perClass[i].ap50);
    }
  });

  test('toJson omits null metric fields', () {
    final ApEvalResult result = ApEvalResult(
      evaluatorName: 'test',
      generatedAt: DateTime.utc(2026),
    );
    final Map<String, dynamic> json = parser.toJson(result);
    expect(json.containsKey('ap'), isFalse);
    expect(json.containsKey('ap50'), isFalse);
    expect(json.containsKey('ar100'), isFalse);
  });

  test('fromJson parses JSON string via jsonDecode', () {
    final String jsonStr = jsonEncode(_fullJson);
    final dynamic decoded = jsonDecode(jsonStr);
    final ApEvalResult result =
        parser.fromJson(decoded as Map<String, dynamic>);
    expect(result.ap, closeTo(0.458, 1e-6));
    expect(result.perClass, hasLength(2));
  });
}
