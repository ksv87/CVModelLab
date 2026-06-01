import 'dart:typed_data';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

class DetectionImageViewer extends StatefulWidget {
  const DetectionImageViewer({
    required this.image,
    required this.categoriesById,
    required this.matches,
    required this.imageBytes,
    required this.loadingImage,
    required this.selectedMatch,
    required this.onMatchSelected,
    super.key,
  });

  final ImageRecord? image;
  final Map<int, CategoryRecord> categoriesById;
  final List<DetectionMatch> matches;
  final Uint8List? imageBytes;
  final bool loadingImage;
  final DetectionMatch? selectedMatch;
  final ValueChanged<DetectionMatch?> onMatchSelected;

  @override
  State<DetectionImageViewer> createState() => _DetectionImageViewerState();
}

class _DetectionImageViewerState extends State<DetectionImageViewer> {
  bool _showGt = true;
  bool _showPred = true;
  bool _showTp = true;
  bool _showFp = true;
  bool _showFn = true;
  bool _showLabels = true;
  bool _showScores = true;
  bool _showIou = true;

  @override
  Widget build(BuildContext context) {
    if (widget.image == null) {
      return const Center(child: Text('No image selected'));
    }

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _ToggleChip(
                  label: 'GT',
                  selected: _showGt,
                  onSelected: (v) => setState(() => _showGt = v),
                ),
                const SizedBox(width: 8),
                _ToggleChip(
                  label: 'Pred',
                  selected: _showPred,
                  onSelected: (v) => setState(() => _showPred = v),
                ),
                const SizedBox(width: 8),
                _ToggleChip(
                  label: 'TP',
                  selected: _showTp,
                  onSelected: (v) => setState(() => _showTp = v),
                ),
                const SizedBox(width: 8),
                _ToggleChip(
                  label: 'FP',
                  selected: _showFp,
                  onSelected: (v) => setState(() => _showFp = v),
                ),
                const SizedBox(width: 8),
                _ToggleChip(
                  label: 'FN',
                  selected: _showFn,
                  onSelected: (v) => setState(() => _showFn = v),
                ),
                const SizedBox(width: 8),
                _ToggleChip(
                  label: 'Labels',
                  selected: _showLabels,
                  onSelected: (v) => setState(() => _showLabels = v),
                ),
                const SizedBox(width: 8),
                _ToggleChip(
                  label: 'Scores',
                  selected: _showScores,
                  onSelected: (v) => setState(() => _showScores = v),
                ),
                const SizedBox(width: 8),
                _ToggleChip(
                  label: 'IoU',
                  selected: _showIou,
                  onSelected: (v) => setState(() => _showIou = v),
                ),
                const SizedBox(width: 16),
                if (widget.loadingImage)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            minScale: 0.25,
            maxScale: 8,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final Size paintSize =
                    Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (TapDownDetails details) {
                    widget.onMatchSelected(
                      _hitTestMatch(details.localPosition, paintSize),
                    );
                  },
                  child: CustomPaint(
                    size: paintSize,
                    foregroundPainter: BBoxPainter(
                      image: widget.image!,
                      categoriesById: widget.categoriesById,
                      matches: _visibleOverlayMatches(),
                      selectedMatch: widget.selectedMatch,
                      imageBytesAvailable: widget.imageBytes != null,
                      showGt: _showGt,
                      showPredictions: _showPred,
                      showLabels: _showLabels,
                      showScores: _showScores,
                      showIou: _showIou,
                    ),
                    child: SizedBox.expand(
                      child: _ImageLayer(
                        image: widget.image!,
                        bytes: widget.imageBytes,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<DetectionMatch> _visibleOverlayMatches() {
    return widget.matches.where((DetectionMatch match) {
      return switch (match.type) {
        DetectionMatchType.truePositive => _showTp,
        DetectionMatchType.falsePositive => _showFp,
        DetectionMatchType.falseNegative => _showFn,
        DetectionMatchType.ignored => false,
      };
    }).toList();
  }

  DetectionMatch? _hitTestMatch(Offset position, Size size) {
    final ImageRecord image = widget.image!;
    final _ContainTransform transform = _transformFor(image, size);
    final List<DetectionMatch> visible = _visibleOverlayMatches();
    for (final DetectionMatch match in visible.reversed) {
      if (_showPred &&
          match.prediction != null &&
          transform
              .rectFor(match.prediction!.bbox)
              .inflate(4)
              .contains(position)) {
        return match;
      }
      if (_showGt &&
          match.groundTruth != null &&
          transform
              .rectFor(match.groundTruth!.bbox)
              .inflate(4)
              .contains(position)) {
        return match;
      }
    }
    return null;
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
    );
  }
}

class _ImageLayer extends StatelessWidget {
  const _ImageLayer({required this.image, required this.bytes});

  final ImageRecord image;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    if (bytes == null) {
      return const SizedBox.expand();
    }
    return Image.memory(
      bytes!,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const SizedBox.expand(),
    );
  }
}

class BBoxPainter extends CustomPainter {
  BBoxPainter({
    required this.image,
    required this.categoriesById,
    required this.matches,
    required this.selectedMatch,
    required this.imageBytesAvailable,
    required this.showGt,
    required this.showPredictions,
    required this.showLabels,
    required this.showScores,
    required this.showIou,
  });

  final ImageRecord image;
  final Map<int, CategoryRecord> categoriesById;
  final List<DetectionMatch> matches;
  final DetectionMatch? selectedMatch;
  final bool imageBytesAvailable;
  final bool showGt;
  final bool showPredictions;
  final bool showLabels;
  final bool showScores;
  final bool showIou;

  @override
  void paint(Canvas canvas, Size size) {
    final _ContainTransform transform = _transformFor(image, size);

    if (!imageBytesAvailable) {
      _paintPlaceholder(canvas, size, transform);
    }

    for (final DetectionMatch match in matches) {
      final bool selected = identical(match, selectedMatch);
      if (showGt && match.groundTruth != null) {
        _paintBox(
          canvas: canvas,
          transform: transform,
          bbox: match.groundTruth!.bbox,
          color: _colorForMatch(match.type),
          strokeWidth: selected ? 4 : 2,
          dashed: false,
          label: showLabels ? _labelForGroundTruth(match) : null,
        );
      }
      if (showPredictions && match.prediction != null) {
        _paintBox(
          canvas: canvas,
          transform: transform,
          bbox: match.prediction!.bbox,
          color: _colorForMatch(match.type),
          strokeWidth: selected ? 4 : 2,
          dashed: true,
          label: showLabels ? _labelForPrediction(match) : null,
        );
      }
    }
  }

  void _paintPlaceholder(
    Canvas canvas,
    Size size,
    _ContainTransform transform,
  ) {
    final Paint background = Paint()..color = const Color(0xfff8fafc);
    canvas.drawRect(Offset.zero & size, background);
    final Paint imageArea = Paint()..color = const Color(0xffe2e8f0);
    canvas.drawRect(transform.imageRect, imageArea);
    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xff94a3b8);
    canvas.drawRect(transform.imageRect, border);
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: 'Missing image: ${image.fileName}',
        style: const TextStyle(color: Color(0xff475569), fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: transform.imageRect.width - 24);
    textPainter.paint(
      canvas,
      Offset(transform.imageRect.left + 12, transform.imageRect.top + 12),
    );
  }

  void _paintBox({
    required Canvas canvas,
    required _ContainTransform transform,
    required BBox bbox,
    required Color color,
    required double strokeWidth,
    required bool dashed,
    required String? label,
  }) {
    final Rect rect = transform.rectFor(bbox);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;

    if (dashed) {
      _drawDashedRect(canvas, rect, paint);
    } else {
      canvas.drawRect(rect, paint);
    }

    if (label != null) {
      _paintLabel(canvas, rect, label, color);
    }
  }

  void _paintLabel(Canvas canvas, Rect rect, String label, Color color) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.2),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: 260);
    final Rect labelRect = Rect.fromLTWH(
      rect.left,
      (rect.top - textPainter.height - 4).clamp(0, double.infinity).toDouble(),
      textPainter.width + 8,
      textPainter.height + 4,
    );
    final Paint background = Paint()..color = color.withValues(alpha: 0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
      background,
    );
    textPainter.paint(canvas, labelRect.topLeft + const Offset(4, 2));
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint);
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, paint);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double dash = 8;
    const double gap = 5;
    final Offset delta = end - start;
    final double distance = delta.distance;
    if (distance == 0) {
      return;
    }
    final Offset direction = delta / distance;
    var current = 0.0;
    while (current < distance) {
      final double next = (current + dash).clamp(0, distance).toDouble();
      canvas.drawLine(
        start + direction * current,
        start + direction * next,
        paint,
      );
      current += dash + gap;
    }
  }

  Color _colorForMatch(DetectionMatchType type) {
    return switch (type) {
      DetectionMatchType.truePositive => const Color(0xff16a34a),
      DetectionMatchType.falsePositive => const Color(0xffdc2626),
      DetectionMatchType.falseNegative => const Color(0xfff97316),
      DetectionMatchType.ignored => const Color(0xff64748b),
    };
  }

  String _labelForGroundTruth(DetectionMatch match) {
    final int? categoryId = match.groundTruth?.categoryId ?? match.categoryId;
    return '${_typeLabel(match.type)} GT ${_categoryName(categoryId)}';
  }

  String _labelForPrediction(DetectionMatch match) {
    final Prediction prediction = match.prediction!;
    final List<String> parts = [
      _typeLabel(match.type),
      'Pred',
      _categoryName(prediction.categoryId),
      if (showScores) prediction.score.toStringAsFixed(2),
      if (showIou && match.iou != null) 'IoU ${match.iou!.toStringAsFixed(2)}',
    ];
    return parts.join(' ');
  }

  String _categoryName(int? categoryId) {
    if (categoryId == null) {
      return '-';
    }
    return categoriesById[categoryId]?.name ?? categoryId.toString();
  }

  String _typeLabel(DetectionMatchType type) {
    return switch (type) {
      DetectionMatchType.truePositive => 'TP',
      DetectionMatchType.falsePositive => 'FP',
      DetectionMatchType.falseNegative => 'FN',
      DetectionMatchType.ignored => 'Ignored',
    };
  }

  @override
  bool shouldRepaint(covariant BBoxPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.matches != matches ||
        oldDelegate.selectedMatch != selectedMatch ||
        oldDelegate.imageBytesAvailable != imageBytesAvailable ||
        oldDelegate.showGt != showGt ||
        oldDelegate.showPredictions != showPredictions ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showScores != showScores ||
        oldDelegate.showIou != showIou;
  }
}

class _ContainTransform {
  const _ContainTransform({
    required this.scale,
    required this.offset,
    required this.imageRect,
  });

  final double scale;
  final Offset offset;
  final Rect imageRect;

  Rect rectFor(BBox bbox) {
    return Rect.fromLTWH(
      offset.dx + bbox.x * scale,
      offset.dy + bbox.y * scale,
      bbox.width * scale,
      bbox.height * scale,
    );
  }
}

_ContainTransform _transformFor(ImageRecord image, Size canvasSize) {
  final double imageWidth = (image.width ?? 640).toDouble();
  final double imageHeight = (image.height ?? 480).toDouble();
  final double scale =
      (canvasSize.width / imageWidth) < (canvasSize.height / imageHeight)
          ? canvasSize.width / imageWidth
          : canvasSize.height / imageHeight;
  final double displayWidth = imageWidth * scale;
  final double displayHeight = imageHeight * scale;
  final Offset offset = Offset(
    (canvasSize.width - displayWidth) / 2,
    (canvasSize.height - displayHeight) / 2,
  );
  return _ContainTransform(
    scale: scale,
    offset: offset,
    imageRect: offset & Size(displayWidth, displayHeight),
  );
}
