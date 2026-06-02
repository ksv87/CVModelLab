import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ProjectSerializer serializer = ProjectSerializer();

  CvmlProject _makeProject({
    List<ProjectModelRunSource>? modelRuns,
    String? activeModelRunId,
    EvalConfig? config,
    ProjectDatasetSource? dataset,
  }) {
    final DateTime now = DateTime.utc(2026, 6, 1, 12, 0, 0);
    return CvmlProject(
      schemaVersion: '1',
      id: 'proj-123',
      name: 'Test Project',
      createdAt: now,
      updatedAt: now.add(const Duration(minutes: 10)),
      datasetSource: dataset ??
          const ProjectDatasetSource(
            annotationsPath: '/data/annotations.json',
            imagesRootPath: '/data/images',
            annotationsFileName: 'annotations.json',
            imagesSourceLabel: 'images/',
          ),
      modelRuns: modelRuns ??
          [
            ProjectModelRunSource(
              id: 'run-1',
              name: 'YOLOX-S',
              predictionsPath: '/data/preds.json',
              predictionsFileName: 'preds.json',
              addedAt: now,
            ),
          ],
      defaultEvalConfig: config ?? const EvalConfig(),
      activeModelRunId: activeModelRunId,
    );
  }

  test('roundtrip: single model run', () {
    final CvmlProject original = _makeProject(activeModelRunId: 'run-1');
    final String json = serializer.toJsonString(original);
    final CvmlProject restored = serializer.fromJsonString(json);

    expect(restored.schemaVersion, '1');
    expect(restored.id, 'proj-123');
    expect(restored.name, 'Test Project');
    expect(restored.activeModelRunId, 'run-1');
    expect(restored.modelRuns.length, 1);
    expect(restored.modelRuns.first.id, 'run-1');
    expect(restored.modelRuns.first.name, 'YOLOX-S');
  });

  test('roundtrip: multiple model runs', () {
    final DateTime now = DateTime.utc(2026, 6, 1);
    final CvmlProject original = _makeProject(
      modelRuns: [
        ProjectModelRunSource(
          id: 'run-1',
          name: 'Model A',
          addedAt: now,
        ),
        ProjectModelRunSource(
          id: 'run-2',
          name: 'Model B',
          predictionsPath: '/preds/b.json',
          predictionsFileName: 'b.json',
          addedAt: now,
        ),
        ProjectModelRunSource(
          id: 'run-3',
          name: 'Model C',
          addedAt: now,
        ),
      ],
      activeModelRunId: 'run-2',
    );

    final CvmlProject restored =
        serializer.fromJsonString(serializer.toJsonString(original));

    expect(restored.modelRuns.length, 3);
    expect(restored.modelRuns[0].id, 'run-1');
    expect(restored.modelRuns[1].id, 'run-2');
    expect(restored.modelRuns[1].predictionsPath, '/preds/b.json');
    expect(restored.modelRuns[2].id, 'run-3');
    expect(restored.activeModelRunId, 'run-2');
  });

  test('activeModelRunId preserved when set', () {
    final CvmlProject project = _makeProject(activeModelRunId: 'run-1');
    final CvmlProject restored =
        serializer.fromJsonString(serializer.toJsonString(project));
    expect(restored.activeModelRunId, 'run-1');
  });

  test('activeModelRunId is null when not set', () {
    final CvmlProject project = _makeProject();
    final CvmlProject restored =
        serializer.fromJsonString(serializer.toJsonString(project));
    expect(restored.activeModelRunId, isNull);
  });

  test('eval config roundtrip', () {
    final EvalConfig config = const EvalConfig(
      iouThreshold: 0.75,
      confidenceThreshold: 0.4,
      classAwareMatching: false,
      ignoreCrowd: false,
    );
    final CvmlProject project = _makeProject(config: config);
    final CvmlProject restored =
        serializer.fromJsonString(serializer.toJsonString(project));

    expect(restored.defaultEvalConfig.iouThreshold, closeTo(0.75, 0.001));
    expect(
      restored.defaultEvalConfig.confidenceThreshold,
      closeTo(0.4, 0.001),
    );
    expect(restored.defaultEvalConfig.classAwareMatching, isFalse);
    expect(restored.defaultEvalConfig.ignoreCrowd, isFalse);
  });

  test('null optional paths are preserved as null (web-safe)', () {
    final CvmlProject project = _makeProject(
      dataset: const ProjectDatasetSource(
        annotationsFileName: 'annotations.json',
      ),
    );
    final CvmlProject restored =
        serializer.fromJsonString(serializer.toJsonString(project));

    expect(restored.datasetSource.annotationsPath, isNull);
    expect(restored.datasetSource.imagesRootPath, isNull);
    expect(restored.datasetSource.annotationsFileName, 'annotations.json');
  });

  test('unknown schema_version throws ProjectSerializationException', () {
    const String json = '''
{
  "schema_version": "99",
  "id": "x",
  "name": "n",
  "created_at": "2026-01-01T00:00:00.000Z",
  "updated_at": "2026-01-01T00:00:00.000Z",
  "dataset": {},
  "model_runs": [],
  "default_eval_config": {"iou_threshold": 0.5, "confidence_threshold": 0.25,
    "class_aware_matching": true, "ignore_crowd": true}
}
''';
    expect(
      () => serializer.fromJsonString(json),
      throwsA(isA<ProjectSerializationException>()),
    );
  });

  test('missing name field throws ProjectSerializationException', () {
    const String json = '''
{
  "schema_version": "1",
  "id": "x",
  "created_at": "2026-01-01T00:00:00.000Z",
  "updated_at": "2026-01-01T00:00:00.000Z",
  "dataset": {},
  "model_runs": [],
  "default_eval_config": {"iou_threshold": 0.5, "confidence_threshold": 0.25,
    "class_aware_matching": true, "ignore_crowd": true}
}
''';
    expect(
      () => serializer.fromJsonString(json),
      throwsA(isA<ProjectSerializationException>()),
    );
  });

  test('missing id field throws ProjectSerializationException', () {
    const String json = '''
{
  "schema_version": "1",
  "name": "Test",
  "created_at": "2026-01-01T00:00:00.000Z",
  "updated_at": "2026-01-01T00:00:00.000Z",
  "dataset": {},
  "model_runs": [],
  "default_eval_config": {"iou_threshold": 0.5, "confidence_threshold": 0.25,
    "class_aware_matching": true, "ignore_crowd": true}
}
''';
    expect(
      () => serializer.fromJsonString(json),
      throwsA(isA<ProjectSerializationException>()),
    );
  });
}
