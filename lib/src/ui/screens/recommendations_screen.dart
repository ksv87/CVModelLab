import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import '../l10n/app_locale_scope.dart';
import '../widgets/responsive.dart';
import '../widgets/status_views.dart';

enum RecommendationUiFilter {
  all,
  critical,
  warnings,
  info,
  dataset,
  model,
  classes,
  comparison,
}

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({
    required this.recommendations,
    required this.dataset,
    required this.onImageSelected,
    required this.onCategorySelected,
    super.key,
  });

  final List<Recommendation> recommendations;
  final CocoDataset dataset;
  final ValueChanged<int> onImageSelected;
  final ValueChanged<int> onCategorySelected;

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  RecommendationUiFilter _filter = RecommendationUiFilter.all;
  Recommendation? _selected;

  @override
  Widget build(BuildContext context) {
    final List<Recommendation> recommendations = _filtered();
    final bool compact = context.isCompactWidth;
    final Widget list = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recommendations',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<RecommendationUiFilter>(
                initialValue: _filter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Filter',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final RecommendationUiFilter filter
                      in RecommendationUiFilter.values)
                    DropdownMenuItem(
                      value: filter,
                      child: Text(_filterLabel(filter)),
                    ),
                ],
                onChanged: (RecommendationUiFilter? value) {
                  if (value != null) {
                    setState(() => _filter = value);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
              _SummaryRow(recommendations: widget.recommendations),
              const SizedBox(height: 12),
              if (recommendations.isEmpty)
                EmptyStateView(
                  title: widget.recommendations.isEmpty
                      ? 'No recommendations'
                      : 'No recommendations for this filter',
                  explanation: widget.recommendations.isEmpty
                      ? 'The rule-based checks did not find actionable dataset or model issues for the current run.'
                      : 'The selected recommendation filter has no matches. Switch back to All to review the available advice.',
                  actionLabel:
                      widget.recommendations.isEmpty ? null : 'Show all',
                  onAction: widget.recommendations.isEmpty
                      ? null
                      : () =>
                          setState(() => _filter = RecommendationUiFilter.all),
                  icon: Icons.tips_and_updates_outlined,
                )
              else
                for (final Recommendation recommendation in recommendations)
                  _RecommendationCard(
                    recommendation: recommendation,
                    dataset: widget.dataset,
                    selected: identical(_selected, recommendation),
                    onTap: compact
                        ? () => _openRecommendationSheet(recommendation)
                        : () => setState(() => _selected = recommendation),
                    onOpenImage: recommendation.relatedImageIds.isEmpty
                        ? null
                        : () => widget.onImageSelected(
                              recommendation.relatedImageIds.first,
                            ),
                    onApplyClass: recommendation.relatedCategoryIds.isEmpty
                        ? null
                        : () => widget.onCategorySelected(
                              recommendation.relatedCategoryIds.first,
                            ),
                  ),
      ],
    );

    if (compact) {
      return list;
    }

    return Row(
      children: [
        Expanded(flex: 3, child: list),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 380,
          child: _RecommendationDetails(
            recommendation: _selected,
            dataset: widget.dataset,
            onOpenImage: _selected?.relatedImageIds.isEmpty == false
                ? () => widget.onImageSelected(_selected!.relatedImageIds.first)
                : null,
            onApplyClass: _selected?.relatedCategoryIds.isEmpty == false
                ? () => widget.onCategorySelected(
                      _selected!.relatedCategoryIds.first,
                    )
                : null,
          ),
        ),
      ],
    );
  }

  Future<void> _openRecommendationSheet(Recommendation recommendation) async {
    setState(() => _selected = recommendation);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
            ),
            child: _RecommendationDetails(
              recommendation: recommendation,
              dataset: widget.dataset,
              onOpenImage: recommendation.relatedImageIds.isEmpty
                  ? null
                  : () {
                      Navigator.of(sheetContext).pop();
                      widget.onImageSelected(
                        recommendation.relatedImageIds.first,
                      );
                    },
              onApplyClass: recommendation.relatedCategoryIds.isEmpty
                  ? null
                  : () {
                      Navigator.of(sheetContext).pop();
                      widget.onCategorySelected(
                        recommendation.relatedCategoryIds.first,
                      );
                    },
            ),
          ),
        );
      },
    );
  }

  List<Recommendation> _filtered() {
    return [
      for (final Recommendation recommendation in widget.recommendations)
        if (_matches(recommendation)) recommendation,
    ];
  }

  bool _matches(Recommendation recommendation) {
    return switch (_filter) {
      RecommendationUiFilter.all => true,
      RecommendationUiFilter.critical =>
        recommendation.severity == RecommendationSeverity.critical,
      RecommendationUiFilter.warnings =>
        recommendation.severity == RecommendationSeverity.warning,
      RecommendationUiFilter.info =>
        recommendation.severity == RecommendationSeverity.info,
      RecommendationUiFilter.dataset => recommendation.category ==
              RecommendationCategory.datasetHealth ||
          recommendation.category == RecommendationCategory.annotationQuality ||
          recommendation.category == RecommendationCategory.classImbalance,
      RecommendationUiFilter.model =>
        recommendation.category == RecommendationCategory.falsePositives ||
            recommendation.category == RecommendationCategory.falseNegatives ||
            recommendation.category == RecommendationCategory.smallObjects ||
            recommendation.category == RecommendationCategory.classConfusion ||
            recommendation.category == RecommendationCategory.thresholds ||
            recommendation.category == RecommendationCategory.scoreCalibration,
      RecommendationUiFilter.classes =>
        recommendation.relatedCategoryIds.isNotEmpty,
      RecommendationUiFilter.comparison =>
        recommendation.category == RecommendationCategory.modelComparison,
    };
  }

  String _filterLabel(RecommendationUiFilter filter) {
    return switch (filter) {
      RecommendationUiFilter.all => 'All',
      RecommendationUiFilter.critical => 'Critical',
      RecommendationUiFilter.warnings => 'Warnings',
      RecommendationUiFilter.info => 'Info',
      RecommendationUiFilter.dataset => 'Dataset',
      RecommendationUiFilter.model => 'Model',
      RecommendationUiFilter.classes => 'Classes',
      RecommendationUiFilter.comparison => 'Comparison',
    };
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.recommendations});

  final List<Recommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    int count(RecommendationSeverity severity) => recommendations
        .where((Recommendation r) => r.severity == severity)
        .length;
    final items = [
      ('Critical', count(RecommendationSeverity.critical)),
      ('Warnings', count(RecommendationSeverity.warning)),
      ('Info', count(RecommendationSeverity.info)),
      ('Total', recommendations.length),
    ];
    return Row(
      children: [
        for (final item in items) ...[
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$1,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Text(
                      '${item.$2}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.dataset,
    required this.selected,
    required this.onTap,
    required this.onOpenImage,
    required this.onApplyClass,
  });

  final Recommendation recommendation;
  final CocoDataset dataset;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onOpenImage;
  final VoidCallback? onApplyClass;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocaleScope.l10n(context);
    return Card(
      elevation: selected ? 3 : 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _SeverityChip(severity: recommendation.severity),
                  Chip(
                    label: Text(
                      l10n.recommendationCategory(recommendation.category),
                    ),
                  ),
                  if (recommendation.relatedCategoryIds.isNotEmpty)
                    Chip(
                      label: Text(
                        'Classes: ${_classNames(dataset, recommendation.relatedCategoryIds)}',
                      ),
                    ),
                  if (recommendation.relatedImageIds.isNotEmpty)
                    Chip(
                      label: Text(
                        '${recommendation.relatedImageIds.length} images',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.recommendationTitle(recommendation),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(l10n.recommendationMessage(recommendation)),
              const SizedBox(height: 8),
              Text(
                l10n.recommendationAction(recommendation),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Open images'),
                    onPressed: onOpenImage,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.category),
                    label: const Text('Filter class'),
                    onPressed: onApplyClass,
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

class _RecommendationDetails extends StatelessWidget {
  const _RecommendationDetails({
    required this.recommendation,
    required this.dataset,
    required this.onOpenImage,
    required this.onApplyClass,
  });

  final Recommendation? recommendation;
  final CocoDataset dataset;
  final VoidCallback? onOpenImage;
  final VoidCallback? onApplyClass;

  @override
  Widget build(BuildContext context) {
    final Recommendation? r = recommendation;
    if (r == null) {
      return const Center(child: Text('Select a recommendation.'));
    }
    final l10n = AppLocaleScope.l10n(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SeverityChip(severity: r.severity),
        const SizedBox(height: 12),
        Text(
          l10n.recommendationTitle(r),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(l10n.recommendationMessage(r)),
        const SizedBox(height: 16),
        Text('Action', style: Theme.of(context).textTheme.titleSmall),
        Text(l10n.recommendationAction(r)),
        const SizedBox(height: 16),
        Text('Related classes', style: Theme.of(context).textTheme.titleSmall),
        Text(_classNames(dataset, r.relatedCategoryIds).ifEmpty('-')),
        const SizedBox(height: 12),
        Text('Related images', style: Theme.of(context).textTheme.titleSmall),
        Text(
          r.relatedImageIds.isEmpty
              ? '-'
              : r.relatedImageIds.take(30).join(', '),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Open first image'),
              onPressed: onOpenImage,
            ),
            FilledButton.icon(
              icon: const Icon(Icons.category),
              label: const Text('Apply class filter'),
              onPressed: onApplyClass,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Evidence', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final MapEntry<String, Object?> entry in r.evidence.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${entry.key}: ${entry.value}'),
          ),
      ],
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity});

  final RecommendationSeverity severity;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (severity) {
      RecommendationSeverity.critical => Colors.red.shade700,
      RecommendationSeverity.warning => Colors.orange.shade800,
      RecommendationSeverity.info => Colors.blue.shade700,
    };
    return Chip(
      label: Text(AppLocaleScope.l10n(context).severity(severity)),
      labelStyle: const TextStyle(color: Colors.white),
      backgroundColor: color,
    );
  }
}

String _classNames(CocoDataset dataset, List<int> ids) {
  return ids
      .map((int id) => dataset.categoriesById[id]?.name ?? '$id')
      .join(', ');
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
