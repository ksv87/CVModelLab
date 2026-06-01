import 'dart:convert';

import '../eval/class_stats.dart';
import '../eval/small_object_stats.dart';
import '../model/coco_dataset.dart';
import '../model/detection_match.dart';
import '../model/eval_config.dart';
import '../model/eval_result.dart';
import '../model/eval_view_filter.dart';
import '../model/model_run.dart';
import '../eval/eval_result_filter.dart';
import 'report_models.dart';

/// Builds a self-contained HTML report (inline CSS, no external assets, no JS).
class HtmlReportBuilder {
  const HtmlReportBuilder({this.errorExampleLimit = 25});

  /// Maximum number of rows shown in each "error examples" table.
  final int errorExampleLimit;

  String build({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required EvalConfig evalConfig,
    required EvalResult evalResult,
    EvalViewFilter? activeFilter,
    FilteredEvalView? filteredView,
    ReportScope scope = ReportScope.fullEvaluation,
    String? projectName,
    String? modelRunName,
    DateTime? generatedAt,
    Set<String> missingImageFileNames = const <String>{},
  }) {
    final EvalViewFilter filter = activeFilter ?? const EvalViewFilter();
    final List<DetectionMatch> matches = matchesForScope(
      evalResult: evalResult,
      scope: scope,
      filteredView: filteredView,
    );
    final List<int> imageIds = imageIdsForScope(
      dataset: dataset,
      scope: scope,
      filteredView: filteredView,
    );
    final List<ReportMatchRow> matchRows = buildMatchRows(
      dataset: dataset,
      modelRun: modelRun,
      matches: matches,
    );

    final StringBuffer html = StringBuffer();
    html.writeln('<!DOCTYPE html>');
    html.writeln('<html lang="en">');
    html.writeln('<head>');
    html.writeln('<meta charset="utf-8">');
    html.writeln(
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
    );
    html.writeln('<title>CV Model Lab Report</title>');
    html.writeln('<style>${_css()}</style>');
    html.writeln('</head>');
    html.writeln('<body>');

    _writeHeader(html, projectName, modelRunName, generatedAt ?? DateTime.now());
    _writeConfigSection(html, evalConfig, dataset, scope, activeFilter);
    _writeDatasetSummary(html, dataset, evalResult, missingImageFileNames);
    _writeOverallMetrics(html, evalResult);
    _writePerClassTable(html, evalResult);
    _writeClassImbalanceTable(html, evalResult);
    _writeSmallObjectTable(html, dataset, evalResult);
    _writeErrorExamples(html, evalResult, matchRows, imageIds, dataset, filter);

    html.writeln('</body>');
    html.writeln('</html>');
    return html.toString();
  }

  void _writeHeader(
    StringBuffer html,
    String? projectName,
    String? modelRunName,
    DateTime generatedAt,
  ) {
    html.writeln('<header>');
    html.writeln('<h1>CV Model Lab Report</h1>');
    html.writeln(
      '<p><strong>Project:</strong> ${_esc(projectName ?? 'Untitled project')}</p>',
    );
    html.writeln(
      '<p><strong>Model run:</strong> ${_esc(modelRunName ?? '-')}</p>',
    );
    html.writeln(
      '<p><strong>Generated at:</strong> ${_esc(generatedAt.toIso8601String())}</p>',
    );
    html.writeln('</header>');
  }

  void _writeConfigSection(
    StringBuffer html,
    EvalConfig config,
    CocoDataset dataset,
    ReportScope scope,
    EvalViewFilter? activeFilter,
  ) {
    html.writeln('<section>');
    html.writeln('<h2>Evaluation config</h2>');
    final List<List<String>> rows = [
      ['IoU threshold', _num(config.iouThreshold)],
      ['Confidence threshold', _num(config.confidenceThreshold)],
      ['Class-aware matching', config.classAwareMatching ? 'yes' : 'no'],
      ['Ignore crowd', config.ignoreCrowd ? 'yes' : 'no'],
      [
        'Scope',
        scope == ReportScope.filteredView
            ? 'Current filtered view'
            : 'Full evaluation result',
      ],
    ];
    if (activeFilter != null && activeFilter.hasClassFilter) {
      rows.add([
        'Selected classes',
        activeFilter.selectedClassIds
            .map((int id) => dataset.categoriesById[id]?.name ?? '$id')
            .join(', '),
      ]);
    }
    if (activeFilter != null) {
      final List<String> active = _activeFilterDescriptions(activeFilter);
      if (active.isNotEmpty) {
        rows.add(['Active view filters', active.join(', ')]);
      }
    }
    _keyValueTable(html, rows);
    html.writeln('</section>');
  }

