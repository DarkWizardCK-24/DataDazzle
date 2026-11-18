import 'package:flutter/material.dart';
import 'package:data_registration/services/field_validator.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:data_registration/services/data_store.dart';
import 'package:data_registration/utils/responsive.dart';

class TableFormScreen extends StatefulWidget {
  final TableDefinition? table;

  /// Open the first rule-bearing field's "Rules" section (demo screenshots).
  final bool expandRules;

  const TableFormScreen({super.key, this.table, this.expandRules = false});

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
    'pdf',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.table != null) {
      _nameController.text = widget.table!.name;
      for (var field in widget.table!.fields) {
        _fields.add(_newFieldMap(field));
      }
    } else {
      _fields.add(_newFieldMap());
    }
  }

  /// Editing state for one field row; seeded from [field] when editing.
  Map<String, dynamic> _newFieldMap([FieldDefinition? field]) {
    String fmt(num? n) =>
        n == null ? '' : (n == n.truncate() ? '${n.toInt()}' : '$n');
    return {
      'name': TextEditingController(text: field?.name ?? ''),
      'type': field?.type ?? 'text',
      'isList': field?.isList ?? false,
      'subfields': field?.subfields != null
          ? List<TextEditingController>.generate(
              field!.subfields!.length,
              (i) => TextEditingController(text: field.subfields![i]),
            )
          : [],
      'required': field?.required ?? false,
      'unique': field?.unique ?? false,
      'default': TextEditingController(text: field?.defaultValue ?? ''),
      'min': TextEditingController(text: fmt(field?.min)),
      'max': TextEditingController(text: fmt(field?.max)),
      'pattern': TextEditingController(text: field?.pattern ?? ''),
    };
  }

  bool _supportsRules(Map<String, dynamic> f) =>
      !f['isList'] &&
      f['subfields'].isEmpty &&
      const {'text', 'integer', 'email'}.contains(f['type']);

  InputDecoration _ruleDecoration(String label, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white),
        hintStyle: const TextStyle(color: Colors.white38),
        isDense: true,
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white70),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      );

  String? _numberOrEmpty(String? v) =>
      (v == null || v.trim().isEmpty || num.tryParse(v.trim()) != null)
      ? null
      : 'Enter a number';

  /// Required / unique / default / min-max / pattern settings for one field.
  Widget _rulesSection(Map<String, dynamic> field, {bool expanded = false}) {
    final isInt = field['type'] == 'integer';
    final rules = _supportsRules(field);
    final active =
        field['required'] ||
        (rules &&
            (field['unique'] ||
                field['default'].text.isNotEmpty ||
                field['min'].text.isNotEmpty ||
                field['max'].text.isNotEmpty ||
                field['pattern'].text.isNotEmpty));
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: expanded,
        tilePadding: EdgeInsets.zero,
        iconColor: Colors.white,
        collapsedIconColor: Colors.white70,
        title: Text(
          active ? 'Rules (set)' : 'Rules',
          style: TextStyle(color: active ? Colors.amber : Colors.white70),
        ),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Required',
              style: TextStyle(color: Colors.white),
            ),
            value: field['required'],
            onChanged: (v) => setState(() => field['required'] = v),
          ),
          if (rules) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Unique',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'No two rows may share a value',
                style: TextStyle(color: Colors.white54),
              ),
              value: field['unique'],
              onChanged: (v) => setState(() => field['unique'] = v),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: field['default'],
              style: const TextStyle(color: Colors.white),
              decoration: _ruleDecoration('Default value'),
              keyboardType: isInt ? TextInputType.number : null,
              validator: (v) {
                if (isInt && v != null && v.trim().isNotEmpty) {
                  if (int.tryParse(v.trim()) == null) {
                    return 'Enter a whole number';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: field['min'],
                    style: const TextStyle(color: Colors.white),
                    decoration: _ruleDecoration(
                      isInt ? 'Min value' : 'Min length',
                    ),
                    keyboardType: TextInputType.number,
                    validator: _numberOrEmpty,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: field['max'],
                    style: const TextStyle(color: Colors.white),
                    decoration: _ruleDecoration(
                      isInt ? 'Max value' : 'Max length',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final e = _numberOrEmpty(v);
                      if (e != null) return e;
                      final lo = num.tryParse(field['min'].text.trim());
                      final hi = num.tryParse((v ?? '').trim());
                      if (lo != null && hi != null && hi < lo) {
                        return 'Must be at least min';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            if (!isInt) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: field['pattern'],
                style: const TextStyle(color: Colors.white),
                decoration: _ruleDecoration(
                  'Pattern (regex)',
                  hint: r'e.g. [A-Z]{2}\d{4}',
                ),
                validator: (v) =>
                    FieldValidator.checkPattern((v ?? '').trim()) == null
                    ? null
                    : 'Invalid regular expression',
              ),
            ],
          ] else
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Unique, default, range and pattern apply to single-value '
                'text, integer and email fields.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (var field in _fields) {
      field['name'].dispose();
      for (final k in const ['default', 'min', 'max', 'pattern']) {
        field[k].dispose();
      }
      for (var subfield in field['subfields']) {
        subfield.dispose();
      }
    }
    super.dispose();
  }

  void _addField() {
    setState(() {
      _fields.add(_newFieldMap());
    });
  }

  void _removeField(int index) {
    setState(() {
      _fields[index]['name'].dispose();
      for (final k in const ['default', 'min', 'max', 'pattern']) {
        _fields[index][k].dispose();
      }
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
            .map(
              (entry) => FieldDefinition(
                name: entry.value['name'].text,
                type: entry.value['type'],
                isList: entry.value['isList'],
                subfields: entry.value['subfields'].isNotEmpty
                    ? entry.value['subfields'].map((c) => c.text).toList()
                    : null,
                required: entry.value['required'],
                // The remaining rules only apply to plain single-value fields.
                unique: _supportsRules(entry.value) && entry.value['unique'],
                defaultValue:
                    _supportsRules(entry.value) &&
                        entry.value['default'].text.trim().isNotEmpty
                    ? entry.value['default'].text.trim()
                    : null,
                min: _supportsRules(entry.value)
                    ? num.tryParse(entry.value['min'].text.trim())
                    : null,
                max: _supportsRules(entry.value)
                    ? num.tryParse(entry.value['max'].text.trim())
                    : null,
                pattern:
                    _supportsRules(entry.value) &&
                        entry.value['type'] != 'integer' &&
                        entry.value['pattern'].text.trim().isNotEmpty
                    ? entry.value['pattern'].text.trim()
                    : null,
              ),
            )
            .toList(),
      );
      if (widget.table == null) {
        dataStore.createTable(table);
      } else {
        dataStore.updateTable(table);
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
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.black,
      ),
      body: Container(
        constraints: const BoxConstraints.expand(),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            child: MaxWidthBox(
              maxWidth: Breakpoints.formMaxWidth,
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Fields (${_fields.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._fields.asMap().entries.map((entry) {
                    int index = entry.key;
                    var field = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldRow(context, [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: field['name'],
                                  decoration: const InputDecoration(
                                    labelText: 'Field Name',
                                    labelStyle: TextStyle(color: Colors.white),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white,
                                      ),
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
                                      borderSide: BorderSide(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                  dropdownColor: Colors.grey[800],
                                  items: _fieldTypes.map((type) {
                                    return DropdownMenuItem(
                                      value: type,
                                      child: Text(
                                        type,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
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
                                icon: const Icon(
                                  Icons.arrow_upward,
                                  color: Colors.white,
                                ),
                                onPressed: () => _moveFieldUp(index),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_downward,
                                  color: Colors.white,
                                ),
                                onPressed: () => _moveFieldDown(index),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _removeField(index),
                              ),
                            ]),
                            _rulesSection(
                              field,
                              expanded: widget.expandRules && index == 1,
                            ),
                            Theme(
                              data: Theme.of(
                                context,
                              ).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                iconColor: Colors.white,
                                collapsedIconColor: Colors.white70,
                                title: Text(
                                  field['isList']
                                      ? 'List & subfields (list)'
                                      : field['subfields'].isNotEmpty
                                      ? 'List & subfields (${field['subfields'].length} subfields)'
                                      : 'List & subfields',
                                  style: TextStyle(
                                    color:
                                        field['isList'] ||
                                            field['subfields'].isNotEmpty
                                        ? Colors.amber
                                        : Colors.white70,
                                  ),
                                ),
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: field['isList'],
                                        onChanged: (value) {
                                          setState(() {
                                            field['isList'] = value!;
                                            if (value &&
                                                field['subfields'].isNotEmpty) {
                                              field['subfields'] = [];
                                            }
                                          });
                                        },
                                      ),
                                      const Text(
                                        'Is List',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  if (!field['isList'])
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Subfields (2-4)',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        ...field['subfields'].asMap().entries.map((
                                          subEntry,
                                        ) {
                                          int subIndex = subEntry.key;
                                          TextEditingController controller =
                                              subEntry.value;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    controller: controller,
                                                    decoration: InputDecoration(
                                                      labelText:
                                                          'Subfield ${subIndex + 1}',
                                                      labelStyle:
                                                          const TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                      enabledBorder:
                                                          const OutlineInputBorder(
                                                            borderSide:
                                                                BorderSide(
                                                                  color: Colors
                                                                      .white70,
                                                                ),
                                                          ),
                                                      focusedBorder:
                                                          const OutlineInputBorder(
                                                            borderSide:
                                                                BorderSide(
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                          ),
                                                    ),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                    validator: (value) {
                                                      if (value == null ||
                                                          value.isEmpty) {
                                                        return 'Please enter a subfield name';
                                                      }
                                                      final subfieldNames =
                                                          field['subfields']
                                                              .asMap()
                                                              .entries
                                                              .where(
                                                                (e) =>
                                                                    e.key !=
                                                                    subIndex,
                                                              )
                                                              .map(
                                                                (e) => e
                                                                    .value
                                                                    .text,
                                                              )
                                                              .toList();
                                                      if (subfieldNames
                                                          .contains(value)) {
                                                        return 'Subfield name must be unique';
                                                      }
                                                      return null;
                                                    },
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.redAccent,
                                                  ),
                                                  onPressed: () =>
                                                      _removeSubfield(
                                                        index,
                                                        subIndex,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                        if (field['subfields'].length < 4)
                                          ElevatedButton(
                                            onPressed: () =>
                                                _addSubfield(index),
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
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addField,
                      icon: const Icon(Icons.add),
                      label: const Text('Add field'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        widget.table == null ? 'Create table' : 'Save changes',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Field name, type and actions. On phones the name gets its own line so
  /// the inputs are not squeezed next to the three action buttons.
  Widget _fieldRow(BuildContext context, List<Widget> children) {
    if (!context.isCompact) return Row(children: children);
    final name = (children[0] as Expanded).child;
    return Column(
      children: [
        name,
        const SizedBox(height: 8),
        Row(children: children.sublist(2)),
      ],
    );
  }
}
