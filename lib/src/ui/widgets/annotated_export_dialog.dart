import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

class AnnotatedExportDialog extends StatefulWidget {
  const AnnotatedExportDialog({
    required this.currentImageAvailable,
    required this.filteredImagesAvailable,
    super.key,
  });

  final bool currentImageAvailable;
  final bool filteredImagesAvailable;

  @override
  State<AnnotatedExportDialog> createState() => _AnnotatedExportDialogState();
}

class _AnnotatedExportDialogState extends State<AnnotatedExportDialog> {
  AnnotatedImageExportConfig _config = const AnnotatedImageExportConfig();
  late final TextEditingController _maxController;
  late final TextEditingController _scaleController;

  @override
  void initState() {
    super.initState();
    _maxController = TextEditingController(text: '${_config.maxImages}');
    _scaleController = TextEditingController(text: '${_config.outputScale}');
  }

  @override
  void dispose() {
    _maxController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export Annotated Images'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scope', style: Theme.of(context).textTheme.titleSmall),
              RadioGroup<AnnotatedExportScope>(
                groupValue: _config.scope,
                onChanged: (AnnotatedExportScope? scope) {
                  if (scope != null) {
                    setState(() => _config = _config.copyWith(scope: scope));
                  }
                },
                child: Column(
                  children: [
                    for (final AnnotatedExportScope scope
                        in AnnotatedExportScope.values)
                      if (!scope.isComparisonScope)
                        RadioListTile<AnnotatedExportScope>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: scope,
                          title: Text(scope.label),
                          enabled: _enabled(scope),
                        ),
                  ],
                ),
              ),
              const Divider(),
              Text('Options', style: Theme.of(context).textTheme.titleSmall),
              Wrap(
                spacing: 8,
                runSpacing: 0,
                children: [
                  _chip(
                    'GT',
                    _config.includeGt,
                    (v) => _config = _config.copyWith(includeGt: v),
                  ),
                  _chip(
                    'Predictions',
                    _config.includePredictions,
                    (v) => _config = _config.copyWith(includePredictions: v),
                  ),
                  _chip(
                    'TP',
                    _config.includeTp,
                    (v) => _config = _config.copyWith(includeTp: v),
                  ),
                  _chip(
                    'FP',
                    _config.includeFp,
                    (v) => _config = _config.copyWith(includeFp: v),
                  ),
                  _chip(
                    'FN',
                    _config.includeFn,
                    (v) => _config = _config.copyWith(includeFn: v),
                  ),
                  _chip(
                    'Labels',
                    _config.includeLabels,
                    (v) => _config = _config.copyWith(includeLabels: v),
                  ),
                  _chip(
                    'Scores',
                    _config.includeScores,
                    (v) => _config = _config.copyWith(includeScores: v),
                  ),
                  _chip(
                    'IoU',
                    _config.includeIou,
                    (v) => _config = _config.copyWith(includeIou: v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _maxController,
                      decoration: const InputDecoration(
                        labelText: 'Max images',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _scaleController,
                      decoration: const InputDecoration(
                        labelText: 'Output scale',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Export'),
        ),
      ],
    );
  }

  bool _enabled(AnnotatedExportScope scope) {
    return switch (scope) {
      AnnotatedExportScope.currentImage => widget.currentImageAvailable,
      AnnotatedExportScope.currentFilteredImages =>
        widget.filteredImagesAvailable,
      AnnotatedExportScope.falsePositiveImages ||
      AnnotatedExportScope.falseNegativeImages ||
      AnnotatedExportScope.classConfusionImages ||
      AnnotatedExportScope.worstImages =>
        true,
      _ => false,
    };
  }

  Widget _chip(String label, bool selected, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (bool value) => setState(() => onChanged(value)),
    );
  }

  void _submit() {
    final int maxImages = int.tryParse(_maxController.text.trim()) ?? 100;
    final double outputScale =
        double.tryParse(_scaleController.text.trim().replaceAll(',', '.')) ??
            1.0;
    Navigator.of(context).pop(
      _config.copyWith(
        maxImages: maxImages < 0 ? 0 : maxImages,
        outputScale: outputScale <= 0 ? 1.0 : outputScale,
      ),
    );
  }
}
