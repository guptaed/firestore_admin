import 'package:flutter/material.dart';

class FieldEditor extends StatefulWidget {
  final String fieldName;
  final dynamic currentValue;
  final String fieldType;
  final Function(dynamic) onSave;

  const FieldEditor({
    super.key,
    required this.fieldName,
    required this.currentValue,
    required this.fieldType,
    required this.onSave,
  });

  @override
  State<FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends State<FieldEditor> {
  late TextEditingController _controller;
  late String _selectedType;
  late bool _boolValue;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentValue?.toString() ?? '',
    );
    _selectedType = widget.fieldType;
    _boolValue = widget.currentValue == true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Field: ${widget.fieldName}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedType,
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
                setState(() {
                  _selectedType = value!;
                  if (_selectedType == 'boolean') {
                    _boolValue = _controller.text.toLowerCase() == 'true';
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedType == 'string')
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Value',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            if (_selectedType == 'number')
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Value',
                  border: OutlineInputBorder(),
                  hintText: 'Enter a number',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            if (_selectedType == 'boolean')
              SwitchListTile(
                title: const Text('Value'),
                subtitle: Text(_boolValue ? 'true' : 'false'),
                value: _boolValue,
                onChanged: (value) {
                  setState(() => _boolValue = value);
                },
              ),
            if (_selectedType == 'null')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Value will be set to null'),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current: ${widget.currentValue?.toString() ?? 'null'} (${widget.fieldType})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    dynamic newValue;

    switch (_selectedType) {
      case 'string':
        newValue = _controller.text;
        break;
      case 'number':
        final text = _controller.text;
        if (text.contains('.')) {
          newValue = double.tryParse(text) ?? 0.0;
        } else {
          newValue = int.tryParse(text) ?? 0;
        }
        break;
      case 'boolean':
        newValue = _boolValue;
        break;
      case 'null':
        newValue = null;
        break;
    }

    widget.onSave(newValue);
  }
}
