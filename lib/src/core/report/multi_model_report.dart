import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../comparison/multi_model_comparison_models.dart';
import '../i18n/message_key.dart';
import 'csv_exporter.dart';
import 'xlsx_report_builder.dart';
import 'xlsx_report_data.dart';
import '../../ui/l10n/app_localizations.dart';

/// Canonical file names for a multi-model comparison export.
class MultiModelReportFileNames {
  static const String html = 'multi_model_comparison.html';
  static const String leaderboard = 'multi_model_leaderboard.csv';
  static const String perClass = 'multi_model_per_class.csv';
  static const String imageDisagreements = 'multi_model_image_disagreements.csv';
  static const String regressionMatrix = 'multi_model_regression_matrix.csv';
  static const String xlsx = 'multi_model_comparison.xlsx';
  static const String pdf = 'multi_model_comparison.pdf';
}

/// An in-memory, platform-agnostic multi-model export.
class MultiModelReportBundle {
  const MultiModelReportBundle({
    required this.htmlReport,
    required this.csvFiles,
    required this.binaryFiles,
  });

  final String htmlReport;
  final Map<String, String> csvFiles;
  final Map<String, List<int>> binaryFiles;

  List<String> get fileNames => [
        if (htmlReport.isNotEmpty) MultiModelReportFileNames.html,
        ...csvFiles.keys,
        ...binaryFiles.keys,
      ];
}

/// Formats a [MultiModelComparisonResult] into HTML, CSV, XLSX and PDF.
///
/// This builder only formats already-computed data; it never recomputes any
/// metrics. CSV headers stay English for machine readability; HTML and PDF
/// headings are localized via [AppLocalizations].
class MultiModelReportBuilder {
  const MultiModelReportBuilder({
    this.csvExporter = const CsvExporter(),
    this.xlsxBuilder = const XlsxReportBuilder(),
  });

  final CsvExporter csvExporter;
  final XlsxReportBuilder xlsxBuilder;

  static const int _topRows = 20;

  Future<MultiModelReportBundle> build({
    required MultiModelComparisonResult result,
    required String projectName,
    AppLocale locale = AppLocale.en,
    bool includeHtml = true,
    bool includeCsv = true,
    bool includeXlsx = true,
    bool includePdf = true,
    DateTime? generatedAt,
  }) async {
    final AppLocalizations l = AppLocalizations.forLocale(locale);
    final DateTime timestamp = generatedAt ?? result.generatedAt;

    final Map<String, String> csvFiles = {};
    if (includeCsv) {
      csvFiles[MultiModelReportFileNames.leaderboard] = leaderboardCsv(result);
      csvFiles[MultiModelReportFileNames.perClass] = perClassCsv(result);
      csvFiles[MultiModelReportFileNames.imageDisagreements] =
          imageDisagreementsCsv(result);
      csvFiles[MultiModelReportFileNames.regressionMatrix] =
          regressionMatrixCsv(result);
    }

    final Map<String, List<int>> binaryFiles = {};
    if (includeXlsx) {
      binaryFiles[MultiModelReportFileNames.xlsx] =
          xlsxBuilder.buildWorkbook(buildXlsxData(result));
    }
    if (includePdf) {
      binaryFiles[MultiModelReportFileNames.pdf] = await buildPdf(
        result: result,
        projectName: projectName,
        l: l,
        generatedAt: timestamp,
      );
    }

    return MultiModelReportBundle(
      htmlReport: includeHtml
          ? buildHtml(
              result: result,
              projectName: projectName,
              l: l,
              generatedAt: timestamp,
            )
          : '',
      csvFiles: csvFiles,
      binaryFiles: binaryFiles,
    );
  }

  // ── CSV ─────────────────────────────────────────────────────────────────

  String leaderboardCsv(MultiModelComparisonResult result) =>
      _csv(leaderboardRows(result));

  String perClassCsv(MultiModelComparisonResult result) =>
      _csv(perClassRows(result));

  String imageDisagreementsCsv(MultiModelComparisonResult result) =>
      _csv(imageDisagreementRows(result));

