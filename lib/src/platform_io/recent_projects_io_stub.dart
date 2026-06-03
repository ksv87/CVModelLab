import '../core/preferences/recent_projects.dart';
import '../core/preferences/user_preferences_store.dart';

RecentProjectsManager createRecentProjectsManager(UserPreferencesStore store) {
  return RecentProjectsManager(store: store);
}
