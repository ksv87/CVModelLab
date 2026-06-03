import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/src/ui/l10n/app_localizations.dart';

// Multi-model UI labels and report headings introduced in v0.6.0.
const List<MessageKey> _multiModelKeys = [
  MessageKey.mmMultiModelComparison,
  MessageKey.mmPairwiseMode,
  MessageKey.mmMultiModelMode,
  MessageKey.mmLeaderboard,
  MessageKey.mmPerClassRanking,
  MessageKey.mmImageDisagreement,
  MessageKey.mmRegressionMatrix,
  MessageKey.mmCompareViewer,
  MessageKey.mmAllModelsCorrect,
  MessageKey.mmAllModelsWrong,
  MessageKey.mmSomeModelsWrong,
  MessageKey.mmOnlyOneModelCorrect,
  MessageKey.mmOnlyOneModelWrong,
  MessageKey.mmClassDisagreement,
  MessageKey.mmLargeErrorSpread,
  MessageKey.mmPredictionCountDisagreement,
  MessageKey.mmApNotComputed,
  MessageKey.mmSelectTwoRuns,
  MessageKey.mmOpenPairwise,
  MessageKey.mmBestModel,
  MessageKey.mmWorstModel,
  MessageKey.mmF1Spread,
  MessageKey.mmErrorSpread,
  MessageKey.mmRankingMetric,
  MessageKey.mmHideAllCorrect,
  MessageKey.mmIncludeAp,
  MessageKey.mmMakeActiveModel,
];

void main() {
  final en = AppLocalizations.forLocale(AppLocale.en);
  final ru = AppLocalizations.forLocale(AppLocale.ru);

  test('all multi-model keys resolve in English and Russian', () {
    for (final MessageKey key in _multiModelKeys) {
      expect(en.lookup(key, const {}), isNotNull, reason: 'EN $key');
      expect(en.lookup(key, const {})!.trim(), isNotEmpty, reason: 'EN $key');
      expect(ru.lookup(key, const {}), isNotNull, reason: 'RU $key');
      expect(ru.lookup(key, const {})!.trim(), isNotEmpty, reason: 'RU $key');
    }
  });

  test('empty-state strings match the specification', () {
    expect(
      en.t(MessageKey.mmSelectTwoRuns),
      'Add at least two model runs to compare models.',
    );
    expect(
      ru.t(MessageKey.mmSelectTwoRuns),
      'Добавьте минимум два запуска модели для сравнения.',
    );
  });

  test('disagreement type labels are localized for every enum value', () {
    for (final ImageDisagreementType type in ImageDisagreementType.values) {
      expect(en.multiModelDisagreementType(type), isNotEmpty);
      expect(ru.multiModelDisagreementType(type), isNotEmpty);
    }
    expect(
      en.multiModelDisagreementType(ImageDisagreementType.onlyOneModelCorrect),
      'Only one model correct',
    );
    expect(
      ru.multiModelDisagreementType(ImageDisagreementType.onlyOneModelCorrect),
      'Только одна модель верна',
    );
  });

  test('ranking metric labels resolve for every enum value', () {
    for (final MultiModelRankingMetric metric
        in MultiModelRankingMetric.values) {
      expect(en.multiModelRankingMetric(metric), isNotEmpty);
      expect(ru.multiModelRankingMetric(metric), isNotEmpty);
    }
  });

  test('missing translation falls back to English', () {
    const localizations = _EmptyLocalizations();
    expect(localizations.t(MessageKey.mmLeaderboard), 'Leaderboard');
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
