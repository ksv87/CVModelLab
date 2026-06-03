import 'dart:io';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/src/ui/l10n/app_localizations.dart';

void main() {
  test('recommendations render in English and Russian', () {
    const recommendation = Recommendation(
      messageKey: MessageKey.recLowRecallClass,
      severity: RecommendationSeverity.warning,
      category: RecommendationCategory.falseNegatives,
      evidence: {'class_name': 'red'},
      relatedCategoryIds: [1],
    );

    final en = AppLocalizations.forLocale(AppLocale.en);
    final ru = AppLocalizations.forLocale(AppLocale.ru);

    expect(en.recommendationTitle(recommendation), contains('Low recall'));
    expect(ru.recommendationTitle(recommendation), contains('Низкий recall'));
    expect(en.recommendationAction(recommendation), isNotEmpty);
    expect(ru.recommendationAction(recommendation), isNotEmpty);
  });

  test('dataset health issues render in English and Russian', () {
    const issue = DatasetHealthIssue(
      type: DatasetIssueType.missingImageFile,
      severity: DatasetIssueSeverity.error,
      fileName: 'missing.jpg',
      details: {'file_name': 'missing.jpg'},
    );

    final en = AppLocalizations.forLocale(AppLocale.en);
    final ru = AppLocalizations.forLocale(AppLocale.ru);

    expect(en.datasetIssueTitle(issue), contains('Missing image file'));
    expect(ru.datasetIssueTitle(issue), contains('Файл изображения'));
    expect(en.datasetIssueMessage(issue), contains('missing.jpg'));
    expect(ru.datasetIssueMessage(issue), contains('missing.jpg'));
  });

  test('parser warnings render in English and Russian', () {
    final result = const CocoAnnotationParser().parseString('{invalid json');
    final issue = result.issues.single;

    expect(issue.key, MessageKey.parseInvalidJson);
    expect(
      AppLocalizations.forLocale(AppLocale.en).parseIssue(issue),
      contains('Invalid JSON'),
    );
    expect(
      AppLocalizations.forLocale(AppLocale.ru).parseIssue(issue),
      contains('Некорректный JSON'),
    );
  });

  test('HTML report uses selected locale for headings', () async {
    final dataset = const CocoAnnotationParser()
        .parseString(
          File('test_data/mini_coco/annotations.json').readAsStringSync(),
        )
        .value!;
    final run = const CocoPredictionParser()
        .parseString(
          File('test_data/mini_coco/predictions.json').readAsStringSync(),
          dataset: dataset,
          modelRunId: 'run-1',
          modelRunName: 'Run 1',
        )
        .value!;
    final evalResult = const MetricsCalculator().evaluate(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );

    final bundle = await const ReportBundleBuilder().build(
      dataset: dataset,
      modelRun: run,
      evalConfig: const EvalConfig(),
      evalResult: evalResult,
      components: const ReportComponents(includeHtml: true),
      locale: AppLocale.ru,
      projectName: 'mini',
      modelRunName: 'Run 1',
    );

    expect(bundle.htmlReport, contains('Отчет CV Model Lab'));
    expect(bundle.htmlReport, contains('Сводка датасета'));
  });

  test('missing translation falls back to English without raw key text', () {
    const localizations = _EmptyLocalizations();

    expect(localizations.t(MessageKey.reportTitle), 'CV Model Lab Report');
    expect(localizations.t(MessageKey.reportTitle), isNot(contains('report')));
  });
}

class _EmptyLocalizations extends AppLocalizations {
  const _EmptyLocalizations() : super(AppLocale.ru);

  @override
  String? lookup(MessageKey key, MessageParams params) => null;

  @override
  String? datasetIssueLookup(
    DatasetIssueType type,
    String part,
    MessageParams params,
  ) =>
      null;
}
