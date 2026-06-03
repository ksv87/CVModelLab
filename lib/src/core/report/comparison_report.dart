import 'dart:convert';

import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;

import '../comparison/comparison_models.dart';
import '../i18n/message_key.dart';
import '../model/coco_dataset.dart';
import '../model/model_run.dart';
import '../report/csv_exporter.dart';
import '../../ui/l10n/app_localizations.dart';

class ComparisonReportFileNames {
  static const String html = 'cv_model_lab_comparison.html';
  static const String perClass = 'comparison_per_class.csv';
  static const String images = 'comparison_images.csv';
  static const String pdf = 'cv_model_lab_comparison.pdf';
}

class ComparisonReportBundle {
  const ComparisonReportBundle({
    required this.htmlReport,
    required this.csvFiles,
    required this.binaryFiles,
  });

  final String htmlReport;
  final Map<String, String> csvFiles;
  final Map<String, List<int>> binaryFiles;

  List<String> get fileNames => [
        if (htmlReport.isNotEmpty) ComparisonReportFileNames.html,
        ...csvFiles.keys,
        ...binaryFiles.keys,
      ];
}

class ComparisonReportBuilder {
  const ComparisonReportBuilder();

  Future<ComparisonReportBundle> build({
    required CocoDataset dataset,
    required ModelRun baseRun,
    required ModelRun candidateRun,
    required ModelComparisonResult result,
    String? projectName,
    bool includeHtml = true,
    bool includePerClassCsv = true,
    bool includeImagesCsv = true,
    bool includePdf = true,
    DateTime? generatedAt,
    pw.ThemeData? pdfTheme,
    AppLocale locale = AppLocale.en,
  }) async {
    final DateTime timestamp = generatedAt ?? DateTime.now();
    final AppLocalizations l = AppLocalizations.forLocale(locale);

    final String html = includeHtml
        ? _buildHtml(
            dataset: dataset,
            baseRun: baseRun,
            candidateRun: candidateRun,
            result: result,
            projectName: projectName,
            generatedAt: timestamp,
            l: l,
          )
        : '';

    final Map<String, String> csvFiles = {};
    if (includePerClassCsv) {
      csvFiles[ComparisonReportFileNames.perClass] = _buildPerClassCsv(result);
    }
    if (includeImagesCsv) {
      csvFiles[ComparisonReportFileNames.images] = _buildImagesCsv(result);
    }

    final Map<String, List<int>> binaryFiles = {};
    if (includePdf) {
      binaryFiles[ComparisonReportFileNames.pdf] = await _buildPdf(
        baseRun: baseRun,
        candidateRun: candidateRun,
        result: result,
        projectName: projectName,
        generatedAt: timestamp,
        theme: pdfTheme,
        l: l,
      );
    }

    return ComparisonReportBundle(
      htmlReport: html,
      csvFiles: csvFiles,
      binaryFiles: binaryFiles,
    );
  }

  // ---------- HTML ----------

