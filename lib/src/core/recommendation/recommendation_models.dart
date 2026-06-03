import '../i18n/message_key.dart';

enum RecommendationSeverity {
  info,
  warning,
  critical,
}

enum RecommendationCategory {
  dataCollection,
  annotationQuality,
  classImbalance,
  smallObjects,
  falsePositives,
  falseNegatives,
  classConfusion,
  modelComparison,
  thresholds,
  datasetHealth,
  scoreCalibration,
}

class Recommendation {
  const Recommendation({
    required this.severity,
    required this.category,
    required this.messageKey,
    this.title = '',
    this.message = '',
    this.action = '',
    this.relatedImageIds = const <int>[],
    this.relatedCategoryIds = const <int>[],
    this.evidence = const <String, Object?>{},
  });

  final RecommendationSeverity severity;
  final RecommendationCategory category;
  final MessageKey messageKey;
  final String title;
  final String message;
  final String action;
  final List<int> relatedImageIds;
  final List<int> relatedCategoryIds;
  final Map<String, Object?> evidence;
}

class RecommendationConfig {
  const RecommendationConfig({
    required this.lowRecallThreshold,
    required this.lowPrecisionThreshold,
    required this.rareClassThreshold,
    required this.classImbalancePercentThreshold,
    required this.highConfidenceFpThreshold,
    required this.smallObjectRecallGapThreshold,
    required this.minIssueCountForCritical,
  });

  const RecommendationConfig.defaults()
      : lowRecallThreshold = 0.5,
        lowPrecisionThreshold = 0.5,
        rareClassThreshold = 10,
        classImbalancePercentThreshold = 0.05,
        highConfidenceFpThreshold = 0.7,
        smallObjectRecallGapThreshold = 0.25,
        minIssueCountForCritical = 10;

  final double lowRecallThreshold;
  final double lowPrecisionThreshold;
  final int rareClassThreshold;
  final double classImbalancePercentThreshold;
  final double highConfidenceFpThreshold;
  final double smallObjectRecallGapThreshold;
  final int minIssueCountForCritical;
}
