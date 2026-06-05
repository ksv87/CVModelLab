import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:cv_model_lab/src/platform_io/image_source.dart';
import 'package:cv_model_lab/src/ui/l10n/app_locale_scope.dart';
import 'package:cv_model_lab/src/ui/l10n/app_localizations_en.dart';
import 'package:cv_model_lab/src/ui/l10n/app_theme_scope.dart';
import 'package:cv_model_lab/src/ui/screens/workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'desktop worst cases open image browser with selected image visible',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final _WorkspaceFixture fixture = _problemFixture();

    await _pumpWorkspaceShell(tester, fixture);

    await tester.tap(find.text('Worst'));
    await _pumpWorkspace(tester);

    await tester.tap(find.byType(ListTile).first);
    await _pumpWorkspace(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Open in Browser'));
    await _pumpWorkspace(tester);

    expect(find.text('Error Browser'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
  });

  testWidgets('desktop advice opens image browser with selected image visible',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final _WorkspaceFixture fixture = _problemFixture();

    await _pumpWorkspaceShell(tester, fixture);

    await tester.tap(find.text('Advice'));
    await _pumpWorkspace(tester);

    final Finder recommendationWithImages =
        find.textContaining(RegExp(r'^\d+ images$'));
    for (int i = 0; i < 8 && recommendationWithImages.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -360));
      await _pumpWorkspace(tester);
    }
    expect(recommendationWithImages, findsWidgets);

    final Finder recommendationCard = find
        .ancestor(
          of: recommendationWithImages,
          matching: find.byType(Card),
        )
        .first;
    final Finder openImagesButton = find
        .descendant(
          of: recommendationCard,
          matching: find.widgetWithText(OutlinedButton, 'Open images'),
        )
        .first;
    await tester.ensureVisible(openImagesButton);
    await _pumpWorkspace(tester);
    await tester.tap(openImagesButton);
    await _pumpWorkspace(tester);

    expect(find.text('Error Browser'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'img_1.jpg'), findsOneWidget);
  });
}

Future<void> _pumpWorkspaceShell(
  WidgetTester tester,
  _WorkspaceFixture fixture,
) async {
  await tester.pumpWidget(
    AppLocaleScope(
      locale: AppLocale.en,
      localizations: const AppLocalizationsEn(),
      setLocale: (_) async {},
      child: AppThemeScope(
        theme: AppTheme.system,
        setTheme: (_) async {},
        child: MaterialApp(
          home: WorkspaceScreen(
            projectName: 'P',
            dataset: fixture.dataset,
            modelRunEntries: [
              ModelRunEntry(
                modelRun: fixture.run,
                evalResult: fixture.evalResult,
              ),
            ],
            imageSource: const EmptyImageSource(),
            issues: const <ParseIssue>[],
          ),
        ),
      ),
    ),
  );
  await _pumpWorkspace(tester);
}

Future<void> _pumpWorkspace(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

_WorkspaceFixture _problemFixture() {
  final images = <int, ImageRecord>{
    for (int i = 1; i <= 30; i++)
      i: ImageRecord(id: i, fileName: 'img_$i.jpg', width: 200, height: 200),
  };
  final anns = <GroundTruthAnnotation>[
    for (int i = 1; i <= 30; i++)
      GroundTruthAnnotation(
        id: i,
        imageId: i,
        categoryId: 1,
        bbox: const BBox(x: 0, y: 0, width: 100, height: 100),
      ),
  ];
  final preds = <Prediction>[
    const Prediction(
      imageId: 1,
      categoryId: 1,
      bbox: BBox(x: 150, y: 150, width: 30, height: 30),
      score: 0.95,
    ),
    const Prediction(
      imageId: 2,
      categoryId: 1,
      bbox: BBox(x: 150, y: 150, width: 30, height: 30),
      score: 0.9,
    ),
  ];
  final dataset = CocoDataset(
    imagesById: images,
    categoriesById: const {1: CategoryRecord(id: 1, name: 'obj')},
    annotations: anns,
  );
  final run = ModelRun(id: 'run', name: 'Run', predictions: preds);
  final evalResult = const MetricsCalculator().evaluate(
    dataset: dataset,
    modelRun: run,
    config: const EvalConfig(),
  );
  return _WorkspaceFixture(dataset: dataset, run: run, evalResult: evalResult);
}

class _WorkspaceFixture {
  const _WorkspaceFixture({
    required this.dataset,
    required this.run,
    required this.evalResult,
  });

  final CocoDataset dataset;
  final ModelRun run;
  final EvalResult evalResult;
}
