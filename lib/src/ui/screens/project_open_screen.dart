import 'dart:convert';
import 'dart:typed_data';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import '../../platform_io/file_pick_result.dart';
import '../../platform_io/image_source.dart';
import '../../platform_io/platform_file_picker.dart';
import '../../platform_io/project_file_io.dart';
import '../../platform_io/project_loader.dart';
import 'workspace_screen.dart';

class ProjectOpenScreen extends StatefulWidget {
  const ProjectOpenScreen({super.key});

  @override
  State<ProjectOpenScreen> createState() => _ProjectOpenScreenState();
}

class _ProjectOpenScreenState extends State<ProjectOpenScreen> {
  final TextEditingController _modelName =
      TextEditingController(text: 'Model run');
  final PlatformFilePicker _filePicker = createPlatformFilePicker();

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
  String? _error;

  bool get _inRestoreMode => _pendingProject != null;

  bool get _canLoadFromManifest {
    if (_pendingProject == null || _pendingAnnotations == null) return false;
    return _pendingProject!.modelRuns.asMap().entries.every(
          (entry) => _pendingPredFiles[entry.key] != null,
        );
  }

  @override
  void dispose() {
    _modelName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CV Model Lab'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _inRestoreMode
                ? _buildRestoreMode(context)
                : _buildNormalMode(context),
          ),
        ),
      ),
    );
  }

  // ── Normal mode ───────────────────────────────────────────────────────────

  Widget _buildNormalMode(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Open Dataset',
          style: Theme.of(context).textTheme.headlineMedium,
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
              onPressed: _loading ? null : _openDemo,
              icon: const Icon(Icons.science),
              label: const Text('Open demo project'),
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
          _MessageBox(message: _error!, isError: true),
        ],
        if (_loadResult?.preflightSummary != null) ...[
          const SizedBox(height: 16),
          _PreflightSummaryCard(summary: _loadResult!.preflightSummary!),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: _loadResult == null || _loadResult!.issues.isEmpty
              ? const _EmptyHint()
              : _IssueList(issues: _loadResult!.issues),
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
          _MessageBox(message: _error!, isError: true),
        ],
        const Spacer(),
      ],
    );
  }

  // ── Pickers — normal mode ─────────────────────────────────────────────────

  Future<void> _pickAnnotations() async {
    final PickedDataFile? file = await _safePick(
      _filePicker.pickAnnotationsJson,
    );
    if (file == null || !mounted) {
      return;
    }
    setState(() {
      _annotationsFile = file;
      _loadResult = null;
    });
  }

  Future<void> _pickPredictions() async {
    final PickedDataFile? file = await _safePick(
      _filePicker.pickPredictionsJson,
    );
    if (file == null || !mounted) {
      return;
    }
    setState(() {
      _predictionsFile = file;
      _loadResult = null;
    });
  }

  Future<void> _pickImages() async {
    final ImageSource? source = await _safePick(_filePicker.pickImages);
    if (source == null || !mounted) {
      return;
    }
    setState(() {
      _imageSource = source;
      _loadResult = null;
      _imagesRootPath = _extractRootPath(source);
    });
  }

  // ── Pickers — restore mode ────────────────────────────────────────────────

  Future<void> _pickPendingAnnotations() async {
    final PickedDataFile? file = await _safePick(
      _filePicker.pickAnnotationsJson,
    );
    if (file == null || !mounted) {
      return;
    }
    setState(() => _pendingAnnotations = file);
  }

  Future<void> _pickPendingImages() async {
    final ImageSource? source = await _safePick(_filePicker.pickImages);
    if (source == null || !mounted) {
      return;
    }
    setState(() {
      _pendingImageSource = source;
      _pendingImagesRootPath = _extractRootPath(source);
    });
  }

  Future<void> _pickPendingPredictions(int runIndex) async {
    final PickedDataFile? file = await _safePick(
      _filePicker.pickPredictionsJson,
    );
    if (file == null || !mounted) {
      return;
    }
    setState(() {
      _pendingPredFiles = List<PickedDataFile?>.of(_pendingPredFiles)
        ..[runIndex] = file;
    });
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
    });
    await Future<void>.delayed(Duration.zero);

    try {
      final List<ModelRunEntry> entries = [];
      final List<ParseIssue> allIssues = [];
      final Map<String, ApEvalResult> apEvalResults = {};
      CocoDataset? dataset;

      for (int i = 0; i < project.modelRuns.length; i++) {
        final PickedDataFile? predFile = _pendingPredFiles[i];
        if (predFile == null) continue;
        final ProjectModelRunSource runSource = project.modelRuns[i];

        final ProjectLoadResult result = const ProjectLoader().load(
          annotationsFile: annotationsFile,
          predictionsFile: predFile,
          imageSource: imageSource,
          projectName: project.name,
          modelRunName: runSource.name,
          config: evalConfig,
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
          () => _error =
              'Could not load any model runs. Check the selected files.',
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
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'Failed to load project: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Future<T?> _safePick<T>(Future<T?> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
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
        _error = 'Select annotations.json and predictions.json first.';
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

  void _openDemo() {
    _loadProject(
      annotationsFile:
          _memoryJsonFile('annotations.json', _demoAnnotationsJson),
      predictionsFile:
          _memoryJsonFile('predictions.json', _demoPredictionsJson),
      imageSource: const EmptyImageSource(),
      projectName: 'Mini COCO demo',
    );
  }

  Future<void> _openSavedProject() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ProjectFileIo io = createProjectFileIo();

      final PickedDataFile? projectFile = await io.openProject();
      if (projectFile == null || !mounted) return;

      final CvmlProject project;
      try {
        project = const ProjectSerializer().fromJsonString(
          projectFile.readAsString(),
        );
      } on ProjectSerializationException catch (e) {
        setState(() => _error = 'Invalid project file: ${e.message}');
        return;
      }

      // Try to auto-load all referenced files from saved paths (desktop only).
      // readFileAtPath returns null on web or when the file is missing.
      final String? annotationsPath = project.datasetSource.annotationsPath;
      if (annotationsPath != null) {
        final PickedDataFile? annotationsFile =
            await io.readFileAtPath(annotationsPath);
        if (!mounted) return;

        if (annotationsFile != null) {
          // Attempt to load all model runs from their saved paths.
          ImageSource imageSource = const EmptyImageSource();
          final String? imagesRootPath = project.datasetSource.imagesRootPath;
          if (imagesRootPath != null) {
            imageSource =
                await io.openImageSourceAtPath(imagesRootPath) ?? imageSource;
          }

          final List<ModelRunEntry> entries = [];
          final List<ParseIssue> allIssues = [];
          CocoDataset? dataset;
          bool anyMissing = false;

          for (final ProjectModelRunSource runSource in project.modelRuns) {
            final String? predPath = runSource.predictionsPath;
            if (predPath == null) {
              anyMissing = true;
              break;
            }
            final PickedDataFile? predFile = await io.readFileAtPath(predPath);
            if (!mounted) return;
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
            }
          }

          if (!mounted) return;

          // All files found and at least one run loaded → open workspace.
          if (!anyMissing && entries.isNotEmpty) {
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
                  projectFilePath: projectFile.path,
                  annotationsPath: annotationsPath,
                  imagesRootPath: imagesRootPath,
                  initialActiveRunIndex: initialActiveIndex,
                ),
              ),
            );
            return;
          }
          // Some files missing → fall through to restore mode.
        }
        // annotationsFile == null → fall through to restore mode.
      }
      // annotationsPath == null (web manifest) → fall through to restore mode.

      if (!mounted) return;
      _enterRestoreMode(project);
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'Failed to open project: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadProject({
    required PickedDataFile annotationsFile,
    required PickedDataFile predictionsFile,
    required ImageSource imageSource,
    required String projectName,
  }) {
    final ProjectLoadResult result = const ProjectLoader().load(
      annotationsFile: annotationsFile,
      predictionsFile: predictionsFile,
      imageSource: imageSource,
      projectName: projectName,
      modelRunName: _modelName.text,
    );
    setState(() {
      _loadResult = result;
      _error = result.canOpen
          ? null
          : 'Could not load project. Review errors below.';
    });
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
}

