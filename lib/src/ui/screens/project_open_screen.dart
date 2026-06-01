import 'dart:convert';
import 'dart:typed_data';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import '../../platform_io/file_pick_result.dart';
import '../../platform_io/image_source.dart';
import '../../platform_io/platform_file_picker.dart';
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

  PickedDataFile? _annotationsFile;
  PickedDataFile? _predictionsFile;
  ImageSource? _imageSource;
  ProjectLoadResult? _loadResult;
  bool _loading = false;
  String? _error;

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
            child: Column(
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
                  icon: Icons.fact_check_outlined,
                  onPick: _loading ? null : _pickAnnotations,
                ),
                const SizedBox(height: 12),
                _PickedFileRow(
                  label: 'predictions.json',
                  value: _predictionsFile?.name,
                  icon: Icons.model_training_outlined,
                  onPick: _loading ? null : _pickPredictions,
                ),
                const SizedBox(height: 12),
                _PickedFileRow(
                  label: 'images directory / files',
                  value: _imageSource == null ? null : 'Selected',
                  icon: Icons.image_outlined,
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
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('Analyze'),
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
                  _PreflightSummaryCard(
                    summary: _loadResult!.preflightSummary!,
                  ),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: _loadResult == null || _loadResult!.issues.isEmpty
                      ? const _EmptyHint()
                      : _IssueList(issues: _loadResult!.issues),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAnnotations() async {
    await _runPicker(() async {
      final PickedDataFile? file = await _filePicker.pickAnnotationsJson();
      if (file != null) {
        setState(() {
          _annotationsFile = file;
          _loadResult = null;
        });
      }
    });
  }

  Future<void> _pickPredictions() async {
    await _runPicker(() async {
      final PickedDataFile? file = await _filePicker.pickPredictionsJson();
      if (file != null) {
        setState(() {
          _predictionsFile = file;
          _loadResult = null;
        });
      }
    });
  }

  Future<void> _pickImages() async {
    await _runPicker(() async {
      final ImageSource? source = await _filePicker.pickImages();
      if (source != null) {
        setState(() {
          _imageSource = source;
          _loadResult = null;
        });
      }
    });
  }

  Future<void> _runPicker(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

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
    if (result == null || !result.canOpen) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkspaceScreen(
          projectName: result.projectName,
          dataset: result.dataset!,
          modelRun: result.modelRun!,
          imageSource: result.imageSource!,
          initialEvalResult: result.evalResult!,
          issues: result.issues,
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
  const _MessageBox({
    required this.message,
    required this.isError,
  });

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
                ? Icons.error_outline
                : Icons.warning_amber,
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
