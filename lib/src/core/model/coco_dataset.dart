import 'annotation.dart';
import 'category.dart';
import 'image_record.dart';

class CocoDataset {
  CocoDataset({
    required this.imagesById,
    required this.categoriesById,
    required this.annotations,
  }) : annotationsByImageId = _groupAnnotations(annotations);

  final Map<int, ImageRecord> imagesById;
  final Map<int, CategoryRecord> categoriesById;
  final List<GroundTruthAnnotation> annotations;
  final Map<int, List<GroundTruthAnnotation>> annotationsByImageId;

  Map<String, int> get imageIdsByFileName {
    return {
      for (final ImageRecord image in imagesById.values)
        image.fileName: image.id,
    };
  }

  static Map<int, List<GroundTruthAnnotation>> _groupAnnotations(
    List<GroundTruthAnnotation> annotations,
  ) {
    final Map<int, List<GroundTruthAnnotation>> grouped = {};
    for (final GroundTruthAnnotation annotation in annotations) {
      grouped.putIfAbsent(annotation.imageId, () => []).add(annotation);
    }
    return grouped;
  }
}
