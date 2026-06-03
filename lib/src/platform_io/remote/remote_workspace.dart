import 'package:cv_model_lab/cv_model_lab.dart';

import '../image_source.dart';
import 'cvml_api_client.dart';
import 'remote_image_source.dart';

/// Everything the existing workspace screens need, reconstructed from a server
/// "full" eval payload. This reuses all local screens unchanged in remote mode.
class RemoteWorkspaceData {
  const RemoteWorkspaceData({
    required this.dataset,
    required this.modelRun,
    required this.evalResult,
    required this.imageSource,
    required this.config,
  });

  final CocoDataset dataset;
  final ModelRun modelRun;
  final EvalResult evalResult;
  final ImageSource imageSource;
  final EvalConfig config;
}

/// Builds [RemoteWorkspaceData] from the JSON returned by
/// `GET /api/sessions/{sid}/eval/{run}/full`.
RemoteWorkspaceData buildRemoteWorkspace({
  required CvmlApiClient client,
  required String sessionId,
  required String modelRunId,
  required String modelRunName,
  required Map<String, dynamic> full,
}) {
  final Map<String, dynamic> datasetJson =
      full['dataset'] as Map<String, dynamic>;
  final CocoDataset dataset = _datasetFromJson(datasetJson);

  final List<Prediction> predictions = [
    for (final dynamic p in (full['predictions'] as List<dynamic>))
      _predictionFromJson(p as Map<String, dynamic>),
  ];
  final ModelRun modelRun = ModelRun(
    id: modelRunId,
    name: modelRunName,
    predictions: predictions,
  );

  final List<DetectionMatch> matches = [
    for (final dynamic m in (full['matches'] as List<dynamic>))
      _matchFromJson(m as Map<String, dynamic>),
  ];

  final EvalResult evalResult = evalResultFromCompactJson(
    full['eval'] as Map<String, dynamic>,
    matches: matches,
  );

  final Map<String, int> imageIdByFileName = {
    for (final ImageRecord image in dataset.imagesById.values)
      image.fileName: image.id,
  };
  final ImageSource imageSource = RemoteImageSource(
    client: client,
    sessionId: sessionId,
    imageIdByFileName: imageIdByFileName,
    expectedFileNames: imageIdByFileName.keys,
  );

  return RemoteWorkspaceData(
    dataset: dataset,
    modelRun: modelRun,
    evalResult: evalResult,
    imageSource: imageSource,
    config: evalResult.config,
  );
}

CocoDataset _datasetFromJson(Map<String, dynamic> map) {
  final Map<int, ImageRecord> imagesById = {
    for (final dynamic img in (map['images'] as List<dynamic>))
      (img as Map<String, dynamic>)['id'] as int: ImageRecord(
        id: img['id'] as int,
        fileName: img['file_name'] as String,
        width: (img['width'] as num?)?.toInt(),
        height: (img['height'] as num?)?.toInt(),
      ),
  };
  final Map<int, CategoryRecord> categoriesById = {
    for (final dynamic cat in (map['categories'] as List<dynamic>))
      (cat as Map<String, dynamic>)['id'] as int: CategoryRecord(
        id: cat['id'] as int,
        name: cat['name'] as String,
      ),
  };
  final List<GroundTruthAnnotation> annotations = [
    for (final dynamic ann in (map['annotations'] as List<dynamic>))
      _annotationFromJson(ann as Map<String, dynamic>),
  ];
  return CocoDataset(
    imagesById: imagesById,
    categoriesById: categoriesById,
    annotations: annotations,
  );
}

BBox _bboxFromJson(List<dynamic> raw) {
  return BBox(
    x: (raw[0] as num).toDouble(),
    y: (raw[1] as num).toDouble(),
    width: (raw[2] as num).toDouble(),
    height: (raw[3] as num).toDouble(),
  );
}

GroundTruthAnnotation _annotationFromJson(Map<String, dynamic> map) {
  return GroundTruthAnnotation(
    id: map['id'] as int,
    imageId: map['image_id'] as int,
    categoryId: map['category_id'] as int,
    bbox: _bboxFromJson(map['bbox'] as List<dynamic>),
    area: (map['area'] as num?)?.toDouble(),
    isCrowd: map['is_crowd'] as bool? ?? false,
  );
}

Prediction _predictionFromJson(Map<String, dynamic> map) {
  return Prediction(
    imageId: map['image_id'] as int,
    categoryId: map['category_id'] as int,
    bbox: _bboxFromJson(map['bbox'] as List<dynamic>),
    score: (map['score'] as num).toDouble(),
  );
}

DetectionMatch _matchFromJson(Map<String, dynamic> map) {
  final Object? gtRaw = map['ground_truth'];
  final Object? predRaw = map['prediction'];
  return DetectionMatch(
    type: _matchType(map['type'] as String?),
    imageId: map['image_id'] as int,
    categoryId: (map['category_id'] as num?)?.toInt(),
    groundTruth:
        gtRaw is Map<String, dynamic> ? _annotationFromJson(gtRaw) : null,
    prediction:
        predRaw is Map<String, dynamic> ? _predictionFromJson(predRaw) : null,
    iou: (map['iou'] as num?)?.toDouble(),
    reason: map['reason'] as String?,
  );
}

DetectionMatchType _matchType(String? raw) {
  switch (raw) {
    case 'truePositive':
      return DetectionMatchType.truePositive;
    case 'falsePositive':
      return DetectionMatchType.falsePositive;
    case 'falseNegative':
      return DetectionMatchType.falseNegative;
    case 'ignored':
      return DetectionMatchType.ignored;
    default:
      return DetectionMatchType.falsePositive;
  }
}
