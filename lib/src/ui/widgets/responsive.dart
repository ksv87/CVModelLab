import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/widgets.dart';

/// Flutter glue for the pure [ResponsiveLayoutInfo] breakpoint logic.
///
/// Use [ResponsiveLayoutInfo.of] to read the current size class from the
/// nearest [MediaQuery], or wrap a subtree in [ResponsiveBuilder] when the
/// layout should react to the constraints of a specific region rather than the
/// whole window.
extension ResponsiveContext on BuildContext {
  /// The responsive layout info derived from the current [MediaQuery] width.
  ResponsiveLayoutInfo get responsive => ResponsiveLayoutInfo.fromWidth(
        MediaQuery.sizeOf(this).width,
      );

  /// Convenience: whether the current [MediaQuery] width is compact.
  bool get isCompactWidth => responsive.isCompact;
}

/// Builds different layouts based on the [BoxConstraints] of the region it is
/// placed in, classified through [ResponsiveLayoutInfo].
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({required this.builder, super.key});

  final Widget Function(BuildContext context, ResponsiveLayoutInfo info)
      builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return builder(context, ResponsiveLayoutInfo.fromWidth(width));
      },
    );
  }
}
