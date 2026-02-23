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
        width: 180,
      ),
      const _GridColumn(keyName: _pathSortKey, label: 'Path', width: 300),
      ...visibleColumns.map(
        (column) => _GridColumn(keyName: column, label: column, width: 220),
      ),
    ];

    final tableWidth = columns.fold<double>(
      0,
      (totalWidth, column) => totalWidth + column.width,
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
                          sortKey: _sortKey,
                          sortAscending: _sortAscending,
                          onSort: _toggleSort,
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
  final String? sortKey;
  final bool sortAscending;
  final ValueChanged<String> onSort;

  const _GridHeader({
    required this.columns,
    required this.sortKey,
    required this.sortAscending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final headerColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Container(
      height: 46,
      color: headerColor,
      child: Row(
        children: columns
            .map((column) {
              final isActive = sortKey == column.keyName;
              return InkWell(
                onTap: () => onSort(column.keyName),
                child: Container(
                  width: column.width,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          column.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
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
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _GridDataRow extends StatelessWidget {
  final List<_GridColumn> columns;
  final _GridRow row;
  final FirestoreAdminService service;

  const _GridDataRow({
    required this.columns,
    required this.row,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: columns
            .map((column) {
              final cellValue = _valueForColumn(column.keyName);
              final cellText = service.formatGridCellValue(cellValue);

              return Container(
                width: column.width,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
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
  final double width;

  const _GridColumn({
    required this.keyName,
    required this.label,
    required this.width,
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
