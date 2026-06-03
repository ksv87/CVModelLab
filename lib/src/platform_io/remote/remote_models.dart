/// Parsed DTOs for CV Model Lab server responses.

class ServerClientConfig {
  const ServerClientConfig({
    required this.authRequired,
    required this.manifestsEnabled,
    required this.customPathsEnabled,
    this.version,
  });

  final bool authRequired;
  final bool manifestsEnabled;
  final bool customPathsEnabled;
  final String? version;

  factory ServerClientConfig.fromJson(Map<String, dynamic> map) {
    return ServerClientConfig(
      authRequired: map['auth_required'] as bool? ?? false,
      manifestsEnabled: map['manifests_enabled'] as bool? ?? false,
      customPathsEnabled: map['custom_paths_enabled'] as bool? ?? false,
      version: map['version'] as String?,
    );
  }
}

class ServerRoot {
  const ServerRoot({required this.id, required this.label});

  final String id;
  final String label;

  factory ServerRoot.fromJson(Map<String, dynamic> map) {
    return ServerRoot(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? (map['id'] as String? ?? ''),
    );
  }
}

class ServerBrowseEntry {
  const ServerBrowseEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.sizeBytes,
    this.modifiedAt,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int? sizeBytes;
  final String? modifiedAt;

  factory ServerBrowseEntry.fromJson(Map<String, dynamic> map) {
    return ServerBrowseEntry(
      name: map['name'] as String? ?? '',
      path: map['path'] as String? ?? '',
      isDirectory: (map['kind'] as String?) == 'directory',
      sizeBytes: (map['size_bytes'] as num?)?.toInt(),
      modifiedAt: map['modified_at'] as String?,
    );
  }
}

class ServerBrowseListing {
  const ServerBrowseListing({
    required this.rootId,
    required this.path,
    required this.absPath,
    required this.entries,
  });

  final String rootId;
  final String path;
  final String? absPath;
  final List<ServerBrowseEntry> entries;

  factory ServerBrowseListing.fromJson(Map<String, dynamic> map) {
    final List<dynamic> entriesRaw =
        map['entries'] as List<dynamic>? ?? const [];
    return ServerBrowseListing(
      rootId: map['root_id'] as String? ?? '',
      path: map['path'] as String? ?? '',
      absPath: map['abs_path'] as String?,
      entries: entriesRaw
          .whereType<Map<String, dynamic>>()
          .map(ServerBrowseEntry.fromJson)
          .toList(),
    );
  }
}

class ServerManifestSummary {
  const ServerManifestSummary({required this.id, required this.name});

  final String id;
  final String name;

  factory ServerManifestSummary.fromJson(Map<String, dynamic> map) {
    return ServerManifestSummary(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? (map['id'] as String? ?? ''),
    );
  }
}

class ServerModelRunInfo {
  const ServerModelRunInfo({required this.id, required this.name});

  final String id;
  final String name;

  factory ServerModelRunInfo.fromJson(Map<String, dynamic> map) {
    return ServerModelRunInfo(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? (map['id'] as String? ?? ''),
    );
  }
}

class ServerSessionInfo {
  const ServerSessionInfo({
    required this.sessionId,
    required this.projectHash,
    required this.name,
    required this.source,
    required this.manifestId,
    required this.modelRuns,
    required this.images,
    required this.categories,
    required this.annotations,
    required this.missingImages,
  });

  final String sessionId;
  final String projectHash;
  final String name;
  final String source;
  final String? manifestId;
  final List<ServerModelRunInfo> modelRuns;
  final int images;
  final int categories;
  final int annotations;
  final int missingImages;

  factory ServerSessionInfo.fromJson(Map<String, dynamic> map) {
    final Map<String, dynamic> summary =
        (map['summary'] as Map<String, dynamic>?) ?? const {};
    final List<dynamic> runsRaw =
        map['model_runs'] as List<dynamic>? ?? const [];
    return ServerSessionInfo(
      sessionId: map['session_id'] as String? ?? '',
      projectHash: map['project_hash'] as String? ?? '',
      name: map['name'] as String? ?? 'Remote project',
      source: map['source'] as String? ?? 'custom_paths',
      manifestId: map['manifest_id'] as String?,
      modelRuns: runsRaw
          .whereType<Map<String, dynamic>>()
          .map(ServerModelRunInfo.fromJson)
          .toList(),
      images: (summary['images'] as num?)?.toInt() ?? 0,
      categories: (summary['categories'] as num?)?.toInt() ?? 0,
      annotations: (summary['annotations'] as num?)?.toInt() ?? 0,
      missingImages: (summary['missing_images'] as num?)?.toInt() ?? 0,
    );
  }
}
