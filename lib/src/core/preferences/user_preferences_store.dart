abstract interface class UserPreferencesStore {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);
}

class MemoryUserPreferencesStore implements UserPreferencesStore {
  MemoryUserPreferencesStore([Map<String, String>? initialValues])
      : _values = Map<String, String>.of(initialValues ?? const {});

  final Map<String, String> _values;

  @override
  Future<String?> getString(String key) async => _values[key];

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

class PreferenceKeys {
  static const String lastAnnotationsDirectory = 'last_annotations_directory';
  static const String lastPredictionsDirectory = 'last_predictions_directory';
  static const String lastImagesDirectory = 'last_images_directory';
  static const String lastExportDirectory = 'last_export_directory';
  static const String lastProjectDirectory = 'last_project_directory';
  static const String lastApMetricsImportDirectory =
      'last_ap_metrics_import_directory';
  static const String recentProjects = 'recent_projects';
  static const String appLocale = 'app_locale';
  static const String appTheme = 'app_theme';

  /// Last selected Model Compare mode ('pairwise' or 'multi').
  static const String lastCompareMode = 'last_compare_mode';

  /// Last selected multi-model leaderboard ranking metric (enum name).
  static const String lastRankingMetric = 'last_ranking_metric';
}
