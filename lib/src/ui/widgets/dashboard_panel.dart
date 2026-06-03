import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import '../l10n/app_locale_scope.dart';
import 'status_views.dart';

class DashboardPanel extends StatelessWidget {
  const DashboardPanel({
    required this.dataset,
    required this.evalResult,
    required this.selectedImage,
    required this.selectedMatches,
    required this.selectedMatch,
    required this.issues,
    this.apEvalResult,
    this.canRunApEval = false,
    this.runningApEval = false,
    this.onRunApEval,
    this.onImportApMetrics,
    this.apEvalUnavailableReason,
    super.key,
  });

  final CocoDataset dataset;
  final EvalResult evalResult;
  final ImageRecord? selectedImage;
  final List<DetectionMatch> selectedMatches;
  final DetectionMatch? selectedMatch;
  final List<ParseIssue> issues;
  final ApEvalResult? apEvalResult;
  final bool canRunApEval;
  final bool runningApEval;
  final VoidCallback? onRunApEval;
  final VoidCallback? onImportApMetrics;
  final String? apEvalUnavailableReason;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Dashboard',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _MetricsGrid(overall: evalResult.overall),
        const SizedBox(height: 16),
        Text(
          'Per Class',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _ClassStatsTable(stats: evalResult.perClassStats.values.toList()),
        const SizedBox(height: 16),
        Text(
          'Selected Image',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _SelectedImageDetails(
          image: selectedImage,
          matches: selectedMatches,
          categoriesById: dataset.categoriesById,
          selectedMatch: selectedMatch,
        ),
        const SizedBox(height: 16),
        _ApMetricsSection(
          apEvalResult: apEvalResult,
          canRunApEval: canRunApEval,
          runningApEval: runningApEval,
          onRunApEval: onRunApEval,
          onImportApMetrics: onImportApMetrics,
          apEvalUnavailableReason: apEvalUnavailableReason,
        ),
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Load Warnings',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...issues.take(8).map(
                (issue) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning),
                  title: Text(AppLocaleScope.l10n(context).parseIssue(issue)),
                  subtitle: issue.path == null ? null : Text(issue.path!),
                ),
              ),
          if (issues.length > 8) Text('+${issues.length - 8} more'),
        ],
      ],
    );
  }
}

class BrowserDashboardTabs extends StatelessWidget {
  const BrowserDashboardTabs({
    required this.dataset,
    required this.evalResult,
    required this.selectedImage,
    required this.selectedMatches,
    required this.selectedMatch,
    required this.issues,
    this.apEvalResult,
    this.canRunApEval = false,
    this.runningApEval = false,
    this.onRunApEval,
    this.onImportApMetrics,
    this.apEvalUnavailableReason,
    super.key,
  });

