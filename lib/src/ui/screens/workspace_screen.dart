import 'dart:convert' as dart_convert;
import 'dart:typed_data';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import '../../platform_io/annotated_image_saver.dart';
import '../../core/parser/coco_serializer.dart';
import '../../platform_io/ap_evaluator.dart';
import '../../platform_io/file_pick_result.dart';
import '../../platform_io/image_source.dart';
import '../../platform_io/platform_file_picker.dart';
import '../../platform_io/project_file_io.dart';
import '../../platform_io/recent_projects_io.dart';
import '../../platform_io/report_saver.dart';
import '../../platform_io/thumbnail_cache.dart';
import '../../platform_io/user_preferences.dart';
import '../export/annotated_image_renderer.dart';
import '../l10n/app_locale_scope.dart';
import '../widgets/annotated_export_dialog.dart';
import '../widgets/dashboard_panel.dart';
import '../widgets/detection_image_viewer.dart';
import '../widgets/export_report_dialog.dart';
import '../widgets/image_browser_panel.dart';
import '../widgets/language_selector.dart';
import '../widgets/status_views.dart';
import 'confusion_matrix_screen.dart';
import 'dataset_health_screen.dart';
import 'model_compare_screen.dart';
import 'recommendations_screen.dart';
import 'worst_cases_screen.dart';

/// A single loaded model run together with its evaluation result.
class ModelRunEntry {
  const ModelRunEntry({
    required this.modelRun,
    required this.evalResult,
    this.predictionsPath,
  });

  final ModelRun modelRun;
  final EvalResult evalResult;

  /// Absolute path on desktop; null on web or when not yet persisted.
  final String? predictionsPath;
}

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    required this.projectName,
    required this.dataset,
    required this.modelRunEntries,
    required this.imageSource,
    required this.issues,
    this.projectFilePath,
    this.annotationsPath,
    this.imagesRootPath,
    this.initialActiveRunIndex = 0,
    this.initialApEvalResults = const {},
    super.key,
  });

  final String projectName;
  final CocoDataset dataset;
  final List<ModelRunEntry> modelRunEntries;
  final ImageSource imageSource;
  final List<ParseIssue> issues;

  /// Desktop: path of saved .cvmlab.json file; null if unsaved.
  final String? projectFilePath;

  /// Desktop: path of the annotations JSON file.
  final String? annotationsPath;

  /// Desktop: path of the images directory.
  final String? imagesRootPath;

  /// Which model run to show as active when the workspace first opens.
  final int initialActiveRunIndex;

  /// AP eval results loaded from a saved project.
  final Map<String, ApEvalResult> initialApEvalResults;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

enum _WorkspacePage {
  dashboard,
  errorBrowser,
  datasetHealth,
  confusionMatrix,
  worstCases,
  recommendations,
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  static const EvalConfig _defaultEvalConfig = EvalConfig();
  static const EvalViewFilter _defaultViewFilter = EvalViewFilter();

  late List<ModelRunEntry> _modelRunEntries;
  late String _projectName;
  int _activeRunIndex = 0;
  _WorkspacePage _page = _WorkspacePage.errorBrowser;
  String? _projectFilePath;

  EvalConfig _evalConfig = _defaultEvalConfig;
  EvalViewFilter _viewFilter = _defaultViewFilter;
  int? _selectedImageId;
  DetectionMatch? _selectedMatch;
  Uint8List? _selectedImageBytes;
  bool _loadingImage = false;
  bool _evaluating = false;
  bool _exporting = false;
  bool _addingRun = false;
  bool _savingProject = false;
  int _evaluationRequestId = 0;
  LongRunningTaskProgress? _taskProgress;
  CancellationToken? _cancellationToken;

  final ReportSaver _reportSaver = createReportSaver();
  final AnnotatedImageSaver _annotatedImageSaver = createAnnotatedImageSaver();
  final PlatformFilePicker _filePicker = createPlatformFilePicker();
  final ApEvaluator _apEvaluator = createApEvaluator();
  final UserPreferencesStore _preferences = createUserPreferencesStore();
  late final RecentProjectsManager _recentProjectsManager =
      createRecentProjectsManager(_preferences);
  late final ThumbnailCache _thumbnailCache = createThumbnailCache();

  final Map<String, ApEvalResult> _apEvalResults = {};
  bool _runningApEval = false;
  String? _apEvalError;

  late EvalResult _evalResult;
  late Set<String> _missingImageFileNames;

  FilteredEvalView? _cachedView;
  EvalResult? _cachedViewResult;
  EvalViewFilter? _cachedViewFilter;

  Map<int, List<DetectionMatch>>? _cachedMatchesByImageId;
  EvalResult? _cachedMatchesResult;

  @override
  void initState() {
    super.initState();
    _modelRunEntries = List<ModelRunEntry>.of(widget.modelRunEntries);
    _projectName = widget.projectName;
    _projectFilePath = widget.projectFilePath;
    _activeRunIndex =
        widget.initialActiveRunIndex.clamp(0, _modelRunEntries.length - 1);
    _evalResult = _modelRunEntries[_activeRunIndex].evalResult;
    _missingImageFileNames = widget.imageSource.missingImages().toSet();
    _selectedImageId = widget.dataset.imagesById.keys.isEmpty
        ? null
        : (widget.dataset.imagesById.keys.toList()..sort()).first;
    _apEvalResults.addAll(widget.initialApEvalResults);
    _loadSelectedImage();
  }

