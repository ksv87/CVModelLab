import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import '../../core/platform/platform_capabilities.dart';
import '../../core/preferences/recent_remote_projects.dart';
import '../../platform_io/file_pick_result.dart';
import '../../platform_io/image_source.dart';
import '../../platform_io/platform_capabilities.dart';
import '../../platform_io/platform_file_picker.dart';
import '../../platform_io/project_file_io.dart';
import '../../platform_io/project_loader.dart';
import '../../platform_io/recent_projects_io.dart';
import '../../platform_io/user_preferences.dart';
import '../widgets/status_views.dart';
import '../widgets/language_selector.dart';
import '../widgets/theme_selector.dart';
import '../l10n/app_locale_scope.dart';
import '../l10n/app_localizations.dart';
import 'remote_connect_screen.dart';
import 'workspace_screen.dart';

class ProjectOpenScreen extends StatefulWidget {
  const ProjectOpenScreen({this.capabilities, super.key});

  final PlatformCapabilities? capabilities;

  @override
  State<ProjectOpenScreen> createState() => _ProjectOpenScreenState();
}

class _ProjectOpenScreenState extends State<ProjectOpenScreen> {
  final TextEditingController _modelName =
      TextEditingController(text: 'Model run');
  final PlatformFilePicker _filePicker = createPlatformFilePicker();
  final UserPreferencesStore _preferences = createUserPreferencesStore();
  late final RecentProjectsManager _recentProjectsManager =
      createRecentProjectsManager(_preferences);
  late final RecentRemoteProjectsManager _recentRemoteProjectsManager =
      RecentRemoteProjectsManager(store: _preferences);
  late final PlatformCapabilities _capabilities =
      widget.capabilities ?? currentPlatformCapabilities();

  // ── Normal open mode ──────────────────────────────────────────────────────
  PickedDataFile? _annotationsFile;
  PickedDataFile? _predictionsFile;
  ImageSource? _imageSource;
  String? _imagesRootPath;
  ProjectLoadResult? _loadResult;

  // ── Restore mode (opened manifest but files need re-picking) ──────────────
  CvmlProject? _pendingProject;
  PickedDataFile? _pendingAnnotations;
  ImageSource? _pendingImageSource;
  String? _pendingImagesRootPath;
  List<PickedDataFile?> _pendingPredFiles = [];

  // ── Shared ────────────────────────────────────────────────────────────────
  bool _loading = false;
  FriendlyError? _error;
  LongRunningTaskProgress? _taskProgress;
  CancellationToken? _cancellationToken;
  List<RecentProjectEntry> _recentProjects = const <RecentProjectEntry>[];
  List<RecentRemoteProjectEntry> _recentRemoteProjects =
      const <RecentRemoteProjectEntry>[];

  bool get _inRestoreMode => _pendingProject != null;

  bool get _canLoadFromManifest {
    if (_pendingProject == null || _pendingAnnotations == null) return false;
    return _pendingProject!.modelRuns.asMap().entries.every(
          (entry) => _pendingPredFiles[entry.key] != null,
        );
  }

  @override
  void initState() {
    super.initState();
    _loadRecentProjects();
    _loadRecentRemoteProjects();
  }

