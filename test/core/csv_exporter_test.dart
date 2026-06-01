import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('csvEscape', () {
    test('null becomes an empty field', () {
      expect(csvEscape(null), '');
    });

    test('escapes commas by wrapping in quotes', () {
      expect(csvEscape('a,b'), '"a,b"');
    });

    test('escapes quotes by doubling them', () {
      expect(csvEscape('say "hi"'), '"say ""hi"""');
    });

    test('escapes newlines by wrapping in quotes', () {
      expect(csvEscape('line1\nline2'), '"line1\nline2"');
      expect(csvEscape('line1\r\nline2'), '"line1\r\nline2"');
    });

    test('formats numbers with a dot decimal separator', () {
      expect(csvEscape(0.5), '0.5');
      expect(csvEscape(3), '3');
      expect(csvEscape(1234.25), '1234.25');
    });

    test('formats booleans as true/false', () {
      expect(csvEscape(true), 'true');
      expect(csvEscape(false), 'false');
    });

    test('leaves plain strings untouched', () {
      expect(csvEscape('red'), 'red');
    });
  });

  group('CsvExporter', () {
    const exporter = CsvExporter();

    test('per_class_metrics columns and order', () {
      final fixture = _fixture();
      final csv =
          exporter.buildPerClassMetricsCsv(fixture.evalResult.perClassStats);
      final lines = _lines(csv);

      expect(
        lines.first,
        'class_id,class_name,gt_count,pred_count,tp,fp,fn,'
        'precision,recall,f1',
      );
      // Sorted by class id: red (1) then yellow (2).
      expect(lines[1], startsWith('1,red,'));
      expect(lines[2], startsWith('2,yellow,'));
    });

    test('quotes class names containing commas', () {
      final fixture = _fixture(redName: 'red, bright');
      final csv =
          exporter.buildPerClassMetricsCsv(fixture.evalResult.perClassStats);
      expect(csv, contains('1,"red, bright",'));
    });

    test('image_errors columns', () {
      final fixture = _fixture();
      final csv = exporter.buildImageErrorsCsv(
        dataset: fixture.dataset,
        modelRun: fixture.modelRun,
        evalConfig: fixture.evalResult.config,
        evalResult: fixture.evalResult,
        imageIds: fixture.dataset.imagesById.keys.toList()..sort(),
        missingImageFileNames: const <String>{'missing.jpg'},
      );
      final lines = _lines(csv);

      expect(
        lines.first,
        'image_id,file_name,gt_count,pred_count,tp,fp,fn,has_error,'
        'has_fp,has_fn,has_class_confusion,has_small_object,missing_image',
      );
      // The image with a missing file should be flagged.
      final missingLine =
          lines.firstWhere((String line) => line.contains('missing.jpg'));
      expect(missingLine, endsWith('true'));
    });

    test('matches rows cover TP, FP and FN', () {
      final fixture = _fixture();
      final rows = buildMatchRows(
        dataset: fixture.dataset,
        modelRun: fixture.modelRun,
        matches: fixture.evalResult.matches,
      );
      final csv = exporter.buildMatchesCsv(rows);
      final lines = _lines(csv);

      expect(
        lines.first,
        'image_id,file_name,match_type,category_id,category_name,score,iou,'
        'reason,bbox_x,bbox_y,bbox_w,bbox_h,gt_annotation_id,prediction_index',
      );
      final body = lines.skip(1).toList();
      expect(body.any((String l) => l.contains(',TP,')), isTrue);
      expect(body.any((String l) => l.contains(',FP,')), isTrue);
      expect(body.any((String l) => l.contains(',FN,')), isTrue);

      // FN rows carry the GT bbox, an empty score and no prediction index.
      final fnLine = body.firstWhere((String l) => l.contains(',FN,'));
      final fnCells = fnLine.split(',');
      expect(fnCells[5], ''); // score empty
      expect(fnCells.last, ''); // prediction_index empty
      expect(fnCells[12], isNot('')); // gt_annotation_id present
    });

    test('small_object_stats columns', () {
      final fixture = _fixture();
      final csv = exporter.buildSmallObjectStatsCsv(
        dataset: fixture.dataset,
        smallObjectStats: fixture.evalResult.smallObjectStats,
      );
      expect(
        _lines(csv).first,
        'class_id,class_name,size_bucket,gt_count,tp,fn,recall',
      );
    });

    test('confusion_matrix columns', () {
      final fixture = _fixture();
      final csv =
          exporter.buildConfusionMatrixCsv(fixture.evalResult.confusionMatrix);
      expect(_lines(csv).first, 'gt_class,pred_class,count');
    });
  });
}

List<String> _lines(String csv) {
  return csv.split('\n').where((String line) => line.isNotEmpty).toList();
}

_Fixture _fixture({String redName = 'red'}) {
  final dataset = CocoDataset(
    imagesById: const {
      1: ImageRecord(id: 1, fileName: 'tp.jpg', width: 200, height: 200),
      2: ImageRecord(id: 2, fileName: 'fp.jpg', width: 200, height: 200),
      3: ImageRecord(id: 3, fileName: 'fn.jpg', width: 200, height: 200),
      4: ImageRecord(id: 4, fileName: 'missing.jpg', width: 200, height: 200),
    },
    categoriesById: {
      1: CategoryRecord(id: 1, name: redName),
      2: const CategoryRecord(id: 2, name: 'yellow'),
    },
    annotations: <GroundTruthAnnotation>[
      _gt(1, imageId: 1, categoryId: 1, x: 0, y: 0, w: 100, h: 100),
      _gt(2, imageId: 3, categoryId: 2, x: 0, y: 0, w: 100, h: 100),
      _gt(3, imageId: 4, categoryId: 1, x: 10, y: 10, w: 20, h: 20),
    ],
  );
  final run = ModelRun(
    id: 'run',
    name: 'Run',
    predictions: <Prediction>[
      _pred(imageId: 1, categoryId: 1, score: 0.9, x: 0, y: 0, w: 100, h: 100),
      _pred(imageId: 2, categoryId: 1, score: 0.95, x: 0, y: 0, w: 50, h: 50),
    ],
  );
  final evalResult = const MetricsCalculator().evaluate(
    dataset: dataset,
    modelRun: run,
    config: const EvalConfig(iouThreshold: 0.45),
  );
  return _Fixture(dataset, run, evalResult);
}

GroundTruthAnnotation _gt(
  int id, {
  required int imageId,
  required int categoryId,
  required double x,
  required double y,
  required double w,
  required double h,
}) {
  return GroundTruthAnnotation(
    id: id,
    imageId: imageId,
    categoryId: categoryId,
    bbox: BBox(x: x, y: y, width: w, height: h),
  );
}

Prediction _pred({
  required int imageId,
  required int categoryId,
  required double score,
  required double x,
  required double y,
  required double w,
  required double h,
}) {
  return Prediction(
    imageId: imageId,
    categoryId: categoryId,
    bbox: BBox(x: x, y: y, width: w, height: h),
    score: score,
  );
}

class _Fixture {
  const _Fixture(this.dataset, this.modelRun, this.evalResult);

  final CocoDataset dataset;
  final ModelRun modelRun;
  final EvalResult evalResult;
}