  List<String> _activeFilterDescriptions(EvalViewFilter filter) {
    final List<String> active = [];
    if (filter.imageFilter != EvalImageFilter.all) {
      active.add('image filter: ${filter.imageFilter.name}');
    }
    if (filter.objectSizeFilter != ObjectSizeFilter.all) {
      active.add('object size: ${filter.objectSizeFilter.name}');
    }
    if (filter.onlyImagesWithErrors) {
      active.add('only images with errors');
    }
    if (filter.onlyImagesWithClassConfusion) {
      active.add('only class confusion');
    }
    if (filter.onlyMissingImages) {
      active.add('only missing images');
    }
    if (filter.enabledMatchTypes.length < 3) {
      active.add(
        'match types: ${filter.enabledMatchTypes.map(matchTypeLabel).join('/')}',
      );
    }
    return active;
  }

  void _writeDatasetSummary(
    StringBuffer html,
    CocoDataset dataset,
    EvalResult evalResult,
    Set<String> missingImageFileNames,
  ) {
    final OverallStats overall = evalResult.overall;
    html.writeln('<section>');
    html.writeln('<h2>Dataset summary</h2>');
    final List<List<String>> rows = [
      ['Total images', '${dataset.imagesById.length}'],
      ['Total annotations / GT boxes', '${overall.totalGt}'],
      ['Total categories', '${dataset.categoriesById.length}'],
      [
        'Total predictions before threshold',
        '${overall.totalPredictionsBeforeThreshold}',
      ],
      [
        'Total predictions after threshold',
        '${overall.totalPredictionsAfterThreshold}',
      ],
    ];
    if (missingImageFileNames.isNotEmpty) {
      rows.add(['Missing image files', '${missingImageFileNames.length}']);
    }
    _keyValueTable(html, rows);
    html.writeln('</section>');
  }

  void _writeOverallMetrics(StringBuffer html, EvalResult evalResult) {
    final OverallStats o = evalResult.overall;
    final double precision = _ratio(o.totalTp, o.totalTp + o.totalFp);
    final double recall = _ratio(o.totalTp, o.totalTp + o.totalFn);
    final double f1 = _f1(precision, recall);
    html.writeln('<section>');
    html.writeln('<h2>Overall metrics</h2>');
    _keyValueTable(html, [
      ['TP', '${o.totalTp}'],
      ['FP', '${o.totalFp}'],
      ['FN', '${o.totalFn}'],
    ]);
    html.writeln('<table>');
    html.writeln(
      '<thead><tr><th>Metric</th><th>Precision</th><th>Recall</th><th>F1</th></tr></thead>',
    );
    html.writeln('<tbody>');
    _metricRow(html, 'Overall', precision, recall, f1);
    _metricRow(html, 'Micro', o.microPrecision, o.microRecall, o.microF1);
    _metricRow(html, 'Macro', o.macroPrecision, o.macroRecall, o.macroF1);
    html.writeln('</tbody></table>');
    _keyValueTable(html, [
      ['Images with any error', '${o.imagesWithAnyError}'],
      ['Images with FP', '${o.imagesWithFp}'],
      ['Images with FN', '${o.imagesWithFn}'],
    ]);
    html.writeln('</section>');
  }

  void _metricRow(
    StringBuffer html,
    String label,
    double precision,
    double recall,
    double f1,
  ) {
    html.writeln('<tr>');
    html.writeln('<td>${_esc(label)}</td>');
    html.writeln(_metricCell(precision));
    html.writeln(_metricCell(recall));
    html.writeln(_metricCell(f1));
    html.writeln('</tr>');
  }

  void _writePerClassTable(StringBuffer html, EvalResult evalResult) {
    html.writeln('<section>');
    html.writeln('<h2>Per-class metrics</h2>');
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
    html.writeln('<table>');
    html.writeln(
      '<thead><tr><th>Class</th><th>GT</th><th>Pred</th><th>TP</th>'
      '<th>FP</th><th>FN</th><th>Precision</th><th>Recall</th><th>F1</th></tr></thead>',
    );
    html.writeln('<tbody>');
    for (final ClassStats stat in stats) {
      html.writeln('<tr>');
      html.writeln('<td>${_esc(stat.categoryName)}</td>');
      html.writeln('<td>${stat.gtCount}</td>');
      html.writeln('<td>${stat.predCount}</td>');
      html.writeln('<td>${stat.tp}</td>');
      html.writeln('<td>${stat.fp}</td>');
      html.writeln('<td>${stat.fn}</td>');
      html.writeln(_metricCell(stat.precision));
      html.writeln(_metricCell(stat.recall));
      html.writeln(_metricCell(stat.f1));
      html.writeln('</tr>');
    }
    html.writeln('</tbody></table>');
    html.writeln('</section>');
  }

