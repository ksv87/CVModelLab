import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../ap_eval/ap_eval_models.dart';
import '../comparison/comparison_models.dart';
import '../comparison/multi_model_comparison_models.dart';
import '../eval/class_stats.dart';
import '../eval/confusion_details.dart';
import '../health/dataset_health_models.dart';
import '../i18n/message_key.dart';
import '../model/coco_dataset.dart';
import '../model/eval_config.dart';
import '../model/eval_result.dart';
import '../model/model_run.dart';
import '../recommendation/recommendation_models.dart';
import '../worst_cases/worst_case_models.dart';
import 'pdf_report_data.dart';
import 'report_models.dart';
import '../../ui/l10n/app_localizations.dart';

// ─── brand colours ────────────────────────────────────────────────────────────
const _kPrimary = PdfColor.fromInt(0x3949AB); // indigo 600
const _kPrimaryDark = PdfColor.fromInt(0x283593); // indigo 800
const _kPrimaryLight = PdfColor.fromInt(0xE8EAF6); // indigo 50
const _kTableHeader = PdfColor.fromInt(0x1A237E); // indigo 900
const _kBorder = PdfColor.fromInt(0xBDBDBD); // grey 400
const _kRowAlt = PdfColor.fromInt(0xFAFAFA); // grey 50
const _kLabel = PdfColor.fromInt(0x757575); // grey 600
const _kMuted = PdfColor.fromInt(0x9E9E9E); // grey 500
const _kDark = PdfColor.fromInt(0x212121); // grey 900

class PdfReportBuilder {
  const PdfReportBuilder();

  // ─── data extraction ──────────────────────────────────────────────────────

  PdfReportData buildData({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required EvalConfig evalConfig,
    required EvalResult evalResult,
    required String projectName,
    required String modelRunName,
    required DateTime generatedAt,
    required List<ReportMatchRow> matchRows,
    Set<String> missingImageFileNames = const <String>{},
    DatasetHealthReport? healthReport,
    WorstCasesResult? worstCases,
    ConfusionMatrixDetails? confusionDetails,
    ModelComparisonResult? comparison,
    MultiModelComparisonResult? multiComparison,
    List<Recommendation> recommendations = const <Recommendation>[],
    ApEvalResult? apEvalResult,
    AppLocale locale = AppLocale.en,
  }) {
    final o = evalResult.overall;
    final double prec = _ratio(o.totalTp, o.totalTp + o.totalFp);
    final double rec = _ratio(o.totalTp, o.totalTp + o.totalFn);

    return PdfReportData(
      projectName: projectName,
      modelRunName: modelRunName,
      generatedAt: generatedAt,
      evalConfig: evalConfig,
      totalImages: o.totalImages,
      totalGt: o.totalGt,
      totalPredictions: o.totalPredictionsBeforeThreshold,
      predictionsAfterThreshold: o.totalPredictionsAfterThreshold,
      tp: o.totalTp,
      fp: o.totalFp,
      fn: o.totalFn,
      precision: prec,
      recall: rec,
      f1: _f1(prec, rec),
      microPrecision: o.microPrecision,
      microRecall: o.microRecall,
      microF1: o.microF1,
      macroPrecision: o.macroPrecision,
      macroRecall: o.macroRecall,
      macroF1: o.macroF1,
      imagesWithErrors: o.imagesWithAnyError,
      totalCategories: dataset.categoriesById.length,
      perClassStats: evalResult.perClassStats.values.toList(),
      matchRows: matchRows,
      missingImageFileNames: missingImageFileNames,
      healthReport: healthReport,
      worstCases: worstCases,
      confusionDetails: confusionDetails,
      comparison: comparison,
      multiComparison: multiComparison,
      recommendations: recommendations,
      apEvalResult: apEvalResult,
      locale: locale,
    );
  }

  // ─── document assembly ────────────────────────────────────────────────────