PickedDataFile _memoryJsonFile(String name, String json) {
  return PickedDataFile(
    name: name,
    bytes: Uint8List.fromList(utf8.encode(json)),
  );
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
    return Center(
      child: Text(
        'Select JSON files and images, then run Analyze.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final Color color = isError ? Colors.red.shade700 : Colors.amber.shade800;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, style: TextStyle(color: color)),
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
          title: Text(issue.message),
          subtitle: issue.path == null ? null : Text(issue.path!),
        );
      },
    );
  }
}

const String _demoAnnotationsJson = '''
{
  "images": [
    {"id": 1, "file_name": "image_001.jpg", "width": 200, "height": 200},
    {"id": 2, "file_name": "image_002.jpg", "width": 200, "height": 200},
    {"id": 3, "file_name": "image_003.jpg", "width": 200, "height": 200},
    {"id": 4, "file_name": "image_004.jpg", "width": 200, "height": 200},
    {"id": 5, "file_name": "nested/image_005.jpg", "width": 200, "height": 200}
  ],
  "annotations": [
    {"id": 101, "image_id": 1, "category_id": 1, "bbox": [10, 10, 100, 100], "area": 10000, "iscrowd": 0},
    {"id": 102, "image_id": 2, "category_id": 2, "bbox": [50, 50, 30, 30], "area": 900, "iscrowd": 0},
    {"id": 103, "image_id": 4, "category_id": 3, "bbox": [100, 100, 80, 80], "area": 6400, "iscrowd": 0},
    {"id": 104, "image_id": 5, "category_id": 1, "bbox": [0, 0, 100, 100], "area": 10000, "iscrowd": 0},
    {"id": 105, "image_id": 5, "category_id": 3, "bbox": [150, 150, 10, 10], "area": 100, "iscrowd": 0}
  ],
  "categories": [
    {"id": 1, "name": "red"},
    {"id": 2, "name": "yellow"},
    {"id": 3, "name": "green"}
  ]
}
''';

const String _demoPredictionsJson = '''
[
  {"image_id": 1, "category_id": 1, "bbox": [10, 10, 100, 100], "score": 0.9},
  {"image_id": 3, "category_id": 3, "bbox": [20, 20, 50, 50], "score": 0.8},
  {"image_id": 4, "category_id": 1, "bbox": [100, 100, 80, 80], "score": 0.95},
  {"file_name": "image_005.jpg", "category_id": 1, "bbox": [0, 0, 100, 100], "score": 0.9},
  {"image_id": 5, "category_id": 1, "bbox": [1, 1, 100, 100], "score": 0.8},
  {"image_id": 5, "category_id": 3, "bbox": [150, 150, 10, 10], "score": 0.1}
]
''';
