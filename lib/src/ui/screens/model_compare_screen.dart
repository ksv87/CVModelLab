import 'dart:typed_data';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import '../../platform_io/image_source.dart';
import '../../platform_io/pdf_font_loader.dart';
import '../../platform_io/report_saver.dart';
import '../../platform_io/user_preferences.dart';
import '../l10n/app_locale_scope.dart';
import '../l10n/app_localizations.dart';
import '../widgets/detection_image_viewer.dart';
import '../widgets/status_views.dart';
import 'workspace_screen.dart';

enum _CompareMode { pairwise, multi }

class ModelCompareScreen extends StatefulWidget {
  const ModelCompareScreen({
    required this.dataset,
    required this.modelRunEntries,
    required this.imageSource,
    required this.evalConfig,
    required this.projectName,
    this.apEvalResults = const {},
    this.onActivateRun,
    this.onOpenCategory,
    this.onOpenImage,
    super.key,
  });

  final CocoDataset dataset;
  final List<ModelRunEntry> modelRunEntries;
  final ImageSource imageSource;
  final EvalConfig evalConfig;
  final String projectName;
  final Map<String, ApEvalResult> apEvalResults;

  /// Set a model run as the workspace's active run (and leave the screen).
  final void Function(String runId)? onActivateRun;

  /// Open the Error Browser filtered by a category.
  final void Function(int categoryId)? onOpenCategory;

  /// Open the Error Browser focused on an image.
  final void Function(int imageId)? onOpenImage;

  @override
  State<ModelCompareScreen> createState() => _ModelCompareScreenState();
}

// Metrics valid for the per-class ranking dropdown (class-level comparison).
// Must stay in sync with the items list in the per-class DropdownButton.
const List<MultiModelRankingMetric> _kPerClassMetrics = [
  MultiModelRankingMetric.f1,
  MultiModelRankingMetric.recall,
  MultiModelRankingMetric.precision,
  MultiModelRankingMetric.ap,
  MultiModelRankingMetric.fp,
  MultiModelRankingMetric.fn,
];

