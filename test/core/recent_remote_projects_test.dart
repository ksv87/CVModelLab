import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:cv_model_lab/src/core/preferences/recent_remote_projects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores remote descriptors without API keys', () async {
    final store = MemoryUserPreferencesStore();
    final manager = RecentRemoteProjectsManager(store: store);

    await manager.addOrUpdate(
      serverUrl: 'https://cvmlab.example',
      projectName: 'Traffic',
      descriptor: const RemoteProjectDescriptor(
        source: 'custom_paths',
        annotationsPath: '/data/ann.json',
        imagesRootPath: '/data/images',
        modelRuns: [
          RemoteModelRunRef(
            id: 'run_1',
            name: 'Run 1',
            predictionsPath: '/data/pred.json',
            apMetricsPath: '/data/ap.json',
          ),
        ],
      ),
    );

    final raw = await store.getString(PreferenceKeys.recentRemoteProjects);
    expect(raw, isNotNull);
    expect(raw, contains('https://cvmlab.example'));
    expect(raw, contains('/data/ann.json'));
    expect(raw, isNot(contains('"api_key":')));
    expect(raw, isNot(contains('secret')));

    final entries = await manager.list();
    expect(entries.single.serverUrl, 'https://cvmlab.example');
    expect(
      entries.single.descriptor.modelRuns.single.apMetricsPath,
      '/data/ap.json',
    );
  });
}
