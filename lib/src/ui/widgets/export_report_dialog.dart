import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

/// User selections collected by [ExportReportDialog].
class ExportReportRequest {
  const ExportReportRequest({
    required this.components,
    required this.scope,
  });

  final ReportComponents components;
  final ReportScope scope;
}

/// Lets the user choose which artifacts to export and over which scope.
class ExportReportDialog extends StatefulWidget {
  const ExportReportDialog({
    required this.smallObjectStatsAvailable,
    required this.confusionMatrixAvailable,
    required this.filteredViewAvailable,
    super.key,
  });

  final bool smallObjectStatsAvailable;
  final bool confusionMatrixAvailable;
  final bool filteredViewAvailable;

  @override
  State<ExportReportDialog> createState() => _ExportReportDialogState();
}

class _ExportReportDialogState extends State<ExportReportDialog> {
  bool _html = true;
  bool _perClass = true;
  bool _imageErrors = true;
  bool _matches = true;
  bool _smallObject = false;
  bool _confusion = false;
  ReportScope _scope = ReportScope.fullEvaluation;

  bool get _anySelected =>
      _html ||
      _perClass ||
      _imageErrors ||
      _matches ||
      (_smallObject && widget.smallObjectStatsAvailable) ||
      (_confusion && widget.confusionMatrixAvailable);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export Report'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Include:', style: Theme.of(context).textTheme.titleSmall),
            _checkbox(
              label: 'HTML report',
              value: _html,
              onChanged: (bool v) => setState(() => _html = v),
            ),
            _checkbox(
              label: 'CSV: per-class metrics',
              value: _perClass,
              onChanged: (bool v) => setState(() => _perClass = v),
            ),
            _checkbox(
              label: 'CSV: image errors',
              value: _imageErrors,
              onChanged: (bool v) => setState(() => _imageErrors = v),
            ),
            _checkbox(
              label: 'CSV: matches',
              value: _matches,
              onChanged: (bool v) => setState(() => _matches = v),
            ),
            _checkbox(
              label: 'CSV: small object stats',
              value: _smallObject && widget.smallObjectStatsAvailable,
              enabled: widget.smallObjectStatsAvailable,
              onChanged: (bool v) => setState(() => _smallObject = v),
            ),
            _checkbox(
              label: 'CSV: confusion matrix',
              value: _confusion && widget.confusionMatrixAvailable,
              enabled: widget.confusionMatrixAvailable,
              onChanged: (bool v) => setState(() => _confusion = v),
            ),
            const Divider(),
            Text('Scope:', style: Theme.of(context).textTheme.titleSmall),
            RadioGroup<ReportScope>(
              groupValue: _scope,
              onChanged: (ReportScope? v) => setState(
                () => _scope = v ?? ReportScope.fullEvaluation,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RadioListTile<ReportScope>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Full evaluation result'),
                    value: ReportScope.fullEvaluation,
                  ),
                  RadioListTile<ReportScope>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Current filtered view'),
                    value: ReportScope.filteredView,
                    enabled: widget.filteredViewAvailable,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _anySelected ? _submit : null,
          child: const Text('Export'),
        ),
      ],
    );
  }

  void _submit() {
    Navigator.of(context).pop(
      ExportReportRequest(
        components: ReportComponents(
          includeHtml: _html,
          includePerClassMetricsCsv: _perClass,
          includeImageErrorsCsv: _imageErrors,
          includeMatchesCsv: _matches,
          includeSmallObjectStatsCsv:
              _smallObject && widget.smallObjectStatsAvailable,
          includeConfusionMatrixCsv:
              _confusion && widget.confusionMatrixAvailable,
        ),
        scope: _scope,
      ),
    );
  }

  Widget _checkbox({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(label),
      value: value,
      onChanged: enabled ? (bool? v) => onChanged(v ?? false) : null,
    );
  }
}
