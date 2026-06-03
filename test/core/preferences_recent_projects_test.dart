import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preferences store saves and removes strings', () async {
    final store = MemoryUserPreferencesStore();

    expect(await store.getString('key'), isNull);
    await store.setString('key', 'value');
    expect(await store.getString('key'), 'value');
    await store.remove('key');
    expect(await store.getString('key'), isNull);
  });

  test('recent projects move existing entry to top', () async {
    final store = MemoryUserPreferencesStore();
    final manager = RecentProjectsManager(store: store);

    await manager.addOrUpdate(
      projectPath: '/tmp/a.cvmlab.json',
      projectName: 'A',
      openedAt: DateTime.utc(2026, 1, 1),
    );
    await manager.addOrUpdate(
      projectPath: '/tmp/b.cvmlab.json',
      projectName: 'B',
      openedAt: DateTime.utc(2026, 1, 2),
    );
    await manager.addOrUpdate(
      projectPath: '/tmp/a.cvmlab.json',
      projectName: 'A new',
      openedAt: DateTime.utc(2026, 1, 3),
    );

    final entries = await manager.list();
    expect(entries.map((entry) => entry.projectPath), [
      '/tmp/a.cvmlab.json',
      '/tmp/b.cvmlab.json',
    ]);
    expect(entries.first.projectName, 'A new');
  });

  test('recent projects max limit and remove work', () async {
    final store = MemoryUserPreferencesStore();
    final manager = RecentProjectsManager(store: store, maxEntries: 2);

    await manager.addOrUpdate(projectPath: '/tmp/a', projectName: 'A');
    await manager.addOrUpdate(projectPath: '/tmp/b', projectName: 'B');
    await manager.addOrUpdate(projectPath: '/tmp/c', projectName: 'C');

    expect((await manager.list()).map((entry) => entry.projectPath), [
      '/tmp/c',
      '/tmp/b',
    ]);

    await manager.remove('/tmp/b');
    expect(
      (await manager.list()).map((entry) => entry.projectPath),
      ['/tmp/c'],
    );
  });

  test('recent projects mark missing files', () async {
    final store = MemoryUserPreferencesStore();
    final manager = RecentProjectsManager(
      store: store,
      existsChecker: (path) async => path.endsWith('exists'),
    );

    await manager.addOrUpdate(
      projectPath: '/tmp/missing',
      projectName: 'Missing',
    );
    await manager.addOrUpdate(
      projectPath: '/tmp/exists',
      projectName: 'Exists',
    );

    final entries = await manager.list();
    expect(entries.first.exists, isTrue);
    expect(entries.last.exists, isFalse);
  });
}
