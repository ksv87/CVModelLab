import 'dart:typed_data';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../platform_io/image_source.dart';

class ImageBrowserPanel extends StatefulWidget {
  const ImageBrowserPanel({
    required this.dataset,
    required this.view,
    required this.filter,
    required this.selectedImageId,
    required this.onFilterChanged,
    required this.onImageSelected,
    required this.onResetFilters,
    this.thumbnailCache,
    this.projectId,
    this.imageSource,
    this.showFilters = true,
    this.scrollToSelectedRequest = 0,
    super.key,
  });

  final CocoDataset dataset;
  final FilteredEvalView view;
  final EvalViewFilter filter;
  final int? selectedImageId;
  final ValueChanged<EvalViewFilter> onFilterChanged;
  final ValueChanged<int> onImageSelected;
  final VoidCallback onResetFilters;
  final ThumbnailCache? thumbnailCache;
  final String? projectId;
  final ImageSource? imageSource;

  /// When false, the inline filter controls are omitted (used on compact
  /// layouts where filters live in a bottom sheet instead).
  final bool showFilters;

  /// Monotonic request counter used by parent screens to distinguish external
  /// navigation into the browser from ordinary list selection.
  final int scrollToSelectedRequest;

  @override
  State<ImageBrowserPanel> createState() => _ImageBrowserPanelState();
}

class _ImageBrowserPanelState extends State<ImageBrowserPanel> {
  static const double _estimatedTileExtent = 76;

  late final ScrollController _scrollController;
  final Map<int, GlobalKey> _tileKeys = <int, GlobalKey>{};
  int _lastHandledScrollRequest = 0;
  int _scrollRetryGeneration = 0;