class _ModelCompareScreenState extends State<ModelCompareScreen>
    with TickerProviderStateMixin {
  late TabController _pairwiseTab;
  late TabController _multiTab;
  _CompareMode _mode = _CompareMode.pairwise;

  // Pairwise state.
  int _baseIndex = 0;
  int _candidateIndex = 1;
  ModelComparisonResult? _comparisonResult;
  ImageComparisonStatus? _imageFilter;
  int? _selectedImageId;
  Uint8List? _selectedImageBytes;
  bool _loadingImage = false;
  final TransformationController _pairwiseTransform =
      TransformationController();

  // Multi-model state.
  late Set<String> _selectedRunIds;
  MultiModelRankingMetric _rankingMetric = MultiModelRankingMetric.f1;
  bool _hideAllCorrect = true;
  bool _includeAp = true;
  MultiModelComparisonResult? _multiResult;
  ImageDisagreementType? _disagreementFilter;
  MultiModelRankingMetric _perClassMetric = MultiModelRankingMetric.f1;
  String _classSearch = '';
  String _matrixCellMode = 'dF1';
  final Set<String> _pairSelection = {};
  int? _multiImageId;
  Uint8List? _multiImageBytes;
  bool _loadingMultiImage = false;
  final TransformationController _multiTransform = TransformationController();

  bool _exporting = false;

  final ReportSaver _reportSaver = createReportSaver();
  final UserPreferencesStore _preferences = createUserPreferencesStore();

  @override
  void initState() {
    super.initState();
    _pairwiseTab = TabController(length: 5, vsync: this);
    _multiTab = TabController(length: 5, vsync: this);
    _pairwiseTab.addListener(_onPairwiseTabChanged);
    _multiTab.addListener(_onMultiTabChanged);
    _selectedRunIds = {
      for (final ModelRunEntry e in widget.modelRunEntries) e.modelRun.id,
    };
    _includeAp = widget.apEvalResults.isNotEmpty;
    _computePairwise();
    _computeMulti();
    _restorePreferences();
  }

  void _onPairwiseTabChanged() {
    if (!mounted) return;
    if (!_pairwiseTab.indexIsChanging &&
        _pairwiseTab.index == 3 &&
        _selectedImageId == null) {
      final List<int> ids = widget.dataset.imagesById.keys.toList()..sort();
      if (ids.isNotEmpty) _selectPairwiseImage(ids.first);
    }
  }

  void _onMultiTabChanged() {
    if (!mounted) return;
    if (!_multiTab.indexIsChanging &&
        _multiTab.index == 4 &&
        _multiImageId == null) {
      final List<int> ids = widget.dataset.imagesById.keys.toList()..sort();
      if (ids.isNotEmpty) _selectMultiImage(ids.first);
    }
  }

  @override
  void dispose() {
    _pairwiseTab.removeListener(_onPairwiseTabChanged);
    _multiTab.removeListener(_onMultiTabChanged);
    _pairwiseTab.dispose();
    _multiTab.dispose();
    _pairwiseTransform.dispose();
    _multiTransform.dispose();
    super.dispose();
  }

  Future<void> _restorePreferences() async {
    final String? mode =
        await _preferences.getString(PreferenceKeys.lastCompareMode);
    final String? metric =
        await _preferences.getString(PreferenceKeys.lastRankingMetric);
    if (!mounted) {
      return;
    }
    setState(() {
      if (mode == 'multi' && widget.modelRunEntries.length >= 2) {
        _mode = _CompareMode.multi;
      }
      if (metric != null) {
        _rankingMetric = MultiModelRankingMetric.values.firstWhere(
          (m) => m.name == metric,
          orElse: () => MultiModelRankingMetric.f1,
        );
        // _perClassMetric must be in the per-class dropdown subset.
        _perClassMetric = _kPerClassMetrics.contains(_rankingMetric)
            ? _rankingMetric
            : MultiModelRankingMetric.f1;
      }
    });
    _computeMulti();
  }

  // ── compute ────────────────────────────────────────────────────────────

  void _computePairwise() {
    if (widget.modelRunEntries.length < 2) {
      return;
    }
    final ModelRunEntry baseEntry = widget.modelRunEntries[_baseIndex];
    final ModelRunEntry candidateEntry =
        widget.modelRunEntries[_candidateIndex];
    final ModelComparisonResult result = const ModelComparator().compare(
      dataset: widget.dataset,
      baseRun: baseEntry.modelRun,
      baseEval: baseEntry.evalResult,
      candidateRun: candidateEntry.modelRun,
      candidateEval: candidateEntry.evalResult,
      evalConfig: widget.evalConfig,
    );
    setState(() => _comparisonResult = result);
  }

  void _computeMulti() {
    final List<ModelRunEntry> selected = widget.modelRunEntries
        .where((e) => _selectedRunIds.contains(e.modelRun.id))
        .toList();
    if (selected.length < 2) {
      setState(() => _multiResult = null);
      return;
    }
    final Map<String, EvalResult> evals = {
      for (final ModelRunEntry e in selected) e.modelRun.id: e.evalResult,
    };
    final MultiModelComparisonResult result =
        const MultiModelComparator().compare(
      dataset: widget.dataset,
      modelRuns: selected.map((e) => e.modelRun).toList(),
      evalResultsByRunId: evals,
      evalConfig: widget.evalConfig,
      apResultsByRunId: _includeAp ? widget.apEvalResults : null,
      config: MultiModelComparisonConfig(primaryMetric: _rankingMetric),
      generatedAt: DateTime.now(),
    );
    setState(() => _multiResult = result);
  }

  bool get _hasAnyAp => widget.apEvalResults.isNotEmpty;

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocaleScope.l10n(context);
    if (widget.modelRunEntries.length < 2) {
      return Scaffold(
        appBar: AppBar(title: Text('Compare — ${widget.projectName}')),
        body: EmptyStateView(
          title: l.t(MessageKey.mmSelectTwoRuns),
          explanation: l.t(MessageKey.mmSelectTwoRuns),
          icon: Icons.compare_arrows,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Compare — ${widget.projectName}'),
        actions: [
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
              onPressed: _export,
              icon: const Icon(Icons.download),
              label: Text(l.t(MessageKey.mmExportTable)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildModeSelector(l),
          if (_mode == _CompareMode.pairwise)
            _buildPairwiseBody(l)
          else
            _buildMultiBody(l),
        ],
      ),
    );
  }

  Widget _buildModeSelector(AppLocalizations l) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SegmentedButton<_CompareMode>(
              segments: [
                ButtonSegment(
                  value: _CompareMode.pairwise,
                  label: Text(l.t(MessageKey.mmPairwiseMode)),
                  icon: const Icon(Icons.compare),
                ),
                ButtonSegment(
                  value: _CompareMode.multi,
                  label: Text(l.t(MessageKey.mmMultiModelMode)),
                  icon: const Icon(Icons.leaderboard),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) {
                setState(() => _mode = s.first);
                _preferences.setString(
                  PreferenceKeys.lastCompareMode,
                  _mode == _CompareMode.multi ? 'multi' : 'pairwise',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════ PAIRWISE ════════════════════════

  Widget _buildPairwiseBody(AppLocalizations l) {
    return Expanded(
      child: Column(
        children: [
          _buildPairwiseSelector(),
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _pairwiseTab,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Per Class'),
                Tab(text: 'Images'),
                Tab(text: 'Compare Viewer'),
                Tab(text: 'AP Diff'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _pairwiseTab,
              children: [
                _buildOverviewTab(),
                _buildPerClassTab(),
                _buildImagesTab(),
                _buildCompareViewerTab(),
                _buildApDiffTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairwiseSelector() {
    final List<DropdownMenuItem<int>> items = [
      for (int i = 0; i < widget.modelRunEntries.length; i++)
        DropdownMenuItem<int>(
          value: i,
          child: Text(widget.modelRunEntries[i].modelRun.name),
        ),
    ];
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Text('Base model:'),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _baseIndex,
              items: items,
              onChanged: (int? v) {
                if (v == null || v == _baseIndex) {
                  return;
                }
                setState(() {
                  _baseIndex = v;
                  if (_candidateIndex == _baseIndex) {
                    _candidateIndex = _baseIndex == 0 ? 1 : 0;
                  }
                });
                _computePairwise();
              },
            ),
            const SizedBox(width: 24),
            const Text('Candidate model:'),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _candidateIndex,
              items: items,
              onChanged: (int? v) {
                if (v == null || v == _candidateIndex) {
                  return;
                }
                setState(() {
                  _candidateIndex = v;
                  if (_baseIndex == _candidateIndex) {
                    _baseIndex = _candidateIndex == 0 ? 1 : 0;
                  }
                });
                _computePairwise();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final ModelComparisonResult? result = _comparisonResult;
    if (result == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final MetricsDiff diff = result.overallDiff;
    final String baseName = widget.modelRunEntries[_baseIndex].modelRun.name;
    final String candidateName =
        widget.modelRunEntries[_candidateIndex].modelRun.name;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Metrics',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                label: 'Precision',
                base: diff.basePrecision.toStringAsFixed(3),
                candidate: diff.candidatePrecision.toStringAsFixed(3),
                delta: diff.deltaPrecision,
                higherIsBetter: true,
              ),
              _MetricCard(
                label: 'Recall',
                base: diff.baseRecall.toStringAsFixed(3),
                candidate: diff.candidateRecall.toStringAsFixed(3),
                delta: diff.deltaRecall,
                higherIsBetter: true,
              ),
              _MetricCard(
                label: 'F1',
                base: diff.baseF1.toStringAsFixed(3),
                candidate: diff.candidateF1.toStringAsFixed(3),
                delta: diff.deltaF1,
                higherIsBetter: true,
              ),
              _MetricCard(
                label: 'TP',
                base: diff.baseTp.toString(),
                candidate: diff.candidateTp.toString(),
                intDelta: diff.deltaTp,
                higherIsBetter: true,
              ),
              _MetricCard(
                label: 'FP',
                base: diff.baseFp.toString(),
                candidate: diff.candidateFp.toString(),
                intDelta: diff.deltaFp,
                higherIsBetter: false,
              ),
              _MetricCard(
                label: 'FN',
                base: diff.baseFn.toString(),
                candidate: diff.candidateFn.toString(),
                intDelta: diff.deltaFn,
                higherIsBetter: false,
              ),
              _MetricCard(
                label: 'Images\nwith errors',
                base: diff.baseImagesWithErrors.toString(),
                candidate: diff.candidateImagesWithErrors.toString(),
                intDelta: diff.deltaImagesWithErrors,
                higherIsBetter: false,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _StatusSummaryRow(result: result),
          const SizedBox(height: 16),
          Text(
            'Base: $baseName   Candidate: $candidateName',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildPerClassTab() {
    final ModelComparisonResult? result = _comparisonResult;
    if (result == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _PerClassTable(
      diffs: result.perClassDiffs,
      baseName: widget.modelRunEntries[_baseIndex].modelRun.name,
      candidateName: widget.modelRunEntries[_candidateIndex].modelRun.name,
    );
  }

  Widget _buildImagesTab() {
    final ModelComparisonResult? result = _comparisonResult;
    if (result == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final List<ImageComparisonSummary> summaries = _imageFilter == null
        ? result.imageSummaries
        : result.imageSummaries.where((s) => s.status == _imageFilter).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _imageFilter == null,
                  onSelected: (_) => setState(() => _imageFilter = null),
                ),
                const SizedBox(width: 8),
                for (final ImageComparisonStatus status
                    in ImageComparisonStatus.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_statusLabel(status)),
                      selected: _imageFilter == status,
                      selectedColor:
                          _statusColor(status).withValues(alpha: 0.2),
                      onSelected: (_) => setState(
                        () => _imageFilter =
                            _imageFilter == status ? null : status,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: summaries.length,
            itemBuilder: (context, index) {
              final ImageComparisonSummary s = summaries[index];
              return ListTile(
                dense: true,
                leading: Icon(
                  _statusIcon(s.status),
                  color: _statusColor(s.status),
                ),
                title: Text(s.fileName),
                subtitle: Text(
                  'Base: ${s.baseTp}TP/${s.baseFp}FP/${s.baseFn}FN  '
                  'Cand: ${s.candidateTp}TP/${s.candidateFp}FP/${s.candidateFn}FN  '
                  'Delta: ${_sign(s.deltaTp)}TP/${_sign(s.deltaFp)}FP/${_sign(s.deltaFn)}FN',
                ),
                trailing: Text(_statusLabel(s.status)),
                onTap: () => _openPairwiseImage(s.imageId),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompareViewerTab() {
    final List<int> imageIds = widget.dataset.imagesById.keys.toList()..sort();
    final int? effectiveId = _selectedImageId != null &&
            widget.dataset.imagesById.containsKey(_selectedImageId)
        ? _selectedImageId
        : (imageIds.isEmpty ? null : imageIds.first);
    final ImageRecord? selectedImage =
        effectiveId == null ? null : widget.dataset.imagesById[effectiveId];
    final ModelRunEntry baseEntry = widget.modelRunEntries[_baseIndex];
    final ModelRunEntry candidateEntry =
        widget.modelRunEntries[_candidateIndex];
    final List<DetectionMatch> baseMatches = effectiveId == null
        ? const []
        : baseEntry.evalResult.matches
            .where((m) => m.imageId == effectiveId)
            .toList();
    final List<DetectionMatch> candidateMatches = effectiveId == null
        ? const []
        : candidateEntry.evalResult.matches
            .where((m) => m.imageId == effectiveId)
            .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Text('Image:'),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: effectiveId,
                  items: [
                    for (final int id in imageIds)
                      DropdownMenuItem<int>(
                        value: id,
                        child: Text(
                          widget.dataset.imagesById[id]?.fileName ?? '$id',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (int? id) {
                    if (id != null) {
                      _selectPairwiseImage(id);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              _buildZoomControls(_pairwiseTransform),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _viewerPanel(
                  baseEntry.modelRun.name,
                  selectedImage,
                  baseMatches,
                  _selectedImageBytes,
                  _loadingImage,
                  _pairwiseTransform,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _viewerPanel(
                  candidateEntry.modelRun.name,
                  selectedImage,
                  candidateMatches,
                  _selectedImageBytes,
                  _loadingImage,
                  _pairwiseTransform,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildZoomControls(TransformationController ctrl) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.zoom_out, size: 20),
          tooltip: 'Zoom out',
          onPressed: () => _applyZoom(ctrl, 1 / 1.5),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: const Icon(Icons.zoom_in, size: 20),
          tooltip: 'Zoom in',
          onPressed: () => _applyZoom(ctrl, 1.5),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: const Icon(Icons.fit_screen, size: 20),
          tooltip: 'Reset zoom',
          onPressed: () => ctrl.value = Matrix4.identity(),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  void _applyZoom(TransformationController ctrl, double factor) {
    final Matrix4 m = ctrl.value.clone();
    final double current = m.getMaxScaleOnAxis();
    final double next = (current * factor).clamp(0.1, 8.0);
    final double actual = next / current;
    m.scaleByDouble(actual, actual, 1.0, 1.0);
    ctrl.value = m;
  }

  Widget _buildApDiffTab() {
    final ApEvalResult? baseAp =
        widget.apEvalResults[widget.modelRunEntries[_baseIndex].modelRun.id];
    final ApEvalResult? candidateAp = widget
        .apEvalResults[widget.modelRunEntries[_candidateIndex].modelRun.id];
    final String baseName = widget.modelRunEntries[_baseIndex].modelRun.name;
    final String candidateName =
        widget.modelRunEntries[_candidateIndex].modelRun.name;
    if (baseAp == null && candidateAp == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No AP metrics available for either model.\n'
            'Run COCO AP evaluation from the Dashboard.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    String fmt(double? v) => v == null ? '-' : v.toStringAsFixed(3);
    String delta(double? b, double? c) {
      if (b == null || c == null) {
        return '-';
      }
      final double d = c - b;
      return d >= 0 ? '+${d.toStringAsFixed(3)}' : d.toStringAsFixed(3);
    }

    final List<({String metric, double? base, double? candidate})> rows = [
      (metric: 'AP@[.5:.95]', base: baseAp?.ap, candidate: candidateAp?.ap),
      (metric: 'AP50', base: baseAp?.ap50, candidate: candidateAp?.ap50),
      (metric: 'AP75', base: baseAp?.ap75, candidate: candidateAp?.ap75),
      (
        metric: 'APsmall',
        base: baseAp?.apSmall,
        candidate: candidateAp?.apSmall
      ),
      (
        metric: 'APmedium',
        base: baseAp?.apMedium,
        candidate: candidateAp?.apMedium
      ),
      (
        metric: 'APlarge',
        base: baseAp?.apLarge,
        candidate: candidateAp?.apLarge
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AP Metrics Diff',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Base: $baseName   Candidate: $candidateName',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          DataTable(
            columns: [
              const DataColumn(label: Text('Metric')),
              DataColumn(label: Text(baseName)),
              DataColumn(label: Text(candidateName)),
              const DataColumn(label: Text('Delta')),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(Text(row.metric)),
                    DataCell(Text(fmt(row.base))),
                    DataCell(Text(fmt(row.candidate))),
                    DataCell(Text(delta(row.base, row.candidate))),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════ MULTI-MODEL ════════════════════════

  Widget _buildMultiBody(AppLocalizations l) {
    return Expanded(
      child: Column(
        children: [
          _buildMultiControls(l),
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _multiTab,
              isScrollable: true,
              tabs: [
                Tab(text: l.t(MessageKey.mmLeaderboard)),
                Tab(text: l.t(MessageKey.mmPerClassRanking)),
                Tab(text: l.t(MessageKey.mmImageDisagreement)),
                Tab(text: l.t(MessageKey.mmRegressionMatrix)),
                Tab(text: l.t(MessageKey.mmCompareViewer)),
              ],
            ),
          ),
          Expanded(
            child: _multiResult == null
                ? EmptyStateView(
                    title: l.t(MessageKey.mmSelectTwoRuns),
                    explanation: l.t(MessageKey.mmSelectTwoRuns),
                    icon: Icons.leaderboard,
                  )
                : TabBarView(
                    controller: _multiTab,
                    children: [
                      _buildLeaderboardTab(l, _multiResult!),
                      _buildPerClassRankingTab(l, _multiResult!),
                      _buildDisagreementTab(l, _multiResult!),
                      _buildRegressionMatrixTab(l, _multiResult!),
                      _buildMultiCompareViewerTab(l, _multiResult!),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiControls(AppLocalizations l) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text('${l.t(MessageKey.mmModelRuns)}:'),
              const SizedBox(width: 8),
              for (final ModelRunEntry e in widget.modelRunEntries)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(e.modelRun.name),
                    selected: _selectedRunIds.contains(e.modelRun.id),
                    onSelected: (sel) {
                      setState(() {
                        if (sel) {
                          _selectedRunIds.add(e.modelRun.id);
                        } else {
                          _selectedRunIds.remove(e.modelRun.id);
                        }
                      });
                      _computeMulti();
                    },
                  ),
                ),
              const SizedBox(width: 16),
              Text('${l.t(MessageKey.mmRankingMetric)}:'),
              const SizedBox(width: 8),
              DropdownButton<MultiModelRankingMetric>(
                value: _rankingMetric,
                items: [
                  for (final MultiModelRankingMetric m
                      in MultiModelRankingMetric.values)
                    DropdownMenuItem(
                      value: m,
                      child: Text(l.multiModelRankingMetric(m)),
                    ),
                ],
                onChanged: (m) {
                  if (m == null) {
                    return;
                  }
                  setState(() => _rankingMetric = m);
                  _preferences.setString(
                    PreferenceKeys.lastRankingMetric,
                    m.name,
                  );
                  _computeMulti();
                },
              ),
              const SizedBox(width: 16),
              FilterChip(
                label: Text(l.t(MessageKey.mmHideAllCorrect)),
                selected: _hideAllCorrect,
                onSelected: (v) => setState(() => _hideAllCorrect = v),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(l.t(MessageKey.mmIncludeAp)),
                selected: _includeAp,
                onSelected: _hasAnyAp
                    ? (v) {
                        setState(() => _includeAp = v);
                        _computeMulti();
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Leaderboard tab ──

  Widget _buildLeaderboardTab(
    AppLocalizations l,
    MultiModelComparisonResult result,
  ) {
    return Column(
      children: [
        if (_pairSelection.length == 2)
          Padding(
            padding: const EdgeInsets.all(8),
            child: FilledButton.icon(
              icon: const Icon(Icons.compare_arrows),
              label: Text(l.t(MessageKey.mmOpenPairwise)),
              onPressed: _openPairwiseFromSelection,
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 16,
                columns: [
                  DataColumn(label: Text(l.t(MessageKey.mmRank))),
                  DataColumn(label: Text(l.t(MessageKey.mmModel))),
                  const DataColumn(label: Text('AP'), numeric: true),
                  const DataColumn(label: Text('AP50'), numeric: true),
                  const DataColumn(label: Text('P'), numeric: true),
                  const DataColumn(label: Text('R'), numeric: true),
                  const DataColumn(label: Text('F1'), numeric: true),
                  const DataColumn(label: Text('TP'), numeric: true),
                  const DataColumn(label: Text('FP'), numeric: true),
                  const DataColumn(label: Text('FN'), numeric: true),
                  DataColumn(
                    label: Text(l.t(MessageKey.mmImagesWithErrors)),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(l.t(MessageKey.mmSmallRecall)),
                    numeric: true,
                  ),
                ],
                rows: [
                  for (final ModelRunLeaderboardEntry e in result.leaderboard)
                    DataRow(
                      selected: _pairSelection.contains(e.modelRunId),
                      onSelectChanged: (_) => _togglePair(e.modelRunId),
                      cells: [
                        DataCell(Text('${e.rank}')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(e.modelRunName),
                              if (widget.onActivateRun != null)
                                IconButton(
                                  tooltip: l.t(MessageKey.mmMakeActiveModel),
                                  icon: const Icon(Icons.open_in_new, size: 16),
                                  onPressed: () =>
                                      widget.onActivateRun!(e.modelRunId),
                                ),
                            ],
                          ),
                        ),
                        DataCell(_apCell(l, e.ap)),
                        DataCell(_apCell(l, e.ap50)),
                        DataCell(Text(_f(e.precision))),
                        DataCell(Text(_f(e.recall))),
                        DataCell(Text(_f(e.f1))),
                        DataCell(Text('${e.totalTp}')),
                        DataCell(Text('${e.totalFp}')),
                        DataCell(Text('${e.totalFn}')),
                        DataCell(Text('${e.imagesWithErrors}')),
                        DataCell(_apCell(l, e.smallObjectRecall)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _apCell(AppLocalizations l, double? value) {
    if (value == null) {
      return Tooltip(
        message: l.t(MessageKey.mmApNotComputed),
        child: const Text('—'),
      );
    }
    return Text(_f(value));
  }

  // ── Per-class ranking tab ──

  Widget _buildPerClassRankingTab(
    AppLocalizations l,
    MultiModelComparisonResult result,
  ) {
    final String query = _classSearch.toLowerCase();
    final List<ClassModelRanking> rankings = result.perClassRankings
        .where((r) => r.categoryName.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => _spreadFor(b).compareTo(_spreadFor(a)));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    hintText: l.t(MessageKey.mmClassFilter),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _classSearch = v),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<MultiModelRankingMetric>(
                value: _perClassMetric,
                items: [
                  for (final MultiModelRankingMetric m in _kPerClassMetrics)
                    DropdownMenuItem(
                      value: m,
                      child: Text(l.multiModelRankingMetric(m)),
                    ),
                ],
                onChanged: (m) =>
                    setState(() => _perClassMetric = m ?? _perClassMetric),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: rankings.length,
            itemBuilder: (context, index) {
              final ClassModelRanking r = rankings[index];
              return ExpansionTile(
                title: Text(r.categoryName),
                subtitle: Text(
                  '${l.t(MessageKey.mmBestModel)}: '
                  '${_runName(result, r.bestModelRunId)}   '
                  '${l.t(MessageKey.mmWorstModel)}: '
                  '${_runName(result, r.worstModelRunId)}   '
                  '${l.t(MessageKey.mmF1Spread)}: ${_f(r.f1Spread)}',
                ),
                trailing: widget.onOpenCategory == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.filter_alt),
                        tooltip: l.t(MessageKey.mmClassFilter),
                        onPressed: () => widget.onOpenCategory!(r.categoryId),
                      ),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 14,
                      columns: [
                        DataColumn(label: Text(l.t(MessageKey.mmModel))),
                        const DataColumn(label: Text('P'), numeric: true),
                        const DataColumn(label: Text('R'), numeric: true),
                        const DataColumn(label: Text('F1'), numeric: true),
                        const DataColumn(label: Text('TP'), numeric: true),
                        const DataColumn(label: Text('FP'), numeric: true),
                        const DataColumn(label: Text('FN'), numeric: true),
                        const DataColumn(label: Text('AP'), numeric: true),
                        const DataColumn(label: Text('AP50'), numeric: true),
                        const DataColumn(label: Text('AR'), numeric: true),
                      ],
                      rows: [
                        for (final ClassModelMetricEntry e in r.entries)
                          DataRow(
                            cells: [
                              DataCell(Text(e.modelRunName)),
                              DataCell(Text(_f(e.precision))),
                              DataCell(Text(_f(e.recall))),
                              DataCell(Text(_f(e.f1))),
                              DataCell(Text('${e.tp}')),
                              DataCell(Text('${e.fp}')),
                              DataCell(Text('${e.fn}')),
                              DataCell(_apCell(l, e.ap)),
                              DataCell(_apCell(l, e.ap50)),
                              DataCell(_apCell(l, e.ar)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  double _spreadFor(ClassModelRanking r) {
    switch (_perClassMetric) {
      case MultiModelRankingMetric.recall:
        return r.recallSpread;
      case MultiModelRankingMetric.ap:
        return r.apSpread ?? 0;
      case MultiModelRankingMetric.precision:
        return (r.bestPrecision ?? 0) - (r.worstPrecision ?? 0);
      default:
        return r.f1Spread;
    }
  }

  // ── Image disagreement tab ──

  Widget _buildDisagreementTab(
    AppLocalizations l,
    MultiModelComparisonResult result,
  ) {
    final List<ImageModelDisagreement> all = result.imageDisagreements.where(
      (d) {
        if (_hideAllCorrect && d.type == ImageDisagreementType.allCorrect) {
          return false;
        }
        if (_disagreementFilter != null && d.type != _disagreementFilter) {
          return false;
        }
        return true;
      },
    ).toList();
    final List<ImageDisagreementType> filterTypes = const [
      ImageDisagreementType.someModelsWrong,
      ImageDisagreementType.onlyOneModelCorrect,
      ImageDisagreementType.onlyOneModelWrong,
      ImageDisagreementType.allWrong,
      ImageDisagreementType.classDisagreement,
      ImageDisagreementType.largeErrorSpread,
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _disagreementFilter == null,
                  onSelected: (_) => setState(() => _disagreementFilter = null),
                ),
                const SizedBox(width: 6),
                for (final ImageDisagreementType t in filterTypes)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(l.multiModelDisagreementType(t)),
                      selected: _disagreementFilter == t,
                      onSelected: (_) => setState(
                        () => _disagreementFilter =
                            _disagreementFilter == t ? null : t,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: all.length,
            itemBuilder: (context, index) {
              final ImageModelDisagreement d = all[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(d.fileName)),
                      Chip(
                        label: Text(l.multiModelDisagreementType(d.type)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l.t(MessageKey.mmCorrectModels)}: '
                        '${d.modelsCorrectCount}   '
                        '${l.t(MessageKey.mmWrongModels)}: '
                        '${d.modelsWrongCount}   '
                        '${l.t(MessageKey.mmErrorSpread)}: ${d.errorSpread}',
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        children: [
                          for (final ImageModelStatus s in d.modelStatuses)
                            Text(
                              '${s.modelRunName}: '
                              '${s.tp} / ${s.fp} / ${s.fn}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => _openMultiImage(d.imageId),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Regression matrix tab ──

  Widget _buildRegressionMatrixTab(
    AppLocalizations l,
    MultiModelComparisonResult result,
  ) {
    final List<ModelRunLeaderboardEntry> models = result.leaderboard;
    final Map<String, PairwiseRegressionSummary> byPair = {
      for (final p in result.pairwiseRegressionMatrix)
        '${p.baseModelRunId}->${p.candidateModelRunId}': p,
    };
    const List<String> cellModes = [
      'dF1',
      'dAP',
      'fixed-broken',
      'improved-regressed',
      'dFP',
      'dFN',
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Text('Cell:'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _matrixCellMode,
                items: [
                  for (final String mode in cellModes)
                    DropdownMenuItem(value: mode, child: Text(mode)),
                ],
                onChanged: (m) =>
                    setState(() => _matrixCellMode = m ?? _matrixCellMode),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 14,
                columns: [
                  DataColumn(label: Text(l.t(MessageKey.mmModel))),
                  for (final ModelRunLeaderboardEntry c in models)
                    DataColumn(label: Text(c.modelRunName)),
                ],
                rows: [
                  for (final ModelRunLeaderboardEntry base in models)
                    DataRow(
                      cells: [
                        DataCell(Text(base.modelRunName)),
                        for (final ModelRunLeaderboardEntry cand in models)
                          if (base.modelRunId == cand.modelRunId)
                            const DataCell(Text('—'))
                          else
                            _matrixCell(
                              byPair['${base.modelRunId}->${cand.modelRunId}'],
                            ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  DataCell _matrixCell(PairwiseRegressionSummary? p) {
    if (p == null) {
      return const DataCell(Text(''));
    }
    final ({double value, String text}) cell = switch (_matrixCellMode) {
      'dAP' => (
          value: p.deltaAp ?? 0,
          text: p.deltaAp == null ? '-' : _signed(p.deltaAp!),
        ),
      'fixed-broken' => (
          value: (p.fixedImages - p.brokenImages).toDouble(),
          text: '${p.fixedImages - p.brokenImages}',
        ),
      'improved-regressed' => (
          value: (p.improvedImages - p.regressedImages).toDouble(),
          text: '${p.improvedImages - p.regressedImages}',
        ),
      'dFP' => (value: -p.deltaFp.toDouble(), text: _signedInt(p.deltaFp)),
      'dFN' => (value: -p.deltaFn.toDouble(), text: _signedInt(p.deltaFn)),
      _ => (value: p.deltaF1, text: _signed(p.deltaF1)),
    };
    final Color color = cell.value > 0
        ? Colors.green.shade700
        : (cell.value < 0 ? Colors.red.shade700 : Colors.black54);
    return DataCell(
      Text(
        cell.text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      onTap: () =>
          _openPairwiseForPair(p.baseModelRunId, p.candidateModelRunId),
    );
  }

  // ── Multi compare viewer tab ──

  Widget _buildMultiCompareViewerTab(
    AppLocalizations l,
    MultiModelComparisonResult result,
  ) {
    final List<int> imageIds = widget.dataset.imagesById.keys.toList()..sort();
    final int? effectiveId = _multiImageId != null &&
            widget.dataset.imagesById.containsKey(_multiImageId)
        ? _multiImageId
        : (imageIds.isEmpty ? null : imageIds.first);
    final ImageRecord? image =
        effectiveId == null ? null : widget.dataset.imagesById[effectiveId];
    final List<ModelRunEntry> selected = widget.modelRunEntries
        .where((e) => _selectedRunIds.contains(e.modelRun.id))
        .toList();
    final int columns =
        selected.length <= 1 ? 1 : (selected.length <= 4 ? 2 : 3);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text('${l.t(MessageKey.mmImage)}:'),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: effectiveId,
                  items: [
                    for (final int id in imageIds)
                      DropdownMenuItem<int>(
                        value: id,
                        child: Text(
                          widget.dataset.imagesById[id]?.fileName ?? '$id',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) {
                    if (id != null) {
                      _selectMultiImage(id);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              _buildZoomControls(_multiTransform),
            ],
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: columns,
            childAspectRatio: 0.85,
            children: [
              for (final ModelRunEntry e in selected)
                _multiViewerPanel(l, e, image, effectiveId),
            ],
          ),
        ),
      ],
    );
  }

  Widget _multiViewerPanel(
    AppLocalizations l,
    ModelRunEntry entry,
    ImageRecord? image,
    int? imageId,
  ) {
    final List<DetectionMatch> matches = imageId == null
        ? const []
        : entry.evalResult.matches.where((m) => m.imageId == imageId).toList();
    final int tp =
        matches.where((m) => m.type == DetectionMatchType.truePositive).length;
    final int fp =
        matches.where((m) => m.type == DetectionMatchType.falsePositive).length;
    final int fn =
        matches.where((m) => m.type == DetectionMatchType.falseNegative).length;
    return Card(
      margin: const EdgeInsets.all(4),
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Text(
              entry.modelRun.name,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            subtitle: Text('TP $tp / FP $fp / FN $fn'),
            trailing: widget.onActivateRun == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    tooltip: l.t(MessageKey.mmMakeActiveModel),
                    onPressed: () => widget.onActivateRun!(entry.modelRun.id),
                  ),
          ),
          Expanded(
            child: DetectionImageViewer(
              image: image,
              categoriesById: widget.dataset.categoriesById,
              matches: matches,
              imageBytes: _multiImageBytes,
              loadingImage: _loadingMultiImage,
              selectedMatch: null,
              onMatchSelected: (_) {},
              transformationController: _multiTransform,
              scaleEnabled: false,
            ),
          ),
        ],
      ),
    );
  }

  // ── shared viewer panel (pairwise) ──

  Widget _viewerPanel(
    String name,
    ImageRecord? image,
    List<DetectionMatch> matches,
    Uint8List? bytes,
    bool loading,
    TransformationController transformCtrl,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(name, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(
          child: DetectionImageViewer(
            image: image,
            categoriesById: widget.dataset.categoriesById,
            matches: matches,
            imageBytes: bytes,
            loadingImage: loading,
            selectedMatch: null,
            onMatchSelected: (_) {},
            transformationController: transformCtrl,
            scaleEnabled: false,
          ),
        ),
      ],
    );
  }

  // ── actions ──

  void _togglePair(String runId) {
    setState(() {
      if (_pairSelection.contains(runId)) {
        _pairSelection.remove(runId);
      } else {
        if (_pairSelection.length >= 2) {
          _pairSelection.remove(_pairSelection.first);
        }
        _pairSelection.add(runId);
      }
    });
  }

  void _openPairwiseFromSelection() {
    final List<String> ids = _pairSelection.toList();
    if (ids.length != 2) {
      return;
    }
    _openPairwiseForPair(ids[0], ids[1]);
  }

  void _openPairwiseForPair(String baseId, String candidateId) {
    final int baseIdx =
        widget.modelRunEntries.indexWhere((e) => e.modelRun.id == baseId);
    final int candIdx =
        widget.modelRunEntries.indexWhere((e) => e.modelRun.id == candidateId);
    if (baseIdx < 0 || candIdx < 0) {
      return;
    }
    setState(() {
      _mode = _CompareMode.pairwise;
      _baseIndex = baseIdx;
      _candidateIndex = candIdx;
    });
    _computePairwise();
  }

  void _openPairwiseImage(int imageId) {
    _pairwiseTab.animateTo(3);
    _selectPairwiseImage(imageId);
  }

  void _selectPairwiseImage(int imageId) {
    if (_selectedImageId == imageId) {
      return;
    }
    setState(() {
      _selectedImageId = imageId;
      _selectedImageBytes = null;
      _loadingImage = true;
    });
    _loadImage(imageId, pairwise: true);
  }

  void _openMultiImage(int imageId) {
    _multiTab.animateTo(4);
    _selectMultiImage(imageId);
  }

  void _selectMultiImage(int imageId) {
    if (_multiImageId == imageId) {
      return;
    }
    setState(() {
      _multiImageId = imageId;
      _multiImageBytes = null;
      _loadingMultiImage = true;
    });
    _loadImage(imageId, pairwise: false);
  }

  Future<void> _loadImage(int imageId, {required bool pairwise}) async {
    final ImageRecord? image = widget.dataset.imagesById[imageId];
    if (image == null) {
      return;
    }
    final Uint8List? bytes =
        await widget.imageSource.readImageBytes(image.fileName);
    if (!mounted) {
      return;
    }
    if (pairwise) {
      if (_selectedImageId != imageId) {
        return;
      }
      setState(() {
        _selectedImageBytes = bytes;
        _loadingImage = false;
      });
    } else {
      if (_multiImageId != imageId) {
        return;
      }
      setState(() {
        _multiImageBytes = bytes;
        _loadingMultiImage = false;
      });
    }
  }

  // ── export ──

  Future<void> _export() async {
    if (_mode == _CompareMode.pairwise) {
      await _exportPairwise();
    } else {
      await _exportMulti();
    }
  }

  Future<void> _exportPairwise() async {
    final ModelComparisonResult? result = _comparisonResult;
    if (result == null) {
      return;
    }
    setState(() => _exporting = true);
    try {
      final pdfTheme = await loadPdfTheme();
      final ComparisonReportBundle bundle =
          await const ComparisonReportBuilder().build(
        dataset: widget.dataset,
        baseRun: widget.modelRunEntries[_baseIndex].modelRun,
        candidateRun: widget.modelRunEntries[_candidateIndex].modelRun,
        result: result,
        projectName: widget.projectName,
        pdfTheme: pdfTheme,
        locale: AppLocaleScope.l10n(context).locale,
      );
      await _save(
        _ReportBundleAdapter(
          htmlReport: bundle.htmlReport,
          csvFiles: bundle.csvFiles,
          binaryFiles: bundle.binaryFiles,
        ),
      );
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _exportMulti() async {
    final MultiModelComparisonResult? result = _multiResult;
    if (result == null) {
      return;
    }
    setState(() => _exporting = true);
    try {
      final AppLocalizations l = AppLocaleScope.l10n(context);
      final pdfTheme = await loadPdfTheme();
      final MultiModelReportBundle bundle =
          await const MultiModelReportBuilder().build(
        result: result,
        projectName: widget.projectName,
        locale: l.locale,
        pdfTheme: pdfTheme,
      );
      await _save(
        _ReportBundleAdapter(
          htmlReport: bundle.htmlReport,
          csvFiles: bundle.csvFiles,
          binaryFiles: bundle.binaryFiles,
        ),
      );
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _save(ReportBundle bundle) async {
    final ReportSaveResult saveResult = await _reportSaver.save(bundle);
    if (!mounted) {
      return;
    }
    switch (saveResult.status) {
      case ReportSaveStatus.cancelled:
        break;
      case ReportSaveStatus.downloadStarted:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report download started.')),
        );
      case ReportSaveStatus.savedToDirectory:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to: ${saveResult.location}')),
        );
    }
  }

  void _showError(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $error')),
      );
    }
  }

  // ── helpers ──

  String _f(double v) => v.toStringAsFixed(3);
  String _signed(double v) =>
      v >= 0 ? '+${v.toStringAsFixed(3)}' : v.toStringAsFixed(3);
  String _signedInt(int v) => v >= 0 ? '+$v' : '$v';
  String _sign(int value) => value >= 0 ? '+$value' : '$value';

  String _runName(MultiModelComparisonResult result, String? id) {
    if (id == null) {
      return '';
    }
    for (final ModelRunLeaderboardEntry e in result.leaderboard) {
      if (e.modelRunId == id) {
        return e.modelRunName;
      }
    }
    return id;
  }

  String _statusLabel(ImageComparisonStatus status) {
    return switch (status) {
      ImageComparisonStatus.fixed => 'Fixed',
      ImageComparisonStatus.broken => 'Broken',
      ImageComparisonStatus.improved => 'Improved',
      ImageComparisonStatus.regressed => 'Regressed',
      ImageComparisonStatus.unchangedCorrect => 'Unchanged correct',
      ImageComparisonStatus.unchangedWrong => 'Unchanged wrong',
    };
  }

  Color _statusColor(ImageComparisonStatus status) {
    return switch (status) {
      ImageComparisonStatus.fixed => Colors.green,
      ImageComparisonStatus.broken => Colors.red,
      ImageComparisonStatus.improved => Colors.lightGreen,
      ImageComparisonStatus.regressed => Colors.orange,
      ImageComparisonStatus.unchangedCorrect => Colors.blueGrey,
      ImageComparisonStatus.unchangedWrong => Colors.grey,
    };
  }

  IconData _statusIcon(ImageComparisonStatus status) {
    return switch (status) {
      ImageComparisonStatus.fixed => Icons.check_circle,
      ImageComparisonStatus.broken => Icons.cancel,
      ImageComparisonStatus.improved => Icons.trending_up,
      ImageComparisonStatus.regressed => Icons.trending_down,
      ImageComparisonStatus.unchangedCorrect => Icons.check,
      ImageComparisonStatus.unchangedWrong => Icons.warning,
    };
  }
}

/// Adapts a comparison/multi-model bundle to the [ReportBundle] interface the
/// platform saver expects.
class _ReportBundleAdapter extends ReportBundle {
  _ReportBundleAdapter({
    required String htmlReport,
    required Map<String, String> csvFiles,
    required Map<String, List<int>> binaryFiles,
  }) : super(
          projectName: '',
          modelRunName: '',
          generatedAt: DateTime.now(),
          evalConfig: const EvalConfig(),
          htmlReport: htmlReport,
          csvFiles: csvFiles,
          binaryFiles: binaryFiles,
        );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.base,
    required this.candidate,
    required this.higherIsBetter,
    this.delta,
    this.intDelta,
  });

  final String label;
  final String base;
  final String candidate;
  final bool higherIsBetter;
  final double? delta;
  final int? intDelta;

  @override
  Widget build(BuildContext context) {
    final double? d = delta ?? intDelta?.toDouble();
    final bool isGood = d != null && (higherIsBetter ? d > 0 : d < 0);
    final bool isBad = d != null && (higherIsBetter ? d < 0 : d > 0);
    final Color deltaColor = isGood
        ? Colors.green.shade700
        : (isBad ? Colors.red.shade700 : Colors.black87);
    final String deltaText = d == null
        ? ''
        : (d >= 0
            ? '+${intDelta ?? d.toStringAsFixed(3)}'
            : '${intDelta ?? d.toStringAsFixed(3)}');
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text('Base: $base', style: Theme.of(context).textTheme.bodySmall),
              Text(
                'Cand: $candidate',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                deltaText,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: deltaColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusSummaryRow extends StatelessWidget {
  const _StatusSummaryRow({required this.result});

  final ModelComparisonResult result;

  @override
  Widget build(BuildContext context) {
    final List<(String, int, Color)> items = [
      ('Fixed', result.fixedImageIds.length, Colors.green),
      ('Broken', result.brokenImageIds.length, Colors.red),
      ('Improved', result.improvedImageIds.length, Colors.lightGreen),
      ('Regressed', result.regressedImageIds.length, Colors.orange),
      (
        'Unchanged correct',
        result.unchangedCorrectImageIds.length,
        Colors.blueGrey
      ),
      ('Unchanged wrong', result.unchangedWrongImageIds.length, Colors.grey),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final (label, count, color) in items)
          Chip(
            label: Text('$label: $count'),
            backgroundColor: color.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: color.withValues(alpha: 1),
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _PerClassTable extends StatefulWidget {
  const _PerClassTable({
    required this.diffs,
    required this.baseName,
    required this.candidateName,
  });

  final List<ClassMetricsDiff> diffs;
  final String baseName;
  final String candidateName;

  @override
  State<_PerClassTable> createState() => _PerClassTableState();
}

class _PerClassTableState extends State<_PerClassTable> {
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final List<ClassMetricsDiff> filtered = switch (_filter) {
      'improved' => widget.diffs.where((d) => d.diff.deltaF1 > 0).toList(),
      'regressed' => widget.diffs.where((d) => d.diff.deltaF1 < 0).toList(),
      _ => widget.diffs,
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Improved'),
                selected: _filter == 'improved',
                onSelected: (_) => setState(
                  () => _filter = _filter == 'improved' ? null : 'improved',
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Regressed'),
                selected: _filter == 'regressed',
                onSelected: (_) => setState(
                  () => _filter = _filter == 'regressed' ? null : 'regressed',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 12,
                columns: const [
                  DataColumn(label: Text('Class')),
                  DataColumn(label: Text('Base P'), numeric: true),
                  DataColumn(label: Text('Cand P'), numeric: true),
                  DataColumn(label: Text('ΔP'), numeric: true),
                  DataColumn(label: Text('Base R'), numeric: true),
                  DataColumn(label: Text('Cand R'), numeric: true),
                  DataColumn(label: Text('ΔR'), numeric: true),
                  DataColumn(label: Text('Base F1'), numeric: true),
                  DataColumn(label: Text('Cand F1'), numeric: true),
                  DataColumn(label: Text('ΔF1'), numeric: true),
                  DataColumn(label: Text('ΔTP'), numeric: true),
                  DataColumn(label: Text('ΔFP'), numeric: true),
                  DataColumn(label: Text('ΔFN'), numeric: true),
                ],
                rows: filtered.map((ClassMetricsDiff d) {
                  final MetricsDiff diff = d.diff;
                  return DataRow(
                    cells: [
                      DataCell(Text(d.categoryName)),
                      DataCell(Text(diff.basePrecision.toStringAsFixed(3))),
                      DataCell(
                        Text(diff.candidatePrecision.toStringAsFixed(3)),
                      ),
                      DataCell(_deltaText(diff.deltaPrecision, true)),
                      DataCell(Text(diff.baseRecall.toStringAsFixed(3))),
                      DataCell(Text(diff.candidateRecall.toStringAsFixed(3))),
                      DataCell(_deltaText(diff.deltaRecall, true)),
                      DataCell(Text(diff.baseF1.toStringAsFixed(3))),
                      DataCell(Text(diff.candidateF1.toStringAsFixed(3))),
                      DataCell(_deltaText(diff.deltaF1, true)),
                      DataCell(_intDeltaText(diff.deltaTp, true)),
                      DataCell(_intDeltaText(diff.deltaFp, false)),
                      DataCell(_intDeltaText(diff.deltaFn, false)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _deltaText(double delta, bool higherIsBetter) {
    final bool isGood = higherIsBetter ? delta > 0 : delta < 0;
    final bool isBad = higherIsBetter ? delta < 0 : delta > 0;
    final Color color = isGood
        ? Colors.green.shade700
        : (isBad ? Colors.red.shade700 : Colors.black87);
    final String text =
        delta >= 0 ? '+${delta.toStringAsFixed(3)}' : delta.toStringAsFixed(3);
    return Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }

  Widget _intDeltaText(int delta, bool higherIsBetter) {
    final bool isGood = higherIsBetter ? delta > 0 : delta < 0;
    final bool isBad = higherIsBetter ? delta < 0 : delta > 0;
    final Color color = isGood
        ? Colors.green.shade700
        : (isBad ? Colors.red.shade700 : Colors.black87);
    final String text = delta >= 0 ? '+$delta' : '$delta';
    return Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}
