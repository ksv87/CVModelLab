import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cv_model_lab/src/ui/l10n/app_localizations.dart';

const String _annotationsJson = '''
{
  "images": [
    {"id": 1, "file_name": "img1.jpg", "width": 200, "height": 200},
    {"id": 2, "file_name": "img2.jpg", "width": 200, "height": 200},
    {"id": 3, "file_name": "img3.jpg", "width": 200, "height": 200}
  ],
  "annotations": [
    {"id": 1, "image_id": 1, "category_id": 1, "bbox": [10, 10, 100, 100], "iscrowd": 0},
    {"id": 2, "image_id": 2, "category_id": 2, "bbox": [10, 10, 100, 100], "iscrowd": 0},
    {"id": 3, "image_id": 3, "category_id": 1, "bbox": [10, 10, 100, 100], "iscrowd": 0}
  ],
  "categories": [
    {"id": 1, "name": "red"},
    {"id": 2, "name": "yellow"}
  ]
}
''';

const String _predsA = '''
[
  {"image_id": 1, "category_id": 1, "bbox": [10, 10, 100, 100], "score": 0.9},
  {"image_id": 2, "category_id": 2, "bbox": [10, 10, 100, 100], "score": 0.9},
  {"image_id": 3, "category_id": 1, "bbox": [10, 10, 100, 100], "score": 0.9}
]
''';

const String _predsB = '''
[
  {"image_id": 1, "category_id": 1, "bbox": [10, 10, 100, 100], "score": 0.9}
]
''';

const String _predsC = '''
[
  {"image_id": 1, "category_id": 1, "bbox": [10, 10, 100, 100], "score": 0.9},
  {"image_id": 2, "category_id": 2, "bbox": [10, 10, 100, 100], "score": 0.9}
]
''';

MultiModelComparisonResult _result() {
  final dataset =
      const CocoAnnotationParser().parseString(_annotationsJson).value!;
  ModelRun mk(String id, String json) => const CocoPredictionParser()
      .parseString(json, dataset: dataset, modelRunId: id, modelRunName: id)
      .value!;
  final runs = [mk('A', _predsA), mk('B', _predsB), mk('C', _predsC)];
  final evals = {
    for (final r in runs)
      r.id: const MetricsCalculator()
          .evaluate(dataset: dataset, modelRun: r, config: const EvalConfig()),
  };
  return const MultiModelComparator().compare(
    dataset: dataset,
    modelRuns: runs,
    evalResultsByRunId: evals,
    evalConfig: const EvalConfig(),
    generatedAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  const MultiModelReportBuilder builder = MultiModelReportBuilder();
  late MultiModelComparisonResult result;

  setUp(() {
    result = _result();
  });

  group('CSV', () {
    test('leaderboard CSV has the expected header and one row per model', () {
      final lines = builder
          .leaderboardCsv(result)
          .trim()
          .split('\n')
          .where((l) => l.isNotEmpty)
          .toList();
      expect(lines.first, startsWith('rank,model_run_id,model_run_name'));
      expect(lines.length, result.leaderboard.length + 1);
    });

    test('per-class CSV header is present', () {
      expect(
        builder.perClassCsv(result).split('\n').first,
        startsWith('category_id,category_name,model_run_id'),
      );
    });

    test('image disagreement CSV header is present', () {
      expect(
        builder.imageDisagreementsCsv(result).split('\n').first,
        startsWith('image_id,file_name,type'),
      );
    });

    test('regression matrix CSV has all non-diagonal pairs', () {
      final lines = builder
          .regressionMatrixCsv(result)
          .trim()
          .split('\n')
          .where((l) => l.isNotEmpty)
          .toList();
      expect(
        lines.first,
        startsWith('base_model_run_id,candidate_model_run_id'),
      );
      // 3 models → 6 ordered non-diagonal pairs.
      expect(lines.length, 6 + 1);
    });
  });

  group('full bundle', () {
    test('builds HTML/CSV/XLSX/PDF without crashing', () async {
      final bundle = await builder.build(
        result: result,
        projectName: 'mini',
        locale: AppLocale.en,
        generatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(bundle.htmlReport, contains('Multi-model Comparison'));
      expect(bundle.csvFiles.length, 4);
      expect(
        bundle.csvFiles.keys,
        containsAll([
          MultiModelReportFileNames.leaderboard,
          MultiModelReportFileNames.perClass,
          MultiModelReportFileNames.imageDisagreements,
          MultiModelReportFileNames.regressionMatrix,
        ]),
      );
      // XLSX is a non-empty ZIP (starts with 'PK').
      final xlsx = bundle.binaryFiles[MultiModelReportFileNames.xlsx]!;
      expect(xlsx.length, greaterThan(0));
      expect(xlsx[0], 0x50); // 'P'
      expect(xlsx[1], 0x4B); // 'K'
      // PDF starts with %PDF.
      final pdf = bundle.binaryFiles[MultiModelReportFileNames.pdf]!;
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    });

    test('HTML headings are localized in Russian', () async {
      final bundle = await builder.build(
        result: result,
        projectName: 'mini',
        locale: AppLocale.ru,
        includeXlsx: false,
        includePdf: false,
        generatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(bundle.htmlReport, contains('Сравнение нескольких моделей'));
      expect(bundle.htmlReport, contains('Таблица лидеров'));
    });

    test('XLSX sheet names use selected locale', () {
      final data = builder.buildXlsxData(
        result,
        localizations: AppLocalizations.forLocale(AppLocale.ru),
      );
      expect(
        data.sheets.map((sheet) => sheet.name),
        containsAll([
          'Таблица лидеров',
          'Рейтинг по классам',
          'Расхождения по изображениям',
          'Матрица регрессий',
        ]),
      );
    });

    test('empty result still produces a valid bundle', () async {
      final empty = MultiModelComparisonResult.empty(
        config: const MultiModelComparisonConfig.defaults(),
        generatedAt: DateTime.utc(2026, 1, 1),
      );
      final bundle = await builder.build(
        result: empty,
        projectName: 'empty',
      );
      expect(bundle.csvFiles.length, 4);
      final pdf = bundle.binaryFiles[MultiModelReportFileNames.pdf]!;
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    });
  });
}
