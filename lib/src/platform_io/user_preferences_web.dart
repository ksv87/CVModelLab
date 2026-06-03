export 'user_preferences_stub.dart' show createUserPreferencesStore;

// ignore: deprecated_member_use
import 'dart:html' as html;

import '../core/preferences/user_preferences_store.dart';

UserPreferencesStore createUserPreferencesStore() {
  return const WebUserPreferencesStore();
}

class WebUserPreferencesStore implements UserPreferencesStore {
  const WebUserPreferencesStore();

  static const String _prefix = 'cv_model_lab.';

  @override
  Future<String?> getString(String key) async {
    return html.window.localStorage['$_prefix$key'];
  }

  @override
  Future<void> setString(String key, String value) async {
    html.window.localStorage['$_prefix$key'] = value;
  }

  @override
  Future<void> remove(String key) async {
    html.window.localStorage.remove('$_prefix$key');
  }
}
