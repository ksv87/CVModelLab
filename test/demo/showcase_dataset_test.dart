import 'dart:convert';
import 'dart:io';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

// Helpers
CocoDataset _parseAnnotations(String path) {
  final String raw = File(path).readAsStringSync();
  final ParseResult<CocoDataset> result =
      const CocoAnnotationParser().parseString(raw);
  expect(
    result.value,
    isNotNull,
    reason: 'Showcase annotations should parse without fatal errors',
  );
  return result.value!;
}

List<dynamic> _decodeJsonList(String path) {
  final dynamic decoded = json.decode(File(path).readAsStringSync());
  expect(decoded, isA<List>(), reason: '$path must be a JSON array');
  return decoded as List<dynamic>;
}

Map<String, dynamic> _decodeJsonMap(String path) {
  final dynamic decoded = json.decode(File(path).readAsStringSync());
  expect(decoded, isA<Map<String, dynamic>>(), reason: '$path must be a JSON object');
  return decoded as Map<String, dynamic>;
}

void main() {
  const String base = 'demo/showcase_coco';

  // ── 1. File existence ──────────────────────────────────────────────────────
  group('File existence', () {
    test('annotations.json exists', () {
      expect(File('$base/annotations.json').existsSync(), isTrue);
    });

    for (final String model in ['model_a', 'model_b', 'model_c']) {
      test('predictions_$model.json exists', () {
        expect(File('$base/predictions_$model.json').existsSync(), isTrue);
      });

      test('ap_metrics_$model.json exists', () {
        expect(File('$base/ap_metrics_$model.json').existsSync(), isTrue);
      });
    }

    test('images directory exists and has 30+ PNG files', () {
      final Directory dir = Directory('$base/images');
      expect(dir.existsSync(), isTrue);
      final int pngCount = dir
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.endsWith('.png'))
          .length;
      expect(pngCount, greaterThanOrEqualTo(30));
    });
  });

  // ── 2. Annotations structure ───────────────────────────────────────────────
  group('Annotations', () {
    late CocoDataset dataset;

    setUpAll(() {
      dataset = _parseAnnotations('$base/annotations.json');
    });

    test('has 30+ images', () {
      expect(dataset.imagesById.length, greaterThanOrEqualTo(30));
    });

    test('has exactly 5 categories', () {
      expect(dataset.categoriesById.length, equals(5));
    });

    test('categories include required names', () {
      final Set<String> names =
          dataset.categoriesById.values.map((c) => c.name).toSet();
      for (final String name in [
        'red_light',
        'yellow_light',
        'green_light',
        'pedestrian_sign',
        'background_distractor',
      ]) {
        expect(names, contains(name), reason: 'Missing category: $name');
      }
    });

    test('has annotations', () {
      expect(dataset.annotations.isNotEmpty, isTrue);
    });

    test('all annotation image_ids exist in images', () {
      final Set<int> imageIds = dataset.imagesById.keys.toSet();
      for (final GroundTruthAnnotation ann in dataset.annotations) {
        expect(
          imageIds,
          contains(ann.imageId),
          reason: 'Annotation ${ann.id} references unknown image ${ann.imageId}',
        );
      }
    });

    test('all annotation category_ids are valid', () {
      final Set<int> catIds = dataset.categoriesById.keys.toSet();
      for (final GroundTruthAnnotation ann in dataset.annotations) {
        expect(
          catIds,
          contains(ann.categoryId),
          reason: 'Annotation ${ann.id} has unknown category ${ann.categoryId}',
        );
      }
    });

    test('has at least one image with no GT (background-only)', () {
      final Set<int> annotatedImageIds =
          dataset.annotations.map((a) => a.imageId).toSet();
      final bool hasBackgroundOnly = dataset.imagesById.keys
          .any((id) => !annotatedImageIds.contains(id));
      expect(
        hasBackgroundOnly,
        isTrue,
        reason: 'Dataset should have at least one background-only image',
      );
    });

    test('has small objects (area < 1024)', () {
      final bool hasSmall =
          dataset.annotations.any((a) => a.area != null && a.area! < 1024);
      expect(
        hasSmall,
        isTrue,
        reason: 'Dataset should contain small objects for AR_small testing',
      );
    });

    test('has annotations for multiple categories (class confusion scenario)', () {
      final Set<int> usedCatIds =
          dataset.annotations.map((a) => a.categoryId).toSet();
      expect(
        usedCatIds.length,
        greaterThanOrEqualTo(3),
        reason: 'Need 3+ classes to have class confusion',
      );
    });
  });

  // ── 3. Prediction files ────────────────────────────────────────────────────
  group('Predictions', () {
    late CocoDataset dataset;

    setUpAll(() {
      dataset = _parseAnnotations('$base/annotations.json');
    });

    for (final (String model, String label) in [
      ('model_a', 'Model A'),
      ('model_b', 'Model B'),
      ('model_c', 'Model C'),
    ]) {
      group(label, () {
        late List<dynamic> rawPreds;
        late ParseResult<ModelRun> parseResult;

        setUpAll(() {
          final String raw =
              File('$base/predictions_$model.json').readAsStringSync();
          rawPreds = json.decode(raw) as List<dynamic>;
          parseResult = const CocoPredictionParser().parseString(
            raw,
            dataset: dataset,
            modelRunId: model,
            modelRunName: label,
          );
        });

        test('predictions file is a non-empty JSON array', () {
          expect(rawPreds.isNotEmpty, isTrue);
        });

        test('prediction parser produces a ModelRun without fatal errors', () {
          expect(
            parseResult.value,
            isNotNull,
            reason: 'Parser returned null for $label predictions',
          );
        });

        test('all predictions reference valid image_ids', () {
          final Set<int> validIds = dataset.imagesById.keys.toSet();
          for (final dynamic p in rawPreds) {
            final dynamic imgId = (p as Map<String, dynamic>)['image_id'];
            if (imgId != null) {
              expect(
                validIds,
                contains(imgId),
                reason: 'Prediction references unknown image_id $imgId',
              );
            }
          }
        });

        test('EvalResult can be computed without error', () {
          final ModelRun? run = parseResult.value;
          if (run == null) return;
          expect(
            () => const MetricsCalculator()
                .evaluate(dataset: dataset, modelRun: run, config: const EvalConfig()),
            returnsNormally,
          );
        });
      });
    }

    test('Model B has more predictions than Model C (higher recall behaviour)', () {
      final List<dynamic> predsB =
          _decodeJsonList('$base/predictions_model_b.json');
      final List<dynamic> predsC =
          _decodeJsonList('$base/predictions_model_c.json');
      expect(predsB.length, greaterThan(predsC.length));
    });
  });

  // ── 4. AP metrics JSON ─────────────────────────────────────────────────────
  group('AP metrics', () {
    for (final (String model, String label) in [
      ('model_a', 'Model A'),
      ('model_b', 'Model B'),
      ('model_c', 'Model C'),
    ]) {
      test('$label: ap_metrics_$model.json parses successfully', () {
        final Map<String, dynamic> raw =
            _decodeJsonMap('$base/ap_metrics_$model.json');
        expect(
          () => const ApEvalResultParser().fromJson(raw),
          returnsNormally,
        );
        final ApEvalResult result = const ApEvalResultParser().fromJson(raw);
        expect(result.ap, isNotNull);
        expect(result.ap50, isNotNull);
        expect(result.perClass, isNotEmpty);
      });
    }

    test('Model C has higher AP than Model B (precision beats recall in AP)', () {
      final ApEvalResult apB = const ApEvalResultParser()
          .fromJson(_decodeJsonMap('$base/ap_metrics_model_b.json'));
      final ApEvalResult apC = const ApEvalResultParser()
          .fromJson(_decodeJsonMap('$base/ap_metrics_model_c.json'));
      expect(apC.ap!, greaterThan(apB.ap!));
    });

    test('Model B has higher AR100 than Model C (recall vs precision trade-off)',
        () {
      final ApEvalResult apB = const ApEvalResultParser()
          .fromJson(_decodeJsonMap('$base/ap_metrics_model_b.json'));
      final ApEvalResult apC = const ApEvalResultParser()
          .fromJson(_decodeJsonMap('$base/ap_metrics_model_c.json'));
      expect(apB.ar100!, greaterThan(apC.ar100!));
    });

    test('Model C has lower AP_small than Model A (misses small objects)', () {
      final ApEvalResult apA = const ApEvalResultParser()
          .fromJson(_decodeJsonMap('$base/ap_metrics_model_a.json'));
      final ApEvalResult apC = const ApEvalResultParser()
          .fromJson(_decodeJsonMap('$base/ap_metrics_model_c.json'));
      expect(apC.apSmall!, lessThan(apA.apSmall!));
    });
  });

  // ── 5. Multi-model comparator ──────────────────────────────────────────────
  group('Multi-model comparator', () {
    test('can compare A/B/C without throwing', () {
      final CocoDataset dataset = _parseAnnotations('$base/annotations.json');
      final List<ModelRun?> runs = [];
      final Map<String, EvalResult> evalResults = {};

      for (final (String id, String label, String file) in [
        ('showcase-a', 'Model A', 'model_a'),
        ('showcase-b', 'Model B', 'model_b'),
        ('showcase-c', 'Model C', 'model_c'),
      ]) {
        final String raw =
            File('$base/predictions_$file.json').readAsStringSync();
        final ParseResult<ModelRun> pr = const CocoPredictionParser()
            .parseString(raw, dataset: dataset, modelRunId: id, modelRunName: label);
        if (pr.value == null) continue;
        runs.add(pr.value);
        evalResults[id] = const MetricsCalculator()
            .evaluate(dataset: dataset, modelRun: pr.value!, config: const EvalConfig());
      }

      expect(runs.length, equals(3));
      expect(
        () => const MultiModelComparator().compare(
          dataset: dataset,
          modelRuns: runs.whereType<ModelRun>().toList(),
          evalResultsByRunId: evalResults,
          evalConfig: const EvalConfig(),
        ),
        returnsNormally,
      );
    });

    test('leaderboard has 3 entries', () {
      final CocoDataset dataset = _parseAnnotations('$base/annotations.json');
      final List<ModelRun> runs = [];
      final Map<String, EvalResult> evalResults = {};

      for (final (String id, String label, String file) in [
        ('showcase-a', 'Model A', 'model_a'),
        ('showcase-b', 'Model B', 'model_b'),
        ('showcase-c', 'Model C', 'model_c'),
      ]) {
        final String raw =
            File('$base/predictions_$file.json').readAsStringSync();
        final ParseResult<ModelRun> pr = const CocoPredictionParser()
            .parseString(raw, dataset: dataset, modelRunId: id, modelRunName: label);
        if (pr.value == null) continue;
        runs.add(pr.value!);
        evalResults[id] = const MetricsCalculator()
            .evaluate(dataset: dataset, modelRun: pr.value!, config: const EvalConfig());
      }

      final result = const MultiModelComparator().compare(
        dataset: dataset,
        modelRuns: runs,
        evalResultsByRunId: evalResults,
        evalConfig: const EvalConfig(),
      );

      expect(result.leaderboard.length, equals(3));
    });
  });
}
