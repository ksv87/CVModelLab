import 'dart:typed_data';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import '../../platform_io/image_source.dart';
import '../../platform_io/report_saver.dart';
import '../widgets/detection_image_viewer.dart';
import 'workspace_screen.dart';

class ModelCompareScreen extends StatefulWidget {
  const ModelCompareScreen({
    required this.dataset,
    required this.modelRunEntries,
    required this.imageSource,
    required this.evalConfig,
    required this.projectName,
    this.apEvalResults = const {},
    super.key,
  });

  final CocoDataset dataset;
  final List<ModelRunEntry> modelRunEntries;
  final ImageSource imageSource;
  final EvalConfig evalConfig;
  final String projectName;
  final Map<String, ApEvalResult> apEvalResults;

  @override
  State<ModelCompareScreen> createState() => _ModelCompareScreenState();
}

class _ModelCompareScreenState extends State<ModelCompareScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _baseIndex = 0;
  int _candidateIndex = 1;
  ModelComparisonResult? _comparisonResult;
  ImageComparisonStatus? _imageFilter;
  int? _selectedImageId;
  Uint8List? _selectedImageBytes;
  bool _loadingImage = false;
  bool _exporting = false;

  final ReportSaver _reportSaver = createReportSaver();

  static const List<String> _tabLabels = [
    'Overview',
    'Per Class',
    'Images',
    'Compare Viewer',
    'AP Diff',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _compute();
  }

  ApEvalResult? get _baseApEval =>
      widget.apEvalResults[widget.modelRunEntries[_baseIndex].modelRun.id];
  ApEvalResult? get _candidateApEval =>
      widget.apEvalResults[widget.modelRunEntries[_candidateIndex].modelRun.id];

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _compute() {
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
    setState(() {
      _comparisonResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Compare — ${widget.projectName}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabLabels.map((t) => Tab(text: t)).toList(),
        ),
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
              onPressed: _comparisonResult == null ? null : _exportComparison,
              icon: const Icon(Icons.download),
              label: const Text('Export'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildModelSelector(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
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

  Widget _buildModelSelector() {
    final List<DropdownMenuItem<int>> items = [
      for (int i = 0; i < widget.modelRunEntries.length; i++)
        DropdownMenuItem<int>(
          value: i,
          child: Text(widget.modelRunEntries[i].modelRun.name),
        ),
    ];

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                if (v == _candidateIndex) {
                  setState(() {
                    _baseIndex = v;
                    _candidateIndex = _baseIndex == 0 ? 1 : 0;
                  });
                } else {
                  setState(() => _baseIndex = v);
                }
                _compute();
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
                if (v == _baseIndex) {
                  setState(() {
                    _candidateIndex = v;
                    _baseIndex = _candidateIndex == 0 ? 1 : 0;
                  });
                } else {
                  setState(() => _candidateIndex = v);
                }
                _compute();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---- Overview Tab ----

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

  // ---- Per Class Tab ----

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

  // ---- Images Tab ----

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
                onTap: () => _openInCompareViewer(s.imageId),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---- Compare Viewer Tab ----

  Widget _buildCompareViewerTab() {
    final ModelComparisonResult? result = _comparisonResult;
    if (result == null) {
      return const Center(child: CircularProgressIndicator());
    }

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
        // Image selector.
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
                      _selectCompareImage(id);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        // Side-by-side viewers.
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        baseEntry.modelRun.name,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    Expanded(
                      child: DetectionImageViewer(
                        image: selectedImage,
                        categoriesById: widget.dataset.categoriesById,
                        matches: baseMatches,
                        imageBytes: _selectedImageBytes,
                        loadingImage: _loadingImage,
                        selectedMatch: null,
                        onMatchSelected: (_) {},
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        candidateEntry.modelRun.name,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    Expanded(
                      child: DetectionImageViewer(
                        image: selectedImage,
                        categoriesById: widget.dataset.categoriesById,
                        matches: candidateMatches,
                        imageBytes: _selectedImageBytes,
                        loadingImage: _loadingImage,
                        selectedMatch: null,
                        onMatchSelected: (_) {},
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- AP Diff Tab ----

  Widget _buildApDiffTab() {
    final ApEvalResult? baseAp = _baseApEval;
    final ApEvalResult? candidateAp = _candidateApEval;
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
    if (baseAp == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'AP metrics available for $candidateName only.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (candidateAp == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'AP metrics available for $baseName only.',
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

    Color deltaColor(double? b, double? c) {
      if (b == null || c == null) {
        return Colors.black87;
      }
      final double d = c - b;
      if (d > 0) return Colors.green.shade700;
      if (d < 0) return Colors.red.shade700;
      return Colors.black87;
    }

    final List<({String metric, double? base, double? candidate})> rows = [
      (metric: 'AP@[.5:.95]', base: baseAp.ap, candidate: candidateAp.ap),
      (metric: 'AP50', base: baseAp.ap50, candidate: candidateAp.ap50),
      (metric: 'AP75', base: baseAp.ap75, candidate: candidateAp.ap75),
      (metric: 'APsmall', base: baseAp.apSmall, candidate: candidateAp.apSmall),
      (metric: 'APmedium', base: baseAp.apMedium, candidate: candidateAp.apMedium),
      (metric: 'APlarge', base: baseAp.apLarge, candidate: candidateAp.apLarge),
      (metric: 'AR1', base: baseAp.ar1, candidate: candidateAp.ar1),
      (metric: 'AR10', base: baseAp.ar10, candidate: candidateAp.ar10),
      (metric: 'AR100', base: baseAp.ar100, candidate: candidateAp.ar100),
      (metric: 'ARsmall', base: baseAp.arSmall, candidate: candidateAp.arSmall),
      (metric: 'ARmedium', base: baseAp.arMedium, candidate: candidateAp.arMedium),
      (metric: 'ARlarge', base: baseAp.arLarge, candidate: candidateAp.arLarge),
    ];

    final hasPerClass =
        baseAp.perClass.isNotEmpty && candidateAp.perClass.isNotEmpty;
    final Map<int, ClassApMetric> baseMap = {
      for (final c in baseAp.perClass) c.categoryId: c,
    };
    final Map<int, ClassApMetric> candidateMap = {
      for (final c in candidateAp.perClass) c.categoryId: c,
    };
    final Set<int> allCatIds = {...baseMap.keys, ...candidateMap.keys};

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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
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
                      DataCell(
                        Text(
                          delta(row.base, row.candidate),
                          style: TextStyle(
                            color: deltaColor(row.base, row.candidate),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (hasPerClass) ...[
            const SizedBox(height: 24),
            Text(
              'Per-class AP diff',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('Class')),
                  const DataColumn(label: Text('AP base')),
                  const DataColumn(label: Text('AP cand')),
                  const DataColumn(label: Text('dAP')),
                  const DataColumn(label: Text('AP50 base')),
                  const DataColumn(label: Text('AP50 cand')),
                  const DataColumn(label: Text('dAP50')),
                ],
                rows: [
                  for (final int catId in allCatIds.toList()..sort())
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            baseMap[catId]?.categoryName ??
                                candidateMap[catId]?.categoryName ??
                                '$catId',
                          ),
                        ),
                        DataCell(Text(fmt(baseMap[catId]?.ap))),
                        DataCell(Text(fmt(candidateMap[catId]?.ap))),
                        DataCell(
                          Text(
                            delta(baseMap[catId]?.ap, candidateMap[catId]?.ap),
                            style: TextStyle(
                              color: deltaColor(
                                baseMap[catId]?.ap,
                                candidateMap[catId]?.ap,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(Text(fmt(baseMap[catId]?.ap50))),
                        DataCell(Text(fmt(candidateMap[catId]?.ap50))),
                        DataCell(
                          Text(
                            delta(
                              baseMap[catId]?.ap50,
                              candidateMap[catId]?.ap50,
                            ),
                            style: TextStyle(
                              color: deltaColor(
                                baseMap[catId]?.ap50,
                                candidateMap[catId]?.ap50,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openInCompareViewer(int imageId) {
    _tabController.animateTo(3);
    _selectCompareImage(imageId);
  }

  void _selectCompareImage(int imageId) {
    if (_selectedImageId == imageId) {
      return;
    }
    setState(() {
      _selectedImageId = imageId;
      _selectedImageBytes = null;
      _loadingImage = false;
    });
    _loadCompareImage(imageId);
  }

  Future<void> _loadCompareImage(int imageId) async {
    final ImageRecord? image = widget.dataset.imagesById[imageId];
    if (image == null) {
      return;
    }
    setState(() => _loadingImage = true);
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

  Future<void> _exportComparison() async {
    final ModelComparisonResult? result = _comparisonResult;
    if (result == null) {
      return;
    }
    setState(() => _exporting = true);
    await Future<void>.delayed(Duration.zero);
    try {
      final ComparisonReportBundle bundle =
          const ComparisonReportBuilder().build(
        dataset: widget.dataset,
        baseRun: widget.modelRunEntries[_baseIndex].modelRun,
        candidateRun: widget.modelRunEntries[_candidateIndex].modelRun,
        result: result,
        projectName: widget.projectName,
      );

      // Wrap in ReportBundle for the saver.
      final _ComparisonReportBundleAdapter adapted =
          _ComparisonReportBundleAdapter(bundle);
      final ReportSaveResult saveResult = await _reportSaver.save(adapted);
      if (!mounted) {
        return;
      }
      switch (saveResult.status) {
        case ReportSaveStatus.cancelled:
          break;
        case ReportSaveStatus.downloadStarted:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comparison report download started.'),
            ),
          );
        case ReportSaveStatus.savedToDirectory:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Saved to: ${saveResult.location}',
              ),
            ),
          );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  // ---- Helpers ----

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

  String _sign(int value) => value >= 0 ? '+$value' : '$value';
}

// Adapter wrapping ComparisonReportBundle to satisfy ReportBundle's interface.
class _ComparisonReportBundleAdapter extends ReportBundle {
  _ComparisonReportBundleAdapter(ComparisonReportBundle bundle)
      : super(
          projectName: '',
          modelRunName: '',
          generatedAt: DateTime.now(),
          evalConfig: const EvalConfig(),
          htmlReport: bundle.htmlReport,
          csvFiles: bundle.csvFiles,
          binaryFiles: const <String, List<int>>{},
        );
}

// ---- Reusable widgets ----

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
            ? '+${intDelta != null ? intDelta : d.toStringAsFixed(3)}'
            : '${intDelta != null ? intDelta : d.toStringAsFixed(3)}');

    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Base: $base',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
  String? _filter; // null = all, 'improved', 'regressed'

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
                      DataCell(
                        _deltaText(diff.deltaPrecision, higherIsBetter: true),
                      ),
                      DataCell(Text(diff.baseRecall.toStringAsFixed(3))),
                      DataCell(Text(diff.candidateRecall.toStringAsFixed(3))),
                      DataCell(
                        _deltaText(diff.deltaRecall, higherIsBetter: true),
                      ),
                      DataCell(Text(diff.baseF1.toStringAsFixed(3))),
                      DataCell(Text(diff.candidateF1.toStringAsFixed(3))),
                      DataCell(
                        _deltaText(diff.deltaF1, higherIsBetter: true),
                      ),
                      DataCell(
                        _intDeltaText(diff.deltaTp, higherIsBetter: true),
                      ),
                      DataCell(
                        _intDeltaText(diff.deltaFp, higherIsBetter: false),
                      ),
                      DataCell(
                        _intDeltaText(diff.deltaFn, higherIsBetter: false),
                      ),
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

  Widget _deltaText(double delta, {required bool higherIsBetter}) {
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

  Widget _intDeltaText(int delta, {required bool higherIsBetter}) {
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
