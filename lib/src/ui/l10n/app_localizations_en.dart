import 'package:cv_model_lab/cv_model_lab.dart';

import 'app_localizations.dart';

class AppLocalizationsEn extends AppLocalizations {
  const AppLocalizationsEn() : super(AppLocale.en);

  @override
  String? lookup(MessageKey key, MessageParams p) {
    return switch (key) {
      MessageKey.parseInvalidJson => 'Invalid JSON: ${p['error'] ?? ''}',
      MessageKey.parseAnnotationsRootMustBeObject =>
        'COCO annotations root must be an object',
      MessageKey.parseAnnotationsListsRequired =>
        'images, annotations and categories must be lists',
      MessageKey.parseImageMustBeObject => 'image must be an object',
      MessageKey.parseImageRequiresIdAndFileName =>
        'image requires id and file_name',
      MessageKey.parseDuplicateImageIdSkipped =>
        'duplicate image id ${p['id']} skipped',
      MessageKey.parseCategoryMustBeObject => 'category must be an object',
      MessageKey.parseCategoryRequiresIdAndName =>
        'category requires id and name',
      MessageKey.parseDuplicateCategoryIdSkipped =>
        'duplicate category id ${p['id']} skipped',
      MessageKey.parseAnnotationMustBeObject => 'annotation must be an object',
      MessageKey.parseAnnotationUnknownImageId =>
        'annotation references unknown image_id',
      MessageKey.parseAnnotationUnknownCategoryId =>
        'annotation references unknown category_id',
      MessageKey.parsePredictionsRootMustBeList =>
        'COCO predictions root must be a list',
      MessageKey.parsePredictionMustBeObject => 'prediction must be an object',
      MessageKey.parsePredictionUnknownCategoryId =>
        'prediction references unknown category_id',
      MessageKey.parsePredictionUnknownImageId =>
        'prediction references unknown image_id',
      MessageKey.parsePredictionRequiresImageIdOrFileName =>
        'prediction requires image_id or file_name',
      MessageKey.parsePredictionFileNameBasenameFallback =>
        'prediction file_name matched by basename fallback',
      MessageKey.parsePredictionFileNameAmbiguous =>
        'prediction file_name basename is ambiguous',
      MessageKey.parsePredictionUnknownFileName =>
        'prediction references unknown file_name',
      MessageKey.parsePredictionRequiresNumericScore =>
        'prediction requires numeric score',
      MessageKey.parsePredictionScoreOutOfRange =>
        'prediction score is outside expected 0..1 range',
      MessageKey.parseBboxMustHaveFourNumbers => 'bbox must have 4 numbers',
      MessageKey.parseBboxNonPositiveSize =>
        'bbox width and height must be positive',
      MessageKey.parseMissingImageFile => 'missing image file',
      MessageKey.parseMoreMissingImageFiles =>
        '${p['count']} more image files are missing',
      MessageKey.errorInvalidJson =>
        'The selected file is not valid JSON or does not match the expected CV Model Lab format.',
      MessageKey.errorPermissionDenied =>
        'CV Model Lab could not access the selected file or folder. Pick it again or choose a location you can read and write.',
      MessageKey.errorApUnavailable =>
        'COCO AP evaluation cannot run in this environment. On web, import AP metrics JSON instead.',
      MessageKey.errorOperationFailed =>
        'The operation could not be completed. Review the details or try again with a different file or folder.',
      MessageKey.errorProjectRestoreFailed =>
        'Could not restore the project. Re-select the referenced files and try again.',
      MessageKey.errorExportFailed =>
        'Export failed. Choose a writable destination and try again.',
      MessageKey.recLowRecallClass => _recLowRecall(p),
      MessageKey.recLowPrecisionClass => _recLowPrecision(p),
      MessageKey.recRareClass => _recRareClass(p),
      MessageKey.recClassImbalance => _recClassImbalance(p),
      MessageKey.recSmallObjectRecallGap => _recSmallObject(p),
      MessageKey.recHighConfidenceFalsePositives => _recHighConfidenceFp(p),
      MessageKey.recManyFalseNegatives => _recManyFn(p),
      MessageKey.recClassConfusion => _recClassConfusion(p),
      MessageKey.recDatasetHealthErrors => _recDatasetHealth(p),
      MessageKey.recCandidateRegression => _recCandidateRegression(p),
      MessageKey.recThresholdLowPrecision => _recThresholdLowPrecision(p),
      MessageKey.recThresholdLowRecall => _recThresholdLowRecall(p),
      MessageKey.reportTitle => 'CV Model Lab Report',
      MessageKey.reportDatasetSummary => 'Dataset summary',
      MessageKey.reportModelRunSummary => 'Model Run Summary',
      MessageKey.reportOverallMetrics => 'Overall metrics',
      MessageKey.reportPerClassMetrics => 'Per-class metrics',
      MessageKey.reportSmallObjectStats => 'Small object stats',
      MessageKey.reportConfusionMatrix => 'Confusion matrix',
      MessageKey.reportDatasetHealth => 'Dataset health check',
      MessageKey.reportWorstCases => 'Worst cases',
      MessageKey.reportRecommendations => 'Recommendations',
      MessageKey.reportCocoApMetrics => 'COCO AP Metrics',
      MessageKey.reportModelComparison => 'Model Comparison',
      MessageKey.reportImageErrors => 'Image Errors',
      MessageKey.reportMatches => 'Matches',
      MessageKey.mmMultiModelComparison => 'Multi-model Comparison',
      MessageKey.mmPairwiseMode => 'Pairwise Compare',
      MessageKey.mmMultiModelMode => 'Multi-model Compare',
      MessageKey.mmLeaderboard => 'Leaderboard',
      MessageKey.mmPerClassRanking => 'Per-Class Ranking',
      MessageKey.mmImageDisagreement => 'Image Disagreement',
      MessageKey.mmRegressionMatrix => 'Regression Matrix',
      MessageKey.mmCompareViewer => 'Compare Viewer',
      MessageKey.mmAllModelsCorrect => 'All models correct',
      MessageKey.mmAllModelsWrong => 'All models wrong',
      MessageKey.mmSomeModelsWrong => 'Some models wrong',
      MessageKey.mmOnlyOneModelCorrect => 'Only one model correct',
      MessageKey.mmOnlyOneModelWrong => 'Only one model wrong',
      MessageKey.mmClassDisagreement => 'Class disagreement',
      MessageKey.mmLargeErrorSpread => 'Large error spread',
      MessageKey.mmPredictionCountDisagreement =>
        'Prediction count disagreement',
      MessageKey.mmApNotComputed => 'AP metrics not computed for this model.',
      MessageKey.mmSelectTwoRuns =>
        'Add at least two model runs to compare models.',
      MessageKey.mmOpenPairwise => 'Open pairwise comparison',
      MessageKey.mmBestModel => 'Best model',
      MessageKey.mmWorstModel => 'Worst model',
      MessageKey.mmF1Spread => 'F1 spread',
      MessageKey.mmErrorSpread => 'Error spread',
      MessageKey.mmRankingMetric => 'Ranking metric',
      MessageKey.mmHideAllCorrect => 'Hide all-correct images',
      MessageKey.mmIncludeAp => 'Include AP',
      MessageKey.mmMakeActiveModel => 'Make active model',
      MessageKey.mmRank => 'Rank',
      MessageKey.mmModel => 'Model',
      MessageKey.mmCorrectModels => 'Correct models',
      MessageKey.mmWrongModels => 'Wrong models',
      MessageKey.mmSpread => 'Spread',
      MessageKey.mmImagesWithErrors => 'Images with errors',
      MessageKey.mmSmallRecall => 'Small recall',
      MessageKey.mmExportTable => 'Export table',
      MessageKey.mmType => 'Type',
      MessageKey.mmImage => 'Image',
      MessageKey.mmClassFilter => 'Class',
      MessageKey.mmBestErrorCount => 'Best error count',
      MessageKey.mmWorstErrorCount => 'Worst error count',
      MessageKey.mmConsensusSummary => 'Consensus summary',
      MessageKey.mmModelRuns => 'Model runs',
    };
  }

