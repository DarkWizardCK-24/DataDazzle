class TableDefinition {
  int? id;
  String name;
  List<FieldDefinition> fields;

  TableDefinition({
    this.id,
    required this.name,
    required this.fields,
  });
}

class FieldDefinition {
  String name;
  String type;
  bool isList; // Indicates if the field stores a list of values
  List<String>? subfields; // Optional subfields for fields like "Degree"

  FieldDefinition({
    required this.name,
    required this.type,
    this.isList = false,
    this.subfields,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'isList': isList,
      'subfields': subfields,
    };
  }

  factory FieldDefinition.fromMap(Map<String, dynamic> map) {
    return FieldDefinition(
      name: map['name'],
      type: map['type'],
      isList: map['isList'] ?? false,
      subfields: map['subfields'] != null ? List<String>.from(map['subfields']) : null,
    );
  }
}