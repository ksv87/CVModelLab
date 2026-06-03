import 'dart:convert';

import 'user_preferences_store.dart';

class RecentProjectEntry {
  const RecentProjectEntry({
    required this.projectPath,
    required this.projectName,
    required this.lastOpenedAt,
    this.lastModifiedAt,
    this.exists = true,
  });

  final String projectPath;
  final String projectName;
  final DateTime lastOpenedAt;
  final DateTime? lastModifiedAt;
  final bool exists;

  RecentProjectEntry copyWith({
    String? projectPath,
    String? projectName,
    DateTime? lastOpenedAt,
    DateTime? lastModifiedAt,
    bool clearLastModifiedAt = false,
    bool? exists,
  }) {
    return RecentProjectEntry(
      projectPath: projectPath ?? this.projectPath,
      projectName: projectName ?? this.projectName,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      lastModifiedAt:
          clearLastModifiedAt ? null : (lastModifiedAt ?? this.lastModifiedAt),
      exists: exists ?? this.exists,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'project_path': projectPath,
      'project_name': projectName,
      'last_opened_at': lastOpenedAt.toIso8601String(),
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'exists': exists,
    };
  }

  static RecentProjectEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final Object? path = value['project_path'];
    final Object? name = value['project_name'];
    final Object? opened = value['last_opened_at'];
    if (path is! String || name is! String || opened is! String) {
      return null;
    }
    final DateTime? openedAt = DateTime.tryParse(opened);
    if (openedAt == null) return null;
    final Object? modified = value['last_modified_at'];
    return RecentProjectEntry(
      projectPath: path,
      projectName: name,
      lastOpenedAt: openedAt,
      lastModifiedAt: modified is String ? DateTime.tryParse(modified) : null,
      exists: value['exists'] is bool ? value['exists'] as bool : true,
    );
  }
}

typedef ProjectExistsChecker = Future<bool> Function(String path);
typedef ProjectModifiedAtReader = Future<DateTime?> Function(String path);

class RecentProjectsManager {
  const RecentProjectsManager({
    required UserPreferencesStore store,
    this.maxEntries = 10,
    ProjectExistsChecker? existsChecker,
    ProjectModifiedAtReader? modifiedAtReader,
  })  : _store = store,
        _existsChecker = existsChecker,
        _modifiedAtReader = modifiedAtReader;

  final UserPreferencesStore _store;
  final int maxEntries;
  final ProjectExistsChecker? _existsChecker;
  final ProjectModifiedAtReader? _modifiedAtReader;

  Future<List<RecentProjectEntry>> list() async {
    final List<RecentProjectEntry> entries = await _loadRaw();
    final List<RecentProjectEntry> refreshed = [];
    for (final RecentProjectEntry entry in entries) {
      final ProjectExistsChecker? existsChecker = _existsChecker;
      final ProjectModifiedAtReader? modifiedAtReader = _modifiedAtReader;
      final bool exists = existsChecker == null
          ? entry.exists
          : await existsChecker(entry.projectPath);
      final DateTime? modifiedAt = exists && modifiedAtReader != null
          ? await modifiedAtReader(entry.projectPath)
          : entry.lastModifiedAt;
      refreshed.add(
        entry.copyWith(
          exists: exists,
          lastModifiedAt: modifiedAt,
          clearLastModifiedAt: modifiedAt == null,
        ),
      );
    }
    return refreshed;
  }

  Future<void> addOrUpdate({
    required String projectPath,
    required String projectName,
    DateTime? openedAt,
    DateTime? modifiedAt,
  }) async {
    final DateTime now = openedAt ?? DateTime.now();
    final List<RecentProjectEntry> current = await _loadRaw();
    final List<RecentProjectEntry> next = [
      RecentProjectEntry(
        projectPath: projectPath,
        projectName: projectName,
        lastOpenedAt: now,
        lastModifiedAt: modifiedAt,
        exists: true,
      ),
      for (final RecentProjectEntry entry in current)
        if (entry.projectPath != projectPath) entry,
    ].take(maxEntries).toList();
    await _save(next);
  }

  Future<void> remove(String projectPath) async {
    final List<RecentProjectEntry> next = [
      for (final RecentProjectEntry entry in await _loadRaw())
        if (entry.projectPath != projectPath) entry,
    ];
    await _save(next);
  }

  Future<void> clear() async {
    await _store.remove(PreferenceKeys.recentProjects);
  }

  Future<List<RecentProjectEntry>> _loadRaw() async {
    final String? json = await _store.getString(PreferenceKeys.recentProjects);
    if (json == null || json.isEmpty) {
      return const <RecentProjectEntry>[];
    }
    try {
      final Object? decoded = jsonDecode(json);
      if (decoded is! List) {
        return const <RecentProjectEntry>[];
      }
      return [
        for (final Object? value in decoded)
          if (RecentProjectEntry.fromJson(value) != null)
            RecentProjectEntry.fromJson(value)!,
      ];
    } on Object {
      return const <RecentProjectEntry>[];
    }
  }

  Future<void> _save(List<RecentProjectEntry> entries) async {
    await _store.setString(
      PreferenceKeys.recentProjects,
      jsonEncode(
        entries.map((RecentProjectEntry entry) => entry.toJson()).toList(),
      ),
    );
  }
}
