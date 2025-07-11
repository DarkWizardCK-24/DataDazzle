import 'package:flutter/material.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:data_registration/screens/table_data_screen.dart';
import 'package:data_registration/screens/table_form_screen.dart';
import 'package:data_registration/services/database_helper.dart';

class TableManagerScreen extends StatefulWidget {
  const TableManagerScreen({super.key});

  @override
  _TableManagerScreenState createState() => _TableManagerScreenState();
}

class _TableManagerScreenState extends State<TableManagerScreen> {
  List<TableDefinition> tables = [];

  @override
  void initState() {
    super.initState();
    _refreshTables();
  }

  void _refreshTables() async {
    final data = await DatabaseHelper.instance.getTables();
    setState(() {
      tables = data;
    });
  }

  void _deleteTable(int tableId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this table and all its data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.deleteTable(tableId);
              _refreshTables();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
        backgroundColor: Colors.grey[800],
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        contentTextStyle: const TextStyle(color: Colors.white70),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tables',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.black,
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
        child: tables.isEmpty
            ? const Center(
                child: Text(
                  'No tables found. Create a new table!',
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
              )
            : ListView.builder(
                itemCount: tables.length,
                itemBuilder: (context, index) {
                  final table = tables[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
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
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TableDataScreen(table: table),
                                ),
                              );
                            },
                            child: Text(
                              table.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TableFormScreen(table: table),
                              ),
                            ).then((_) => _refreshTables());
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _deleteTable(table.id!),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.grey[800],
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TableFormScreen(),
            ),
          ).then((_) => _refreshTables());
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}