  String regressionMatrixCsv(MultiModelComparisonResult result) =>
      _csv(regressionMatrixRows(result));

  List<List<Object?>> leaderboardRows(MultiModelComparisonResult result) {
    final List<List<Object?>> rows = [
      const [
        'rank',
        'model_run_id',
        'model_run_name',
        'ap',
        'ap50',
        'ap75',
        'ap_small',
        'ap_medium',
        'ap_large',
        'precision',
        'recall',
        'f1',
        'tp',
        'fp',
        'fn',
        'images_with_errors',
        'small_recall',
        'medium_recall',
        'large_recall',
        'score',
      ],
    ];
    for (final ModelRunLeaderboardEntry e in result.leaderboard) {
      rows.add([
        e.rank,
        e.modelRunId,
        e.modelRunName,
        e.ap,
        e.ap50,
        e.ap75,
        e.apSmall,
        e.apMedium,
        e.apLarge,
        e.precision,
        e.recall,
        e.f1,
        e.totalTp,
        e.totalFp,
        e.totalFn,
        e.imagesWithErrors,
        e.smallObjectRecall,
        e.mediumObjectRecall,
        e.largeObjectRecall,
        e.score,
      ]);
    }
    return rows;
  }

  List<List<Object?>> perClassRows(MultiModelComparisonResult result) {
    final List<List<Object?>> rows = [
      const [
        'category_id',
        'category_name',
        'model_run_id',
        'model_run_name',
        'gt_count',
        'pred_count',
        'tp',
        'fp',
        'fn',
        'precision',
        'recall',
        'f1',
        'ap',
        'ap50',
        'ap75',
        'ar',
        'f1_spread',
        'best_model_run_id',
        'worst_model_run_id',
      ],
    ];
    for (final ClassModelRanking r in result.perClassRankings) {
      for (final ClassModelMetricEntry e in r.entries) {
        rows.add([
          r.categoryId,
          r.categoryName,
          e.modelRunId,
          e.modelRunName,
          e.gtCount,
          e.predCount,
          e.tp,
          e.fp,
          e.fn,
          e.precision,
          e.recall,
          e.f1,
          e.ap,
          e.ap50,
          e.ap75,
          e.ar,
          r.f1Spread,
          r.bestModelRunId,
          r.worstModelRunId,
        ]);
      }
    }
    return rows;
  }

  List<List<Object?>> imageDisagreementRows(
    MultiModelComparisonResult result,
  ) {
    final List<List<Object?>> rows = [
      const [
        'image_id',
        'file_name',
        'type',
        'correct_models',
        'wrong_models',
        'best_error_count',
        'worst_error_count',
        'error_spread',
        'per_model_status',
      ],
    ];
    for (final ImageModelDisagreement d in result.imageDisagreements) {
      final String perModel = d.modelStatuses
          .map((s) => '${s.modelRunName}: ${s.tp}/${s.fp}/${s.fn}')
          .join(' | ');
      rows.add([
        d.imageId,
        d.fileName,
        d.type.name,
        d.modelsCorrectCount,
        d.modelsWrongCount,
        d.bestErrorCount,
        d.worstErrorCount,
        d.errorSpread,
        perModel,
      ]);
    }
    return rows;
  }

  List<List<Object?>> regressionMatrixRows(
    MultiModelComparisonResult result,
  ) {
    final List<List<Object?>> rows = [
      const [
        'base_model_run_id',
        'candidate_model_run_id',
        'fixed_images',
        'broken_images',
        'improved_images',
        'regressed_images',
        'delta_tp',
        'delta_fp',
        'delta_fn',
        'delta_precision',
        'delta_recall',
        'delta_f1',
        'delta_ap',
      ],
    ];
    for (final PairwiseRegressionSummary p in result.pairwiseRegressionMatrix) {
      rows.add([
        p.baseModelRunId,
        p.candidateModelRunId,
        p.fixedImages,
        p.brokenImages,
        p.improvedImages,
        p.regressedImages,
        p.deltaTp,
        p.deltaFp,
        p.deltaFn,
        p.deltaPrecision,
        p.deltaRecall,
        p.deltaF1,
        p.deltaAp,
      ]);
    }
    return rows;
  }

