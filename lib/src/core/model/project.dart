import '../ap_eval/ap_eval_models.dart';
import 'eval_config.dart';

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

  CvmlProject copyWith({
    String? name,
    DateTime? updatedAt,
    ProjectDatasetSource? datasetSource,
    List<ProjectModelRunSource>? modelRuns,
    EvalConfig? defaultEvalConfig,
    String? activeModelRunId,
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
    );
  }
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
