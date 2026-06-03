import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../ap_eval/ap_eval_models.dart';
import '../comparison/comparison_models.dart';
import '../eval/class_stats.dart';
import '../eval/confusion_details.dart';
import '../eval/small_object_stats.dart';
import '../health/dataset_health_models.dart';
import '../i18n/message_key.dart';
import '../model/annotation.dart';
import '../model/coco_dataset.dart';
import '../model/eval_config.dart';
import '../model/eval_result.dart';
import '../model/model_run.dart';
import '../model/prediction.dart';
import '../recommendation/recommendation_models.dart';
import '../worst_cases/worst_case_models.dart';
import 'report_models.dart';
import 'xlsx_report_data.dart';
import '../../ui/l10n/app_localizations.dart';

class XlsxReportBuilder {
  const XlsxReportBuilder();

  Uint8List buildWorkbook(XlsxWorkbookData data) {
    final List<XlsxSheetData> sheets = _safeSheets(data.sheets);
    final Archive archive = Archive();

    void add(String path, String content) {
      final List<int> bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    add('[Content_Types].xml', _contentTypes(sheets.length));
    add('_rels/.rels', _rootRels());
    add('xl/workbook.xml', _workbook(sheets));
    add('xl/_rels/workbook.xml.rels', _workbookRels(sheets.length));
    add('xl/styles.xml', _styles());
    for (var i = 0; i < sheets.length; i += 1) {
      add('xl/worksheets/sheet${i + 1}.xml', _worksheet(sheets[i]));
    }

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  XlsxWorkbookData buildData({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required EvalConfig evalConfig,
    required EvalResult evalResult,
    required String projectName,
    required String modelRunName,
    required DateTime generatedAt,
    required List<ReportMatchRow> matchRows,
    required List<int> imageIds,
    Set<String> missingImageFileNames = const <String>{},
    DatasetHealthReport? healthReport,
    WorstCasesResult? worstCases,
    List<Recommendation> recommendations = const <Recommendation>[],
    ConfusionMatrixDetails? confusionDetails,
    ModelComparisonResult? comparison,
    ApEvalResult? apEvalResult,
    AppLocalizations? localizations,
  }) {
    final AppLocalizations l10n =
        localizations ?? AppLocalizations.forLocale(AppLocale.en);
    final List<XlsxSheetData> sheets = [
      XlsxSheetData(
        name: _localizedSheetName(
          l10n,
          MessageKey.reportDatasetSummary,
          'Summary',
        ),
        rows: _summaryRows(
          projectName: projectName,
          modelRunName: modelRunName,
          generatedAt: generatedAt,
          evalResult: evalResult,
        ),
      ),
      XlsxSheetData(
        name: _localizedSheetName(
          l10n,
          MessageKey.reportPerClassMetrics,
          'Per-Class Metrics',
        ),
        rows: _perClassRows(evalResult),
      ),
      XlsxSheetData(
        name: _localizedSheetName(
          l10n,
          MessageKey.reportImageErrors,
          'Image Errors',
        ),
        rows: _imageErrorRows(
          dataset: dataset,
          modelRun: modelRun,
          evalConfig: evalConfig,
          evalResult: evalResult,
          imageIds: imageIds,
          missingImageFileNames: missingImageFileNames,
        ),
      ),
      XlsxSheetData(
        name: _localizedSheetName(l10n, MessageKey.reportMatches, 'Matches'),
        rows: _matchRows(matchRows),
      ),
    ];

    if (evalResult.smallObjectStats.isNotEmpty) {
      sheets.add(
        XlsxSheetData(
          name: _localizedSheetName(
            l10n,
            MessageKey.reportSmallObjectStats,
            'Small Object Stats',
          ),
          rows: _smallObjectRows(dataset, evalResult),
        ),
      );
    }
    if (confusionDetails != null) {
      sheets.add(
        XlsxSheetData(
          name: _localizedSheetName(
            l10n,
            MessageKey.reportConfusionMatrix,
            'Confusion Matrix',
          ),
          rows: _confusionRows(confusionDetails),
        ),
      );
    }
    if (worstCases != null &&
        worstCases.categories.any((g) => g.items.isNotEmpty)) {
      sheets.add(
        XlsxSheetData(
          name: _localizedSheetName(
            l10n,
            MessageKey.reportWorstCases,
            'Worst Cases',
          ),
          rows: _worstRows(worstCases),
        ),
      );
    }
    if (healthReport != null) {
      sheets.add(
        XlsxSheetData(
          name: _localizedSheetName(
            l10n,
            MessageKey.reportDatasetHealth,
            'Dataset Health',
          ),
          rows: _healthRows(healthReport, l10n),
        ),
      );
    }
    if (recommendations.isNotEmpty) {
      sheets.add(
        XlsxSheetData(
          name: _localizedSheetName(
            l10n,
            MessageKey.reportRecommendations,
            'Recommendations',
          ),
          rows: _recommendationRows(recommendations, l10n),
        ),
      );
    }
    if (comparison != null) {
      sheets
        ..add(
          XlsxSheetData(
            name: l10n.locale == AppLocale.ru
                ? _sheetName(
                    '${l10n.t(MessageKey.reportModelComparison)} class',
                  )
                : 'Comparison Per-Class',
            rows: _comparisonPerClassRows(comparison),
          ),
        )
        ..add(
          XlsxSheetData(
            name: l10n.locale == AppLocale.ru
                ? _sheetName(
                    '${l10n.t(MessageKey.reportModelComparison)} images',
                  )
                : 'Comparison Images',
            rows: _comparisonImageRows(comparison),
          ),
        );
    }
    if (apEvalResult != null) {
      sheets.add(
        XlsxSheetData(
          name: _localizedSheetName(
            l10n,
            MessageKey.reportCocoApMetrics,
            'AP Metrics',
          ),
          rows: _apMetricsRows(apEvalResult),
        ),
      );
    }

    return XlsxWorkbookData(sheets: sheets);
  }

  List<List<Object?>> _summaryRows({
    required String projectName,
    required String modelRunName,
    required DateTime generatedAt,
    required EvalResult evalResult,
  }) {
    final OverallStats o = evalResult.overall;
    final double precision = _safeRatio(o.totalTp, o.totalTp + o.totalFp);
    final double recall = _safeRatio(o.totalTp, o.totalTp + o.totalFn);
    final double f1 = _f1(precision, recall);
    return [
      const ['field', 'value'],
      ['project_name', projectName],
      ['model_run_name', modelRunName],
      ['generated_at', generatedAt.toIso8601String()],
      ['total_images', o.totalImages],
      ['total_gt', o.totalGt],
      ['total_predictions_before_threshold', o.totalPredictionsBeforeThreshold],
      ['total_predictions_after_threshold', o.totalPredictionsAfterThreshold],
      ['tp', o.totalTp],
      ['fp', o.totalFp],
      ['fn', o.totalFn],
      ['precision', precision],
      ['recall', recall],
      ['f1', f1],
      ['micro_precision', o.microPrecision],
      ['micro_recall', o.microRecall],
      ['micro_f1', o.microF1],
      ['macro_precision', o.macroPrecision],
      ['macro_recall', o.macroRecall],
      ['macro_f1', o.macroF1],
      ['images_with_any_error', o.imagesWithAnyError],
      ['images_with_fp', o.imagesWithFp],
      ['images_with_fn', o.imagesWithFn],
    ];
  }

  List<List<Object?>> _perClassRows(EvalResult evalResult) {
    final List<ClassStats> stats = evalResult.perClassStats.values.toList()
      ..sort((ClassStats a, ClassStats b) {
        final int byRecall = a.recall.compareTo(b.recall);
        if (byRecall != 0) {
          return byRecall;
        }
        final int byFn = b.fn.compareTo(a.fn);
        if (byFn != 0) {
          return byFn;
        }
        return a.categoryName.compareTo(b.categoryName);
      });
    return [
      const [
        'class_id',
        'class_name',
        'gt_count',
        'pred_count',
        'tp',
        'fp',
        'fn',
        'precision',
        'recall',
        'f1',
      ],
      for (final ClassStats stat in stats)
        [
          stat.categoryId,
          stat.categoryName,
          stat.gtCount,
          stat.predCount,
          stat.tp,
          stat.fp,
          stat.fn,
          stat.precision,
          stat.recall,
          stat.f1,
        ],
    ];
  }

  List<List<Object?>> _imageErrorRows({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required EvalConfig evalConfig,
    required EvalResult evalResult,
    required List<int> imageIds,
    required Set<String> missingImageFileNames,
  }) {
    return [
      const [
        'image_id',
        'file_name',
        'gt_count',
        'pred_count',
        'tp',
        'fp',
        'fn',
        'has_error',
        'has_fp',
        'has_fn',
        'has_class_confusion',
        'has_small_object',
        'missing_image',
      ],
      for (final int imageId in imageIds)
        [
          imageId,
          dataset.imagesById[imageId]?.fileName ?? '',
          _gtCount(dataset, evalConfig, imageId),
          _predCount(modelRun, evalConfig, imageId),
          evalResult.imageSummaries[imageId]?.tp ?? 0,
          evalResult.imageSummaries[imageId]?.fp ?? 0,
          evalResult.imageSummaries[imageId]?.fn ?? 0,
          (evalResult.imageSummaries[imageId]?.fp ?? 0) > 0 ||
              (evalResult.imageSummaries[imageId]?.fn ?? 0) > 0,
          (evalResult.imageSummaries[imageId]?.fp ?? 0) > 0,
          (evalResult.imageSummaries[imageId]?.fn ?? 0) > 0,
          evalResult.imageSummaries[imageId]?.hasClassConfusion ?? false,
          evalResult.imageSummaries[imageId]?.hasSmallObject ?? false,
          missingImageFileNames.contains(
            dataset.imagesById[imageId]?.fileName ?? '',
          ),
        ],
    ];
  }

  List<List<Object?>> _matchRows(List<ReportMatchRow> matchRows) {
    return [
      const [
        'image_id',
        'file_name',
        'match_type',
        'category_id',
        'category_name',
        'score',
        'iou',
        'reason',
        'bbox_x',
        'bbox_y',
        'bbox_w',
        'bbox_h',
        'gt_annotation_id',
        'prediction_index',
      ],
      for (final ReportMatchRow row in matchRows)
        [
          row.imageId,
          row.fileName,
          row.matchType,
          row.categoryId,
          row.categoryName,
          row.score,
          row.iou,
          row.reason,
          row.bbox?.x,
          row.bbox?.y,
          row.bbox?.width,
          row.bbox?.height,
          row.gtAnnotationId,
          row.predictionIndex,
        ],
    ];
  }

  List<List<Object?>> _smallObjectRows(
    CocoDataset dataset,
    EvalResult evalResult,
  ) {
    final List<List<Object?>> rows = [
      const [
        'class_id',
        'class_name',
        'size_bucket',
        'gt_count',
        'tp',
        'fn',
        'recall',
      ],
    ];
    final List<int> classIds = evalResult.smallObjectStats.keys.toList()
      ..sort();
    for (final int classId in classIds) {
      final String className =
          dataset.categoriesById[classId]?.name ?? '$classId';
      for (final ObjectSizeBucket bucket in ObjectSizeBucket.values) {
        final SmallObjectClassStats? stat =
            evalResult.smallObjectStats[classId]?[bucket];
        if (stat == null) {
          continue;
        }
        rows.add([
          classId,
          className,
          bucket.name,
          stat.gtCount,
          stat.tp,
          stat.fn,
          stat.recall,
        ]);
      }
    }
    return rows;
  }

  List<List<Object?>> _confusionRows(ConfusionMatrixDetails details) {
    return [
      const [
        'gt_class_id',
        'gt_class_name',
        'pred_class_id',
        'pred_class_name',
        'count',
        'row_percent',
      ],
      for (final ConfusionPair pair in details.pairs(includeDiagonal: true))
        [
          pair.gtCategoryId,
          pair.gtClass,
          pair.predCategoryId,
          pair.predClass,
          pair.count,
          pair.rowPercent,
        ],
    ];
  }

  List<List<Object?>> _worstRows(WorstCasesResult worstCases) {
    final List<List<Object?>> rows = [
      const [
        'category',
        'image_id',
        'file_name',
        'title',
        'reason',
        'tp',
        'fp',
        'fn',
        'score',
        'iou',
        'severity_score',
      ],
    ];
    for (final group in worstCases.categories) {
      for (final WorstCaseItem item in group.items) {
        rows.add([
          group.key,
          item.imageId,
          item.fileName,
          item.title,
          item.reason,
          item.tp,
          item.fp,
          item.fn,
          item.score,
          item.iou,
          item.severityScore,
        ]);
      }
    }
    return rows;
  }

  List<List<Object?>> _healthRows(
    DatasetHealthReport report,
    AppLocalizations l10n,
  ) {
    return [
      const [
        'severity',
        'type',
        'image_id',
        'file_name',
        'annotation_id',
        'category_id',
        'category_name',
        'title',
        'message',
        'recommendation',
        'details_json',
      ],
      for (final DatasetHealthIssue issue in report.issues)
        [
          issue.severity.name,
          issue.type.name,
          issue.imageId,
          issue.fileName,
          issue.annotationId,
          issue.categoryId,
          issue.categoryName,
          l10n.datasetIssueTitle(issue),
          l10n.datasetIssueMessage(issue),
          l10n.datasetIssueRecommendation(issue),
          issue.details.isEmpty ? '' : jsonEncode(issue.details),
        ],
    ];
  }

  List<List<Object?>> _recommendationRows(
    List<Recommendation> recommendations,
    AppLocalizations l10n,
  ) {
    return [
      const [
        'severity',
        'category',
        'title',
        'message',
        'action',
        'related_image_ids',
        'related_category_ids',
        'evidence_json',
      ],
      for (final Recommendation recommendation in recommendations)
        [
          recommendation.severity.name,
          recommendation.category.name,
          l10n.recommendationTitle(recommendation),
          l10n.recommendationMessage(recommendation),
          l10n.recommendationAction(recommendation),
          recommendation.relatedImageIds.join(' '),
          recommendation.relatedCategoryIds.join(' '),
          recommendation.evidence.isEmpty
              ? ''
              : jsonEncode(recommendation.evidence),
        ],
    ];
  }

  List<List<Object?>> _comparisonPerClassRows(
    ModelComparisonResult comparison,
  ) {
    return [
      const [
        'class_id',
        'class_name',
        'base_precision',
        'candidate_precision',
        'delta_precision',
        'base_recall',
        'candidate_recall',
        'delta_recall',
        'base_f1',
        'candidate_f1',
        'delta_f1',
        'base_tp',
        'candidate_tp',
        'delta_tp',
        'base_fp',
        'candidate_fp',
        'delta_fp',
        'base_fn',
        'candidate_fn',
        'delta_fn',
      ],
      for (final ClassMetricsDiff item in comparison.perClassDiffs)
        [
          item.categoryId,
          item.categoryName,
          item.diff.basePrecision,
          item.diff.candidatePrecision,
          item.diff.deltaPrecision,
          item.diff.baseRecall,
          item.diff.candidateRecall,
          item.diff.deltaRecall,
          item.diff.baseF1,
          item.diff.candidateF1,
          item.diff.deltaF1,
          item.diff.baseTp,
          item.diff.candidateTp,
          item.diff.deltaTp,
          item.diff.baseFp,
          item.diff.candidateFp,
          item.diff.deltaFp,
          item.diff.baseFn,
          item.diff.candidateFn,
          item.diff.deltaFn,
        ],
    ];
  }

  List<List<Object?>> _apMetricsRows(ApEvalResult result) {
    final List<List<Object?>> rows = [
      const ['metric', 'value'],
      ['AP@[.5:.95]', result.ap],
      ['AP50', result.ap50],
      ['AP75', result.ap75],
      ['APsmall', result.apSmall],
      ['APmedium', result.apMedium],
      ['APlarge', result.apLarge],
      ['AR1', result.ar1],
      ['AR10', result.ar10],
      ['AR100', result.ar100],
      ['ARsmall', result.arSmall],
      ['ARmedium', result.arMedium],
      ['ARlarge', result.arLarge],
    ];
    if (result.perClass.isNotEmpty) {
      rows
        ..add(const [])
        ..add(const ['class_id', 'class_name', 'ap', 'ap50', 'ap75', 'ar']);
      for (final ClassApMetric cls in result.perClass) {
        rows.add([
          cls.categoryId,
          cls.categoryName,
          cls.ap,
          cls.ap50,
          cls.ap75,
          cls.ar,
        ]);
      }
    }
    return rows;
  }

  List<List<Object?>> _comparisonImageRows(ModelComparisonResult comparison) {
    return [
      const [
        'image_id',
        'file_name',
        'status',
        'base_tp',
        'base_fp',
        'base_fn',
        'candidate_tp',
        'candidate_fp',
        'candidate_fn',
        'delta_tp',
        'delta_fp',
        'delta_fn',
      ],
      for (final ImageComparisonSummary item in comparison.imageSummaries)
        [
          item.imageId,
          item.fileName,
          item.status.name,
          item.baseTp,
          item.baseFp,
          item.baseFn,
          item.candidateTp,
          item.candidateFp,
          item.candidateFn,
          item.deltaTp,
          item.deltaFp,
          item.deltaFn,
        ],
    ];
  }

  String _contentTypes(int sheetCount) {
    final StringBuffer xml = StringBuffer();
    xml.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    xml.write(
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
    );
    xml.write(
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
    );
    xml.write('<Default Extension="xml" ContentType="application/xml"/>');
    xml.write(
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
    );
    xml.write(
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>',
    );
    for (var i = 1; i <= sheetCount; i += 1) {
      xml.write(
        '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
      );
    }
    xml.write('</Types>');
    return xml.toString();
  }

  String _rootRels() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>';
  }

  String _workbook(List<XlsxSheetData> sheets) {
    final StringBuffer xml = StringBuffer();
    xml.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    xml.write(
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>',
    );
    for (var i = 0; i < sheets.length; i += 1) {
      xml.write(
        '<sheet name="${_xml(sheets[i].name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>',
      );
    }
    xml.write('</sheets></workbook>');
    return xml.toString();
  }

  String _workbookRels(int sheetCount) {
    final StringBuffer xml = StringBuffer();
    xml.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    xml.write(
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    );
    for (var i = 1; i <= sheetCount; i += 1) {
      xml.write(
        '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>',
      );
    }
    xml.write(
      '<Relationship Id="rId${sheetCount + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>',
    );
    xml.write('</Relationships>');
    return xml.toString();
  }

  String _styles() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
        '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>'
        '<borders count="1"><border/></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>'
        '</styleSheet>';
  }

