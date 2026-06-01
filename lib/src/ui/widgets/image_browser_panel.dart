import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

class ImageBrowserPanel extends StatelessWidget {
  const ImageBrowserPanel({
    required this.dataset,
    required this.view,
    required this.filter,
    required this.selectedImageId,
    required this.onFilterChanged,
    required this.onImageSelected,
    required this.onResetFilters,
    super.key,
  });

  final CocoDataset dataset;
  final FilteredEvalView view;
  final EvalViewFilter filter;
  final int? selectedImageId;
  final ValueChanged<EvalViewFilter> onFilterChanged;
  final ValueChanged<int> onImageSelected;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    final List<ImageRecord> images = [
      for (final int imageId in view.filteredImageIds)
        if (dataset.imagesById[imageId] != null) dataset.imagesById[imageId]!,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  Text(
                    'Error Browser',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Tooltip(
                    message: 'Reset filters',
                    child: IconButton(
                      icon: const Icon(Icons.restart_alt),
                      onPressed: onResetFilters,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<EvalImageFilter>(
                initialValue: filter.imageFilter,
                decoration: const InputDecoration(
                  labelText: 'Image filter',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final EvalImageFilter value in EvalImageFilter.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(
                        '${_imageFilterLabel(value)} (${view.filterCounts[value] ?? 0})',
                      ),
                    ),
                ],
                onChanged: (EvalImageFilter? value) {
                  if (value != null) {
                    onFilterChanged(filter.copyWith(imageFilter: value));
                  }
                },
              ),
              const SizedBox(height: 8),
              _ClassMultiSelect(
                dataset: dataset,
                selectedClassIds: filter.selectedClassIds,
                onChanged: (Set<int> selected) {
                  onFilterChanged(filter.copyWith(selectedClassIds: selected));
                },
              ),
              const SizedBox(height: 8),
              _MatchTypeChips(
                enabledMatchTypes: filter.enabledMatchTypes,
                onChanged: (Set<DetectionMatchType> selected) {
                  onFilterChanged(filter.copyWith(enabledMatchTypes: selected));
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ObjectSizeFilter>(
                initialValue: filter.objectSizeFilter,
                decoration: const InputDecoration(
                  labelText: 'Object size',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: ObjectSizeFilter.all,
                    child: Text('All sizes'),
                  ),
                  DropdownMenuItem(
                    value: ObjectSizeFilter.small,
                    child: Text('Small'),
                  ),
                  DropdownMenuItem(
                    value: ObjectSizeFilter.medium,
                    child: Text('Medium'),
                  ),
                  DropdownMenuItem(
                    value: ObjectSizeFilter.large,
                    child: Text('Large'),
                  ),
                ],
                onChanged: (ObjectSizeFilter? value) {
                  if (value != null) {
                    onFilterChanged(filter.copyWith(objectSizeFilter: value));
                  }
                },
              ),
              const SizedBox(height: 8),
              _FlagCheckboxes(filter: filter, onChanged: onFilterChanged),
              const SizedBox(height: 8),
              _FilterThreshold(
                label: 'High FP',
                value: filter.highConfidenceFpThreshold,
                onChanged: (double value) => onFilterChanged(
                  filter.copyWith(highConfidenceFpThreshold: value),
                ),
              ),
              _FilterThreshold(
                label: 'Low IoU TP',
                value: filter.lowIouTpThreshold,
                onChanged: (double value) => onFilterChanged(
                  filter.copyWith(lowIouTpThreshold: value),
                ),
              ),
              const Divider(height: 24),
              Text(
                '${images.length} / ${dataset.imagesById.length} images',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (images.isEmpty)
                const _EmptyImageList()
              else
                for (final ImageRecord image in images)
                  _ImageListTile(
                    image: image,
                    summary: view.imageSummaries[image.id],
                    selected: selectedImageId == image.id,
                    onTap: () => onImageSelected(image.id),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  static String _imageFilterLabel(EvalImageFilter value) {
    return switch (value) {
      EvalImageFilter.all => 'All images',
      EvalImageFilter.anyError => 'Any error',
      EvalImageFilter.falsePositive => 'False positives',
      EvalImageFilter.falseNegative => 'False negatives',
      EvalImageFilter.falsePositiveAndFalseNegative => 'FP and FN',
      EvalImageFilter.classConfusion => 'Class confusion',
      EvalImageFilter.highConfidenceFalsePositive => 'High confidence FP',
      EvalImageFilter.lowIouTruePositive => 'Low IoU TP',
      EvalImageFilter.smallObjects => 'Small objects',
      EvalImageFilter.missingImages => 'Missing images',
    };
  }
}

class _ClassMultiSelect extends StatelessWidget {
  const _ClassMultiSelect({
    required this.dataset,
    required this.selectedClassIds,
    required this.onChanged,
  });

  final CocoDataset dataset;
  final Set<int> selectedClassIds;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final categories = dataset.categoriesById.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final bool noClassesSelected = selectedClassIds.contains(-1);
    final String title = selectedClassIds.isEmpty
        ? 'All classes'
        : (noClassesSelected
            ? '0 selected'
            : '${selectedClassIds.length} selected');
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text('Classes: $title'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => onChanged(<int>{}),
                  child: const Text('Select all'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => onChanged(<int>{-1}),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final category in categories)
                  CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: selectedClassIds.isEmpty
                        ? true
                        : selectedClassIds.contains(category.id),
                    title: Text(category.name),
                    onChanged: (bool? value) {
                      final bool checked = value ?? false;
                      final Set<int> next = selectedClassIds.isEmpty
                          ? categories.map((category) => category.id).toSet()
                          : {...selectedClassIds};
                      next.remove(-1);
                      if (checked) {
                        next.add(category.id);
                      } else {
                        next.remove(category.id);
                      }
                      if (next.length == categories.length) {
                        onChanged(<int>{});
                      } else {
                        onChanged(next);
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchTypeChips extends StatelessWidget {
  const _MatchTypeChips({
    required this.enabledMatchTypes,
    required this.onChanged,
  });

  final Set<DetectionMatchType> enabledMatchTypes;
  final ValueChanged<Set<DetectionMatchType>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _chip(DetectionMatchType.truePositive, 'TP'),
        _chip(DetectionMatchType.falsePositive, 'FP'),
        _chip(DetectionMatchType.falseNegative, 'FN'),
      ],
    );
  }

  Widget _chip(DetectionMatchType type, String label) {
    return FilterChip(
      label: Text(label),
      selected: enabledMatchTypes.contains(type),
      onSelected: (bool selected) {
        final Set<DetectionMatchType> next = {...enabledMatchTypes};
        if (selected) {
          next.add(type);
        } else {
          next.remove(type);
        }
        onChanged(next);
      },
    );
  }
}

class _FlagCheckboxes extends StatelessWidget {
  const _FlagCheckboxes({required this.filter, required this.onChanged});

  final EvalViewFilter filter;
  final ValueChanged<EvalViewFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Only images with errors'),
          value: filter.onlyImagesWithErrors,
          onChanged: (bool? value) => onChanged(
            filter.copyWith(onlyImagesWithErrors: value ?? false),
          ),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Only class confusion'),
          value: filter.onlyImagesWithClassConfusion,
          onChanged: (bool? value) => onChanged(
            filter.copyWith(onlyImagesWithClassConfusion: value ?? false),
          ),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Only missing images'),
          value: filter.onlyMissingImages,
          onChanged: (bool? value) => onChanged(
            filter.copyWith(onlyMissingImages: value ?? false),
          ),
        ),
      ],
    );
  }
}

class _FilterThreshold extends StatelessWidget {
  const _FilterThreshold({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 1,
            divisions: 20,
            label: value.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 40, child: Text(value.toStringAsFixed(2))),
      ],
    );
  }
}

class _ImageListTile extends StatelessWidget {
  const _ImageListTile({
    required this.image,
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  final ImageRecord image;
  final FilteredImageSummary? summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasError = summary?.hasError ?? false;
    return ListTile(
      selected: selected,
      dense: true,
      leading: SizedBox(
        width: 44,
        height: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            summary?.isMissingImage ?? false
                ? Icons.broken_image_outlined
                : Icons.image_outlined,
            size: 20,
          ),
        ),
      ),
      title: Text(image.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          _Badge('TP ${summary?.tp ?? 0}'),
          _Badge('FP ${summary?.fp ?? 0}', active: (summary?.fp ?? 0) > 0),
          _Badge('FN ${summary?.fn ?? 0}', active: (summary?.fn ?? 0) > 0),
          if (hasError) const _Badge('error', active: true),
          if (summary?.isMissingImage ?? false)
            const _Badge('missing', active: true),
          if (summary?.hasClassConfusion ?? false)
            const _Badge('confusion', active: true),
          if (summary?.hasSmallObject ?? false) const _Badge('small'),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

class _EmptyImageList extends StatelessWidget {
  const _EmptyImageList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No images match the active filters.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
