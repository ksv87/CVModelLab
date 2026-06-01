import 'package:cv_model_lab/src/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows project open screen', (WidgetTester tester) async {
    await tester.pumpWidget(const CvModelLabApp());

    expect(find.text('CV Model Lab'), findsOneWidget);
    expect(find.text('Open Dataset'), findsOneWidget);
    expect(find.text('Open demo project'), findsOneWidget);
  });
}
