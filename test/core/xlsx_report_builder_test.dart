import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CocoDataset dataset;
  late ModelRun run;
  late EvalResult evalResult;
  late List<ReportMatchRow> matchRows;
  late List<int> imageIds;

  setUp(() {
    dataset = const CocoAnnotationParser()
        .parseString(
          File('test_data/mini_coco/annotations.json').readAsStringSync(),
        )
        .value!;
    run = const CocoPredictionParser()
        .parseString(
          File('test_data/mini_coco/predictions.json').readAsStringSync(),
          dataset: dataset,
          modelRunId: 'run-1',
          modelRunName: 'Run 1',
        )
        .value!;
    evalResult = const MetricsCalculator().evaluate(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );
    matchRows = buildMatchRows(
      dataset: dataset,
      modelRun: run,
      matches: evalResult.matches,
    );
    imageIds = dataset.imagesById.keys.toList()..sort();
  });

  test('workbook bytes are non-empty and contain expected sheets', () {
    final XlsxWorkbookData data = const XlsxReportBuilder().buildData(
      dataset: dataset,
      modelRun: run,
      evalConfig: const EvalConfig(),
      evalResult: evalResult,
      projectName: 'mini',
      modelRunName: 'Run 1',
      generatedAt: DateTime(2026),
      matchRows: matchRows,
      imageIds: imageIds,
      healthReport: _healthReport(),
      worstCases: const WorstCaseMiner().mine(
        dataset: dataset,
        modelRun: run,
        evalResult: evalResult,
        evalConfig: const EvalConfig(),
      ),
      recommendations: const RuleBasedRecommendationEngine().build(
        dataset: dataset,
        modelRun: run,
        evalResult: evalResult,
        evalConfig: const EvalConfig(),
      ),
      confusionDetails: const ConfusionMatrixDetailBuilder().build(
        dataset: dataset,
        modelRun: run,
        config: const EvalConfig(),
      ),
    );
    final List<int> bytes = const XlsxReportBuilder().buildWorkbook(data);

    expect(bytes, isNotEmpty);
    final Archive archive = ZipDecoder().decodeBytes(bytes);
    expect(_entryNames(archive), contains('xl/workbook.xml'));
    expect(_entryNames(archive), contains('xl/worksheets/sheet1.xml'));

    final String workbook = _entryText(archive, 'xl/workbook.xml');
    for (final String sheetName in [
      'Summary',
      'Per-Class Metrics',
      'Image Errors',
      'Matches',
      'Small Object Stats',
      'Confusion Matrix',
      'Worst Cases',
      'Dataset Health',
      'Recommendations',
    ]) {
      expect(workbook, contains('name="$sheetName"'));
    }
  });

  test('per-class and image error rows counts are correct', () {
    final XlsxWorkbookData data = const XlsxReportBuilder().buildData(
      dataset: dataset,
      modelRun: run,
      evalConfig: const EvalConfig(),
      evalResult: evalResult,
      projectName: 'mini',
      modelRunName: 'Run 1',
      generatedAt: DateTime(2026),
      matchRows: matchRows,
      imageIds: imageIds,
    );

    final XlsxSheetData perClass = data.sheets.firstWhere(
      (XlsxSheetData sheet) => sheet.name == 'Per-Class Metrics',
    );
    final XlsxSheetData imageErrors = data.sheets.firstWhere(
      (XlsxSheetData sheet) => sheet.name == 'Image Errors',
    );

    expect(perClass.rows.length, dataset.categoriesById.length + 1);
    expect(imageErrors.rows.length, dataset.imagesById.length + 1);
  });

  test('optional sections missing do not crash', () {
    final XlsxWorkbookData data = const XlsxReportBuilder().buildData(
      dataset: dataset,
      modelRun: run,
      evalConfig: const EvalConfig(),
      evalResult: evalResult,
      projectName: 'mini',
      modelRunName: 'Run 1',
      generatedAt: DateTime(2026),
      matchRows: matchRows,
      imageIds: imageIds,
    );
    final List<int> bytes = const XlsxReportBuilder().buildWorkbook(data);

    expect(bytes, isNotEmpty);
    expect(data.sheets.map((XlsxSheetData sheet) => sheet.name), isNot(contains('Dataset Health')));
    expect(data.sheets.map((XlsxSheetData sheet) => sheet.name), isNot(contains('Recommendations')));
  });

  test('UTF-8 names do not crash', () {
    final CocoDataset utfDataset = CocoDataset(
      imagesById: const {
        1: ImageRecord(id: 1, fileName: 'изображение.png', width: 100, height: 100),
      },
      categoriesById: const {
        1: CategoryRecord(id: 1, name: 'красный'),
      },
      annotations: const [
        GroundTruthAnnotation(
          id: 1,
          imageId: 1,
          categoryId: 1,
          bbox: BBox(x: 10, y: 10, width: 20, height: 20),
        ),
      ],
    );
    final ModelRun utfRun = ModelRun(
      id: 'run',
      name: 'Модель',
      predictions: const [
        Prediction(
          imageId: 1,
          categoryId: 1,
          bbox: BBox(x: 10, y: 10, width: 20, height: 20),
          score: 0.9,
        ),
      ],
    );
    final EvalResult utfEval = const MetricsCalculator().evaluate(
      dataset: utfDataset,
      modelRun: utfRun,
      config: const EvalConfig(),
    );
    final XlsxWorkbookData data = const XlsxReportBuilder().buildData(
      dataset: utfDataset,
      modelRun: utfRun,
      evalConfig: const EvalConfig(),
      evalResult: utfEval,
      projectName: 'Проект',
      modelRunName: 'Модель',
      generatedAt: DateTime(2026),
      matchRows: buildMatchRows(
        dataset: utfDataset,
        modelRun: utfRun,
        matches: utfEval.matches,
      ),
      imageIds: const [1],
    );
    final List<int> bytes = const XlsxReportBuilder().buildWorkbook(data);
    final Archive archive = ZipDecoder().decodeBytes(bytes);

    expect(bytes, isNotEmpty);
    expect(_entryText(archive, 'xl/worksheets/sheet1.xml'), contains('Проект'));
  });

  test('empty predictions do not crash', () {
    final ModelRun emptyRun = ModelRun(
      id: 'empty',
      name: 'Empty',
      predictions: const [],
    );
    final EvalResult emptyEval = const MetricsCalculator().evaluate(
      dataset: dataset,
      modelRun: emptyRun,
      config: const EvalConfig(),
    );
    final XlsxWorkbookData data = const XlsxReportBuilder().buildData(
      dataset: dataset,
      modelRun: emptyRun,
      evalConfig: const EvalConfig(),
      evalResult: emptyEval,
      projectName: 'mini',
      modelRunName: 'Empty',
      generatedAt: DateTime(2026),
      matchRows: buildMatchRows(
        dataset: dataset,
        modelRun: emptyRun,
        matches: emptyEval.matches,
      ),
      imageIds: imageIds,
    );

    expect(const XlsxReportBuilder().buildWorkbook(data), isNotEmpty);
  });

  test('report bundle includes xlsx binary file when requested', () async {
    final ReportBundle bundle = await const ReportBundleBuilder().build(
      dataset: dataset,
      modelRun: run,
      evalConfig: const EvalConfig(),
      evalResult: evalResult,
      components: const ReportComponents(includeXlsxWorkbook: true),
      projectName: 'mini',
      modelRunName: 'Run 1',
    );

    expect(bundle.binaryFiles.containsKey(ReportFileNames.xlsx), isTrue);
    expect(bundle.binaryFiles[ReportFileNames.xlsx], isNotEmpty);
    expect(bundle.fileNames, contains(ReportFileNames.xlsx));
  });
}

DatasetHealthReport _healthReport() {
  return DatasetHealthReport(
    issues: const [
      DatasetHealthIssue(
        severity: DatasetIssueSeverity.warning,
        type: DatasetIssueType.rareClass,
        title: 'Rare class',
        message: 'Class is rare',
        categoryId: 1,
        categoryName: 'red',
      ),
    ],
    errorCount: 0,
    warningCount: 1,
    infoCount: 0,
    missingImageCount: 0,
    invalidAnnotationCount: 0,
    invalidPredictionCount: 0,
    imageWithoutGtCount: 0,
    unusedImageFileCount: 0,
    rareClassCount: 1,
    gtCountByClass: const {1: 1},
    gtPercentByClass: const {1: 1},
    generatedAt: DateTime(2026),
  );
}

Set<String> _entryNames(Archive archive) {
  return archive.files.map((ArchiveFile file) => file.name).toSet();
}

String _entryText(Archive archive, String name) {
  final ArchiveFile file = archive.files.firstWhere(
    (ArchiveFile file) => file.name == name,
  );
  return utf8.decode(file.content as List<int>);
}
