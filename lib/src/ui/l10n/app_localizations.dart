import 'package:cv_model_lab/cv_model_lab.dart';

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

abstract class AppLocalizations {
  const AppLocalizations(this.locale);

  final AppLocale locale;

  static AppLocalizations forLocale(AppLocale locale) {
    return switch (locale) {
      AppLocale.ru => const AppLocalizationsRu(),
      AppLocale.en || AppLocale.system => const AppLocalizationsEn(),
    };
  }

  static const AppLocalizations fallback = AppLocalizationsEn();

  String t(MessageKey key, [MessageParams params = const {}]) {
    return lookup(key, params) ??
        fallback.lookup(key, params) ??
        params['fallback']?.toString() ??
        '';
  }

  String? lookup(MessageKey key, MessageParams params);

  String message(LocalizedMessage message) {
    return t(message.key, {
      ...message.params,
      if (message.fallback != null) 'fallback': message.fallback,
    });
  }

  String parseIssue(ParseIssue issue) {
    final MessageKey? key = issue.key;
    if (key == null) return issue.message;
    return t(key, issue.params);
  }

  String datasetIssueTitle(DatasetHealthIssue issue) {
    return _datasetIssuePart(issue, 'title') ?? issue.title;
  }

  String datasetIssueMessage(DatasetHealthIssue issue) {
    return _datasetIssuePart(issue, 'message') ?? issue.message;
  }

  String? datasetIssueRecommendation(DatasetHealthIssue issue) {
    return _datasetIssuePart(issue, 'recommendation') ?? issue.recommendation;
  }

  String recommendationTitle(Recommendation recommendation) {
    return _recommendationPart(recommendation, 'title');
  }

  String recommendationMessage(Recommendation recommendation) {
    return _recommendationPart(recommendation, 'message');
  }

  String recommendationAction(Recommendation recommendation) {
    return _recommendationPart(recommendation, 'action');
  }

  String severity(Object severity) {
    return switch (severity.toString().split('.').last) {
      'critical' => locale == AppLocale.ru ? 'Критично' : 'Critical',
      'warning' => locale == AppLocale.ru ? 'Предупреждение' : 'Warning',
      'error' => locale == AppLocale.ru ? 'Ошибка' : 'Error',
      'info' => locale == AppLocale.ru ? 'Информация' : 'Info',
      _ => severity.toString(),
    };
  }

  String recommendationCategory(RecommendationCategory category) {
    final String name = category.name;
    if (locale != AppLocale.ru) return name;
    return switch (category) {
      RecommendationCategory.dataCollection => 'Сбор данных',
      RecommendationCategory.annotationQuality => 'Качество разметки',
      RecommendationCategory.classImbalance => 'Дисбаланс классов',
      RecommendationCategory.smallObjects => 'Малые объекты',
      RecommendationCategory.falsePositives => 'False positives',
      RecommendationCategory.falseNegatives => 'False negatives',
      RecommendationCategory.classConfusion => 'Путаница классов',
      RecommendationCategory.modelComparison => 'Сравнение моделей',
      RecommendationCategory.thresholds => 'Пороги',
      RecommendationCategory.datasetHealth => 'Качество датасета',
      RecommendationCategory.scoreCalibration => 'Калибровка score',
    };
  }

  /// Localized label for an image-disagreement type.
  String multiModelDisagreementType(ImageDisagreementType type) {
    return t(switch (type) {
      ImageDisagreementType.allCorrect => MessageKey.mmAllModelsCorrect,
      ImageDisagreementType.allWrong => MessageKey.mmAllModelsWrong,
      ImageDisagreementType.someModelsWrong => MessageKey.mmSomeModelsWrong,
      ImageDisagreementType.onlyOneModelCorrect =>
        MessageKey.mmOnlyOneModelCorrect,
      ImageDisagreementType.onlyOneModelWrong =>
        MessageKey.mmOnlyOneModelWrong,
      ImageDisagreementType.predictionCountDisagreement =>
        MessageKey.mmPredictionCountDisagreement,
      ImageDisagreementType.classDisagreement => MessageKey.mmClassDisagreement,
      ImageDisagreementType.largeErrorSpread => MessageKey.mmLargeErrorSpread,
    },);
  }

  /// Label for a leaderboard ranking metric. Universal acronyms (AP, F1, …)
  /// stay untranslated; descriptive metrics are localized.
  String multiModelRankingMetric(MultiModelRankingMetric metric) {
    return switch (metric) {
      MultiModelRankingMetric.ap => 'AP',
      MultiModelRankingMetric.ap50 => 'AP50',
      MultiModelRankingMetric.ap75 => 'AP75',
      MultiModelRankingMetric.precision =>
        locale == AppLocale.ru ? 'Точность' : 'Precision',
      MultiModelRankingMetric.recall =>
        locale == AppLocale.ru ? 'Полнота' : 'Recall',
      MultiModelRankingMetric.f1 => 'F1',
      MultiModelRankingMetric.tp => 'TP',
      MultiModelRankingMetric.fp => 'FP',
      MultiModelRankingMetric.fn => 'FN',
      MultiModelRankingMetric.imagesWithErrors => t(MessageKey.mmImagesWithErrors),
      MultiModelRankingMetric.smallObjectRecall => t(MessageKey.mmSmallRecall),
    };
  }

  String _recommendationPart(Recommendation recommendation, String part) {
    final MessageKey key = recommendation.messageKey;
    return t(key, {
      ...recommendation.evidence,
      'part': part,
    });
  }

  String? _datasetIssuePart(DatasetHealthIssue issue, String part) {
    return datasetIssueLookup(issue.type, part, {
      ...issue.details,
      'image_id': issue.imageId,
      'file_name': issue.fileName,
      'annotation_id': issue.annotationId,
      'category_id': issue.categoryId,
      'category_name': issue.categoryName,
    });
  }

  String? datasetIssueLookup(
    DatasetIssueType type,
    String part,
    MessageParams params,
  );

  String fmtDouble(Object? value, [int digits = 3]) {
    if (value is num) return value.toDouble().toStringAsFixed(digits);
    return value?.toString() ?? '';
  }
}
