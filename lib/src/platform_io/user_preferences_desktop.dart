export 'user_preferences_stub.dart' show createUserPreferencesStore;

import 'dart:convert';
import 'dart:io';

import '../core/preferences/user_preferences_store.dart';

UserPreferencesStore createUserPreferencesStore() {
  return DesktopJsonUserPreferencesStore();
}

class DesktopJsonUserPreferencesStore implements UserPreferencesStore {
  DesktopJsonUserPreferencesStore({String? filePath})
      : _filePath = filePath ?? _defaultPreferencesPath();

  final String _filePath;

  @override
  Future<String?> getString(String key) async {
    return (await _read())[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    final Map<String, String> values = await _read();
    values[key] = value;
    await _write(values);
  }

  @override
  Future<void> remove(String key) async {
    final Map<String, String> values = await _read();
    values.remove(key);
    await _write(values);
  }

  Future<Map<String, String>> _read() async {
    final File file = File(_filePath);
    if (!await file.exists()) {
      return <String, String>{};
    }
    try {
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return <String, String>{};
      }
      return decoded.map(
        (Object? key, Object? value) => MapEntry('$key', '$value'),
      );
    } on Object {
      return <String, String>{};
    }
  }

  Future<void> _write(Map<String, String> values) async {
    final File file = File(_filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(values));
  }
}

String _defaultPreferencesPath() {
  final Map<String, String> env = Platform.environment;
  if (Platform.isMacOS) {
    return '${env['HOME'] ?? '.'}/Library/Application Support/CV Model Lab/preferences.json';
  }
  if (Platform.isWindows) {
    return '${env['APPDATA'] ?? '.'}\\CV Model Lab\\preferences.json';
  }
  return '${env['XDG_CONFIG_HOME'] ?? '${env['HOME'] ?? '.'}/.config'}/cv_model_lab/preferences.json';
}
