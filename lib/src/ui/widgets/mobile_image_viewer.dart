import 'dart:typed_data';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import '../l10n/app_locale_scope.dart';
import '../l10n/app_localizations.dart';
import 'detection_image_viewer.dart';

/// Immutable set of overlay toggles for the detection viewer.
class DetectionOverlayOptions {
  const DetectionOverlayOptions({
    this.showGt = true,
    this.showPredictions = true,
    this.showTp = true,
    this.showFp = true,
    this.showFn = true,
    this.showLabels = true,
    this.showScores = true,
    this.showIou = true,
  });

  final bool showGt;
  final bool showPredictions;
  final bool showTp;
  final bool showFp;
  final bool showFn;
  final bool showLabels;
  final bool showScores;
  final bool showIou;

  DetectionOverlayOptions copyWith({
    bool? showGt,
    bool? showPredictions,
    bool? showTp,
    bool? showFp,
    bool? showFn,
    bool? showLabels,
    bool? showScores,
    bool? showIou,
  }) {
    return DetectionOverlayOptions(
      showGt: showGt ?? this.showGt,
      showPredictions: showPredictions ?? this.showPredictions,
      showTp: showTp ?? this.showTp,
      showFp: showFp ?? this.showFp,
      showFn: showFn ?? this.showFn,
      showLabels: showLabels ?? this.showLabels,
      showScores: showScores ?? this.showScores,
      showIou: showIou ?? this.showIou,
    );
  }
}

/// A full-screen, touch-first image viewer for compact layouts.
///
/// Provides pinch zoom and pan (via [InteractiveViewer]), fit-to-screen,
/// next/previous image and next/previous error navigation, an overlay-options
/// bottom sheet, and a bounding-box details bottom sheet on tap.
class MobileImageViewerPage extends StatefulWidget {
  const MobileImageViewerPage({
    required this.dataset,
    required this.categoriesById,
    required this.imageIds,
    required this.errorImageIds,
    required this.initialImageId,
    required this.matchesFor,
    required this.loadImageBytes,
    required this.modelRunName,
    this.onImageChanged,
    super.key,
  });

  final CocoDataset dataset;
  final Map<int, CategoryRecord> categoriesById;
  final List<int> imageIds;
  final Set<int> errorImageIds;
  final int initialImageId;
  final List<DetectionMatch> Function(int imageId) matchesFor;
  final Future<Uint8List?> Function(String fileName) loadImageBytes;
  final String modelRunName;
  final ValueChanged<int>? onImageChanged;

  @override
  State<MobileImageViewerPage> createState() => _MobileImageViewerPageState();
}

class _MobileImageViewerPageState extends State<MobileImageViewerPage> {
  final TransformationController _transform = TransformationController();
  late int _index;
  DetectionOverlayOptions _options = const DetectionOverlayOptions();
  DetectionMatch? _selectedMatch;
  Uint8List? _bytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _index = widget.imageIds.indexOf(widget.initialImageId);
    if (_index < 0) {
      _index = 0;
    }
    _loadBytes();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  int? get _currentImageId =>
      widget.imageIds.isEmpty ? null : widget.imageIds[_index];

  ImageRecord? get _currentImage {
    final int? id = _currentImageId;
    return id == null ? null : widget.dataset.imagesById[id];
  }

