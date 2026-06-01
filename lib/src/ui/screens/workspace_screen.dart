import 'dart:typed_data';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import '../../platform_io/image_source.dart';
import '../../platform_io/report_saver.dart';
import '../widgets/dashboard_panel.dart';
import '../widgets/detection_image_viewer.dart';
import '../widgets/export_report_dialog.dart';
import '../widgets/image_browser_panel.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    required this.projectName,
    required this.dataset,
    required this.modelRun,
    required this.imageSource,
    required this.initialEvalResult,
    required this.issues,
    super.key,
  });

  final String projectName;
  final CocoDataset dataset;
  final ModelRun modelRun;
  final ImageSource imageSource;
  final EvalResult initialEvalResult;
  final List<ParseIssue> issues;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  static const EvalConfig _defaultEvalConfig = EvalConfig();
  static const EvalViewFilter _defaultViewFilter = EvalViewFilter();

  EvalConfig _evalConfig = _defaultEvalConfig;
  EvalViewFilter _viewFilter = _defaultViewFilter;
  int? _selectedImageId;
  DetectionMatch? _selectedMatch;
  Uint8List? _selectedImageBytes;
  bool _loadingImage = false;
  bool _evaluating = false;
  bool _exporting = false;
  int _evaluationRequestId = 0;

  final ReportSaver _reportSaver = createReportSaver();

  late EvalResult _evalResult;
  late Set<String> _missingImageFileNames;

  // Memoized filtered view. Recomputing it is O(matches); doing so on every
  // rebuild (e.g. when image bytes finish loading) janks the UI, especially on
  // web where there is no background isolate. Cache it against the only mutable
  // inputs the filter depends on.
  FilteredEvalView? _cachedView;
  EvalResult? _cachedViewResult;
  EvalViewFilter? _cachedViewFilter;

  @override
  void initState() {
    super.initState();
    _evalResult = widget.initialEvalResult;
    _missingImageFileNames = widget.imageSource.missingImages().toSet();
    _selectedImageId = widget.dataset.imagesById.keys.isEmpty
        ? null
        : (widget.dataset.imagesById.keys.toList()..sort()).first;
    _loadSelectedImage();
  }

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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text(widget.modelRun.name)),
          ),
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
        ],
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
                    SizedBox(
                      width: 340,
                      child: ImageBrowserPanel(
                        dataset: widget.dataset,
                        view: filteredView,
                        filter: _viewFilter,
                        selectedImageId: effectiveImageId,
                        onFilterChanged: _updateViewFilter,
                        onResetFilters: () =>
                            _updateViewFilter(_defaultViewFilter),
                        onImageSelected: _selectImage,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: DetectionImageViewer(
                        image: selectedImage,
                        categoriesById: widget.dataset.categoriesById,
                        matches: selectedMatches,
                        imageBytes: _selectedImageBytes,
                        loadingImage: _loadingImage,
                        selectedMatch: _selectedMatch,
                        onMatchSelected: (DetectionMatch? match) {
                          setState(() {
                            _selectedMatch = match;
                          });
                        },
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 360,
                      child: DashboardPanel(
                        dataset: widget.dataset,
                        evalResult: _evalResult,
                        selectedImage: selectedImage,
                        selectedMatches: selectedMatches,
                        selectedMatch: _selectedMatch,
                        issues: widget.issues,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_evaluating) const _EvaluationOverlay(),
        ],
      ),
    );
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
      modelRun: widget.modelRun,
      evalResult: result,
      missingImageFileNames: _missingImageFileNames,
      filter: filter,
    );
    _cachedView = view;
    _cachedViewResult = result;
    _cachedViewFilter = filter;
    return view;
  }

  int? _effectiveSelectedImageId(FilteredEvalView view) {
    if (_selectedImageId != null &&
        view.filteredImageIds.contains(_selectedImageId)) {
      return _selectedImageId;
    }
    return view.filteredImageIds.isEmpty ? null : view.filteredImageIds.first;
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

  Future<void> _reevaluate(EvalConfig config) async {
    final int requestId = ++_evaluationRequestId;
    setState(() {
      _evalConfig = config;
      _evaluating = true;
      _selectedMatch = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 50));
    final EvalResult result = const MetricsCalculator().evaluate(
      dataset: widget.dataset,
      modelRun: widget.modelRun,
      config: config,
    );
    if (!mounted || requestId != _evaluationRequestId) {
      return;
    }

    final FilteredEvalView nextView = _filteredViewFor(result, _viewFilter);
    final int? nextImageId = _selectedImageId != null &&
            nextView.filteredImageIds.contains(_selectedImageId)
        ? _selectedImageId
        : (nextView.filteredImageIds.isEmpty
            ? null
            : nextView.filteredImageIds.first);

    setState(() {
      _evalResult = result;
      _evaluating = false;
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
      ),
    );
    if (request == null || !mounted) {
      return;
    }
    await _exportReport(request);
  }

  Future<void> _exportReport(ExportReportRequest request) async {
    setState(() => _exporting = true);
    // Yield a frame so the progress indicator paints before the (synchronous)
    // bundle build runs.
    await Future<void>.delayed(Duration.zero);
    try {
      final ReportBundle bundle = const ReportBundleBuilder().build(
        dataset: widget.dataset,
        modelRun: widget.modelRun,
        evalConfig: _evalConfig,
        evalResult: _evalResult,
        components: request.components,
        activeFilter: _viewFilter,
        filteredView: _buildFilteredView(),
        scope: request.scope,
        projectName: widget.projectName,
        modelRunName: widget.modelRun.name,
        missingImageFileNames: _missingImageFileNames,
      );
      final ReportSaveResult result = await _reportSaver.save(bundle);
      if (!mounted) {
        return;
      }
      _showExportResult(result);
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
              icon: const Icon(Icons.restart_alt),
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
