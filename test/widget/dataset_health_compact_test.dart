import 'dart:typed_data';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:cv_model_lab/src/ui/l10n/app_locale_scope.dart';
import 'package:cv_model_lab/src/ui/l10n/app_localizations_en.dart';
import 'package:cv_model_lab/src/ui/screens/dataset_health_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return AppLocaleScope(
      locale: AppLocale.en,
      localizations: const AppLocalizationsEn(),
      setLocale: (_) async {},
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  DatasetHealthScreen buildScreen() {
    final dataset = CocoDataset(
      imagesById: const {
        1: ImageRecord(id: 1, fileName: 'missing.jpg', width: 100, height: 100),
        2: ImageRecord(id: 2, fileName: 'b.jpg', width: 100, height: 100),
      },
      categoriesById: const {
        1: CategoryRecord(id: 1, name: 'red'),
      },
      annotations: <GroundTruthAnnotation>[
        GroundTruthAnnotation(
          id: 1,
          imageId: 1,
          categoryId: 1,
          bbox: const BBox(x: 0, y: 0, width: 50, height: 50),
        ),
      ],
    );
    final report = const DatasetHealthChecker().check(
      dataset: dataset,
      predictions: const <Prediction>[],
      imageAvailability: const DatasetImageAvailability(
        missingFileNames: {'missing.jpg'},
        available: true,
      ),
    );
    expect(report.issues, isNotEmpty);
    return DatasetHealthScreen(
      report: report,
      dataset: dataset,
      matchesByImageId: const {},
      loadImageBytes: (_) async => Uint8List(0),
      onImageSelected: (_) {},
    );
  }

  testWidgets('Health screen renders as cards without overflow on compact',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(380, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(buildScreen()));
    await tester.pump();

    // Compact layout uses issue cards, not the wide 3-panel DataTable.
    expect(find.byType(Card), findsWidgets);
    expect(find.byType(DataTable), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