  String _worksheet(XlsxSheetData sheet) {
    final StringBuffer xml = StringBuffer();
    xml.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    xml.write(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    );
    xml.write(
      '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>',
    );
    xml.write('<sheetData>');
    for (var rowIndex = 0; rowIndex < sheet.rows.length; rowIndex += 1) {
      final List<Object?> row = sheet.rows[rowIndex];
      xml.write('<row r="${rowIndex + 1}">');
      for (var colIndex = 0; colIndex < row.length; colIndex += 1) {
        xml.write(
          _cell(
            row[rowIndex >= 0 ? colIndex : colIndex],
            rowIndex,
            colIndex,
          ),
        );
      }
      xml.write('</row>');
    }
    xml.write('</sheetData></worksheet>');
    return xml.toString();
  }

  String _cell(Object? value, int rowIndex, int colIndex) {
    final String ref = '${_columnName(colIndex)}${rowIndex + 1}';
    final String style = rowIndex == 0 ? ' s="1"' : '';
    if (value == null) {
      return '<c r="$ref"$style/>';
    }
    if (value is bool) {
      return '<c r="$ref"$style t="b"><v>${value ? 1 : 0}</v></c>';
    }
    if (value is num) {
      return '<c r="$ref"$style><v>${value.toString()}</v></c>';
    }
    return '<c r="$ref"$style t="inlineStr"><is><t>${_xml(value.toString())}</t></is></c>';
  }

