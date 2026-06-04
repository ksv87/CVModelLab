import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import '../l10n/app_locale_scope.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_theme_scope.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  IconData _iconFor(AppTheme theme) {
    return switch (theme) {
      AppTheme.system => Icons.brightness_auto_outlined,
      AppTheme.light => Icons.light_mode_outlined,
      AppTheme.dark => Icons.dark_mode_outlined,
    };
  }

  String _labelFor(AppTheme theme, AppLocalizations l10n) {
    return switch (theme) {
      AppTheme.system => l10n.t(MessageKey.themeSystem),
      AppTheme.light => l10n.t(MessageKey.themeLight),
      AppTheme.dark => l10n.t(MessageKey.themeDark),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeScope scope = AppThemeScope.of(context);
    final AppLocalizations l10n = AppLocaleScope.l10n(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    return PopupMenuButton<AppTheme>(
      icon: Icon(_iconFor(scope.theme)),
      tooltip: l10n.t(MessageKey.themeTooltip),
      onSelected: scope.setTheme,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<AppTheme>>[
        for (final AppTheme theme in AppTheme.values)
          PopupMenuItem<AppTheme>(
            value: theme,
            child: Row(
              children: <Widget>[
                Icon(
                  _iconFor(theme),
                  size: 20,
                  color: theme == scope.theme ? colors.primary : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_labelFor(theme, l10n))),
                if (theme == scope.theme)
                  Icon(Icons.check, size: 18, color: colors.primary),
              ],
            ),
          ),
      ],
    );
  }
}
