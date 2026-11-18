import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:data_registration/models/dynamic_item.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:data_registration/services/field_validator.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

/// Why a row was not imported.
class ImportIssue {
  /// Row number as the user sees it in their spreadsheet
  /// (the header is row 1, so the first data row is row 2).
  final int row;
  final String reason;
  const ImportIssue(this.row, this.reason);

  @override
  String toString() => 'Row $row: $reason';
}

class ImportResult {
  final List<DynamicItem> items;
  final List<ImportIssue> skipped;

  /// File columns that did not match any field and were ignored.
  final List<String> ignoredColumns;

  /// Table fields that had no matching column in the file.
  final List<String> missingFields;

  /// True when no header matched and columns were mapped by position.
  final bool mappedByPosition;

  const ImportResult({
    this.items = const [],
    this.skipped = const [],
    this.ignoredColumns = const [],
    this.missingFields = const [],
    this.mappedByPosition = false,
  });

  int get imported => items.length;

  String get summary {
    final b = StringBuffer(
      '${items.length} imported, ${skipped.length} skipped',
    );
    if (mappedByPosition) {
      b.write('\nNo column headers matched; columns were mapped by position.');
    }
    if (ignoredColumns.isNotEmpty) {
      b.write('\nIgnored columns: ${ignoredColumns.join(', ')}');
    }
    if (missingFields.isNotEmpty && !mappedByPosition) {
      b.write('\nFields not in file: ${missingFields.join(', ')}');
    }
    return b.toString();
  }
}

typedef ImageSaver = Future<String> Function(File source);

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
const supportedImageExtensions = ['jpg', 'png', 'jpeg', 'avif', 'webp'];

/// Parses CSV / XLSX / ODS into raw string grids and turns them into
/// validated [DynamicItem]s. Pure Dart apart from `dart:io` file access, so
/// it can be unit-tested without a device.
class ImportService {
  Future<ImportResult> importFile(
    File file,
    TableDefinition table,
    int tableId,
    ImageSaver saveImage, {
    List<DynamicItem> existing = const [],
  }) async {
    final ext = p.extension(file.path).replaceFirst('.', '').toLowerCase();
    final List<List<String>> grid;
    switch (ext) {
      case 'csv':
        grid = parseCsv(await file.readAsString());
      case 'xlsx':
        grid = parseXlsx(await file.readAsBytes());
      case 'ods':
        grid = parseOds(await file.readAsBytes());
      default:
        throw FormatException('Unsupported file type: .$ext');
    }
    return buildItems(grid, table, tableId, saveImage, existing: existing);
  }

  List<List<String>> parseCsv(String text) {
    if (text.startsWith('﻿')) text = text.substring(1); // strip BOM
    // Normalise CRLF / CR so LF-only and Windows files both parse.
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(text);
    return rows.map((r) => r.map((c) => c.toString()).toList()).toList();
  }

