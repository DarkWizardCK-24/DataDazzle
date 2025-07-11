import 'dart:convert';
import 'dart:io';
import 'package:data_registration/models/dynamic_item.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';

class FileHandler {
  Future<void> importFile(int tableId, TableDefinition table) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'ods'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String fileExtension = file.path.split('.').last.toLowerCase();
      List<DynamicItem> items = [];

      if (fileExtension == 'csv') {
        items = await _parseCsv(file, table, tableId);
      } else if (fileExtension == 'xlsx') {
        items = await _parseXlsx(file, table, tableId);
      } else if (fileExtension == 'ods') {
        items = await _parseOds(file, table, tableId);
      }

      if (items.isEmpty) {
      }

      for (var item in items) {
        await DatabaseHelper.instance.insertItem(item);
      }
    }
  }

  Future<List<DynamicItem>> _parseCsv(File file, TableDefinition table, int tableId) async {
    final input = file.openRead();
    final fields = await input
        .transform(utf8.decoder)
        .transform(CsvToListConverter())
        .toList();

    List<DynamicItem> items = [];
    final supportedImageExtensions = ['jpg', 'png', 'jpeg', 'avif', 'webp'];

    for (var i = 1; i < fields.length; i++) {
      var row = fields[i];
      Map<String, dynamic> itemFields = {};
      bool isValidRow = true;

      for (var j = 0; j < table.fields.length && j < row.length; j++) {
        var field = table.fields[j];
        var value = row[j].toString();
        if (field.type == 'image' && value.isNotEmpty) {
          try {
            final imageFile = File(value);
            final extension = value.split('.').last.toLowerCase();
            if (await imageFile.exists() &&
                supportedImageExtensions.contains(extension)) {
              final newPath = await DatabaseHelper.instance.saveImageFile(tableId, imageFile);
              itemFields[field.name] = field.isList ? [newPath] : newPath;
            } else {
              itemFields[field.name] = field.isList ? [] : '';
              isValidRow = false;
            }
          } catch (e) {
            itemFields[field.name] = field.isList ? [] : '';
            isValidRow = false;
          }
        } else if ((field.isList || field.subfields != null) && value.isNotEmpty) {
          try {
            // Expect comma-separated values for lists/subfields
            final values = value.split(',').map((v) => v.trim()).toList();
            itemFields[field.name] = values;
          } catch (e) {
            itemFields[field.name] = [];
            isValidRow = false;
          }
        } else {
          itemFields[field.name] = value;
        }
      }

      if (isValidRow) {
        items.add(DynamicItem(tableId: tableId, fields: itemFields));
      }
    }
    return items;
  }

  Future<List<DynamicItem>> _parseXlsx(File file, TableDefinition table, int tableId) async {
    var bytes = file.readAsBytesSync();
    var excel = Excel.decodeBytes(bytes);
    List<DynamicItem> items = [];
    final supportedImageExtensions = ['jpg', 'png', 'jpeg', 'avif', 'webp'];

    for (var sheet in excel.tables.keys) {
      for (var row in excel.tables[sheet]!.rows.skip(1)) {
        Map<String, dynamic> itemFields = {};
        bool isValidRow = true;

        for (var j = 0; j < table.fields.length && j < row.length; j++) {
          var field = table.fields[j];
          var value = row[j]?.value?.toString() ?? '';
          if (field.type == 'image' && value.isNotEmpty) {
            try {
              final imageFile = File(value);
              final extension = value.split('.').last.toLowerCase();
              if (await imageFile.exists() &&
                  supportedImageExtensions.contains(extension)) {
                final newPath = await DatabaseHelper.instance.saveImageFile(tableId, imageFile);
                itemFields[field.name] = field.isList ? [newPath] : newPath;
              } else {
                itemFields[field.name] = field.isList ? [] : '';
                isValidRow = false;
              }
            } catch (e) {
              itemFields[field.name] = field.isList ? [] : '';
              isValidRow = false;
            }
          } else if ((field.isList || field.subfields != null) && value.isNotEmpty) {
            try {
              final values = value.split(',').map((v) => v.trim()).toList();
              itemFields[field.name] = values;
            } catch (e) {
              itemFields[field.name] = [];
              isValidRow = false;
            }
          } else {
            itemFields[field.name] = value;
          }
        }

        if (isValidRow) {
          items.add(DynamicItem(tableId: tableId, fields: itemFields));
        }
      }
    }
    return items;
  }

  Future<List<DynamicItem>> _parseOds(File file, TableDefinition table, int tableId) async {
    return _parseXlsx(file, table, tableId); // Placeholder
  }

  Future<String> exportToCsv(int tableId, TableDefinition table, List<DynamicItem> items) async {
    List<List<dynamic>> rows = [
      table.fields.map((f) => f.name).toList(),
    ];

    for (var item in items) {
      rows.add(table.fields.map((f) {
        final value = item.fields[f.name];
        if (f.isList || f.subfields != null) {
          return (value as List<dynamic>?)?.join(', ') ?? '';
        }
        return value ?? '';
      }).toList());
    }

    String csv = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/${table.name}_export.csv';
    final file = File(path);
    await file.writeAsString(csv);
    return path;
  }

  Future<String> exportToXlsx(int tableId, TableDefinition table, List<DynamicItem> items) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Sheet1'];

    // Add headers
    List<String> headers = table.fields.map((f) => f.name).toList();
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
    }

    // Add data rows
    for (var rowIndex = 0; rowIndex < items.length; rowIndex++) {
      var item = items[rowIndex];
      for (var colIndex = 0; colIndex < table.fields.length; colIndex++) {
        var field = table.fields[colIndex];
        var value = item.fields[field.name];
        if (field.type == 'image' && value != null && value.isNotEmpty) {
          try {
            final imageFile = field.isList ? File((value as List).first) : File(value);
            if (await imageFile.exists()) {
              sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex + 1)).value = TextCellValue(field.isList ? value.join(', ') : value);
            } else {
              sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex + 1)).value = TextCellValue('Image Not Found');
            }
          } catch (e) {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex + 1)).value = TextCellValue('Image Error');
          }
        } else if ((field.isList || field.subfields != null) && value != null && value is List) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex + 1)).value = TextCellValue(value.join(', '));
        } else {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex + 1)).value = TextCellValue(value?.toString() ?? '');
        }
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/${table.name}_export.xlsx';
    final file = File(path);
    await file.writeAsBytes(excel.encode()!);
    return path;
  }
}