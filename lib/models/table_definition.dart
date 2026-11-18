class TableDefinition {
  int? id;
  String name;
  List<FieldDefinition> fields;

  TableDefinition({this.id, required this.name, required this.fields});
}

class FieldDefinition {
  String name;
  String type;
  bool isList; // Indicates if the field stores a list of values
  List<String>? subfields; // Optional subfields for fields like "Degree"

  /// A value must be provided.
  bool required;

  /// No two rows may hold the same value (case-insensitive for text).
  bool unique;

  /// Pre-filled for new rows, and used by import when a cell is empty.
  String? defaultValue;

  /// For `integer`: smallest / largest allowed value.
  /// For text-like types: minimum / maximum length.
  num? min;
  num? max;

  /// Regular expression a text value must fully match.
  String? pattern;

  FieldDefinition({
    required this.name,
    required this.type,
    this.isList = false,
    this.subfields,
    this.required = false,
    this.unique = false,
    this.defaultValue,
    this.min,
    this.max,
    this.pattern,
  });

  /// Unique / min / max / pattern / default only make sense for plain
  /// single-value text and number fields.
  bool get supportsRules =>
      !isList &&
      subfields == null &&
      const {'text', 'integer', 'email'}.contains(type);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'isList': isList,
      'subfields': subfields,
      'required': required,
      'unique': unique,
      'defaultValue': defaultValue,
      'min': min,
      'max': max,
      'pattern': pattern,
    };
  }

  factory FieldDefinition.fromMap(Map<String, dynamic> map) {
    return FieldDefinition(
      name: map['name'],
      type: map['type'],
      isList: map['isList'] ?? false,
      subfields: map['subfields'] != null
          ? List<String>.from(map['subfields'])
          : null,
      // Older saved tables have none of these keys.
      required: map['required'] ?? false,
      unique: map['unique'] ?? false,
      defaultValue: map['defaultValue'],
      min: map['min'],
      max: map['max'],
      pattern: map['pattern'],
    );
  }
}
