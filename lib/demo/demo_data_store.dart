import 'dart:io';

import 'package:data_registration/models/dynamic_item.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:data_registration/services/data_store.dart';

/// In-memory [DataStore] seeded with sample tables. Only used when the app is
/// built with `--dart-define=DEMO=true`; never touches sqflite or the file
/// system, so it works on the web.
class DemoDataStore implements DataStore {
  static final DemoDataStore instance = DemoDataStore._();

  DemoDataStore._() {
    _seed();
  }

  final List<TableDefinition> _tables = [];
  final List<DynamicItem> _items = [];
  int _nextTableId = 1;
  int _nextItemId = 1;

  /// Seeded tables, in display order.
  List<TableDefinition> get seededTables => List.unmodifiable(_tables);

  List<DynamicItem> itemsFor(int tableId) =>
      _items.where((i) => i.tableId == tableId).toList();

  // ---------------------------------------------------------------- DataStore
  @override
  Future<List<TableDefinition>> getTables() async => List.of(_tables);

  @override
  Future<void> createTable(TableDefinition table) async {
    _tables.add(
      TableDefinition(
        id: _nextTableId++,
        name: table.name,
        fields: table.fields,
      ),
    );
  }

  @override
  Future<void> updateTable(TableDefinition table) async {
    final i = _tables.indexWhere((t) => t.id == table.id);
    if (i >= 0) _tables[i] = table;
  }

  @override
  Future<void> deleteTable(int tableId) async {
    _tables.removeWhere((t) => t.id == tableId);
    _items.removeWhere((i) => i.tableId == tableId);
  }

  @override
  Future<List<DynamicItem>> getItems(int tableId) async => itemsFor(tableId);

  @override
  Future<void> insertItem(DynamicItem item) async {
    _items.add(
      DynamicItem(
        id: _nextItemId++,
        tableId: item.tableId,
        fields: Map.of(item.fields),
      ),
    );
  }

