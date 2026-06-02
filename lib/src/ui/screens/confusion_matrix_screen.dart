import 'dart:typed_data';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../widgets/image_preview_pane.dart';

enum ConfusionValueMode {
  counts,
  rowPercent,
  columnPercent,
}

class ConfusionMatrixScreen extends StatefulWidget {
  const ConfusionMatrixScreen({
    required this.details,
    required this.dataset,
    required this.matchesByImageId,
    required this.loadImageBytes,
    required this.onImageSelected,
    super.key,
  });

  final ConfusionMatrixDetails details;
  final CocoDataset dataset;
  final Map<int, List<DetectionMatch>> matchesByImageId;
  final Future<Uint8List?> Function(String fileName) loadImageBytes;
  final ValueChanged<int> onImageSelected;

  @override
  State<ConfusionMatrixScreen> createState() => _ConfusionMatrixScreenState();
}

class _ConfusionMatrixScreenState extends State<ConfusionMatrixScreen> {
  ConfusionValueMode _mode = ConfusionValueMode.counts;
  bool _hideDiagonal = false;
  bool _errorsOnly = false;
  bool _topPairsOnly = false;
  String? _selectedRow;
  String? _selectedColumn;
  int? _previewImageId;
  Set<DetectionMatchType> _focusTypes = const {};
  DetectionMatch? _focusMatch;

  @override
  Widget build(BuildContext context) {
    final labels = _labels();
    final examples = _selectedRow == null || _selectedColumn == null
        ? const <ConfusionCellExample>[]
        : widget.details.examples(_selectedRow!, _selectedColumn!);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Confusion Matrix',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SegmentedButton<ConfusionValueMode>(
                      segments: const [
                        ButtonSegment(
                          value: ConfusionValueMode.counts,
                          label: Text('Counts'),
                        ),
                        ButtonSegment(
                          value: ConfusionValueMode.rowPercent,
                          label: Text('Row % (recall)'),
                          tooltip: 'count / GT-row total · diagonal = recall',
                        ),
                        ButtonSegment(
                          value: ConfusionValueMode.columnPercent,
                          label: Text('Col % (precision)'),
                          tooltip:
                              'count / Pred-column total · diagonal = precision',
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (Set<ConfusionValueMode> values) {
                        setState(() => _mode = values.first);
                      },
                    ),
                    FilterChip(
                      label: const Text('Hide diagonal'),
                      selected: _hideDiagonal,
                      onSelected: (v) => setState(() => _hideDiagonal = v),
                    ),
                    FilterChip(
                      label: const Text('Errors only'),
                      selected: _errorsOnly,
                      onSelected: (v) => setState(() => _errorsOnly = v),
                    ),
                    FilterChip(
                      label: const Text('Top pairs'),
                      selected: _topPairsOnly,
                      onSelected: (v) => setState(() => _topPairsOnly = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _topPairsOnly
                      ? _TopPairsTable(
                          pairs: widget.details.pairs(
                            includeDiagonal: !_hideDiagonal,
                          ),
                          onPairSelected: _selectCell,
                        )
                      : _MatrixTable(
                          labels: labels,
                          details: widget.details,
                          mode: _mode,
                          hideDiagonal: _hideDiagonal,
                          errorsOnly: _errorsOnly,
                          selectedRow: _selectedRow,
                          selectedColumn: _selectedColumn,
                          onCellSelected: _selectCell,
                        ),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 320,
          child: _ExamplesPanel(
            row: _selectedRow,
            column: _selectedColumn,
            examples: examples,
            selectedImageId: _previewImageId,
            onPreview: _selectPreview,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: ImagePreviewPane(
            imageId: _previewImageId,
            dataset: widget.dataset,
            matches: _previewImageId == null
                ? const <DetectionMatch>[]
                : widget.matchesByImageId[_previewImageId] ??
                    const <DetectionMatch>[],
            loadBytes: widget.loadImageBytes,
            focusMatchTypes: _focusTypes,
            focusMatch: _focusMatch,
            onOpenInBrowser: widget.onImageSelected,
          ),
        ),
      ],
    );
  }

  ({List<String> rows, List<String> columns}) _labels() {
    final Set<String> rows = {...widget.details.matrix.counts.keys};
    final Set<String> columns = {};
    for (final Map<String, int> row in widget.details.matrix.counts.values) {
      columns.addAll(row.keys);
    }
    return (
      rows: rows.toList()..sort(_specialAwareCompare),
      columns: columns.toList()..sort(_specialAwareCompare),
    );
  }

  int _specialAwareCompare(String a, String b) {
    int rank(String value) {
      if (value == backgroundFpRow) {
        return 1;
      }
      if (value == missedColumn) {
        return 2;
      }
      return 0;
    }

    final int byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : a.compareTo(b);
  }

  void _selectCell(String row, String column) {
    setState(() {
      _selectedRow = row;
      _selectedColumn = column;
    });
  }

  void _selectPreview(ConfusionCellExample example) {
    final List<DetectionMatch> matches =
        widget.matchesByImageId[example.imageId] ?? const <DetectionMatch>[];
    setState(() {
      _previewImageId = example.imageId;
      _focusTypes = _focusTypesFor(example);
      _focusMatch = _focusMatchFor(example, matches);
    });
  }

  Set<DetectionMatchType> _focusTypesFor(ConfusionCellExample example) {
    if (example.predClass == missedColumn) {
      return const {DetectionMatchType.falseNegative};
    }
    if (example.gtClass == backgroundFpRow) {
      return const {DetectionMatchType.falsePositive};
    }
    if (example.gtClass == example.predClass) {
      return const {DetectionMatchType.truePositive};
    }
    return const {
      DetectionMatchType.falsePositive,
      DetectionMatchType.falseNegative,
    };
  }

  DetectionMatch? _focusMatchFor(
    ConfusionCellExample example,
    List<DetectionMatch> matches,
  ) {
    for (final DetectionMatch match in matches) {
      if (example.predBbox != null &&
          match.prediction != null &&
          _sameBox(match.prediction!.bbox, example.predBbox!)) {
        return match;
      }
      if (example.gtBbox != null &&
          match.groundTruth != null &&
          _sameBox(match.groundTruth!.bbox, example.gtBbox!)) {
        return match;
      }
    }
    return null;
  }

  bool _sameBox(BBox a, BBox b) {
    return a.x == b.x && a.y == b.y && a.width == b.width && a.height == b.height;
  }
}

class _MatrixTable extends StatefulWidget {
  const _MatrixTable({
    required this.labels,
    required this.details,
    required this.mode,
    required this.hideDiagonal,
    required this.errorsOnly,
    required this.selectedRow,
    required this.selectedColumn,
    required this.onCellSelected,
  });

