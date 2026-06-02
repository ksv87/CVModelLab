import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

const String _annotationsJson = '''
{
  "images": [
    {"id": 1, "file_name": "img1.jpg", "width": 100, "height": 100},
    {"id": 2, "file_name": "img2.jpg", "width": 100, "height": 100}
  ],
  "annotations": [
    {"id": 1, "image_id": 1, "category_id": 1, "bbox": [10, 10, 50, 50], "area": 2500, "iscrowd": 0},
    {"id": 2, "image_id": 2, "category_id": 2, "bbox": [20, 20, 40, 40], "area": 1600, "iscrowd": 0}
  ],
  "categories": [
    {"id": 1, "name": "cat"},
    {"id": 2, "name": "dog"}
  ]
}
''';

const String _basePredictionsJson = '''
[
  {"image_id": 1, "category_id": 1, "bbox": [10, 10, 50, 50], "score": 0.9}
]
''';

const String _candidatePredictionsJson = '''
[
  {"image_id": 1, "category_id": 1, "bbox": [10, 10, 50, 50], "score": 0.85},
  {"image_id": 2, "category_id": 2, "bbox": [20, 20, 40, 40], "score": 0.8}
]
''';

void main() {
  late CocoDataset dataset;
  late ModelRun baseRun;
  late ModelRun candidateRun;
  late ModelComparisonResult result;

  setUp(() {
    dataset = const CocoAnnotationParser().parseString(_annotationsJson).value!;
    baseRun = const CocoPredictionParser()
        .parseString(
          _basePredictionsJson,
          dataset: dataset,
          modelRunId: 'base',
          modelRunName: 'Base Model',
        )
        .value!;
    candidateRun = const CocoPredictionParser()
        .parseString(
          _candidatePredictionsJson,
          dataset: dataset,
          modelRunId: 'cand',
          modelRunName: 'Candidate Model',
        )
        .value!;

    final EvalResult baseEval = const MetricsCalculator().evaluate(
      dataset: dataset,
      modelRun: baseRun,
      config: const EvalConfig(),
    );
    final EvalResult candidateEval = const MetricsCalculator().evaluate(
      dataset: dataset,
      modelRun: candidateRun,
      config: const EvalConfig(),
    );
    result = const ModelComparator().compare(
      dataset: dataset,
      baseRun: baseRun,
      baseEval: baseEval,
      candidateRun: candidateRun,
      candidateEval: candidateEval,
      evalConfig: const EvalConfig(),
    );
  });

  const ComparisonReportBuilder builder = ComparisonReportBuilder();

  group('HTML report', () {
    test('contains base model name', () {
      final ComparisonReportBundle bundle = builder.build(
        dataset: dataset,
        baseRun: baseRun,
        candidateRun: candidateRun,
        result: result,
        projectName: 'My Project',
      );
      expect(bundle.htmlReport, contains('Base Model'));
    });

    test('contains candidate model name', () {
      final ComparisonReportBundle bundle = builder.build(
        dataset: dataset,
        baseRun: baseRun,
        candidateRun: candidateRun,
        result: result,
      );
      expect(bundle.htmlReport, contains('Candidate Model'));
    });

    test('contains project name when provided', () {
      final ComparisonReportBundle bundle = builder.build(
        dataset: dataset,
        baseRun: baseRun,
        candidateRun: candidateRun,
        result: result,
        projectName: 'My Special Project',
      );
      expect(bundle.htmlReport, contains('My Special Project'));
    });

    test('is empty when includeHtml = false', () {
      final ComparisonReportBundle bundle = builder.build(
        dataset: dataset,
        baseRun: baseRun,
        candidateRun: candidateRun,
        result: result,
        includeHtml: false,
      );
      expect(bundle.htmlReport, isEmpty);
    });
  });

  group('per-class CSV', () {
    test('has correct headers', () {
      final ComparisonReportBundle bundle = builder.build(
        dataset: dataset,
        baseRun: baseRun,
        candidateRun: candidateRun,
        result: result,
        includeHtml: false,
        includeImagesCsv: false,
      );
      final String csv = bundle.csvFiles[ComparisonReportFileNames.perClass]!;
      final String header = csv.split('\n').first;
      expect(header, contains('class_id'));
      expect(header, contains('class_name'));
      expect(header, contains('base_precision'));
      expect(header, contains('candidate_precision'));
      expect(header, contains('delta_precision'));
      expect(header, contains('base_recall'));
      expect(header, contains('candidate_recall'));
      expect(header, contains('delta_recall'));
      expect(header, contains('base_f1'));
      expect(header, contains('candidate_f1'));
      expect(header, contains('delta_f1'));
      expect(header, contains('base_tp'));
      expect(header, contains('candidate_tp'));
      expect(header, contains('delta_tp'));
      expect(header, contains('base_fp'));
      expect(header, contains('candidate_fp'));
      expect(header, contains('delta_fp'));
      expect(header, contains('base_fn'));
      expect(header, contains('candidate_fn'));
      expect(header, contains('delta_fn'));
    });

    test('contains data rows for each category', () {
      final ComparisonReportBundle bundle = builder.build(
        dataset: dataset,
        baseRun: baseRun,
        candidateRun: candidateRun,
        result: result,
        includeHtml: false,
        includeImagesCsv: false,
      );
      final String csv = bundle.csvFiles[ComparisonReportFileNames.perClass]!;
      expect(csv, contains('cat'));
      expect(csv, contains('dog'));
    });
  });

  group('images CSV', () {
    test('has correct headers', () {
      final ComparisonReportBundle bundle = builder.build(
        dataset: dataset,
        baseRun: baseRun,
        candidateRun: candidateRun,
        result: result,
        includeHtml: false,
        includePerClassCsv: false,
      );
      final String csv = bundle.csvFiles[ComparisonReportFileNames.images]!;
      final String header = csv.split('\n').first;
      expect(header, contains('image_id'));
      expect(header, contains('file_name'));
      expect(header, contains('status'));
      expect(header, contains('base_tp'));
      expect(header, contains('base_fp'));
      expect(header, contains('base_fn'));
      expect(header, contains('candidate_tp'));
      expect(header, contains('candidate_fp'));
      expect(header, contains('candidate_fn'));
      expect(header, contains('delta_tp'));
      expect(header, contains('delta_fp'));
      expect(header, contains('delta_fn'));
    });

    test('CSV values match comparison result', () {
      final ComparisonReportBundle bundle = builder.build(
        dataset: dataset,
        baseRun: baseRun,
        candidateRun: candidateRun,
        result: result,
        includeHtml: false,
        includePerClassCsv: false,
      );
      final String csv = bundle.csvFiles[ComparisonReportFileNames.images]!;
      // img1.jpg and img2.jpg should be present.
      expect(csv, contains('img1.jpg'));
      expect(csv, contains('img2.jpg'));
    });
  });

  group('fileNames', () {
    test('includes HTML and both CSVs when all enabled', () {
      final ComparisonReportBundle bundle = builder.build(
        dataset: dataset,
        baseRun: baseRun,
        candidateRun: candidateRun,
        result: result,
      );
      expect(bundle.fileNames, contains(ComparisonReportFileNames.html));
      expect(bundle.fileNames, contains(ComparisonReportFileNames.perClass));
      expect(bundle.fileNames, contains(ComparisonReportFileNames.images));
    });

    test('fileNames excludes HTML when not included', () {
      final ComparisonReportBundle bundle = builder.build(
        dataset: dataset,
        baseRun: baseRun,
        candidateRun: candidateRun,
        result: result,
        includeHtml: false,
      );
      expect(
        bundle.fileNames,
        isNot(contains(ComparisonReportFileNames.html)),
      );
    });
  });
}
