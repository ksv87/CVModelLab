import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ProjectSerializer serializer = ProjectSerializer();
  final DateTime now = DateTime.utc(2026, 6, 3, 12);

  CvmlProject remoteProject({String source = 'custom_paths'}) {
    return CvmlProject(
      schemaVersion: '2',
      id: 'remote-1',
      name: 'Remote Project',
      createdAt: now,
      updatedAt: now,
      datasetSource: const ProjectDatasetSource(),
      modelRuns: const <ProjectModelRunSource>[],
      defaultEvalConfig: const EvalConfig(iouThreshold: 0.6),
      activeModelRunId: 'run_1',
      mode: ProjectMode.remote,
      server: const RemoteServerRef(url: 'http://server:8080', apiKeySaved: true),
      remoteProject: source == 'manifest'
          ? const RemoteProjectDescriptor(
              source: 'manifest',
              manifestId: 'traffic_lights',
            )
          : const RemoteProjectDescriptor(
              source: 'custom_paths',
              annotationsPath: '/data/ann.json',
              imagesRootPath: '/data/images',
              modelRuns: <RemoteModelRunRef>[
                RemoteModelRunRef(
                  id: 'run_1',
                  name: 'YOLOX',
                  predictionsPath: '/data/preds.json',
                  apMetricsPath: '/data/ap.json',
                ),
              ],
            ),
    );
  }

  test('remote custom_paths project round-trips through schema v2', () {
    final CvmlProject original = remoteProject();
    final String json = serializer.toJsonString(original);
    final CvmlProject restored = serializer.fromJsonString(json);

    expect(restored.schemaVersion, '2');
    expect(restored.isRemote, isTrue);
    expect(restored.server?.url, 'http://server:8080');
    expect(restored.server?.apiKeySaved, isTrue);
    expect(restored.remoteProject?.source, 'custom_paths');
    expect(restored.remoteProject?.annotationsPath, '/data/ann.json');
    expect(restored.remoteProject?.imagesRootPath, '/data/images');
    expect(restored.remoteProject?.modelRuns.single.predictionsPath,
        '/data/preds.json',);
    expect(restored.remoteProject?.modelRuns.single.apMetricsPath, '/data/ap.json');
    expect(restored.activeModelRunId, 'run_1');
    expect(restored.defaultEvalConfig.iouThreshold, 0.6);
  });

  test('remote manifest project round-trips', () {
    final CvmlProject restored =
        serializer.fromJsonString(serializer.toJsonString(remoteProject(source: 'manifest')));
    expect(restored.remoteProject?.isManifest, isTrue);
    expect(restored.remoteProject?.manifestId, 'traffic_lights');
  });

  test('project JSON never contains an API key value', () {
    final String json = serializer.toJsonString(remoteProject());
    // Only the api_key_saved flag is allowed; never an api_key value.
    expect(json.contains('"api_key":'), isFalse);
    expect(json.contains('"api_key_saved":'), isTrue);
  });

  test('legacy v1 project still loads as local', () {
    const String legacy = '''
{
  "schema_version": "1",
  "id": "legacy-1",
  "name": "Legacy",
  "created_at": "2026-01-01T00:00:00.000Z",
  "updated_at": "2026-01-01T00:00:00.000Z",
  "dataset": {"annotations_path": "/a.json", "images_root_path": "/imgs"},
  "model_runs": [
    {"id": "run-1", "name": "M", "predictions_path": "/p.json",
     "added_at": "2026-01-01T00:00:00.000Z"}
  ],
  "default_eval_config": {"iou_threshold": 0.5, "confidence_threshold": 0.25,
    "class_aware_matching": true, "ignore_crowd": true}
}
''';
    final CvmlProject restored = serializer.fromJsonString(legacy);
    expect(restored.mode, ProjectMode.local);
    expect(restored.isRemote, isFalse);
    expect(restored.datasetSource.annotationsPath, '/a.json');
    expect(restored.modelRuns.single.id, 'run-1');
  });

  test('local project serialization stays schema v1', () {
    final CvmlProject local = CvmlProject(
      schemaVersion: '1',
      id: 'p',
      name: 'Local',
      createdAt: now,
      updatedAt: now,
      datasetSource: const ProjectDatasetSource(annotationsPath: '/a.json'),
      modelRuns: const <ProjectModelRunSource>[],
      defaultEvalConfig: const EvalConfig(),
    );
    final String json = serializer.toJsonString(local);
    expect(json.contains('"schema_version": "1"'), isTrue);
    expect(json.contains('"mode"'), isFalse);
  });
}