  @override
  void dispose() {
    _cancellationToken?.cancel();
    _modelName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CV Model Lab'),
        actions: const [
          Center(child: ThemeSelector()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: LanguageSelector()),
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _capabilities.isMobile
                    ? _buildMobileRemoteHome(context)
                    : _inRestoreMode
                        ? _buildRestoreMode(context)
                        : _buildNormalMode(context),
              ),
            ),
          ),
          if (_taskProgress != null)
            TaskProgressOverlay(
              progress: _taskProgress!,
              onCancel: _taskProgress!.canCancel ? _cancelTask : null,
            ),
        ],
      ),
    );
  }

  // ── Normal mode ───────────────────────────────────────────────────────────

  Widget _buildMobileRemoteHome(BuildContext context) {
    final AppLocalizations l10n = AppLocaleScope.l10n(context);
    return ListView(
      children: [
        Text(
          l10n.t(MessageKey.mobileRemoteClientMode),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(l10n.t(MessageKey.mobileRemoteClientExplanation)),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _loading ? null : _connectToServer,
          icon: const Icon(Icons.cloud_outlined),
          label: Text(l10n.t(MessageKey.remoteConnectToServer)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _recentRemoteProjects.isEmpty
              ? null
              : () => _openRecentRemoteProject(_recentRemoteProjects.first),
          icon: const Icon(Icons.history),
          label: Text(l10n.t(MessageKey.mobileOpenRecentRemoteProject)),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 360,
          child: _RecentRemoteProjectsPanel(
            entries: _recentRemoteProjects,
            onOpen: _loading ? null : _openRecentRemoteProject,
            onRemove: _loading ? null : _removeRecentRemoteProject,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          FriendlyErrorView(error: _error!),
        ],
      ],
    );
  }

  Widget _buildNormalMode(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Open Dataset',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Load COCO annotations, predictions, and an image folder to start reviewing detections.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _PickedFileRow(
          label: 'annotations.json',
          value: _annotationsFile?.name,
          icon: Icons.check_circle,
          onPick: _loading ? null : _pickAnnotations,
        ),
        const SizedBox(height: 12),
        _PickedFileRow(
          label: 'predictions.json',
          value: _predictionsFile?.name,
          icon: Icons.memory,
          onPick: _loading ? null : _pickPredictions,
        ),
        const SizedBox(height: 12),
        _PickedFileRow(
          label: 'images directory / files',
          value: _imageSource == null ? null : 'Selected',
          icon: Icons.image,
          onPick: _loading ? null : _pickImages,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _modelName,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'model run name',
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _loading ? null : _analyzeSelectedFiles,
              icon: const Icon(Icons.assessment),
              label: const Text('Analyze'),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _openSavedProject,
              icon: const Icon(Icons.folder_open),
              label: const Text('Open project'),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _connectToServer,
              icon: const Icon(Icons.cloud_outlined),
              label: Text(
                AppLocaleScope.l10n(context)
                    .t(MessageKey.remoteConnectToServer),
              ),
            ),
            if (_loadResult?.canOpen ?? false)
              OutlinedButton.icon(
                onPressed: _loading ? null : _openWorkspace,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open workspace'),
              ),
          ],
        ),
        if (_loading) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          FriendlyErrorView(error: _error!),
        ],
        if (_loadResult?.preflightSummary != null) ...[
          const SizedBox(height: 16),
          _PreflightSummaryCard(summary: _loadResult!.preflightSummary!),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: _loadResult == null || _loadResult!.issues.isEmpty
                    ? const _EmptyHint()
                    : _IssueList(issues: _loadResult!.issues),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _RecentProjectsPanel(
                  entries: _recentProjects,
                  onOpen: _loading ? null : _openRecentProject,
                  onRemove: _loading ? null : _removeRecentProject,
                  onClear: _loading ? null : _clearRecentProjects,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Restore mode ──────────────────────────────────────────────────────────

  Widget _buildRestoreMode(BuildContext context) {
    final CvmlProject project = _pendingProject!;
    final ProjectDatasetSource ds = project.datasetSource;

    final String annotationsHint = _hintFromPathOrName(
      ds.annotationsPath,
      ds.annotationsFileName,
      'annotations.json',
    );
    final String imagesHint = _hintFromPathOrName(
      ds.imagesRootPath,
      ds.imagesSourceLabel,
      'images directory / files',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.folder_open,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Restoring "${project.name}"',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select the files listed below to continue.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Annotations
        _PickedFileRow(
          label: annotationsHint,
          value: _pendingAnnotations?.name,
          icon: Icons.check_circle,
          onPick: _loading ? null : _pickPendingAnnotations,
        ),
        const SizedBox(height: 12),

        // Images (optional)
        _PickedFileRow(
          label: imagesHint,
          value: _pendingImageSource != null ? 'Selected' : null,
          icon: Icons.image,
          onPick: _loading ? null : _pickPendingImages,
        ),

        // One predictions row per model run
        for (int i = 0; i < project.modelRuns.length; i++) ...[
          const SizedBox(height: 12),
          _PickedFileRow(
            label: _hintFromPathOrName(
              project.modelRuns[i].predictionsPath,
              project.modelRuns[i].predictionsFileName,
              project.modelRuns[i].name,
            ),
            value: _pendingPredFiles[i]?.name,
            icon: Icons.memory,
            onPick: _loading ? null : () => _pickPendingPredictions(i),
          ),
        ],

        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: (_loading || !_canLoadFromManifest)
                  ? null
                  : _loadFromManifest,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Load project'),
            ),
            TextButton(
              onPressed: _loading ? null : _cancelRestore,
              child: const Text('Cancel'),
            ),
          ],
        ),
        if (_loading) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          FriendlyErrorView(error: _error!),
        ],
        const Spacer(),
      ],
    );
  }

  // ── Pickers — normal mode ─────────────────────────────────────────────────

  Future<void> _pickAnnotations() async {
    final PickedDataFile? file = await _safePick(
      () async => _filePicker.pickAnnotationsJson(
        initialDirectory: await _preferences.getString(
          PreferenceKeys.lastAnnotationsDirectory,
        ),
      ),
    );
    if (file == null || !mounted) {
      return;
    }
    setState(() {
      _annotationsFile = file;
      _loadResult = null;
    });
    await _rememberDirectory(
      PreferenceKeys.lastAnnotationsDirectory,
      file.path,
    );
  }

  Future<void> _pickPredictions() async {
    final PickedDataFile? file = await _safePick(
      () async => _filePicker.pickPredictionsJson(
        initialDirectory: await _preferences.getString(
          PreferenceKeys.lastPredictionsDirectory,
        ),
      ),
    );
    if (file == null || !mounted) {
      return;
    }
    setState(() {
      _predictionsFile = file;
      _loadResult = null;
    });
    await _rememberDirectory(
      PreferenceKeys.lastPredictionsDirectory,
      file.path,
    );
  }

  Future<void> _pickImages() async {
    final ImageSource? source = await _safePick(
      () async => _filePicker.pickImages(
        initialDirectory: await _preferences.getString(
          PreferenceKeys.lastImagesDirectory,
        ),
      ),
    );
    if (source == null || !mounted) {
      return;
    }
    setState(() {
      _imageSource = source;
      _loadResult = null;
      _imagesRootPath = _extractRootPath(source);
    });
    await _rememberDirectory(
      PreferenceKeys.lastImagesDirectory,
      _imagesRootPath,
    );
  }

  // ── Pickers — restore mode ────────────────────────────────────────────────

  Future<void> _pickPendingAnnotations() async {
    final PickedDataFile? file = await _safePick(
      () async => _filePicker.pickAnnotationsJson(
        initialDirectory: await _preferences.getString(
          PreferenceKeys.lastAnnotationsDirectory,
        ),
      ),
    );
    if (file == null || !mounted) {
      return;
    }
    setState(() => _pendingAnnotations = file);
    await _rememberDirectory(
      PreferenceKeys.lastAnnotationsDirectory,
      file.path,
    );
  }

  Future<void> _pickPendingImages() async {
    final ImageSource? source = await _safePick(
      () async => _filePicker.pickImages(
        initialDirectory: await _preferences.getString(
          PreferenceKeys.lastImagesDirectory,
        ),
      ),
    );
    if (source == null || !mounted) {
      return;
    }
    setState(() {
      _pendingImageSource = source;
      _pendingImagesRootPath = _extractRootPath(source);
    });
    await _rememberDirectory(
      PreferenceKeys.lastImagesDirectory,
      _pendingImagesRootPath,
    );
  }

  Future<void> _pickPendingPredictions(int runIndex) async {
    final PickedDataFile? file = await _safePick(
      () async => _filePicker.pickPredictionsJson(
        initialDirectory: await _preferences.getString(
          PreferenceKeys.lastPredictionsDirectory,
        ),
      ),
    );
    if (file == null || !mounted) {
      return;
    }
    setState(() {
      _pendingPredFiles = List<PickedDataFile?>.of(_pendingPredFiles)
        ..[runIndex] = file;
    });
    await _rememberDirectory(
      PreferenceKeys.lastPredictionsDirectory,
      file.path,
    );
  }

  // ── Restore mode logic ────────────────────────────────────────────────────

  void _enterRestoreMode(CvmlProject project) {
    setState(() {
      _pendingProject = project;
      _pendingAnnotations = null;
      _pendingImageSource = null;
      _pendingImagesRootPath = null;
      _pendingPredFiles = List<PickedDataFile?>.filled(
        project.modelRuns.length,
        null,
      );
      _error = null;
    });
  }

  void _cancelRestore() {
    setState(() {
      _pendingProject = null;
      _pendingAnnotations = null;
      _pendingImageSource = null;
      _pendingImagesRootPath = null;
      _pendingPredFiles = [];
      _error = null;
    });
  }

  Future<void> _loadFromManifest() async {
    final CvmlProject project = _pendingProject!;
    final PickedDataFile annotationsFile = _pendingAnnotations!;
    ImageSource imageSource = _pendingImageSource ?? const EmptyImageSource();
    final EvalConfig evalConfig = project.defaultEvalConfig;

    setState(() {
      _loading = true;
      _error = null;
      _cancellationToken = CancellationToken();
      _taskProgress = const LongRunningTaskProgress(
        taskId: 'project-restore',
        title: 'Restoring project',
        message: 'Preparing saved project files',
        progress: null,
        canCancel: true,
      );
    });
    await Future<void>.delayed(Duration.zero);

    try {
      final CancellationToken token = _cancellationToken!;
      final List<ModelRunEntry> entries = [];
      final List<ParseIssue> allIssues = [];
      final Map<String, ApEvalResult> apEvalResults = {};
      CocoDataset? dataset;

      for (int i = 0; i < project.modelRuns.length; i++) {
        token.throwIfCancelled();
        final PickedDataFile? predFile = _pendingPredFiles[i];
        if (predFile == null) continue;
        final ProjectModelRunSource runSource = project.modelRuns[i];

        final ProjectLoadResult result = await const ProjectLoader().loadAsync(
          annotationsFile: annotationsFile,
          predictionsFile: predFile,
          imageSource: imageSource,
          projectName: project.name,
          modelRunName: runSource.name,
          modelRunId: runSource.id,
          config: evalConfig,
          cancellationToken: token,
          onProgress: (LongRunningTaskProgress progress) {
            if (!mounted || token.isCancelled) return;
            setState(
              () => _taskProgress = progress.copyWith(
                taskId: 'project-restore',
                title: 'Restoring project',
                message: '${runSource.name}: ${progress.message}',
              ),
            );
          },
        );
        if (result.dataset != null) {
          dataset ??= result.dataset;
          imageSource = result.imageSource ?? imageSource;
        }
        allIssues.addAll(result.issues);
        if (result.canOpen) {
          entries.add(
            ModelRunEntry(
              modelRun: result.modelRun!,
              evalResult: result.evalResult!,
            ),
          );
          if (runSource.apEvalResult != null) {
            apEvalResults[result.modelRun!.id] = runSource.apEvalResult!;
          }
        }
      }

      if (!mounted) return;

      if (entries.isEmpty) {
        setState(
          () => _error = const FriendlyError(
            title: 'Project restore failed',
            message:
                'Could not load any model runs. Check the selected files and try again.',
          ),
        );
        return;
      }

      final String? activeRunId = project.activeModelRunId;
      final int initialActiveIndex = activeRunId == null
          ? 0
          : entries
              .indexWhere((e) => e.modelRun.id == activeRunId)
              .clamp(0, entries.length - 1);

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WorkspaceScreen(
            projectName: project.name,
            dataset: dataset!,
            modelRunEntries: entries,
            imageSource: imageSource,
            issues: allIssues,
            annotationsPath: annotationsFile.path,
            imagesRootPath: _pendingImagesRootPath,
            initialActiveRunIndex: initialActiveIndex,
            initialApEvalResults: apEvalResults,
          ),
        ),
      );
      if (mounted) setState(() => _pendingProject = null);
    } on TaskCancelledException {
      if (mounted) {
        setState(
          () => _error = const FriendlyError(
            title: 'Project restore cancelled',
            message: 'No project data was changed.',
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => _error = friendlyErrorFrom(
            e,
            fallbackTitle: 'Project restore failed',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _taskProgress = null;
          _cancellationToken = null;
        });
      }
    }
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Future<T?> _safePick<T>(Future<T?> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = friendlyErrorFrom(error));
      }
      return null;
    }
  }

  static String? _extractRootPath(ImageSource source) {
    try {
      // ignore: avoid_dynamic_calls
      final Object? v = (source as dynamic).rootPath;
      return v is String ? v : null;
    } on NoSuchMethodError {
      return null;
    }
  }

  static String _hintFromPathOrName(
    String? path,
    String? name,
    String fallback,
  ) {
    if (name != null && name.isNotEmpty) return name;
    if (path != null && path.isNotEmpty) return path.split('/').last;
    return fallback;
  }

  // ── Normal mode actions ───────────────────────────────────────────────────

  void _analyzeSelectedFiles() {
    final PickedDataFile? annotations = _annotationsFile;
    final PickedDataFile? predictions = _predictionsFile;
    if (annotations == null || predictions == null) {
      setState(() {
        _error = const FriendlyError(
          title: 'Select required files',
          message:
              'Choose annotations.json and predictions.json before running analysis.',
        );
      });
      return;
    }
    _loadProject(
      annotationsFile: annotations,
      predictionsFile: predictions,
      imageSource: _imageSource ?? const EmptyImageSource(),
      projectName: annotations.name,
    );
  }

  void _connectToServer() {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const RemoteConnectScreen(),
          ),
        )
        .then((_) => _loadRecentRemoteProjects());
  }

  void _openRemoteProject(CvmlProject project) {
    final RemoteProjectDescriptor? descriptor = project.remoteProject;
    final String? url = project.server?.url;
    if (descriptor == null || url == null) {
      setState(
        () => _error = const FriendlyError(
          title: 'Invalid remote project',
          message: 'The remote project file is missing server information.',
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RemoteConnectScreen(
          reopen: RemoteReopenRequest(
            serverUrl: url,
            descriptor: descriptor,
            activeModelRunId: project.activeModelRunId,
            defaultEvalConfig: project.defaultEvalConfig,
          ),
        ),
      ),
    );
  }

  void _openRecentRemoteProject(RecentRemoteProjectEntry entry) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => RemoteConnectScreen(
              reopen: RemoteReopenRequest(
                serverUrl: entry.serverUrl,
                descriptor: entry.descriptor,
                activeModelRunId: entry.activeModelRunId,
                defaultEvalConfig: entry.defaultEvalConfig,
              ),
            ),
          ),
        )
        .then((_) => _loadRecentRemoteProjects());
  }

  Future<void> _openSavedProject() async {
    if (!_capabilities.supportsLocalStandaloneProjects) {
      setState(
        () => _error = FriendlyError(
          title: AppLocaleScope.l10n(context).t(
            MessageKey.mobileLocalUnavailable,
          ),
          message: AppLocaleScope.l10n(context).t(
            MessageKey.mobileRemoteClientExplanation,
          ),
        ),
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _taskProgress = const LongRunningTaskProgress(
        taskId: 'open-project',
        title: 'Opening project',
        message: 'Waiting for project file selection',
        progress: null,
        canCancel: false,
      );
    });
    try {
      final ProjectFileIo io = createProjectFileIo();

      final PickedDataFile? projectFile = await io.openProject(
        initialDirectory:
            await _preferences.getString(PreferenceKeys.lastProjectDirectory),
      );
      if (projectFile == null || !mounted) return;
      await _rememberDirectory(
        PreferenceKeys.lastProjectDirectory,
        projectFile.path,
      );

      final CvmlProject project;
      try {
        project = const ProjectSerializer().fromJsonString(
          projectFile.readAsString(),
        );
      } on ProjectSerializationException catch (e) {
        setState(
          () => _error = FriendlyError(
            title: 'Invalid project file',
            message:
                'The selected file is not a valid CV Model Lab project manifest.',
            details: e.message,
          ),
        );
        return;
      }

      if (project.isRemote) {
        _openRemoteProject(project);
        return;
      }

      final bool opened = await _autoLoadFromManifest(
        project,
        io: io,
        projectFilePath: projectFile.path,
      );
      if (!mounted) return;

      if (opened) {
        if (projectFile.path != null) {
          await _recentProjectsManager.addOrUpdate(
            projectPath: projectFile.path!,
            projectName: project.name,
          );
          await _loadRecentProjects();
        }
        return;
      }
      // Some files are no longer at their saved paths → let user re-pick.
      _enterRestoreMode(project);
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => _error = friendlyErrorFrom(
            e,
            fallbackTitle: 'Project restore failed',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _taskProgress = null;
        });
      }
    }
  }

  /// Tries to load all project files from their saved absolute paths and opens
  /// the workspace. Returns `true` if the workspace was opened successfully.
  /// Returns `false` when any file is missing; the caller should then enter
  /// restore mode so the user can re-pick the missing paths.
  // Resolve a path stored in the project manifest.
  // Relative paths are resolved from the directory containing the project file.
  static String _resolve(String path, String? projectFilePath) {
    if (projectFilePath == null) return path;
    // An absolute path starts with / on Unix/macOS or a drive letter on Windows.
    if (path.startsWith('/') ||
        (path.length >= 2 && path[1] == ':') ||
        path.startsWith('\\\\')) {
      return path;
    }
    final int lastSep = projectFilePath.lastIndexOf(RegExp(r'[/\\]'));
    if (lastSep < 0) return path;
    final String dir = projectFilePath.substring(0, lastSep);
    return '$dir/$path';
  }

  Future<bool> _autoLoadFromManifest(
    CvmlProject project, {
    required ProjectFileIo io,
    String? projectFilePath,
  }) async {
    final String? rawAnnotationsPath = project.datasetSource.annotationsPath;
    if (rawAnnotationsPath == null) return false;
    final String annotationsPath =
        _resolve(rawAnnotationsPath, projectFilePath);

    final PickedDataFile? annotationsFile =
        await io.readFileAtPath(annotationsPath);
    if (!mounted || annotationsFile == null) return false;

    ImageSource imageSource = const EmptyImageSource();
    final String? imagesRootPath = project.datasetSource.imagesRootPath;
    if (imagesRootPath != null) {
      final String resolvedImages = _resolve(imagesRootPath, projectFilePath);
      imageSource =
          await io.openImageSourceAtPath(resolvedImages) ?? imageSource;
    }

    final List<ModelRunEntry> entries = [];
    final List<ParseIssue> allIssues = [];
    final Map<String, ApEvalResult> apEvalResults = {};
    CocoDataset? dataset;
    bool anyMissing = false;

    for (final ProjectModelRunSource runSource in project.modelRuns) {
      setState(
        () => _taskProgress = LongRunningTaskProgress(
          taskId: 'open-project',
          title: 'Opening project',
          message: 'Loading ${runSource.name}',
          progress: null,
          canCancel: false,
        ),
      );
      final String? rawPredPath = runSource.predictionsPath;
      if (rawPredPath == null) {
        anyMissing = true;
        break;
      }
      final String predPath = _resolve(rawPredPath, projectFilePath);
      final PickedDataFile? predFile = await io.readFileAtPath(predPath);
      if (!mounted) return false;
      if (predFile == null) {
        anyMissing = true;
        break;
      }

      final ProjectLoadResult result = const ProjectLoader().load(
        annotationsFile: annotationsFile,
        predictionsFile: predFile,
        imageSource: imageSource,
        projectName: project.name,
        modelRunName: runSource.name,
        modelRunId: runSource.id,
        config: project.defaultEvalConfig,
      );
      if (result.dataset != null) {
        dataset ??= result.dataset;
        imageSource = result.imageSource ?? imageSource;
      }
      allIssues.addAll(result.issues);
      if (result.canOpen) {
        entries.add(
          ModelRunEntry(
            modelRun: result.modelRun!,
            evalResult: result.evalResult!,
            predictionsPath: predPath,
          ),
        );
        if (runSource.apEvalResult != null) {
          apEvalResults[result.modelRun!.id] = runSource.apEvalResult!;
        }
      }
    }

    if (!mounted || anyMissing || entries.isEmpty) return false;

    final String? activeRunId = project.activeModelRunId;
    final int initialActiveIndex = activeRunId == null
        ? 0
        : entries
            .indexWhere((e) => e.modelRun.id == activeRunId)
            .clamp(0, entries.length - 1);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkspaceScreen(
          projectName: project.name,
          dataset: dataset!,
          modelRunEntries: entries,
          imageSource: imageSource,
          issues: allIssues,
          projectFilePath: projectFilePath,
          annotationsPath: annotationsPath,
          imagesRootPath: imagesRootPath,
          initialActiveRunIndex: initialActiveIndex,
          initialApEvalResults: apEvalResults,
        ),
      ),
    );
    return true;
  }

  Future<void> _loadProject({
    required PickedDataFile annotationsFile,
    required PickedDataFile predictionsFile,
    required ImageSource imageSource,
    required String projectName,
  }) async {
    final CancellationToken token = CancellationToken();
    setState(() {
      _loading = true;
      _error = null;
      _cancellationToken = token;
      _taskProgress = const LongRunningTaskProgress(
        taskId: 'project-load',
        title: 'Loading project',
        message: 'Preparing selected files',
        progress: null,
        canCancel: true,
      );
    });
    try {
      final ProjectLoadResult result = await const ProjectLoader().loadAsync(
        annotationsFile: annotationsFile,
        predictionsFile: predictionsFile,
        imageSource: imageSource,
        projectName: projectName,
        modelRunName: _modelName.text,
        cancellationToken: token,
        onProgress: (LongRunningTaskProgress progress) {
          if (mounted && identical(_cancellationToken, token)) {
            setState(() => _taskProgress = progress);
          }
        },
      );
      if (!mounted || token.isCancelled) return;
      setState(() {
        _loadResult = result;
        _error = result.canOpen
            ? null
            : const FriendlyError(
                title: 'Could not load project',
                message:
                    'Review the validation issues below and pick corrected files.',
              );
      });
    } on TaskCancelledException {
      if (mounted) {
        setState(
          () => _error = const FriendlyError(
            title: 'Analysis cancelled',
            message: 'No project was opened.',
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = friendlyErrorFrom(
            error,
            fallbackTitle: 'Could not load project',
          ),
        );
      }
    } finally {
      if (mounted && identical(_cancellationToken, token)) {
        setState(() {
          _loading = false;
          _taskProgress = null;
          _cancellationToken = null;
        });
      }
    }
  }

  void _openWorkspace() {
    final ProjectLoadResult? result = _loadResult;
    if (result == null || !result.canOpen) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkspaceScreen(
          projectName: result.projectName,
          dataset: result.dataset!,
          modelRunEntries: [
            ModelRunEntry(
              modelRun: result.modelRun!,
              evalResult: result.evalResult!,
              predictionsPath: _predictionsFile?.path,
            ),
          ],
          imageSource: result.imageSource!,
          issues: result.issues,
          annotationsPath: _annotationsFile?.path,
          imagesRootPath: _imagesRootPath,
        ),
      ),
    );
  }

  Future<void> _loadRecentProjects() async {
    final List<RecentProjectEntry> entries =
        await _recentProjectsManager.list();
    if (mounted) {
      setState(() => _recentProjects = entries);
    }
  }

  Future<void> _loadRecentRemoteProjects() async {
    final List<RecentRemoteProjectEntry> entries =
        await _recentRemoteProjectsManager.list();
    if (mounted) {
      setState(() => _recentRemoteProjects = entries);
    }
  }

  Future<void> _removeRecentRemoteProject(
    RecentRemoteProjectEntry entry,
  ) async {
    await _recentRemoteProjectsManager.remove(entry.key);
    await _loadRecentRemoteProjects();
  }

  Future<void> _openRecentProject(RecentProjectEntry entry) async {
    setState(() {
      _loading = true;
      _error = null;
      _taskProgress = const LongRunningTaskProgress(
        taskId: 'open-project',
        title: 'Opening project',
        message: 'Reading project file',
        progress: null,
        canCancel: false,
      );
    });
    try {
      final ProjectFileIo io = createProjectFileIo();
      final PickedDataFile? file = await io.readFileAtPath(entry.projectPath);
      if (!mounted) return;
      if (file == null) {
        await _loadRecentProjects();
        setState(
          () => _error = const FriendlyError(
            title: 'Project unavailable',
            message:
                'The recent project file is missing. Remove it from the list or choose another project.',
          ),
        );
        return;
      }

      final CvmlProject project;
      try {
        project = const ProjectSerializer().fromJsonString(file.readAsString());
      } on ProjectSerializationException catch (e) {
        setState(
          () => _error = FriendlyError(
            title: 'Invalid project file',
            message:
                'The selected file is not a valid CV Model Lab project manifest.',
            details: e.message,
          ),
        );
        return;
      }

      await _recentProjectsManager.addOrUpdate(
        projectPath: entry.projectPath,
        projectName: project.name,
      );
      await _rememberDirectory(
        PreferenceKeys.lastProjectDirectory,
        entry.projectPath,
      );

      // Try to load all files from their saved paths. Fall back to restore
      // mode only when a file has moved or is inaccessible.
      final bool opened = await _autoLoadFromManifest(
        project,
        io: io,
        projectFilePath: entry.projectPath,
      );
      if (!mounted) return;

      if (!opened) {
        _enterRestoreMode(project);
      }
      await _loadRecentProjects();
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = friendlyErrorFrom(
            error,
            fallbackTitle: 'Project restore failed',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _taskProgress = null;
        });
      }
    }
  }

  Future<void> _removeRecentProject(RecentProjectEntry entry) async {
    await _recentProjectsManager.remove(entry.projectPath);
    await _loadRecentProjects();
  }

  Future<void> _clearRecentProjects() async {
    await _recentProjectsManager.clear();
    await _loadRecentProjects();
  }

  void _cancelTask() {
    _cancellationToken?.cancel();
    setState(() {
      _taskProgress = _taskProgress?.copyWith(
        message: 'Cancelling...',
        clearProgress: true,
        canCancel: false,
      );
    });
  }

  Future<void> _rememberDirectory(String key, String? path) async {
    final String? directory = _directoryName(path);
    if (directory != null && directory.isNotEmpty) {
      await _preferences.setString(key, directory);
    }
  }
}