  ModelRunEntry get _activeEntry => _modelRunEntries[_activeRunIndex];
  ModelRun get _activeModelRun => _activeEntry.modelRun;
  String get _projectCacheId =>
      _projectFilePath ?? 'project-${_projectName.hashCode.abs()}';

  @override
  Widget build(BuildContext context) {
    final FilteredEvalView filteredView = _buildFilteredView();
    final int? effectiveImageId = _effectiveSelectedImageId(filteredView);
    if (effectiveImageId != _selectedImageId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectImage(effectiveImageId);
        }
      });
    }

    final ImageRecord? selectedImage = effectiveImageId == null
        ? null
        : widget.dataset.imagesById[effectiveImageId];
    final List<DetectionMatch> selectedMatches = effectiveImageId == null
        ? const <DetectionMatch>[]
        : filteredView.visibleMatchesForImage(effectiveImageId);

    final String title =
        _projectName + (_projectFilePath == null ? ' (unsaved)' : '');

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onDoubleTap: _evaluating ? null : _renameProject,
          child: Text(title),
        ),
        actions: _buildAppBarActions(context),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _ThresholdToolbar(
                config: _evalConfig,
                enabled: !_evaluating,
                onConfigChanged: _reevaluate,
                onReset: () => _reevaluate(_defaultEvalConfig),
              ),
              Expanded(
                child: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _page.index,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: (int index) {
                        setState(() => _page = _WorkspacePage.values[index]);
                      },
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.assessment),
                          selectedIcon: Icon(Icons.assessment),
                          label: Text('Dashboard'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.photo_library),
                          selectedIcon: Icon(Icons.photo_library),
                          label: Text('Browser'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.check_circle),
                          selectedIcon: Icon(Icons.check_circle),
                          label: Text('Health'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.grid_on),
                          selectedIcon: Icon(Icons.grid_on),
                          label: Text('Confusion'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.list),
                          selectedIcon: Icon(Icons.list),
                          label: Text('Worst'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.tips_and_updates),
                          selectedIcon: Icon(Icons.tips_and_updates),
                          label: Text('Advice'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _buildWorkspacePage(
                        filteredView: filteredView,
                        selectedImage: selectedImage,
                        selectedMatches: selectedMatches,
                        effectiveImageId: effectiveImageId,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_taskProgress != null)
            TaskProgressOverlay(
              progress: _taskProgress!,
              onCancel: _taskProgress!.canCancel ? _cancelTask : null,
            )
          else if (_evaluating)
            const _EvaluationOverlay(),
        ],
      ),
    );
  }

  Widget _buildWorkspacePage({
    required FilteredEvalView filteredView,
    required ImageRecord? selectedImage,
    required List<DetectionMatch> selectedMatches,
    required int? effectiveImageId,
  }) {
    return switch (_page) {
      _WorkspacePage.dashboard => DashboardPanel(
          dataset: widget.dataset,
          evalResult: _evalResult,
          selectedImage: null,
          selectedMatches: const <DetectionMatch>[],
          selectedMatch: null,
          issues: widget.issues,
          apEvalResult: _apEvalResults[_activeModelRun.id],
          canRunApEval: _canRunApEval(),
          runningApEval: _runningApEval,
          onRunApEval: _canRunApEval() ? _runApEval : null,
          onImportApMetrics: _importApMetrics,
          apEvalUnavailableReason: _apEvalError,
        ),
      _WorkspacePage.errorBrowser => Row(
          children: [
            SizedBox(
              width: 340,
              child: ImageBrowserPanel(
                dataset: widget.dataset,
                view: filteredView,
                filter: _viewFilter,
                selectedImageId: effectiveImageId,
                thumbnailCache: _thumbnailCache,
                projectId: _projectCacheId,
                imageSource: widget.imageSource,
                onFilterChanged: _updateViewFilter,
                onResetFilters: () => _updateViewFilter(_defaultViewFilter),
                onImageSelected: _selectImage,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _viewer(selectedImage, selectedMatches)),
            const VerticalDivider(width: 1),
            SizedBox(
              width: 360,
              child: BrowserDashboardTabs(
                dataset: widget.dataset,
                evalResult: _evalResult,
                selectedImage: selectedImage,
                selectedMatches: selectedMatches,
                selectedMatch: _selectedMatch,
                issues: widget.issues,
                apEvalResult: _apEvalResults[_activeModelRun.id],
                canRunApEval: _canRunApEval(),
                runningApEval: _runningApEval,
                onRunApEval: _canRunApEval() ? _runApEval : null,
                onImportApMetrics: _importApMetrics,
                apEvalUnavailableReason: _apEvalError,
              ),
            ),
          ],
        ),
      _WorkspacePage.datasetHealth => DatasetHealthScreen(
          report: _buildHealthReport(),
          dataset: widget.dataset,
          matchesByImageId: _matchesByImageId(),
          loadImageBytes: widget.imageSource.readImageBytes,
          onImageSelected: _openImageInBrowser,
        ),
      _WorkspacePage.confusionMatrix => ConfusionMatrixScreen(
          details: _buildConfusionDetails(),
          dataset: widget.dataset,
          matchesByImageId: _matchesByImageId(),
          loadImageBytes: widget.imageSource.readImageBytes,
          onImageSelected: _openImageInBrowser,
        ),
      _WorkspacePage.worstCases => WorstCasesScreen(
          result: _buildWorstCases(),
          dataset: widget.dataset,
          matchesByImageId: _matchesByImageId(),
          loadImageBytes: widget.imageSource.readImageBytes,
          onImageSelected: _openImageInBrowser,
          onExportAnnotated: _exportAnnotatedImageIds,
        ),
      _WorkspacePage.recommendations => RecommendationsScreen(
          recommendations: _buildRecommendations(),
          dataset: widget.dataset,
          onImageSelected: _openImageInBrowser,
          onCategorySelected: _openCategoryInBrowser,
        ),
    };
  }

  Widget _viewer(ImageRecord? selectedImage, List<DetectionMatch> matches) {
    return DetectionImageViewer(
      image: selectedImage,
      categoriesById: widget.dataset.categoriesById,
      matches: matches,
      imageBytes: _selectedImageBytes,
      loadingImage: _loadingImage,
      selectedMatch: _selectedMatch,
      onMatchSelected: (DetectionMatch? match) {
        setState(() {
          _selectedMatch = match;
        });
      },
    );
  }

  DatasetHealthReport _buildHealthReport() {
    return const DatasetHealthChecker().check(
      dataset: widget.dataset,
      predictions: _activeModelRun.predictions,
      imageAvailability: DatasetImageAvailability(
        missingFileNames: _missingImageFileNames,
        available: true,
      ),
    );
  }

  ConfusionMatrixDetails _buildConfusionDetails() {
    return const ConfusionMatrixDetailBuilder().build(
      dataset: widget.dataset,
      modelRun: _activeModelRun,
      config: _evalConfig,
    );
  }

  WorstCasesResult _buildWorstCases() {
    return const WorstCaseMiner().mine(
      dataset: widget.dataset,
      modelRun: _activeModelRun,
      evalResult: _evalResult,
      evalConfig: _evalConfig,
    );
  }

  ModelComparisonResult? _buildRecommendationComparison() {
    if (_modelRunEntries.length < 2) {
      return null;
    }
    final int baseIndex = _activeRunIndex == 0 ? 0 : 0;
    final int candidateIndex = _activeRunIndex == 0 ? 1 : _activeRunIndex;
    if (baseIndex == candidateIndex) {
      return null;
    }
    final ModelRunEntry base = _modelRunEntries[baseIndex];
    final ModelRunEntry candidate = _modelRunEntries[candidateIndex];
    return const ModelComparator().compare(
      dataset: widget.dataset,
      baseRun: base.modelRun,
      baseEval: base.evalResult,
      candidateRun: candidate.modelRun,
      candidateEval: candidate.evalResult,
      evalConfig: _evalConfig,
    );
  }

  List<Recommendation> _buildRecommendations() {
    final DatasetHealthReport healthReport = _buildHealthReport();
    final WorstCasesResult worstCases = _buildWorstCases();
    return const RuleBasedRecommendationEngine().build(
      dataset: widget.dataset,
      modelRun: _activeModelRun,
      evalResult: _evalResult,
      evalConfig: _evalConfig,
      healthReport: healthReport,
      worstCases: worstCases,
      comparison: _buildRecommendationComparison(),
      apEvalResult: _apEvalResults[_activeModelRun.id],
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    return [
      // Model run selector / label.
      if (_modelRunEntries.length >= 2)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: DropdownButton<int>(
            value: _activeRunIndex,
            underline: const SizedBox.shrink(),
            items: [
              for (int i = 0; i < _modelRunEntries.length; i++)
                DropdownMenuItem<int>(
                  value: i,
                  child: Text(_modelRunEntries[i].modelRun.name),
                ),
            ],
            onChanged: _evaluating ? null : _switchActiveRun,
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(child: Text(_activeModelRun.name)),
        ),

      // Rename active model run.
      Tooltip(
        message: 'Rename model run',
        child: IconButton(
          onPressed: _evaluating || _addingRun ? null : _renameActiveModelRun,
          icon: const Icon(Icons.edit),
        ),
      ),

      // Add Model Run button.
      if (!_addingRun)
        TextButton.icon(
          onPressed: _evaluating ? null : _addModelRun,
          icon: const Icon(Icons.add),
          label: const Text('Add model run'),
        ),
      if (_addingRun)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),

      // Remove model run button (only when > 1 runs).
      if (_modelRunEntries.length > 1)
        TextButton.icon(
          onPressed: _evaluating || _addingRun ? null : _removeActiveModelRun,
          icon: const Icon(Icons.remove_circle),
          label: const Text('Remove'),
        ),

      // Compare Models button.
      if (_modelRunEntries.length >= 2)
        TextButton.icon(
          onPressed: _evaluating ? null : _openCompareScreen,
          icon: const Icon(Icons.compare_arrows),
          label: const Text('Compare'),
        ),

      TextButton.icon(
        onPressed: _evaluating ? null : _openAnnotatedExportDialog,
        icon: const Icon(Icons.image),
        label: const Text('Export annotated'),
      ),

      Tooltip(
        message: 'Clear thumbnail cache',
        child: IconButton(
          onPressed: _evaluating ? null : _clearThumbnailCache,
          icon: const Icon(Icons.cleaning_services_outlined),
        ),
      ),

      // Save project button.
      if (_savingProject)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        )
      else
        TextButton.icon(
          onPressed: _evaluating ? null : _saveProject,
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),

      // Export button.
      if (_exporting)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        )
      else
        TextButton.icon(
          onPressed: _evaluating ? null : _openExportDialog,
          icon: const Icon(Icons.download),
          label: const Text('Export report'),
        ),
      const SizedBox(width: 8),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Center(child: LanguageSelector()),
      ),
    ];
  }

  FilteredEvalView _buildFilteredView() {
    return _filteredViewFor(_evalResult, _viewFilter);
  }

  FilteredEvalView _filteredViewFor(EvalResult result, EvalViewFilter filter) {
    final FilteredEvalView? cached = _cachedView;
    if (cached != null &&
        identical(_cachedViewResult, result) &&
        identical(_cachedViewFilter, filter)) {
      return cached;
    }
    final FilteredEvalView view = const EvalResultFilter().apply(
      dataset: widget.dataset,
      modelRun: _activeModelRun,
      evalResult: result,
      missingImageFileNames: _missingImageFileNames,
      filter: filter,
    );
    _cachedView = view;
    _cachedViewResult = result;
    _cachedViewFilter = filter;
    return view;
  }

  Map<int, List<DetectionMatch>> _matchesByImageId() {
    final Map<int, List<DetectionMatch>>? cached = _cachedMatchesByImageId;
    if (cached != null && identical(_cachedMatchesResult, _evalResult)) {
      return cached;
    }
    final Map<int, List<DetectionMatch>> matchesByImage = {};
    for (final DetectionMatch match in _evalResult.matches) {
      (matchesByImage[match.imageId] ??= <DetectionMatch>[]).add(match);
    }
    _cachedMatchesByImageId = matchesByImage;
    _cachedMatchesResult = _evalResult;
    return matchesByImage;
  }

  int? _effectiveSelectedImageId(FilteredEvalView view) {
    if (_selectedImageId != null &&
        view.filteredImageIds.contains(_selectedImageId)) {
      return _selectedImageId;
    }
    return view.filteredImageIds.isEmpty ? null : view.filteredImageIds.first;
  }

  void _openImageInBrowser(int imageId) {
    setState(() => _page = _WorkspacePage.errorBrowser);
    _selectImage(imageId);
  }

  void _openCategoryInBrowser(int categoryId) {
    _updateViewFilter(
      _viewFilter.copyWith(
        selectedClassIds: {categoryId},
        imageFilter: EvalImageFilter.all,
      ),
    );
    setState(() => _page = _WorkspacePage.errorBrowser);
  }

  void _updateViewFilter(EvalViewFilter filter) {
    final FilteredEvalView nextView = _filteredViewFor(_evalResult, filter);
    final int? nextImageId = _selectedImageId != null &&
            nextView.filteredImageIds.contains(_selectedImageId)
        ? _selectedImageId
        : (nextView.filteredImageIds.isEmpty
            ? null
            : nextView.filteredImageIds.first);
    setState(() {
      _viewFilter = filter;
      _selectedMatch = null;
    });
    if (nextImageId != _selectedImageId) {
      _selectImage(nextImageId);
    }
  }

  void _switchActiveRun(int? index) {
    if (index == null || index == _activeRunIndex) {
      return;
    }
    setState(() {
      _activeRunIndex = index;
      _evalResult = _modelRunEntries[index].evalResult;
      _selectedMatch = null;
      _cachedView = null;
      _cachedViewResult = null;
      _cachedViewFilter = null;
    });
    _loadSelectedImage();
  }

  Future<void> _addModelRun() async {
    setState(() => _addingRun = true);
    try {
      final PickedDataFile? file = await _filePicker.pickPredictionsJson(
        initialDirectory: await _preferences.getString(
          PreferenceKeys.lastPredictionsDirectory,
        ),
      );
      if (file == null || !mounted) {
        return;
      }
      await _rememberDirectory(
        PreferenceKeys.lastPredictionsDirectory,
        file.path,
      );

      final String defaultName = file.name.replaceAll('.json', '');
      final String? name = await _showNameDialog(defaultName: defaultName);
      if (name == null || !mounted) {
        return;
      }

      final String deduplicatedName = _deduplicateName(name);
      final ParseResult<ModelRun> parseResult =
          const CocoPredictionParser().parseString(
        file.readAsString(),
        dataset: widget.dataset,
        modelRunId: 'run-${DateTime.now().millisecondsSinceEpoch}',
        modelRunName: deduplicatedName,
      );

      if (parseResult.value == null) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not parse predictions file: '
              '${parseResult.issues.map((i) => i.message).join('; ')}',
            ),
          ),
        );
        return;
      }

      final EvalResult evalResult = const MetricsCalculator().evaluate(
        dataset: widget.dataset,
        modelRun: parseResult.value!,
        config: _evalConfig,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _modelRunEntries = [
          ..._modelRunEntries,
          ModelRunEntry(
            modelRun: parseResult.value!,
            evalResult: evalResult,
            predictionsPath: file.path,
          ),
        ];
        _activeRunIndex = _modelRunEntries.length - 1;
        _evalResult = evalResult;
        _selectedMatch = null;
        _cachedView = null;
        _cachedViewResult = null;
        _cachedViewFilter = null;
      });
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add model run: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _addingRun = false);
      }
    }
  }

  Future<void> _removeActiveModelRun() async {
    if (_modelRunEntries.length <= 1) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove model run'),
        content: Text(
          'Remove "${_activeModelRun.name}" from the workspace? '
          'This does not delete any files.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      final int removedIndex = _activeRunIndex;
      _modelRunEntries = [
        ..._modelRunEntries.sublist(0, removedIndex),
        ..._modelRunEntries.sublist(removedIndex + 1),
      ];
      _activeRunIndex = (_activeRunIndex >= _modelRunEntries.length)
          ? _modelRunEntries.length - 1
          : _activeRunIndex;
      _evalResult = _modelRunEntries[_activeRunIndex].evalResult;
      _selectedMatch = null;
      _cachedView = null;
      _cachedViewResult = null;
      _cachedViewFilter = null;
    });
  }

  Future<void> _renameProject() async {
    final String? newName = await _showNameDialog(defaultName: _projectName);
    if (newName == null || newName.isEmpty || !mounted) {
      return;
    }
    setState(() => _projectName = newName.trim());
  }

  Future<void> _renameActiveModelRun() async {
    final String? newName = await _showNameDialog(
      defaultName: _activeModelRun.name,
    );
    if (newName == null || newName.isEmpty || !mounted) {
      return;
    }
    final String deduplicatedName = newName == _activeModelRun.name
        ? newName
        : _deduplicateName(newName);
    final ModelRunEntry old = _modelRunEntries[_activeRunIndex];
    setState(() {
      _modelRunEntries = [
        ..._modelRunEntries.sublist(0, _activeRunIndex),
        ModelRunEntry(
          modelRun: old.modelRun.withName(deduplicatedName),
          evalResult: old.evalResult,
          predictionsPath: old.predictionsPath,
        ),
        ..._modelRunEntries.sublist(_activeRunIndex + 1),
      ];
    });
  }

  void _openCompareScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ModelCompareScreen(
          dataset: widget.dataset,
          modelRunEntries: List<ModelRunEntry>.of(_modelRunEntries),
          imageSource: widget.imageSource,
          evalConfig: _evalConfig,
          projectName: _projectName,
          apEvalResults: Map<String, ApEvalResult>.of(_apEvalResults),
          onActivateRun: (String runId) {
            final int index = _modelRunEntries
                .indexWhere((e) => e.modelRun.id == runId);
            if (index >= 0) {
              _switchActiveRun(index);
              Navigator.of(context).pop();
            }
          },
          onOpenCategory: (int categoryId) {
            _openCategoryInBrowser(categoryId);
            Navigator.of(context).pop();
          },
          onOpenImage: (int imageId) {
            _openImageInBrowser(imageId);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _saveProject({bool forceNewPath = false}) async {
    setState(() => _savingProject = true);
    try {
      final ProjectFileIo io = createProjectFileIo();
      final CvmlProject project = _buildProject();
      final String json = const ProjectSerializer().toJsonString(project);

      if (!forceNewPath && _projectFilePath != null) {
        final bool ok = await io.saveProjectToPath(_projectFilePath!, json);
        if (!mounted) {
          return;
        }
        if (ok) {
          await _recentProjectsManager.addOrUpdate(
            projectPath: _projectFilePath!,
            projectName: _projectName,
          );
          await _rememberDirectory(
            PreferenceKeys.lastProjectDirectory,
            _projectFilePath,
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'Project saved.' : 'Failed to save project.',
            ),
          ),
        );
      } else {
        final String suggestedName = '${_projectName}.cvmlab.json';
        final String? path = await io.saveProjectAs(
          json,
          suggestedName,
          initialDirectory:
              await _preferences.getString(PreferenceKeys.lastProjectDirectory),
        );
        if (!mounted) {
          return;
        }
        if (path != null) {
          setState(() => _projectFilePath = path);
          await _rememberDirectory(PreferenceKeys.lastProjectDirectory, path);
          await _recentProjectsManager.addOrUpdate(
            projectPath: path,
            projectName: _projectName,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project saved.')),
          );
        }
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingProject = false);
      }
    }
  }

  CvmlProject _buildProject() {
    final DateTime now = DateTime.now();
    return CvmlProject(
      schemaVersion: '1',
      id: 'project-${_projectName.hashCode.abs()}',
      name: _projectName,
      createdAt: now,
      updatedAt: now,
      datasetSource: ProjectDatasetSource(
        annotationsPath: widget.annotationsPath,
        imagesRootPath: widget.imagesRootPath,
        annotationsFileName: widget.annotationsPath != null
            ? widget.annotationsPath!.split('/').last
            : null,
        imagesSourceLabel: widget.imagesRootPath != null
            ? '${widget.imagesRootPath!.split('/').last}/'
            : null,
      ),
      modelRuns: _modelRunEntries
          .map(
            (ModelRunEntry e) => ProjectModelRunSource(
              id: e.modelRun.id,
              name: e.modelRun.name,
              predictionsPath: e.predictionsPath,
              predictionsFileName: e.predictionsPath != null
                  ? e.predictionsPath!.split('/').last
                  : null,
              addedAt: now,
              apEvalResult: _apEvalResults[e.modelRun.id],
            ),
          )
          .toList(),
      activeModelRunId: _activeModelRun.id,
      defaultEvalConfig: _evalConfig,
    );
  }

  Future<String?> _showNameDialog({required String defaultName}) async {
    final TextEditingController controller =
        TextEditingController(text: defaultName);
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Model run name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Name',
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  String _deduplicateName(String name) {
    final Set<String> existing =
        _modelRunEntries.map((e) => e.modelRun.name).toSet();
    if (!existing.contains(name)) {
      return name;
    }
    for (int i = 2; i < 1000; i++) {
      final String candidate = '$name ($i)';
      if (!existing.contains(candidate)) {
        return candidate;
      }
    }
    return '$name (${DateTime.now().millisecondsSinceEpoch})';
  }

  // The button is always enabled — availability is checked lazily on click.
  bool _canRunApEval() => !_runningApEval;

  Future<void> _runApEval() async {
    final String? unavailable = await _apEvaluator.checkAvailability();
    if (unavailable != null) {
      if (mounted) {
        setState(() => _apEvalError = unavailable);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(unavailable)),
        );
      }
      return;
    }

    setState(() {
      _runningApEval = true;
      _apEvalError = null;
      _taskProgress = const LongRunningTaskProgress(
        taskId: 'ap-eval',
        title: 'Running COCO AP evaluation',
        message: 'Starting AP evaluator',
        progress: null,
        canCancel: false,
      );
    });

    try {
      final String? annotationsPath = widget.annotationsPath;
      final String? predictionsPath = _activeEntry.predictionsPath;

      final ApEvalResult result;
      if (annotationsPath != null && predictionsPath != null) {
        result = await _apEvaluator.evaluate(
          annotationsPath: annotationsPath,
          predictionsPath: predictionsPath,
        );
      } else {
        // No on-disk paths (e.g. demo project) — serialize in-memory data.
        const CocoSerializer serializer = CocoSerializer();
        result = await _apEvaluator.evaluateFromJson(
          annotationsJson: serializer.annotationsJson(widget.dataset),
          predictionsJson:
              serializer.predictionsJson(_activeEntry.modelRun.predictions),
        );
      }
      if (mounted) {
        setState(() {
          _apEvalResults[_activeModelRun.id] = result;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        final FriendlyError friendly = friendlyErrorFrom(
          error,
          fallbackTitle: 'AP evaluator unavailable',
        );
        setState(() => _apEvalError = friendly.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendly.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _runningApEval = false;
          _taskProgress = null;
        });
      }
    }
  }

  Future<void> _importApMetrics() async {
    try {
      final PickedDataFile? file = await _filePicker.pickApMetricsJson(
        initialDirectory: await _preferences.getString(
          PreferenceKeys.lastApMetricsImportDirectory,
        ),
      );
      if (file == null || !mounted) {
        return;
      }
      await _rememberDirectory(
        PreferenceKeys.lastApMetricsImportDirectory,
        file.path,
      );
      final dynamic decoded = dart_convert.jsonDecode(file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Invalid AP metrics JSON: expected a JSON object.',
              ),
            ),
          );
        }
        return;
      }
      final ApEvalResult result = const ApEvalResultParser().fromJson(decoded);
      if (mounted) {
        setState(() {
          _apEvalResults[_activeModelRun.id] = result;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        final FriendlyError friendly = friendlyErrorFrom(
          error,
          fallbackTitle: 'Invalid AP metrics JSON',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendly.message)),
        );
      }
    }
  }

  Future<void> _reevaluate(EvalConfig config) async {
    final int requestId = ++_evaluationRequestId;
    final CancellationToken token = CancellationToken();
    setState(() {
      _evalConfig = config;
      _evaluating = true;
      _selectedMatch = null;
      _cancellationToken?.cancel();
      _cancellationToken = token;
      _taskProgress = const LongRunningTaskProgress(
        taskId: 'threshold-recompute',
        title: 'Recalculating metrics',
        message: 'Applying threshold changes',
        progress: null,
        canCancel: true,
      );
    });

    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Re-evaluate all runs under the new config.
    final List<ModelRunEntry> reevaluated = [];
    for (int i = 0; i < _modelRunEntries.length; i++) {
      if (token.isCancelled) {
        if (mounted && identical(_cancellationToken, token)) {
          setState(() {
            _evaluating = false;
            _taskProgress = null;
            _cancellationToken = null;
          });
        }
        return;
      }
      final ModelRunEntry e = _modelRunEntries[i];
      setState(
        () => _taskProgress = LongRunningTaskProgress(
          taskId: 'threshold-recompute',
          title: 'Recalculating metrics',
          message: 'Evaluating ${e.modelRun.name}',
          progress:
              _modelRunEntries.isEmpty ? null : i / _modelRunEntries.length,
          canCancel: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final EvalResult newEval = const MetricsCalculator().evaluate(
        dataset: widget.dataset,
        modelRun: e.modelRun,
        config: config,
      );
      reevaluated.add(
        ModelRunEntry(
          modelRun: e.modelRun,
          evalResult: newEval,
          predictionsPath: e.predictionsPath,
        ),
      );
    }

    if (!mounted || requestId != _evaluationRequestId || token.isCancelled) {
      if (mounted && identical(_cancellationToken, token)) {
        setState(() {
          _evaluating = false;
          _taskProgress = null;
          _cancellationToken = null;
        });
      }
      return;
    }

    final EvalResult newActiveResult = reevaluated[_activeRunIndex].evalResult;
    final FilteredEvalView nextView =
        _filteredViewFor(newActiveResult, _viewFilter);
    final int? nextImageId = _selectedImageId != null &&
            nextView.filteredImageIds.contains(_selectedImageId)
        ? _selectedImageId
        : (nextView.filteredImageIds.isEmpty
            ? null
            : nextView.filteredImageIds.first);

    setState(() {
      _modelRunEntries = reevaluated;
      _evalResult = newActiveResult;
      _evaluating = false;
      _cachedView = null;
      _cachedViewResult = null;
      _cachedViewFilter = null;
      _taskProgress = null;
      _cancellationToken = null;
    });
    if (nextImageId != _selectedImageId) {
      _selectImage(nextImageId);
    }
  }

  void _selectImage(int? imageId) {
    if (_selectedImageId == imageId && imageId != null) {
      return;
    }
    setState(() {
      _selectedImageId = imageId;
      _selectedMatch = null;
      _selectedImageBytes = null;
      _loadingImage = false;
    });
    _loadSelectedImage();
  }

  Future<void> _loadSelectedImage() async {
    final int? imageId = _selectedImageId;
    if (imageId == null) {
      return;
    }
    final ImageRecord? image = widget.dataset.imagesById[imageId];
    if (image == null) {
      return;
    }
    setState(() {
      _loadingImage = true;
    });
    final Uint8List? bytes =
        await widget.imageSource.readImageBytes(image.fileName);
    if (!mounted || _selectedImageId != imageId) {
      return;
    }
    setState(() {
      _selectedImageBytes = bytes;
      _loadingImage = false;
    });
  }

  Future<void> _openExportDialog() async {
    final ExportReportRequest? request = await showDialog<ExportReportRequest>(
      context: context,
      builder: (BuildContext context) => ExportReportDialog(
        smallObjectStatsAvailable: _evalResult.smallObjectStats.isNotEmpty,
        confusionMatrixAvailable: _evalResult.confusionMatrix.counts.isNotEmpty,
        filteredViewAvailable: true,
        apMetricsAvailable: _apEvalResults[_activeModelRun.id] != null,
      ),
    );
    if (request == null || !mounted) {
      return;
    }
    await _exportReport(request);
  }

  Future<void> _exportReport(ExportReportRequest request) async {
    setState(() {
      _exporting = true;
      _taskProgress = const LongRunningTaskProgress(
        taskId: 'report-export',
        title: 'Exporting report',
        message: 'Building selected report files',
        progress: null,
        canCancel: false,
      );
    });
    await Future<void>.delayed(Duration.zero);
    try {
      final AppLocale reportLocale = request.locale == AppLocale.system
          ? AppLocaleScope.of(context).locale
          : request.locale;
      final ReportBundle bundle = await const ReportBundleBuilder().build(
        dataset: widget.dataset,
        modelRun: _activeModelRun,
        evalConfig: _evalConfig,
        evalResult: _evalResult,
        components: request.components,
        locale: reportLocale,
        activeFilter: _viewFilter,
        filteredView: _buildFilteredView(),
        scope: request.scope,
        projectName: _projectName,
        modelRunName: _activeModelRun.name,
        missingImageFileNames: _missingImageFileNames,
        imageAvailability: DatasetImageAvailability(
          missingFileNames: _missingImageFileNames,
          available: true,
        ),
        comparison: _buildRecommendationComparison(),
        apEvalResult: _apEvalResults[_activeModelRun.id],
      );
      setState(
        () => _taskProgress = const LongRunningTaskProgress(
          taskId: 'report-export',
          title: 'Exporting report',
          message: 'Choosing export folder',
          progress: null,
          canCancel: false,
        ),
      );
      final ReportSaveResult result = await _reportSaver.save(
        bundle,
        initialDirectory:
            await _preferences.getString(PreferenceKeys.lastExportDirectory),
      );
      if (result.location != null &&
          result.status == ReportSaveStatus.savedToDirectory) {
        await _preferences.setString(
          PreferenceKeys.lastExportDirectory,
          result.location!,
        );
      }
      if (!mounted) {
        return;
      }
      _showExportResult(result);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorFrom(error, fallbackTitle: 'Export failed').message,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
          _taskProgress = null;
        });
      }
    }
  }

  Future<void> _openAnnotatedExportDialog() async {
    final AnnotatedImageExportConfig? config =
        await showDialog<AnnotatedImageExportConfig>(
      context: context,
      builder: (BuildContext context) => AnnotatedExportDialog(
        currentImageAvailable: _selectedImageId != null,
        filteredImagesAvailable:
            _buildFilteredView().filteredImageIds.isNotEmpty,
      ),
    );
    if (config == null || !mounted) {
      return;
    }
    await _exportAnnotatedImages(config: config);
  }

  Future<void> _exportAnnotatedImageIds(List<int> imageIds) async {
    await _exportAnnotatedImages(
      config: const AnnotatedImageExportConfig(
        scope: AnnotatedExportScope.currentFilteredImages,
      ),
      explicitImageIds: imageIds,
    );
  }

  Future<void> _exportAnnotatedImages({
    required AnnotatedImageExportConfig config,
    List<int>? explicitImageIds,
  }) async {
    final CancellationToken token = CancellationToken();
    setState(() {
      _exporting = true;
      _cancellationToken = token;
      _taskProgress = const LongRunningTaskProgress(
        taskId: 'annotated-export',
        title: 'Exporting annotated images',
        message: 'Preparing image list',
        progress: null,
        canCancel: true,
      );
    });
    await Future<void>.delayed(Duration.zero);
    try {
      final FilteredEvalView view = _buildFilteredView();
      final List<AnnotatedExportTarget> targets =
          const AnnotatedExportSelector().resolveTargets(
        config: config,
        dataset: widget.dataset,
        evalResult: _evalResult,
        currentImageId: _selectedImageId,
        filteredImageIds: explicitImageIds ?? view.filteredImageIds,
      );
      if (targets.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No images match this export scope.')),
          );
        }
        return;
      }

      final Map<int, List<DetectionMatch>> matchesByImage = _matchesByImageId();
      final Map<String, Uint8List> pngFiles = {};
      final AnnotatedImageRenderer renderer = const AnnotatedImageRenderer();
      for (int i = 0; i < targets.length; i++) {
        token.throwIfCancelled();
        final AnnotatedExportTarget target = targets[i];
        setState(
          () => _taskProgress = LongRunningTaskProgress(
            taskId: 'annotated-export',
            title: 'Exporting annotated images',
            message: 'Rendering ${target.outputFileName}',
            progress: targets.isEmpty ? null : i / targets.length,
            canCancel: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        final ImageRecord? image = widget.dataset.imagesById[target.imageId];
        if (image == null) {
          continue;
        }
        final Uint8List? bytes = await widget.imageSource.readImageBytes(
          image.fileName,
        );
        pngFiles[target.outputFileName] = await renderer.render(
          image: image,
          imageBytes: bytes,
          matches: matchesByImage[target.imageId] ?? const <DetectionMatch>[],
          categoriesById: widget.dataset.categoriesById,
          config: config,
          modelName: _activeModelRun.name,
        );
      }
      token.throwIfCancelled();
      final AnnotatedImageSaveResult result =
          await _annotatedImageSaver.save(pngFiles);
      if (!mounted) {
        return;
      }
      _showAnnotatedExportResult(result);
    } on TaskCancelledException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Annotated export cancelled.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Annotated export failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
          if (identical(_cancellationToken, token)) {
            _cancellationToken = null;
          }
          _taskProgress = null;
        });
      }
    }
  }

  void _showAnnotatedExportResult(AnnotatedImageSaveResult result) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    switch (result.status) {
      case AnnotatedImageSaveStatus.cancelled:
        return;
      case AnnotatedImageSaveStatus.downloadStarted:
        messenger.showSnackBar(
          const SnackBar(content: Text('Annotated image download started.')),
        );
      case AnnotatedImageSaveStatus.savedToDirectory:
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Saved ${result.fileNames.length} annotated image(s) to ${result.location}.',
            ),
          ),
        );
    }
  }

  void _showExportResult(ReportSaveResult result) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    switch (result.status) {
      case ReportSaveStatus.cancelled:
        return;
      case ReportSaveStatus.downloadStarted:
        messenger.showSnackBar(
          const SnackBar(content: Text('Your report download has started.')),
        );
      case ReportSaveStatus.savedToDirectory:
        showDialog<void>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Report exported successfully'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.location != null) ...[
                  Text('Saved to:\n${result.location}'),
                  const SizedBox(height: 12),
                ],
                const Text('Files:'),
                for (final String fileName in result.fileNames)
                  Text('• $fileName'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
    }
  }

  Future<void> _clearThumbnailCache() async {
    await _thumbnailCache.clearProjectCache(_projectCacheId);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thumbnail cache cleared.')),
    );
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

