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

/// Which context data is available to conditionally enable PDF options.
class ExportReportContext {
  const ExportReportContext({
    this.smallObjectStatsAvailable = false,
    this.confusionMatrixAvailable = false,
    this.filteredViewAvailable = false,
    this.comparisonAvailable = false,
  });

  final bool smallObjectStatsAvailable;
  final bool confusionMatrixAvailable;
  final bool filteredViewAvailable;
  final bool comparisonAvailable;
}

/// Lets the user choose which artifacts to export and over which scope.
class ExportReportDialog extends StatefulWidget {
  const ExportReportDialog({
    required this.smallObjectStatsAvailable,
    required this.confusionMatrixAvailable,
    required this.filteredViewAvailable,
    this.comparisonAvailable = false,
    super.key,
  });

  final bool smallObjectStatsAvailable;
  final bool confusionMatrixAvailable;
  final bool filteredViewAvailable;
  final bool comparisonAvailable;

  @override
  State<ExportReportDialog> createState() => _ExportReportDialogState();
}

class _ExportReportDialogState extends State<ExportReportDialog> {
  bool _html = true;
  bool _perClass = false;
  bool _imageErrors = false;
  bool _matches = false;
  bool _smallObject = false;
  bool _confusion = false;
  bool _confusionPairs = false;
  bool _datasetHealth = false;
  bool _worstCases = false;
  bool _recommendations = false;
  bool _xlsx = false;
  bool _pdf = false;
  bool _pdfRecs = true;
  bool _pdfWorstCases = true;
  bool _pdfComparison = true;
  bool _pdfHealth = true;
  bool _pdfConfusion = true;
  ReportScope _scope = ReportScope.fullEvaluation;

  bool get _anySelected =>
      _html ||
      _perClass ||
      _imageErrors ||
      _matches ||
      (_smallObject && widget.smallObjectStatsAvailable) ||
      (_confusion && widget.confusionMatrixAvailable) ||
      (_confusionPairs && widget.confusionMatrixAvailable) ||
      _datasetHealth ||
      _worstCases ||
      _recommendations ||
      _xlsx ||
      _pdf;

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
              label: 'PDF report',
              value: _pdf,
              onChanged: (bool v) => setState(() => _pdf = v),
            ),
            if (_pdf) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _checkbox(
                      label: 'Include recommendations',
                      value: _pdfRecs,
                      onChanged: (bool v) => setState(() => _pdfRecs = v),
                    ),
                    _checkbox(
                      label: 'Include worst cases',
                      value: _pdfWorstCases,
                      onChanged: (bool v) => setState(() => _pdfWorstCases = v),
                    ),
                    _checkbox(
                      label: 'Include model comparison',
                      value: _pdfComparison,
                      enabled: widget.comparisonAvailable,
                      onChanged: (bool v) => setState(() => _pdfComparison = v),
                    ),
                    _checkbox(
                      label: 'Include dataset health',
                      value: _pdfHealth,
                      onChanged: (bool v) => setState(() => _pdfHealth = v),
                    ),
                    _checkbox(
                      label: 'Include confusion summary',
                      value: _pdfConfusion,
                      enabled: widget.confusionMatrixAvailable,
                      onChanged: (bool v) => setState(() => _pdfConfusion = v),
                    ),
                  ],
                ),
              ),
            ],
            _checkbox(
              label: 'XLSX workbook',
              value: _xlsx,
              onChanged: (bool v) => setState(() => _xlsx = v),
            ),
            const Divider(),
            Text('CSV exports:', style: Theme.of(context).textTheme.titleSmall),
            _checkbox(
              label: 'per-class metrics',
              value: _perClass,
              onChanged: (bool v) => setState(() => _perClass = v),
            ),
            _checkbox(
              label: 'image errors',
              value: _imageErrors,
              onChanged: (bool v) => setState(() => _imageErrors = v),
            ),
            _checkbox(
              label: 'matches',
              value: _matches,
              onChanged: (bool v) => setState(() => _matches = v),
            ),
            _checkbox(
              label: 'small object stats',
              value: _smallObject && widget.smallObjectStatsAvailable,
              enabled: widget.smallObjectStatsAvailable,
              onChanged: (bool v) => setState(() => _smallObject = v),
            ),
            _checkbox(
              label: 'confusion matrix',
              value: _confusion && widget.confusionMatrixAvailable,
              enabled: widget.confusionMatrixAvailable,
              onChanged: (bool v) => setState(() => _confusion = v),
            ),
            _checkbox(
              label: 'confusion pairs',
              value: _confusionPairs && widget.confusionMatrixAvailable,
              enabled: widget.confusionMatrixAvailable,
              onChanged: (bool v) => setState(() => _confusionPairs = v),
            ),
            _checkbox(
              label: 'dataset health',
              value: _datasetHealth,
              onChanged: (bool v) => setState(() => _datasetHealth = v),
            ),
            _checkbox(
              label: 'worst cases',
              value: _worstCases,
              onChanged: (bool v) => setState(() => _worstCases = v),
            ),
            _checkbox(
              label: 'recommendations',
              value: _recommendations,
              onChanged: (bool v) => setState(() => _recommendations = v),
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
          includeConfusionPairsCsv:
              _confusionPairs && widget.confusionMatrixAvailable,
          includeDatasetHealthCsv: _datasetHealth,
          includeWorstCasesCsv: _worstCases,
          includeRecommendationsCsv: _recommendations,
          includeXlsxWorkbook: _xlsx,
          includePdfReport: _pdf,
          pdfOptions: PdfReportOptions(
            includeRecommendations: _pdfRecs,
            includeWorstCases: _pdfWorstCases,
            includeComparison: _pdfComparison && widget.comparisonAvailable,
            includeHealth: _pdfHealth,
            includeConfusion:
                _pdfConfusion && widget.confusionMatrixAvailable,
          ),
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
