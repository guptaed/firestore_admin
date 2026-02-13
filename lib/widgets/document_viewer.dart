import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_admin_service.dart';
import 'field_editor.dart';

class DocumentViewer extends StatelessWidget {
  final String documentPath;
  final FirestoreAdminService service;
  final VoidCallback onDocumentDeleted;
  final VoidCallback? onBackToSearch;
  final String? searchTerm;

  const DocumentViewer({
    super.key,
    required this.documentPath,
    required this.service,
    required this.onDocumentDeleted,
    this.onBackToSearch,
    this.searchTerm,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: service.streamDocument(documentPath),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final doc = snapshot.data!;
        if (!doc.exists) {
          return const Center(
            child: Text('Document does not exist'),
          );
        }

        final data = doc.data() ?? {};

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button (if coming from search or query results)
            if (onBackToSearch != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onBackToSearch,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: Text(
                          'Back to Results${searchTerm != null ? ': $searchTerm' : ''}',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: onBackToSearch != null
                    ? BorderRadius.zero
                    : const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.id,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          documentPath,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add Field',
                    onPressed: () => _showAddFieldDialog(context),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    tooltip: 'Delete Document',
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Fields table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: const Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: Text(
                      'Field',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      'Type',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Value',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(width: 80),
                ],
              ),
            ),
            const Divider(height: 1),
            // Fields list
            Expanded(
              child: data.isEmpty
                  ? const Center(
                      child: Text('No fields in this document'),
                    )
                  : ListView.separated(
                      itemCount: data.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = data.entries.elementAt(index);
                        return _buildFieldRow(context, entry.key, entry.value);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFieldRow(BuildContext context, String fieldName, dynamic value) {
    final fieldType = FirestoreAdminService.getFieldType(value);
    final displayValue = FirestoreAdminService.formatValue(value);
    final isEditable = ['string', 'number', 'boolean', 'null'].contains(fieldType);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              fieldName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 100,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getTypeColor(fieldType).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                fieldType,
                style: TextStyle(
                  fontSize: 12,
                  color: _getTypeColor(fieldType),
                ),
              ),
            ),
          ),
          Expanded(
            child: fieldType == 'map' || fieldType == 'array'
                ? _buildNestedValue(context, value, fieldType)
                : SelectableText(
                    displayValue,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: _getValueColor(context, value),
                    ),
                  ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isEditable)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: 'Edit',
                    onPressed: () => _editField(context, fieldName, value, fieldType),
                  ),
                IconButton(
                  icon: Icon(Icons.delete, size: 18, color: Theme.of(context).colorScheme.error),
                  tooltip: 'Delete Field',
                  onPressed: () => _deleteField(context, fieldName),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNestedValue(BuildContext context, dynamic value, String type, {int depth = 0}) {
    if (type == 'array' && value is List) {
      return ExpansionTile(
        title: Text('[${value.length} items]'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.only(left: 16.0 + (depth * 8)),
        children: value.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final itemType = FirestoreAdminService.getFieldType(item);
          final isNested = itemType == 'map' || itemType == 'array';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 50,
                  child: Text('[$index]', style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _getTypeColor(itemType).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    itemType,
                    style: TextStyle(fontSize: 11, color: _getTypeColor(itemType)),
                  ),
                ),
                Expanded(
                  child: isNested
                      ? _buildNestedValue(context, item, itemType, depth: depth + 1)
                      : Text(
                          FirestoreAdminService.formatValue(item),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: _getValueColor(context, item),
                          ),
                        ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    if (type == 'map' && value is Map) {
      return ExpansionTile(
        title: Text('{${value.length} fields}'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.only(left: 16.0 + (depth * 8)),
        children: value.entries.map((entry) {
          final itemType = FirestoreAdminService.getFieldType(entry.value);
          final isNested = itemType == 'map' || itemType == 'array';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 150,
                  child: Text(entry.key.toString(), style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _getTypeColor(itemType).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    itemType,
                    style: TextStyle(fontSize: 11, color: _getTypeColor(itemType)),
                  ),
                ),
                Expanded(
                  child: isNested
                      ? _buildNestedValue(context, entry.value, itemType, depth: depth + 1)
                      : Text(
                          FirestoreAdminService.formatValue(entry.value),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: _getValueColor(context, entry.value),
                          ),
                        ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return Text(FirestoreAdminService.formatValue(value));
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'string':
        return Colors.green;
      case 'number':
        return Colors.blue;
      case 'boolean':
        return Colors.purple;
      case 'timestamp':
        return Colors.orange;
      case 'geopoint':
        return Colors.teal;
      case 'reference':
        return Colors.indigo;
      case 'array':
        return Colors.pink;
      case 'map':
        return Colors.brown;
      case 'null':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getValueColor(BuildContext context, dynamic value) {
    if (value == null) return Colors.grey;
    if (value is bool) return Colors.purple;
    if (value is num) return Colors.blue;
    if (value is String) return Colors.green.shade700;
    return Theme.of(context).colorScheme.onSurface;
  }

  void _editField(BuildContext context, String fieldName, dynamic currentValue, String fieldType) {
    showDialog(
      context: context,
      builder: (context) => FieldEditor(
        fieldName: fieldName,
        currentValue: currentValue,
        fieldType: fieldType,
        onSave: (newValue) async {
          await service.updateField(documentPath, fieldName, newValue);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _deleteField(BuildContext context, String fieldName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Field'),
        content: Text('Are you sure you want to delete the field "$fieldName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await service.updateField(documentPath, fieldName, FieldValue.delete());
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete this document?\n\nPath: $documentPath'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await service.deleteDocument(documentPath);
              onDocumentDeleted();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddFieldDialog(BuildContext context) {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    String selectedType = 'string';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Field'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Field Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'string', child: Text('string')),
                  DropdownMenuItem(value: 'number', child: Text('number')),
                  DropdownMenuItem(value: 'boolean', child: Text('boolean')),
                  DropdownMenuItem(value: 'null', child: Text('null')),
                ],
                onChanged: (value) {
                  setState(() => selectedType = value!);
                },
              ),
              const SizedBox(height: 16),
              if (selectedType != 'null' && selectedType != 'boolean')
                TextField(
                  controller: valueController,
                  decoration: InputDecoration(
                    labelText: 'Value',
                    border: const OutlineInputBorder(),
                    hintText: selectedType == 'number' ? 'Enter a number' : 'Enter text',
                  ),
                  keyboardType: selectedType == 'number'
                      ? TextInputType.number
                      : TextInputType.text,
                ),
              if (selectedType == 'boolean')
                SwitchListTile(
                  title: const Text('Value'),
                  value: valueController.text == 'true',
                  onChanged: (value) {
                    setState(() {
                      valueController.text = value.toString();
                    });
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final fieldName = nameController.text.trim();
                if (fieldName.isEmpty) return;

                dynamic value;
                switch (selectedType) {
                  case 'string':
                    value = valueController.text;
                    break;
                  case 'number':
                    value = num.tryParse(valueController.text) ?? 0;
                    break;
                  case 'boolean':
                    value = valueController.text == 'true';
                    break;
                  case 'null':
                    value = null;
                    break;
                }

                Navigator.pop(context);
                await service.updateField(documentPath, fieldName, value);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
