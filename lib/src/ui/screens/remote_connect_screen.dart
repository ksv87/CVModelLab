import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import '../../platform_io/image_source.dart';
import '../../platform_io/remote/api_base.dart';
import '../../platform_io/remote/cvml_api_client.dart';
import '../../platform_io/remote/remote_connection.dart';
import '../../platform_io/remote/remote_credentials.dart';
import '../../platform_io/remote/remote_models.dart';
import '../../platform_io/remote/remote_workspace.dart';
import '../../platform_io/user_preferences.dart';
import '../l10n/app_locale_scope.dart';
import '../l10n/app_localizations.dart';
import 'remote_server_browser.dart';
import 'workspace_screen.dart';

/// A pre-selected remote project to auto-open (used when reopening a saved
/// remote `.cvmlab.json`).
class RemoteReopenRequest {
  const RemoteReopenRequest({
    required this.serverUrl,
    required this.descriptor,
    this.activeModelRunId,
    this.defaultEvalConfig = const EvalConfig(),
  });

  final String serverUrl;
  final RemoteProjectDescriptor descriptor;
  final String? activeModelRunId;
  final EvalConfig defaultEvalConfig;
}

class RemoteConnectScreen extends StatefulWidget {
  const RemoteConnectScreen({this.reopen, super.key});

  final RemoteReopenRequest? reopen;

  @override
  State<RemoteConnectScreen> createState() => _RemoteConnectScreenState();
}

