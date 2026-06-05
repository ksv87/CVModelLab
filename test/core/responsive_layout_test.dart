import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('responsiveSizeClassForWidth', () {
    test('classifies compact below 700', () {
      expect(responsiveSizeClassForWidth(0), ResponsiveSizeClass.compact);
      expect(responsiveSizeClassForWidth(360), ResponsiveSizeClass.compact);
      expect(responsiveSizeClassForWidth(699.9), ResponsiveSizeClass.compact);
    });

    test('classifies medium in [700, 1100)', () {
      expect(responsiveSizeClassForWidth(700), ResponsiveSizeClass.medium);
      expect(responsiveSizeClassForWidth(900), ResponsiveSizeClass.medium);
      expect(responsiveSizeClassForWidth(1099.9), ResponsiveSizeClass.medium);
    });

    test('classifies expanded at or above 1100', () {
      expect(responsiveSizeClassForWidth(1100), ResponsiveSizeClass.expanded);
      expect(responsiveSizeClassForWidth(1920), ResponsiveSizeClass.expanded);
    });

    test('uses documented breakpoint constants', () {
      expect(kCompactBreakpoint, 700);
      expect(kExpandedBreakpoint, 1100);
    });
  });

  group('ResponsiveLayoutInfo', () {
    test('exposes boolean helpers for each size class', () {
      const ResponsiveLayoutInfo compact =
          ResponsiveLayoutInfo(ResponsiveSizeClass.compact);
      expect(compact.isCompact, isTrue);
      expect(compact.isMedium, isFalse);
      expect(compact.isExpanded, isFalse);

      final ResponsiveLayoutInfo medium = ResponsiveLayoutInfo.fromWidth(800);
      expect(medium.isMedium, isTrue);
      expect(medium.isCompact, isFalse);
      expect(medium.isExpanded, isFalse);

      final ResponsiveLayoutInfo expanded =
          ResponsiveLayoutInfo.fromWidth(1400);
      expect(expanded.isExpanded, isTrue);
    });

    test('value equality on size class', () {
      expect(
        ResponsiveLayoutInfo.fromWidth(500),
        const ResponsiveLayoutInfo(ResponsiveSizeClass.compact),
      );
      expect(
        ResponsiveLayoutInfo.fromWidth(500) ==
            ResponsiveLayoutInfo.fromWidth(800),
        isFalse,
      );
    });
  });
}
