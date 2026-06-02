import 'dart:convert';

import '../model/coco_dataset.dart';
import '../model/prediction.dart';

/// Serializes an in-memory dataset and predictions back to COCO JSON strings.
///
/// Used by the desktop AP evaluator when no on-disk file paths are available
/// (e.g. the demo project or a project loaded from a web browser). The strings
/// are written to temp files by the platform-specific evaluator.
class CocoSerializer {
  const CocoSerializer();

  String annotationsJson(CocoDataset dataset) {
    final List<Map<String, Object?>> images = [
      for (final img in dataset.imagesById.values)
        <String, Object?>{
          'id': img.id,
          'file_name': img.fileName,
          if (img.width != null) 'width': img.width,
          if (img.height != null) 'height': img.height,
        },
    ];

    final List<Map<String, Object?>> annotations = [
      for (final ann in dataset.annotations)
        <String, Object?>{
          'id': ann.id,
          'image_id': ann.imageId,
          'category_id': ann.categoryId,
          'bbox': [ann.bbox.x, ann.bbox.y, ann.bbox.width, ann.bbox.height],
          'area': ann.effectiveArea,
          'iscrowd': ann.isCrowd ? 1 : 0,
        },
    ];

    final List<Map<String, Object?>> categories = [
      for (final cat in dataset.categoriesById.values)
        <String, Object?>{'id': cat.id, 'name': cat.name},
    ];

    return jsonEncode(<String, Object?>{
      'images': images,
      'annotations': annotations,
      'categories': categories,
    });
  }

  String predictionsJson(List<Prediction> predictions) {
    return jsonEncode([
      for (final p in predictions)
        <String, Object?>{
          'image_id': p.imageId,
          'category_id': p.categoryId,
          'bbox': [p.bbox.x, p.bbox.y, p.bbox.width, p.bbox.height],
          'score': p.score,
        },
    ]);
  }
}
