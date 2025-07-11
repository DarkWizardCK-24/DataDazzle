import 'package:flutter/material.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:data_registration/services/database_helper.dart';

class TableFormScreen extends StatefulWidget {
  final TableDefinition? table;

  const TableFormScreen({super.key, this.table});

  @override
  _TableFormScreenState createState() => _TableFormScreenState();
}

class _TableFormScreenState extends State<TableFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final List<Map<String, dynamic>> _fields = [];
  final List<String> _fieldTypes = [
    'text',
    'integer',
    'email',
    'date',
    'image',
    'audio',
    'video',
    'excel',
    'pdf'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.table != null) {
      _nameController.text = widget.table!.name;
      for (var field in widget.table!.fields) {
        _fields.add({
          'name': TextEditingController(text: field.name),
          'type': field.type,
          'isList': field.isList,
          'subfields': field.subfields != null
              ? List<TextEditingController>.generate(
                  field.subfields!.length, (i) => TextEditingController(text: field.subfields![i]))
              : [],
        });
      }
    } else {
      _fields.add({
        'name': TextEditingController(),
        'type': 'text',
        'isList': false,
        'subfields': [],
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (var field in _fields) {
      field['name'].dispose();
      for (var subfield in field['subfields']) {
        subfield.dispose();
      }
    }
    super.dispose();
  }

  void _addField() {
    setState(() {
      _fields.add({
        'name': TextEditingController(),
        'type': 'text',
        'isList': false,
        'subfields': [],
      });
    });
  }

  void _removeField(int index) {
    setState(() {
      _fields[index]['name'].dispose();
      for (var subfield in _fields[index]['subfields']) {
        subfield.dispose();
      }
      _fields.removeAt(index);
    });
  }

  void _moveFieldUp(int index) {
    if (index > 0) {
      setState(() {
        final temp = _fields[index];
        _fields[index] = _fields[index - 1];
        _fields[index - 1] = temp;
      });
    }
  }

  void _moveFieldDown(int index) {
    if (index < _fields.length - 1) {
      setState(() {
        final temp = _fields[index];
        _fields[index] = _fields[index + 1];
        _fields[index + 1] = temp;
      });
    }
  }

  void _addSubfield(int fieldIndex) {
    setState(() {
      if (_fields[fieldIndex]['subfields'].length < 4) {
        _fields[fieldIndex]['subfields'].add(TextEditingController());
      }
    });
  }

  void _removeSubfield(int fieldIndex, int subfieldIndex) {
    setState(() {
      if (_fields[fieldIndex]['subfields'].length > 2) {
        _fields[fieldIndex]['subfields'][subfieldIndex].dispose();
        _fields[fieldIndex]['subfields'].removeAt(subfieldIndex);
      }
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final table = TableDefinition(
        id: widget.table?.id,
        name: _nameController.text,
        fields: _fields
            .asMap()
            .entries
            .map((entry) => FieldDefinition(
                  name: entry.value['name'].text,
                  type: entry.value['type'],
                  isList: entry.value['isList'],
                  subfields: entry.value['subfields'].isNotEmpty
                      ? entry.value['subfields'].map((c) => c.text).toList()
                      : null,
                ))
            .toList(),
      );
      if (widget.table == null) {
        DatabaseHelper.instance.createTable(table);
      } else {
        DatabaseHelper.instance.updateTable(table);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.table == null ? 'Create Table' : 'Edit Table',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.black,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black,
              Color(0xFF212121),
              Color(0xFF424242),
              Color(0xFF616161),
              Color(0xFF757575),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.3, 0.5, 0.7, 1.0],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Table Name',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a table name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Fields',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ..._fields.asMap().entries.map((entry) {
                  int index = entry.key;
                  var field = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: field['name'],
                                decoration: const InputDecoration(
                                  labelText: 'Field Name',
                                  labelStyle: TextStyle(color: Colors.white),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white70),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white),
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a field name';
                                  }
                                  final fieldNames = _fields
                                      .asMap()
                                      .entries
                                      .where((e) => e.key != index)
                                      .map((e) => e.value['name'].text)
                                      .toList();
                                  if (fieldNames.contains(value)) {
                                    return 'Field name must be unique';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: field['type'],
                                decoration: const InputDecoration(
                                  labelText: 'Type',
                                  labelStyle: TextStyle(color: Colors.white),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white70),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white),
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
                                dropdownColor: Colors.grey[800],
                                items: _fieldTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(type, style: const TextStyle(color: Colors.white)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    field['type'] = value!;
                                  });
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_upward, color: Colors.white),
                              onPressed: () => _moveFieldUp(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_downward, color: Colors.white),
                              onPressed: () => _moveFieldDown(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _removeField(index),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: field['isList'],
                              onChanged: (value) {
                                setState(() {
                                  field['isList'] = value!;
                                  if (value && field['subfields'].isNotEmpty) {
                                    field['subfields'] = [];
                                  }
                                });
                              },
                            ),
                            const Text('Is List', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                        if (!field['isList'])
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Subfields (2-4)',
                                style: TextStyle(color: Colors.white),
                              ),
                              ...field['subfields'].asMap().entries.map((subEntry) {
                                int subIndex = subEntry.key;
                                TextEditingController controller = subEntry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: controller,
                                          decoration: InputDecoration(
                                            labelText: 'Subfield ${subIndex + 1}',
                                            labelStyle: const TextStyle(color: Colors.white),
                                            enabledBorder: const OutlineInputBorder(
                                              borderSide: BorderSide(color: Colors.white70),
                                            ),
                                            focusedBorder: const OutlineInputBorder(
                                              borderSide: BorderSide(color: Colors.white),
                                            ),
                                          ),
                                          style: const TextStyle(color: Colors.white),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Please enter a subfield name';
                                            }
                                            final subfieldNames = field['subfields']
                                                .asMap()
                                                .entries
                                                .where((e) => e.key != subIndex)
                                                .map((e) => e.value.text)
                                                .toList();
                                            if (subfieldNames.contains(value)) {
                                              return 'Subfield name must be unique';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                                        onPressed: () => _removeSubfield(index, subIndex),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              if (field['subfields'].length < 4)
                                ElevatedButton(
                                  onPressed: () => _addSubfield(index),
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.grey[800],
                                  ),
                                  child: const Text('Add Subfield'),
                                ),
                            ],
                          ),
                      ],
                    ),
                  );
                }),
                ElevatedButton(
                  onPressed: _addField,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.grey[800],
                  ),
                  child: const Text('Add Field'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.grey[800],
                  ),
                  child: Text(widget.table == null ? 'Create Table' : 'Update Table'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}