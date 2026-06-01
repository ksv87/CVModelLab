import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const double epsilon = 1e-6;

  test('identical boxes have IoU 1', () {
    const BBox box = BBox(x: 10, y: 20, width: 30, height: 40);

    expect(calculateIoU(box, box), closeTo(1, epsilon));
  });

  test('non-overlapping boxes have IoU 0', () {
    const BBox a = BBox(x: 0, y: 0, width: 10, height: 10);
    const BBox b = BBox(x: 20, y: 20, width: 10, height: 10);

    expect(calculateIoU(a, b), 0);
  });

  test('partial overlap returns expected value', () {
    const BBox a = BBox(x: 0, y: 0, width: 10, height: 10);
    const BBox b = BBox(x: 5, y: 5, width: 10, height: 10);

    expect(calculateIoU(a, b), closeTo(25 / 175, epsilon));
  });

  test('one box inside another returns expected value', () {
    const BBox outer = BBox(x: 0, y: 0, width: 10, height: 10);
    const BBox inner = BBox(x: 2, y: 2, width: 4, height: 4);

    expect(calculateIoU(outer, inner), closeTo(16 / 100, epsilon));
  });

  test('zero or negative area returns 0', () {
    const BBox zero = BBox(x: 0, y: 0, width: 0, height: 10);
    const BBox negative = BBox(x: 0, y: 0, width: -1, height: 10);
    const BBox valid = BBox(x: 0, y: 0, width: 10, height: 10);

    expect(calculateIoU(zero, valid), 0);
    expect(calculateIoU(negative, valid), 0);
  });
}
