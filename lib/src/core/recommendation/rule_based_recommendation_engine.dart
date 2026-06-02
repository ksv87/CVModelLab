import '../ap_eval/ap_eval_models.dart';
import '../comparison/comparison_models.dart';
import '../eval/class_stats.dart';
import '../eval/confusion_details.dart';
import '../eval/small_object_stats.dart';
import '../health/dataset_health_models.dart';
import '../model/coco_dataset.dart';
import '../model/detection_match.dart';
import '../model/eval_config.dart';
import '../model/eval_result.dart';
import '../model/model_run.dart';
import '../worst_cases/worst_case_models.dart';
import 'recommendation_models.dart';

class RuleBasedRecommendationEngine {
  const RuleBasedRecommendationEngine();

  List<Recommendation> build({
    required CocoDataset dataset,
    required ModelRun modelRun,
    required EvalResult evalResult,
    required EvalConfig evalConfig,
    RecommendationConfig config = const RecommendationConfig.defaults(),
    DatasetHealthReport? healthReport,
    WorstCasesResult? worstCases,
    ModelComparisonResult? comparison,
    ApEvalResult? apEvalResult,
  }) {
    final List<Recommendation> recommendations = [];
    _addClassMetricRecommendations(recommendations, evalResult, config);
    _addClassImbalanceRecommendation(recommendations, evalResult, config);
    _addSmallObjectRecommendations(recommendations, dataset, evalResult, config);
    _addHighConfidenceFpRecommendation(
      recommendations,
      evalResult,
      config,
      worstCases,
    );
    _addManyFnRecommendation(recommendations, evalResult, config);
    _addClassConfusionRecommendations(
      recommendations,
      dataset,
      modelRun,
      evalResult,
      evalConfig,
      config,
      worstCases,
    );
    _addDatasetHealthRecommendation(recommendations, healthReport, config);
    _addComparisonRecommendation(recommendations, comparison, config);
    _addThresholdRecommendations(recommendations, evalResult, config);

    recommendations.sort(_compareRecommendations);
    return recommendations;
  }

  void _addClassMetricRecommendations(
    List<Recommendation> out,
    EvalResult evalResult,
    RecommendationConfig config,
  ) {
    final List<ClassStats> stats = evalResult.perClassStats.values.toList()
      ..sort((ClassStats a, ClassStats b) => a.categoryId.compareTo(b.categoryId));
    for (final ClassStats stat in stats) {
      if (stat.gtCount > 0 && stat.recall < config.lowRecallThreshold) {
        out.add(
          Recommendation(
            severity: _severityForCount(stat.fn, config),
            category: RecommendationCategory.falseNegatives,
            title: 'Low recall for class "${stat.categoryName}"',
            message: 'The model misses many objects of this class.',
            action:
                'Inspect false negatives, check annotation consistency, add more examples, and consider resolution/augmentation changes.',
            relatedCategoryIds: [stat.categoryId],
            evidence: {
              'class_id': stat.categoryId,
              'class_name': stat.categoryName,
              'recall': stat.recall,
              'fn': stat.fn,
              'gt_count': stat.gtCount,
            },
          ),
        );
      }
      if (stat.predCount > 0 &&
          stat.precision < config.lowPrecisionThreshold) {
        out.add(
          Recommendation(
            severity: _severityForCount(stat.fp, config),
            category: RecommendationCategory.falsePositives,
            title: 'Low precision for class "${stat.categoryName}"',
            message: 'Many predictions for this class are false positives.',
            action:
                'Inspect false positives, add hard negatives, review class taxonomy and score threshold.',
            relatedCategoryIds: [stat.categoryId],
            evidence: {
              'class_id': stat.categoryId,
              'class_name': stat.categoryName,
              'precision': stat.precision,
              'fp': stat.fp,
              'pred_count': stat.predCount,
            },
          ),
        );
      }
      if (stat.gtCount > 0 && stat.gtCount < config.rareClassThreshold) {
        out.add(
          Recommendation(
            severity: RecommendationSeverity.info,
            category: RecommendationCategory.dataCollection,
            title: 'Rare class "${stat.categoryName}"',
            message: 'This class has too few ground-truth examples.',
            action:
                'Collect more samples or avoid trusting metrics for this class.',
            relatedCategoryIds: [stat.categoryId],
            evidence: {
              'class_id': stat.categoryId,
              'class_name': stat.categoryName,
              'gt_count': stat.gtCount,
              'rare_class_threshold': config.rareClassThreshold,
            },
          ),
        );
      }
    }
  }

