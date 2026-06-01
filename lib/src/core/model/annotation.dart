import 'bbox.dart';

class GroundTruthAnnotation {
  const GroundTruthAnnotation({
    required this.id,
    required this.imageId,
    required this.categoryId,
    required this.bbox,
    this.area,
    this.isCrowd = false,
  });

  final int id;
  final int imageId;
  final int categoryId;
  final BBox bbox;
  final double? area;
  final bool isCrowd;

  double get effectiveArea => area ?? bbox.area;
}
