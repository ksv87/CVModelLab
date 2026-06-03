export 'recent_projects_io_stub.dart' show createRecentProjectsManager;

import 'dart:io';

import '../core/preferences/recent_projects.dart';
import '../core/preferences/user_preferences_store.dart';

RecentProjectsManager createRecentProjectsManager(UserPreferencesStore store) {
  return RecentProjectsManager(
    store: store,
    maxEntries: 12,
    existsChecker: (String path) => File(path).exists(),
    modifiedAtReader: (String path) async {
      final File file = File(path);
      if (!await file.exists()) {
        return null;
      }
      return file.lastModified();
    },
  );
}
