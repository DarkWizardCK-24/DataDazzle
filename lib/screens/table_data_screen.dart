import 'package:flutter/material.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:data_registration/models/dynamic_item.dart';
import 'package:data_registration/services/database_helper.dart';
import 'package:data_registration/services/file_handler.dart';
import 'package:data_registration/widgets/dynamic_item_form.dart';
import 'package:data_registration/widgets/dynamic_item_card.dart';
import 'package:data_registration/widgets/dynamic_item_table.dart';
import 'package:open_file/open_file.dart';

class TableDataScreen extends StatefulWidget {
  final TableDefinition table;

  const TableDataScreen({super.key, required this.table});

  @override
  _TableDataScreenState createState() => _TableDataScreenState();
}

class _TableDataScreenState extends State<TableDataScreen> {
  List<DynamicItem> _items = [];
  bool _showTableView = true; // Toggle between card and table view

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await DatabaseHelper.instance.getItems(widget.table.id!);
    setState(() {
      _items = items;
    });
  }

  void _addItem() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DynamicItemForm(
            table: widget.table,
            onSubmit: (item) async {
              await DatabaseHelper.instance.insertItem(item);
              _loadItems();
            },
          ),
        ),
      ),
    );
  }

  void _editItem(DynamicItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DynamicItemForm(
            table: widget.table,
            item: item, // Pass the item for editing
            onSubmit: (updatedItem) async {
              await DatabaseHelper.instance.updateItem(updatedItem);
              _loadItems();
            },
          ),
        ),
      ),
    );
  }

  void _deleteItem(int id) async {
    await DatabaseHelper.instance.deleteItem(id);
    _loadItems();
  }

  void _exportData(String type) async {
    String path;
    if (type == 'csv') {
      path = await FileHandler().exportToCsv(
        widget.table.id!,
        widget.table,
        _items,
      );
    } else {
      path = await FileHandler().exportToXlsx(
        widget.table.id!,
        widget.table,
        _items,
      );
    }
    OpenFile.open(path);
  }

  void _importData() async {
    await FileHandler().importFile(widget.table.id!, widget.table);
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.table.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(
              _showTableView ? Icons.view_list : Icons.view_module,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showTableView = !_showTableView;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_upload, color: Colors.white),
            onPressed: _importData,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download, color: Colors.white),
            onSelected: _exportData,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'csv',
                child: Text(
                  'Export as CSV',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              const PopupMenuItem(
                value: 'xlsx',
                child: Text(
                  'Export as XLSX',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black,
              Color(0xFF212121),
              Color(0xFF424242),
              Color(0xFF616161),
              Color(0xFF757575),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.3, 0.5, 0.7, 1.0],
          ),
        ),
        child: _items.isEmpty
            ? const Center(
                child: Text(
                  'No items found. Add an item to get started.',
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
              )
            : _showTableView
                ? DynamicItemTable(
                    table: widget.table,
                    items: _items,
                    onEdit: _editItem,
                    onDelete: _deleteItem,
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) => DynamicItemCard(
                      table: widget.table,
                      item: _items[index],
                      onEdit: () => _editItem(_items[index]),
                      onDelete: () => _deleteItem(_items[index].id!),
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        backgroundColor: Colors.grey[800],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}