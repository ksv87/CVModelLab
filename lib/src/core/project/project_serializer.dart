import 'dart:convert';

import '../ap_eval/ap_eval_models.dart';
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

  static const String _localSchemaVersion = '1';
  static const String _remoteSchemaVersion = '2';
  static const Set<String> _supportedSchemaVersions = {'1', '2'};

  Map<String, dynamic> toJson(CvmlProject project) {
    if (project.mode == ProjectMode.remote) {
      return _remoteToJson(project);
    }
    return <String, dynamic>{
      'schema_version': _localSchemaVersion,
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

  Map<String, dynamic> _remoteToJson(CvmlProject project) {
    final RemoteServerRef? server = project.server;
    final RemoteProjectDescriptor? remote = project.remoteProject;
    return <String, dynamic>{
      'schema_version': _remoteSchemaVersion,
      'mode': 'remote',
      'id': project.id,
      'name': project.name,
      'created_at': project.createdAt.toUtc().toIso8601String(),
      'updated_at': project.updatedAt.toUtc().toIso8601String(),
      if (server != null)
        'server': <String, dynamic>{
          'url': server.url,
          'api_key_saved': server.apiKeySaved,
        },
      if (remote != null) 'remote_project': _remoteProjectToJson(remote),
      if (project.activeModelRunId != null)
        'active_model_run_id': project.activeModelRunId,
      'default_eval_config': _evalConfigToJson(project.defaultEvalConfig),
    };
  }

  Map<String, dynamic> _remoteProjectToJson(RemoteProjectDescriptor remote) {
    return <String, dynamic>{
      'source': remote.source,
      if (remote.manifestId != null) 'manifest_id': remote.manifestId,
      if (remote.annotationsPath != null)
        'annotations_path': remote.annotationsPath,
      if (remote.imagesRootPath != null)
        'images_root_path': remote.imagesRootPath,
      if (remote.modelRuns.isNotEmpty)
        'model_runs': [
          for (final RemoteModelRunRef run in remote.modelRuns)
            <String, dynamic>{
              'id': run.id,
              'name': run.name,
              if (run.predictionsPath != null)
                'predictions_path': run.predictionsPath,
              if (run.apMetricsPath != null)
                'ap_metrics_path': run.apMetricsPath,
            },
        ],
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
    if (schemaVersion is! String ||
        !_supportedSchemaVersions.contains(schemaVersion)) {
      throw ProjectSerializationException(
        'Unknown schema_version: "$schemaVersion". '
        'Supported versions: ${_supportedSchemaVersions.join(', ')}.',
      );
    }

    // Projects without a "mode" field are legacy local projects.
    final String modeRaw = (map['mode'] as String?) ?? 'local';
    if (modeRaw == 'remote') {
      return _remoteFromJson(map, schemaVersion);
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
      schemaVersion: schemaVersion,
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

  CvmlProject _remoteFromJson(Map<String, dynamic> map, String schemaVersion) {
    final String id = _requireString(map, 'id');
    final String name = _requireString(map, 'name');
    final DateTime createdAt = _requireDateTime(map, 'created_at');
    final DateTime updatedAt = _requireDateTime(map, 'updated_at');

    RemoteServerRef? server;
    final Object? serverRaw = map['server'];
    if (serverRaw is Map<String, dynamic>) {
      server = RemoteServerRef(
        url: (serverRaw['url'] as String?) ?? '',
        apiKeySaved: serverRaw['api_key_saved'] as bool? ?? false,
      );
    }

    RemoteProjectDescriptor? remote;
    final Object? remoteRaw = map['remote_project'];
    if (remoteRaw is Map<String, dynamic>) {
      remote = _remoteProjectFromJson(remoteRaw);
    }

    final Object? defaultConfigRaw = map['default_eval_config'];
    final EvalConfig defaultEvalConfig =
        defaultConfigRaw is Map<String, dynamic>
            ? _evalConfigFromJson(defaultConfigRaw)
            : const EvalConfig();

    return CvmlProject(
      schemaVersion: schemaVersion,
      id: id,
      name: name,
      createdAt: createdAt,
      updatedAt: updatedAt,
      datasetSource: const ProjectDatasetSource(),
      modelRuns: const <ProjectModelRunSource>[],
      defaultEvalConfig: defaultEvalConfig,
      activeModelRunId: map['active_model_run_id'] as String?,
      mode: ProjectMode.remote,
      server: server,
      remoteProject: remote,
    );
  }

  RemoteProjectDescriptor _remoteProjectFromJson(Map<String, dynamic> map) {
    final Object? runsRaw = map['model_runs'];
    final List<RemoteModelRunRef> runs = runsRaw is List<dynamic>
        ? runsRaw
            .whereType<Map<String, dynamic>>()
            .map(
              (Map<String, dynamic> run) => RemoteModelRunRef(
                id: (run['id'] as String?) ?? '',
                name: (run['name'] as String?) ?? 'Model run',
                predictionsPath: run['predictions_path'] as String?,
                apMetricsPath: run['ap_metrics_path'] as String?,
              ),
            )
            .toList()
        : const <RemoteModelRunRef>[];
    return RemoteProjectDescriptor(
      source: (map['source'] as String?) ?? 'custom_paths',
      manifestId: map['manifest_id'] as String?,
      annotationsPath: map['annotations_path'] as String?,
      imagesRootPath: map['images_root_path'] as String?,
      modelRuns: runs,
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
      if (run.apEvalResult != null)
        'ap_eval_result': const ApEvalResultParser().toJson(run.apEvalResult!),
    };
  }

  ProjectModelRunSource _modelRunFromJson(Map<String, dynamic> map) {
    final String id = _requireString(map, 'id');
    final String name = _requireString(map, 'name');
    final DateTime addedAt = _requireDateTime(map, 'added_at');
    final Object? apRaw = map['ap_eval_result'];
    final ApEvalResult? apEvalResult = apRaw is Map<String, dynamic>
        ? const ApEvalResultParser().fromJson(apRaw)
        : null;
    return ProjectModelRunSource(
      id: id,
      name: name,
      predictionsPath: map['predictions_path'] as String?,
      predictionsFileName: map['predictions_file_name'] as String?,
      addedAt: addedAt,
      apEvalResult: apEvalResult,
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
