import 'dart:io';
import 'package:data_registration/models/dynamic_item.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'data_store.dart';
import 'import_service.dart';

class FileHandler {
  /// Lets the user pick a CSV/XLSX/ODS file and imports it. Returns null if
  /// the picker was cancelled, otherwise a report of what was imported/skipped.
  Future<ImportResult?> importFile(int tableId, TableDefinition table) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'ods'],
    );
    final path = picked?.files.single.path;
    if (path == null) return null;

    final result = await ImportService().importFile(
      File(path),
      table,
      tableId,
      (src) => dataStore.saveImageFile(tableId, src),
      existing: await dataStore.getItems(tableId),
    );
    for (final item in result.items) {
      await dataStore.insertItem(item);
    }
    return result;
  }

  Future<String> exportToCsv(
    int tableId,
    TableDefinition table,
    List<DynamicItem> items,
  ) async {
    List<List<dynamic>> rows = [table.fields.map((f) => f.name).toList()];

    for (var item in items) {
      rows.add(
        table.fields.map((f) {
          final value = item.fields[f.name];
          if (f.isList || f.subfields != null) {
            return (value as List<dynamic>?)?.join(', ') ?? '';
          }
          return value ?? '';
        }).toList(),
      );
    }

    String csv = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, '${table.name}_export.csv');
    final file = File(path);
    await file.writeAsString(csv);
    return path;
  }

  Future<String> exportToXlsx(
    int tableId,
    TableDefinition table,
    List<DynamicItem> items,
  ) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Sheet1'];

    // Add headers
    List<String> headers = table.fields.map((f) => f.name).toList();
    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = TextCellValue(
        headers[i],
      );
    }

    // Add data rows
    for (var rowIndex = 0; rowIndex < items.length; rowIndex++) {
      var item = items[rowIndex];
      for (var colIndex = 0; colIndex < table.fields.length; colIndex++) {
        var field = table.fields[colIndex];
        var value = item.fields[field.name];
        if (field.type == 'image' && value != null && value.isNotEmpty) {
          try {
            final imageFile = field.isList
                ? File((value as List).first)
                : File(value);
            if (await imageFile.exists()) {
              sheet
                  .cell(
                    CellIndex.indexByColumnRow(
                      columnIndex: colIndex,
                      rowIndex: rowIndex + 1,
                    ),
                  )
                  .value = TextCellValue(
                field.isList ? value.join(', ') : value,
              );
            } else {
              sheet
                  .cell(
                    CellIndex.indexByColumnRow(
                      columnIndex: colIndex,
                      rowIndex: rowIndex + 1,
                    ),
                  )
                  .value = TextCellValue(
                'Image Not Found',
              );
            }
          } catch (e) {
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: colIndex,
                    rowIndex: rowIndex + 1,
                  ),
                )
                .value = TextCellValue(
              'Image Error',
            );
          }
        } else if ((field.isList || field.subfields != null) &&
            value != null &&
            value is List) {
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: colIndex,
                  rowIndex: rowIndex + 1,
                ),
              )
              .value = TextCellValue(
            value.join(', '),
          );
        } else {
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: colIndex,
                  rowIndex: rowIndex + 1,
                ),
              )
              .value = TextCellValue(
            value?.toString() ?? '',
          );
        }
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, '${table.name}_export.xlsx');
    final file = File(path);
    await file.writeAsBytes(excel.encode()!);
    return path;
  }
}
