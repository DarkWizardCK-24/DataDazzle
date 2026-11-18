import 'package:data_registration/models/dynamic_item.dart';
import 'package:data_registration/models/table_definition.dart';

/// Search / sort / filter state for a table's rows. Pure Dart so it can be
/// unit-tested; the UI just holds one of these and calls [apply].
class ItemQuery {
  /// Free-text search across every field (case-insensitive substring).
  final String search;

  /// Field name to sort by, or null for insertion order.
  final String? sortField;
  final bool ascending;

  /// Per-field filters: field name -> case-insensitive substring.
  final Map<String, String> filters;

  const ItemQuery({
    this.search = '',
    this.sortField,
    this.ascending = true,
    this.filters = const {},
  });

  bool get hasSearch => search.trim().isNotEmpty;
  int get activeFilterCount =>
      filters.values.where((v) => v.trim().isNotEmpty).length;
  bool get isActive => hasSearch || activeFilterCount > 0;

  ItemQuery copyWith({
    String? search,
    String? sortField,
    bool clearSort = false,
    bool? ascending,
    Map<String, String>? filters,
  }) => ItemQuery(
    search: search ?? this.search,
    sortField: clearSort ? null : (sortField ?? this.sortField),
    ascending: ascending ?? this.ascending,
    filters: filters ?? this.filters,
  );

  /// Tapping a column header: asc -> desc -> unsorted.
  ItemQuery toggleSort(String field) {
    if (sortField != field) {
      return copyWith(sortField: field, ascending: true);
    }
    if (ascending) return copyWith(ascending: false);
    return copyWith(clearSort: true, ascending: true);
  }

  /// Text used for searching/filtering a field value. Lists are joined;
  /// images match on their file name only.
  static String textOf(dynamic value) {
    if (value == null) return '';
    if (value is List) return value.map(textOf).join(', ');
    return value.toString();
  }

  List<DynamicItem> apply(TableDefinition table, List<DynamicItem> items) {
    final needle = search.trim().toLowerCase();
    final active = {
      for (final e in filters.entries)
        if (e.value.trim().isNotEmpty) e.key: e.value.trim().toLowerCase(),
    };

    var out = items.where((item) {
      if (needle.isNotEmpty) {
        final hit = table.fields.any(
          (f) =>
              f.type != 'image' &&
              textOf(item.fields[f.name]).toLowerCase().contains(needle),
        );
        if (!hit) return false;
      }
      for (final e in active.entries) {
        if (!textOf(item.fields[e.key]).toLowerCase().contains(e.value)) {
          return false;
        }
      }
      return true;
    }).toList();

    final sf = sortField;
    if (sf != null) {
      // List.sort is not stable, so decorate with the original index.
      final indexed = [for (var i = 0; i < out.length; i++) (i, out[i])];
      indexed.sort((a, b) {
        final c = _compare(a.$2.fields[sf], b.$2.fields[sf]);
        if (c == 0) return a.$1.compareTo(b.$1);
        return c;
      });
      out = [for (final e in indexed) e.$2];
    }
    return out;
  }

  /// Empty values always sort last, whatever the direction.
  int _compare(dynamic a, dynamic b) {
    final ea = textOf(a).trim().isEmpty;
    final eb = textOf(b).trim().isEmpty;
    if (ea && eb) return 0;
    if (ea) return 1;
    if (eb) return -1;

    final na = a is num ? a : num.tryParse(textOf(a));
    final nb = b is num ? b : num.tryParse(textOf(b));
    int c;
    if (na != null && nb != null) {
      c = na.compareTo(nb);
    } else {
      c = textOf(a).toLowerCase().compareTo(textOf(b).toLowerCase());
    }
    return ascending ? c : -c;
  }
}
