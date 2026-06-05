import 'dart:typed_data';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:cv_model_lab/src/platform_io/image_source.dart';
import 'package:cv_model_lab/src/ui/l10n/app_locale_scope.dart';
import 'package:cv_model_lab/src/ui/l10n/app_localizations_en.dart';
import 'package:cv_model_lab/src/ui/l10n/app_theme_scope.dart';
import 'package:cv_model_lab/src/ui/screens/workspace_screen.dart';
import 'package:cv_model_lab/src/ui/widgets/mobile_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact: tapping a worst case opens the mobile image viewer',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final images = <int, ImageRecord>{
      for (int i = 1; i <= 6; i++)
        i: ImageRecord(id: i, fileName: 'img_$i.jpg', width: 200, height: 200),
    };
    final anns = <GroundTruthAnnotation>[
      for (int i = 1; i <= 6; i++)
        GroundTruthAnnotation(
          id: i,
          imageId: i,
          categoryId: 1,
          bbox: const BBox(x: 0, y: 0, width: 100, height: 100),
        ),
    ];
    // Predictions that miss some GT (FN) and add wrong boxes (FP) -> worst cases.
    final preds = <Prediction>[
      const Prediction(
        imageId: 2,
        categoryId: 1,
        bbox: BBox(x: 150, y: 150, width: 30, height: 30),
        score: 0.95,
      ),
      const Prediction(
        imageId: 4,
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
    final eval = const MetricsCalculator()
        .evaluate(dataset: dataset, modelRun: run, config: const EvalConfig());

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
              dataset: dataset,
              modelRunEntries: [ModelRunEntry(modelRun: run, evalResult: eval)],
              imageSource: const EmptyImageSource(),
              issues: const <ParseIssue>[],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Go to Metrics tab, then the Worst sub-page.
    await tester.tap(find.text('Metrics'));
    await tester.pump();
    await tester.ensureVisible(find.text('Worst'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Worst'));
    await tester.pumpAndSettle();

    final Finder tile = find.byType(ListTile).first;
    expect(tile, findsWidgets);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.byType(MobileImageViewerPage), findsOneWidget);
  });

  testWidgets('compact: opening an advice image opens the mobile image viewer',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final _WorkspaceFixture fixture = _problemFixture();

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
    await tester.pump();

    await tester.tap(find.text('Metrics'));
    await tester.pump();
    await tester.ensureVisible(find.text('Advice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advice'));
    await tester.pumpAndSettle();

    final Finder recommendationWithImages =
        find.textContaining(RegExp(r'^\d+ images$'));
    for (int i = 0; i < 8 && recommendationWithImages.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -360));
      await tester.pumpAndSettle();
    }
    expect(recommendationWithImages, findsWidgets);
    await tester.ensureVisible(recommendationWithImages.first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();
    await tester.tap(openImagesButton);
    await tester.pumpAndSettle();

    expect(find.byType(MobileImageViewerPage), findsOneWidget);
  });

  testWidgets('mobile viewer: next-error skips clean images',
      (WidgetTester tester) async {
    final images = <int, ImageRecord>{
      for (int i = 1; i <= 5; i++)
        i: ImageRecord(id: i, fileName: 'img_$i.jpg', width: 100, height: 100),
    };
    final dataset = CocoDataset(
      imagesById: images,
      categoriesById: const {1: CategoryRecord(id: 1, name: 'obj')},
      annotations: const <GroundTruthAnnotation>[],
    );

    await tester.pumpWidget(
      AppLocaleScope(
        locale: AppLocale.en,
        localizations: const AppLocalizationsEn(),
        setLocale: (_) async {},
        child: MaterialApp(
          home: MobileImageViewerPage(
            dataset: dataset,
            categoriesById: dataset.categoriesById,
            imageIds: const [1, 2, 3, 4, 5],
            errorImageIds: const {1, 4},
            initialImageId: 1,
            matchesFor: (_) => const <DetectionMatch>[],
            loadImageBytes: (_) async => Uint8List(0),
            modelRunName: 'Run',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1 / 5'), findsOneWidget);
    // Next error should jump straight to image 4 (index 3), skipping 2 and 3.
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pump();
    expect(find.text('4 / 5'), findsOneWidget);
  });
}

_WorkspaceFixture _problemFixture() {
  final images = <int, ImageRecord>{
    for (int i = 1; i <= 8; i++)
      i: ImageRecord(id: i, fileName: 'img_$i.jpg', width: 200, height: 200),
  };
  final anns = <GroundTruthAnnotation>[
    for (int i = 1; i <= 8; i++)
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
