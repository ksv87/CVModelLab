/// A single image surfaced by the [WorstCaseMiner], annotated with the reason
/// it is interesting for a given category.
class WorstCaseItem {
  const WorstCaseItem({
    required this.imageId,
    required this.fileName,
    required this.category,
    required this.title,
    required this.reason,
    required this.tp,
    required this.fp,
    required this.fn,
    required this.severityScore,
    this.score,
    this.iou,
  });

  final int imageId;
  final String fileName;

  /// The worst-case category this item belongs to (e.g. "most_errors").
  final String category;

  final String title;
  final String reason;

  final int tp;
  final int fp;
  final int fn;

  /// Most relevant prediction score for this category, when applicable.
  final double? score;

  /// Most relevant IoU for this category, when applicable.
  final double? iou;

  /// Sorting key — higher means "more worth reviewing" for its category.
  final double severityScore;
}

/// Mined worst cases grouped by analysis category. Comparison-derived lists are
/// empty when no [ModelComparisonResult] was supplied.
class WorstCasesResult {
  const WorstCasesResult({
    required this.mostErrors,
    required this.mostFalsePositives,
    required this.mostFalseNegatives,
    required this.highConfidenceFalsePositives,
    required this.lowIouTruePositives,
    required this.classConfusions,
    required this.smallMissedObjects,
    required this.imagesWithoutGtButWithPredictions,
    required this.imagesWithGtButNoPredictions,
    this.fixedByCandidate = const [],
    this.brokenByCandidate = const [],
    this.improvedByCandidate = const [],
    this.regressedByCandidate = const [],
  });

  final List<WorstCaseItem> mostErrors;
  final List<WorstCaseItem> mostFalsePositives;
  final List<WorstCaseItem> mostFalseNegatives;
  final List<WorstCaseItem> highConfidenceFalsePositives;
  final List<WorstCaseItem> lowIouTruePositives;
  final List<WorstCaseItem> classConfusions;
  final List<WorstCaseItem> smallMissedObjects;
  final List<WorstCaseItem> imagesWithoutGtButWithPredictions;
  final List<WorstCaseItem> imagesWithGtButNoPredictions;

  final List<WorstCaseItem> fixedByCandidate;
  final List<WorstCaseItem> brokenByCandidate;
  final List<WorstCaseItem> improvedByCandidate;
  final List<WorstCaseItem> regressedByCandidate;

  /// All categories, in display order, paired with their items.
  List<({String key, String label, List<WorstCaseItem> items})>
      get categories => [
            (key: 'most_errors', label: 'Most errors', items: mostErrors),
            (
              key: 'most_fp',
              label: 'Most false positives',
              items: mostFalsePositives
            ),
            (
              key: 'most_fn',
              label: 'Most false negatives',
              items: mostFalseNegatives
            ),
            (
              key: 'high_conf_fp',
              label: 'High confidence FP',
              items: highConfidenceFalsePositives
            ),
            (
              key: 'low_iou_tp',
              label: 'Low IoU TP',
              items: lowIouTruePositives
            ),
            (
              key: 'class_confusion',
              label: 'Class confusion',
              items: classConfusions
            ),
            (
              key: 'small_missed',
              label: 'Small missed objects',
              items: smallMissedObjects
            ),
            (
              key: 'no_gt_with_pred',
              label: 'No GT but predictions',
              items: imagesWithoutGtButWithPredictions
            ),
            (
              key: 'gt_no_pred',
              label: 'GT but no predictions',
              items: imagesWithGtButNoPredictions
            ),
            if (fixedByCandidate.isNotEmpty)
              (
                key: 'fixed',
                label: 'Fixed by candidate',
                items: fixedByCandidate
              ),
            if (brokenByCandidate.isNotEmpty)
              (
                key: 'broken',
                label: 'Broken by candidate',
                items: brokenByCandidate
              ),
            if (improvedByCandidate.isNotEmpty)
              (
                key: 'improved',
                label: 'Improved by candidate',
                items: improvedByCandidate
              ),
            if (regressedByCandidate.isNotEmpty)
              (
                key: 'regressed',
                label: 'Regressed by candidate',
                items: regressedByCandidate
              ),
          ];
}
