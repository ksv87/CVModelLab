import 'dart:io';

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

  PdfReportData _buildData({
    DatasetHealthReport? healthReport,
    WorstCasesResult? worstCases,
    ConfusionMatrixDetails? confusionDetails,
    ModelComparisonResult? comparison,
    List<Recommendation> recommendations = const [],
  }) {
    return const PdfReportBuilder().buildData(
      dataset: dataset,
      modelRun: run,
      evalConfig: const EvalConfig(),
      evalResult: evalResult,
      projectName: 'mini',
      modelRunName: 'Run 1',
      generatedAt: DateTime(2026),
      matchRows: matchRows,
      healthReport: healthReport,
      worstCases: worstCases,
      confusionDetails: confusionDetails,
      comparison: comparison,
      recommendations: recommendations,
    );
  }

  test('PDF bytes are non-empty and start with PDF magic', () async {
    final data = _buildData();
    final bytes = await const PdfReportBuilder().buildPdf(data);

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), equals('%PDF'));
  });

  test('mini dataset does not crash', () async {
    final data = _buildData(
      healthReport: _healthReport(),
      worstCases: const WorstCaseMiner().mine(
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
      recommendations: const RuleBasedRecommendationEngine().build(
        dataset: dataset,
        modelRun: run,
        evalResult: evalResult,
        evalConfig: const EvalConfig(),
      ),
    );
    final bytes = await const PdfReportBuilder().buildPdf(data);
    expect(bytes, isNotEmpty);
  });

  test('missing optional sections do not crash', () async {
    final data = _buildData();
    expect(data.healthReport, isNull);
    expect(data.worstCases, isNull);
    expect(data.confusionDetails, isNull);
    expect(data.comparison, isNull);
    expect(data.recommendations, isEmpty);

    final bytes = await const PdfReportBuilder().buildPdf(data);
    expect(bytes, isNotEmpty);
  });

  test('recommendations included when available', () async {
    final recs = const RuleBasedRecommendationEngine().build(
      dataset: dataset,
      modelRun: run,
      evalResult: evalResult,
      evalConfig: const EvalConfig(),
    );
    final data = _buildData(recommendations: recs);

    expect(data.recommendations, isNotEmpty);
    final bytes = await const PdfReportBuilder().buildPdf(data);
    expect(bytes, isNotEmpty);
  });

  test('comparison section included when comparison exists', () async {
    final comparison = const ModelComparator().compare(
      dataset: dataset,
      baseRun: run,
      baseEval: evalResult,
      candidateRun: run,
      candidateEval: evalResult,
      evalConfig: const EvalConfig(),
    );
    final data = _buildData(comparison: comparison);

    expect(data.comparison, isNotNull);
    final bytes = await const PdfReportBuilder().buildPdf(data);
    expect(bytes, isNotEmpty);
  });

  test('empty predictions do not crash', () async {
    final emptyRun = ModelRun(
      id: 'empty',
      name: 'Empty',
      predictions: const [],
    );
    final emptyEval = const MetricsCalculator().evaluate(
      dataset: dataset,
      modelRun: emptyRun,
      config: const EvalConfig(),
    );
    final emptyRows = buildMatchRows(
      dataset: dataset,
      modelRun: emptyRun,
      matches: emptyEval.matches,
    );
    final data = const PdfReportBuilder().buildData(
      dataset: dataset,
      modelRun: emptyRun,
      evalConfig: const EvalConfig(),
      evalResult: emptyEval,
      projectName: 'mini',
      modelRunName: 'Empty',
      generatedAt: DateTime(2026),
      matchRows: emptyRows,
    );

    final bytes = await const PdfReportBuilder().buildPdf(data);
    expect(bytes, isNotEmpty);
  });

  test('UTF-8 class names do not crash', () async {
    final utfDataset = CocoDataset(
      imagesById: const {
        1: ImageRecord(
          id: 1,
          fileName: 'изображение.png',
          width: 100,
          height: 100,
        ),
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
    final utfRun = ModelRun(
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
    final utfEval = const MetricsCalculator().evaluate(
      dataset: utfDataset,
      modelRun: utfRun,
      config: const EvalConfig(),
    );
    final data = const PdfReportBuilder().buildData(
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
    );

    final bytes = await const PdfReportBuilder().buildPdf(data);
    expect(bytes, isNotEmpty);
  });

  test('report bundle includes PDF binary file when requested', () async {
    final bundle = await const ReportBundleBuilder().build(
      dataset: dataset,
      modelRun: run,
      evalConfig: const EvalConfig(),
      evalResult: evalResult,
      components: const ReportComponents(includePdfReport: true),
      projectName: 'mini',
      modelRunName: 'Run 1',
    );

    expect(bundle.binaryFiles.containsKey(ReportFileNames.pdf), isTrue);
    expect(bundle.binaryFiles[ReportFileNames.pdf], isNotEmpty);
    expect(bundle.fileNames, contains(ReportFileNames.pdf));
  });

  test('XLSX and PDF are independent — only PDF when requested', () async {
    final bundle = await const ReportBundleBuilder().build(
      dataset: dataset,
      modelRun: run,
      evalConfig: const EvalConfig(),
      evalResult: evalResult,
      components: const ReportComponents(
        includeHtml: false,
        includePerClassMetricsCsv: false,
        includeImageErrorsCsv: false,
        includeMatchesCsv: false,
        includeXlsxWorkbook: false,
        includePdfReport: true,
      ),
      projectName: 'mini',
      modelRunName: 'Run 1',
    );

    expect(bundle.binaryFiles.containsKey(ReportFileNames.pdf), isTrue);
    expect(bundle.binaryFiles.containsKey(ReportFileNames.xlsx), isFalse);
    expect(bundle.csvFiles, isEmpty);
    expect(bundle.htmlReport, isEmpty);
  });

  test('HTML-only export produces no CSV files', () async {
    final bundle = await const ReportBundleBuilder().build(
      dataset: dataset,
      modelRun: run,
      evalConfig: const EvalConfig(),
      evalResult: evalResult,
      components: const ReportComponents(
        includeHtml: true,
        includePerClassMetricsCsv: false,
        includeImageErrorsCsv: false,
        includeMatchesCsv: false,
        includeXlsxWorkbook: false,
        includePdfReport: false,
      ),
      projectName: 'mini',
      modelRunName: 'Run 1',
    );

    expect(bundle.hasHtml, isTrue);
    expect(bundle.csvFiles, isEmpty);
    expect(bundle.binaryFiles, isEmpty);
  });

  test('XLSX-only export produces no CSV files', () async {
    final bundle = await const ReportBundleBuilder().build(
      dataset: dataset,
      modelRun: run,
      evalConfig: const EvalConfig(),
      evalResult: evalResult,
      components: const ReportComponents(
        includeHtml: false,
        includePerClassMetricsCsv: false,
        includeImageErrorsCsv: false,
        includeMatchesCsv: false,
        includeXlsxWorkbook: true,
        includePdfReport: false,
      ),
      projectName: 'mini',
      modelRunName: 'Run 1',
    );

    expect(bundle.binaryFiles.containsKey(ReportFileNames.xlsx), isTrue);
    expect(bundle.csvFiles, isEmpty);
    expect(bundle.htmlReport, isEmpty);
  });

  test('PDF with all sections disabled still produces a file', () async {
    final bundle = await const ReportBundleBuilder().build(
      dataset: dataset,
      modelRun: run,
      evalConfig: const EvalConfig(),
      evalResult: evalResult,
      components: const ReportComponents(
        includeHtml: false,
        includePerClassMetricsCsv: false,
        includeImageErrorsCsv: false,
        includeMatchesCsv: false,
        includePdfReport: true,
        pdfOptions: PdfReportOptions(
          includeRecommendations: false,
          includeWorstCases: false,
          includeComparison: false,
          includeHealth: false,
          includeConfusion: false,
        ),
      ),
      projectName: 'mini',
      modelRunName: 'Run 1',
    );

    expect(bundle.binaryFiles[ReportFileNames.pdf], isNotEmpty);
  });

  test('imageIds param is correct for mini dataset', () {
    expect(imageIds, equals([1, 2, 3, 4, 5]));
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
