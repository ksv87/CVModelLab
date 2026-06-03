import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

ApEvalResult _makeResult({bool withPerClass = true}) {
  return ApEvalResult(
    evaluatorName: 'pycocotools',
    generatedAt: DateTime.utc(2026, 6, 2),
    ap: 0.458,
    ap50: 0.621,
    ap75: 0.512,
    apSmall: null,
    apMedium: 0.489,
    apLarge: null,
    ar100: 0.502,
    perClass: withPerClass
        ? const [
            ClassApMetric(
              categoryId: 1,
              categoryName: 'person',
              ap: 0.412,
              ap50: 0.598,
              ap75: 0.441,
              ar: 0.478,
            ),
            ClassApMetric(
              categoryId: 2,
              categoryName: 'car',
              ap: null,
              ap50: 0.644,
              ap75: null,
              ar: null,
            ),
          ]
        : const [],
  );
}

void main() {
  const CsvExporter exporter = CsvExporter();

  group('buildApMetricsCsv', () {
    test('produces correct header row', () {
      final ApEvalResult result = _makeResult();
      final String csv = exporter.buildApMetricsCsv(result);
      final List<String> lines = csv.trim().split('\n');
      expect(lines.first, 'metric,value');
    });

    test('AP row contains correct value', () {
      final ApEvalResult result = _makeResult();
      final String csv = exporter.buildApMetricsCsv(result);
      expect(csv, contains('AP@[.5:.95],0.458'));
    });

    test('AP50 row contains correct value', () {
      final ApEvalResult result = _makeResult();
      final String csv = exporter.buildApMetricsCsv(result);
      expect(csv, contains('AP50,0.621'));
    });

    test('null values become empty cells', () {
      final ApEvalResult result = _makeResult();
      final String csv = exporter.buildApMetricsCsv(result);
      expect(csv, contains('APsmall,\n'));
      expect(csv, contains('APlarge,\n'));
    });

    test('produces 13 rows (1 header + 12 metrics)', () {
      final ApEvalResult result = _makeResult();
      final String csv = exporter.buildApMetricsCsv(result);
      final List<String> lines =
          csv.split('\n').where((l) => l.isNotEmpty).toList();
      expect(lines, hasLength(13));
    });
  });

  group('buildPerClassApCsv', () {
    test('produces correct header', () {
      final ApEvalResult result = _makeResult();
      final String csv = exporter.buildPerClassApCsv(result);
      expect(
        csv.trim().split('\n').first,
        'class_id,class_name,ap,ap50,ap75,ar',
      );
    });

    test('has one row per class', () {
      final ApEvalResult result = _makeResult();
      final String csv = exporter.buildPerClassApCsv(result);
      final List<String> dataRows =
          csv.trim().split('\n').where((l) => l.isNotEmpty).skip(1).toList();
      expect(dataRows, hasLength(2));
    });

    test('null values become empty cells', () {
      final ApEvalResult result = _makeResult();
      final String csv = exporter.buildPerClassApCsv(result);
      final List<String> lines = csv.trim().split('\n');
      final String carRow = lines.last;
      // car has null ap, ap75, ar — should be empty CSV fields
      final List<String> fields = carRow.split(',');
      expect(fields[2], ''); // ap
      expect(fields[4], ''); // ap75
      expect(fields[5], ''); // ar
    });

    test('non-null ap50 appears in car row', () {
      final ApEvalResult result = _makeResult();
      final String csv = exporter.buildPerClassApCsv(result);
      expect(csv, contains('0.644'));
    });
  });

  group('ReportBundle AP CSV flags', () {
    test('includeApMetricsCsv flag includes ap_metrics.csv', () async {
      final ApEvalResult apResult = _makeResult();
      final ReportBundle bundle = await const ReportBundleBuilder().build(
        dataset: _emptyDataset(),
        modelRun: _emptyModelRun(),
        evalConfig: const EvalConfig(),
        evalResult: _emptyEvalResult(),
        components: const ReportComponents(
          includeHtml: false,
          includePerClassMetricsCsv: false,
          includeImageErrorsCsv: false,
          includeMatchesCsv: false,
          includeApMetricsCsv: true,
        ),
        apEvalResult: apResult,
      );
      expect(bundle.csvFiles.containsKey(ReportFileNames.apMetrics), isTrue);
    });

    test('includePerClassApCsv flag includes per_class_ap.csv', () async {
      final ApEvalResult apResult = _makeResult();
      final ReportBundle bundle = await const ReportBundleBuilder().build(
        dataset: _emptyDataset(),
        modelRun: _emptyModelRun(),
        evalConfig: const EvalConfig(),
        evalResult: _emptyEvalResult(),
        components: const ReportComponents(
          includeHtml: false,
          includePerClassMetricsCsv: false,
          includeImageErrorsCsv: false,
          includeMatchesCsv: false,
          includePerClassApCsv: true,
        ),
        apEvalResult: apResult,
      );
      expect(bundle.csvFiles.containsKey(ReportFileNames.perClassAp), isTrue);
    });

    test('AP flags without apEvalResult do not include AP CSVs', () async {
      final ReportBundle bundle = await const ReportBundleBuilder().build(
        dataset: _emptyDataset(),
        modelRun: _emptyModelRun(),
        evalConfig: const EvalConfig(),
        evalResult: _emptyEvalResult(),
        components: const ReportComponents(
          includeHtml: false,
          includePerClassMetricsCsv: false,
          includeImageErrorsCsv: false,
          includeMatchesCsv: false,
          includeApMetricsCsv: true,
          includePerClassApCsv: true,
        ),
      );
      expect(bundle.csvFiles.containsKey(ReportFileNames.apMetrics), isFalse);
      expect(bundle.csvFiles.containsKey(ReportFileNames.perClassAp), isFalse);
    });

    test('AP flags disabled exclude AP CSVs even when apEvalResult is present',
        () async {
      final ApEvalResult apResult = _makeResult();
      final ReportBundle bundle = await const ReportBundleBuilder().build(
        dataset: _emptyDataset(),
        modelRun: _emptyModelRun(),
        evalConfig: const EvalConfig(),
        evalResult: _emptyEvalResult(),
        components: const ReportComponents(
          includeHtml: false,
          includePerClassMetricsCsv: false,
          includeImageErrorsCsv: false,
          includeMatchesCsv: false,
        ),
        apEvalResult: apResult,
      );
      expect(bundle.csvFiles.containsKey(ReportFileNames.apMetrics), isFalse);
      expect(bundle.csvFiles.containsKey(ReportFileNames.perClassAp), isFalse);
    });

    test('includeApInHtml false excludes AP section from HTML', () async {
      final ApEvalResult apResult = _makeResult();
      final ReportBundle bundle = await const ReportBundleBuilder().build(
        dataset: _emptyDataset(),
        modelRun: _emptyModelRun(),
        evalConfig: const EvalConfig(),
        evalResult: _emptyEvalResult(),
        components: const ReportComponents(
          includeHtml: true,
          includePerClassMetricsCsv: false,
          includeImageErrorsCsv: false,
          includeMatchesCsv: false,
          includeApInHtml: false,
        ),
        apEvalResult: apResult,
      );
      expect(bundle.htmlReport, isNot(contains('COCO AP Metrics')));
    });

    test('includePerClassAp false excludes per_class_ap.csv', () async {
      final ApEvalResult apResult = _makeResult();
      final ReportBundle bundle = await const ReportBundleBuilder().build(
        dataset: _emptyDataset(),
        modelRun: _emptyModelRun(),
        evalConfig: const EvalConfig(),
        evalResult: _emptyEvalResult(),
        components: const ReportComponents(
          includeHtml: false,
          includePerClassMetricsCsv: false,
          includeImageErrorsCsv: false,
          includeMatchesCsv: false,
          includeApMetricsCsv: true,
          includePerClassApCsv: true,
          includePerClassAp: false,
        ),
        apEvalResult: apResult,
      );
      expect(bundle.csvFiles.containsKey(ReportFileNames.apMetrics), isTrue);
      expect(bundle.csvFiles.containsKey(ReportFileNames.perClassAp), isFalse);
    });
  });
}

CocoDataset _emptyDataset() {
  return CocoDataset(
    imagesById: const {},
    categoriesById: const {},
    annotations: const [],
  );
}

ModelRun _emptyModelRun() {
  return ModelRun(
    id: 'test',
    name: 'test',
    predictions: const [],
  );
}

EvalResult _emptyEvalResult() {
  return const MetricsCalculator().evaluate(
    dataset: CocoDataset(
      imagesById: const {},
      categoriesById: const {},
      annotations: const [],
    ),
    modelRun: ModelRun(
      id: 'test',
      name: 'test',
      predictions: const [],
    ),
    config: const EvalConfig(),
  );
}