  @override
  Future<void> updateItem(DynamicItem item) async {
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i >= 0) _items[i] = item;
  }

  @override
  Future<void> deleteItem(int id) async =>
      _items.removeWhere((e) => e.id == id);

  @override
  Future<void> deleteItems(List<int> ids) async =>
      _items.removeWhere((e) => ids.contains(e.id));

  @override
  Future<void> restoreItems(List<DynamicItem> items) async {
    for (final item in items) {
      _items.removeWhere((e) => e.id == item.id);
      _items.add(
        DynamicItem(
          id: item.id,
          tableId: item.tableId,
          fields: Map.of(item.fields),
        ),
      );
    }
    _items.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
  }

  @override
  Future<String> saveImageFile(int tableId, File imageFile) async =>
      imageFile.path;

  // ---------------------------------------------------------------- seed data
  void _addTable(
    String name,
    List<FieldDefinition> fields,
    List<Map<String, dynamic>> rows,
  ) {
    final id = _nextTableId++;
    _tables.add(TableDefinition(id: id, name: name, fields: fields));
    for (final r in rows) {
      _items.add(DynamicItem(id: _nextItemId++, tableId: id, fields: r));
    }
  }

  void _seed() {
    _addTable(
      'Students',
      [
        FieldDefinition(name: 'Name', type: 'text', required: true),
        FieldDefinition(
          name: 'Roll No',
          type: 'integer',
          required: true,
          unique: true,
          min: 1,
          max: 9999,
        ),
        FieldDefinition(
          name: 'Course',
          type: 'text',
          defaultValue: 'B.Tech CSE',
        ),
        FieldDefinition(name: 'Email', type: 'email', unique: true),
        FieldDefinition(name: 'Admitted', type: 'date'),
        FieldDefinition(
          name: 'Guardian',
          type: 'text',
          subfields: ['Name', 'Phone'],
        ),
        FieldDefinition(name: 'Skills', type: 'text', isList: true),
      ],
      [
        {
          'Name': 'Aarav Sharma',
          'Roll No': 101,
          'Course': 'B.Tech CSE',
          'Email': 'aarav.sharma@college.in',
          'Admitted': '2024-07-15',
          'Guardian': ['Rakesh Sharma', '98100 23456'],
          'Skills': ['Flutter', 'Python'],
        },
        {
          'Name': 'Diya Patel',
          'Roll No': 102,
          'Course': 'B.Sc Data Science',
          'Email': 'diya.patel@college.in',
          'Admitted': '2024-07-15',
          'Guardian': ['Meena Patel', '98250 77812'],
          'Skills': ['SQL', 'Tableau'],
        },
        {
          'Name': 'Kabir Mehta',
          'Roll No': 103,
          'Course': 'BBA',
          'Email': 'kabir.mehta@college.in',
          'Admitted': '2024-07-18',
          'Guardian': ['Sanjay Mehta', '99300 11902'],
          'Skills': ['Excel', 'Public speaking'],
        },
        {
          'Name': 'Ananya Iyer',
          'Roll No': 104,
          'Course': 'B.Tech ECE',
          'Email': 'ananya.iyer@college.in',
          'Admitted': '2024-07-20',
          'Guardian': ['Lakshmi Iyer', '94440 56231'],
          'Skills': ['Arduino', 'C++'],
        },
        {
          'Name': 'Rohan Gupta',
          'Roll No': 105,
          'Course': 'B.Com',
          'Email': 'rohan.gupta@college.in',
          'Admitted': '2024-07-22',
          'Guardian': ['Anil Gupta', '98711 40087'],
          'Skills': ['Tally', 'Accounting'],
        },
        {
          'Name': 'Ishita Reddy',
          'Roll No': 106,
          'Course': 'B.Tech CSE',
          'Email': 'ishita.reddy@college.in',
          'Admitted': '2024-07-22',
          'Guardian': ['Srinivas Reddy', '90000 34519'],
          'Skills': ['Java', 'Figma'],
        },
        {
          'Name': 'Vihaan Nair',
          'Roll No': 107,
          'Course': 'B.Des',
          'Email': 'vihaan.nair@college.in',
          'Admitted': '2024-07-25',
          'Guardian': ['Priya Nair', '94470 88213'],
          'Skills': ['Illustrator', 'UI design'],
        },
        {
          'Name': 'Saanvi Joshi',
          'Roll No': 108,
          'Course': 'B.Sc Physics',
          'Email': 'saanvi.joshi@college.in',
          'Admitted': '2024-07-26',
          'Guardian': ['Mahesh Joshi', '98220 67340'],
          'Skills': ['MATLAB', 'Research'],
        },
        {
          'Name': 'Arjun Singh',
          'Roll No': 109,
          'Course': 'B.Tech Mech',
          'Email': 'arjun.singh@college.in',
          'Admitted': '2024-07-29',
          'Guardian': ['Harpreet Singh', '98140 22785'],
          'Skills': ['AutoCAD', 'SolidWorks'],
        },
        {
          'Name': 'Meera Krishnan',
          'Roll No': 110,
          'Course': 'MBA',
          'Email': 'meera.k@college.in',
          'Admitted': '2024-08-01',
          'Guardian': ['Gopal Krishnan', '94430 90126'],
          'Skills': ['Marketing', 'Power BI'],
        },
      ],
    );

    _addTable(
      'Inventory',
      [
        FieldDefinition(name: 'Item', type: 'text'),
        FieldDefinition(name: 'SKU', type: 'text'),
        FieldDefinition(name: 'Category', type: 'text'),
        FieldDefinition(name: 'Qty', type: 'integer'),
        FieldDefinition(name: 'Unit Price', type: 'text'),
        FieldDefinition(name: 'Supplier', type: 'text'),
        FieldDefinition(name: 'Restocked', type: 'date'),
      ],
      [
        {
          'Item': 'Basmati Rice 5 kg',
          'SKU': 'GR-1042',
          'Category': 'Grocery',
          'Qty': 48,
          'Unit Price': '₹649',
          'Supplier': 'Shree Traders',
          'Restocked': '2025-11-02',
        },
        {
          'Item': 'Toor Dal 1 kg',
          'SKU': 'GR-1108',
          'Category': 'Grocery',
          'Qty': 120,
          'Unit Price': '₹165',
          'Supplier': 'Shree Traders',
          'Restocked': '2025-11-04',
        },
        {
          'Item': 'Cold-pressed Mustard Oil 1 L',
          'SKU': 'GR-1215',
          'Category': 'Grocery',
          'Qty': 36,
          'Unit Price': '₹210',
          'Supplier': 'Kisan Oils',
          'Restocked': '2025-10-28',
        },
        {
          'Item': 'Steel Water Bottle 1 L',
          'SKU': 'HM-2031',
          'Category': 'Home',
          'Qty': 64,
          'Unit Price': '₹399',
          'Supplier': 'Milton Distributors',
          'Restocked': '2025-10-30',
        },
        {
          'Item': 'Cotton Bedsheet (Double)',
          'SKU': 'HM-2087',
          'Category': 'Home',
          'Qty': 22,
          'Unit Price': '₹1,149',
          'Supplier': 'Jaipur Textiles',
          'Restocked': '2025-10-21',
        },
        {
          'Item': 'LED Bulb 9 W (pack of 4)',
          'SKU': 'EL-3012',
          'Category': 'Electrical',
          'Qty': 85,
          'Unit Price': '₹299',
          'Supplier': 'Bharat Electricals',
          'Restocked': '2025-11-06',
        },
        {
          'Item': 'Extension Board 4-way',
          'SKU': 'EL-3040',
          'Category': 'Electrical',
          'Qty': 18,
          'Unit Price': '₹549',
          'Supplier': 'Bharat Electricals',
          'Restocked': '2025-10-25',
        },
        {
          'Item': 'Masala Chai 250 g',
          'SKU': 'GR-1302',
          'Category': 'Grocery',
          'Qty': 75,
          'Unit Price': '₹180',
          'Supplier': 'Assam Leaf Co.',
          'Restocked': '2025-11-07',
        },
        {
          'Item': 'Notebook A5 (200 pages)',
          'SKU': 'ST-4011',
          'Category': 'Stationery',
          'Qty': 140,
          'Unit Price': '₹85',
          'Supplier': 'Classmate Wholesale',
          'Restocked': '2025-11-01',
        },
      ],
    );

    _addTable(
      'Customers',
      [
        FieldDefinition(name: 'Name', type: 'text'),
        FieldDefinition(name: 'Phone', type: 'text'),
        FieldDefinition(name: 'Email', type: 'email'),
        FieldDefinition(name: 'City', type: 'text'),
        FieldDefinition(name: 'Since', type: 'date'),
        FieldDefinition(name: 'Tags', type: 'text', isList: true),
      ],
      [
        {
          'Name': 'Priya Menon',
          'Phone': '+91 98450 12345',
          'Email': 'priya.menon@gmail.com',
          'City': 'Bengaluru',
          'Since': '2023-03-14',
          'Tags': ['Premium', 'Wholesale'],
        },
        {
          'Name': 'Rahul Verma',
          'Phone': '+91 98110 45678',
          'Email': 'rahul.verma@outlook.com',
          'City': 'New Delhi',
          'Since': '2023-06-02',
          'Tags': ['Retail'],
        },
        {
          'Name': 'Sneha Kulkarni',
          'Phone': '+91 98220 33410',
          'Email': 'sneha.k@yahoo.in',
          'City': 'Pune',
          'Since': '2023-09-19',
          'Tags': ['Premium'],
        },
        {
          'Name': 'Mohammed Irfan',
          'Phone': '+91 99490 77120',
          'Email': 'irfan.m@gmail.com',
          'City': 'Hyderabad',
          'Since': '2024-01-08',
          'Tags': ['Wholesale', 'Credit'],
        },
        {
          'Name': 'Kavya Nair',
          'Phone': '+91 94470 22891',
          'Email': 'kavya.nair@gmail.com',
          'City': 'Kochi',
          'Since': '2024-02-27',
          'Tags': ['Retail', 'Newsletter'],
        },
        {
          'Name': 'Aditya Rao',
          'Phone': '+91 98860 51904',
          'Email': 'aditya.rao@company.in',
          'City': 'Mysuru',
          'Since': '2024-05-11',
          'Tags': ['Corporate'],
        },
        {
          'Name': 'Neha Agarwal',
          'Phone': '+91 98300 66218',
          'Email': 'neha.agarwal@gmail.com',
          'City': 'Kolkata',
          'Since': '2024-08-23',
          'Tags': ['Retail'],
        },
        {
          'Name': 'Siddharth Bose',
          'Phone': '+91 90070 41352',
          'Email': 'sid.bose@protonmail.com',
          'City': 'Kolkata',
          'Since': '2025-01-16',
          'Tags': ['Premium', 'Newsletter'],
        },
      ],
    );

    _addTable(
      'Event Registrations',
      [
        FieldDefinition(name: 'Participant', type: 'text'),
        FieldDefinition(name: 'Event', type: 'text'),
        FieldDefinition(name: 'Ticket', type: 'text'),
        FieldDefinition(name: 'Fee', type: 'text'),
        FieldDefinition(name: 'Registered', type: 'date'),
      ],
      [
        {
          'Participant': 'Tanvi Deshpande',
          'Event': 'Flutter Forward Mumbai',
          'Ticket': 'Early bird',
          'Fee': '₹499',
          'Registered': '2025-10-12',
        },
        {
          'Participant': 'Nikhil Bansal',
          'Event': 'Flutter Forward Mumbai',
          'Ticket': 'Standard',
          'Fee': '₹799',
          'Registered': '2025-10-18',
        },
        {
          'Participant': 'Pooja Hegde',
          'Event': 'Data Day Bengaluru',
          'Ticket': 'Workshop',
          'Fee': '₹1,499',
          'Registered': '2025-10-20',
        },
        {
          'Participant': 'Yash Malhotra',
          'Event': 'Data Day Bengaluru',
          'Ticket': 'Standard',
          'Fee': '₹999',
          'Registered': '2025-10-24',
        },
        {
          'Participant': 'Riya Chatterjee',
          'Event': 'Startup Mixer Delhi',
          'Ticket': 'Student',
          'Fee': '₹199',
          'Registered': '2025-11-01',
        },
        {
          'Participant': 'Harsh Vardhan',
          'Event': 'Startup Mixer Delhi',
          'Ticket': 'Standard',
          'Fee': '₹499',
          'Registered': '2025-11-03',
        },
      ],
    );
  }
}
