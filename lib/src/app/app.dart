import 'package:flutter/material.dart';

import '../platform_io/user_preferences.dart';
import '../ui/screens/project_open_screen.dart';
import '../ui/l10n/app_locale_scope.dart';
import '../ui/l10n/app_localizations.dart';
import '../ui/l10n/app_theme_scope.dart';
import 'package:cv_model_lab/cv_model_lab.dart';

class CvModelLabApp extends StatefulWidget {
  const CvModelLabApp({super.key});

  @override
  State<CvModelLabApp> createState() => _CvModelLabAppState();
}

class _CvModelLabAppState extends State<CvModelLabApp> {
  final UserPreferencesStore _preferences = createUserPreferencesStore();
  AppLocale _locale = AppLocale.system;
  AppTheme _theme = AppTheme.system;

  @override
  void initState() {
    super.initState();
    _loadLocale();
    _loadTheme();
  }

  Future<void> _loadLocale() async {
    final String? saved =
        await _preferences.getString(PreferenceKeys.appLocale);
    final AppLocale locale = AppLocale.values.firstWhere(
      (AppLocale value) => value.name == saved,
      orElse: () => AppLocale.system,
    );
    if (mounted) {
      setState(() => _locale = locale);
    }
  }

  Future<void> _setLocale(AppLocale locale) async {
    if (locale == AppLocale.system) {
      await _preferences.remove(PreferenceKeys.appLocale);
    } else {
      await _preferences.setString(PreferenceKeys.appLocale, locale.name);
    }
    if (mounted) {
      setState(() => _locale = locale);
    }
  }

  Future<void> _loadTheme() async {
    final String? saved =
        await _preferences.getString(PreferenceKeys.appTheme);
    final AppTheme theme = AppTheme.values.firstWhere(
      (AppTheme value) => value.name == saved,
      orElse: () => AppTheme.system,
    );
    if (mounted) {
      setState(() => _theme = theme);
    }
  }

  Future<void> _setTheme(AppTheme theme) async {
    if (theme == AppTheme.system) {
      await _preferences.remove(PreferenceKeys.appTheme);
    } else {
      await _preferences.setString(PreferenceKeys.appTheme, theme.name);
    }
    if (mounted) {
      setState(() => _theme = theme);
    }
  }

  AppLocale _effectiveLocale() {
    if (_locale != AppLocale.system) {
      return _locale;
    }
    final String code =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return code == 'ru' ? AppLocale.ru : AppLocale.en;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations =
        AppLocalizations.forLocale(_effectiveLocale());
    return AppLocaleScope(
      locale: _locale,
      localizations: localizations,
      setLocale: _setLocale,
      child: AppThemeScope(
        theme: _theme,
        setTheme: _setTheme,
        child: MaterialApp(
          title: 'CV Model Lab',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: themeModeFor(_theme),
          home: const ProjectOpenScreen(),
        ),
      ),
    );
  }
}
