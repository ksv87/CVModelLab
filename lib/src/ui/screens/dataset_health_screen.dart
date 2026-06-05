import 'dart:typed_data';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import '../widgets/image_preview_pane.dart';
import '../widgets/responsive.dart';
import '../widgets/status_views.dart';
import '../l10n/app_locale_scope.dart';
import '../l10n/app_localizations.dart';

enum DatasetHealthUiFilter {
  all,
  errors,
  warnings,
  info,
  missingImages,
  invalidBoxes,
  classImbalance,
  tinyBoxes,
  bboxOutsideImage,
  imagesWithoutGt,
}

class DatasetHealthScreen extends StatefulWidget {
  const DatasetHealthScreen({
    required this.report,
    required this.dataset,
    required this.matchesByImageId,
    required this.loadImageBytes,
    required this.onImageSelected,
    super.key,
  });

  final DatasetHealthReport report;
  final CocoDataset dataset;
  final Map<int, List<DetectionMatch>> matchesByImageId;
  final Future<Uint8List?> Function(String fileName) loadImageBytes;
  final ValueChanged<int> onImageSelected;

  @override
  State<DatasetHealthScreen> createState() => _DatasetHealthScreenState();
}

class _DatasetHealthScreenState extends State<DatasetHealthScreen> {
  DatasetHealthUiFilter _filter = DatasetHealthUiFilter.all;
  DatasetHealthIssue? _selectedIssue;
  int? _previewImageId;