  /// Whether the inline (desktop/wide) filter section is expanded. Collapsed by
  /// default so the image list gets most of the panel height.
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    if (widget.scrollToSelectedRequest > 0) {
      _scheduleScrollSelectedIntoView(widget.scrollToSelectedRequest);
    }
  }

  @override
  void didUpdateWidget(covariant ImageBrowserPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll only when a parent explicitly bumps the request counter
    // (external navigation, or returning from the full-screen mobile viewer).
    // Ordinary selection never moves the list, so neither desktop nor mobile
    // jumps unexpectedly.
    if (widget.scrollToSelectedRequest != oldWidget.scrollToSelectedRequest) {
      _scheduleScrollSelectedIntoView(widget.scrollToSelectedRequest);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollSelectedIntoView(int scrollRequest) {
    final int generation = ++_scrollRetryGeneration;
    void attempt(int remaining) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _scrollRetryGeneration) {
          return;
        }
        // Converge over a few frames: each pass anchors on the nearest laid-out
        // tile and jumps closer until the target tile is built and centered.
        if (_scrollSelectedIntoView(scrollRequest) || remaining <= 0) {
          return;
        }
        attempt(remaining - 1);
      });
    }

    attempt(6);
  }

  /// Centers the selected image in the list. Returns `true` once the request is
  /// fully handled, or `false` if it should be retried on the next frame.
  bool _scrollSelectedIntoView(int scrollRequest) {
    if (scrollRequest <= _lastHandledScrollRequest) {
      return true;
    }
    final int? selectedImageId = widget.selectedImageId;
    if (selectedImageId == null || !_scrollController.hasClients) {
      return false;
    }
    final List<int> ids = widget.view.filteredImageIds;
    final int index = ids.indexOf(selectedImageId);
    if (index < 0) {
      return false;
    }

    // The target tile is laid out: center it precisely and finish.
    final BuildContext? tileContext =
        _tileKeys[selectedImageId]?.currentContext;
    if (tileContext != null) {
      _lastHandledScrollRequest = scrollRequest;
      Scrollable.ensureVisible(
        tileContext,
        alignment: 0.5,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
      return true;
    }

    final ScrollPosition position = _scrollController.position;
    if (position.maxScrollExtent <= position.minScrollExtent) {
      return false;
    }

    // The target is outside the build cache. Extrapolate its offset from the
    // nearest laid-out tile (its real offset + measured row height) rather than
    // a constant from the top: anchoring on a nearby tile keeps the error
    // bounded and shrinking as we step closer, avoiding the systematic
    // overshoot of a fixed estimate. After the jump the tile builds, so the
    // next pass centers it exactly.
    final Map<int, int> indexById = <int, int>{
      for (int i = 0; i < ids.length; i++) ids[i]: i,
    };
    final _TileAnchor anchor = _nearestTileAnchor(indexById, index);
    final double target = (anchor.offset +
            (index - anchor.index) * anchor.extent -
            position.viewportDimension / 2 +
            anchor.extent / 2)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((position.pixels - target).abs() < 1) {
      // As close as the estimate allows but the tile is still not built; stop
      // to avoid churn (the list is at least near the target).
      return false;
    }
    _scrollController.jumpTo(target);
    return false;
  }

  /// Finds the laid-out tile closest to [targetIndex] and returns its real
  /// scroll offset and measured row height. Falls back to a constant estimate
  /// from the top when no tile is laid out yet.
  _TileAnchor _nearestTileAnchor(Map<int, int> indexById, int targetIndex) {
    int? bestIndex;
    RenderBox? bestBox;
    // Only a handful of tiles are actually laid out; resolving their index via
    // the precomputed map keeps this O(N) instead of O(N^2) (an `indexOf` per
    // key), which previously froze the list for large datasets.
    _tileKeys.forEach((int imageId, GlobalKey key) {
      final RenderObject? object = key.currentContext?.findRenderObject();
      if (object is! RenderBox || !object.hasSize) {
        return;
      }
      final int? tileIndex = indexById[imageId];
      if (tileIndex == null) {
        return;
      }
      if (bestIndex == null ||
          (tileIndex - targetIndex).abs() <
              (bestIndex! - targetIndex).abs()) {
        bestIndex = tileIndex;
        bestBox = object;
      }
    });
    final RenderBox? box = bestBox;
    final int? anchorIndex = bestIndex;
    if (box == null || anchorIndex == null) {
      return const _TileAnchor(index: 0, offset: 0, extent: _estimatedTileExtent);
    }
    final double offset =
        RenderAbstractViewport.of(box).getOffsetToReveal(box, 0.0).offset;
    final double extent =
        box.size.height > 0 ? box.size.height : _estimatedTileExtent;
    return _TileAnchor(index: anchorIndex, offset: offset, extent: extent);
  }

  @override
  Widget build(BuildContext context) {
    final List<ImageRecord> images = [
      for (final int imageId in widget.view.filteredImageIds)
        if (widget.dataset.imagesById[imageId] != null)
          widget.dataset.imagesById[imageId]!,
    ];
    final Set<int> visibleImageIds =
        images.map((ImageRecord i) => i.id).toSet();
    _tileKeys
        .removeWhere((int imageId, _) => !visibleImageIds.contains(imageId));
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // On compact layouts the header, count and filter access live in the
            // surrounding tab, so the panel renders only the list to avoid
            // duplicated chrome.
            if (widget.showFilters) ...[
              _BrowserHeader(onResetFilters: widget.onResetFilters),
              _FiltersToggle(
                expanded: _filtersExpanded,
                onToggle: () =>
                    setState(() => _filtersExpanded = !_filtersExpanded),
              ),
              if (_filtersExpanded)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: _filterMaxHeight(constraints),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: ImageBrowserFilters(
                      dataset: widget.dataset,
                      view: widget.view,
                      filter: widget.filter,
                      onFilterChanged: widget.onFilterChanged,
                    ),
                  ),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Text(
                  '${images.length} / '
                  '${widget.dataset.imagesById.length} images',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            Expanded(child: _buildImageList(images)),
          ],
        );
      },
    );
  }

  /// Max height of the expanded filter section: capped so the image list always
  /// keeps a healthy share of the panel and the filters scroll internally if
  /// they do not fit.
  double _filterMaxHeight(BoxConstraints constraints) {
    if (!constraints.maxHeight.isFinite) {
      return 460;
    }
    return (constraints.maxHeight * 0.6).clamp(200, 560);
  }

  Widget _buildImageList(List<ImageRecord> images) {
    final PageStorageKey<String> storageKey = PageStorageKey<String>(
      'image-browser-list-${widget.projectId ?? 'project'}-'
      '${widget.showFilters ? 'filters' : 'compact'}',
    );
    if (images.isEmpty) {
      return ListView(
        key: storageKey,
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: const [_EmptyImageList()],
      );
    }
    // `ListView.builder` keeps large datasets responsive: only the visible
    // tiles are constructed, so switching to / selecting in the browser stays
    // fast instead of building every row up front.
    return ListView.builder(
      key: storageKey,
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: images.length,
      itemBuilder: (BuildContext context, int index) {
        final ImageRecord image = images[index];
        return _ImageListTile(
          key: _tileKeys.putIfAbsent(
            image.id,
            () => GlobalKey(debugLabel: 'image-browser-${image.id}'),
          ),
          image: image,
          summary: widget.view.imageSummaries[image.id],
          selected: widget.selectedImageId == image.id,
          thumbnailCache: widget.thumbnailCache,
          projectId: widget.projectId,
          imageSource: widget.imageSource,
          onTap: () => widget.onImageSelected(image.id),
        );
      },
    );
  }
}