  Future<void> _loadBytes() async {
    final ImageRecord? image = _currentImage;
    if (image == null) {
      return;
    }
    setState(() => _loading = true);
    final Uint8List? bytes = await widget.loadImageBytes(image.fileName);
    if (!mounted || _currentImage?.fileName != image.fileName) {
      return;
    }
    setState(() {
      _bytes = bytes;
      _loading = false;
    });
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.imageIds.length || index == _index) {
      return;
    }
    setState(() {
      _index = index;
      _selectedMatch = null;
      _bytes = null;
    });
    _transform.value = Matrix4.identity();
    widget.onImageChanged?.call(widget.imageIds[index]);
    _loadBytes();
  }

  void _goToNextError() {
    for (int i = _index + 1; i < widget.imageIds.length; i++) {
      if (widget.errorImageIds.contains(widget.imageIds[i])) {
        _goTo(i);
        return;
      }
    }
  }

  void _goToPrevError() {
    for (int i = _index - 1; i >= 0; i--) {
      if (widget.errorImageIds.contains(widget.imageIds[i])) {
        _goTo(i);
        return;
      }
    }
  }

  void _fitToScreen() => _transform.value = Matrix4.identity();

  List<DetectionMatch> _visibleMatches(List<DetectionMatch> matches) {
    return matches.where((DetectionMatch match) {
      return switch (match.type) {
        DetectionMatchType.truePositive => _options.showTp,
        DetectionMatchType.falsePositive => _options.showFp,
        DetectionMatchType.falseNegative => _options.showFn,
        DetectionMatchType.ignored => false,
      };
    }).toList();
  }

  DetectionMatch? _hitTest(
    Offset position,
    Size size,
    ImageRecord image,
    List<DetectionMatch> visible,
  ) {
    final ContainTransform transform = containTransformFor(image, size);
    for (final DetectionMatch match in visible.reversed) {
      if (_options.showPredictions &&
          match.prediction != null &&
          transform.rectFor(match.prediction!.bbox).inflate(8).contains(position)) {
        return match;
      }
      if (_options.showGt &&
          match.groundTruth != null &&
          transform.rectFor(match.groundTruth!.bbox).inflate(8).contains(position)) {
        return match;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocaleScope.l10n(context);
    final ImageRecord? image = _currentImage;
    final int? imageId = _currentImageId;
    final List<DetectionMatch> matches =
        imageId == null ? const [] : widget.matchesFor(imageId);
    final List<DetectionMatch> visible = _visibleMatches(matches);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          image?.fileName ?? '-',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: l10n.t(MessageKey.mobileFitToScreen),
            icon: const Icon(Icons.fit_screen),
            onPressed: _fitToScreen,
          ),
          IconButton(
            tooltip: l10n.t(MessageKey.mobileOverlayOptions),
            icon: const Icon(Icons.layers),
            onPressed: _openOverlaySheet,
          ),
        ],
      ),
      body: image == null
          ? Center(child: Text(l10n.t(MessageKey.mobileBackToList)))
          : Column(
              children: [
                if (widget.imageIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.imageIds.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Expanded(
                  child: InteractiveViewer(
                    transformationController: _transform,
                    minScale: 0.5,
                    maxScale: 8,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final Size paintSize =
                            Size(constraints.maxWidth, constraints.maxHeight);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (TapDownDetails details) {
                            final DetectionMatch? hit = _hitTest(
                              details.localPosition,
                              paintSize,
                              image,
                              visible,
                            );
                            setState(() => _selectedMatch = hit);
                            if (hit != null) {
                              _openDetailsSheet(hit);
                            }
                          },
                          child: CustomPaint(
                            size: paintSize,
                            foregroundPainter: BBoxPainter(
                              image: image,
                              categoriesById: widget.categoriesById,
                              matches: visible,
                              selectedMatch: _selectedMatch,
                              imageBytesAvailable: _bytes != null,
                              loading: _loading,
                              showGt: _options.showGt,
                              showPredictions: _options.showPredictions,
                              showLabels: _options.showLabels,
                              showScores: _options.showScores,
                              showIou: _options.showIou,
                            ),
                            child: SizedBox.expand(
                              child: _bytes == null
                                  ? const SizedBox.expand()
                                  : Image.memory(
                                      _bytes!,
                                      fit: BoxFit.contain,
                                      gaplessPlayback: true,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox.expand(),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              tooltip: l10n.t(MessageKey.mobilePrevImage),
              icon: const Icon(Icons.chevron_left),
              onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
            ),
            IconButton(
              tooltip: l10n.t(MessageKey.mobilePrevError),
              color: Theme.of(context).colorScheme.error,
              icon: const Icon(Icons.skip_previous),
              onPressed: _hasPrevError() ? _goToPrevError : null,
            ),
            IconButton(
              tooltip: l10n.t(MessageKey.mobileNextError),
              color: Theme.of(context).colorScheme.error,
              icon: const Icon(Icons.skip_next),
              onPressed: _hasNextError() ? _goToNextError : null,
            ),
            IconButton(
              tooltip: l10n.t(MessageKey.mobileNextImage),
              icon: const Icon(Icons.chevron_right),
              onPressed: _index < widget.imageIds.length - 1
                  ? () => _goTo(_index + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  bool _hasNextError() {
    for (int i = _index + 1; i < widget.imageIds.length; i++) {
      if (widget.errorImageIds.contains(widget.imageIds[i])) return true;
    }
    return false;
  }

  bool _hasPrevError() {
    for (int i = _index - 1; i >= 0; i--) {
      if (widget.errorImageIds.contains(widget.imageIds[i])) return true;
    }
    return false;
  }

  Future<void> _openOverlaySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final AppLocalizations l10n = AppLocaleScope.l10n(sheetContext);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void toggle(DetectionOverlayOptions next) {
              setState(() => _options = next);
              setSheetState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t(MessageKey.mobileOverlayOptions),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _overlayChip(
                          'GT',
                          _options.showGt,
                          (v) => toggle(_options.copyWith(showGt: v)),
                        ),
                        _overlayChip(
                          'Pred',
                          _options.showPredictions,
                          (v) => toggle(_options.copyWith(showPredictions: v)),
                        ),
                        _overlayChip(
                          'TP',
                          _options.showTp,
                          (v) => toggle(_options.copyWith(showTp: v)),
                        ),
                        _overlayChip(
                          'FP',
                          _options.showFp,
                          (v) => toggle(_options.copyWith(showFp: v)),
                        ),
                        _overlayChip(
                          'FN',
                          _options.showFn,
                          (v) => toggle(_options.copyWith(showFn: v)),
                        ),
                        _overlayChip(
                          'Labels',
                          _options.showLabels,
                          (v) => toggle(_options.copyWith(showLabels: v)),
                        ),
                        _overlayChip(
                          'Scores',
                          _options.showScores,
                          (v) => toggle(_options.copyWith(showScores: v)),
                        ),
                        _overlayChip(
                          'IoU',
                          _options.showIou,
                          (v) => toggle(_options.copyWith(showIou: v)),
                        ),
                      ],
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

  Widget _overlayChip(String label, bool selected, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onChanged,
    );
  }

  Future<void> _openDetailsSheet(DetectionMatch match) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final AppLocalizations l10n = AppLocaleScope.l10n(sheetContext);
        final int? categoryId = match.prediction?.categoryId ??
            match.groundTruth?.categoryId ??
            match.categoryId;
        final String className =
            widget.categoriesById[categoryId]?.name ?? categoryId?.toString() ?? '-';
        final BBox? bbox =
            match.prediction?.bbox ?? match.groundTruth?.bbox;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t(MessageKey.mobileDetails),
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _detailRow('Type', _typeLabel(match.type)),
                _detailRow('Class', className),
                if (match.prediction != null)
                  _detailRow('Score', match.prediction!.score.toStringAsFixed(3)),
                if (match.iou != null)
                  _detailRow('IoU', match.iou!.toStringAsFixed(3)),
                if (bbox != null)
                  _detailRow(
                    'BBox',
                    '[${bbox.x.toStringAsFixed(0)}, ${bbox.y.toStringAsFixed(0)}, '
                        '${bbox.width.toStringAsFixed(0)}, '
                        '${bbox.height.toStringAsFixed(0)}]',
                  ),
                if (match.reason != null)
                  _detailRow('Reason', match.reason!.replaceAll('_', ' ')),
                _detailRow('Model run', widget.modelRunName),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _typeLabel(DetectionMatchType type) {
    return switch (type) {
      DetectionMatchType.truePositive => 'TP',
      DetectionMatchType.falsePositive => 'FP',
      DetectionMatchType.falseNegative => 'FN',
      DetectionMatchType.ignored => 'Ignored',
    };
  }
}
