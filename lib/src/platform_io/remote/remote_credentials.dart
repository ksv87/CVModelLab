import '../../core/preferences/user_preferences_store.dart';

/// Stores per-server API keys in local preferences, only when the user opts in.
/// The key is associated with the server URL and is never written to a project
/// file.
class RemoteCredentialStore {
  RemoteCredentialStore(this._prefs);

  final UserPreferencesStore _prefs;

  static String _keyFor(String serverUrl) =>
      'remote_api_key:${serverUrl.trim()}';

  Future<String?> getApiKey(String serverUrl) {
    return _prefs.getString(_keyFor(serverUrl));
  }

  Future<void> saveApiKey(String serverUrl, String apiKey) {
    return _prefs.setString(_keyFor(serverUrl), apiKey);
  }

  Future<void> clearApiKey(String serverUrl) {
    return _prefs.remove(_keyFor(serverUrl));
  }
}
