import 'package:data_registration/models/dynamic_item.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dynamic_items.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, filePath);
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tables (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            fields TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tableId INTEGER,
            fields TEXT,
            FOREIGN KEY (tableId) REFERENCES tables(id)
          )
        ''');
      },
    );
  }

  Future<String> _getImageStoragePath(int tableId) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = join(directory.path, 'images', tableId.toString());
    await Directory(imagePath).create(recursive: true);
    return imagePath;
  }

  Future<String> saveImageFile(int tableId, File imageFile) async {
    final imagePath = await _getImageStoragePath(tableId);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
    final newPath = join(imagePath, fileName);
    await imageFile.copy(newPath);
    return newPath;
  }

  Future<void> createTable(TableDefinition table) async {
    final db = await database;
    await db.insert(
      'tables',
      {
        'name': table.name,
        'fields': jsonEncode(table.fields.map((f) => f.toMap()).toList()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTable(TableDefinition table) async {
    final db = await database;
    // Update table metadata
    await db.update(
      'tables',
      {
        'name': table.name,
        'fields': jsonEncode(table.fields.map((f) => f.toMap()).toList()),
      },
      where: 'id = ?',
      whereArgs: [table.id],
    );
    // Update items to reflect new fields (remove deleted fields, adjust lists/subfields)
    final items = await getItems(table.id!);
    final newFieldNames = table.fields.map((f) => f.name).toSet();
    for (var item in items) {
      final updatedFields = Map<String, dynamic>.from(item.fields);
      updatedFields.removeWhere((key, _) => !newFieldNames.contains(key));
      // Add default values for new fields
      for (var field in table.fields) {
        if (!updatedFields.containsKey(field.name)) {
          updatedFields[field.name] = field.isList || field.subfields != null ? [] : '';
        }
      }
      await updateItem(DynamicItem(
        id: item.id,
        tableId: item.tableId,
        fields: updatedFields,
      ));
    }
  }

  Future<void> deleteTable(int tableId) async {
    final db = await database;
    // Delete items
    await db.delete(
      'items',
      where: 'tableId = ?',
      whereArgs: [tableId],
    );
    // Delete table
    await db.delete(
      'tables',
      where: 'id = ?',
      whereArgs: [tableId],
    );
    // Delete associated image directory
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = join(directory.path, 'images', tableId.toString());
    final imageDir = Directory(imagePath);
    if (await imageDir.exists()) {
      await imageDir.delete(recursive: true);
    }
  }

  Future<List<TableDefinition>> getTables() async {
    final db = await database;
    final maps = await db.query('tables');
    return List.generate(maps.length, (i) {
      return TableDefinition(
        id: maps[i]['id'] as int?,
        name: maps[i]['name'].toString(),
        fields: (jsonDecode(maps[i]['fields'].toString()) as List)
            .map((f) => FieldDefinition.fromMap(f))
            .toList(),
      );
    });
  }

  Future<List<DynamicItem>> getItems(int tableId) async {
    final db = await database;
    final maps = await db.query(
      'items',
      where: 'tableId = ?',
      whereArgs: [tableId],
    );
    return List.generate(maps.length, (i) => DynamicItem.fromMap({
          'id': maps[i]['id'],
          'tableId': maps[i]['tableId'],
          'fields': jsonDecode(maps[i]['fields'].toString()),
        }));
  }

  Future<void> insertItem(DynamicItem item) async {
    final db = await database;
    await db.insert(
      'items',
      {
        'tableId': item.tableId,
        'fields': jsonEncode(item.fields),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateItem(DynamicItem item) async {
    final db = await database;
    await db.update(
      'items',
      {
        'tableId': item.tableId,
        'fields': jsonEncode(item.fields),
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteItem(int id) async {
    final db = await database;
    await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}