import 'package:data_registration/demo/demo_data_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bulk delete then undo restores rows with the same ids and order', () async {
    final store = DemoDataStore.instance;
    final table = (await store.getTables()).first;
    final before = await store.getItems(table.id!);
    expect(before.length, greaterThan(4));

    final doomed = [before[1], before[3]];
    await store.deleteItems([for (final r in doomed) r.id!]);
    final during = await store.getItems(table.id!);
    expect(during.length, before.length - 2);
    expect(during.any((r) => doomed.map((d) => d.id).contains(r.id)), isFalse);

    await store.restoreItems(doomed);
    final after = await store.getItems(table.id!);
    expect(after.map((r) => r.id), before.map((r) => r.id));
    expect(after[1].fields, before[1].fields);
  });

  test('deleting nothing is a no-op', () async {
    final store = DemoDataStore.instance;
    final table = (await store.getTables()).first;
    final n = (await store.getItems(table.id!)).length;
    await store.deleteItems([]);
    await store.restoreItems([]);
    expect((await store.getItems(table.id!)).length, n);
  });
}