  String _part(MessageParams p) => '${p['part'] ?? 'message'}';

  String _recLowRecall(MessageParams p) => switch (_part(p)) {
        'title' => 'Low recall for class "${p['class_name']}"',
        'action' =>
          'Inspect false negatives, check annotation consistency, add more examples, and consider resolution/augmentation changes.',
        _ => 'The model misses many objects of this class.',
      };

  String _recLowPrecision(MessageParams p) => switch (_part(p)) {
        'title' => 'Low precision for class "${p['class_name']}"',
        'action' =>
          'Inspect false positives, add hard negatives, review class taxonomy and score threshold.',
        _ => 'Many predictions for this class are false positives.',
      };

  String _recRareClass(MessageParams p) => switch (_part(p)) {
        'title' => 'Rare class "${p['class_name']}"',
        'action' =>
          'Collect more samples or avoid trusting metrics for this class.',
        _ => 'This class has too few ground-truth examples.',
      };

  String _recClassImbalance(MessageParams p) => switch (_part(p)) {
        'title' => 'Class imbalance detected',
        'action' => 'Collect or oversample underrepresented classes.',
        _ =>
          'Some classes have a very small share of the ground-truth objects.',
      };

  String _recSmallObject(MessageParams p) => switch (_part(p)) {
        'title' => 'Small object performance is weak',
        'action' =>
          'Consider higher input resolution, tiling, more small-object samples, or reviewing tiny annotations.',
        _ =>
          'Small objects for "${p['class_name']}" have much lower recall than larger objects.',
      };

