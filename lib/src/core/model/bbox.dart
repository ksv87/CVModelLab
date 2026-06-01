class BBox {
  const BBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  double get x1 => x;
  double get y1 => y;
  double get x2 => x + width;
  double get y2 => y + height;
  double get area => width <= 0 || height <= 0 ? 0 : width * height;

  BBox clampToImage({
    required double imageWidth,
    required double imageHeight,
  }) {
    final double clampedX1 = x1.clamp(0, imageWidth).toDouble();
    final double clampedY1 = y1.clamp(0, imageHeight).toDouble();
    final double clampedX2 = x2.clamp(0, imageWidth).toDouble();
    final double clampedY2 = y2.clamp(0, imageHeight).toDouble();
    return BBox(
      x: clampedX1,
      y: clampedY1,
      width: (clampedX2 - clampedX1).clamp(0, double.infinity).toDouble(),
      height: (clampedY2 - clampedY1).clamp(0, double.infinity).toDouble(),
    );
  }

  @override
  String toString() => 'BBox($x, $y, $width, $height)';
}