  final CocoDataset dataset;
  final EvalResult evalResult;
  final ImageRecord? selectedImage;
  final List<DetectionMatch> selectedMatches;
  final DetectionMatch? selectedMatch;
  final List<ParseIssue> issues;
  final ApEvalResult? apEvalResult;
  final bool canRunApEval;
  final bool runningApEval;
  final VoidCallback? onRunApEval;
  final VoidCallback? onImportApMetrics;
  final String? apEvalUnavailableReason;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Общее'),
              Tab(text: 'Selected'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _DashboardOverview(
                  evalResult: evalResult,
                  issues: issues,
                  apEvalResult: apEvalResult,
                  canRunApEval: canRunApEval,
                  runningApEval: runningApEval,
                  onRunApEval: onRunApEval,
                  onImportApMetrics: onImportApMetrics,
                  apEvalUnavailableReason: apEvalUnavailableReason,
                ),
                _SelectedDetailsView(
                  dataset: dataset,
                  selectedImage: selectedImage,
                  selectedMatches: selectedMatches,
                  selectedMatch: selectedMatch,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({
    required this.evalResult,
    required this.issues,
    this.apEvalResult,
    this.canRunApEval = false,
    this.runningApEval = false,
    this.onRunApEval,
    this.onImportApMetrics,
    this.apEvalUnavailableReason,
  });

  final EvalResult evalResult;
  final List<ParseIssue> issues;
  final ApEvalResult? apEvalResult;
  final bool canRunApEval;
  final bool runningApEval;
  final VoidCallback? onRunApEval;
  final VoidCallback? onImportApMetrics;
  final String? apEvalUnavailableReason;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Dashboard',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _MetricsGrid(overall: evalResult.overall),
        const SizedBox(height: 16),
        Text(
          'Per Class',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _ClassStatsTable(stats: evalResult.perClassStats.values.toList()),
        const SizedBox(height: 16),
        _ApMetricsSection(
          apEvalResult: apEvalResult,
          canRunApEval: canRunApEval,
          runningApEval: runningApEval,
          onRunApEval: onRunApEval,
          onImportApMetrics: onImportApMetrics,
          apEvalUnavailableReason: apEvalUnavailableReason,
        ),
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Load Warnings',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...issues.take(8).map(
                (issue) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning),
                  title: Text(AppLocaleScope.l10n(context).parseIssue(issue)),
                  subtitle: issue.path == null ? null : Text(issue.path!),
                ),
              ),
          if (issues.length > 8) Text('+${issues.length - 8} more'),
        ],
      ],
    );
  }
}

class _SelectedDetailsView extends StatelessWidget {
  const _SelectedDetailsView({
    required this.dataset,
    required this.selectedImage,
    required this.selectedMatches,
    required this.selectedMatch,
  });

  final CocoDataset dataset;
  final ImageRecord? selectedImage;
  final List<DetectionMatch> selectedMatches;
  final DetectionMatch? selectedMatch;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Selected Image',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _SelectedImageDetails(
          image: selectedImage,
          matches: selectedMatches,
          categoriesById: dataset.categoriesById,
          selectedMatch: selectedMatch,
        ),
      ],
    );
  }
}

class _SelectedObjectDetails extends StatelessWidget {
  const _SelectedObjectDetails({
    required this.image,
    required this.match,
    required this.categoriesById,
  });

  final ImageRecord image;
  final DetectionMatch match;
  final Map<int, CategoryRecord> categoriesById;

  @override
  Widget build(BuildContext context) {
    final Prediction? prediction = match.prediction;
    final GroundTruthAnnotation? groundTruth = match.groundTruth;
    final BBox? bbox = prediction?.bbox ?? groundTruth?.bbox;
    final int? categoryId =
        match.categoryId ?? prediction?.categoryId ?? groundTruth?.categoryId;
    final String className = categoryId == null
        ? '-'
        : categoriesById[categoryId]?.name ?? categoryId.toString();
    final List<String> rows = [
      'type: ${_matchTypeLabelStatic(match.type)}',
      'class: $className',
      if (categoryId != null) 'category_id: $categoryId',
      if (bbox != null)
        'bbox: ${bbox.x.toStringAsFixed(1)}, ${bbox.y.toStringAsFixed(1)}, ${bbox.width.toStringAsFixed(1)}, ${bbox.height.toStringAsFixed(1)}',
      if (prediction != null) 'score: ${prediction.score.toStringAsFixed(3)}',
      if (match.iou != null) 'IoU: ${match.iou!.toStringAsFixed(3)}',
      if (match.reason != null) 'reason: ${match.reason}',
      'image: ${image.fileName}',
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final row in rows) Text(row)],
        ),
      ),
    );
  }
}

