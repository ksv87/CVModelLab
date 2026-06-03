import '../ap_eval/ap_eval_models.dart';
import 'eval_config.dart';

/// Whether a project's data lives on the local machine or on a remote server.
enum ProjectMode { local, remote }

class CvmlProject {
  const CvmlProject({
    required this.schemaVersion,
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.datasetSource,
    required this.modelRuns,
    required this.defaultEvalConfig,
    this.activeModelRunId,
    this.mode = ProjectMode.local,
    this.server,
    this.remoteProject,
  });

  final String schemaVersion;
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProjectDatasetSource datasetSource;
  final List<ProjectModelRunSource> modelRuns;
  final EvalConfig defaultEvalConfig;
  final String? activeModelRunId;

  /// Local (default) or remote server mode.
  final ProjectMode mode;

  /// Server reference, present only for [ProjectMode.remote] projects.
  final RemoteServerRef? server;

  /// Remote project descriptor, present only for [ProjectMode.remote] projects.
  final RemoteProjectDescriptor? remoteProject;

  bool get isRemote => mode == ProjectMode.remote;

  CvmlProject copyWith({
    String? name,
    DateTime? updatedAt,
    ProjectDatasetSource? datasetSource,
    List<ProjectModelRunSource>? modelRuns,
    EvalConfig? defaultEvalConfig,
    String? activeModelRunId,
    ProjectMode? mode,
    RemoteServerRef? server,
    RemoteProjectDescriptor? remoteProject,
  }) {
    return CvmlProject(
      schemaVersion: schemaVersion,
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      datasetSource: datasetSource ?? this.datasetSource,
      modelRuns: modelRuns ?? this.modelRuns,
      defaultEvalConfig: defaultEvalConfig ?? this.defaultEvalConfig,
      activeModelRunId: activeModelRunId ?? this.activeModelRunId,
      mode: mode ?? this.mode,
      server: server ?? this.server,
      remoteProject: remoteProject ?? this.remoteProject,
    );
  }
}

/// Reference to a remote CV Model Lab server. The API key is never stored in
/// the project file; [apiKeySaved] only records whether the user opted to save
/// it in local preferences keyed by [url].
class RemoteServerRef {
  const RemoteServerRef({required this.url, this.apiKeySaved = false});

  final String url;
  final bool apiKeySaved;
}

/// A remote model run reference holding server-side paths so reopening a remote
/// project never requires re-selecting files.
class RemoteModelRunRef {
  const RemoteModelRunRef({
    required this.id,
    required this.name,
    this.predictionsPath,
    this.apMetricsPath,
  });

  final String id;
  final String name;
  final String? predictionsPath;
  final String? apMetricsPath;
}

/// Describes how a remote project is sourced: from a server manifest or from
/// custom server paths chosen via the server file browser.
class RemoteProjectDescriptor {
  const RemoteProjectDescriptor({
    required this.source,
    this.manifestId,
    this.annotationsPath,
    this.imagesRootPath,
    this.modelRuns = const <RemoteModelRunRef>[],
  });

  /// 'manifest' or 'custom_paths'.
  final String source;
  final String? manifestId;
  final String? annotationsPath;
  final String? imagesRootPath;
  final List<RemoteModelRunRef> modelRuns;

  bool get isManifest => source == 'manifest';
}

class ProjectDatasetSource {
  const ProjectDatasetSource({
    this.annotationsPath,
    this.imagesRootPath,
    this.annotationsFileName,
    this.imagesSourceLabel,
  });

  final String? annotationsPath;
  final String? imagesRootPath;
  final String? annotationsFileName;
  final String? imagesSourceLabel;
}

class ProjectModelRunSource {
  const ProjectModelRunSource({
    required this.id,
    required this.name,
    required this.addedAt,
    this.predictionsPath,
    this.predictionsFileName,
    this.apEvalResult,
  });

  final String id;
  final String name;
  final String? predictionsPath;
  final String? predictionsFileName;
  final DateTime addedAt;
  final ApEvalResult? apEvalResult;
}
