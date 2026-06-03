import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

/// Renders a single image with its GT / prediction overlays to PNG bytes using
/// the Flutter engine's canvas. Works on both web and desktop (no `dart:io`).
///
/// This is intentionally separate from the on-screen [BBoxPainter]: the export
/// draws at the image's native resolution (times [AnnotatedImageExportConfig.
/// outputScale]) rather than fitting into a viewport, and bakes in labels and a
/// corner caption.
class AnnotatedImageRenderer {
  const AnnotatedImageRenderer();

  static const Color _tpColor = Color(0xff16a34a);
  static const Color _fpColor = Color(0xffdc2626);
  static const Color _fnColor = Color(0xfff97316);
  static const Color _placeholderBg = Color(0xffe2e8f0);

  Future<Uint8List> render({
    required ImageRecord image,
    required Uint8List? imageBytes,
    required List<DetectionMatch> matches,
    required Map<int, CategoryRecord> categoriesById,
    required AnnotatedImageExportConfig config,
    String? modelName,
  }) async {
    ui.Image? decoded;
    if (imageBytes != null) {
      try {
        final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
        final ui.FrameInfo frame = await codec.getNextFrame();
        decoded = frame.image;
      } on Object {
        decoded = null;
      }
    }

    final double scale = config.outputScale <= 0 ? 1.0 : config.outputScale;
    final double srcWidth = (decoded?.width ?? image.width ?? 640).toDouble();
    final double srcHeight =
        (decoded?.height ?? image.height ?? 480).toDouble();
    final int outWidth = (srcWidth * scale).round().clamp(1, 1 << 16);
    final int outHeight = (srcHeight * scale).round().clamp(1, 1 << 16);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
    );

    // Background / base image.
    if (decoded != null) {
      canvas.drawImageRect(
        decoded,
        Rect.fromLTWH(0, 0, srcWidth, srcHeight),
        Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
        Paint(),
      );
    } else {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
        Paint()..color = _placeholderBg,
      );
      _drawText(
        canvas,
        'Missing image: ${image.fileName}',
        Offset(12, 12),
        const Color(0xff475569),
        14,
      );
    }

    for (final DetectionMatch match in matches) {
      if (!_isMatchEnabled(match.type, config)) {
        continue;
      }
      final Color color = _colorFor(match.type);
      if (config.includeGt && match.groundTruth != null) {
        _drawBox(
          canvas,
          match.groundTruth!.bbox,
          scale,
          color,
          dashed: false,
          label: config.includeLabels ? _gtLabel(match, categoriesById) : null,
        );
      }
      if (config.includePredictions && match.prediction != null) {
        _drawBox(
          canvas,
          match.prediction!.bbox,
          scale,
          color,
          dashed: true,
          label: config.includeLabels
              ? _predLabel(match, categoriesById, config)
              : null,
        );
      }
    }

    // Corner caption.
    final String caption = [
      'CV Model Lab',
      if (modelName != null && modelName.isNotEmpty) 'model: $modelName',
      'file: ${image.fileName}',
    ].join('  |  ');
    _drawCaption(canvas, caption, outWidth.toDouble(), outHeight.toDouble());

    final ui.Picture picture = recorder.endRecording();
    final ui.Image rendered = await picture.toImage(outWidth, outHeight);
    final ByteData? data =
        await rendered.toByteData(format: ui.ImageByteFormat.png);
    decoded?.dispose();
    rendered.dispose();
    if (data == null) {
      throw StateError('Failed to encode annotated PNG.');
    }
    return data.buffer.asUint8List();
  }

  bool _isMatchEnabled(DetectionMatchType type, AnnotatedImageExportConfig c) {
    return switch (type) {
      DetectionMatchType.truePositive => c.includeTp,
      DetectionMatchType.falsePositive => c.includeFp,
      DetectionMatchType.falseNegative => c.includeFn,
      DetectionMatchType.ignored => false,
    };
  }

  Color _colorFor(DetectionMatchType type) {
    return switch (type) {
      DetectionMatchType.truePositive => _tpColor,
      DetectionMatchType.falsePositive => _fpColor,
      DetectionMatchType.falseNegative => _fnColor,
      DetectionMatchType.ignored => const Color(0xff64748b),
    };
  }

  void _drawBox(
    Canvas canvas,
    BBox bbox,
    double scale,
    Color color, {
    required bool dashed,
    String? label,
  }) {
    final Rect rect = Rect.fromLTWH(
      bbox.x * scale,
      bbox.y * scale,
      bbox.width * scale,
      bbox.height * scale,
    );
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    if (dashed) {
      _drawDashedRect(canvas, rect, paint);
    } else {
      canvas.drawRect(rect, paint);
    }
    if (label != null && label.isNotEmpty) {
      _drawLabel(canvas, rect, label, color);
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    void line(Offset a, Offset b) {
      const double dash = 8;
      const double gap = 5;
      final Offset delta = b - a;
      final double distance = delta.distance;
      if (distance == 0) {
        return;
      }
      final Offset dir = delta / distance;
      double current = 0;
      while (current < distance) {
        final double next = (current + dash).clamp(0, distance).toDouble();
        canvas.drawLine(a + dir * current, a + dir * next, paint);
        current += dash + gap;
      }
    }

    line(rect.topLeft, rect.topRight);
    line(rect.topRight, rect.bottomRight);
    line(rect.bottomRight, rect.bottomLeft);
    line(rect.bottomLeft, rect.topLeft);
  }

  void _drawLabel(Canvas canvas, Rect rect, String label, Color color) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.2),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: 320);
    final double top =
        (rect.top - tp.height - 4).clamp(0, double.infinity).toDouble();
    final Rect labelRect =
        Rect.fromLTWH(rect.left, top, tp.width + 8, tp.height + 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
      Paint()..color = color.withValues(alpha: 0.9),
    );
    tp.paint(canvas, labelRect.topLeft + const Offset(4, 2));
  }

  void _drawCaption(Canvas canvas, String text, double width, double height) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: width - 16);
    final Rect bg = Rect.fromLTWH(
      4,
      height - tp.height - 8,
      tp.width + 8,
      tp.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, const Radius.circular(4)),
      Paint()..color = const Color(0xcc0f172a),
    );
    tp.paint(canvas, bg.topLeft + const Offset(4, 2));
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double size,
  ) {
    final TextPainter tp = TextPainter(
      text:
          TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  String _gtLabel(DetectionMatch match, Map<int, CategoryRecord> cats) {
    final int? id = match.groundTruth?.categoryId ?? match.categoryId;
    return '${_typeTag(match.type)} GT ${_catName(id, cats)}';
  }

  String _predLabel(
    DetectionMatch match,
    Map<int, CategoryRecord> cats,
    AnnotatedImageExportConfig config,
  ) {
    final Prediction prediction = match.prediction!;
    return [
      _typeTag(match.type),
      'Pred',
      _catName(prediction.categoryId, cats),
      if (config.includeScores) prediction.score.toStringAsFixed(2),
      if (config.includeIou && match.iou != null)
        'IoU ${match.iou!.toStringAsFixed(2)}',
    ].join(' ');
  }

  String _catName(int? id, Map<int, CategoryRecord> cats) {
    if (id == null) {
      return '-';
    }
    return cats[id]?.name ?? '$id';
  }

  String _typeTag(DetectionMatchType type) {
    return switch (type) {
      DetectionMatchType.truePositive => 'TP',
      DetectionMatchType.falsePositive => 'FP',
      DetectionMatchType.falseNegative => 'FN',
      DetectionMatchType.ignored => 'Ignored',
    };
  }
}
