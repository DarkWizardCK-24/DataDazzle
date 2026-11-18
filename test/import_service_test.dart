import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:data_registration/services/import_service.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

TableDefinition _table() => TableDefinition(
  id: 1,
  name: 'People',
  fields: [
    FieldDefinition(name: 'Name', type: 'text'),
    FieldDefinition(name: 'Age', type: 'integer'),
    FieldDefinition(name: 'Email', type: 'email'),
  ],
);

Future<String> _noImages(File f) async => f.path;

void main() {
  final svc = ImportService();

  test('maps columns by header, not position', () async {
    final grid = svc.parseCsv('Email,Name,Age\nann@x.com,Ann,30\n');
    final r = await svc.buildItems(grid, _table(), 1, _noImages);
    expect(r.imported, 1);
    expect(r.items.single.fields, {
      'Name': 'Ann',
      'Age': 30,
      'Email': 'ann@x.com',
    });
    expect(r.mappedByPosition, isFalse);
  });

  test(
    'header match is case-insensitive; extra columns are reported',
    () async {
      final grid = svc.parseCsv('name,AGE,Notes\nBob,41,hi\n');
      final r = await svc.buildItems(grid, _table(), 1, _noImages);
      expect(r.imported, 1);
      expect(r.ignoredColumns, ['Notes']);
      expect(r.missingFields, ['Email']);
    },
  );

  test('falls back to position when no header matches', () async {
    final grid = svc.parseCsv('a,b,c\nCy,22,cy@x.com\n');
    final r = await svc.buildItems(grid, _table(), 1, _noImages);
    expect(r.mappedByPosition, isTrue);
    expect(r.items.single.fields['Name'], 'Cy');
  });

  test('invalid rows are skipped with a reason and row number', () async {
    final grid = svc.parseCsv(
      'Name,Age,Email\n'
      'Ok,1,ok@x.com\n'
      'BadAge,abc,a@x.com\n'
      'BadMail,3,nope\n'
      ',,\n' // blank line is ignored silently
      'Float,7.0,f@x.com\n',
    );
    final r = await svc.buildItems(grid, _table(), 1, _noImages);
    expect(r.imported, 2);
    expect(r.skipped.length, 2);
    expect(r.skipped[0].row, 3);
    expect(r.skipped[0].reason, contains('Age'));
    expect(r.skipped[1].row, 4);
    expect(r.skipped[1].reason, contains('Email'));
    expect(r.items.last.fields['Age'], 7);
    expect(r.summary, startsWith('2 imported, 2 skipped'));
  });

  test('missing image file skips the row with a reason', () async {
    final t = TableDefinition(
      id: 1,
      name: 'Pics',
      fields: [FieldDefinition(name: 'Photo', type: 'image')],
    );
    final grid = svc.parseCsv('Photo\n/definitely/not/here.png\n');
    final r = await svc.buildItems(grid, t, 1, _noImages);
    expect(r.imported, 0);
    expect(r.skipped.single.reason, contains('image not found'));
  });

  test('empty file is reported, not silent', () async {
    final r = await svc.buildItems([], _table(), 1, _noImages);
    expect(r.skipped.single.reason, contains('empty'));
  });

  test('xlsx reads only the first sheet', () async {
    final excel = Excel.createExcel();
    final s1 = excel['Sheet1'];
    s1.appendRow([TextCellValue('Name'), TextCellValue('Age')]);
    s1.appendRow([TextCellValue('Ann'), IntCellValue(30)]);
    final s2 = excel['Other'];
    s2.appendRow([TextCellValue('Name'), TextCellValue('Age')]);
    s2.appendRow([TextCellValue('Zed'), IntCellValue(99)]);
    final grid = svc.parseXlsx(excel.encode()!);
    final r = await svc.buildItems(grid, _table(), 1, _noImages);
    expect(r.items.map((i) => i.fields['Name']), ['Ann']);
  });

  test('ods is parsed for real', () async {
    const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-content
  xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
  xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
  xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0">
 <office:body><office:spreadsheet>
  <table:table table:name="Sheet1">
   <table:table-row>
    <table:table-cell><text:p>Name</text:p></table:table-cell>
    <table:table-cell><text:p>Age</text:p></table:table-cell>
   </table:table-row>
   <table:table-row>
    <table:table-cell><text:p>Ann</text:p></table:table-cell>
    <table:table-cell table:number-columns-repeated="1"><text:p>30</text:p></table:table-cell>
   </table:table-row>
   <table:table-row table:number-rows-repeated="1048000">
    <table:table-cell table:number-columns-repeated="1024"/>
   </table:table-row>
  </table:table>
  <table:table table:name="Sheet2">
   <table:table-row><table:table-cell><text:p>ignored</text:p></table:table-cell></table:table-row>
  </table:table>
 </office:spreadsheet></office:body>
</office:document-content>''';
    final bytes = utf8.encode(xml);
    final archive = Archive()
      ..addFile(ArchiveFile('content.xml', bytes.length, bytes));
    final ods = ZipEncoder().encode(archive)!;

    final grid = svc.parseOds(ods);
    expect(grid.first, ['Name', 'Age']);
    final r = await svc.buildItems(grid, _table(), 1, _noImages);
    expect(r.items.single.fields['Name'], 'Ann');
    expect(r.items.single.fields['Age'], 30);
  });

  test('non-ods zip is rejected clearly', () {
    final archive = Archive()..addFile(ArchiveFile('x.txt', 1, [65]));
    final zip = ZipEncoder().encode(archive)!;
    expect(() => svc.parseOds(zip), throwsFormatException);
  });
}