String _matchTypeLabelStatic(DetectionMatchType type) {
  return switch (type) {
    DetectionMatchType.truePositive => 'TP',
    DetectionMatchType.falsePositive => 'FP',
    DetectionMatchType.falseNegative => 'FN',
    DetectionMatchType.ignored => 'Ignored',
  };
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.overall});

  final OverallStats overall;

  @override
  Widget build(BuildContext context) {
    final List<_MetricItem> items = [
      _MetricItem('Images', overall.totalImages.toString()),
      _MetricItem('GT', overall.totalGt.toString()),
      _MetricItem('Pred', overall.totalPredictionsAfterThreshold.toString()),
      _MetricItem('TP', overall.totalTp.toString()),
      _MetricItem('FP', overall.totalFp.toString()),
      _MetricItem('FN', overall.totalFn.toString()),
      _MetricItem('Precision', overall.microPrecision.toStringAsFixed(3)),
      _MetricItem('Recall', overall.microRecall.toStringAsFixed(3)),
      _MetricItem('F1', overall.microF1.toStringAsFixed(3)),
      _MetricItem('Error imgs', overall.imagesWithAnyError.toString()),
    ];
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 64,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final _MetricItem item = items[index];
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  item.value,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricItem {
  const _MetricItem(this.label, this.value);

  final String label;
  final String value;
}

class _ClassStatsTable extends StatelessWidget {
  const _ClassStatsTable({required this.stats});

  final List<ClassStats> stats;

  @override
  Widget build(BuildContext context) {
    final List<ClassStats> sortedStats = [...stats]..sort(
        (ClassStats a, ClassStats b) => a.categoryId.compareTo(b.categoryId),
      );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 14,
        headingRowHeight: 32,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 36,
        columns: const [
          DataColumn(label: Text('Class')),
          DataColumn(label: Text('GT')),
          DataColumn(label: Text('TP')),
          DataColumn(label: Text('FP')),
          DataColumn(label: Text('FN')),
          DataColumn(label: Text('P')),
          DataColumn(label: Text('R')),
        ],
        rows: [
          for (final ClassStats stat in sortedStats)
            DataRow(
              cells: [
                DataCell(Text(stat.categoryName)),
                DataCell(Text(stat.gtCount.toString())),
                DataCell(Text(stat.tp.toString())),
                DataCell(Text(stat.fp.toString())),
                DataCell(Text(stat.fn.toString())),
                DataCell(Text(stat.precision.toStringAsFixed(2))),
                DataCell(Text(stat.recall.toStringAsFixed(2))),
              ],
            ),
        ],
      ),
    );
  }
}

class _SelectedImageDetails extends StatelessWidget {
  const _SelectedImageDetails({
    required this.image,
    required this.matches,
    required this.categoriesById,
    required this.selectedMatch,
  });

  final ImageRecord? image;
  final List<DetectionMatch> matches;
  final Map<int, CategoryRecord> categoriesById;
  final DetectionMatch? selectedMatch;

  @override
  Widget build(BuildContext context) {
    if (image == null) {
      return const Text('No image selected');
    }
    final int tp = matches
        .where((match) => match.type == DetectionMatchType.truePositive)
        .length;
    final int fp = matches
        .where((match) => match.type == DetectionMatchType.falsePositive)
        .length;
    final int fn = matches
        .where((match) => match.type == DetectionMatchType.falseNegative)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(image!.fileName),
        Text(
          'id ${image!.id}   ${image!.width ?? '-'} x ${image!.height ?? '-'}',
        ),
        Text('TP $tp   FP $fp   FN $fn'),
        const SizedBox(height: 12),
        if (selectedMatch != null) ...[
          Text(
            'Selected Object',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          _SelectedObjectDetails(
            image: image!,
            match: selectedMatch!,
            categoriesById: categoriesById,
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Visible Matches',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ...matches.map((DetectionMatch match) {
          final int? categoryId =
              match.categoryId ?? match.prediction?.categoryId;
          final String categoryName = categoryId == null
              ? '-'
              : categoriesById[categoryId]?.name ?? categoryId.toString();
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${_matchTypeLabel(match.type)}  $categoryName'),
            subtitle: Text(
              [
                if (match.prediction != null)
                  'score ${match.prediction!.score.toStringAsFixed(2)}',
                if (match.iou != null) 'IoU ${match.iou!.toStringAsFixed(2)}',
                if (match.reason != null) match.reason!,
              ].join('   '),
            ),
          );
        }),
      ],
    );
  }

  String _matchTypeLabel(DetectionMatchType type) {
    return switch (type) {
      DetectionMatchType.truePositive => 'TP',
      DetectionMatchType.falsePositive => 'FP',
      DetectionMatchType.falseNegative => 'FN',
      DetectionMatchType.ignored => 'Ignored',
    };
  }
}

