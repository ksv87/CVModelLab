import 'package:cv_model_lab/src/core/platform/platform_capabilities.dart';
import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:cv_model_lab/src/ui/l10n/app_locale_scope.dart';
import 'package:cv_model_lab/src/ui/l10n/app_localizations_en.dart';
import 'package:cv_model_lab/src/ui/l10n/app_theme_scope.dart';
import 'package:cv_model_lab/src/ui/screens/project_open_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mobile home hides local actions and shows server connect',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppLocaleScope(
        locale: AppLocale.en,
        localizations: const AppLocalizationsEn(),
        setLocale: (_) async {},
        child: AppThemeScope(
          theme: AppTheme.system,
          setTheme: (_) async {},
          child: const MaterialApp(
            home: ProjectOpenScreen(capabilities: PlatformCapabilities.mobile),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('CV Model Lab'), findsOneWidget);
    expect(find.text('Remote client mode'), findsOneWidget);
    expect(find.text('Connect to Server'), findsOneWidget);
    expect(find.text('Open Recent Remote Project'), findsWidgets);
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Open Dataset'), findsNothing);
    expect(find.text('Analyze'), findsNothing);
    expect(find.text('Open project'), findsNothing);
    expect(find.text('annotations.json'), findsNothing);
    expect(find.text('predictions.json'), findsNothing);
  });
}
