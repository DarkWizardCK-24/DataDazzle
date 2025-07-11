class DynamicItem {
  final int? id;
  final int tableId;
  final Map<String, dynamic> fields;

  DynamicItem({this.id, required this.tableId, required this.fields});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tableId': tableId,
      'fields': fields,
    };
  }

  static DynamicItem fromMap(Map<String, dynamic> map) {
    return DynamicItem(
      id: map['id'],
      tableId: map['tableId'],
      fields: Map<String, dynamic>.from(map['fields']),
    );
  }
}