  Future<Uint8List> buildPdf(PdfReportData data, {pw.ThemeData? theme}) async {
    final doc = pw.Document(
      title: AppLocalizations.forLocale(data.locale).t(MessageKey.reportTitle),
      author: 'CV Model Lab',
      theme: theme,
    );

    doc.addPage(_titlePage(data));
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        header: (ctx) => _header(ctx, data),
        footer: _footer,
        build: (ctx) => _body(data),
      ),
    );

    return doc.save();
  }

  // ─── title page ───────────────────────────────────────────────────────────

  pw.Page _titlePage(PdfReportData data) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Spacer(),
          pw.Container(width: double.infinity, height: 4, color: _kPrimaryDark),
          pw.SizedBox(height: 24),
          pw.Text(
            AppLocalizations.forLocale(data.locale).t(MessageKey.reportTitle),
            style: pw.TextStyle(
              fontSize: 26,
              fontWeight: pw.FontWeight.bold,
              color: _kTableHeader,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            _clip(data.projectName, 80),
            style: pw.TextStyle(fontSize: 16, color: _kLabel),
          ),
          pw.Text(
            'Model: ${_clip(data.modelRunName, 80)}',
            style: pw.TextStyle(fontSize: 12, color: _kMuted),
          ),
          pw.SizedBox(height: 28),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: const pw.BoxDecoration(
              color: _kPrimaryLight,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _kv('Generated', _fmtDate(data.generatedAt)),
                _kv(
                  'IoU Threshold',
                  data.evalConfig.iouThreshold.toStringAsFixed(2),
                ),
                _kv(
                  'Confidence Threshold',
                  data.evalConfig.confidenceThreshold.toStringAsFixed(2),
                ),
                _kv(
                  'Class-aware Matching',
                  data.evalConfig.classAwareMatching ? 'Yes' : 'No',
                ),
                _kv('Ignore Crowd', data.evalConfig.ignoreCrowd ? 'Yes' : 'No'),
              ],
            ),
          ),
          pw.Spacer(flex: 2),
          pw.Text(
            'Generated by CV Model Lab',
            style: const pw.TextStyle(fontSize: 9, color: _kMuted),
          ),
        ],
      ),
    );
  }

  // ─── page header / footer ─────────────────────────────────────────────────

  pw.Widget _header(pw.Context ctx, PdfReportData data) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              _clip(data.projectName, 50),
              style: const pw.TextStyle(fontSize: 8, color: _kMuted),
            ),
            pw.Text(
              _clip(data.modelRunName, 50),
              style: const pw.TextStyle(fontSize: 8, color: _kMuted),
            ),
          ],
        ),
        pw.Divider(height: 4, thickness: 0.5, color: _kBorder),
        pw.SizedBox(height: 4),
      ],
    );
  }

  pw.Widget _footer(pw.Context ctx) {
    return pw.Column(
      children: [
        pw.Divider(height: 4, thickness: 0.5, color: _kBorder),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'CV Model Lab',
              style: const pw.TextStyle(fontSize: 8, color: _kMuted),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _kMuted),
            ),
          ],
        ),
      ],
    );
  }

  // ─── body sections ────────────────────────────────────────────────────────

  List<pw.Widget> _body(PdfReportData data) {
    return [
      ..._execSummary(data),
      ..._datasetSummary(data),
      ..._overallMetrics(data),
      if (data.apEvalResult != null) ..._apMetrics(data.apEvalResult!, data),
      ..._perClassMetrics(data),
      if (data.healthReport != null) ..._health(data.healthReport!, data),
      if (data.worstCases != null) ..._worstCases(data.worstCases!, data),
      if (data.confusionDetails != null)
        ..._confusion(data.confusionDetails!, data),
      if (data.multiComparison != null)
        ..._multiComparison(data.multiComparison!, data)
      else if (data.comparison != null)
        ..._comparison(data.comparison!, data),
      if (data.recommendations.isNotEmpty)
        ..._recommendations(data.recommendations, data),
      ..._appendix(data),
    ];
  }

  // ─── executive summary ────────────────────────────────────────────────────

  List<pw.Widget> _execSummary(PdfReportData data) {
    final AppLocalizations l = AppLocalizations.forLocale(data.locale);
    final health = data.healthReport;
    final critRecs = data.recommendations
        .where((r) => r.severity == RecommendationSeverity.critical)
        .length;
    final warnRecs = data.recommendations
        .where((r) => r.severity == RecommendationSeverity.warning)
        .length;

    return [
      _sectionTitle(l.t(MessageKey.reportExecutiveSummary)),
      _grid([
        _card('Images', '${data.totalImages}'),
        _card('Ground Truth', '${data.totalGt}'),
        _card('Predictions', '${data.predictionsAfterThreshold}'),
        _card('Images w/ Errors', '${data.imagesWithErrors}'),
      ]),
      pw.SizedBox(height: 4),
      _grid([
        _card('TP', '${data.tp}'),
        _card('FP', '${data.fp}'),
        _card('FN', '${data.fn}'),
        _card('F1', _pct(data.f1)),
      ]),
      pw.SizedBox(height: 4),
      _grid([
        _card('Precision', _pct(data.precision)),
        _card('Recall', _pct(data.recall)),
        if (health != null) ...[
          _card('Health Errors', '${health.errorCount}'),
          _card('Health Warnings', '${health.warningCount}'),
        ] else ...[
          _card('Categories', '${data.totalCategories}'),
          _card('Missing Files', '${data.missingImageFileNames.length}'),
        ],
      ]),
      if (data.recommendations.isNotEmpty) ...[
        pw.SizedBox(height: 4),
        _grid([
          _card('Critical Recs', '$critRecs'),
          _card('Warning Recs', '$warnRecs'),
          _card('Total Recs', '${data.recommendations.length}'),
          _card('Categories', '${data.totalCategories}'),
        ]),
      ],
      pw.SizedBox(height: 14),
    ];
  }

  // ─── dataset summary ──────────────────────────────────────────────────────

  List<pw.Widget> _datasetSummary(PdfReportData data) {
    final AppLocalizations l = AppLocalizations.forLocale(data.locale);
    return [
      _sectionTitle(l.t(MessageKey.reportDatasetSummary)),
      _table(
        headers: const ['Metric', 'Value'],
        rows: [
          ['Images', '${data.totalImages}'],
          ['Annotations (GT)', '${data.totalGt}'],
          ['Categories', '${data.totalCategories}'],
          ['Predictions (before threshold)', '${data.totalPredictions}'],
          [
            'Predictions (after threshold)',
            '${data.predictionsAfterThreshold}',
          ],
          ['Missing image files', '${data.missingImageFileNames.length}'],
        ],
        colWidths: const {0: pw.FlexColumnWidth(2.5), 1: pw.FlexColumnWidth(1)},
      ),
      pw.SizedBox(height: 14),
    ];
  }

  // ─── overall metrics ──────────────────────────────────────────────────────

  List<pw.Widget> _overallMetrics(PdfReportData data) {
    final AppLocalizations l = AppLocalizations.forLocale(data.locale);
    return [
      _sectionTitle(l.t(MessageKey.reportOverallMetrics)),
      _table(
        headers: const ['Metric', 'Value'],
        rows: [
          ['TP', '${data.tp}'],
          ['FP', '${data.fp}'],
          ['FN', '${data.fn}'],
          ['Precision', _pct(data.precision)],
          ['Recall', _pct(data.recall)],
          ['F1', _pct(data.f1)],
          ['Micro Precision', _pct(data.microPrecision)],
          ['Micro Recall', _pct(data.microRecall)],
          ['Micro F1', _pct(data.microF1)],
          ['Macro Precision', _pct(data.macroPrecision)],
          ['Macro Recall', _pct(data.macroRecall)],
          ['Macro F1', _pct(data.macroF1)],
        ],
        colWidths: const {0: pw.FlexColumnWidth(2.5), 1: pw.FlexColumnWidth(1)},
      ),
      pw.SizedBox(height: 14),
    ];
  }

  // ─── COCO AP metrics ──────────────────────────────────────────────────────

  List<pw.Widget> _apMetrics(ApEvalResult result, PdfReportData data) {
    final AppLocalizations l = AppLocalizations.forLocale(data.locale);
    String _opt(double? v) => v == null ? '-' : _pct(v);
    final List<pw.Widget> widgets = [
      _sectionTitle(l.t(MessageKey.reportCocoApMetrics)),
      _table(
        headers: const ['Metric', 'Value'],
        rows: [
          ['AP@[.5:.95]', _opt(result.ap)],
          ['AP50', _opt(result.ap50)],
          ['AP75', _opt(result.ap75)],
          ['APsmall', _opt(result.apSmall)],
          ['APmedium', _opt(result.apMedium)],
          ['APlarge', _opt(result.apLarge)],
          ['AR1', _opt(result.ar1)],
          ['AR10', _opt(result.ar10)],
          ['AR100', _opt(result.ar100)],
          ['ARsmall', _opt(result.arSmall)],
          ['ARmedium', _opt(result.arMedium)],
          ['ARlarge', _opt(result.arLarge)],
        ],
        colWidths: const {0: pw.FlexColumnWidth(2.5), 1: pw.FlexColumnWidth(1)},
      ),
    ];
    if (result.perClass.isNotEmpty) {
      final top = result.perClass.take(20).toList();
      widgets
        ..add(pw.SizedBox(height: 8))
        ..add(_subTitle('Per-class AP (top ${top.length})'))
        ..add(pw.SizedBox(height: 4))
        ..add(
          _table(
            headers: const ['Class', 'AP', 'AP50', 'AP75', 'AR'],
            rows: [
              for (final ClassApMetric cls in top)
                [
                  _clip(cls.categoryName, 32),
                  _opt(cls.ap),
                  _opt(cls.ap50),
                  _opt(cls.ap75),
                  _opt(cls.ar),
                ],
            ],
            colWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1),
            },
          ),
        );
    }
    widgets.add(pw.SizedBox(height: 14));
    return widgets;
  }

  // ─── per-class metrics ────────────────────────────────────────────────────

  List<pw.Widget> _perClassMetrics(PdfReportData data) {
    final AppLocalizations l = AppLocalizations.forLocale(data.locale);
    const headers = [
      'Class',
      'GT',
      'Pred',
      'TP',
      'FP',
      'FN',
      'Precision',
      'Recall',
      'F1',
    ];
    const colWidths = {
      0: pw.FlexColumnWidth(2.5),
      1: pw.FlexColumnWidth(0.6),
      2: pw.FlexColumnWidth(0.6),
      3: pw.FlexColumnWidth(0.6),
      4: pw.FlexColumnWidth(0.6),
      5: pw.FlexColumnWidth(0.6),
      6: pw.FlexColumnWidth(1),
      7: pw.FlexColumnWidth(1),
      8: pw.FlexColumnWidth(1),
    };

    List<List<String>> classRows(List<ClassStats> stats) => [
          for (final s in stats)
            [
              _clip(s.categoryName, 32),
              '${s.gtCount}',
              '${s.predCount}',
              '${s.tp}',
              '${s.fp}',
              '${s.fn}',
              _pct(s.precision),
              _pct(s.recall),
              _pct(s.f1),
            ],
        ];

    final byRecall = (data.perClassStats.toList()
          ..sort((a, b) => a.recall.compareTo(b.recall)))
        .take(10)
        .toList();
    final byFp = (data.perClassStats.toList()
          ..sort((a, b) => b.fp.compareTo(a.fp)))
        .take(10)
        .toList();
    final byFn = (data.perClassStats.toList()
          ..sort((a, b) => b.fn.compareTo(a.fn)))
        .take(10)
        .toList();

    return [
      _sectionTitle(l.t(MessageKey.reportPerClassMetrics)),
      _subTitle('Top 10 weakest classes by Recall'),
      pw.SizedBox(height: 4),
      byRecall.isEmpty
          ? _empty()
          : _table(
              headers: headers,
              rows: classRows(byRecall),
              colWidths: colWidths,
            ),
      pw.SizedBox(height: 10),
      _subTitle('Top 10 classes by FP count'),
      pw.SizedBox(height: 4),
      byFp.isEmpty
          ? _empty()
          : _table(
              headers: headers,
              rows: classRows(byFp),
              colWidths: colWidths,
            ),
      pw.SizedBox(height: 10),
      _subTitle('Top 10 classes by FN count'),
      pw.SizedBox(height: 4),
      byFn.isEmpty
          ? _empty()
          : _table(
              headers: headers,
              rows: classRows(byFn),
              colWidths: colWidths,
            ),
      pw.SizedBox(height: 14),
    ];
  }

  // ─── dataset health ───────────────────────────────────────────────────────

  List<pw.Widget> _health(DatasetHealthReport report, PdfReportData data) {
    final AppLocalizations l10n = AppLocalizations.forLocale(data.locale);
    final topIssues = report.issues.take(20).toList();
    return [
      _sectionTitle(l10n.t(MessageKey.reportDatasetHealth)),
      _grid([
        _card('Errors', '${report.errorCount}'),
        _card('Warnings', '${report.warningCount}'),
        _card('Info', '${report.infoCount}'),
        _card('Missing Images', '${report.missingImageCount}'),
      ]),
      pw.SizedBox(height: 8),
      if (topIssues.isNotEmpty) ...[
        _subTitle('Top ${topIssues.length} issues'),
        pw.SizedBox(height: 4),
        _table(
          headers: const ['Severity', 'Type', 'File', 'Message'],
          rows: [
            for (final i in topIssues)
              [
                l10n.severity(i.severity),
                i.type.name,
                _clip(i.fileName ?? '', 28),
                _clip(l10n.datasetIssueMessage(i), 60),
              ],
          ],
          colWidths: const {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(4),
          },
        ),
      ],
      pw.SizedBox(height: 14),
    ];
  }

  // ─── worst cases ──────────────────────────────────────────────────────────

  List<pw.Widget> _worstCases(WorstCasesResult wc, PdfReportData data) {
    final AppLocalizations l = AppLocalizations.forLocale(data.locale);
    final sections = [
      (label: 'Most Errors', items: wc.mostErrors),
      (label: 'High Confidence FP', items: wc.highConfidenceFalsePositives),
      (label: 'Most False Negatives', items: wc.mostFalseNegatives),
      (label: 'Class Confusion', items: wc.classConfusions),
      (label: 'Small Missed Objects', items: wc.smallMissedObjects),
    ];

    final widgets = <pw.Widget>[
      _sectionTitle(l.t(MessageKey.reportWorstCases)),
    ];

    const worstColWidths = {
      0: pw.FlexColumnWidth(3),
      1: pw.FlexColumnWidth(3),
      2: pw.FlexColumnWidth(0.6),
      3: pw.FlexColumnWidth(0.6),
      4: pw.FlexColumnWidth(0.6),
      5: pw.FlexColumnWidth(1),
      6: pw.FlexColumnWidth(1),
    };

    for (final s in sections) {
      final top10 = s.items.take(10).toList();
      if (top10.isEmpty) continue;
      widgets
        ..add(_subTitle(s.label))
        ..add(pw.SizedBox(height: 4))
        ..add(
          _table(
            headers: const ['File', 'Reason', 'TP', 'FP', 'FN', 'Score', 'IoU'],
            rows: [
              for (final item in top10)
                [
                  _clip(item.fileName, 38),
                  _clip(item.reason, 38),
                  '${item.tp}',
                  '${item.fp}',
                  '${item.fn}',
                  item.score != null ? _f3(item.score!) : '',
                  item.iou != null ? _f3(item.iou!) : '',
                ],
            ],
            colWidths: worstColWidths,
          ),
        )
        ..add(pw.SizedBox(height: 10));
    }
    widgets.add(pw.SizedBox(height: 14));
    return widgets;
  }

  // ─── confusion matrix ─────────────────────────────────────────────────────

  List<pw.Widget> _confusion(
    ConfusionMatrixDetails details,
    PdfReportData data,
  ) {
    final AppLocalizations l = AppLocalizations.forLocale(data.locale);
    final pairs = details.pairs(includeDiagonal: false).take(30).toList();
    return [
      _sectionTitle(l.t(MessageKey.reportConfusionMatrix)),
      if (pairs.isEmpty)
        _empty()
      else ...[
        _subTitle('Top confused pairs (error cells only)'),
        pw.SizedBox(height: 4),
        _table(
          headers: const ['GT Class', 'Pred Class', 'Count', 'Row %'],
          rows: [
            for (final p in pairs)
              [
                _clip(p.gtClass, 30),
                _clip(p.predClass, 30),
                '${p.count}',
                _pct(p.rowPercent),
              ],
          ],
          colWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(1),
          },
        ),
      ],
      pw.SizedBox(height: 14),
    ];
  }

  // ─── model comparison ─────────────────────────────────────────────────────

  List<pw.Widget> _comparison(ModelComparisonResult cmp, PdfReportData data) {
    final AppLocalizations l = AppLocalizations.forLocale(data.locale);
    final d = cmp.overallDiff;
    final top10Reg = (cmp.perClassDiffs.toList()
          ..sort((a, b) => a.diff.deltaF1.compareTo(b.diff.deltaF1)))
        .take(10)
        .toList();

    return [
      _sectionTitle(l.t(MessageKey.reportModelComparison)),
      _grid([
        _card('Fixed Images', '${cmp.fixedImageIds.length}'),
        _card('Broken Images', '${cmp.brokenImageIds.length}'),
        _card('Improved', '${cmp.improvedImageIds.length}'),
        _card('Regressed', '${cmp.regressedImageIds.length}'),
      ]),
      pw.SizedBox(height: 8),
      _subTitle('Overall diff'),
      pw.SizedBox(height: 4),
      _table(
        headers: const ['Metric', 'Base', 'Candidate', 'Delta'],
        rows: [
          [
            'Precision',
            _pct(d.basePrecision),
            _pct(d.candidatePrecision),
            _sPct(d.deltaPrecision),
          ],
          [
            'Recall',
            _pct(d.baseRecall),
            _pct(d.candidateRecall),
            _sPct(d.deltaRecall),
          ],
          ['F1', _pct(d.baseF1), _pct(d.candidateF1), _sPct(d.deltaF1)],
          ['TP', '${d.baseTp}', '${d.candidateTp}', _sInt(d.deltaTp)],
          ['FP', '${d.baseFp}', '${d.candidateFp}', _sInt(d.deltaFp)],
          ['FN', '${d.baseFn}', '${d.candidateFn}', _sInt(d.deltaFn)],
          [
            'Images w/ Errors',
            '${d.baseImagesWithErrors}',
            '${d.candidateImagesWithErrors}',
            _sInt(d.deltaImagesWithErrors),
          ],
        ],
        colWidths: const {
          0: pw.FlexColumnWidth(2),
          1: pw.FlexColumnWidth(1),
          2: pw.FlexColumnWidth(1),
          3: pw.FlexColumnWidth(1),
        },
      ),
      if (top10Reg.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        _subTitle('Top 10 per-class regressions (worst dF1)'),
        pw.SizedBox(height: 4),
        _table(
          headers: const [
            'Class',
            'dF1',
            'dRecall',
            'dPrecision',
            'dFP',
            'dFN',
          ],
          rows: [
            for (final item in top10Reg)
              [
                _clip(item.categoryName, 30),
                _sPct(item.diff.deltaF1),
                _sPct(item.diff.deltaRecall),
                _sPct(item.diff.deltaPrecision),
                _sInt(item.diff.deltaFp),
                _sInt(item.diff.deltaFn),
              ],
          ],
          colWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(1),
            4: pw.FlexColumnWidth(1),
            5: pw.FlexColumnWidth(1),
          },
        ),
      ],
      pw.SizedBox(height: 14),
    ];
  }

  // ─── multi-model comparison ───────────────────────────────────────────────

  List<pw.Widget> _multiComparison(
    MultiModelComparisonResult result,
    PdfReportData data,
  ) {
    final AppLocalizations l = AppLocalizations.forLocale(data.locale);
    final bool hasAp = result.leaderboard.any((e) => e.ap != null);
    return [
      _sectionTitle(l.t(MessageKey.reportModelComparison)),
      _subTitle(l.t(MessageKey.mmLeaderboard)),
      pw.SizedBox(height: 4),
      _table(
        headers: [
          '#',
          'Model',
          'P',
          'R',
          'F1',
          'TP',
          'FP',
          'FN',
          if (hasAp) 'AP',
          if (hasAp) 'AP50',
        ],
        rows: [
          for (final e in result.leaderboard)
            [
              '${e.rank}',
              _clip(e.modelRunName, 28),
              _pct(e.precision),
              _pct(e.recall),
              _pct(e.f1),
              '${e.totalTp}',
              '${e.totalFp}',
              '${e.totalFn}',
              if (hasAp) (e.ap != null ? _pct(e.ap!) : '—'),
              if (hasAp) (e.ap50 != null ? _pct(e.ap50!) : '—'),
            ],
        ],
        colWidths: {
          0: const pw.FlexColumnWidth(0.5),
          1: const pw.FlexColumnWidth(3),
          2: const pw.FlexColumnWidth(1),
          3: const pw.FlexColumnWidth(1),
          4: const pw.FlexColumnWidth(1),
          5: const pw.FlexColumnWidth(1),
          6: const pw.FlexColumnWidth(1),
          7: const pw.FlexColumnWidth(1),
          if (hasAp) 8: const pw.FlexColumnWidth(1),
          if (hasAp) 9: const pw.FlexColumnWidth(1),
        },
      ),
      if (result.perClassRankings.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        _subTitle(l.t(MessageKey.mmPerClassRanking)),
        pw.SizedBox(height: 4),
        _table(
          headers: const ['Class', 'Best model', 'Worst model', 'F1 spread'],
          rows: [
            for (final r in result.perClassRankings.toList()
              ..sort(
                (a, b) => (b.f1Spread).compareTo(a.f1Spread),
              ))
              [
                _clip(r.categoryName, 30),
                _clip(_runNameInLeaderboard(result, r.bestModelRunId), 24),
                _clip(_runNameInLeaderboard(result, r.worstModelRunId), 24),
                _pct(r.f1Spread),
              ],
          ],
          colWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(1),
          },
        ),
      ],
      pw.SizedBox(height: 14),
    ];
  }

  String _runNameInLeaderboard(MultiModelComparisonResult result, String? id) {
    if (id == null) return '—';
    return result.leaderboard
            .where((e) => e.modelRunId == id)
            .map((e) => e.modelRunName)
            .firstOrNull ??
        id;
  }

  // ─── recommendations ──────────────────────────────────────────────────────

  List<pw.Widget> _recommendations(
    List<Recommendation> recs,
    PdfReportData data,
  ) {
    final AppLocalizations l10n = AppLocalizations.forLocale(data.locale);
    final bySev = <RecommendationSeverity, List<Recommendation>>{
      for (final s in RecommendationSeverity.values) s: [],
    };
    for (final r in recs) {
      bySev[r.severity]!.add(r);
    }

    const recColWidths = {
      0: pw.FlexColumnWidth(2),
      1: pw.FlexColumnWidth(3),
      2: pw.FlexColumnWidth(3),
    };

    final widgets = <pw.Widget>[
      _sectionTitle(l10n.t(MessageKey.reportRecommendations)),
    ];

    void addGroup(String label, RecommendationSeverity sev) {
      final group = bySev[sev]!;
      if (group.isEmpty) return;
      widgets
        ..add(_subTitle('$label (${group.length})'))
        ..add(pw.SizedBox(height: 4))
        ..add(
          _table(
            headers: const ['Title', 'Message', 'Action'],
            rows: [
              for (final r in group)
                [
                  _clip(l10n.recommendationTitle(r), 40),
                  _clip(l10n.recommendationMessage(r), 70),
                  _clip(l10n.recommendationAction(r), 70),
                ],
            ],
            colWidths: recColWidths,
          ),
        )
        ..add(pw.SizedBox(height: 10));
    }

    addGroup('Critical', RecommendationSeverity.critical);
    addGroup('Warnings', RecommendationSeverity.warning);
    addGroup('Info', RecommendationSeverity.info);
    widgets.add(pw.SizedBox(height: 14));
    return widgets;
  }

  // ─── appendix ─────────────────────────────────────────────────────────────

  List<pw.Widget> _appendix(PdfReportData data) {
    final AppLocalizations l = AppLocalizations.forLocale(data.locale);
    final rows = data.matchRows
        .where((r) => r.matchType == 'FP' || r.matchType == 'FN')
        .take(50)
        .toList();

    if (rows.isEmpty) return const [];

    return [
      _sectionTitle(l.t(MessageKey.reportAppendix)),
      _table(
        headers: const ['File', 'Category', 'Type', 'Score', 'IoU'],
        rows: [
          for (final r in rows)
            [
              _clip(r.fileName, 40),
              _clip(r.categoryName, 28),
              r.matchType,
              r.score != null ? _f3(r.score!) : '',
              r.iou != null ? _f3(r.iou!) : '',
            ],
        ],
        colWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(2),
          2: pw.FlexColumnWidth(0.8),
          3: pw.FlexColumnWidth(1),
          4: pw.FlexColumnWidth(1),
        },
      ),
    ];
  }

  // ─── widget helpers ───────────────────────────────────────────────────────

  pw.Widget _sectionTitle(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: _kTableHeader,
          ),
        ),
        pw.Container(
          height: 1,
          margin: const pw.EdgeInsets.only(top: 2, bottom: 8),
          color: _kPrimary,
        ),
      ],
    );
  }

  pw.Widget _subTitle(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: _kDark,
      ),
    );
  }

  pw.Widget _empty() {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        'No data available.',
        style: const pw.TextStyle(fontSize: 9, color: _kMuted),
      ),
    );
  }

  pw.Widget _grid(List<pw.Widget> cards) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            pw.Expanded(child: cards[i]),
            if (i < cards.length - 1) pw.SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  pw.Widget _card(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const pw.BoxDecoration(
        color: _kPrimaryLight,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 7, color: _kLabel),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _kTableHeader,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    Map<int, pw.TableColumnWidth>? colWidths,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      columnWidths: colWidths,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kTableHeader),
          children: [
            for (final h in headers)
              pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: pw.Text(
                  h,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? _kRowAlt : PdfColors.white,
            ),
            children: [
              for (final cell in rows[i])
                pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: pw.Text(cell, style: const pw.TextStyle(fontSize: 8)),
                ),
            ],
          ),
      ],
    );
  }

  pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  // ─── formatting helpers ───────────────────────────────────────────────────

  String _clip(String? text, int maxLen) {
    if (text == null || text.isEmpty) return '';
    if (text.length > maxLen) return '${text.substring(0, maxLen - 3)}...';
    return text;
  }

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
  String _f3(double v) => v.toStringAsFixed(3);
  String _sPct(double v) => v >= 0
      ? '+${(v * 100).toStringAsFixed(1)}%'
      : '${(v * 100).toStringAsFixed(1)}%';
  String _sInt(int v) => v >= 0 ? '+$v' : '$v';

  String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  double _ratio(int num, int den) => den == 0 ? 0.0 : num / den;
  double _f1(double p, double r) => p + r == 0 ? 0.0 : 2 * p * r / (p + r);
}