class _BrowserHeader extends StatelessWidget {
  const _BrowserHeader({required this.onResetFilters});

  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Text(
            'Error Browser',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          Tooltip(
            message: 'Reset filters',
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onResetFilters,
            ),
          ),
        ],
      ),
    );
  }
}

/// A laid-out list tile used as a reference point to extrapolate the scroll
/// offset of an off-screen target tile.
class _TileAnchor {
  const _TileAnchor({
    required this.index,
    required this.offset,
    required this.extent,
  });

  final int index;
  final double offset;
  final double extent;
}

class _FiltersToggle extends StatelessWidget {
  const _FiltersToggle({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Row(
          children: [
            const Icon(Icons.filter_list, size: 20),
            const SizedBox(width: 8),
            Text('Filters', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 20),
          ],
        ),
      ),
    );
  }
}

String _imageFilterLabel(EvalImageFilter value) {
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

/// The reusable set of Error Browser filter controls. Rendered inline in the
/// desktop [ImageBrowserPanel] and inside a bottom sheet on compact layouts.
class ImageBrowserFilters extends StatelessWidget {
  const ImageBrowserFilters({
    required this.dataset,
    required this.view,
    required this.filter,
    required this.onFilterChanged,
    super.key,
  });

  final CocoDataset dataset;
  final FilteredEvalView view;
  final EvalViewFilter filter;
  final ValueChanged<EvalViewFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<EvalImageFilter>(
          initialValue: filter.imageFilter,
          isExpanded: true,
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
                  '${_imageFilterLabel(value)} '
                  '(${view.filterCounts[value] ?? 0})',
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
          isExpanded: true,
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
      ],
    );
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
    this.thumbnailCache,
    this.projectId,
    this.imageSource,
    super.key,
  });

  final ImageRecord image;
  final FilteredImageSummary? summary;
  final bool selected;
  final VoidCallback onTap;
  final ThumbnailCache? thumbnailCache;
  final String? projectId;
  final ImageSource? imageSource;

  @override
  Widget build(BuildContext context) {
    final bool hasError = summary?.hasError ?? false;
    return ListTile(
      selected: selected,
      dense: true,
      leading: SizedBox(
        width: 44,
        height: 44,
        child: _ThumbnailBox(
          image: image,
          missing: summary?.isMissingImage ?? false,
          thumbnailCache: thumbnailCache,
          projectId: projectId,
          imageSource: imageSource,
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

class _ThumbnailBox extends StatefulWidget {
  const _ThumbnailBox({
    required this.image,
    required this.missing,
    required this.thumbnailCache,
    required this.projectId,
    required this.imageSource,
  });

  final ImageRecord image;
  final bool missing;
  final ThumbnailCache? thumbnailCache;
  final String? projectId;
  final ImageSource? imageSource;

  @override
  State<_ThumbnailBox> createState() => _ThumbnailBoxState();
}

class _ThumbnailBoxState extends State<_ThumbnailBox> {
  static const int _maxSize = 96;

  // Already-cached bytes available synchronously: rendered immediately so
  // scrolling never flashes a placeholder for a thumbnail we already have.
  Uint8List? _immediate;
  // The async load, started lazily (and only once the list is not being flung /
  // scrollbar-dragged fast) and then kept, so unrelated rebuilds do not recreate
  // it and flip the FutureBuilder back to its loading placeholder.
  Future<Uint8List?>? _thumbnail;
  bool _canLoad = false;
  bool _deferralScheduled = false;

  @override
  void initState() {
    super.initState();
    _resolveThumbnail();
  }

  @override
  void didUpdateWidget(covariant _ThumbnailBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.id != widget.image.id ||
        oldWidget.image.fileName != widget.image.fileName ||
        oldWidget.missing != widget.missing ||
        oldWidget.projectId != widget.projectId ||
        !identical(oldWidget.thumbnailCache, widget.thumbnailCache) ||
        !identical(oldWidget.imageSource, widget.imageSource)) {
      _resolveThumbnail();
    }
  }

  void _resolveThumbnail() {
    final ThumbnailCache? cache = widget.thumbnailCache;
    final ImageSource? source = widget.imageSource;
    final String? id = widget.projectId;
    _canLoad =
        !widget.missing && cache != null && source != null && id != null;
    _thumbnail = null;
    if (!_canLoad) {
      _immediate = null;
      return;
    }
    // A synchronous cache hit can be shown right away, no deferral needed.
    _immediate = ThumbnailService(cache: cache!).peekThumbnail(
      projectId: id!,
      imageId: widget.image.id,
      fileName: widget.image.fileName,
      maxSize: _maxSize,
    );
  }

  Future<Uint8List?> _startLoad() {
    final ThumbnailCache cache = widget.thumbnailCache!;
    final ImageSource source = widget.imageSource!;
    final String id = widget.projectId!;
    return ThumbnailService(cache: cache).getOrCreateThumbnail(
      projectId: id,
      imageId: widget.image.id,
      fileName: widget.image.fileName,
      loadImageBytes: () => source.readImageBytes(widget.image.fileName),
      maxSize: _maxSize,
    );
  }

  // Re-evaluate on the next frame while loading is deferred; scrolling keeps
  // producing frames, so once it slows enough the load starts on its own.
  void _scheduleDeferredRetry() {
    if (_deferralScheduled) {
      return;
    }
    _deferralScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deferralScheduled = false;
      if (mounted && _immediate == null && _thumbnail == null) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? immediate = _immediate;
    if (immediate != null) {
      return _image(context, immediate);
    }
    Future<Uint8List?>? thumbnail = _thumbnail;
    if (thumbnail == null && _canLoad) {
      // Defer the (potentially expensive) byte load while the list is being
      // flung or the scrollbar dragged fast, so we do not kick off thousands of
      // image reads for tiles that are only swept past. This is exactly why
      // wheel scrolling was smooth but dragging the scrollbar was not.
      if (Scrollable.recommendDeferredLoadingForContext(context)) {
        _scheduleDeferredRetry();
        return _placeholder(context);
      }
      thumbnail = _thumbnail = _startLoad();
    }
    if (thumbnail == null) {
      return _placeholder(context, missing: widget.missing);
    }
    return FutureBuilder<Uint8List?>(
      future: thumbnail,
      builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
        final Uint8List? bytes = snapshot.data;
        if (bytes == null) {
          return _placeholder(
            context,
            loading: snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasError,
          );
        }
        return _image(context, bytes);
      },
    );
  }

  Widget _image(BuildContext context, Uint8List bytes) {
    // Decode straight to the display size (×DPR) instead of the full image, so
    // the engine never holds multi-megabyte full-resolution bitmaps for 44px
    // tiles — the cause of the image-cache thrash that made scrolling stutter.
    final int decodeWidth =
        (44 * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(44, 192).toInt();
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: 44,
        height: 44,
        cacheWidth: decodeWidth,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
      ),
    );
  }

  Widget _placeholder(
    BuildContext context, {
    bool missing = false,
    bool loading = false,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                missing ? Icons.broken_image_outlined : Icons.image_outlined,
                size: 20,
              ),
      ),
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
