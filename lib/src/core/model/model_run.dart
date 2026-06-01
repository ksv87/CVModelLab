import 'prediction.dart';

class ModelRun {
  ModelRun({
    required this.id,
    required this.name,
    required this.predictions,
  }) : predictionsByImageId = _groupPredictions(predictions);

  final String id;
  final String name;
  final List<Prediction> predictions;
  final Map<int, List<Prediction>> predictionsByImageId;

  static Map<int, List<Prediction>> _groupPredictions(
    List<Prediction> predictions,
  ) {
    final Map<int, List<Prediction>> grouped = {};
    for (final Prediction prediction in predictions) {
      grouped.putIfAbsent(prediction.imageId, () => []).add(prediction);
    }
    return grouped;
  }
}
