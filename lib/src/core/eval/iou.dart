import '../model/bbox.dart';

double calculateIoU(BBox a, BBox b) {
  final double areaA = a.area;
  final double areaB = b.area;
  if (areaA <= 0 || areaB <= 0) {
    return 0;
  }

  final double intersectionX1 = a.x1 > b.x1 ? a.x1 : b.x1;
  final double intersectionY1 = a.y1 > b.y1 ? a.y1 : b.y1;
  final double intersectionX2 = a.x2 < b.x2 ? a.x2 : b.x2;
  final double intersectionY2 = a.y2 < b.y2 ? a.y2 : b.y2;
  final double intersectionWidth = intersectionX2 - intersectionX1;
  final double intersectionHeight = intersectionY2 - intersectionY1;
  if (intersectionWidth <= 0 || intersectionHeight <= 0) {
    return 0;
  }

  final double intersection = intersectionWidth * intersectionHeight;
  final double union = areaA + areaB - intersection;
  if (union <= 0) {
    return 0;
  }
  return intersection / union;
}
