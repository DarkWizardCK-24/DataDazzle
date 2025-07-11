import 'package:data_registration/models/dynamic_item.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:data_registration/services/database_helper.dart';
import 'dart:io';

class DynamicItemForm extends StatefulWidget {
  final TableDefinition table;
  final DynamicItem? item;
  final Function(DynamicItem) onSubmit;

  const DynamicItemForm({
    super.key,
    required this.table,
    this.item,
    required this.onSubmit,
  });

  @override
  _DynamicItemFormState createState() => _DynamicItemFormState();
}

class _DynamicItemFormState extends State<DynamicItemForm> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic> _fields = {};
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _fields = Map.from(widget.item!.fields);
    } else {
      for (var field in widget.table.fields) {
        _fields[field.name] = field.isList || field.subfields != null ? [] : '';
      }
    }
  }

  Future<void> _pickFile(String fieldName, String type, {bool isList = false}) async {
    if (type == 'image') {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final imagePath = await DatabaseHelper.instance.saveImageFile(
            widget.table.id!, File(image.path));
        setState(() {
          if (isList) {
            _fields[fieldName] = [...(_fields[fieldName] ?? []), imagePath];
          } else {
            _fields[fieldName] = imagePath;
          }
        });
      }
    } else if (type == 'audio' || type == 'video' || type == 'excel' || type == 'pdf') {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: type == 'audio'
            ? ['mp3', 'wav']
            : type == 'video'
                ? ['mp4', 'mov']
                : type == 'excel'
                    ? ['xlsx']
                    : ['pdf'],
      );
      if (result != null) {
        setState(() {
          if (isList) {
            _fields[fieldName] = [...(_fields[fieldName] ?? []), result.files.single.path!];
          } else {
            _fields[fieldName] = result.files.single.path!;
          }
        });
      }
    }
  }

  Widget _buildFieldInput(FieldDefinition field) {
    if (field.isList || field.subfields != null) {
      // Handle list fields or fields with subfields
      List<dynamic> currentValues = _fields[field.name] ?? [];
      final isSubfield = field.subfields != null;
      final maxEntries = isSubfield ? field.subfields!.length : 10; // Arbitrary max for lists
      final minEntries = isSubfield ? field.subfields!.length : 0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          ...List.generate(
            isSubfield ? field.subfields!.length : currentValues.length + 1,
            (index) {
              if (index >= maxEntries) return Container();
              final controller = TextEditingController(
                text: index < currentValues.length ? currentValues[index].toString() : '',
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: field.type == 'image' ||
                              field.type == 'audio' ||
                              field.type == 'video' ||
                              field.type == 'excel' ||
                              field.type == 'pdf'
                          ? Text(
                              index < currentValues.length
                                  ? currentValues[index].isEmpty
                                      ? 'No file selected'
                                      : '${field.type} selected'
                                  : 'No file selected',
                              style: const TextStyle(color: Colors.white70),
                              overflow: TextOverflow.ellipsis,
                            )
                          : TextFormField(
                              controller: controller,
                              decoration: InputDecoration(
                                labelText: isSubfield ? field.subfields![index] : 'Entry ${index + 1}',
                                labelStyle: const TextStyle(color: Colors.white),
                                enabledBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white70),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white),
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                              onChanged: (value) {
                                setState(() {
                                  if (index < currentValues.length) {
                                    currentValues[index] = value;
                                  } else {
                                    currentValues.add(value);
                                  }
                                  _fields[field.name] = currentValues;
                                });
                              },
                            ),
                    ),
                    if (field.type == 'image' ||
                        field.type == 'audio' ||
                        field.type == 'video' ||
                        field.type == 'excel' ||
                        field.type == 'pdf')
                      ElevatedButton(
                        onPressed: () => _pickFile(field.name, field.type, isList: true),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.grey[800],
                        ),
                        child: const Text('Pick'),
                      ),
                    if (index < currentValues.length && !isSubfield)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () {
                          setState(() {
                            currentValues.removeAt(index);
                            _fields[field.name] = currentValues;
                          });
                        },
                      ),
                  ],
                ),
              );
            },
          ),
          if (!isSubfield && currentValues.length < maxEntries)
            ElevatedButton(
              onPressed: () {
                setState(() {
                  currentValues.add('');
                  _fields[field.name] = currentValues;
                });
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.grey[800],
              ),
              child: const Text('Add Entry'),
            ),
        ],
      );
    }

    // Handle single-value fields
    switch (field.type) {
      case 'integer':
        return TextFormField(
          initialValue: _fields[field.name]?.toString() ?? '',
          decoration: InputDecoration(
            labelText: field.name,
            labelStyle: const TextStyle(color: Colors.white),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white70),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          onChanged: (value) => _fields[field.name] = int.tryParse(value) ?? '',
        );
      case 'email':
        return TextFormField(
          initialValue: _fields[field.name]?.toString() ?? '',
          decoration: InputDecoration(
            labelText: field.name,
            labelStyle: const TextStyle(color: Colors.white),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white70),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.emailAddress,
          onChanged: (value) => _fields[field.name] = value,
        );
      case 'date':
        return TextFormField(
          initialValue: _fields[field.name]?.toString() ?? '',
          decoration: InputDecoration(
            labelText: field.name,
            labelStyle: const TextStyle(color: Colors.white),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white70),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
          style: const TextStyle(color: Colors.white),
          onTap: () async {
            DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() {
                _fields[field.name] = picked.toIso8601String();
              });
            }
          },
          readOnly: true,
        );
      case 'image':
      case 'audio':
      case 'video':
      case 'excel':
      case 'pdf':
        return Row(
          children: [
            Expanded(
              child: Text(
                _fields[field.name].isEmpty ? 'No file selected' : '${field.type} selected',
                style: const TextStyle(color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ElevatedButton(
              onPressed: () => _pickFile(field.name, field.type),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.grey[800],
              ),
              child: const Text('Pick File'),
            ),
          ],
        );
      default:
        return TextFormField(
          initialValue: _fields[field.name]?.toString() ?? '',
          decoration: InputDecoration(
            labelText: field.name,
            labelStyle: const TextStyle(color: Colors.white),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white70),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (value) => _fields[field.name] = value,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
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
            mainAxisSize: MainAxisSize.min,
            children: [
              ...widget.table.fields.map((field) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildFieldInput(field),
                  )),
              ElevatedButton(
                onPressed: () {
                  widget.onSubmit(DynamicItem(
                    id: widget.item?.id,
                    tableId: widget.table.id!,
                    fields: _fields,
                  ));
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.grey[800],
                ),
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}