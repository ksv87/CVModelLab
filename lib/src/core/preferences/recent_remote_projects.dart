import 'dart:convert';

import '../model/eval_config.dart';
import '../model/project.dart';
import '../project/project_serializer.dart';
import 'user_preferences_store.dart';

class RecentRemoteProjectEntry {
  const RecentRemoteProjectEntry({
    required this.serverUrl,
    required this.projectName,
    required this.descriptor,
    required this.lastOpenedAt,
    this.activeModelRunId,
    this.defaultEvalConfig = const EvalConfig(),
  });

  final String serverUrl;
  final String projectName;
  final RemoteProjectDescriptor descriptor;
  final DateTime lastOpenedAt;
  final String? activeModelRunId;
  final EvalConfig defaultEvalConfig;

  String get key {
    final String sourceKey = descriptor.isManifest
        ? 'manifest:${descriptor.manifestId ?? ''}'
        : 'custom:${descriptor.annotationsPath ?? ''}:${descriptor.imagesRootPath ?? ''}';
    return '$serverUrl|$sourceKey';
  }

  Map<String, Object?> toJson() {
    final CvmlProject project = CvmlProject(
      schemaVersion: '2',
      id: key,
      name: projectName,
      createdAt: lastOpenedAt,
      updatedAt: lastOpenedAt,
      datasetSource: const ProjectDatasetSource(),
      modelRuns: const <ProjectModelRunSource>[],
      defaultEvalConfig: defaultEvalConfig,
      activeModelRunId: activeModelRunId,
      mode: ProjectMode.remote,
      server: RemoteServerRef(url: serverUrl, apiKeySaved: false),
      remoteProject: descriptor,
    );
    return <String, Object?>{
      'last_opened_at': lastOpenedAt.toIso8601String(),
      'project': const ProjectSerializer().toJson(project),
    };
  }

  static RecentRemoteProjectEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final Object? openedRaw = value['last_opened_at'];
    final Object? projectRaw = value['project'];
    if (openedRaw is! String || projectRaw is! Map) return null;
    final DateTime? opened = DateTime.tryParse(openedRaw);
    if (opened == null) return null;
    final CvmlProject project = const ProjectSerializer().fromJson(
      Map<String, dynamic>.from(projectRaw),
    );
    final RemoteServerRef? server = project.server;
    final RemoteProjectDescriptor? descriptor = project.remoteProject;
    if (server == null || descriptor == null) return null;
    return RecentRemoteProjectEntry(
      serverUrl: server.url,
      projectName: project.name,
      descriptor: descriptor,
      lastOpenedAt: opened,
      activeModelRunId: project.activeModelRunId,
      defaultEvalConfig: project.defaultEvalConfig,
    );
  }
}

class RecentRemoteProjectsManager {
  const RecentRemoteProjectsManager({
    required UserPreferencesStore store,
    this.maxEntries = 12,
  }) : _store = store;

  final UserPreferencesStore _store;
  final int maxEntries;

  Future<List<RecentRemoteProjectEntry>> list() async {
    final String? json =
        await _store.getString(PreferenceKeys.recentRemoteProjects);
    if (json == null || json.isEmpty) return const <RecentRemoteProjectEntry>[];
    try {
      final Object? decoded = jsonDecode(json);
      if (decoded is! List) return const <RecentRemoteProjectEntry>[];
      return [
        for (final Object? value in decoded)
          if (RecentRemoteProjectEntry.fromJson(value) != null)
            RecentRemoteProjectEntry.fromJson(value)!,
      ];
    } on Object {
      return const <RecentRemoteProjectEntry>[];
    }
  }

  Future<void> addOrUpdate({
    required String serverUrl,
    required String projectName,
    required RemoteProjectDescriptor descriptor,
    String? activeModelRunId,
    EvalConfig defaultEvalConfig = const EvalConfig(),
    DateTime? openedAt,
  }) async {
    final RecentRemoteProjectEntry nextEntry = RecentRemoteProjectEntry(
      serverUrl: serverUrl,
      projectName: projectName,
      descriptor: descriptor,
      activeModelRunId: activeModelRunId,
      defaultEvalConfig: defaultEvalConfig,
      lastOpenedAt: openedAt ?? DateTime.now(),
    );
    final List<RecentRemoteProjectEntry> current = await list();
    final List<RecentRemoteProjectEntry> next = [
      nextEntry,
      for (final RecentRemoteProjectEntry entry in current)
        if (entry.key != nextEntry.key) entry,
    ].take(maxEntries).toList();
    await _store.setString(
      PreferenceKeys.recentRemoteProjects,
      jsonEncode(next.map((RecentRemoteProjectEntry e) => e.toJson()).toList()),
    );
  }

  Future<void> remove(String key) async {
    final List<RecentRemoteProjectEntry> next = [
      for (final RecentRemoteProjectEntry entry in await list())
        if (entry.key != key) entry,
    ];
    await _store.setString(
      PreferenceKeys.recentRemoteProjects,
      jsonEncode(next.map((RecentRemoteProjectEntry e) => e.toJson()).toList()),
    );
  }
}
