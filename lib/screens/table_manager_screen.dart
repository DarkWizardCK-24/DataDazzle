import 'package:flutter/material.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:data_registration/screens/table_data_screen.dart';
import 'package:data_registration/screens/table_form_screen.dart';
import 'package:data_registration/services/data_store.dart';
import 'package:data_registration/utils/responsive.dart';

class TableManagerScreen extends StatefulWidget {
  const TableManagerScreen({super.key});

  @override
  _TableManagerScreenState createState() => _TableManagerScreenState();
}

class _TableManagerScreenState extends State<TableManagerScreen> {
  List<TableDefinition> tables = [];
  Map<int, int> _rowCounts = {};

  @override
  void initState() {
    super.initState();
    _refreshTables();
  }

  void _refreshTables() async {
    final data = await dataStore.getTables();
    final counts = <int, int>{};
    for (final t in data) {
      if (t.id != null) {
        counts[t.id!] = (await dataStore.getItems(t.id!)).length;
      }
    }
    if (!mounted) return;
    setState(() {
      tables = data;
      _rowCounts = counts;
    });
  }

  void _deleteTable(int tableId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to delete this table and all its data?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () async {
              await dataStore.deleteTable(tableId);
              _refreshTables();
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
        backgroundColor: Colors.grey[800],
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        contentTextStyle: const TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _buildTableCard(TableDefinition table) {
    final rows = _rowCounts[table.id] ?? 0;
    final fieldNames = table.fields.map((f) => f.name).join(' · ');
    return Container(
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
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TableDataScreen(table: table),
                  ),
                ).then((_) => _refreshTables());
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    table.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${table.fields.length} fields  ·  $rows ${rows == 1 ? 'row' : 'rows'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  if (fieldNames.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      fieldNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
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
        constraints: const BoxConstraints.expand(),
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
            : LayoutBuilder(
                builder: (context, constraints) {
                  final columns = gridColumnsForWidth(
                    constraints.maxWidth
                        .clamp(0, Breakpoints.contentMaxWidth)
                        .toDouble(),
                  );
                  if (columns == 1) {
                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 88),
                      itemCount: tables.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        child: _buildTableCard(tables[index]),
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                    child: MaxWidthBox(
                      child: LayoutBuilder(
                        builder: (context, inner) {
                          const gap = 16.0;
                          final tileWidth =
                              (inner.maxWidth - gap * (columns - 1)) / columns;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final table in tables)
                                SizedBox(
                                  width: tileWidth,
                                  child: _buildTableCard(table),
                                ),
                            ],
                          );
                        },
                      ),
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
            MaterialPageRoute(builder: (context) => const TableFormScreen()),
          ).then((_) => _refreshTables());
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
