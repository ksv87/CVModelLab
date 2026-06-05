import 'dart:typed_data';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import 'detection_image_viewer.dart';

/// Inline preview of a single image with its TP/FP/FN overlays.
///
/// Used by the analysis screens (Confusion Matrix, Worst Cases, Dataset Health)
/// so that picking an example shows the annotated image in place instead of
/// navigating away to the Error Browser. An explicit "Open in Browser" action
/// is offered for full inspection.
class ImagePreviewPane extends StatefulWidget {
  const ImagePreviewPane({
    required this.imageId,
    required this.dataset,
    required this.matches,
    required this.loadBytes,
    this.focusMatchTypes = const {},
    this.focusMatch,
    this.onOpenInBrowser,
    super.key,
  });

  /// Currently previewed image, or null when nothing is selected.
  final int? imageId;
  final CocoDataset dataset;

  /// Detection matches for [imageId].
  final List<DetectionMatch> matches;

  /// Loads the raw bytes for an image file name (null if unavailable).
  final Future<Uint8List?> Function(String fileName) loadBytes;

  /// Match types that represent "the error" for the current selection. When
  /// non-empty an "Only error" filter is offered and these types are the ones
  /// kept when it is active.
  final Set<DetectionMatchType> focusMatchTypes;

  /// The specific offending match to highlight on selection. Must be an element
  /// of [matches] (identity is what [DetectionImageViewer] compares).
  final DetectionMatch? focusMatch;

  /// Called when the user requests full inspection in the Error Browser.
  final ValueChanged<int>? onOpenInBrowser;

  @override
  State<ImagePreviewPane> createState() => _ImagePreviewPaneState();
}

class _ImagePreviewPaneState extends State<ImagePreviewPane> {
  Uint8List? _bytes;
  bool _loading = false;
  bool _errorsOnly = false;
  DetectionMatch? _selectedMatch;

  @override
  void initState() {
    super.initState();
    _selectedMatch = widget.focusMatch;
    _loadBytes();
  }

  @override
  void didUpdateWidget(covariant ImagePreviewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageId != oldWidget.imageId) {
      _selectedMatch = widget.focusMatch;
      _errorsOnly = false;
      _bytes = null;
      _loadBytes();
    } else if (!identical(widget.focusMatch, oldWidget.focusMatch)) {
      _selectedMatch = widget.focusMatch;
    }
  }

  Future<void> _loadBytes() async {
    final int? imageId = widget.imageId;
    if (imageId == null) {
      return;
    }
    final ImageRecord? image = widget.dataset.imagesById[imageId];
    if (image == null) {
      return;
    }
    setState(() => _loading = true);
    final Uint8List? bytes = await widget.loadBytes(image.fileName);
    if (!mounted || widget.imageId != imageId) {
      return;
    }
    setState(() {
      _bytes = bytes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final int? imageId = widget.imageId;
    final ImageRecord? image =
        imageId == null ? null : widget.dataset.imagesById[imageId];
    if (image == null) {
      return const Center(child: Text('Select an item to preview'));
    }
    final bool canFocus = widget.focusMatchTypes.isNotEmpty;
    final List<DetectionMatch> visibleMatches = canFocus && _errorsOnly
        ? widget.matches
            .where(
              (DetectionMatch m) => widget.focusMatchTypes.contains(m.type),
            )
            .toList()
        : widget.matches;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                image.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (canFocus || widget.onOpenInBrowser != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (canFocus)
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        segments: const [
                          ButtonSegment<bool>(
                            value: false,
                            label: Text('All'),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            label: Text('Only error'),
                          ),
                        ],
                        selected: {_errorsOnly},
                        onSelectionChanged: (Set<bool> values) {
                          setState(() => _errorsOnly = values.first);
                        },
                      ),
                    if (widget.onOpenInBrowser != null)
                      TextButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Open in Browser'),
                        onPressed: () => widget.onOpenInBrowser!(imageId!),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: DetectionImageViewer(
            image: image,
            categoriesById: widget.dataset.categoriesById,
            matches: visibleMatches,
            imageBytes: _bytes,
            loadingImage: _loading,
            selectedMatch: _selectedMatch,
            onMatchSelected: (DetectionMatch? match) {
              setState(() => _selectedMatch = match);
            },
          ),
        ),
      ],
    );
  }
}