  void _writeClassImbalanceTable(StringBuffer html, EvalResult evalResult) {
    final List<ClassStats> stats = evalResult.perClassStats.values.toList()
      ..sort((ClassStats a, ClassStats b) => b.gtCount.compareTo(a.gtCount));
    final int totalGt =
        stats.fold(0, (int sum, ClassStats s) => sum + s.gtCount);
    final int totalPred =
        stats.fold(0, (int sum, ClassStats s) => sum + s.predCount);
    html.writeln('<section>');
    html.writeln('<h2>Class imbalance</h2>');
    html.writeln('<table>');
    html.writeln(
      '<thead><tr><th>Class</th><th>GT count</th><th>% of all GT</th>'
      '<th>Pred count</th><th>% of all predictions</th></tr></thead>',
    );
    html.writeln('<tbody>');
    for (final ClassStats stat in stats) {
      html.writeln('<tr>');
      html.writeln('<td>${_esc(stat.categoryName)}</td>');
      html.writeln('<td>${stat.gtCount}</td>');
      html.writeln('<td>${_percent(stat.gtCount, totalGt)}</td>');
      html.writeln('<td>${stat.predCount}</td>');
      html.writeln('<td>${_percent(stat.predCount, totalPred)}</td>');
      html.writeln('</tr>');
    }
    html.writeln('</tbody></table>');
    html.writeln('</section>');
  }

  void _writeSmallObjectTable(
    StringBuffer html,
    CocoDataset dataset,
    EvalResult evalResult,
  ) {
    if (evalResult.smallObjectStats.isEmpty) {
      return;
    }
    html.writeln('<section>');
    html.writeln('<h2>Small object stats</h2>');
    html.writeln('<table>');
    html.writeln(
      '<thead><tr><th>Class</th><th>Size bucket</th><th>GT</th>'
      '<th>TP</th><th>FN</th><th>Recall</th></tr></thead>',
    );
    html.writeln('<tbody>');
    final List<int> classIds = evalResult.smallObjectStats.keys.toList()..sort();
    for (final int classId in classIds) {
      final String className =
          dataset.categoriesById[classId]?.name ?? '$classId';
      final Map<ObjectSizeBucket, SmallObjectClassStats> buckets =
          evalResult.smallObjectStats[classId]!;
      for (final ObjectSizeBucket bucket in ObjectSizeBucket.values) {
        final SmallObjectClassStats? stat = buckets[bucket];
        if (stat == null || stat.gtCount == 0) {
          continue;
        }
        html.writeln('<tr>');
        html.writeln('<td>${_esc(className)}</td>');
        html.writeln('<td>${bucket.name}</td>');
        html.writeln('<td>${stat.gtCount}</td>');
        html.writeln('<td>${stat.tp}</td>');
        html.writeln('<td>${stat.fn}</td>');
        html.writeln(_metricCell(stat.recall));
        html.writeln('</tr>');
      }
    }
    html.writeln('</tbody></table>');
    html.writeln('</section>');
  }

  void _writeErrorExamples(
    StringBuffer html,
    EvalResult evalResult,
    List<ReportMatchRow> matchRows,
    List<int> imageIds,
    CocoDataset dataset,
    EvalViewFilter filter,
  ) {
    html.writeln('<section>');
    html.writeln('<h2>Error examples</h2>');

    final List<ReportMatchRow> falsePositives = matchRows
        .where((ReportMatchRow r) => r.matchType == 'FP')
        .toList()
      ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
    _writeMatchTable(html, 'Top false positives', falsePositives);

    final List<ReportMatchRow> falseNegatives =
        matchRows.where((ReportMatchRow r) => r.matchType == 'FN').toList();
    _writeMatchTable(html, 'Top false negatives', falseNegatives);

    final List<ReportMatchRow> highConfFp = falsePositives
        .where(
          (ReportMatchRow r) =>
              (r.score ?? 0) >= filter.highConfidenceFpThreshold,
        )
        .toList();
    _writeMatchTable(html, 'High confidence false positives', highConfFp);

    final List<ReportMatchRow> lowIouTp = matchRows
        .where(
          (ReportMatchRow r) =>
              r.matchType == 'TP' &&
              r.iou != null &&
              r.iou! <= filter.lowIouTpThreshold,
        )
        .toList()
      ..sort((a, b) => (a.iou ?? 0).compareTo(b.iou ?? 0));
    _writeMatchTable(html, 'Low IoU true positives', lowIouTp);

    _writeWorstImagesTable(html, evalResult, imageIds, dataset);
    html.writeln('</section>');
  }

