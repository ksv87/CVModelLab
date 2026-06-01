import 'bbox.dart';

class Prediction {
  const Prediction({
    required this.imageId,
    required this.categoryId,
    required this.bbox,
    required this.score,
    this.sourceModelName,
  });

  final int imageId;
  final int categoryId;
  final BBox bbox;
  final double score;
  final String? sourceModelName;
}
