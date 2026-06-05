/// Responsive layout primitives shared across the UI.
///
/// These are intentionally pure Dart (no Flutter imports) so the breakpoint
/// logic can be unit-tested without a widget harness and reused by any layer.
///
/// Breakpoints (logical pixels of available width):
///   * compact:  width < 700
///   * medium:   700 <= width < 1100
///   * expanded: width >= 1100
enum ResponsiveSizeClass {
  compact,
  medium,
  expanded,
}

/// Width (in logical pixels) below which the layout is considered compact.
const double kCompactBreakpoint = 700;

/// Width (in logical pixels) at or above which the layout is considered
/// expanded (the full desktop layout).
const double kExpandedBreakpoint = 1100;

/// Classifies an available [width] into a [ResponsiveSizeClass].
ResponsiveSizeClass responsiveSizeClassForWidth(double width) {
  if (width < kCompactBreakpoint) {
    return ResponsiveSizeClass.compact;
  }
  if (width < kExpandedBreakpoint) {
    return ResponsiveSizeClass.medium;
  }
  return ResponsiveSizeClass.expanded;
}

/// Immutable description of the current responsive layout.
class ResponsiveLayoutInfo {
  const ResponsiveLayoutInfo(this.sizeClass);

  /// Builds the layout info from an available [width].
  factory ResponsiveLayoutInfo.fromWidth(double width) {
    return ResponsiveLayoutInfo(responsiveSizeClassForWidth(width));
  }

  final ResponsiveSizeClass sizeClass;

  bool get isCompact => sizeClass == ResponsiveSizeClass.compact;
  bool get isMedium => sizeClass == ResponsiveSizeClass.medium;
  bool get isExpanded => sizeClass == ResponsiveSizeClass.expanded;

  @override
  bool operator ==(Object other) =>
      other is ResponsiveLayoutInfo && other.sizeClass == sizeClass;

  @override
  int get hashCode => sizeClass.hashCode;

  @override
  String toString() => 'ResponsiveLayoutInfo(${sizeClass.name})';
}