class _ApMetricsSection extends StatelessWidget {
  const _ApMetricsSection({
    this.apEvalResult,
    this.canRunApEval = false,
    this.runningApEval = false,
    this.onRunApEval,
    this.onImportApMetrics,
    this.apEvalUnavailableReason,
  });

  final ApEvalResult? apEvalResult;
  final bool canRunApEval;
  final bool runningApEval;
  final VoidCallback? onRunApEval;
  final VoidCallback? onImportApMetrics;
  final String? apEvalUnavailableReason;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'COCO AP Metrics',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (runningApEval)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (apEvalResult != null) ...[
          _ApMetricsGrid(result: apEvalResult!),
          if (apEvalResult!.perClass.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ApPerClassTable(perClass: apEvalResult!.perClass),
          ],
        ] else ...[
          EmptyStateView(
            title: apEvalUnavailableReason == null
                ? 'No AP metrics yet'
                : 'AP evaluation unavailable',
            explanation: apEvalUnavailableReason ??
                'Run COCO AP evaluation on desktop or import AP metrics JSON to include AP in dashboards and exports.',
            actionLabel: onRunApEval == null ? null : 'Run AP evaluation',
            onAction: onRunApEval,
            icon: Icons.analytics_outlined,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Tooltip(
                message:
                    onRunApEval == null ? (apEvalUnavailableReason ?? '') : '',
                child: ElevatedButton.icon(
                  onPressed: onRunApEval,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run COCO AP evaluation'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onImportApMetrics,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import AP metrics JSON'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ApMetricsGrid extends StatelessWidget {
  const _ApMetricsGrid({required this.result});

  final ApEvalResult result;

  @override
  Widget build(BuildContext context) {
    String fmt(double? v) => v == null ? '-' : v.toStringAsFixed(3);
    final List<_MetricItem> items = [
      _MetricItem('AP@[.5:.95]', fmt(result.ap)),
      _MetricItem('AP50', fmt(result.ap50)),
      _MetricItem('AP75', fmt(result.ap75)),
      _MetricItem('APsmall', fmt(result.apSmall)),
      _MetricItem('APmedium', fmt(result.apMedium)),
      _MetricItem('APlarge', fmt(result.apLarge)),
      _MetricItem('AR1', fmt(result.ar1)),
      _MetricItem('AR10', fmt(result.ar10)),
      _MetricItem('AR100', fmt(result.ar100)),
      _MetricItem('ARsmall', fmt(result.arSmall)),
      _MetricItem('ARmedium', fmt(result.arMedium)),
      _MetricItem('ARlarge', fmt(result.arLarge)),
    ];
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 56,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final _MetricItem item = items[index];
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  item.value,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ApPerClassTable extends StatelessWidget {
  const _ApPerClassTable({required this.perClass});

  final List<ClassApMetric> perClass;

  @override
  Widget build(BuildContext context) {
    String fmt(double? v) => v == null ? '-' : v.toStringAsFixed(3);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 14,
        headingRowHeight: 32,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 36,
        columns: const [
          DataColumn(label: Text('Class')),
          DataColumn(label: Text('AP')),
          DataColumn(label: Text('AP50')),
          DataColumn(label: Text('AP75')),
          DataColumn(label: Text('AR')),
        ],
        rows: [
          for (final ClassApMetric cls in perClass)
            DataRow(
              cells: [
                DataCell(Text(cls.categoryName)),
                DataCell(Text(fmt(cls.ap))),
                DataCell(Text(fmt(cls.ap50))),
                DataCell(Text(fmt(cls.ap75))),
                DataCell(Text(fmt(cls.ar))),
              ],
            ),
        ],
      ),
    );
  }
}