  String _buildHtml({
    required CocoDataset dataset,
    required ModelRun baseRun,
    required ModelRun candidateRun,
    required ModelComparisonResult result,
    String? projectName,
    required DateTime generatedAt,
    required AppLocalizations l,
  }) {
    final String langAttr = l.locale == AppLocale.ru ? 'ru' : 'en';
    final StringBuffer html = StringBuffer();
    html.writeln('<!DOCTYPE html>');
    html.writeln('<html lang="$langAttr">');
    html.writeln('<head>');
    html.writeln('<meta charset="utf-8">');
    html.writeln(
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
    );
    final String title =
        'CV Model Lab — ${l.t(MessageKey.reportModelComparison)}';
    html.writeln('<title>${_esc(title)}</title>');
    html.writeln('<style>${_css()}</style>');
    html.writeln('</head>');
    html.writeln('<body>');

    // Header.
    html.writeln('<header>');
    html.writeln('<h1>${_esc(title)}</h1>');
    if (projectName != null) {
      html.writeln(
        '<p><strong>Project:</strong> ${_esc(projectName)}</p>',
      );
    }
    html.writeln(
      '<p><strong>Base model:</strong> ${_esc(baseRun.name)}</p>',
    );
    html.writeln(
      '<p><strong>Candidate model:</strong> ${_esc(candidateRun.name)}</p>',
    );
    html.writeln(
      '<p><strong>Generated at:</strong> ${_esc(generatedAt.toIso8601String())}</p>',
    );
    html.writeln('</header>');

    // Overall diff.
    html.writeln('<section>');
    html.writeln('<h2>${_esc(l.t(MessageKey.reportOverallMetrics))}</h2>');
    _writeOverallDiffTable(html, result.overallDiff, baseRun, candidateRun);
    html.writeln('</section>');

    // Per-class diff.
    html.writeln('<section>');
    html.writeln('<h2>${_esc(l.t(MessageKey.reportPerClassMetrics))}</h2>');
    _writePerClassDiffTable(html, result.perClassDiffs, baseRun, candidateRun);
    html.writeln('</section>');

    // Image status lists.
    html.writeln('<section>');
    html.writeln('<h2>${_esc(l.t(MessageKey.reportImagesByStatus))}</h2>');
    _writeImageStatusSection(
      html,
      'Fixed (base had errors, candidate correct)',
      result.fixedImageIds,
      dataset,
      result,
    );
    _writeImageStatusSection(
      html,
      'Broken (base correct, candidate has errors)',
      result.brokenImageIds,
      dataset,
      result,
    );
    _writeImageStatusSection(
      html,
      'Improved (both have errors, candidate has fewer)',
      result.improvedImageIds,
      dataset,
      result,
    );
    _writeImageStatusSection(
      html,
      'Regressed (both have errors, candidate has more)',
      result.regressedImageIds,
      dataset,
      result,
    );
    html.writeln('</section>');

    html.writeln('</body>');
    html.writeln('</html>');
    return html.toString();
  }

  void _writeOverallDiffTable(
    StringBuffer html,
    MetricsDiff diff,
    ModelRun baseRun,
    ModelRun candidateRun,
  ) {
    html.writeln('<table>');
    html.writeln(
      '<thead><tr><th>Metric</th><th>${_esc(baseRun.name)}</th>'
      '<th>${_esc(candidateRun.name)}</th><th>Delta</th></tr></thead>',
    );
    html.writeln('<tbody>');
    _diffRow(
      html,
      'Precision',
      diff.basePrecision,
      diff.candidatePrecision,
      diff.deltaPrecision,
      isPercent: true,
      higherIsBetter: true,
    );
    _diffRow(
      html,
      'Recall',
      diff.baseRecall,
      diff.candidateRecall,
      diff.deltaRecall,
      isPercent: true,
      higherIsBetter: true,
    );
    _diffRow(
      html,
      'F1',
      diff.baseF1,
      diff.candidateF1,
      diff.deltaF1,
      isPercent: true,
      higherIsBetter: true,
    );
    _intDiffRow(
      html,
      'TP',
      diff.baseTp,
      diff.candidateTp,
      diff.deltaTp,
      higherIsBetter: true,
    );
    _intDiffRow(
      html,
      'FP',
      diff.baseFp,
      diff.candidateFp,
      diff.deltaFp,
      higherIsBetter: false,
    );
    _intDiffRow(
      html,
      'FN',
      diff.baseFn,
      diff.candidateFn,
      diff.deltaFn,
      higherIsBetter: false,
    );
    _intDiffRow(
      html,
      'Images with errors',
      diff.baseImagesWithErrors,
      diff.candidateImagesWithErrors,
      diff.deltaImagesWithErrors,
      higherIsBetter: false,
    );
    html.writeln('</tbody></table>');
  }