  @override
  Widget build(BuildContext context) {
    final List<DatasetHealthIssue> issues = _filteredIssues();
    final l10n = AppLocaleScope.l10n(context);
    final bool compact = context.isCompactWidth;

    final Widget emptyState = EmptyStateView(
      title: widget.report.issues.isEmpty
          ? 'No dataset health issues'
          : 'No health issues for this filter',
      explanation: widget.report.issues.isEmpty
          ? 'The loaded dataset did not trigger missing-image, invalid-box, imbalance, or annotation-quality warnings.'
          : 'The selected health filter did not match any issues. Switch back to All to review the full report.',
      actionLabel: widget.report.issues.isEmpty ? null : 'Show all issues',
      onAction: widget.report.issues.isEmpty
          ? null
          : () => setState(() => _filter = DatasetHealthUiFilter.all),
      icon: Icons.check_circle_outline,
    );

    final Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dataset Health',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        _SummaryGrid(report: widget.report),
        const SizedBox(height: 12),
        DropdownButtonFormField<DatasetHealthUiFilter>(
          initialValue: _filter,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Filter',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            for (final DatasetHealthUiFilter filter
                in DatasetHealthUiFilter.values)
              DropdownMenuItem(
                value: filter,
                child: Text(_filterLabel(filter)),
              ),
          ],
          onChanged: (DatasetHealthUiFilter? value) {
            if (value != null) {
              setState(() => _filter = value);
            }
          },
        ),
        const SizedBox(height: 12),
      ],
    );

    if (compact) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          header,
          if (issues.isEmpty)
            emptyState
          else
            for (final DatasetHealthIssue issue in issues)
              _IssueCard(
                issue: issue,
                localizations: l10n,
                onTap: () => _openIssueSheet(issue),
              ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              header,
              if (issues.isEmpty)
                emptyState
              else
                _IssueTable(
                  issues: issues,
                  selectedIssue: _selectedIssue,
                  localizations: l10n,
                  onSelected: (DatasetHealthIssue issue) {
                    setState(() {
                      _selectedIssue = issue;
                      _previewImageId = issue.imageId;
                    });
                  },
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 360,
          child: _IssueDetails(issue: _selectedIssue),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: ImagePreviewPane(
            imageId: _previewImageId,
            dataset: widget.dataset,
            matches: _previewImageId == null
                ? const <DetectionMatch>[]
                : widget.matchesByImageId[_previewImageId] ??
                    const <DetectionMatch>[],
            loadBytes: widget.loadImageBytes,
            onOpenInBrowser: widget.onImageSelected,
          ),
        ),
      ],
    );
  }

  Future<void> _openIssueSheet(DatasetHealthIssue issue) async {
    setState(() {
      _selectedIssue = issue;
      _previewImageId = issue.imageId;
    });
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(child: _IssueDetails(issue: issue)),
                if (issue.imageId != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          widget.onImageSelected(issue.imageId!);
                        },
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Open image'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<DatasetHealthIssue> _filteredIssues() {
    return [
      for (final DatasetHealthIssue issue in widget.report.issues)
        if (_matches(issue)) issue,
    ];
  }

  bool _matches(DatasetHealthIssue issue) {
    return switch (_filter) {
      DatasetHealthUiFilter.all => true,
      DatasetHealthUiFilter.errors =>
        issue.severity == DatasetIssueSeverity.error,
      DatasetHealthUiFilter.warnings =>
        issue.severity == DatasetIssueSeverity.warning,
      DatasetHealthUiFilter.info => issue.severity == DatasetIssueSeverity.info,
      DatasetHealthUiFilter.missingImages =>
        issue.type == DatasetIssueType.missingImageFile,
      DatasetHealthUiFilter.invalidBoxes =>
        issue.type == DatasetIssueType.invalidBbox,
      DatasetHealthUiFilter.classImbalance =>
        issue.type == DatasetIssueType.classImbalance ||
            issue.type == DatasetIssueType.rareClass ||
            issue.type == DatasetIssueType.classWithoutGroundTruth,
      DatasetHealthUiFilter.tinyBoxes =>
        issue.type == DatasetIssueType.tinyBbox,
      DatasetHealthUiFilter.bboxOutsideImage =>
        issue.type == DatasetIssueType.bboxOutsideImage ||
            issue.type == DatasetIssueType.bboxPartiallyOutsideImage,
      DatasetHealthUiFilter.imagesWithoutGt =>
        issue.type == DatasetIssueType.imageWithoutGroundTruth,
    };
  }

  String _filterLabel(DatasetHealthUiFilter filter) {
    return switch (filter) {
      DatasetHealthUiFilter.all => 'All',
      DatasetHealthUiFilter.errors => 'Errors',
      DatasetHealthUiFilter.warnings => 'Warnings',
      DatasetHealthUiFilter.info => 'Info',
      DatasetHealthUiFilter.missingImages => 'Missing images',
      DatasetHealthUiFilter.invalidBoxes => 'Invalid boxes',
      DatasetHealthUiFilter.classImbalance => 'Class imbalance',
      DatasetHealthUiFilter.tinyBoxes => 'Tiny boxes',
      DatasetHealthUiFilter.bboxOutsideImage => 'BBox outside image',
      DatasetHealthUiFilter.imagesWithoutGt => 'Images without GT',
    };
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.report});

  final DatasetHealthReport report;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Errors', report.errorCount),
      ('Warnings', report.warningCount),
      ('Info', report.infoCount),
      ('Missing images', report.missingImageCount),
      ('Invalid boxes', report.invalidAnnotationCount),
      ('Images without GT', report.imageWithoutGtCount),
      ('Rare classes', report.rareClassCount),
      ('Unused files', report.unusedImageFileCount),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int crossAxisCount = width < 360
            ? 2
            : width < 560
                ? 3
                : 4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 64,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
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
                      item.$1,
                      style: Theme.of(context).textTheme.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${item.$2}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _IssueTable extends StatelessWidget {
  const _IssueTable({
    required this.issues,
    required this.selectedIssue,
    required this.localizations,
    required this.onSelected,
  });

  final List<DatasetHealthIssue> issues;
  final DatasetHealthIssue? selectedIssue;
  final dynamic localizations;
  final ValueChanged<DatasetHealthIssue> onSelected;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      interactive: false,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1600),
          child: DataTable(
            headingRowHeight: 34,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 56,
            columns: const [
              DataColumn(label: Text('Severity')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Image/File')),
              DataColumn(label: Text('Class')),
              DataColumn(label: Text('Message')),
              DataColumn(label: Text('Recommendation')),
            ],
            rows: [
              for (final DatasetHealthIssue issue in issues)
                DataRow(
                  selected: identical(issue, selectedIssue),
                  onSelectChanged: (_) => onSelected(issue),
                  cells: [
                    DataCell(Text(issue.severity.name)),
                    DataCell(Text(issue.type.name)),
                    DataCell(Text(issue.fileName ?? '${issue.imageId ?? ''}')),
                    DataCell(
                      Text(issue.categoryName ?? '${issue.categoryId ?? ''}'),
                    ),
                    DataCell(
                      SizedBox(
                        width: 300,
                        child: Text(localizations.datasetIssueMessage(issue)),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 240,
                        child: Text(
                          localizations.datasetIssueRecommendation(issue) ?? '',
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({
    required this.issue,
    required this.localizations,
    required this.onTap,
  });

  final DatasetHealthIssue issue;
  final AppLocalizations localizations;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = switch (issue.severity) {
      DatasetIssueSeverity.error => scheme.error,
      DatasetIssueSeverity.warning => scheme.tertiary,
      DatasetIssueSeverity.info => scheme.primary,
    };
    final String? location = issue.fileName ??
        (issue.imageId != null ? 'image #${issue.imageId}' : null);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.circle, size: 14, color: color),
        title: Text(localizations.datasetIssueTitle(issue)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.datasetIssueMessage(issue),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (location != null)
              Text(
                location,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        isThreeLine: location != null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _IssueDetails extends StatelessWidget {
  const _IssueDetails({required this.issue});

  final DatasetHealthIssue? issue;

  @override
  Widget build(BuildContext context) {
    if (issue == null) {
      return const Center(child: Text('Select an issue'));
    }
    final DatasetHealthIssue i = issue!;
    final l10n = AppLocaleScope.l10n(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.datasetIssueTitle(i),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(l10n.datasetIssueMessage(i)),
        if (i.recommendation != null) ...[
          const SizedBox(height: 12),
          Text(
            'Recommendation',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(l10n.datasetIssueRecommendation(i) ?? i.recommendation!),
        ],
        const SizedBox(height: 12),
        Text('Details', style: Theme.of(context).textTheme.titleSmall),
        _kv('severity', i.severity.name),
        _kv('type', i.type.name),
        _kv('image_id', i.imageId),
        _kv('file_name', i.fileName),
        _kv('annotation_id', i.annotationId),
        _kv('category_id', i.categoryId),
        _kv('category_name', i.categoryName),
        for (final entry in i.details.entries) _kv(entry.key, entry.value),
      ],
    );
  }

  Widget _kv(String key, Object? value) {
    if (value == null || value == '') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text('$key: $value'),
    );
  }
}
