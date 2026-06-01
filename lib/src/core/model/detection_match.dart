import 'annotation.dart';
import 'prediction.dart';

enum DetectionMatchType {
  truePositive,
  falsePositive,
  falseNegative,
  ignored,
}

class DetectionMatchReason {
  static const String matched = 'matched';
  static const String noMatchingGroundTruth = 'no_matching_ground_truth';
  static const String duplicatePrediction = 'duplicate_prediction';
  static const String wrongClass = 'wrong_class';
  static const String lowIou = 'low_iou';
  static const String missedGroundTruth = 'missed_ground_truth';
  static const String ignoredCrowd = 'ignored_crowd';
  static const String belowConfidenceThreshold = 'below_confidence_threshold';
}

class DetectionMatch {
  const DetectionMatch({
    required this.type,
    required this.imageId,
    required this.categoryId,
    this.groundTruth,
    this.prediction,
    this.iou,
    this.reason,
  });

  final DetectionMatchType type;
  final int imageId;
  final int? categoryId;
  final GroundTruthAnnotation? groundTruth;
  final Prediction? prediction;
  final double? iou;
  final String? reason;
}
