import 'dart:typed_data';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import '../widgets/image_preview_pane.dart';
import '../widgets/status_views.dart';

class WorstCasesScreen extends StatefulWidget {
  const WorstCasesScreen({
    required this.result,
    required this.dataset,
    required this.matchesByImageId,
    required this.loadImageBytes,
    required this.onImageSelected,
    required this.onExportAnnotated,
    super.key,
  });

  final WorstCasesResult result;
  final CocoDataset dataset;
  final Map<int, List<DetectionMatch>> matchesByImageId;
  final Future<Uint8List?> Function(String fileName) loadImageBytes;
  final ValueChanged<int> onImageSelected;
  final ValueChanged<List<int>> onExportAnnotated;

  @override
  State<WorstCasesScreen> createState() => _WorstCasesScreenState();
}

class _WorstCasesScreenState extends State<WorstCasesScreen>
    with SingleTickerProviderStateMixin {
  int _topN = 20;
  int? _previewImageId;
  Set<DetectionMatchType> _focusTypes = const {};
  DetectionMatch? _focusMatch;

  @override
  Widget build(BuildContext context) {
    final categories = widget.result.categories
        .where((group) => group.items.isNotEmpty)
        .toList();
    if (categories.isEmpty) {
      return const EmptyStateView(
        title: 'No worst cases found',
        explanation:
            'The current model run does not have ranked FP/FN/confusion examples for the active thresholds.',
        icon: Icons.task_alt,
      );
    }
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: DefaultTabController(
            length: categories.length,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'Worst Cases',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      DropdownButton<int>(
                        value: _topN,
                        items: const [
                          DropdownMenuItem(value: 20, child: Text('Top 20')),
                          DropdownMenuItem(value: 50, child: Text('Top 50')),
                          DropdownMenuItem(value: 100, child: Text('Top 100')),
                          DropdownMenuItem(value: 0, child: Text('All')),
                        ],
                        onChanged: (int? value) {
                          if (value != null) {
                            setState(() => _topN = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  tabs: [
                    for (final group in categories)
                      Tab(text: '${group.label} (${group.items.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final group in categories)
                        _WorstCaseList(
                          label: group.label,
                          categoryKey: group.key,
                          items: _limit(group.items),
                          selectedImageId: _previewImageId,
                          onPreview: _selectPreview,
                          onExportAnnotated: widget.onExportAnnotated,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
            focusMatchTypes: _focusTypes,
            focusMatch: _focusMatch,
            onOpenInBrowser: widget.onImageSelected,
          ),
        ),
      ],
    );
  }

  void _selectPreview(WorstCaseItem item, String categoryKey) {
    final List<DetectionMatch> matches =
        widget.matchesByImageId[item.imageId] ?? const <DetectionMatch>[];
    setState(() {
      _previewImageId = item.imageId;
      _focusTypes = _focusTypesFor(categoryKey);
      _focusMatch = _focusMatchFor(categoryKey, matches);
    });
  }

  Set<DetectionMatchType> _focusTypesFor(String categoryKey) {
    return switch (categoryKey) {
      'most_fp' || 'high_conf_fp' || 'no_gt_with_pred' => const {
          DetectionMatchType.falsePositive,
        },
      'most_fn' || 'gt_no_pred' || 'small_missed' => const {
          DetectionMatchType.falseNegative,
        },
      'low_iou_tp' => const {DetectionMatchType.truePositive},
      _ => const {
          DetectionMatchType.falsePositive,
          DetectionMatchType.falseNegative,
        },
    };
  }

  DetectionMatch? _focusMatchFor(
    String categoryKey,
    List<DetectionMatch> matches,
  ) {
    Iterable<DetectionMatch> ofType(DetectionMatchType type) =>
        matches.where((DetectionMatch m) => m.type == type);

    DetectionMatch? maxByScore(Iterable<DetectionMatch> items) {
      DetectionMatch? best;
      for (final DetectionMatch m in items) {
        if (m.prediction == null) {
          continue;
        }
        if (best == null || m.prediction!.score > best.prediction!.score) {
          best = m;
        }
      }
      return best;
    }

    DetectionMatch? minByIou(Iterable<DetectionMatch> items) {
      DetectionMatch? best;
      for (final DetectionMatch m in items) {
        if (m.iou == null) {
          continue;
        }
        if (best == null || m.iou! < best.iou!) {
          best = m;
        }
      }
      return best ?? (items.isEmpty ? null : items.first);
    }

    DetectionMatch? smallestGt(Iterable<DetectionMatch> items) {
      DetectionMatch? best;
      for (final DetectionMatch m in items) {
        if (m.groundTruth == null) {
          continue;
        }
        if (best == null ||
            m.groundTruth!.effectiveArea < best.groundTruth!.effectiveArea) {
          best = m;
        }
      }
      return best ?? (items.isEmpty ? null : items.first);
    }

    DetectionMatch? firstOrNull(Iterable<DetectionMatch> items) =>
        items.isEmpty ? null : items.first;

    switch (categoryKey) {
      case 'high_conf_fp':
      case 'most_fp':
      case 'no_gt_with_pred':
        return maxByScore(ofType(DetectionMatchType.falsePositive));
      case 'low_iou_tp':
        return minByIou(ofType(DetectionMatchType.truePositive));
      case 'most_fn':
      case 'gt_no_pred':
        return firstOrNull(ofType(DetectionMatchType.falseNegative));
      case 'small_missed':
        return smallestGt(ofType(DetectionMatchType.falseNegative));
      default:
        return maxByScore(ofType(DetectionMatchType.falsePositive)) ??
            firstOrNull(ofType(DetectionMatchType.falseNegative));
    }
  }

  List<WorstCaseItem> _limit(List<WorstCaseItem> items) {
    if (_topN <= 0 || items.length <= _topN) {
      return items;
    }
    return items.take(_topN).toList();
  }
}

class _WorstCaseList extends StatelessWidget {
  const _WorstCaseList({
    required this.label,
    required this.categoryKey,
    required this.items,
    required this.selectedImageId,
    required this.onPreview,
    required this.onExportAnnotated,
  });

  final String label;
  final String categoryKey;
  final List<WorstCaseItem> items;
  final int? selectedImageId;
  final void Function(WorstCaseItem item, String categoryKey) onPreview;
  final ValueChanged<List<int>> onExportAnnotated;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: const Icon(Icons.image),
              label: const Text('Export annotated'),
              onPressed: items.isEmpty
                  ? null
                  : () => onExportAnnotated(
                        [for (final WorstCaseItem item in items) item.imageId],
                      ),
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? EmptyStateView(
                  title: 'No worst cases for $label',
                  explanation:
                      'This category has no examples under the current thresholds. Try another category or adjust thresholds.',
                  icon: Icons.filter_alt_off,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final WorstCaseItem item = items[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      selected: selectedImageId == item.imageId,
                      title: Text(item.fileName),
                      subtitle: Text(
                        [
                          item.reason,
                          'TP ${item.tp}',
                          'FP ${item.fp}',
                          'FN ${item.fn}',
                          if (item.score != null)
                            'score ${item.score!.toStringAsFixed(2)}',
                          if (item.iou != null)
                            'IoU ${item.iou!.toStringAsFixed(2)}',
                        ].join('  |  '),
                      ),
                      trailing: Text(item.severityScore.toStringAsFixed(2)),
                      onTap: () => onPreview(item, categoryKey),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