  void _addClassImbalanceRecommendation(
    List<Recommendation> out,
    EvalResult evalResult,
    RecommendationConfig config,
  ) {
    final int totalGt = evalResult.perClassStats.values.fold(
      0,
      (int sum, ClassStats stat) => sum + stat.gtCount,
    );
    if (totalGt == 0) {
      return;
    }
    final List<ClassStats> underrepresented = evalResult.perClassStats.values
        .where(
          (ClassStats stat) =>
              stat.gtCount > 0 &&
              stat.gtCount / totalGt < config.classImbalancePercentThreshold,
        )
        .toList()
      ..sort((ClassStats a, ClassStats b) => a.categoryId.compareTo(b.categoryId));
    if (underrepresented.isEmpty) {
      return;
    }
    out.add(
      Recommendation(
        severity: RecommendationSeverity.warning,
        category: RecommendationCategory.classImbalance,
        title: 'Class imbalance detected',
        message:
            'Some classes have a very small share of the ground-truth objects.',
        action: 'Collect or oversample underrepresented classes.',
        relatedCategoryIds: [
          for (final ClassStats stat in underrepresented) stat.categoryId,
        ],
        evidence: {
          'total_gt': totalGt,
          'class_imbalance_percent_threshold':
              config.classImbalancePercentThreshold,
          'classes': [
            for (final ClassStats stat in underrepresented)
              {
                'class_id': stat.categoryId,
                'class_name': stat.categoryName,
                'gt_count': stat.gtCount,
                'percent': stat.gtCount / totalGt,
              },
          ],
        },
      ),
    );
  }

  void _addSmallObjectRecommendations(
    List<Recommendation> out,
    CocoDataset dataset,
    EvalResult evalResult,
    RecommendationConfig config,
  ) {
    final List<int> classIds = evalResult.smallObjectStats.keys.toList()
      ..sort();
    for (final int classId in classIds) {
      final Map<ObjectSizeBucket, SmallObjectClassStats> buckets =
          evalResult.smallObjectStats[classId]!;
      final SmallObjectClassStats? small = buckets[ObjectSizeBucket.small];
      if (small == null || small.gtCount == 0) {
        continue;
      }
      final double mediumRecall =
          buckets[ObjectSizeBucket.medium]?.gtCount == 0
              ? 0
              : buckets[ObjectSizeBucket.medium]?.recall ?? 0;
      final double largeRecall = buckets[ObjectSizeBucket.large]?.gtCount == 0
          ? 0
          : buckets[ObjectSizeBucket.large]?.recall ?? 0;
      final double referenceRecall = mediumRecall > largeRecall
          ? mediumRecall
          : largeRecall;
      final double gap = referenceRecall - small.recall;
      if (referenceRecall <= 0 ||
          gap < config.smallObjectRecallGapThreshold) {
        continue;
      }
      final String className = dataset.categoriesById[classId]?.name ?? '$classId';
      out.add(
        Recommendation(
          severity: _severityForCount(small.fn, config),
          category: RecommendationCategory.smallObjects,
          title: 'Small object performance is weak',
          message:
              'Small objects for "$className" have much lower recall than larger objects.',
          action:
              'Consider higher input resolution, tiling, more small-object samples, or reviewing tiny annotations.',
          relatedCategoryIds: [classId],
          evidence: {
            'class_id': classId,
            'class_name': className,
            'small_recall': small.recall,
            'reference_recall': referenceRecall,
            'recall_gap': gap,
            'small_gt_count': small.gtCount,
            'small_fn': small.fn,
          },
        ),
      );
    }
  }