  /// Reads only the first sheet.
  List<List<String>> parseXlsx(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];
    final sheet = excel.tables.values.first;
    return sheet.rows
        .map((r) => r.map((c) => c?.value?.toString() ?? '').toList())
        .toList();
  }

  /// Reads only the first sheet of an OpenDocument spreadsheet.
  List<List<String>> parseOds(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('content.xml');
    if (entry == null) {
      throw const FormatException('Not a valid .ods file (no content.xml).');
    }
    final doc = XmlDocument.parse(utf8.decode(entry.content as List<int>));

    XmlElement? sheet;
    for (final e in doc.descendantElements) {
      if (e.name.local == 'table' && e.name.prefix == 'table') {
        sheet = e;
        break;
      }
    }
    if (sheet == null) {
      throw const FormatException('No sheet found in .ods file.');
    }

    int repeatOf(XmlElement e, String attr) =>
        int.tryParse(
          e.getAttribute(attr, namespace: null) ??
              e.attributes
                  .where((a) => a.name.local == attr)
                  .map((a) => a.value)
                  .firstOrNull ??
              '1',
        ) ??
        1;

    final rows = <List<String>>[];
    for (final row in sheet.childElements.where(
      (e) => e.name.local == 'table-row',
    )) {
      final cells = <String>[];
      for (final cell in row.childElements.where(
        (e) =>
            e.name.local == 'table-cell' ||
            e.name.local == 'covered-table-cell',
      )) {
        final repeat = repeatOf(cell, 'number-columns-repeated');
        final text = cell.childElements
            .where((e) => e.name.local == 'p')
            .map((e) => e.innerText)
            .join('\n');
        // Huge repeats are blank padding to the sheet edge; keep one cell.
        for (var i = 0; i < (repeat > 256 ? 1 : repeat); i++) {
          cells.add(text);
        }
      }
      final isBlank = cells.every((c) => c.isEmpty);
      final rowRepeat = isBlank
          ? 1
          : repeatOf(row, 'number-rows-repeated').clamp(1, 10000);
      for (var i = 0; i < rowRepeat; i++) {
        rows.add(List.of(cells));
      }
    }
    return rows;
  }

  /// Maps header names to fields, validates every row, and reports skips.
  Future<ImportResult> buildItems(
    List<List<String>> grid,
    TableDefinition table,
    int tableId,
    ImageSaver saveImage, {
    List<DynamicItem> existing = const [],
  }) async {
    if (grid.isEmpty) {
      return const ImportResult(skipped: [ImportIssue(1, 'File is empty')]);
    }
    final headers = grid.first.map((h) => h.trim()).toList();

    // field index -> column index
    final mapping = <int, int>{};
    for (var f = 0; f < table.fields.length; f++) {
      final name = table.fields[f].name.trim().toLowerCase();
      final col = headers.indexWhere((h) => h.toLowerCase() == name);
      if (col != -1) mapping[f] = col;
    }
    var byPosition = false;
    if (mapping.isEmpty) {
      byPosition = true;
      for (var f = 0; f < table.fields.length && f < headers.length; f++) {
        mapping[f] = f;
      }
    }

    final usedCols = mapping.values.toSet();
    final ignored = [
      for (var c = 0; c < headers.length; c++)
        if (!usedCols.contains(c) && headers[c].isNotEmpty) headers[c],
    ];
    final missing = [
      for (var f = 0; f < table.fields.length; f++)
        if (!mapping.containsKey(f)) table.fields[f].name,
    ];

    final items = <DynamicItem>[];
    final skipped = <ImportIssue>[];

    // Values already taken for unique fields: existing rows + rows accepted
    // earlier in this file.
    final usedKeys = <String, Set<String>>{
      for (final f in table.fields)
        if (f.unique)
          f.name: {
            for (final i in existing)
              if (FieldValidator.uniqueKey(i.fields[f.name]).isNotEmpty)
                FieldValidator.uniqueKey(i.fields[f.name]),
          },
    };

    for (var r = 1; r < grid.length; r++) {
      final row = grid[r];
      if (row.every((c) => c.trim().isEmpty)) continue; // blank line
      final fields = <String, dynamic>{};
      String? error;

      for (var f = 0; f < table.fields.length && error == null; f++) {
        final field = table.fields[f];
        final col = mapping[f];
        var raw = (col != null && col < row.length) ? row[col].trim() : '';
        if (raw.isEmpty && (field.defaultValue ?? '').isNotEmpty) {
          raw = field.defaultValue!;
        }
        try {
          final value = await _convert(field, raw, saveImage);
          final problem = FieldValidator.validate(
            field,
            value,
            usedKeys: usedKeys[field.name],
          );
          if (problem != null) throw _RowError(problem);
          fields[field.name] = value;
        } on _RowError catch (e) {
          error = '${field.name}: ${e.message}';
        }
      }

      if (error != null) {
        skipped.add(ImportIssue(r + 1, error));
      } else {
        for (final e in usedKeys.entries) {
          final k = FieldValidator.uniqueKey(fields[e.key]);
          if (k.isNotEmpty) e.value.add(k);
        }
        items.add(DynamicItem(tableId: tableId, fields: fields));
      }
    }

    return ImportResult(
      items: items,
      skipped: skipped,
      ignoredColumns: ignored,
      missingFields: missing,
      mappedByPosition: byPosition,
    );
  }

  Future<dynamic> _convert(
    FieldDefinition field,
    String value,
    ImageSaver saveImage,
  ) async {
    final isMulti = field.isList || field.subfields != null;
    List<String> parts() => value.isEmpty
        ? <String>[]
        : value
              .split(',')
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList();

    if (field.type == 'image') {
      if (value.isEmpty) return isMulti ? <String>[] : '';
      final saved = <String>[];
      for (final path in (isMulti ? parts() : [value])) {
        final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
        if (!supportedImageExtensions.contains(ext)) {
          throw _RowError('unsupported image type "$path"');
        }
        final src = File(path);
        if (!await src.exists()) {
          throw _RowError('image not found "$path"');
        }
        saved.add(await saveImage(src));
      }
      return isMulti ? saved : saved.first;
    }

    if (isMulti) {
      return parts().map((v) => _scalar(field.type, v)).toList();
    }
    if (value.isEmpty) return '';
    return _scalar(field.type, value);
  }

  dynamic _scalar(String type, String v) {
    switch (type) {
      case 'integer':
        final i = int.tryParse(v);
        if (i != null) return i;
        // Spreadsheets often render integers as "12.0".
        final d = double.tryParse(v);
        if (d != null && d == d.truncateToDouble()) return d.toInt();
        throw _RowError('"$v" is not a whole number');
      case 'email':
        if (!_emailRe.hasMatch(v)) throw _RowError('"$v" is not a valid email');
        return v;
      default:
        return v;
    }
  }
}

class _RowError implements Exception {
  final String message;
  _RowError(this.message);
}
