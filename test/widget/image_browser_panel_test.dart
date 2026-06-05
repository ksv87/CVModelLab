import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:cv_model_lab/src/ui/widgets/image_browser_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const PageStorageKey<String> imageListKey =
      PageStorageKey<String>('image-browser-list-project-filters');

  Finder imageListScrollable() => find
      .descendant(
        of: find.byKey(imageListKey),
        matching: find.byType(Scrollable),
      )
      .first;

  late CocoDataset dataset;
  late ModelRun run;
  late FilteredEvalView view;

  setUp(() {
    dataset = CocoDataset(
      imagesById: {
        for (int i = 1; i <= 30; i++)
          i: ImageRecord(
            id: i,
            fileName: 'img_$i.jpg',
            width: 200,
            height: 200,
          ),
      },
      categoriesById: const {
        1: CategoryRecord(id: 1, name: 'obj'),
      },
      annotations: [
        for (int i = 1; i <= 30; i++)
          GroundTruthAnnotation(
            id: i,
            imageId: i,
            categoryId: 1,
            bbox: const BBox(x: 0, y: 0, width: 100, height: 100),
          ),
      ],
    );
    run = ModelRun(
      id: 'run',
      name: 'Run',
      predictions: [
        for (int i = 1; i <= 30; i++)
          Prediction(
            imageId: i,
            categoryId: 1,
            bbox: const BBox(x: 0, y: 0, width: 100, height: 100),
            score: 0.9,
          ),
      ],
    );
    final EvalResult eval = const MetricsCalculator().evaluate(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );
    view = const EvalResultFilter().apply(
      dataset: dataset,
      modelRun: run,
      evalResult: eval,
      missingImageFileNames: const <String>{},
      filter: const EvalViewFilter(),
    );
  });

  testWidgets(
      'desktop browser list keeps its scroll position when an item is selected',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: ImageBrowserPanel(
              dataset: dataset,
              view: view,
              filter: const EvalViewFilter(),
              selectedImageId: 15,
              onFilterChanged: (_) {},
              onImageSelected: (_) {},
              onResetFilters: () {},
              showFilters: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder scrollableFinder = imageListScrollable();
    final ScrollableState scrollableState =
        tester.state<ScrollableState>(scrollableFinder);

    expect(scrollableState.position.pixels, 0);
  });

  testWidgets('desktop browser scrolls selected image on external request',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget build({required int selectedImageId, required int scrollRequest}) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: ImageBrowserPanel(
              dataset: dataset,
              view: view,
              filter: const EvalViewFilter(),
              selectedImageId: selectedImageId,
              scrollToSelectedRequest: scrollRequest,
              onFilterChanged: (_) {},
              onImageSelected: (_) {},
              onResetFilters: () {},
              showFilters: true,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(build(selectedImageId: 1, scrollRequest: 0));
    await tester.pumpAndSettle();

    ScrollableState scrollableState = tester.state<ScrollableState>(
      imageListScrollable(),
    );
    expect(scrollableState.position.pixels, 0);

    await tester.pumpWidget(build(selectedImageId: 25, scrollRequest: 0));
    await tester.pumpAndSettle();
    scrollableState = tester.state<ScrollableState>(
      imageListScrollable(),
    );
    expect(scrollableState.position.pixels, 0);

    await tester.pumpWidget(build(selectedImageId: 25, scrollRequest: 1));
    await tester.pumpAndSettle();
    scrollableState = tester.state<ScrollableState>(
      imageListScrollable(),
    );
    expect(scrollableState.position.pixels, greaterThan(0));
  });

  testWidgets('desktop browser external request shows early image immediately',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: ImageBrowserPanel(
              dataset: dataset,
              view: view,
              filter: const EvalViewFilter(),
              selectedImageId: 2,
              scrollToSelectedRequest: 1,
              onFilterChanged: (_) {},
              onImageSelected: (_) {},
              onResetFilters: () {},
              showFilters: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ScrollableState scrollableState = tester.state<ScrollableState>(
      imageListScrollable(),
    );
    expect(scrollableState.position.pixels, lessThan(120));
    final Rect selectedTile =
        tester.getRect(find.widgetWithText(ListTile, 'img_2.jpg'));
    expect(selectedTile.top, greaterThan(0));
    expect(selectedTile.bottom, lessThan(tester.view.physicalSize.height));
  });

  testWidgets('desktop browser centers a far selected image on external request',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget build({required int scrollRequest}) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 340,
              child: ImageBrowserPanel(
                dataset: dataset,
                view: view,
                filter: const EvalViewFilter(),
                selectedImageId: 25,
                scrollToSelectedRequest: scrollRequest,
                onFilterChanged: (_) {},
                onImageSelected: (_) {},
                onResetFilters: () {},
                showFilters: true,
              ),
            ),
          ),
        );

    await tester.pumpWidget(build(scrollRequest: 0));
    await tester.pumpAndSettle();
    // Not requested: the far image stays off-screen (not built).
    expect(find.widgetWithText(ListTile, 'img_25.jpg'), findsNothing);

    await tester.pumpWidget(build(scrollRequest: 1));
    await tester.pumpAndSettle();

    final Finder tile = find.widgetWithText(ListTile, 'img_25.jpg');
    expect(tile, findsOneWidget);
    // The target is actually revealed on screen (centered), not overshot far
    // below or above the viewport.
    final Rect rect = tester.getRect(tile);
    expect(rect.top, greaterThanOrEqualTo(0.0));
    expect(rect.bottom, lessThanOrEqualTo(900.0));
  });

  testWidgets('compact browser omits the panel header and count chrome',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageBrowserPanel(
            dataset: dataset,
            view: view,
            filter: const EvalViewFilter(),
            selectedImageId: 1,
            onFilterChanged: (_) {},
            onImageSelected: (_) {},
            onResetFilters: () {},
            showFilters: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The surrounding compact tab already renders these, so the panel must not
    // duplicate the title, the filter toggle or the image count.
    expect(find.text('Error Browser'), findsNothing);
    expect(find.text('Filters'), findsNothing);
    expect(find.textContaining('images'), findsNothing);
    expect(find.byType(ListTile), findsWidgets);
  });

  testWidgets('desktop filters are collapsed by default and expand on tap',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: ImageBrowserPanel(
              dataset: dataset,
              view: view,
              filter: const EvalViewFilter(),
              selectedImageId: 1,
              onFilterChanged: (_) {},
              onImageSelected: (_) {},
              onResetFilters: () {},
              showFilters: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Collapsed: only the toggle is shown, no filter controls yet.
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Image filter'), findsNothing);

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Image filter'), findsOneWidget);
  });
}