  String _recHighConfidenceFp(MessageParams p) => switch (_part(p)) {
        'title' => 'High-confidence false positives',
        'action' =>
          'Inspect hard negatives, add background examples, check score calibration.',
        _ =>
          'Some false positives have high confidence scores, which makes thresholding less reliable.',
      };

  String _recManyFn(MessageParams p) => switch (_part(p)) {
        'title' => 'Many missed objects',
        'action' =>
          'Inspect FN cases, annotation consistency, input resolution, augmentation and train/val distribution.',
        _ => 'False negatives are a major part of the current error profile.',
      };

  String _recClassConfusion(MessageParams p) => switch (_part(p)) {
        'title' =>
          'Class confusion: "${p['gt_class_name']}" predicted as "${p['pred_class_name']}"',
        'action' =>
          'Review annotation rules and visual similarity. Add discriminative examples.',
        _ => 'The model confuses these two classes in class-agnostic matching.',
      };

  String _recDatasetHealth(MessageParams p) => switch (_part(p)) {
        'title' => 'Dataset health errors detected',
        'action' => 'Fix dataset issues before trusting evaluation metrics.',
        _ =>
          'Dataset health checks found errors that can make metrics unreliable.',
      };

  String _recCandidateRegression(MessageParams p) => switch (_part(p)) {
        'title' => 'Candidate model regressed',
        'action' =>
          'Inspect broken/regressed images before selecting candidate for production.',
        _ =>
          'The candidate model introduced broken or regressed images compared with the base run.',
      };

  String _recThresholdLowPrecision(MessageParams p) => switch (_part(p)) {
        'title' => 'Precision is low while recall is acceptable',
        'action' => 'Try increasing confidence threshold.',
        _ =>
          'The current threshold keeps many detections but admits many false positives.',
      };

  String _recThresholdLowRecall(MessageParams p) => switch (_part(p)) {
        'title' => 'Recall is low while precision is acceptable',
        'action' =>
          'Try lowering confidence threshold or improving data/model recall.',
        _ =>
          'The current threshold may be too strict or the model may need stronger recall.',
      };

