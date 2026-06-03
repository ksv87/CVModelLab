import 'dart:ui';

import 'package:cv_model_lab/src/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows project open screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const CvModelLabApp());

    expect(find.text('CV Model Lab'), findsOneWidget);
    expect(find.text('Open Dataset'), findsOneWidget);
  });
}
