import 'dart:convert';

import '../model/coco_dataset.dart';
import '../model/model_run.dart';
import '../model/prediction.dart';
import 'parse_result.dart';
import 'parser_utils.dart';

class CocoPredictionParser {
  const CocoPredictionParser();

  ParseResult<ModelRun> parseString(
    String jsonString, {
    required CocoDataset dataset,
    required String modelRunId,
    required String modelRunName,
  }) {
    final List<ParseIssue> issues = [];
    void addIssue(ParseIssue issue) => issues.add(issue);

    final Object? decoded;
    try {
      decoded = jsonDecode(jsonString);
    } on FormatException catch (error) {
      return ParseResult<ModelRun>(
        value: null,
        issues: [
          ParseIssue(
            severity: ParseIssueSeverity.error,
            message: 'Invalid JSON: ${error.message}',
          ),
        ],
      );
    }

    if (decoded is! List) {
      return const ParseResult<ModelRun>(
        value: null,
        issues: [
          ParseIssue(
            severity: ParseIssueSeverity.error,
            message: 'COCO predictions root must be a list',
          ),
        ],
      );
    }

    final Map<String, int> exactFileNameToImageId = dataset.imageIdsByFileName;
    final Map<String, List<int>> basenameToImageIds = {};
    for (final image in dataset.imagesById.values) {
      basenameToImageIds
          .putIfAbsent(basename(image.fileName), () => <int>[])
          .add(image.id);
    }

    final List<Prediction> predictions = [];
    for (var index = 0; index < decoded.length; index += 1) {
      final Object? item = decoded[index];
      if (item is! Map<String, Object?>) {
        addIssue(
          ParseIssue(
            severity: ParseIssueSeverity.warning,
            message: 'prediction must be an object',
            path: 'predictions[$index]',
          ),
        );
        continue;
      }

      final int? categoryId = readInt(item['category_id']);
      if (categoryId == null ||
          !dataset.categoriesById.containsKey(categoryId)) {
        addIssue(
          ParseIssue(
            severity: ParseIssueSeverity.warning,
            message: 'prediction references unknown category_id',
            path: 'predictions[$index].category_id',
          ),
        );
        continue;
      }

      final int? imageId = _resolveImageId(
        item,
        dataset,
        exactFileNameToImageId,
        basenameToImageIds,
        index,
        addIssue,
      );
      if (imageId == null) {
        continue;
      }

      final bbox = readBBox(item['bbox'], 'predictions[$index].bbox', addIssue);
      if (bbox == null) {
        continue;
      }

      final double? score = readDouble(item['score']);
      if (score == null) {
        addIssue(
          ParseIssue(
            severity: ParseIssueSeverity.warning,
            message: 'prediction requires numeric score',
            path: 'predictions[$index].score',
          ),
        );
        continue;
      }
      if (score < 0 || score > 1) {
        addIssue(
          ParseIssue(
            severity: ParseIssueSeverity.warning,
            message: 'prediction score is outside expected 0..1 range',
            path: 'predictions[$index].score',
          ),
        );
      }

      predictions.add(
        Prediction(
          imageId: imageId,
          categoryId: categoryId,
          bbox: bbox,
          score: score,
          sourceModelName: modelRunName,
        ),
      );
    }

    return ParseResult<ModelRun>(
      value: ModelRun(
        id: modelRunId,
        name: modelRunName,
        predictions: predictions,
      ),
      issues: issues,
    );
  }

  int? _resolveImageId(
    Map<String, Object?> item,
    CocoDataset dataset,
    Map<String, int> exactFileNameToImageId,
    Map<String, List<int>> basenameToImageIds,
    int index,
    IssueSink addIssue,
  ) {
    final int? directImageId = readInt(item['image_id']);
    if (directImageId != null) {
      if (dataset.imagesById.containsKey(directImageId)) {
        return directImageId;
      }
      addIssue(
        ParseIssue(
          severity: ParseIssueSeverity.warning,
          message: 'prediction references unknown image_id',
          path: 'predictions[$index].image_id',
        ),
      );
      return null;
    }

    final Object? fileNameRaw = item['file_name'];
    if (fileNameRaw is! String || fileNameRaw.isEmpty) {
      addIssue(
        ParseIssue(
          severity: ParseIssueSeverity.warning,
          message: 'prediction requires image_id or file_name',
          path: 'predictions[$index]',
        ),
      );
      return null;
    }

    final int? exactImageId = exactFileNameToImageId[fileNameRaw];
    if (exactImageId != null) {
      return exactImageId;
    }

    final List<int> basenameMatches =
        basenameToImageIds[basename(fileNameRaw)] ?? const <int>[];
    if (basenameMatches.length == 1) {
      addIssue(
        ParseIssue(
          severity: ParseIssueSeverity.warning,
          message: 'prediction file_name matched by basename fallback',
          path: 'predictions[$index].file_name',
        ),
      );
      return basenameMatches.single;
    }
    if (basenameMatches.length > 1) {
      addIssue(
        ParseIssue(
          severity: ParseIssueSeverity.warning,
          message: 'prediction file_name basename is ambiguous',
          path: 'predictions[$index].file_name',
        ),
      );
      return null;
    }

    addIssue(
      ParseIssue(
        severity: ParseIssueSeverity.warning,
        message: 'prediction references unknown file_name',
        path: 'predictions[$index].file_name',
      ),
    );
    return null;
  }
}