class _RemoteConnectScreenState extends State<RemoteConnectScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  late final RemoteCredentialStore _credentials =
      RemoteCredentialStore(createUserPreferencesStore());

  bool _saveApiKey = false;
  bool _hasSavedKey = false;
  bool _busy = false;
  String? _status;
  String? _error;

  ServerClientConfig? _serverConfig;
  RemoteServerConnection? _connection;
  List<ServerManifestSummary> _manifests = const [];

  /// Confirmed by probing the current origin: the PWA is being served by a CV
  /// Model Lab backend, so the server URL is fixed to that origin.
  bool _servedFromBackend = false;

  /// True while the startup probe is still deciding whether this web build is
  /// served by a backend (URL stays locked until the probe resolves).
  bool _probing = false;

  @override
  void initState() {
    super.initState();
    final String? origin = sameOriginServerUrl();
    if (widget.reopen != null) {
      _urlController.text = widget.reopen!.serverUrl;
    } else if (origin != null) {
      // Web: optimistically show the origin while we probe whether a backend
      // actually serves this app. Keep the field locked during the probe.
      _urlController.text = origin;
      _probing = true;
    }
    _urlController.addListener(_onUrlChanged);
    _apiKeyController.addListener(_invalidateActiveConnection);
    final String initialUrl = _urlController.text.trim();
    if (initialUrl.isNotEmpty) {
      _loadSavedApiKey(initialUrl);
    }
    if (widget.reopen != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
    } else if (origin != null) {
      _detectServedMode(origin);
    }
  }

  /// Decides whether the web build is served by a CV Model Lab backend by
  /// probing `/api/config` at [origin]. A valid config (200) or a 401 (server
  /// present but requires a key) means the backend serves this app, so the URL
  /// is fixed. Anything else — a 404, a network error, or an HTML page from the
  /// `flutter run` dev server / a separate host — means standalone web, where
  /// the user types the server address manually like on desktop.
  Future<void> _detectServedMode(String origin) async {
    bool served;
    try {
      await RemoteServerConnection(
        client: HttpCvmlApiClient(baseUrl: origin),
      ).fetchConfig();
      served = true;
    } on RemoteApiException catch (e) {
      served = e.isUnauthorized;
    } on Object {
      served = false;
    }
    if (!mounted) return;
    setState(() {
      _probing = false;
      _servedFromBackend = served;
      if (!served) {
        // The origin is not a backend (dev server / separate host): clear the
        // prefilled origin so the user enters the real server address.
        _urlController.clear();
      }
    });
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _apiKeyController.removeListener(_invalidateActiveConnection);
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    // Editing the URL invalidates a connection established with the old URL.
    _invalidateActiveConnection();
    // When the user finishes typing/pasting a server URL that has a saved key,
    // surface it instead of leaving the field misleadingly empty. Only fill an
    // empty field so we never clobber a key the user is actively entering.
    final String url = _urlController.text.trim();
    if (url.isEmpty || _apiKeyController.text.trim().isNotEmpty) return;
    _loadSavedApiKey(url);
  }

  /// Tears down a previously established connection when the URL or API key is
  /// edited, so server projects cannot be opened with credentials that no
  /// longer match what was tested. The user must press "Test connection" again.
  void _invalidateActiveConnection() {
    if (_connection == null &&
        _serverConfig == null &&
        _manifests.isEmpty &&
        _status == null) {
      return;
    }
    setState(() {
      _connection = null;
      _serverConfig = null;
      _manifests = const [];
      _status = null;
    });
  }

  /// Prefills the API key field and the "save key" checkbox from the locally
  /// stored credential for [url], so a previously saved key is visible rather
  /// than only being applied silently at connect time.
  Future<void> _loadSavedApiKey(String url) async {
    final String? saved = await _credentials.getApiKey(url);
    if (!mounted || saved == null || saved.isEmpty) return;
    if (_apiKeyController.text.trim().isNotEmpty) return;
    _apiKeyController.text = saved;
    setState(() {
      _saveApiKey = true;
      _hasSavedKey = true;
    });
  }

  /// Removes the locally stored API key for the current server URL and resets
  /// the form, so a previously saved authorization can be discarded.
  Future<void> _forgetSavedKey() async {
    final String url = _urlController.text.trim();
    if (url.isEmpty) return;
    await _credentials.clearApiKey(url);
    if (!mounted) return;
    // Clearing the field notifies the key listener, which invalidates any live
    // connection on its own; do it outside setState to avoid a nested call.
    _apiKeyController.clear();
    setState(() {
      _saveApiKey = false;
      _hasSavedKey = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_l10n.t(MessageKey.remoteApiKeyCleared))),
    );
  }

  AppLocalizations get _l10n => AppLocaleScope.l10n(context);

  Future<void> _connect() async {
    final String url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
      // Drop any connection/manifest list from a previous attempt so a failed
      // re-connect can never leave a usable session behind.
      _connection = null;
      _serverConfig = null;
      _manifests = const [];
    });
    String? apiKey = _apiKeyController.text.trim();
    try {
      if (apiKey.isEmpty) {
        apiKey = await _credentials.getApiKey(url);
      }
      final CvmlApiClient client =
          HttpCvmlApiClient(baseUrl: url, apiKey: apiKey);
      final RemoteServerConnection connection =
          RemoteServerConnection(client: client);
      // When auth is enabled every endpoint requires the key, so fetchConfig
      // itself validates it: a missing/wrong key throws 401 here and aborts the
      // connect (handled below).
      final ServerClientConfig config = await connection.fetchConfig();
      final List<ServerManifestSummary> manifests =
          config.manifestsEnabled ? await connection.listManifests() : const [];
      // The key is valid (or not required): persist or forget it now.
      if (_saveApiKey && apiKey != null && apiKey.isNotEmpty) {
        await _credentials.saveApiKey(url, apiKey);
        _hasSavedKey = true;
      } else if (!_saveApiKey) {
        // Unchecking the box forgets any previously stored key for this server.
        await _credentials.clearApiKey(url);
        _hasSavedKey = false;
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _connection = connection;
        _serverConfig = config;
        _manifests = manifests;
        _status = _l10n.t(MessageKey.remoteConnected);
      });
      final RemoteReopenRequest? reopen = widget.reopen;
      if (reopen != null) {
        await _openReopen(connection, reopen);
      }
    } on RemoteApiException catch (e) {
      final bool keyMissing = apiKey == null || apiKey.isEmpty;
      setState(() {
        _busy = false;
        if (e.isUnauthorized) {
          _error = _l10n.t(
            keyMissing
                ? MessageKey.remoteApiKeyRequired
                : MessageKey.remoteApiKeyInvalid,
          );
        } else {
          _error =
              _l10n.t(MessageKey.remoteConnectionFailed, {'error': e.message});
        }
      });
    }
  }

  Future<void> _openReopen(
    RemoteServerConnection connection,
    RemoteReopenRequest reopen,
  ) async {
    if (reopen.descriptor.isManifest && reopen.descriptor.manifestId != null) {
      await _openSession(
        () => connection.openManifest(reopen.descriptor.manifestId!),
        remoteDescriptor: reopen.descriptor,
        defaultConfig: reopen.defaultEvalConfig,
        activeRunId: reopen.activeModelRunId,
      );
    } else {
      final RemoteProjectDescriptor d = reopen.descriptor;
      await _openSession(
        () => connection.openCustomPaths(
          name: 'Remote project',
          annotationsPath: d.annotationsPath ?? '',
          imagesRootPath: d.imagesRootPath ?? '',
          modelRuns: [
            for (final RemoteModelRunRef r in d.modelRuns)
              <String, dynamic>{
                'id': r.id,
                'name': r.name,
                'predictions_path': r.predictionsPath,
                if (r.apMetricsPath != null) 'ap_metrics_path': r.apMetricsPath,
              },
          ],
        ),
        remoteDescriptor: d,
        defaultConfig: reopen.defaultEvalConfig,
        activeRunId: reopen.activeModelRunId,
      );
    }
  }

  Future<void> _openManifest(ServerManifestSummary manifest) async {
    final RemoteServerConnection? connection = _connection;
    if (connection == null) return;
    await _openSession(
      () => connection.openManifest(manifest.id),
      remoteDescriptor: RemoteProjectDescriptor(
        source: 'manifest',
        manifestId: manifest.id,
      ),
    );
  }

  Future<void> _createFromServerPaths() async {
    final RemoteServerConnection? connection = _connection;
    if (connection == null) return;
    final RemoteCustomPathsSelection? selection =
        await showDialog<RemoteCustomPathsSelection>(
      context: context,
      builder: (_) => RemoteServerBrowserDialog(connection: connection),
    );
    if (selection == null) return;
    final RemoteProjectDescriptor descriptor = RemoteProjectDescriptor(
      source: 'custom_paths',
      annotationsPath: selection.annotationsPath,
      imagesRootPath: selection.imagesRootPath,
      modelRuns: [
        RemoteModelRunRef(
          id: 'run_1',
          name: 'Model run',
          predictionsPath: selection.predictionsPath,
        ),
      ],
    );
    await _openSession(
      () => connection.openCustomPaths(
        name: selection.projectName,
        annotationsPath: selection.annotationsPath,
        imagesRootPath: selection.imagesRootPath,
        modelRuns: [
          {
            'id': 'run_1',
            'name': 'Model run',
            'predictions_path': selection.predictionsPath,
          },
        ],
      ),
      remoteDescriptor: descriptor,
    );
  }

  Future<void> _openSession(
    Future<ServerSessionInfo> Function() opener, {
    RemoteProjectDescriptor? remoteDescriptor,
    EvalConfig defaultConfig = const EvalConfig(),
    String? activeRunId,
  }) async {
    final RemoteServerConnection? connection = _connection;
    if (connection == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = _l10n.t(MessageKey.remoteLoadingProject);
    });
    try {
      final ServerSessionInfo info = await opener();
      final List<ModelRunEntry> entries = [];
      final Map<String, ApEvalResult> apResults = {};
      final Map<String, RemoteModelRunRef> remoteRunsById = {
        for (final RemoteModelRunRef run
            in remoteDescriptor?.modelRuns ?? const <RemoteModelRunRef>[])
          run.id: run,
      };
      CocoDataset? dataset;
      ImageSource? imageSource;
      for (final ServerModelRunInfo run in info.modelRuns) {
        final RemoteWorkspaceData data = await connection.loadWorkspace(
          sessionId: info.sessionId,
          modelRunId: run.id,
          modelRunName: run.name,
          config: defaultConfig,
        );
        dataset ??= data.dataset;
        imageSource ??= data.imageSource;
        entries.add(
          ModelRunEntry(
            modelRun: data.modelRun,
            evalResult: data.evalResult,
            predictionsPath: remoteRunsById[run.id]?.predictionsPath,
          ),
        );
        final ApEvalResult? ap =
            await connection.getApMetrics(info.sessionId, run.id);
        if (ap != null) {
          apResults[run.id] = ap;
        }
      }
      if (!mounted || dataset == null || entries.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final int activeIndex = activeRunId == null
          ? 0
          : entries
              .indexWhere((e) => e.modelRun.id == activeRunId)
              .clamp(0, entries.length - 1);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WorkspaceScreen(
            projectName: info.name,
            dataset: dataset!,
            modelRunEntries: entries,
            imageSource: imageSource!,
            issues: const [],
            initialActiveRunIndex: activeIndex,
            initialApEvalResults: apResults,
            remoteContext: remoteDescriptor == null
                ? null
                : RemoteWorkspaceContext(
                    connection: connection,
                    sessionId: info.sessionId,
                    projectId: info.projectHash,
                    server: RemoteServerRef(
                      url: connection.baseUrl,
                      apiKeySaved: _saveApiKey,
                    ),
                    descriptor: remoteDescriptor,
                  ),
          ),
        ),
      );
      if (mounted) setState(() => _busy = false);
    } on RemoteApiException catch (e) {
      setState(() {
        _busy = false;
        _error =
            _l10n.t(MessageKey.remoteConnectionFailed, {'error': e.message});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = _l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t(MessageKey.remoteConnectToServer))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(
                controller: _urlController,
                enabled: !_servedFromBackend && !_probing && widget.reopen == null,
                decoration: InputDecoration(
                  labelText: l10n.t(MessageKey.remoteServerUrl),
                  hintText: 'http://localhost:8080',
                  suffixIcon: _probing
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.t(MessageKey.remoteApiKey),
                ),
              ),
              CheckboxListTile(
                value: _saveApiKey,
                onChanged: (bool? v) =>
                    setState(() => _saveApiKey = v ?? false),
                title: Text(l10n.t(MessageKey.remoteSaveApiKey)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (_hasSavedKey)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _forgetSavedKey,
                    icon: const Icon(Icons.key_off),
                    label: Text(l10n.t(MessageKey.remoteForgetApiKey)),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton(
                    onPressed: _busy ? null : _connect,
                    child: Text(l10n.t(MessageKey.remoteTestConnection)),
                  ),
                  const SizedBox(width: 16),
                  if (_busy)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (_status != null && !_busy)
                    Text(_status!, style: const TextStyle(color: Colors.green)),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_serverConfig != null) ...[
                const Divider(height: 32),
                _buildOpenSection(l10n),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpenSection(AppLocalizations l10n) {
    final ServerClientConfig config = _serverConfig!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (config.manifestsEnabled) ...[
          Text(
            l10n.t(MessageKey.remoteServerManifests),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_manifests.isEmpty)
            Text(l10n.t(MessageKey.remoteNoManifests))
          else
            ..._manifests.map(
              (m) => Card(
                child: ListTile(
                  title: Text(m.name),
                  subtitle: Text(m.id),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: _busy ? null : () => _openManifest(m),
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
        if (config.customPathsEnabled)
          OutlinedButton.icon(
            onPressed: _busy ? null : _createFromServerPaths,
            icon: const Icon(Icons.folder_open),
            label: Text(l10n.t(MessageKey.remoteCreateFromServerPaths)),
          ),
      ],
    );
  }
}
