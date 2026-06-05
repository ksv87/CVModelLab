import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:cv_model_lab/src/platform_io/image_source.dart';
import 'package:cv_model_lab/src/ui/l10n/app_locale_scope.dart';
import 'package:cv_model_lab/src/ui/l10n/app_localizations_ru.dart';
import 'package:cv_model_lab/src/ui/l10n/app_theme_scope.dart';
import 'package:cv_model_lab/src/ui/screens/workspace_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desktop 1312x848 (RU) has no layout overflow across pages',
      (WidgetTester tester) async {
    final List<String> overflows = [];
    final FlutterExceptionHandler? prev = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed')) {
        overflows.add(details.exceptionAsString().split('\n').first);
      }
    };
    addTearDown(() => FlutterError.onError = prev);

    tester.view.physicalSize = const Size(1312, 848);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final images = <int, ImageRecord>{};
    final anns = <GroundTruthAnnotation>[];
    final preds = <Prediction>[];
    final cats = <int, CategoryRecord>{
      1: const CategoryRecord(id: 1, name: 'пешеход'),
      2: const CategoryRecord(id: 2, name: 'легковой автомобиль'),
      3: const CategoryRecord(id: 3, name: 'грузовой автомобиль с прицепом'),
      4: const CategoryRecord(id: 4, name: 'светофор'),
    };
    int aid = 1;
    for (int i = 1; i <= 24; i++) {
      images[i] = ImageRecord(
        id: i,
        fileName: i == 7 ? 'нет_файла_$i.jpg' : 'кадр_$i.jpg',
        width: 640,
        height: 480,
      );
      final int cat = (i % 4) + 1;
      anns.add(
        GroundTruthAnnotation(
          id: aid++,
          imageId: i,
          categoryId: cat,
          bbox: BBox(
            x: 10,
            y: 10,
            width: i.isEven ? 8 : 120,
            height: i.isEven ? 8 : 120,
          ),
        ),
      );
      if (i % 3 != 0) {
        preds.add(
          Prediction(
            imageId: i,
            categoryId: i % 5 == 0 ? (cat % 4) + 1 : cat,
            bbox: const BBox(x: 12, y: 12, width: 110, height: 110),
            score: 0.95,
          ),
        );
      }
    }
    final dataset =
        CocoDataset(imagesById: images, categoriesById: cats, annotations: anns);
    final run = ModelRun(id: 'run', name: 'Базовая модель', predictions: preds);
    final eval = const MetricsCalculator()
        .evaluate(dataset: dataset, modelRun: run, config: const EvalConfig());

    await tester.pumpWidget(
      AppLocaleScope(
        locale: AppLocale.ru,
        localizations: const AppLocalizationsRu(),
        setLocale: (_) async {},
        child: AppThemeScope(
          theme: AppTheme.system,
          setTheme: (_) async {},
          child: MaterialApp(
            home: WorkspaceScreen(
              projectName: 'Демонстрационный проект',
              dataset: dataset,
              modelRunEntries: [
                ModelRunEntry(modelRun: run, evalResult: eval),
              ],
              imageSource: const EmptyImageSource(['нет_файла_7.jpg']),
              issues: const <ParseIssue>[],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    const List<IconData> pages = [
      Icons.assessment,
      Icons.photo_library,
      Icons.check_circle,
      Icons.grid_on,
      Icons.list,
      Icons.tips_and_updates,
    ];
    for (final IconData icon in pages) {
      await tester.tap(find.byIcon(icon).first);
      await tester.pump();
    }

    expect(overflows, isEmpty, reason: overflows.toSet().join('\n'));
  });
}