  @override
  String? datasetIssueLookup(
    DatasetIssueType type,
    String part,
    MessageParams p,
  ) {
    final String file = '${p['file_name'] ?? ''}';
    final String cls = '${p['category_name'] ?? p['category_id'] ?? ''}';
    return switch (type) {
      DatasetIssueType.missingImageFile => switch (part) {
          'title' => 'Missing image file',
          'recommendation' => 'Add the file or fix the file_name path.',
          _ => 'Image "$file" is referenced by COCO but was not found.',
        },
      DatasetIssueType.unusedImageFile => switch (part) {
          'title' => 'Unused image file',
          'recommendation' => 'Remove the file or add an image record for it.',
          _ => 'File "$file" is present but not referenced by the dataset.',
        },
      DatasetIssueType.unknownAnnotationImageId => switch (part) {
          'title' => 'Annotation references unknown image',
          'recommendation' =>
            'Remove the annotation or add the missing image record.',
          _ =>
            'Annotation ${p['annotation_id']} references image_id ${p['image_id']}, which is not in the dataset.',
        },
      DatasetIssueType.unknownAnnotationCategoryId => switch (part) {
          'title' => 'Annotation references unknown category',
          'recommendation' =>
            'Add the category to "categories" or fix the annotation.',
          _ =>
            'Annotation ${p['annotation_id']} references category_id ${p['category_id']}, which is not declared.',
        },
      DatasetIssueType.unknownPredictionImageId => switch (part) {
          'title' => 'Prediction references unknown image',
          'recommendation' =>
            'Check that predictions and annotations use the same image ids / file names.',
          _ =>
            'A prediction references image_id ${p['image_id']}, which is not in the dataset.',
        },
      DatasetIssueType.unknownPredictionCategoryId => switch (part) {
          'title' => 'Prediction references unknown category',
          'recommendation' =>
            'Align prediction category ids with the dataset categories.',
          _ =>
            'A prediction references category_id ${p['category_id']}, which is not declared.',
        },
      DatasetIssueType.invalidBbox => switch (part) {
          'title' => 'Invalid bbox',
          'recommendation' => 'Remove or fix the degenerate box.',
          _ => 'A box has non-positive width or height.',
        },
      DatasetIssueType.bboxOutsideImage => switch (part) {
          'title' => 'BBox outside image',
          'recommendation' => 'Fix the bbox coordinates.',
          _ => 'A bbox lies entirely outside the image bounds.',
        },
      DatasetIssueType.bboxPartiallyOutsideImage => switch (part) {
          'title' => 'BBox partially outside image',
          'recommendation' => 'Clamp the bbox to the image.',
          _ => 'A bbox extends past the image bounds.',
        },
      DatasetIssueType.extremeAspectRatio => switch (part) {
          'title' => 'Extreme aspect ratio',
          'recommendation' => 'Check for a malformed box.',
          _ => 'A bbox has an extreme aspect ratio.',
        },
      DatasetIssueType.tinyBbox => switch (part) {
          'title' => 'Tiny bbox',
          'recommendation' => 'Verify the annotation is not a labelling error.',
          _ => 'A bbox is very small.',
        },
      DatasetIssueType.hugeBbox => switch (part) {
          'title' => 'Huge bbox',
          'recommendation' => 'Confirm the box is intentional.',
          _ => 'A bbox covers most of the image.',
        },
      DatasetIssueType.imageWithoutGroundTruth => switch (part) {
          'title' => 'Image without ground truth',
          'recommendation' =>
            'Confirm the image is intentionally a negative sample.',
          _ => 'Image "$file" has no annotations.',
        },
      DatasetIssueType.classWithoutGroundTruth => switch (part) {
          'title' => 'Class without ground truth',
          'recommendation' =>
            'Remove the unused class or add training data for it.',
          _ => 'Class "$cls" has no GT objects.',
        },
      DatasetIssueType.rareClass => switch (part) {
          'title' => 'Rare class',
          'recommendation' => 'Collect more samples for this class.',
          _ => 'Class "$cls" has few GT objects.',
        },
      DatasetIssueType.classImbalance => switch (part) {
          'title' => 'Class imbalance',
          'recommendation' =>
            'Consider rebalancing the dataset or using class weights.',
          _ => 'Class "$cls" has a small share of GT objects.',
        },
      DatasetIssueType.duplicateImageId => switch (part) {
          'title' => 'Duplicate image id',
          'recommendation' => 'Make image ids unique.',
          _ => 'An image id appears more than once.',
        },
      DatasetIssueType.duplicateFileName => switch (part) {
          'title' => 'Duplicate file name',
          'recommendation' =>
            'Ensure each image record has a unique file_name.',
          _ => 'A file_name is shared by multiple image ids.',
        },
      DatasetIssueType.duplicateAnnotationId => switch (part) {
          'title' => 'Duplicate annotation id',
          'recommendation' => 'Make annotation ids unique.',
          _ => 'An annotation id appears more than once.',
        },
      DatasetIssueType.predictionWithoutImage => switch (part) {
          'title' => 'Prediction without image',
          'recommendation' => 'Align predictions with the dataset image list.',
          _ => 'A prediction does not resolve to a dataset image.',
        },
      DatasetIssueType.predictionOnImageWithoutGroundTruth => switch (part) {
          'title' => 'Predictions on image without ground truth',
          'recommendation' => 'Verify the GT is complete.',
          _ => 'An image has predictions but no ground truth.',
        },
    };
  }
}