String? _directoryName(String? path) {
  if (path == null || path.isEmpty) {
    return null;
  }
  final String normalized = path.replaceAll('\\', '/');
  final int index = normalized.lastIndexOf('/');
  if (index <= 0) {
    return null;
  }
  return normalized.substring(0, index);
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _PickedFileRow extends StatelessWidget {
  const _PickedFileRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.onPick,
  });

  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InputDecorator(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: label,
            ),
            child: Text(value ?? 'Not selected'),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.tonalIcon(
          onPressed: onPick,
          icon: Icon(icon),
          label: const Text('Pick'),
        ),
      ],
    );
  }
}

class _PreflightSummaryCard extends StatelessWidget {
  const _PreflightSummaryCard({required this.summary});

  final PreflightSummary summary;

  @override
  Widget build(BuildContext context) {
    final List<_SummaryItem> items = [
      _SummaryItem('Images in COCO', summary.imageCount.toString()),
      _SummaryItem('Annotations', summary.annotationCount.toString()),
      _SummaryItem('Categories', summary.categoryCount.toString()),
      _SummaryItem('Predictions', summary.predictionCount.toString()),
      _SummaryItem(
        'Matched image files',
        '${summary.matchedImageFileCount} / ${summary.imageCount}',
      ),
      _SummaryItem(
        'Missing image files',
        summary.missingImageFileCount.toString(),
      ),
      _SummaryItem('Warnings', summary.warningCount.toString()),
      _SummaryItem('Errors', summary.errorCount.toString()),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            for (final _SummaryItem item in items)
              SizedBox(
                width: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Text(
                      item.value,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value);

  final String label;
  final String value;
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateView(
      title: 'No project loaded',
      explanation:
          'Select COCO annotations, predictions, and image files, then run Analyze.',
      icon: Icons.folder_open,
    );
  }
}

class _RecentProjectsPanel extends StatelessWidget {
  const _RecentProjectsPanel({
    required this.entries,
    required this.onOpen,
    required this.onRemove,
    required this.onClear,
  });

  final List<RecentProjectEntry> entries;
  final ValueChanged<RecentProjectEntry>? onOpen;
  final ValueChanged<RecentProjectEntry>? onRemove;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent Projects',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: entries.isEmpty ? null : onClear,
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: entries.isEmpty
                  ? const EmptyStateView(
                      title: 'No recent projects',
                      explanation:
                          'Saved desktop projects will appear here after you open or save them.',
                      icon: Icons.history,
                    )
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final RecentProjectEntry entry = entries[index];
                        return ListTile(
                          dense: true,
                          enabled: entry.exists,
                          leading: Icon(
                            entry.exists
                                ? Icons.description_outlined
                                : Icons.link_off,
                          ),
                          title: Text(
                            entry.projectName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            entry.exists
                                ? entry.projectPath
                                : 'Missing: ${entry.projectPath}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            tooltip: 'Remove from recent',
                            onPressed: onRemove == null
                                ? null
                                : () => onRemove!(entry),
                            icon: const Icon(Icons.close),
                          ),
                          onTap: entry.exists && onOpen != null
                              ? () => onOpen!(entry)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentRemoteProjectsPanel extends StatelessWidget {
  const _RecentRemoteProjectsPanel({
    required this.entries,
    required this.onOpen,
    required this.onRemove,
  });

  final List<RecentRemoteProjectEntry> entries;
  final ValueChanged<RecentRemoteProjectEntry>? onOpen;
  final ValueChanged<RecentRemoteProjectEntry>? onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocaleScope.l10n(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.t(MessageKey.mobileOpenRecentRemoteProject),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: entries.isEmpty
                  ? EmptyStateView(
                      title: l10n.t(MessageKey.remoteProject),
                      explanation: l10n.t(
                        MessageKey.mobileRemoteClientExplanation,
                      ),
                      icon: Icons.cloud_outlined,
                    )
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final RecentRemoteProjectEntry entry = entries[index];
                        final String source = entry.descriptor.isManifest
                            ? entry.descriptor.manifestId ?? 'manifest'
                            : entry.descriptor.annotationsPath ??
                                'custom paths';
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.cloud_queue),
                          title: Text(
                            entry.projectName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${entry.serverUrl}\n$source',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            tooltip: 'Remove from recent',
                            onPressed: onRemove == null
                                ? null
                                : () => onRemove!(entry),
                            icon: const Icon(Icons.close),
                          ),
                          onTap: onOpen == null ? null : () => onOpen!(entry),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueList extends StatelessWidget {
  const _IssueList({required this.issues});

  final List<ParseIssue> issues;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: issues.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final ParseIssue issue = issues[index];
        return ListTile(
          dense: true,
          leading: Icon(
            issue.severity == ParseIssueSeverity.error
                ? Icons.error
                : Icons.warning,
          ),
          title: Text(AppLocaleScope.l10n(context).parseIssue(issue)),
          subtitle: issue.path == null ? null : Text(issue.path!),
        );
      },
    );
  }
}