  final ({List<String> rows, List<String> columns}) labels;
  final ConfusionMatrixDetails details;
  final ConfusionValueMode mode;
  final bool hideDiagonal;
  final bool errorsOnly;
  final String? selectedRow;
  final String? selectedColumn;
  final void Function(String row, String column) onCellSelected;

  @override
  State<_MatrixTable> createState() => _MatrixTableState();
}

class _MatrixTableState extends State<_MatrixTable> {
  static const double _rowHeaderWidth = 190;
  static const double _cellWidth = 96;
  static const double _rowHeight = 42;
  static const double _headerHeight = 46;

  final ScrollController _headerHorizontal = ScrollController();
  final ScrollController _bodyHorizontal = ScrollController();
  final ScrollController _rowHeaderVertical = ScrollController();
  final ScrollController _bodyVertical = ScrollController();
  bool _syncing = false;
  String? _hoveredRow;
  String? _hoveredColumn;

  @override
  void initState() {
    super.initState();
    _headerHorizontal.addListener(() {
      _syncScroll(_headerHorizontal, _bodyHorizontal);
    });
    _bodyHorizontal.addListener(() {
      _syncScroll(_bodyHorizontal, _headerHorizontal);
    });
    _rowHeaderVertical.addListener(() {
      _syncScroll(_rowHeaderVertical, _bodyVertical);
    });
    _bodyVertical.addListener(() {
      _syncScroll(_bodyVertical, _rowHeaderVertical);
    });
  }