  List<XlsxSheetData> _safeSheets(List<XlsxSheetData> sheets) {
    final Set<String> used = {};
    return [
      for (final XlsxSheetData sheet in sheets)
        XlsxSheetData(
          name: _safeSheetName(sheet.name, used),
          rows: sheet.rows,
        ),
    ];
  }

  String _safeSheetName(String name, Set<String> used) {
    String safe = name.replaceAll(RegExp(r'[\[\]\*\?/\\:]'), ' ').trim();
    if (safe.isEmpty) {
      safe = 'Sheet';
    }
    if (safe.length > 31) {
      safe = safe.substring(0, 31);
    }
    String candidate = safe;
    var suffix = 2;
    while (used.contains(candidate)) {
      final String marker = ' $suffix';
      final int maxBaseLength = 31 - marker.length;
      candidate =
          '${safe.substring(0, safe.length.clamp(0, maxBaseLength))}$marker';
      suffix += 1;
    }
    used.add(candidate);
    return candidate;
  }

  String _columnName(int index) {
    var n = index + 1;
    final StringBuffer result = StringBuffer();
    while (n > 0) {
      final int rem = (n - 1) % 26;
      result.writeCharCode(65 + rem);
      n = (n - rem - 1) ~/ 26;
    }
    return result.toString().split('').reversed.join();
  }

