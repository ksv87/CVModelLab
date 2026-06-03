import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import '../l10n/app_locale_scope.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocaleScope scope = AppLocaleScope.of(context);
    return DropdownButton<AppLocale>(
      value: scope.locale,
      underline: const SizedBox.shrink(),
      items: const [
        DropdownMenuItem(
          value: AppLocale.system,
          child: Text('System'),
        ),
        DropdownMenuItem(
          value: AppLocale.en,
          child: Text('English'),
        ),
        DropdownMenuItem(
          value: AppLocale.ru,
          child: Text('Русский'),
        ),
      ],
      onChanged: (AppLocale? value) {
        if (value != null) {
          scope.setLocale(value);
        }
      },
    );
  }
}
