import 'package:data_registration/models/dynamic_item.dart';
import 'package:data_registration/models/table_definition.dart';

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Row-level validation shared by the entry form and the importer, so both
/// enforce exactly the same rules.
class FieldValidator {
  /// Returns an error message, or null when [value] is acceptable.
  ///
  /// For `unique` fields, pass either [others] (the other rows' values, without
  /// the row being edited) or, for big batches, a pre-built [usedKeys] set of
  /// [uniqueKey]s, which is O(1) per check.
  static String? validate(
    FieldDefinition field,
    dynamic value, {
    Iterable<dynamic> others = const [],
    Set<String>? usedKeys,
  }) {
    // Lists / subfields / file fields: only "required" applies.
    if (!field.supportsRules) {
      if (field.required && _isEmpty(value)) return '${field.name} is required';
      return null;
    }

    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return field.required ? '${field.name} is required' : null;
    }

    switch (field.type) {
      case 'integer':
        final n = int.tryParse(text);
        if (n == null) return 'Enter a whole number';
        if (field.min != null && n < field.min!) {
          return 'Must be at least ${_fmt(field.min!)}';
        }
        if (field.max != null && n > field.max!) {
          return 'Must be at most ${_fmt(field.max!)}';
        }
      case 'email':
        if (!_emailRe.hasMatch(text)) return 'Enter a valid email';
        final e = _lengthError(field, text);
        if (e != null) return e;
      default:
        final e = _lengthError(field, text);
        if (e != null) return e;
    }

    final pattern = field.pattern;
    if (pattern != null && pattern.isNotEmpty) {
      try {
        if (!RegExp('^(?:$pattern)\$').hasMatch(text)) {
          return 'Does not match the required format';
        }
      } on FormatException {
        // A broken pattern must not block data entry; the builder rejects
        // invalid patterns, so this only guards hand-edited data.
      }
    }

    if (field.unique) {
      final key = uniqueKey(text);
      final taken = usedKeys != null
          ? usedKeys.contains(key)
          : others.any((o) => uniqueKey(o) == key);
      if (taken) return '"$text" already exists';
    }
    return null;
  }

  /// First error for each field of [item], keyed by field name.
  static Map<String, String> validateItem(
    TableDefinition table,
    Map<String, dynamic> fields,
    List<DynamicItem> existing, {
    int? ignoreId,
  }) {
    final errors = <String, String>{};
    final rest = existing.where((i) => i.id == null || i.id != ignoreId);
    for (final f in table.fields) {
      final err = validate(
        f,
        fields[f.name],
        others: f.unique ? rest.map((i) => i.fields[f.name]) : const [],
      );
      if (err != null) errors[f.name] = err;
    }
    return errors;
  }

  /// Returns null if [pattern] is a valid regular expression.
  static String? checkPattern(String pattern) {
    if (pattern.isEmpty) return null;
    try {
      RegExp(pattern);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  static String? _lengthError(FieldDefinition f, String text) {
    if (f.min != null && text.length < f.min!) {
      return 'Must be at least ${_fmt(f.min!)} characters';
    }
    if (f.max != null && text.length > f.max!) {
      return 'Must be at most ${_fmt(f.max!)} characters';
    }
    return null;
  }

  static bool _isEmpty(dynamic v) {
    if (v == null) return true;
    if (v is List) return v.every(_isEmpty);
    return v.toString().trim().isEmpty;
  }

  /// Normalised form of a value for uniqueness comparison.
  static String uniqueKey(dynamic v) =>
      (v?.toString() ?? '').trim().toLowerCase();

  static String _fmt(num n) => n == n.truncate() ? '${n.toInt()}' : '$n';
}