  String _xml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _sheetName(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (sanitized.isEmpty) {
      return 'Sheet';
    }
    return sanitized.length <= 31 ? sanitized : sanitized.substring(0, 31);
  }

  String _localizedSheetName(
    AppLocalizations l10n,
    MessageKey key,
    String englishFallback,
  ) {
    return l10n.locale == AppLocale.ru
        ? _sheetName(l10n.t(key))
        : englishFallback;
  }

  int _gtCount(CocoDataset dataset, EvalConfig config, int imageId) {
    final List<GroundTruthAnnotation> annotations =
        dataset.annotationsByImageId[imageId] ??
            const <GroundTruthAnnotation>[];
    if (!config.ignoreCrowd) {
      return annotations.length;
    }
    return annotations.where((GroundTruthAnnotation a) => !a.isCrowd).length;
  }

  int _predCount(ModelRun modelRun, EvalConfig config, int imageId) {
    final List<Prediction> predictions =
        modelRun.predictionsByImageId[imageId] ?? const <Prediction>[];
    return predictions
        .where((Prediction p) => p.score >= config.confidenceThreshold)
        .length;
  }

  double _safeRatio(int numerator, int denominator) {
    return denominator == 0 ? 0 : numerator / denominator;
  }

  double _f1(double precision, double recall) {
    return precision + recall == 0
        ? 0
        : 2 * precision * recall / (precision + recall);
  }
}
