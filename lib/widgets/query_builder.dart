import 'package:flutter/material.dart';
import '../services/firestore_admin_service.dart';

class QueryBuilder extends StatefulWidget {
  final List<QueryCondition> conditions;
  final String? orderByField;
  final bool descending;
  final int? limit;
  final Function(List<QueryCondition>, String?, bool, int?) onQueryChanged;
  final VoidCallback onClear;
  final String collectionPath;
  final FirestoreAdminService service;

  const QueryBuilder({
    super.key,
    required this.conditions,
    this.orderByField,
    this.descending = false,
    this.limit,
    required this.onQueryChanged,
    required this.onClear,
    required this.collectionPath,
    required this.service,
  });

  @override
  State<QueryBuilder> createState() => _QueryBuilderState();
}

class _QueryBuilderState extends State<QueryBuilder> {
  final _valueController = TextEditingController();
  final _orderByController = TextEditingController();
  final _limitController = TextEditingController();

  QueryOperator _selectedOperator = QueryOperator.equals;
  String _selectedValueType = 'string';
  bool _descending = false;

  // Field names from the collection
  List<String> _availableFields = [];
  String? _selectedField;
  bool _isLoadingFields = true;

  @override
  void initState() {
    super.initState();
    _orderByController.text = widget.orderByField ?? '';
    _limitController.text = widget.limit?.toString() ?? '';
    _descending = widget.descending;
    _loadFieldNames();
  }

  @override
  void didUpdateWidget(QueryBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collectionPath != widget.collectionPath) {
      _loadFieldNames();
    }
  }

  Future<void> _loadFieldNames() async {
    setState(() => _isLoadingFields = true);

    try {
      // Get first few documents to extract field names
      final snapshot = await widget.service.getDocuments(widget.collectionPath);
      final fields = <String>{};

      // Collect all unique field names from documents
      for (final doc in snapshot.docs.take(10)) {
        _extractFieldNames(doc.data(), '', fields);
      }

      setState(() {
        _availableFields = fields.toList()..sort();
        _isLoadingFields = false;
        // Reset selected field if it's not in the new list
        if (_selectedField != null && !_availableFields.contains(_selectedField)) {
          _selectedField = null;
        }
      });
    } catch (e) {
      setState(() {
        _availableFields = [];
        _isLoadingFields = false;
      });
    }
  }

  /// Recursively extract field names, including nested paths
  void _extractFieldNames(Map<String, dynamic> data, String prefix, Set<String> fields) {
    for (final entry in data.entries) {
      final fieldPath = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      fields.add(fieldPath);

      // For nested maps, also add nested field paths
      if (entry.value is Map<String, dynamic>) {
        _extractFieldNames(entry.value as Map<String, dynamic>, fieldPath, fields);
      }
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _orderByController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  void _addCondition() {
    if (_selectedField == null || _selectedField!.isEmpty) return;
    final value = _valueController.text.trim();

    if (value.isEmpty &&
        _selectedOperator != QueryOperator.isNull &&
        _selectedOperator != QueryOperator.isNotNull) {
      return;
    }

    final condition = QueryCondition(
      field: _selectedField!,
      operator: _selectedOperator,
      value: value,
      valueType: _selectedValueType,
    );

    final newConditions = [...widget.conditions, condition];
    widget.onQueryChanged(
      newConditions,
      _orderByController.text.trim().isEmpty ? null : _orderByController.text.trim(),
      _descending,
      int.tryParse(_limitController.text),
    );

    setState(() => _selectedField = null);
    _valueController.clear();
  }

  void _removeCondition(int index) {
    final newConditions = [...widget.conditions];
    newConditions.removeAt(index);
    widget.onQueryChanged(
      newConditions,
      _orderByController.text.trim().isEmpty ? null : _orderByController.text.trim(),
      _descending,
      int.tryParse(_limitController.text),
    );
  }

  void _updateQuery() {
    widget.onQueryChanged(
      widget.conditions,
      _orderByController.text.trim().isEmpty ? null : _orderByController.text.trim(),
      _descending,
      int.tryParse(_limitController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.filter_list,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Query Builder',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.onClear,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // WHERE section
          const Text(
            'WHERE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),

          // Add condition row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Field dropdown
              SizedBox(
                width: 180,
                child: _isLoadingFields
                    ? const LinearProgressIndicator()
                    : DropdownButtonFormField<String>(
                        value: _selectedField,
                        decoration: const InputDecoration(
                          hintText: 'Select field',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                        isExpanded: true,
                        items: _availableFields.map((field) {
                          return DropdownMenuItem(
                            value: field,
                            child: Text(
                              field,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedField = value);
                        },
                      ),
              ),
              // Operator dropdown
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<QueryOperator>(
                  value: _selectedOperator,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                  items: QueryOperator.values.map((op) {
                    return DropdownMenuItem(
                      value: op,
                      child: Text(op.symbol),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedOperator = value!);
                  },
                ),
              ),
              // Value input
              if (_selectedOperator != QueryOperator.isNull &&
                  _selectedOperator != QueryOperator.isNotNull)
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _valueController,
                    decoration: const InputDecoration(
                      hintText: 'Value',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (_) => _addCondition(),
                  ),
                ),
              // Value type dropdown
              if (_selectedOperator != QueryOperator.isNull &&
                  _selectedOperator != QueryOperator.isNotNull)
                SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<String>(
                    value: _selectedValueType,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                    items: const [
                      DropdownMenuItem(value: 'string', child: Text('string')),
                      DropdownMenuItem(value: 'number', child: Text('number')),
                      DropdownMenuItem(value: 'boolean', child: Text('bool')),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedValueType = value!);
                    },
                  ),
                ),
              IconButton(
                onPressed: _addCondition,
                icon: const Icon(Icons.add_circle),
                color: Theme.of(context).colorScheme.primary,
                tooltip: 'Add condition',
              ),
            ],
          ),

          // Active conditions
          if (widget.conditions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.conditions.asMap().entries.map((entry) {
                final index = entry.key;
                final condition = entry.value;
                return Chip(
                  label: Text(
                    condition.toString(),
                    style: const TextStyle(fontSize: 12),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _removeCondition(index),
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 16),

          // ORDER BY and LIMIT section
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ORDER BY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      value: _orderByController.text.isEmpty ? null : _orderByController.text,
                      decoration: const InputDecoration(
                        hintText: 'Select field',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('None', style: TextStyle(fontStyle: FontStyle.italic)),
                        ),
                        ..._availableFields.map((field) {
                          return DropdownMenuItem(
                            value: field,
                            child: Text(
                              field,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _orderByController.text = value ?? '';
                        });
                        _updateQuery();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('ASC', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: true, label: Text('DESC', style: TextStyle(fontSize: 11))),
                    ],
                    selected: {_descending},
                    onSelectionChanged: (value) {
                      setState(() => _descending = value.first);
                      _updateQuery();
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'LIMIT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _limitController,
                      decoration: const InputDecoration(
                        hintText: 'Count',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 13),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _updateQuery(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