  void _writePerClassDiffTable(
    StringBuffer html,
    List<ClassMetricsDiff> diffs,
    ModelRun baseRun,
    ModelRun candidateRun,
  ) {
    html.writeln('<table>');
    html.writeln(
      '<thead><tr>'
      '<th>Class</th>'
      '<th>${_esc(baseRun.name)} P</th><th>${_esc(candidateRun.name)} P</th><th>ΔP</th>'
      '<th>${_esc(baseRun.name)} R</th><th>${_esc(candidateRun.name)} R</th><th>ΔR</th>'
      '<th>${_esc(baseRun.name)} F1</th><th>${_esc(candidateRun.name)} F1</th><th>ΔF1</th>'
      '<th>ΔTP</th><th>ΔFP</th><th>ΔFN</th>'
      '</tr></thead>',
    );
    html.writeln('<tbody>');
    for (final ClassMetricsDiff d in diffs) {
      html.writeln('<tr>');
      html.writeln('<td>${_esc(d.categoryName)}</td>');
      html.writeln('<td>${_numP(d.diff.basePrecision)}</td>');
      html.writeln('<td>${_numP(d.diff.candidatePrecision)}</td>');
      html.writeln(_deltaCell(d.diff.deltaPrecision, higherIsBetter: true));
      html.writeln('<td>${_numP(d.diff.baseRecall)}</td>');
      html.writeln('<td>${_numP(d.diff.candidateRecall)}</td>');
      html.writeln(_deltaCell(d.diff.deltaRecall, higherIsBetter: true));
      html.writeln('<td>${_numP(d.diff.baseF1)}</td>');
      html.writeln('<td>${_numP(d.diff.candidateF1)}</td>');
      html.writeln(_deltaCell(d.diff.deltaF1, higherIsBetter: true));
      html.writeln(_intDeltaCell(d.diff.deltaTp, higherIsBetter: true));
      html.writeln(_intDeltaCell(d.diff.deltaFp, higherIsBetter: false));
      html.writeln(_intDeltaCell(d.diff.deltaFn, higherIsBetter: false));
      html.writeln('</tr>');
    }
    html.writeln('</tbody></table>');
  }

  void _writeImageStatusSection(
    StringBuffer html,
    String title,
    List<int> imageIds,
    CocoDataset dataset,
    ModelComparisonResult result,
  ) {
    html.writeln('<h3>${_esc(title)} (${imageIds.length})</h3>');
    if (imageIds.isEmpty) {
      html.writeln('<p class="empty">None.</p>');
      return;
    }
    final Map<int, ImageComparisonSummary> summaryById = {
      for (final s in result.imageSummaries) s.imageId: s,
    };
    html.writeln('<table>');
    html.writeln(
      '<thead><tr><th>image_id</th><th>file_name</th>'
      '<th>Base TP/FP/FN</th><th>Candidate TP/FP/FN</th>'
      '<th>ΔTP</th><th>ΔFP</th><th>ΔFN</th></tr></thead>',
    );
    html.writeln('<tbody>');
    for (final int id in imageIds) {
      final String fileName = dataset.imagesById[id]?.fileName ?? '$id';
      final ImageComparisonSummary? s = summaryById[id];
      html.writeln('<tr>');
      html.writeln('<td>$id</td>');
      html.writeln('<td>${_esc(fileName)}</td>');
      if (s != null) {
        html.writeln('<td>${s.baseTp}/${s.baseFp}/${s.baseFn}</td>');
        html.writeln(
          '<td>${s.candidateTp}/${s.candidateFp}/${s.candidateFn}</td>',
        );
        html.writeln('<td>${_sign(s.deltaTp)}</td>');
        html.writeln('<td>${_sign(s.deltaFp)}</td>');
        html.writeln('<td>${_sign(s.deltaFn)}</td>');
      } else {
        html.writeln('<td>-</td><td>-</td><td>-</td><td>-</td><td>-</td>');
      }
      html.writeln('</tr>');
    }
    html.writeln('</tbody></table>');
  }

  void _diffRow(
    StringBuffer html,
    String label,
    double base,
    double candidate,
    double delta, {
    bool isPercent = false,
    bool higherIsBetter = true,
  }) {
    html.writeln('<tr>');
    html.writeln('<th>${_esc(label)}</th>');
    html.writeln('<td>${_numP(base)}</td>');
    html.writeln('<td>${_numP(candidate)}</td>');
    html.writeln(_deltaCell(delta, higherIsBetter: higherIsBetter));
    html.writeln('</tr>');
  }