  void _writeMatchTable(
    StringBuffer html,
    String title,
    List<ReportMatchRow> rows,
  ) {
    html.writeln('<h3>${_esc(title)}</h3>');
    if (rows.isEmpty) {
      html.writeln('<p class="empty">None.</p>');
      return;
    }
    html.writeln('<table>');
    html.writeln(
      '<thead><tr><th>file_name</th><th>image_id</th><th>class</th>'
      '<th>score</th><th>IoU</th><th>bbox</th><th>reason</th></tr></thead>',
    );
    html.writeln('<tbody>');
    for (final ReportMatchRow row in rows.take(errorExampleLimit)) {
      html.writeln('<tr>');
      html.writeln('<td>${_esc(row.fileName)}</td>');
      html.writeln('<td>${row.imageId}</td>');
      html.writeln('<td>${_esc(row.categoryName)}</td>');
      html.writeln('<td>${row.score == null ? '' : _num(row.score!)}</td>');
      html.writeln('<td>${row.iou == null ? '' : _num(row.iou!)}</td>');
      html.writeln('<td>${_esc(_bbox(row))}</td>');
      html.writeln('<td>${_esc(row.reason ?? '')}</td>');
      html.writeln('</tr>');
    }
    html.writeln('</tbody></table>');
  }

  void _writeWorstImagesTable(
    StringBuffer html,
    EvalResult evalResult,
    List<int> imageIds,
    CocoDataset dataset,
  ) {
    html.writeln('<h3>Images with most errors</h3>');
    final List<ImageEvalSummary> summaries = [
      for (final int imageId in imageIds)
        if (evalResult.imageSummaries[imageId] != null)
          evalResult.imageSummaries[imageId]!,
    ]..sort((a, b) => (b.fp + b.fn).compareTo(a.fp + a.fn));
    final List<ImageEvalSummary> worst = summaries
        .where((ImageEvalSummary s) => s.fp + s.fn > 0)
        .take(errorExampleLimit)
        .toList();
    if (worst.isEmpty) {
      html.writeln('<p class="empty">None.</p>');
      return;
    }
    html.writeln('<table>');
    html.writeln(
      '<thead><tr><th>file_name</th><th>image_id</th><th>TP</th>'
      '<th>FP</th><th>FN</th></tr></thead>',
    );
    html.writeln('<tbody>');
    for (final ImageEvalSummary s in worst) {
      html.writeln('<tr>');
      html.writeln(
        '<td>${_esc(dataset.imagesById[s.imageId]?.fileName ?? '')}</td>',
      );
      html.writeln('<td>${s.imageId}</td>');
      html.writeln('<td>${s.tp}</td>');
      html.writeln('<td>${s.fp}</td>');
      html.writeln('<td>${s.fn}</td>');
      html.writeln('</tr>');
    }
    html.writeln('</tbody></table>');
  }

  void _keyValueTable(StringBuffer html, List<List<String>> rows) {
    html.writeln('<table class="kv">');
    html.writeln('<tbody>');
    for (final List<String> row in rows) {
      html.writeln('<tr><th>${_esc(row[0])}</th><td>${_esc(row[1])}</td></tr>');
    }
    html.writeln('</tbody></table>');
  }

  String _metricCell(double value) {
    final String cls = value < 0.5 ? ' class="weak"' : '';
    return '<td$cls>${_num(value)}</td>';
  }

  String _bbox(ReportMatchRow row) {
    if (row.bbox == null) {
      return '';
    }
    return '[${_num(row.bbox!.x)}, ${_num(row.bbox!.y)}, '
        '${_num(row.bbox!.width)}, ${_num(row.bbox!.height)}]';
  }

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
        'table.kv th{background:#f8fafc;width:280px;}'
        'td.weak{background:#fee2e2;color:#b91c1c;font-weight:600;}'
        'p.empty{color:#64748b;font-style:italic;}';
  }

  static String _esc(String value) {
    return const HtmlEscape().convert(value);
  }

  static String _num(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      // Integers like bbox coordinates print without trailing ".0".
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(3);
  }

  static double _ratio(int numerator, int denominator) {
    return denominator == 0 ? 0 : numerator / denominator;
  }

  static double _f1(double precision, double recall) {
    return precision + recall == 0
        ? 0
        : 2 * precision * recall / (precision + recall);
  }

  static String _percent(int part, int total) {
    if (total == 0) {
      return '0%';
    }
    return '${(part / total * 100).toStringAsFixed(1)}%';
  }
}
