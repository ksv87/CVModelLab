import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

/// Shared seed color used to derive both the light and dark color schemes.
const Color _seedColor = Color(0xff2563eb);

/// Builds the [ThemeData] for the given [brightness] from the shared seed color.
ThemeData buildAppTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    ),
    useMaterial3: true,
    visualDensity: VisualDensity.compact,
  );
}

/// Maps the user's [AppTheme] selection to a Flutter [ThemeMode].
ThemeMode themeModeFor(AppTheme theme) {
  return switch (theme) {
    AppTheme.system => ThemeMode.system,
    AppTheme.light => ThemeMode.light,
    AppTheme.dark => ThemeMode.dark,
  };
}

/// Exposes the current [AppTheme] selection and a callback to change it.
class AppThemeScope extends InheritedWidget {
  const AppThemeScope({
    required this.theme,
    required this.setTheme,
    required super.child,
    super.key,
  });

  final AppTheme theme;
  final Future<void> Function(AppTheme theme) setTheme;

  static AppThemeScope of(BuildContext context) {
    final AppThemeScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    if (scope == null) {
      throw StateError('AppThemeScope is not available.');
    }
    return scope;
  }

  @override
  bool updateShouldNotify(AppThemeScope oldWidget) {
    return theme != oldWidget.theme;
  }
}
