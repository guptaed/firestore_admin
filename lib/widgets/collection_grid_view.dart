import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_admin_service.dart';

class CollectionGridView extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final FirestoreAdminService service;
  final ValueChanged<String> onDocumentSelected;
  final int flattenDepth;
  final int maxColumns;

  const CollectionGridView({
    super.key,
    required this.docs,
    required this.service,
    required this.onDocumentSelected,
    this.flattenDepth = 2,
    this.maxColumns = 60,
  });

  @override
  State<CollectionGridView> createState() => _CollectionGridViewState();
}

class _CollectionGridViewState extends State<CollectionGridView> {
  static const String _docIdSortKey = '__document_id__';
  static const String _pathSortKey = '__path__';

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final Map<String, double> _columnWidths = <String, double>{};
  String? _sortKey;
  bool _sortAscending = true;

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _toggleSort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortKey = key;
        _sortAscending = true;
      }
    });
  }

  void _syncColumnWidths(List<_GridColumn> columns) {
    final activeKeys = columns.map((c) => c.keyName).toSet();
    _columnWidths.removeWhere((key, _) => !activeKeys.contains(key));
    for (final column in columns) {
      _columnWidths.putIfAbsent(column.keyName, () => column.defaultWidth);
    }
  }

  double _effectiveWidth(_GridColumn column) {
    final width = _columnWidths[column.keyName] ?? column.defaultWidth;
    return width.clamp(column.minWidth, 2000).toDouble();
  }

  void _resizeColumn(String keyName, double delta) {
    setState(() {
      final column = _allColumnsByKey[keyName];
      if (column == null) return;
      final current = _columnWidths[keyName] ?? column.defaultWidth;
      _columnWidths[keyName] = (current + delta)
          .clamp(column.minWidth, 2000)
          .toDouble();
    });
  }

  Map<String, _GridColumn> _allColumnsByKey = const <String, _GridColumn>{};

  int _compareValues(dynamic a, dynamic b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;

    if (a is num && b is num) return a.compareTo(b);
    if (a is Timestamp && b is Timestamp) {
      return a.toDate().compareTo(b.toDate());
    }
    if (a is DateTime && b is DateTime) return a.compareTo(b);
    if (a is bool && b is bool) {
      return (a ? 1 : 0).compareTo(b ? 1 : 0);
    }
    if (a is String && b is String) {
      return a.toLowerCase().compareTo(b.toLowerCase());
    }
    if (a is DocumentReference && b is DocumentReference) {
      return a.path.toLowerCase().compareTo(b.path.toLowerCase());
    }

    final textA = widget.service.formatGridCellValue(a, maxLength: 10000);
    final textB = widget.service.formatGridCellValue(b, maxLength: 10000);
    return textA.toLowerCase().compareTo(textB.toLowerCase());
  }

  List<_GridRow> _applySort(List<_GridRow> rows) {
    if (_sortKey == null) return rows;

    final sorted = List<_GridRow>.from(rows);
    sorted.sort((left, right) {
      dynamic leftValue;
      dynamic rightValue;

      if (_sortKey == _docIdSortKey) {
        leftValue = left.documentId;
        rightValue = right.documentId;
      } else if (_sortKey == _pathSortKey) {
        leftValue = left.path;
        rightValue = right.path;
      } else {
        leftValue = left.values[_sortKey];
        rightValue = right.values[_sortKey];
      }

      final result = _compareValues(leftValue, rightValue);
      return _sortAscending ? result : -result;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.docs
        .map(
          (doc) => _GridRow(
            documentId: doc.id,
            path: doc.reference.path,
            values: widget.service.flattenForGrid(
              doc.data(),
              maxDepth: widget.flattenDepth,
            ),
          ),
        )
        .toList(growable: false);

    final discoveredColumns = widget.service.extractGridColumns(
      rows.map((row) => row.values),
    );
    final visibleColumns = discoveredColumns.take(widget.maxColumns).toList();
    final hiddenCount = discoveredColumns.length - visibleColumns.length;
    final sortedRows = _applySort(rows);

    final columns = <_GridColumn>[
      const _GridColumn(
        keyName: _docIdSortKey,
        label: 'Document ID',
        defaultWidth: 180,
        minWidth: 120,
      ),
      const _GridColumn(
        keyName: _pathSortKey,
        label: 'Path',
        defaultWidth: 300,
        minWidth: 180,
      ),
      ...visibleColumns.map(
        (column) => _GridColumn(
          keyName: column,
          label: column,
          defaultWidth: 220,
          minWidth: 120,
        ),
      ),
    ];

    _allColumnsByKey = {for (final column in columns) column.keyName: column};
    _syncColumnWidths(columns);

    final tableWidth = columns.fold<double>(
      0,
      (totalWidth, column) => totalWidth + _effectiveWidth(column),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hiddenCount > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Text(
              'Showing first ${widget.maxColumns} columns. $hiddenCount additional columns are hidden.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                trackVisibility: true,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    height: constraints.maxHeight,
                    child: Column(
                      children: [
                        _GridHeader(
                          columns: columns,
                          columnWidthFor: _effectiveWidth,
                          sortKey: _sortKey,
                          sortAscending: _sortAscending,
                          onSort: _toggleSort,
                          onResize: _resizeColumn,
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: Scrollbar(
                            controller: _verticalController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            notificationPredicate: (notification) =>
                                notification.metrics.axis == Axis.vertical,
                            child: ListView.separated(
                              controller: _verticalController,
                              itemCount: sortedRows.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final row = sortedRows[index];
                                return InkWell(
                                  onTap: () =>
                                      widget.onDocumentSelected(row.path),
                                  child: _GridDataRow(
                                    columns: columns,
                                    columnWidthFor: _effectiveWidth,
                                    row: row,
                                    service: widget.service,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GridHeader extends StatelessWidget {
  final List<_GridColumn> columns;
  final double Function(_GridColumn column) columnWidthFor;
  final String? sortKey;
  final bool sortAscending;
  final ValueChanged<String> onSort;
  final void Function(String keyName, double delta) onResize;

  const _GridHeader({
    required this.columns,
    required this.columnWidthFor,
    required this.sortKey,
    required this.sortAscending,
    required this.onSort,
    required this.onResize,
  });

  @override
  Widget build(BuildContext context) {
    final headerColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final borderColor = Theme.of(context).dividerColor.withValues(alpha: 0.9);

    return Container(
      height: 46,
      color: headerColor,
      child: Row(
        children: columns
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final column = entry.value;
              final width = columnWidthFor(column);
              final isActive = sortKey == column.keyName;
              return Container(
                width: width,
                decoration: BoxDecoration(
                  border: Border(
                    left: index == 0
                        ? BorderSide(color: borderColor, width: 1)
                        : BorderSide.none,
                    right: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: InkWell(
                        onTap: () => onSort(column.keyName),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  column.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isActive)
                                Icon(
                                  sortAscending
                                      ? Icons.arrow_drop_up
                                      : Icons.arrow_drop_down,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragUpdate: (details) {
                            onResize(column.keyName, details.delta.dx);
                          },
                          child: Container(
                            width: 12,
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 1,
                              color: borderColor.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _GridDataRow extends StatelessWidget {
  final List<_GridColumn> columns;
  final double Function(_GridColumn column) columnWidthFor;
  final _GridRow row;
  final FirestoreAdminService service;

  const _GridDataRow({
    required this.columns,
    required this.columnWidthFor,
    required this.row,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).dividerColor.withValues(alpha: 0.8);
    return SizedBox(
      height: 42,
      child: Row(
        children: columns
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final column = entry.value;
              final cellValue = _valueForColumn(column.keyName);
              final cellText = service.formatGridCellValue(cellValue);

              return Container(
                width: columnWidthFor(column),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(
                    left: index == 0
                        ? BorderSide(color: borderColor, width: 1)
                        : BorderSide.none,
                    right: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: Tooltip(
                  message: cellText,
                  child: Text(
                    cellText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  dynamic _valueForColumn(String key) {
    if (key == _CollectionGridViewState._docIdSortKey) {
      return row.documentId;
    }
    if (key == _CollectionGridViewState._pathSortKey) {
      return row.path;
    }
    return row.values[key];
  }
}

class _GridColumn {
  final String keyName;
  final String label;
  final double defaultWidth;
  final double minWidth;

  const _GridColumn({
    required this.keyName,
    required this.label,
    required this.defaultWidth,
    this.minWidth = 100,
  });
}

class _GridRow {
  final String documentId;
  final String path;
  final Map<String, dynamic> values;

  _GridRow({
    required this.documentId,
    required this.path,
    required this.values,
  });
}