  String _csv(List<List<Object?>> rows) {
    final StringBuffer buffer = StringBuffer();
    for (final List<Object?> row in rows) {
      buffer.writeln(row.map(csvEscape).join(','));
    }
    return buffer.toString();
  }

  // ── XLSX ────────────────────────────────────────────────────────────────

  XlsxWorkbookData buildXlsxData(MultiModelComparisonResult result) {
    return XlsxWorkbookData(
      sheets: [
        XlsxSheetData(
          name: 'Multi Leaderboard',
          rows: leaderboardRows(result),
        ),
        XlsxSheetData(
          name: 'Multi Per-Class',
          rows: perClassRows(result),
        ),
        XlsxSheetData(
          name: 'Multi Disagreement',
          rows: imageDisagreementRows(result),
        ),
        XlsxSheetData(
          name: 'Regression Matrix',
          rows: regressionMatrixRows(result),
        ),
      ],
    );
  }

  // ── HTML ────────────────────────────────────────────────────────────────

  String buildHtml({
    required MultiModelComparisonResult result,
    required String projectName,
    required AppLocalizations l,
    required DateTime generatedAt,
  }) {
    final StringBuffer h = StringBuffer();
    h.writeln('<!DOCTYPE html>');
    h.writeln('<html lang="${l.locale == AppLocale.ru ? 'ru' : 'en'}">');
    h.writeln('<head><meta charset="utf-8">');
    h.writeln('<title>${_esc(l.t(MessageKey.mmMultiModelComparison))}</title>');
    h.writeln('<style>$_htmlCss</style></head><body>');
    h.writeln('<h1>${_esc(l.t(MessageKey.mmMultiModelComparison))}</h1>');
    h.writeln('<p class="muted">${_esc(projectName)} — '
        '${generatedAt.toIso8601String()}</p>');

    // Leaderboard.
    h.writeln('<h2>${_esc(l.t(MessageKey.mmLeaderboard))}</h2>');
    h.writeln('<table><thead><tr>'
        '<th>${_esc(l.t(MessageKey.mmRank))}</th>'
        '<th>${_esc(l.t(MessageKey.mmModel))}</th>'
        '<th>AP</th><th>AP50</th>'
        '<th>P</th><th>R</th><th>F1</th>'
        '<th>TP</th><th>FP</th><th>FN</th>'
        '<th>${_esc(l.t(MessageKey.mmImagesWithErrors))}</th>'
        '<th>${_esc(l.t(MessageKey.mmSmallRecall))}</th>'
        '</tr></thead><tbody>');
    for (final ModelRunLeaderboardEntry e in result.leaderboard) {
      h.writeln('<tr>'
          '<td>${e.rank}</td>'
          '<td>${_esc(e.modelRunName)}</td>'
          '<td>${_ap(e.ap)}</td><td>${_ap(e.ap50)}</td>'
          '<td>${_f(e.precision)}</td><td>${_f(e.recall)}</td>'
          '<td>${_f(e.f1)}</td>'
          '<td>${e.totalTp}</td><td>${e.totalFp}</td><td>${e.totalFn}</td>'
          '<td>${e.imagesWithErrors}</td>'
          '<td>${_ap(e.smallObjectRecall)}</td>'
          '</tr>');
    }
    h.writeln('</tbody></table>');

    // Top per-class spreads.
    if (result.perClassRankings.isNotEmpty) {
      h.writeln('<h2>${_esc(l.t(MessageKey.mmPerClassRanking))}</h2>');
      h.writeln('<table><thead><tr>'
          '<th>${_esc(l.t(MessageKey.mmClassFilter))}</th>'
          '<th>${_esc(l.t(MessageKey.mmBestModel))}</th>'
          '<th>${_esc(l.t(MessageKey.mmWorstModel))}</th>'
          '<th>${_esc(l.t(MessageKey.mmF1Spread))}</th>'
          '</tr></thead><tbody>');
      for (final ClassModelRanking r
          in result.perClassRankings.take(_topRows)) {
        h.writeln('<tr>'
            '<td>${_esc(r.categoryName)}</td>'
            '<td>${_esc(_runName(result, r.bestModelRunId))}</td>'
            '<td>${_esc(_runName(result, r.worstModelRunId))}</td>'
            '<td>${_f(r.f1Spread)}</td>'
            '</tr>');
      }
      h.writeln('</tbody></table>');
    }

    // Top image disagreements (skip all-correct).
    final List<ImageModelDisagreement> topDisagreements = result
        .imageDisagreements
        .where((d) => d.type != ImageDisagreementType.allCorrect)
        .take(_topRows)
        .toList();
    if (topDisagreements.isNotEmpty) {
      h.writeln('<h2>${_esc(l.t(MessageKey.mmImageDisagreement))}</h2>');
      h.writeln('<table><thead><tr>'
          '<th>${_esc(l.t(MessageKey.mmImage))}</th>'
          '<th>${_esc(l.t(MessageKey.mmType))}</th>'
          '<th>${_esc(l.t(MessageKey.mmCorrectModels))}</th>'
          '<th>${_esc(l.t(MessageKey.mmWrongModels))}</th>'
          '<th>${_esc(l.t(MessageKey.mmErrorSpread))}</th>'
          '</tr></thead><tbody>');
      for (final ImageModelDisagreement d in topDisagreements) {
        h.writeln('<tr>'
            '<td>${_esc(d.fileName)}</td>'
            '<td>${_esc(l.multiModelDisagreementType(d.type))}</td>'
            '<td>${d.modelsCorrectCount}</td>'
            '<td>${d.modelsWrongCount}</td>'
            '<td>${d.errorSpread}</td>'
            '</tr>');
      }
      h.writeln('</tbody></table>');
    }

    // Regression matrix summary (ΔF1).
    if (result.pairwiseRegressionMatrix.isNotEmpty) {
      h.writeln('<h2>${_esc(l.t(MessageKey.mmRegressionMatrix))}</h2>');
      h.writeln('<table><thead><tr>'
          '<th>${_esc(l.t(MessageKey.mmModel))}</th>');
      final List<ModelRunLeaderboardEntry> models = result.leaderboard;
      for (final ModelRunLeaderboardEntry c in models) {
        h.writeln('<th>${_esc(c.modelRunName)}</th>');
      }
      h.writeln('</tr></thead><tbody>');
      final Map<String, PairwiseRegressionSummary> byPair = {
        for (final p in result.pairwiseRegressionMatrix)
          '${p.baseModelRunId}->${p.candidateModelRunId}': p,
      };
      for (final ModelRunLeaderboardEntry base in models) {
        h.writeln('<tr><th>${_esc(base.modelRunName)}</th>');
        for (final ModelRunLeaderboardEntry cand in models) {
          if (base.modelRunId == cand.modelRunId) {
            h.writeln('<td class="muted">—</td>');
          } else {
            final p = byPair['${base.modelRunId}->${cand.modelRunId}'];
            h.writeln('<td>${p == null ? '' : _signedF(p.deltaF1)}</td>');
          }
        }
        h.writeln('</tr>');
      }
      h.writeln('</tbody></table>');
    }

    h.writeln('</body></html>');
    return h.toString();
  }

