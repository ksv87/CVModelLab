import '../core/preferences/user_preferences_store.dart';

UserPreferencesStore createUserPreferencesStore() {
  return MemoryUserPreferencesStore();
}