  void _intDiffRow(
    StringBuffer html,
    String label,
    int base,
    int candidate,
    int delta, {
    bool higherIsBetter = true,
  }) {
    html.writeln('<tr>');
    html.writeln('<th>${_esc(label)}</th>');
    html.writeln('<td>$base</td>');
    html.writeln('<td>$candidate</td>');
    html.writeln(_intDeltaCell(delta, higherIsBetter: higherIsBetter));
    html.writeln('</tr>');
  }

  String _deltaCell(double delta, {required bool higherIsBetter}) {
    final double pct = delta * 100;
    final String text =
        pct >= 0 ? '+${pct.toStringAsFixed(1)}%' : '${pct.toStringAsFixed(1)}%';
    final bool isGood = higherIsBetter ? delta > 0 : delta < 0;
    final bool isBad = higherIsBetter ? delta < 0 : delta > 0;
    final String cls = isGood ? ' class="good"' : (isBad ? ' class="bad"' : '');
    return '<td$cls>$text</td>';
  }

  String _intDeltaCell(int delta, {required bool higherIsBetter}) {
    final String text = delta >= 0 ? '+$delta' : '$delta';
    final bool isGood = higherIsBetter ? delta > 0 : delta < 0;
    final bool isBad = higherIsBetter ? delta < 0 : delta > 0;
    final String cls = isGood ? ' class="good"' : (isBad ? ' class="bad"' : '');
    return '<td$cls>$text</td>';
  }

  String _sign(int value) => value >= 0 ? '+$value' : '$value';

  // ---------- PDF ----------

