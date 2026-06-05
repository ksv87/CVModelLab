import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:cv_model_lab/src/platform_io/image_source.dart';
import 'package:cv_model_lab/src/ui/l10n/app_locale_scope.dart';
import 'package:cv_model_lab/src/ui/l10n/app_localizations_en.dart';
import 'package:cv_model_lab/src/ui/l10n/app_theme_scope.dart';
import 'package:cv_model_lab/src/ui/screens/workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return AppLocaleScope(
      locale: AppLocale.en,
      localizations: const AppLocalizationsEn(),
      setLocale: (_) async {},
      child: AppThemeScope(
        theme: AppTheme.system,
        setTheme: (_) async {},
        child: MaterialApp(home: child),
      ),
    );
  }

  WorkspaceScreen buildWorkspace() {
    final dataset = CocoDataset(
      imagesById: const {
        1: ImageRecord(id: 1, fileName: 'a.jpg', width: 200, height: 200),
        2: ImageRecord(id: 2, fileName: 'b.jpg', width: 200, height: 200),
      },
      categoriesById: const {
        1: CategoryRecord(id: 1, name: 'red'),
      },
      annotations: <GroundTruthAnnotation>[
        GroundTruthAnnotation(
          id: 1,
          imageId: 1,
          categoryId: 1,
          bbox: const BBox(x: 0, y: 0, width: 100, height: 100),
        ),
      ],
    );
    final run = ModelRun(
      id: 'run',
      name: 'Run',
      predictions: <Prediction>[
        const Prediction(
          imageId: 1,
          categoryId: 1,
          bbox: BBox(x: 0, y: 0, width: 100, height: 100),
          score: 0.9,
        ),
        const Prediction(
          imageId: 2,
          categoryId: 1,
          bbox: BBox(x: 0, y: 0, width: 40, height: 40),
          score: 0.8,
        ),
      ],
    );
    final eval = const MetricsCalculator().evaluate(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );
    return WorkspaceScreen(
      projectName: 'Test project',
      dataset: dataset,
      modelRunEntries: [ModelRunEntry(modelRun: run, evalResult: eval)],
      imageSource: const EmptyImageSource(),
      issues: const <ParseIssue>[],
    );
  }

  testWidgets('compact width shows bottom NavigationBar, not NavigationRail',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(buildWorkspace()));
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    // No overflow errors should have been recorded while laying out compact.
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded width keeps the desktop NavigationRail layout',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(buildWorkspace()));
    await tester.pump();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
