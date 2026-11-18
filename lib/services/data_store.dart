import 'dart:io';

import 'package:data_registration/demo/demo_config.dart';
import 'package:data_registration/demo/demo_data_store.dart';
import 'package:data_registration/models/dynamic_item.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:data_registration/services/database_helper.dart';

/// Storage interface used by the UI. The real app uses SQLite through
/// [DatabaseHelper]; demo builds (`--dart-define=DEMO=true`) use an in-memory
/// store so they also run on the web.
abstract class DataStore {
  Future<List<TableDefinition>> getTables();
  Future<void> createTable(TableDefinition table);
  Future<void> updateTable(TableDefinition table);
  Future<void> deleteTable(int tableId);
  Future<List<DynamicItem>> getItems(int tableId);
  Future<void> insertItem(DynamicItem item);
  Future<void> updateItem(DynamicItem item);
  Future<void> deleteItem(int id);

  /// Deletes several rows at once.
  Future<void> deleteItems(List<int> ids);

  /// Puts back rows that were deleted, keeping their original ids (and so
  /// their order). Used by "Undo".
  Future<void> restoreItems(List<DynamicItem> items);
  Future<String> saveImageFile(int tableId, File imageFile);
}

DataStore get dataStore =>
    kDemo ? DemoDataStore.instance : DatabaseHelper.instance;