  Future<List<int>> _buildPdf({
    required ModelRun baseRun,
    required ModelRun candidateRun,
    required ModelComparisonResult result,
    String? projectName,
    required DateTime generatedAt,
    pw.ThemeData? theme,
    required AppLocalizations l,
  }) async {
    final MetricsDiff d = result.overallDiff;
    final pw.Document doc = pw.Document(theme: theme);

    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
    String signed(double v) {
      final double p = v * 100;
      return p >= 0 ? '+${p.toStringAsFixed(1)}%' : '${p.toStringAsFixed(1)}%';
    }

    String signedI(int v) => v >= 0 ? '+$v' : '$v';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => [
          pw.Header(level: 0, text: 'CV Model Lab — Comparison Report'),
          if (projectName != null) pw.Text('Project: $projectName'),
          pw.Text('Base model: ${baseRun.name}'),
          pw.Text('Candidate model: ${candidateRun.name}'),
          pw.Text('Generated: ${generatedAt.toIso8601String()}'),
          pw.SizedBox(height: 12),
          pw.Header(level: 1, text: 'Overall metrics'),
          pw.TableHelper.fromTextArray(
            headers: const ['Metric', 'Base', 'Candidate', 'Delta'],
            data: [
              [
                'Precision',
                pct(d.basePrecision),
                pct(d.candidatePrecision),
                signed(d.deltaPrecision),
              ],
              [
                'Recall',
                pct(d.baseRecall),
                pct(d.candidateRecall),
                signed(d.deltaRecall),
              ],
              ['F1', pct(d.baseF1), pct(d.candidateF1), signed(d.deltaF1)],
              ['TP', '${d.baseTp}', '${d.candidateTp}', signedI(d.deltaTp)],
              ['FP', '${d.baseFp}', '${d.candidateFp}', signedI(d.deltaFp)],
              ['FN', '${d.baseFn}', '${d.candidateFn}', signedI(d.deltaFn)],
              [
                'Images w/ Errors',
                '${d.baseImagesWithErrors}',
                '${d.candidateImagesWithErrors}',
                signedI(d.deltaImagesWithErrors),
              ],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Header(level: 1, text: 'Image status summary'),
          pw.TableHelper.fromTextArray(
            headers: const ['Status', 'Count'],
            data: [
              ['Fixed', '${result.fixedImageIds.length}'],
              ['Broken', '${result.brokenImageIds.length}'],
              ['Improved', '${result.improvedImageIds.length}'],
              ['Regressed', '${result.regressedImageIds.length}'],
              [
                'Unchanged correct',
                '${result.unchangedCorrectImageIds.length}',
              ],
              ['Unchanged wrong', '${result.unchangedWrongImageIds.length}'],
            ],
          ),
          if (result.perClassDiffs.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Header(level: 1, text: 'Per-class diff (top 20 by |dF1|)'),
            pw.TableHelper.fromTextArray(
              headers: const [
                'Class',
                'Base F1',
                'Cand F1',
                'dF1',
                'dTP',
                'dFP',
                'dFN',
              ],
              data: [
                for (final item in (result.perClassDiffs.toList()
                      ..sort(
                        (a, b) => b.diff.deltaF1.abs().compareTo(
                              a.diff.deltaF1.abs(),
                            ),
                      ))
                    .take(20))
                  [
                    item.categoryName,
                    pct(item.diff.baseF1),
                    pct(item.diff.candidateF1),
                    signed(item.diff.deltaF1),
                    signedI(item.diff.deltaTp),
                    signedI(item.diff.deltaFp),
                    signedI(item.diff.deltaFn),
                  ],
              ],
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  // ---------- CSV ----------

  String _buildPerClassCsv(ModelComparisonResult result) {
    final List<List<Object?>> rows = [
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
    ];
    for (final ClassMetricsDiff d in result.perClassDiffs) {
      rows.add([
        d.categoryId,
        d.categoryName,
        d.diff.basePrecision,
        d.diff.candidatePrecision,
        d.diff.deltaPrecision,
        d.diff.baseRecall,
        d.diff.candidateRecall,
        d.diff.deltaRecall,
        d.diff.baseF1,
        d.diff.candidateF1,
        d.diff.deltaF1,
        d.diff.baseTp,
        d.diff.candidateTp,
        d.diff.deltaTp,
        d.diff.baseFp,
        d.diff.candidateFp,
        d.diff.deltaFp,
        d.diff.baseFn,
        d.diff.candidateFn,
        d.diff.deltaFn,
      ]);
    }
    return _renderCsv(rows);
  }

  String _buildImagesCsv(ModelComparisonResult result) {
    final List<List<Object?>> rows = [
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
    ];
    for (final ImageComparisonSummary s in result.imageSummaries) {
      rows.add([
        s.imageId,
        s.fileName,
        s.status.name,
        s.baseTp,
        s.baseFp,
        s.baseFn,
        s.candidateTp,
        s.candidateFp,
        s.candidateFn,
        s.deltaTp,
        s.deltaFp,
        s.deltaFn,
      ]);
    }
    return _renderCsv(rows);
  }

  String _renderCsv(List<List<Object?>> rows) {
    final StringBuffer buffer = StringBuffer();
    for (final List<Object?> row in rows) {
      buffer.write(row.map(csvEscape).join(','));
      buffer.write('\n');
    }
    return buffer.toString();
  }

  // ---------- Helpers ----------

  String _css() {
    return 'body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;'
        'margin:24px;color:#1e293b;line-height:1.4;}'
        'h1{margin:0 0 8px;}h2{margin-top:32px;border-bottom:2px solid #e2e8f0;'
        'padding-bottom:4px;}h3{margin-top:24px;}'
        'header p{margin:2px 0;}'
        'section{margin-bottom:24px;}'
        'table{border-collapse:collapse;margin:8px 0;font-size:14px;}'
        'th,td{border:1px solid #cbd5e1;padding:4px 10px;text-align:left;}'
        'thead th{background:#f1f5f9;}'
        'td.good{background:#dcfce7;color:#166534;font-weight:600;}'
        'td.bad{background:#fee2e2;color:#b91c1c;font-weight:600;}'
        'p.empty{color:#64748b;font-style:italic;}';
  }

  static String _esc(String value) => const HtmlEscape().convert(value);

  static String _numP(double value) => '${(value * 100).toStringAsFixed(1)}%';
}
