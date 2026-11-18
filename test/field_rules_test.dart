import 'dart:io';

import 'package:data_registration/models/dynamic_item.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:data_registration/services/field_validator.dart';
import 'package:data_registration/services/import_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:data_registration/widgets/dynamic_item_form.dart';

Future<String> _noImages(File f) async => f.path;

void main() {
  group('FieldValidator', () {
    test('required', () {
      final f = FieldDefinition(name: 'Name', type: 'text', required: true);
      expect(FieldValidator.validate(f, ''), 'Name is required');
      expect(FieldValidator.validate(f, '   '), 'Name is required');
      expect(FieldValidator.validate(f, null), 'Name is required');
      expect(FieldValidator.validate(f, 'x'), isNull);
      // optional + empty is fine
      expect(
        FieldValidator.validate(FieldDefinition(name: 'N', type: 'text'), ''),
        isNull,
      );
    });

    test('required applies to lists and files too', () {
      final list = FieldDefinition(
        name: 'Tags',
        type: 'text',
        isList: true,
        required: true,
      );
      expect(FieldValidator.validate(list, []), isNotNull);
      expect(FieldValidator.validate(list, ['', ' ']), isNotNull);
      expect(FieldValidator.validate(list, ['a']), isNull);
      final img = FieldDefinition(name: 'Pic', type: 'image', required: true);
      expect(FieldValidator.validate(img, ''), isNotNull);
      expect(FieldValidator.validate(img, '/p.png'), isNull);
    });

    test('integer min / max', () {
      final f = FieldDefinition(name: 'Age', type: 'integer', min: 18, max: 65);
      expect(FieldValidator.validate(f, 17), 'Must be at least 18');
      expect(FieldValidator.validate(f, 66), 'Must be at most 65');
      expect(FieldValidator.validate(f, 18), isNull);
      expect(FieldValidator.validate(f, '65'), isNull);
      expect(FieldValidator.validate(f, 'abc'), 'Enter a whole number');
    });

    test('text length and email', () {
      final t = FieldDefinition(name: 'Code', type: 'text', min: 2, max: 4);
      expect(FieldValidator.validate(t, 'a'), contains('at least 2'));
      expect(FieldValidator.validate(t, 'abcde'), contains('at most 4'));
      expect(FieldValidator.validate(t, 'abc'), isNull);
      final e = FieldDefinition(name: 'Mail', type: 'email');
      expect(FieldValidator.validate(e, 'nope'), 'Enter a valid email');
      expect(FieldValidator.validate(e, 'a@b.co'), isNull);
    });

    test('pattern must match the whole value', () {
      final f = FieldDefinition(
        name: 'Code',
        type: 'text',
        pattern: r'[A-Z]{2}\d{2}',
      );
      expect(FieldValidator.validate(f, 'AB12'), isNull);
      expect(FieldValidator.validate(f, 'AB123'), isNotNull); // not a prefix
      expect(FieldValidator.validate(f, 'xAB12'), isNotNull);
      // alternation is anchored as a whole, not per branch
      final alt = FieldDefinition(name: 'A', type: 'text', pattern: 'cat|dog');
      expect(FieldValidator.validate(alt, 'cat'), isNull);
      expect(FieldValidator.validate(alt, 'catdog'), isNotNull);
    });

    test('unique is case-insensitive and ignores the row being edited', () {
      final f = FieldDefinition(name: 'Id', type: 'text', unique: true);
      expect(
        FieldValidator.validate(f, 'ABC', others: ['abc', 'x']),
        '"ABC" already exists',
      );
      expect(FieldValidator.validate(f, 'new', others: ['abc']), isNull);

      final table = TableDefinition(id: 1, name: 'T', fields: [f]);
      final rows = [
        DynamicItem(id: 1, tableId: 1, fields: {'Id': 'a'}),
        DynamicItem(id: 2, tableId: 1, fields: {'Id': 'b'}),
      ];
      // editing row 1 and keeping its own value is allowed
      expect(
        FieldValidator.validateItem(table, {'Id': 'a'}, rows, ignoreId: 1),
        isEmpty,
      );
      // changing row 1 to row 2's value is not
      expect(
        FieldValidator.validateItem(table, {'Id': 'B'}, rows, ignoreId: 1),
        contains('Id'),
      );
    });

    test('invalid pattern detected by checkPattern', () {
      expect(FieldValidator.checkPattern('[a-'), isNotNull);
      expect(FieldValidator.checkPattern(r'\d+'), isNull);
      expect(FieldValidator.checkPattern(''), isNull);
    });
  });

  group('FieldDefinition serialisation', () {
    test('round-trips rules', () {
      final f = FieldDefinition(
        name: 'Age',
        type: 'integer',
        required: true,
        unique: true,
        defaultValue: '18',
        min: 0,
        max: 120,
        pattern: 'x',
      );
      final g = FieldDefinition.fromMap(f.toMap());
      expect(
        (g.required, g.unique, g.defaultValue, g.min, g.max, g.pattern),
        (true, true, '18', 0, 120, 'x'),
      );
    });

    test('tables saved before rules existed still load', () {
      final g = FieldDefinition.fromMap({'name': 'Old', 'type': 'text'});
      expect(g.required, isFalse);
      expect(g.unique, isFalse);
      expect(g.defaultValue, isNull);
    });
  });

  group('import enforces rules', () {
    final svc = ImportService();
    final table = TableDefinition(
      id: 1,
      name: 'T',
      fields: [
        FieldDefinition(
          name: 'Code',
          type: 'text',
          required: true,
          unique: true,
        ),
        FieldDefinition(
          name: 'Qty',
          type: 'integer',
          min: 1,
          defaultValue: '5',
        ),
        FieldDefinition(name: 'Status', type: 'text', defaultValue: 'new'),
      ],
    );

    test('required, min, default and unique within the file', () async {
      final grid = svc.parseCsv(
        'Code,Qty,Status\n'
        'A1,,\n' // ok: Qty->5, Status->new
        ',3,x\n' // missing required Code
        'A1,2,y\n' // duplicate of row above
        'B2,0,z\n' // below min
        'b3,7,done\n',
      );
      final r = await svc.buildItems(grid, table, 1, _noImages);
      expect(r.items.map((i) => i.fields['Code']), ['A1', 'b3']);
      expect(r.items.first.fields['Qty'], 5);
      expect(r.items.first.fields['Status'], 'new');
      expect(r.skipped.map((s) => s.row), [3, 4, 5]);
      expect(r.skipped[0].reason, contains('required'));
      expect(r.skipped[1].reason, contains('already exists'));
      expect(r.skipped[2].reason, contains('at least 1'));
    });

    test('unique also checks rows already in the table', () async {
      final existing = [
        DynamicItem(
          id: 9,
          tableId: 1,
          fields: {'Code': 'A1', 'Qty': 1, 'Status': ''},
        ),
      ];
      final grid = svc.parseCsv('Code,Qty,Status\na1,2,x\nZ9,2,x\n');
      final r = await svc.buildItems(
        grid,
        table,
        1,
        _noImages,
        existing: existing,
      );
      expect(r.items.map((i) => i.fields['Code']), ['Z9']);
      expect(r.skipped.single.reason, contains('already exists'));
    });

    test('a column missing from the file still gets the default', () async {
      final grid = svc.parseCsv('Code\nQ1\n');
      final r = await svc.buildItems(grid, table, 1, _noImages);
      expect(r.items.single.fields['Qty'], 5);
    });
  });

  group('entry form', () {
    final table = TableDefinition(
      id: 1,
      name: 'T',
      fields: [
        FieldDefinition(
          name: 'Code',
          type: 'text',
          required: true,
          unique: true,
        ),
        FieldDefinition(
          name: 'Qty',
          type: 'integer',
          defaultValue: '5',
          min: 1,
        ),
      ],
    );
    final existing = [
      DynamicItem(id: 1, tableId: 1, fields: {'Code': 'taken', 'Qty': 1}),
    ];

    Future<DynamicItem?> pumpForm(
      WidgetTester tester,
      Future<void> Function() act,
    ) async {
      DynamicItem? submitted;
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicItemForm(
              table: table,
              existingItems: existing,
              onSubmit: (i) async => submitted = i,
            ),
          ),
        ),
      );
      await act();
      return submitted;
    }

    testWidgets(
      'blocks submit when required field is empty; prefills default',
      (tester) async {
        final submitted = await pumpForm(tester, () async {
          expect(find.text('5'), findsOneWidget); // default prefilled
          await tester.tap(find.text('Submit'));
          await tester.pump();
        });
        expect(submitted, isNull);
        expect(find.text('Code is required'), findsWidgets);
      },
    );

    testWidgets('blocks duplicate, then accepts a valid row', (tester) async {
      DynamicItem? submitted;
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicItemForm(
              table: table,
              existingItems: existing,
              onSubmit: (i) async => submitted = i,
            ),
          ),
        ),
      );
      final code = find.byType(TextFormField).first;
      await tester.enterText(code, 'TAKEN');
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(submitted, isNull);
      expect(find.text('"TAKEN" already exists'), findsWidgets);

      await tester.enterText(code, 'fresh');
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(submitted?.fields['Code'], 'fresh');
      expect(submitted?.fields['Qty'], 5);
    });
  });

  group('entry form regressions', () {
    Future<void> pump(
      WidgetTester tester,
      TableDefinition table,
      void Function(DynamicItem) onSubmit,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicItemForm(table: table, onSubmit: onSubmit),
          ),
        ),
      );
    }

    testWidgets('date field shows the picked date', (tester) async {
      final table = TableDefinition(
        id: 1,
        name: 'T',
        fields: [FieldDefinition(name: 'When', type: 'date')],
      );
      DynamicItem? got;
      await pump(tester, table, (i) => got = i);
      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // accept today's date
      await tester.pumpAndSettle();
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      // The text box must show the date without reopening the form.
      expect(find.text(today), findsOneWidget);
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(got?.fields['When'], today);
    });

    testWidgets('invalid integer / email block Submit', (tester) async {
      final table = TableDefinition(
        id: 1,
        name: 'T',
        fields: [
          FieldDefinition(name: 'Age', type: 'integer'),
          FieldDefinition(name: 'Mail', type: 'email'),
        ],
      );
      DynamicItem? got;
      await pump(tester, table, (i) => got = i);
      final boxes = find.byType(TextFormField);
      await tester.enterText(boxes.at(0), 'abc');
      await tester.enterText(boxes.at(1), 'not-an-email');
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(got, isNull);
      expect(find.text('Enter a whole number'), findsOneWidget);
      expect(find.text('Enter a valid email'), findsWidgets);

      await tester.enterText(boxes.at(0), '42');
      await tester.enterText(boxes.at(1), 'a@b.co');
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(got?.fields['Age'], 42);
    });
  });
}
