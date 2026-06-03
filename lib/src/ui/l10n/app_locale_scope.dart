import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

class AppLocaleScope extends InheritedWidget {
  const AppLocaleScope({
    required this.locale,
    required this.localizations,
    required this.setLocale,
    required super.child,
    super.key,
  });

  final AppLocale locale;
  final AppLocalizations localizations;
  final Future<void> Function(AppLocale locale) setLocale;

  static AppLocaleScope of(BuildContext context) {
    final AppLocaleScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
    if (scope == null) {
      throw StateError('AppLocaleScope is not available.');
    }
    return scope;
  }

  static AppLocalizations l10n(BuildContext context) =>
      of(context).localizations;

  @override
  bool updateShouldNotify(AppLocaleScope oldWidget) {
    return locale != oldWidget.locale ||
        localizations.locale != oldWidget.localizations.locale;
  }
}