  // ── PDF ─────────────────────────────────────────────────────────────────

  Future<Uint8List> buildPdf({
    required MultiModelComparisonResult result,
    required String projectName,
    required AppLocalizations l,
    required DateTime generatedAt,
  }) async {
    final pw.Document doc = pw.Document();
    final List<pw.Widget> content = [];

    content.add(
      pw.Header(
        level: 0,
        text: l.t(MessageKey.mmMultiModelComparison),
      ),
    );
    content.add(pw.Text('$projectName — ${generatedAt.toIso8601String()}'));
    content.add(pw.SizedBox(height: 12));

    // Leaderboard.
    content.add(pw.Header(level: 1, text: l.t(MessageKey.mmLeaderboard)));
    content.add(
      pw.TableHelper.fromTextArray(
        headers: [
          l.t(MessageKey.mmRank),
          l.t(MessageKey.mmModel),
          'AP',
          'P',
          'R',
          'F1',
          'TP',
          'FP',
          'FN',
        ],
        data: [
          for (final ModelRunLeaderboardEntry e in result.leaderboard)
            [
              '${e.rank}',
              e.modelRunName,
              _ap(e.ap),
              _f(e.precision),
              _f(e.recall),
              _f(e.f1),
              '${e.totalTp}',
              '${e.totalFp}',
              '${e.totalFn}',
            ],
        ],
      ),
    );

    // Top per-class differences.
    if (result.perClassRankings.isNotEmpty) {
      content.add(pw.SizedBox(height: 12));
      content.add(
        pw.Header(level: 1, text: l.t(MessageKey.mmPerClassRanking)),
      );
      content.add(
        pw.TableHelper.fromTextArray(
          headers: [
            l.t(MessageKey.mmClassFilter),
            l.t(MessageKey.mmBestModel),
            l.t(MessageKey.mmWorstModel),
            l.t(MessageKey.mmF1Spread),
          ],
          data: [
            for (final ClassModelRanking r
                in result.perClassRankings.take(10))
              [
                r.categoryName,
                _runName(result, r.bestModelRunId),
                _runName(result, r.worstModelRunId),
                _f(r.f1Spread),
              ],
          ],
        ),
      );
    }

    // Top image disagreements.
    final List<ImageModelDisagreement> topDisagreements = result
        .imageDisagreements
        .where((d) => d.type != ImageDisagreementType.allCorrect)
        .take(10)
        .toList();
    if (topDisagreements.isNotEmpty) {
      content.add(pw.SizedBox(height: 12));
      content.add(
        pw.Header(level: 1, text: l.t(MessageKey.mmImageDisagreement)),
      );
      content.add(
        pw.TableHelper.fromTextArray(
          headers: [
            l.t(MessageKey.mmImage),
            l.t(MessageKey.mmType),
            l.t(MessageKey.mmErrorSpread),
          ],
          data: [
            for (final ImageModelDisagreement d in topDisagreements)
              [
                d.fileName,
                l.multiModelDisagreementType(d.type),
                '${d.errorSpread}',
              ],
          ],
        ),
      );
    }

    // Regression summary.
    if (result.pairwiseRegressionMatrix.isNotEmpty) {
      content.add(pw.SizedBox(height: 12));
      content.add(
        pw.Header(level: 1, text: l.t(MessageKey.mmRegressionMatrix)),
      );
      content.add(
        pw.TableHelper.fromTextArray(
          headers: ['Base', 'Candidate', 'dF1', 'Fixed', 'Broken'],
          data: [
            for (final PairwiseRegressionSummary p
                in result.pairwiseRegressionMatrix)
              [
                _runName(result, p.baseModelRunId),
                _runName(result, p.candidateModelRunId),
                _signedF(p.deltaF1),
                '${p.fixedImages}',
                '${p.brokenImages}',
              ],
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => content,
      ),
    );
    return doc.save();
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  String _runName(MultiModelComparisonResult result, String? id) {
    if (id == null) return '';
    for (final ModelRunLeaderboardEntry e in result.leaderboard) {
      if (e.modelRunId == id) return e.modelRunName;
    }
    return id;
  }

  String _f(double v) => '${(v * 100).toStringAsFixed(1)}%';
  String _signedF(double v) {
    final double pct = v * 100;
    return pct >= 0 ? '+${pct.toStringAsFixed(1)}%' : '${pct.toStringAsFixed(1)}%';
  }

  String _ap(double? v) => v == null ? '-' : '${(v * 100).toStringAsFixed(1)}%';

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static const String _htmlCss = '''
body{font-family:-apple-system,Segoe UI,Roboto,sans-serif;margin:24px;color:#222;}
h1{color:#283593;}
h2{color:#3949AB;margin-top:24px;border-bottom:1px solid #e0e0e0;padding-bottom:4px;}
table{border-collapse:collapse;margin:8px 0;font-size:13px;}
th,td{border:1px solid #ccc;padding:4px 8px;text-align:right;}
th:first-child,td:first-child{text-align:left;}
thead th{background:#E8EAF6;color:#1A237E;}
.muted{color:#888;}
''';
}