  void _addHighConfidenceFpRecommendation(
    List<Recommendation> out,
    EvalResult evalResult,
    RecommendationConfig config,
    WorstCasesResult? worstCases,
  ) {
    final List<DetectionMatch> highConfidenceFp = evalResult.matches
        .where(
          (DetectionMatch match) =>
              match.type == DetectionMatchType.falsePositive &&
              (match.prediction?.score ?? 0) >
                  config.highConfidenceFpThreshold,
        )
        .toList()
      ..sort((DetectionMatch a, DetectionMatch b) {
        final int byScore =
            (b.prediction?.score ?? 0).compareTo(a.prediction?.score ?? 0);
        if (byScore != 0) {
          return byScore;
        }
        return a.imageId.compareTo(b.imageId);
      });
    if (highConfidenceFp.isEmpty) {
      return;
    }
    final Set<int> imageIds = {
      for (final DetectionMatch match in highConfidenceFp) match.imageId,
      if (worstCases != null)
        for (final WorstCaseItem item
            in worstCases.highConfidenceFalsePositives)
          item.imageId,
    };
    final Set<int> categoryIds = {
      for (final DetectionMatch match in highConfidenceFp)
        if (match.categoryId != null) match.categoryId!,
    };
    out.add(
      Recommendation(
        severity: _severityForCount(highConfidenceFp.length, config),
        category: RecommendationCategory.scoreCalibration,
        title: 'High-confidence false positives',
        message:
            'Some false positives have high confidence scores, which makes thresholding less reliable.',
        action:
            'Inspect hard negatives, add background examples, check score calibration.',
        relatedImageIds: imageIds.take(50).toList(),
        relatedCategoryIds: categoryIds.toList()..sort(),
        evidence: {
          'count': highConfidenceFp.length,
          'score_threshold': config.highConfidenceFpThreshold,
          'max_score': highConfidenceFp.first.prediction?.score,
        },
      ),
    );
  }

  void _addManyFnRecommendation(
    List<Recommendation> out,
    EvalResult evalResult,
    RecommendationConfig config,
  ) {
    final OverallStats overall = evalResult.overall;
    if (overall.totalFn <= overall.totalTp &&
        overall.imagesWithFn < config.minIssueCountForCritical) {
      return;
    }
    out.add(
      Recommendation(
        severity: _severityForCount(overall.totalFn, config),
        category: RecommendationCategory.falseNegatives,
        title: 'Many missed objects',
        message:
            'False negatives are a major part of the current error profile.',
        action:
            'Inspect FN cases, annotation consistency, input resolution, augmentation and train/val distribution.',
        relatedImageIds: evalResult.imageSummaries.values
            .where((ImageEvalSummary summary) => summary.hasFn)
            .map((ImageEvalSummary summary) => summary.imageId)
            .take(50)
            .toList(),
        evidence: {
          'total_fn': overall.totalFn,
          'total_tp': overall.totalTp,
          'images_with_fn': overall.imagesWithFn,
        },
      ),
    );
  }

  void _addClassConfusionRecommendations(
    List<Recommendation> out,
    CocoDataset dataset,
    ModelRun modelRun,
    EvalResult evalResult,
    EvalConfig evalConfig,
    RecommendationConfig config,
    WorstCasesResult? worstCases,
  ) {
    final ConfusionMatrixDetails details = const ConfusionMatrixDetailBuilder()
        .build(dataset: dataset, modelRun: modelRun, config: evalConfig);
    final List<ConfusionPair> pairs = details
        .pairs()
        .where(
          (ConfusionPair pair) =>
              pair.gtCategoryId != null &&
              pair.predCategoryId != null &&
              pair.gtCategoryId != pair.predCategoryId,
        )
        .toList();
    for (final ConfusionPair pair in pairs.take(5)) {
      out.add(
        Recommendation(
          severity: _severityForCount(pair.count, config),
          category: RecommendationCategory.classConfusion,
          title:
              'Class confusion: "${pair.gtClass}" predicted as "${pair.predClass}"',
          message:
              'The model confuses these two classes in class-agnostic matching.',
          action:
              'Review annotation rules and visual similarity. Add discriminative examples.',
          relatedImageIds: pair.exampleImageIds.take(50).toList(),
          relatedCategoryIds: [
            if (pair.gtCategoryId != null) pair.gtCategoryId!,
            if (pair.predCategoryId != null) pair.predCategoryId!,
          ],
          evidence: {
            'gt_class_id': pair.gtCategoryId,
            'gt_class_name': pair.gtClass,
            'pred_class_id': pair.predCategoryId,
            'pred_class_name': pair.predClass,
            'count': pair.count,
            'row_percent': pair.rowPercent,
            'worst_case_count': worstCases?.classConfusions.length,
            'total_confusion_errors': evalResult.imageSummaries.values
                .where((ImageEvalSummary summary) => summary.hasClassConfusion)
                .length,
          },
        ),
      );
    }
  }

