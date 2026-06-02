import 'dart:convert';

import '../model/eval_config.dart';
import '../model/project.dart';

class ProjectSerializationException implements Exception {
  const ProjectSerializationException(this.message);
  final String message;

  @override
  String toString() => 'ProjectSerializationException: $message';
}

class ProjectSerializer {
  const ProjectSerializer();

  static const String _currentSchemaVersion = '1';

  Map<String, dynamic> toJson(CvmlProject project) {
    return <String, dynamic>{
      'schema_version': project.schemaVersion,
      'id': project.id,
      'name': project.name,
      'created_at': project.createdAt.toUtc().toIso8601String(),
      'updated_at': project.updatedAt.toUtc().toIso8601String(),
      'dataset': _datasetToJson(project.datasetSource),
      'model_runs':
          project.modelRuns.map(_modelRunToJson).toList(growable: false),
      if (project.activeModelRunId != null)
        'active_model_run_id': project.activeModelRunId,
      'default_eval_config': _evalConfigToJson(project.defaultEvalConfig),
    };
  }

  String toJsonString(CvmlProject project) {
    return const JsonEncoder.withIndent('  ').convert(toJson(project));
  }

  CvmlProject fromJson(Map<String, dynamic> map) {
    final Object? schemaVersion = map['schema_version'];
    if (schemaVersion == null) {
      throw const ProjectSerializationException(
        'Missing required field: schema_version',
      );
    }
    if (schemaVersion != _currentSchemaVersion) {
      throw ProjectSerializationException(
        'Unknown schema_version: "$schemaVersion". '
        'Only version "$_currentSchemaVersion" is supported.',
      );
    }

    final String id = _requireString(map, 'id');
    final String name = _requireString(map, 'name');
    final DateTime createdAt = _requireDateTime(map, 'created_at');
    final DateTime updatedAt = _requireDateTime(map, 'updated_at');

    final Object? datasetRaw = map['dataset'];
    if (datasetRaw == null || datasetRaw is! Map<String, dynamic>) {
      throw const ProjectSerializationException(
        'Missing or invalid required field: dataset',
      );
    }
    final ProjectDatasetSource datasetSource = _datasetFromJson(datasetRaw);

    final Object? modelRunsRaw = map['model_runs'];
    if (modelRunsRaw == null || modelRunsRaw is! List<dynamic>) {
      throw const ProjectSerializationException(
        'Missing or invalid required field: model_runs',
      );
    }
    final List<ProjectModelRunSource> modelRuns =
        modelRunsRaw.map<ProjectModelRunSource>((dynamic item) {
      if (item is! Map<String, dynamic>) {
        throw const ProjectSerializationException(
          'Invalid model run entry in model_runs',
        );
      }
      return _modelRunFromJson(item);
    }).toList();

    final Object? defaultConfigRaw = map['default_eval_config'];
    if (defaultConfigRaw == null || defaultConfigRaw is! Map<String, dynamic>) {
      throw const ProjectSerializationException(
        'Missing or invalid required field: default_eval_config',
      );
    }
    final EvalConfig defaultEvalConfig = _evalConfigFromJson(defaultConfigRaw);

    final String? activeModelRunId = map['active_model_run_id'] as String?;

    return CvmlProject(
      schemaVersion: schemaVersion as String,
      id: id,
      name: name,
      createdAt: createdAt,
      updatedAt: updatedAt,
      datasetSource: datasetSource,
      modelRuns: modelRuns,
      defaultEvalConfig: defaultEvalConfig,
      activeModelRunId: activeModelRunId,
    );
  }

  CvmlProject fromJsonString(String jsonString) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonString);
    } on FormatException catch (e) {
      throw ProjectSerializationException('Invalid JSON: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ProjectSerializationException(
        'Expected a JSON object at the top level',
      );
    }
    return fromJson(decoded);
  }

  // --- helpers ---

  Map<String, dynamic> _datasetToJson(ProjectDatasetSource source) {
    return <String, dynamic>{
      if (source.annotationsPath != null)
        'annotations_path': source.annotationsPath,
      if (source.imagesRootPath != null)
        'images_root_path': source.imagesRootPath,
      if (source.annotationsFileName != null)
        'annotations_file_name': source.annotationsFileName,
      if (source.imagesSourceLabel != null)
        'images_source_label': source.imagesSourceLabel,
    };
  }

  ProjectDatasetSource _datasetFromJson(Map<String, dynamic> map) {
    return ProjectDatasetSource(
      annotationsPath: map['annotations_path'] as String?,
      imagesRootPath: map['images_root_path'] as String?,
      annotationsFileName: map['annotations_file_name'] as String?,
      imagesSourceLabel: map['images_source_label'] as String?,
    );
  }

  Map<String, dynamic> _modelRunToJson(ProjectModelRunSource run) {
    return <String, dynamic>{
      'id': run.id,
      'name': run.name,
      if (run.predictionsPath != null) 'predictions_path': run.predictionsPath,
      if (run.predictionsFileName != null)
        'predictions_file_name': run.predictionsFileName,
      'added_at': run.addedAt.toUtc().toIso8601String(),
    };
  }

  ProjectModelRunSource _modelRunFromJson(Map<String, dynamic> map) {
    final String id = _requireString(map, 'id');
    final String name = _requireString(map, 'name');
    final DateTime addedAt = _requireDateTime(map, 'added_at');
    return ProjectModelRunSource(
      id: id,
      name: name,
      predictionsPath: map['predictions_path'] as String?,
      predictionsFileName: map['predictions_file_name'] as String?,
      addedAt: addedAt,
    );
  }

  Map<String, dynamic> _evalConfigToJson(EvalConfig config) {
    return <String, dynamic>{
      'iou_threshold': config.iouThreshold,
      'confidence_threshold': config.confidenceThreshold,
      'class_aware_matching': config.classAwareMatching,
      'ignore_crowd': config.ignoreCrowd,
    };
  }

  EvalConfig _evalConfigFromJson(Map<String, dynamic> map) {
    return EvalConfig(
      iouThreshold: (map['iou_threshold'] as num?)?.toDouble() ?? 0.5,
      confidenceThreshold:
          (map['confidence_threshold'] as num?)?.toDouble() ?? 0.25,
      classAwareMatching: map['class_aware_matching'] as bool? ?? true,
      ignoreCrowd: map['ignore_crowd'] as bool? ?? true,
    );
  }

  String _requireString(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value == null) {
      throw ProjectSerializationException('Missing required field: $key');
    }
    if (value is! String) {
      throw ProjectSerializationException(
        'Field "$key" must be a string, got ${value.runtimeType}',
      );
    }
    return value;
  }

  DateTime _requireDateTime(Map<String, dynamic> map, String key) {
    final String str = _requireString(map, key);
    final DateTime? parsed = DateTime.tryParse(str);
    if (parsed == null) {
      throw ProjectSerializationException(
        'Field "$key" is not a valid ISO 8601 datetime: "$str"',
      );
    }
    return parsed;
  }
}