  @override
  void dispose() {
    _headerHorizontal.dispose();
    _bodyHorizontal.dispose();
    _rowHeaderVertical.dispose();
    _bodyVertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int maxCount = widget.details.matrix.counts.values
        .expand((Map<String, int> row) => row.values)
        .fold(0, (int max, int count) => count > max ? count : max);
    final Map<String, int> columnTotals = {
      for (final String column in widget.labels.columns)
        column: widget.details.columnTotal(column),
    };
    final double bodyWidth = widget.labels.columns.length * _cellWidth;
    final double bodyHeight = widget.labels.rows.length * _rowHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double tableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (MediaQuery.sizeOf(context).height - 180);
        return ScrollConfiguration(
          behavior: const _MouseDragScrollBehavior(),
          child: SizedBox(
            height: tableHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: _headerHeight,
                    child: Row(
                      children: [
                        _CornerHeader(width: _rowHeaderWidth),
                        Expanded(
                          child: Scrollbar(
                            controller: _headerHorizontal,
                            thumbVisibility: true,
                            notificationPredicate: (notification) =>
                                notification.metrics.axis == Axis.horizontal,
                            child: SingleChildScrollView(
                              controller: _headerHorizontal,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: bodyWidth,
                                child: Row(
                                  children: [
                                    for (final String column
                                        in widget.labels.columns)
                                      _ColumnHeader(
                                        label: column,
                                        width: _cellWidth,
                                        highlighted:
                                            _isColumnHighlighted(column),
                                        diagonal: widget.labels.rows.contains(
                                          column,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, bodyConstraints) {
                        final bool needsVerticalScroll =
                            bodyHeight > bodyConstraints.maxHeight;
                        return Row(
                          children: [
                            SizedBox(
                              width: _rowHeaderWidth,
                              child: needsVerticalScroll
                                  ? SingleChildScrollView(
                                      controller: _rowHeaderVertical,
                                      child: _RowHeaderColumn(
                                        rows: widget.labels.rows,
                                        height: _rowHeight,
                                        bodyHeight: bodyHeight,
                                        isHighlighted: _isRowHighlighted,
                                        isDiagonal: (row) =>
                                            widget.labels.columns.contains(row),
                                      ),
                                    )
                                  : Align(
                                      alignment: Alignment.topLeft,
                                      child: _RowHeaderColumn(
                                        rows: widget.labels.rows,
                                        height: _rowHeight,
                                        bodyHeight: bodyHeight,
                                        isHighlighted: _isRowHighlighted,
                                        isDiagonal: (row) =>
                                            widget.labels.columns.contains(row),
                                      ),
                                    ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: Scrollbar(
                                controller: _bodyHorizontal,
                                thumbVisibility: true,
                                notificationPredicate: (notification) =>
                                    notification.metrics.axis ==
                                    Axis.horizontal,
                                child: SingleChildScrollView(
                                  controller: _bodyHorizontal,
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: bodyWidth,
                                    child: needsVerticalScroll
                                        ? Scrollbar(
                                            controller: _bodyVertical,
                                            thumbVisibility: true,
                                            notificationPredicate:
                                                (notification) =>
                                                    notification.metrics.axis ==
                                                    Axis.vertical,
                                            child: SingleChildScrollView(
                                              controller: _bodyVertical,
                                              child: _MatrixBodyGrid(
                                                rows: widget.labels.rows,
                                                columns: widget.labels.columns,
                                                bodyHeight: bodyHeight,
                                                rowHeight: _rowHeight,
                                                cellWidth: _cellWidth,
                                                details: widget.details,
                                                maxCount: maxCount,
                                                columnTotals: columnTotals,
                                                mode: widget.mode,
                                                selectedRow: widget.selectedRow,
                                                selectedColumn:
                                                    widget.selectedColumn,
                                                isHidden: _hidden,
                                                isRowHighlighted:
                                                    _isRowHighlighted,
                                                isColumnHighlighted:
                                                    _isColumnHighlighted,
                                                isDiagonal: _isDiagonal,
                                                onHoverChanged: _setHover,
                                                onCellSelected:
                                                    widget.onCellSelected,
                                              ),
                                            ),
                                          )
                                        : Align(
                                            alignment: Alignment.topLeft,
                                            child: _MatrixBodyGrid(
                                              rows: widget.labels.rows,
                                              columns: widget.labels.columns,
                                              bodyHeight: bodyHeight,
                                              rowHeight: _rowHeight,
                                              cellWidth: _cellWidth,
                                              details: widget.details,
                                              maxCount: maxCount,
                                              columnTotals: columnTotals,
                                              mode: widget.mode,
                                              selectedRow: widget.selectedRow,
                                              selectedColumn:
                                                  widget.selectedColumn,
                                              isHidden: _hidden,
                                              isRowHighlighted:
                                                  _isRowHighlighted,
                                              isColumnHighlighted:
                                                  _isColumnHighlighted,
                                              isDiagonal: _isDiagonal,
                                              onHoverChanged: _setHover,
                                              onCellSelected:
                                                  widget.onCellSelected,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isRowHighlighted(String row) {
    return row == widget.selectedRow || row == _hoveredRow;
  }

  bool _isColumnHighlighted(String column) {
    return column == widget.selectedColumn || column == _hoveredColumn;
  }

  bool _isDiagonal(String row, String column) {
    return row == column && row != backgroundFpRow && column != missedColumn;
  }

  void _setHover(String? row, String? column) {
    setState(() {
      _hoveredRow = row;
      _hoveredColumn = column;
    });
  }

  void _syncScroll(ScrollController source, ScrollController target) {
    if (_syncing || !source.hasClients || !target.hasClients) {
      return;
    }
    final double targetOffset = source.offset.clamp(
      0,
      target.position.maxScrollExtent,
    );
    if ((target.offset - targetOffset).abs() < 0.5) {
      return;
    }
    _syncing = true;
    target.jumpTo(targetOffset);
    _syncing = false;
  }

  bool _hidden(String row, String column) {
    final bool diagonal = _isDiagonal(row, column);
    if (widget.hideDiagonal && diagonal) {
      return true;
    }
    if (widget.errorsOnly && diagonal) {
      return true;
    }
    return false;
  }
}

class _RowHeaderColumn extends StatelessWidget {
  const _RowHeaderColumn({
    required this.rows,
    required this.height,
    required this.bodyHeight,
    required this.isHighlighted,
    required this.isDiagonal,
  });

  final List<String> rows;
  final double height;
  final double bodyHeight;
  final bool Function(String row) isHighlighted;
  final bool Function(String row) isDiagonal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: bodyHeight,
      child: Column(
        children: [
          for (final String row in rows)
            _RowHeader(
              label: row,
              height: height,
              highlighted: isHighlighted(row),
              diagonal: isDiagonal(row),
            ),
        ],
      ),
    );
  }
}

class _MatrixBodyGrid extends StatelessWidget {
  const _MatrixBodyGrid({
    required this.rows,
    required this.columns,
    required this.bodyHeight,
    required this.rowHeight,
    required this.cellWidth,
    required this.details,
    required this.maxCount,
    required this.columnTotals,
    required this.mode,
    required this.selectedRow,
    required this.selectedColumn,
    required this.isHidden,
    required this.isRowHighlighted,
    required this.isColumnHighlighted,
    required this.isDiagonal,
    required this.onHoverChanged,
    required this.onCellSelected,
  });

  final List<String> rows;
  final List<String> columns;
  final double bodyHeight;
  final double rowHeight;
  final double cellWidth;
  final ConfusionMatrixDetails details;
  final int maxCount;
  final Map<String, int> columnTotals;
  final ConfusionValueMode mode;
  final String? selectedRow;
  final String? selectedColumn;
  final bool Function(String row, String column) isHidden;
  final bool Function(String row) isRowHighlighted;
  final bool Function(String column) isColumnHighlighted;
  final bool Function(String row, String column) isDiagonal;
  final void Function(String? row, String? column) onHoverChanged;
  final void Function(String row, String column) onCellSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: bodyHeight,
      child: Column(
        children: [
          for (final String row in rows)
            SizedBox(
              height: rowHeight,
              child: Row(
                children: [
                  for (final String column in columns)
                    _Cell(
                      row: row,
                      column: column,
                      count: details.matrix.counts[row]?[column] ?? 0,
                      rowTotal: details.rowTotal(row),
                      columnTotal: columnTotals[column] ?? 0,
                      maxCount: maxCount,
                      mode: mode,
                      hidden: isHidden(row, column),
                      selected: row == selectedRow && column == selectedColumn,
                      highlightedRow: isRowHighlighted(row),
                      highlightedColumn: isColumnHighlighted(column),
                      diagonal: isDiagonal(row, column),
                      width: cellWidth,
                      height: rowHeight,
                      onHoverChanged: (hovering) => onHoverChanged(
                        hovering ? row : null,
                        hovering ? column : null,
                      ),
                      onTap: onCellSelected,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MouseDragScrollBehavior extends MaterialScrollBehavior {
  const _MouseDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
      };
}

class _CornerHeader extends StatelessWidget {
  const _CornerHeader({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Text('GT \\ Pred'),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.label,
    required this.width,
    required this.highlighted,
    required this.diagonal,
  });

  final String label;
  final double width;
  final bool highlighted;
  final bool diagonal;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? colors.primaryContainer.withValues(alpha: 0.85)
            : colors.surfaceContainerHighest,
        border: Border(
          right: BorderSide(
            color: diagonal ? colors.primary : Theme.of(context).dividerColor,
            width: diagonal ? 2 : 1,
          ),
          bottom: diagonal
              ? BorderSide(color: colors.primary, width: 2)
              : BorderSide.none,
        ),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: highlighted || diagonal ? FontWeight.w700 : null,
            ),
      ),
    );
  }
}

class _RowHeader extends StatelessWidget {
  const _RowHeader({
    required this.label,
    required this.height,
    required this.highlighted,
    required this.diagonal,
  });

  final String label;
  final double height;
  final bool highlighted;
  final bool diagonal;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      height: height,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: highlighted
            ? colors.primaryContainer.withValues(alpha: 0.85)
            : colors.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(
            color: diagonal ? colors.primary : Theme.of(context).dividerColor,
            width: diagonal ? 2 : 1,
          ),
          right: diagonal
              ? BorderSide(color: colors.primary, width: 2)
              : BorderSide.none,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: highlighted || diagonal ? FontWeight.w700 : null,
            ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.row,
    required this.column,
    required this.count,
    required this.rowTotal,
    required this.columnTotal,
    required this.maxCount,
    required this.mode,
    required this.hidden,
    required this.selected,
    required this.highlightedRow,
    required this.highlightedColumn,
    required this.diagonal,
    required this.width,
    required this.height,
    required this.onHoverChanged,
    required this.onTap,
  });

  final String row;
  final String column;
  final int count;
  final int rowTotal;
  final int columnTotal;
  final int maxCount;
  final ConfusionValueMode mode;
  final bool hidden;
  final bool selected;
  final bool highlightedRow;
  final bool highlightedColumn;
  final bool diagonal;
  final double width;
  final double height;
  final ValueChanged<bool> onHoverChanged;
  final void Function(String row, String column) onTap;

  @override
  Widget build(BuildContext context) {
    if (hidden || count == 0) {
      return MouseRegion(
        onEnter: (_) => onHoverChanged(true),
        onExit: (_) => onHoverChanged(false),
        child: _CellFrame(
          width: width,
          height: height,
          highlightedRow: highlightedRow,
          highlightedColumn: highlightedColumn,
          diagonal: diagonal,
          selected: selected,
          child: const SizedBox.shrink(),
        ),
      );
    }
    final double rowPercent = rowTotal == 0 ? 0 : count / rowTotal;
    final double columnPercent = columnTotal == 0 ? 0 : count / columnTotal;
    final double countShare = maxCount == 0 ? 0 : count / maxCount;
    final double intensity = switch (mode) {
      ConfusionValueMode.counts => countShare,
      ConfusionValueMode.rowPercent => rowPercent,
      ConfusionValueMode.columnPercent => columnPercent,
    };
    final String label = switch (mode) {
      ConfusionValueMode.counts => '$count',
      ConfusionValueMode.rowPercent =>
        '${(rowPercent * 100).toStringAsFixed(1)}%',
      ConfusionValueMode.columnPercent =>
        '${(columnPercent * 100).toStringAsFixed(1)}%',
    };
    final Color base = Theme.of(context).colorScheme.primary;
    final double alpha = 0.10 + intensity.clamp(0, 1) * 0.55;
    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: InkWell(
        onTap: () => onTap(row, column),
        child: _CellFrame(
          width: width,
          height: height,
          highlightedRow: highlightedRow,
          highlightedColumn: highlightedColumn,
          diagonal: diagonal,
          selected: selected,
          fill: base.withValues(alpha: alpha),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: diagonal || selected ? FontWeight.w800 : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _CellFrame extends StatelessWidget {
  const _CellFrame({
    required this.width,
    required this.height,
    required this.highlightedRow,
    required this.highlightedColumn,
    required this.diagonal,
    required this.selected,
    required this.child,
    this.fill,
  });

  final double width;
  final double height;
  final bool highlightedRow;
  final bool highlightedColumn;
  final bool diagonal;
  final bool selected;
  final Color? fill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool highlighted = highlightedRow || highlightedColumn;
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill ??
            (highlighted
                ? colors.primaryContainer.withValues(alpha: 0.22)
                : null),
        border: Border.all(
          color: selected || diagonal
              ? colors.primary
              : (highlighted
                  ? colors.primary.withValues(alpha: 0.65)
                  : Theme.of(context).dividerColor),
          width: selected || diagonal ? 2 : (highlighted ? 1.5 : 1),
        ),
      ),
      child: child,
    );
  }
}

class _TopPairsTable extends StatelessWidget {
  const _TopPairsTable({
    required this.pairs,
    required this.onPairSelected,
  });

  final List<ConfusionPair> pairs;
  final void Function(String row, String column) onPairSelected;

  @override
  Widget build(BuildContext context) {
    final List<ConfusionPair> top = pairs.take(50).toList();
    return Scrollbar(
      thumbVisibility: true,
      interactive: false,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('GT')),
            DataColumn(label: Text('Pred')),
            DataColumn(label: Text('Count')),
            DataColumn(label: Text('Row %')),
          ],
          rows: [
            for (final ConfusionPair pair in top)
              DataRow(
                onSelectChanged: (_) =>
                    onPairSelected(pair.gtClass, pair.predClass),
                cells: [
                  DataCell(Text(pair.gtClass)),
                  DataCell(Text(pair.predClass)),
                  DataCell(Text('${pair.count}')),
                  DataCell(
                    Text('${(pair.rowPercent * 100).toStringAsFixed(1)}%'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ExamplesPanel extends StatelessWidget {
  const _ExamplesPanel({
    required this.row,
    required this.column,
    required this.examples,
    required this.selectedImageId,
    required this.onPreview,
  });

  final String? row;
  final String? column;
  final List<ConfusionCellExample> examples;
  final int? selectedImageId;
  final ValueChanged<ConfusionCellExample> onPreview;

  @override
  Widget build(BuildContext context) {
    if (row == null || column == null) {
      return const Center(child: Text('Select a matrix cell'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('$row → $column', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('${examples.length} example(s)'),
        const SizedBox(height: 12),
        for (final ConfusionCellExample example in examples)
          ListTile(
            contentPadding: EdgeInsets.zero,
            selected: selectedImageId == example.imageId,
            title: Text(example.fileName),
            subtitle: Text(
              [
                'image_id ${example.imageId}',
                if (example.score != null)
                  'score ${example.score!.toStringAsFixed(2)}',
                if (example.iou != null)
                  'IoU ${example.iou!.toStringAsFixed(2)}',
              ].join('  |  '),
            ),
            onTap: () => onPreview(example),
          ),
      ],
    );
  }
}
