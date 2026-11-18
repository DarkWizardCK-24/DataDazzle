import 'package:flutter/material.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:data_registration/models/dynamic_item.dart';
import 'dart:io';

class DynamicItemTable extends StatelessWidget {
  final TableDefinition table;
  final List<DynamicItem> items;
  final Function(DynamicItem) onEdit;
  final Function(int) onDelete;

  /// Field currently sorted by (null = unsorted) and direction.
  final String? sortField;
  final bool sortAscending;

  /// Called with the field name when a column header is tapped.
  final void Function(String field)? onSort;

  /// Multi-select. Checkboxes appear once [selectionMode] is true.
  final bool selectionMode;
  final Set<int> selectedIds;
  final void Function(DynamicItem item)? onToggleSelect;

  const DynamicItemTable({
    super.key,
    required this.table,
    required this.items,
    required this.onEdit,
    required this.onDelete,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.selectionMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
  });

  Widget _buildCell(FieldDefinition field, dynamic value) {
    if (field.type == 'image' && value != null && value.isNotEmpty) {
      try {
        final imagePath = field.isList ? (value as List).first : value;
        final imageFile = File(imagePath);
        if (imageFile.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              imageFile,
              height: 50,
              width: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Text('Image N/A', style: TextStyle(color: Colors.red)),
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
          'Invalid image',
          style: TextStyle(color: Colors.white),
        );
      }
    } else if ((field.isList || field.subfields != null) &&
        value != null &&
        value is List) {
      return Text(
        value.join(', '),
        style: const TextStyle(color: Colors.white),
      );
    }
    return Text(
      value?.toString() ?? 'N/A',
      style: const TextStyle(color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      // Scrolls both ways; on wide screens the table stretches to fill the width.
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 88),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                sortColumnIndex: sortField == null
                    ? null
                    : table.fields.indexWhere((f) => f.name == sortField),
                sortAscending: sortAscending,
                columns: [
                  ...table.fields
                      .map(
                        (field) => DataColumn(
                          onSort: onSort == null || field.type == 'image'
                              ? null
                              : (a, b) => onSort!(field.name),
                          label: Text(
                            field.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                  const DataColumn(
                    label: Text(
                      'Actions',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
                rows: items
                    .map(
                      (item) => DataRow(
                        selected: selectedIds.contains(item.id),
                        onSelectChanged: selectionMode
                            ? (_) => onToggleSelect?.call(item)
                            : null,
                        onLongPress: selectionMode
                            ? null
                            : () => onToggleSelect?.call(item),
                        cells: [
                          ...table.fields.map(
                            (field) => DataCell(
                              _buildCell(field, item.fields[field.name]),
                            ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => onEdit(item),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => onDelete(item.id!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
