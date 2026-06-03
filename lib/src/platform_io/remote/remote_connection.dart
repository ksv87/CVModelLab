import 'package:cv_model_lab/cv_model_lab.dart';

import 'cvml_api_client.dart';
import 'remote_models.dart';
import 'remote_workspace.dart';

/// High-level, typed access to a CV Model Lab server over a [CvmlApiClient].
class RemoteServerConnection {
  RemoteServerConnection({required this.client});

  final CvmlApiClient client;

  String get baseUrl => client.baseUrl;

  Future<bool> testConnection() async {
    final Map<String, dynamic> body = await client.getJson('/api/health');
    return body['status'] == 'ok';
  }

  Future<ServerClientConfig> fetchConfig() async {
    return ServerClientConfig.fromJson(await client.getJson('/api/config'));
  }

  Future<List<ServerRoot>> listRoots() async {
    final Map<String, dynamic> body = await client.getJson('/api/roots');
    final List<dynamic> roots = body['roots'] as List<dynamic>? ?? const [];
    return roots
        .whereType<Map<String, dynamic>>()
        .map(ServerRoot.fromJson)
        .toList();
  }

  Future<ServerBrowseListing> browse({
    required String rootId,
    String path = '',
    bool jsonOnly = false,
  }) async {
    final Map<String, dynamic> body = await client.getJson(
      '/api/browse',
      query: <String, String>{
        'root_id': rootId,
        'path': path,
        if (jsonOnly) 'files': 'json',
      },
    );
    return ServerBrowseListing.fromJson(body);
  }

  Future<List<ServerManifestSummary>> listManifests() async {
    final Map<String, dynamic> body = await client.getJson('/api/manifests');
    if (body['enabled'] != true) {
      return const <ServerManifestSummary>[];
    }
    final List<dynamic> manifests =
        body['manifests'] as List<dynamic>? ?? const [];
    return manifests
        .whereType<Map<String, dynamic>>()
        .map(ServerManifestSummary.fromJson)
        .toList();
  }

  Future<ServerSessionInfo> openManifest(String manifestId) async {
    final Map<String, dynamic> body = await client.postJson(
      '/api/sessions/open',
      body: <String, dynamic>{'source': 'manifest', 'manifest_id': manifestId},
    );
    return ServerSessionInfo.fromJson(body);
  }

  Future<ServerSessionInfo> openCustomPaths({
    required String name,
    required String annotationsPath,
    required String imagesRootPath,
    required List<Map<String, dynamic>> modelRuns,
  }) async {
    final Map<String, dynamic> body = await client.postJson(
      '/api/sessions/open',
      body: <String, dynamic>{
        'source': 'custom_paths',
        'name': name,
        'annotations_path': annotationsPath,
        'images_root_path': imagesRootPath,
        'model_runs': modelRuns,
      },
    );
    return ServerSessionInfo.fromJson(body);
  }

  Map<String, String> _configQuery(EvalConfig config) {
    return <String, String>{
      'iou_threshold': '${config.iouThreshold}',
      'confidence_threshold': '${config.confidenceThreshold}',
      'class_aware_matching': '${config.classAwareMatching}',
      'ignore_crowd': '${config.ignoreCrowd}',
    };
  }

  Future<RemoteWorkspaceData> loadWorkspace({
    required String sessionId,
    required String modelRunId,
    required String modelRunName,
    EvalConfig config = const EvalConfig(),
  }) async {
    final Map<String, dynamic> full = await client.getJson(
      '/api/sessions/$sessionId/eval/$modelRunId/full',
      query: _configQuery(config),
    );
    return buildRemoteWorkspace(
      client: client,
      sessionId: sessionId,
      modelRunId: modelRunId,
      modelRunName: modelRunName,
      full: full,
    );
  }

  Future<ApEvalResult> runApMetrics(String sessionId, String modelRunId) async {
    final Map<String, dynamic> body =
        await client.postJson('/api/sessions/$sessionId/ap/$modelRunId/run');
    return const ApEvalResultParser().fromJson(body);
  }

  Future<ApEvalResult?> getApMetrics(
      String sessionId, String modelRunId,) async {
    try {
      final Map<String, dynamic> body =
          await client.getJson('/api/sessions/$sessionId/ap/$modelRunId');
      return const ApEvalResultParser().fromJson(body);
    } on RemoteApiException {
      return null;
    }
  }
}