  void _addDatasetHealthRecommendation(
    List<Recommendation> out,
    DatasetHealthReport? healthReport,
    RecommendationConfig config,
  ) {
    if (healthReport == null || healthReport.errorCount == 0) {
      return;
    }
    out.add(
      Recommendation(
        severity: RecommendationSeverity.critical,
        category: RecommendationCategory.datasetHealth,
        title: 'Dataset health errors detected',
        message:
            'Dataset health checks found errors that can make metrics unreliable.',
        action: 'Fix dataset issues before trusting evaluation metrics.',
        relatedImageIds: healthReport.issues
            .where((DatasetHealthIssue issue) => issue.imageId != null)
            .map((DatasetHealthIssue issue) => issue.imageId!)
            .take(50)
            .toList(),
        relatedCategoryIds: healthReport.issues
            .where((DatasetHealthIssue issue) => issue.categoryId != null)
            .map((DatasetHealthIssue issue) => issue.categoryId!)
            .toSet()
            .toList()
          ..sort(),
        evidence: {
          'error_count': healthReport.errorCount,
          'warning_count': healthReport.warningCount,
          'missing_image_count': healthReport.missingImageCount,
          'invalid_annotation_count': healthReport.invalidAnnotationCount,
          'invalid_prediction_count': healthReport.invalidPredictionCount,
        },
      ),
    );
  }

  void _addComparisonRecommendation(
    List<Recommendation> out,
    ModelComparisonResult? comparison,
    RecommendationConfig config,
  ) {
    if (comparison == null) {
      return;
    }
    final int regressionCount =
        comparison.brokenImageIds.length + comparison.regressedImageIds.length;
    if (regressionCount == 0) {
      return;
    }
    out.add(
      Recommendation(
        severity: _severityForCount(regressionCount, config),
        category: RecommendationCategory.modelComparison,
        title: 'Candidate model regressed',
        message:
            'The candidate model introduced broken or regressed images compared with the base run.',
        action:
            'Inspect broken/regressed images before selecting candidate for production.',
        relatedImageIds: [
          ...comparison.brokenImageIds,
          ...comparison.regressedImageIds,
        ].take(50).toList(),
        evidence: {
          'broken_images': comparison.brokenImageIds.length,
          'regressed_images': comparison.regressedImageIds.length,
          'delta_precision': comparison.overallDiff.deltaPrecision,
          'delta_recall': comparison.overallDiff.deltaRecall,
          'delta_f1': comparison.overallDiff.deltaF1,
        },
      ),
    );
  }

  void _addThresholdRecommendations(
    List<Recommendation> out,
    EvalResult evalResult,
    RecommendationConfig config,
  ) {
    final OverallStats overall = evalResult.overall;
    if (overall.microPrecision < config.lowPrecisionThreshold &&
        overall.microRecall >= config.lowRecallThreshold) {
      out.add(
        Recommendation(
          severity: RecommendationSeverity.info,
          category: RecommendationCategory.thresholds,
          title: 'Precision is low while recall is acceptable',
          message:
              'The current threshold keeps many detections but admits many false positives.',
          action: 'Try increasing confidence threshold.',
          evidence: {
            'precision': overall.microPrecision,
            'recall': overall.microRecall,
            'confidence_threshold': evalResult.config.confidenceThreshold,
          },
        ),
      );
    }
    if (overall.microRecall < config.lowRecallThreshold &&
        overall.microPrecision >= config.lowPrecisionThreshold) {
      out.add(
        Recommendation(
          severity: RecommendationSeverity.info,
          category: RecommendationCategory.thresholds,
          title: 'Recall is low while precision is acceptable',
          message:
              'The current threshold may be too strict or the model may need stronger recall.',
          action:
              'Try lowering confidence threshold or improving data/model recall.',
          evidence: {
            'precision': overall.microPrecision,
            'recall': overall.microRecall,
            'confidence_threshold': evalResult.config.confidenceThreshold,
          },
        ),
      );
    }
  }

  RecommendationSeverity _severityForCount(
    int count,
    RecommendationConfig config,
  ) {
    return count >= config.minIssueCountForCritical
        ? RecommendationSeverity.critical
        : RecommendationSeverity.warning;
  }
}

int _compareRecommendations(Recommendation a, Recommendation b) {
  final int bySeverity =
      _severityRank(b.severity).compareTo(_severityRank(a.severity));
  if (bySeverity != 0) {
    return bySeverity;
  }
  final int byCategory = a.category.name.compareTo(b.category.name);
  if (byCategory != 0) {
    return byCategory;
  }
  return a.title.compareTo(b.title);
}

int _severityRank(RecommendationSeverity severity) {
  return switch (severity) {
    RecommendationSeverity.critical => 3,
    RecommendationSeverity.warning => 2,
    RecommendationSeverity.info => 1,
  };
}
