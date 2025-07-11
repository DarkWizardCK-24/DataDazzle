import 'package:flutter/material.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:data_registration/models/dynamic_item.dart';
import 'dart:io';

class DynamicItemCard extends StatelessWidget {
  final TableDefinition table;
  final DynamicItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DynamicItemCard({
    super.key,
    required this.table,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  Widget _buildFieldDisplay(FieldDefinition field) {
    final value = item.fields[field.name];
    if (field.type == 'image' && value != null && value.isNotEmpty) {
      try {
        final imagePath = field.isList ? (value as List).first : value;
        final imageFile = File(imagePath);
        if (imageFile.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              imageFile,
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Text(
                'Image not available',
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        } else {
          return const Text(
            'Image not found',
            style: TextStyle(color: Colors.red),
          );
        }
      } catch (e) {
        return const Text(
          'Invalid image data',
          style: TextStyle(color: Colors.red),
        );
      }
    } else if ((field.isList || field.subfields != null) && value != null && value is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          ...value.asMap().entries.map((entry) => Text(
                field.subfields != null
                    ? '${field.subfields![entry.key]}: ${entry.value}'
                    : '- ${entry.value}',
                style: const TextStyle(color: Colors.white70),
              )),
        ],
      );
    } else if (field.type == 'audio' || field.type == 'video' || field.type == 'excel' || field.type == 'pdf') {
      return Text(
        value?.isEmpty ?? true ? 'No file available' : 'File: $value',
        style: const TextStyle(color: Colors.white70),
      );
    }
    return Text(
      '${field.name}: ${value?.toString() ?? 'N/A'}',
      style: const TextStyle(color: Colors.white70),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
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
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    table.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...table.fields.map((field) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildFieldDisplay(field),
                      )),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
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
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...table.fields.take(2).map((field) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildFieldDisplay(field),
                )),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}