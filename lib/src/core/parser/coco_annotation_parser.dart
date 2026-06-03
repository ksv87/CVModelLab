import 'dart:convert';

import '../model/annotation.dart';
import '../model/category.dart';
import '../model/coco_dataset.dart';
import '../model/image_record.dart';
import '../i18n/message_key.dart';
import 'parse_result.dart';
import 'parser_utils.dart';

class CocoAnnotationParser {
  const CocoAnnotationParser();

  ParseResult<CocoDataset> parseString(String jsonString) {
    final List<ParseIssue> issues = [];
    void addIssue(ParseIssue issue) => issues.add(issue);

    final Object? decoded;
    try {
      decoded = jsonDecode(jsonString);
    } on FormatException catch (error) {
      return ParseResult<CocoDataset>(
        value: null,
        issues: [
          ParseIssue(
            severity: ParseIssueSeverity.error,
            message: 'Invalid JSON: ${error.message}',
            key: MessageKey.parseInvalidJson,
            params: {'error': error.message},
          ),
        ],
      );
    }

    if (decoded is! Map<String, Object?>) {
      return const ParseResult<CocoDataset>(
        value: null,
        issues: [
          ParseIssue(
            severity: ParseIssueSeverity.error,
            message: 'COCO annotations root must be an object',
            key: MessageKey.parseAnnotationsRootMustBeObject,
          ),
        ],
      );
    }

    final Object? imagesRaw = decoded['images'];
    final Object? annotationsRaw = decoded['annotations'];
    final Object? categoriesRaw = decoded['categories'];
    if (imagesRaw is! List ||
        annotationsRaw is! List ||
        categoriesRaw is! List) {
      return const ParseResult<CocoDataset>(
        value: null,
        issues: [
          ParseIssue(
            severity: ParseIssueSeverity.error,
            message: 'images, annotations and categories must be lists',
            key: MessageKey.parseAnnotationsListsRequired,
          ),
        ],
      );
    }

    final Map<int, ImageRecord> imagesById = {};
    for (var index = 0; index < imagesRaw.length; index += 1) {
      final Object? item = imagesRaw[index];
      if (item is! Map<String, Object?>) {
        addIssue(
          ParseIssue(
            severity: ParseIssueSeverity.warning,
            message: 'image must be an object',
            path: 'images[$index]',
            key: MessageKey.parseImageMustBeObject,
          ),
        );
        continue;
      }
      final int? id = readInt(item['id']);
      final Object? fileNameRaw = item['file_name'];
      if (id == null || fileNameRaw is! String || fileNameRaw.isEmpty) {
        addIssue(
          ParseIssue(
            severity: ParseIssueSeverity.warning,
            message: 'image requires id and file_name',
            path: 'images[$index]',
            key: MessageKey.parseImageRequiresIdAndFileName,
          ),
        );
        continue;
      }
      if (imagesById.containsKey(id)) {
        addIssue(
          ParseIssue(
            severity: ParseIssueSeverity.warning,
            message: 'duplicate image id $id skipped',
            path: 'images[$index]',
            key: MessageKey.parseDuplicateImageIdSkipped,
            params: {'id': id},
          ),
        );
        continue;
      }
      imagesById[id] = ImageRecord(
        id: id,
        fileName: fileNameRaw,
        width: readInt(item['width']),
        height: readInt(item['height']),
      );
    }

    final Map<int, CategoryRecord> categoriesById = {};
    for (var index = 0; index < categoriesRaw.length; index += 1) {
      final Object? item = categoriesRaw[index];
      if (item is! Map<String, Object?>) {
        addIssue(
          ParseIssue(
            severity: ParseIssueSeverity.warning,
            message: 'category must be an object',
            path: 'categories[$index]',
            key: MessageKey.parseCategoryMustBeObject,
          ),
        );
        continue;
      }
      final int? id = readInt(item['id']);
      final Object? nameRaw = item['name'];
      if (id == null || nameRaw is! String || nameRaw.isEmpty) {
        addIssue(
          ParseIssue(
            severity: ParseIssueSeverity.warning,
            message: 'category requires id and name',
            path: 'categories[$index]',
            key: MessageKey.parseCategoryRequiresIdAndName,
          ),
        );
        continue;
      }
      if (categoriesById.containsKey(id)) {
        addIssue(
          ParseIssue(
            severity: ParseIssueSeverity.warning,
            message: 'duplicate category id $id skipped',
            path: 'categories[$index]',
            key: MessageKey.parseDuplicateCategoryIdSkipped,
            params: {'id': id},
          ),
        );
        continue;
      }
      categoriesById[id] = CategoryRecord(id: id, name: nameRaw);
    }

    final List<GroundTruthAnnotation> annotations = [];
    for (var index = 0; index < annotationsRaw.length; index += 1) {
      final Object? item = annotationsRaw[index];
      if (item is! Map<String, Object?>) {
        addIssue(
          ParseIssue(
            severity: ParseIssueSeverity.warning,
            message: 'annotation must be an object',
            path: 'annotations[$index]',
            key: MessageKey.parseAnnotationMustBeObject,
          ),
        );
        continue;
      }
      final int? imageId = readInt(item['image_id']);
      final int? categoryId = readInt(item['category_id']);
      final bbox = readBBox(item['bbox'], 'annotations[$index].bbox', addIssue);
      if (imageId == null || !imagesById.containsKey(imageId)) {
        addIssue(
          ParseIssue(
            severity: ParseIssueSeverity.warning,
            message: 'annotation references unknown image_id',
            path: 'annotations[$index].image_id',
            key: MessageKey.parseAnnotationUnknownImageId,
          ),
        );
        continue;
      }
      if (categoryId == null || !categoriesById.containsKey(categoryId)) {
        addIssue(
          ParseIssue(
            severity: ParseIssueSeverity.warning,
            message: 'annotation references unknown category_id',
            path: 'annotations[$index].category_id',
            key: MessageKey.parseAnnotationUnknownCategoryId,
          ),
        );
        continue;
      }
      if (bbox == null) {
        continue;
      }

      final int id = readInt(item['id']) ?? index + 1;
      final Object? isCrowdRaw = item['iscrowd'];
      final bool isCrowd = isCrowdRaw == true || isCrowdRaw == 1;
      annotations.add(
        GroundTruthAnnotation(
          id: id,
          imageId: imageId,
          categoryId: categoryId,
          bbox: bbox,
          area: readDouble(item['area']),
          isCrowd: isCrowd,
        ),
      );
    }

    return ParseResult<CocoDataset>(
      value: CocoDataset(
        imagesById: imagesById,
        categoriesById: categoriesById,
        annotations: annotations,
      ),
      issues: issues,
    );
  }
}