class _EvaluationOverlay extends StatelessWidget {
  const _EvaluationOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black12,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 56),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: const SizedBox(
                  width: 320,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Recalculating metrics...'),
                        SizedBox(height: 12),
                        LinearProgressIndicator(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThresholdToolbar extends StatelessWidget {
  const _ThresholdToolbar({
    required this.config,
    required this.enabled,
    required this.onConfigChanged,
    required this.onReset,
  });

  final EvalConfig config;
  final bool enabled;
  final ValueChanged<EvalConfig> onConfigChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: _ThresholdField(
                label: 'IoU',
                value: config.iouThreshold,
                enabled: enabled,
                onSubmitted: (double value) => onConfigChanged(
                  config.copyWith(iouThreshold: value),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ThresholdField(
                label: 'Confidence',
                value: config.confidenceThreshold,
                enabled: enabled,
                onSubmitted: (double value) => onConfigChanged(
                  config.copyWith(confidenceThreshold: value),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: 'Class-aware matching',
              child: FilterChip(
                label: const Text('Class aware'),
                selected: config.classAwareMatching,
                onSelected: enabled
                    ? (bool value) => onConfigChanged(
                          config.copyWith(classAwareMatching: value),
                        )
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Ignore crowd annotations',
              child: FilterChip(
                label: const Text('Ignore crowd'),
                selected: config.ignoreCrowd,
                onSelected: enabled
                    ? (bool value) =>
                        onConfigChanged(config.copyWith(ignoreCrowd: value))
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: enabled ? onReset : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Defaults'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThresholdField extends StatefulWidget {
  const _ThresholdField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onSubmitted,
  });

  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onSubmitted;

  @override
  State<_ThresholdField> createState() => _ThresholdFieldState();
}

class _ThresholdFieldState extends State<_ThresholdField> {
  late double _draftValue;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _draftValue = widget.value;
    _controller = TextEditingController(text: _formatValue(widget.value));
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _ThresholdField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_focusNode.hasFocus) {
      _draftValue = widget.value;
      _controller.text = _formatValue(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text('${widget.label} ${_formatValue(_draftValue)}'),
        ),
        Expanded(
          child: Slider(
            value: _draftValue,
            min: 0,
            max: 1,
            divisions: 100,
            label: _formatValue(_draftValue),
            onChanged: widget.enabled
                ? (double value) {
                    setState(() {
                      _draftValue = value;
                      if (!_focusNode.hasFocus) {
                        _controller.text = _formatValue(value);
                      }
                    });
                  }
                : null,
            onChangeEnd: widget.enabled ? _submitValue : null,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            enabled: widget.enabled,
            onSubmitted: (_) => _submitText(),
          ),
        ),
      ],
    );
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) {
      _submitText();
    }
  }

  void _submitText() {
    final double? parsed =
        double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (parsed == null) {
      _controller.text = _formatValue(_draftValue);
      return;
    }
    _submitValue(parsed.clamp(0, 1).toDouble());
  }

  void _submitValue(double value) {
    final double clamped = value.clamp(0, 1).toDouble();
    setState(() {
      _draftValue = clamped;
      _controller.text = _formatValue(clamped);
    });
    if ((clamped - widget.value).abs() > 0.0001) {
      widget.onSubmitted(clamped);
    }
  }

  String _formatValue(double value) => value.toStringAsFixed(2);
}
