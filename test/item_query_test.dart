import 'package:data_registration/models/dynamic_item.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:data_registration/services/item_query.dart';
import 'package:flutter_test/flutter_test.dart';

final _table = TableDefinition(
  id: 1,
  name: 'People',
  fields: [
    FieldDefinition(name: 'Name', type: 'text'),
    FieldDefinition(name: 'Age', type: 'integer'),
    FieldDefinition(name: 'Tags', type: 'text', isList: true),
  ],
);

DynamicItem _p(
  int id,
  String name,
  dynamic age, [
  List<String> tags = const [],
]) => DynamicItem(
  id: id,
  tableId: 1,
  fields: {'Name': name, 'Age': age, 'Tags': tags},
);

final _items = [
  _p(1, 'Charlie', 30, ['vip']),
  _p(2, 'alice', 9),
  _p(3, 'Bob', ''),
  _p(4, 'Dave', 100, ['vip', 'late']),
];

List<int> _ids(ItemQuery q) =>
    q.apply(_table, _items).map((i) => i.id!).toList();

void main() {
  test('default query returns everything in order', () {
    expect(_ids(const ItemQuery()), [1, 2, 3, 4]);
    expect(const ItemQuery().isActive, isFalse);
  });

  test('search is case-insensitive and spans all fields incl. lists', () {
    expect(_ids(const ItemQuery(search: 'ALI')), [2]);
    expect(_ids(const ItemQuery(search: 'late')), [4]);
    expect(_ids(const ItemQuery(search: '100')), [4]);
    expect(_ids(const ItemQuery(search: 'zzz')), isEmpty);
  });

  test('per-field filters are ANDed with each other and with search', () {
    expect(_ids(const ItemQuery(filters: {'Tags': 'vip'})), [1, 4]);
    expect(_ids(const ItemQuery(filters: {'Tags': 'vip', 'Name': 'dav'})), [4]);
    expect(
      _ids(const ItemQuery(search: 'char', filters: {'Tags': 'late'})),
      isEmpty,
    );
    expect(const ItemQuery(filters: {'Name': '  '}).activeFilterCount, 0);
  });

  test('numeric fields sort numerically, not as text', () {
    // as text, "100" < "30" < "9"
    expect(_ids(const ItemQuery(sortField: 'Age')), [2, 1, 4, 3]);
  });

  test('descending reverses order but empties stay last', () {
    expect(_ids(const ItemQuery(sortField: 'Age', ascending: false)), [
      4,
      1,
      2,
      3,
    ]);
  });

  test('text sort ignores case and is stable for ties', () {
    expect(_ids(const ItemQuery(sortField: 'Name')), [2, 3, 1, 4]);
    final ties = [_p(1, 'x', 5), _p(2, 'x', 5), _p(3, 'x', 5)];
    final out = const ItemQuery(sortField: 'Age').apply(_table, ties);
    expect(out.map((i) => i.id), [1, 2, 3]);
  });

  test('toggleSort cycles asc -> desc -> off and resets on a new field', () {
    var q = const ItemQuery().toggleSort('Age');
    expect((q.sortField, q.ascending), ('Age', true));
    q = q.toggleSort('Age');
    expect((q.sortField, q.ascending), ('Age', false));
    q = q.toggleSort('Age');
    expect(q.sortField, isNull);
    q = const ItemQuery(sortField: 'Age', ascending: false).toggleSort('Name');
    expect((q.sortField, q.ascending), ('Name', true));
  });
}
