import 'package:flutter/material.dart';
import 'package:data_registration/demo/demo_config.dart';
import 'package:data_registration/models/table_definition.dart';
import 'package:data_registration/models/dynamic_item.dart';
import 'package:data_registration/services/data_store.dart';
import 'package:data_registration/services/file_handler.dart';
import 'package:data_registration/services/import_service.dart';
import 'package:data_registration/services/item_query.dart';
import 'package:data_registration/utils/responsive.dart';
import 'package:data_registration/widgets/dynamic_item_form.dart';
import 'package:data_registration/widgets/dynamic_item_card.dart';
import 'package:data_registration/widgets/dynamic_item_table.dart';
import 'package:open_file/open_file.dart';

/// Something to open automatically once rows have loaded (used by demo mode
/// to screenshot the sheets and dialogs).
enum TableDataAutoOpen { add, edit, detail, filter, select, undo }

class TableDataScreen extends StatefulWidget {
  final TableDefinition table;
  final bool initialCardView;
  final TableDataAutoOpen? autoOpen;

  /// Search / sort / filter to start with (demo screenshots).
  final ItemQuery initialQuery;

  const TableDataScreen({
    super.key,
    required this.table,
    this.initialCardView = false,
    this.autoOpen,
    this.initialQuery = const ItemQuery(),
  });

  @override
  State<TableDataScreen> createState() => _TableDataScreenState();
}

class _TableDataScreenState extends State<TableDataScreen> {
  List<DynamicItem> _items = [];
  ItemQuery _query = const ItemQuery();
  bool _searching = false;
  final _searchController = TextEditingController();

  /// Ids of rows picked for a bulk action. Non-empty = selection mode.
  final Set<int> _selected = {};
  bool get _selecting => _selected.isNotEmpty;

  void _toggleSelect(DynamicItem item) {
    final id = item.id;
    if (id == null) return;
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  /// Rows after search / filter / sort.
  List<DynamicItem> get _visible => _query.apply(widget.table, _items);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  late bool _showTableView =
      !widget.initialCardView; // Toggle between card and table view

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    if (_query.hasSearch) {
      _searching = true;
      _searchController.text = _query.search;
    }
    _loadItems().then((_) => _runAutoOpen());
  }

  void _runAutoOpen() {
    if (!mounted || _items.isEmpty) return;
    switch (widget.autoOpen) {
      case TableDataAutoOpen.add:
        _addItem();
      case TableDataAutoOpen.edit:
        _editItem(_items.first);
      case TableDataAutoOpen.detail:
        showItemDetails(context, widget.table, _items.first);
      case TableDataAutoOpen.filter:
        _showFilterSheet();
      case TableDataAutoOpen.select:
        setState(() => _selected.addAll(_items.take(2).map((i) => i.id!)));
      case TableDataAutoOpen.undo:
        _deleteItems([_items[1]]);
      case null:
        break;
    }
  }

  Future<void> _loadItems() async {
    final items = await dataStore.getItems(widget.table.id!);
    if (!mounted) return;
    setState(() {
      _items = items;
    });
  }

  void _showItemSheet({DynamicItem? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: Breakpoints.sheetMaxWidth),
      builder: (context) => SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DynamicItemForm(
            table: widget.table,
            item: item, // Pass the item for editing
            existingItems: _items,
            onSubmit: (submitted) async {
              if (item == null) {
                await dataStore.insertItem(submitted);
              } else {
                await dataStore.updateItem(submitted);
              }
              _loadItems();
            },
          ),
        ),
      ),
    );
  }

  void _addItem() => _showItemSheet();

  void _editItem(DynamicItem item) => _showItemSheet(item: item);

  void _deleteItem(int id) {
    final item = _items.where((i) => i.id == id).toList();
    _deleteItems(item);
  }

  /// Deletes rows, then offers an UNDO that puts them back with their ids.
  Future<void> _deleteItems(List<DynamicItem> rows) async {
    if (rows.isEmpty) return;
    final ids = [for (final r in rows) r.id!];
    await dataStore.deleteItems(ids);
    if (!mounted) return;
    setState(() => _selected.removeAll(ids));
    await _loadItems();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          rows.length == 1 ? 'Row deleted' : '${rows.length} rows deleted',
        ),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            await dataStore.restoreItems(rows);
            _loadItems();
          },
        ),
      ),
    );
  }

  Future<void> _confirmBulkDelete(List<DynamicItem> visible) async {
    final rows = _items.where((i) => _selected.contains(i.id)).toList();
    if (rows.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete ${rows.length} ${rows.length == 1 ? 'row' : 'rows'}?',
        ),
        content: const Text('You can undo this right after.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await _deleteItems(rows);
  }

  PreferredSizeWidget _buildSelectionBar(List<DynamicItem> visible) {
    final allSelected =
        visible.isNotEmpty && visible.every((i) => _selected.contains(i.id));
    return AppBar(
      backgroundColor: Colors.grey[900],
      leading: IconButton(
        tooltip: 'Cancel selection',
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => setState(_selected.clear),
      ),
      title: Text(
        '${_selected.length} selected',
        style: const TextStyle(color: Colors.white),
      ),
      actions: [
        IconButton(
          tooltip: allSelected ? 'Deselect all' : 'Select all',
          icon: Icon(
            allSelected ? Icons.deselect : Icons.select_all,
            color: Colors.white,
          ),
          onPressed: () => setState(() {
            if (allSelected) {
              _selected.clear();
            } else {
              _selected.addAll(visible.map((i) => i.id!));
            }
          }),
        ),
        IconButton(
          tooltip: 'Delete selected',
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: () => _confirmBulkDelete(visible),
        ),
      ],
    );
  }

  void _showDemoNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Import and export are disabled in the demo build.'),
      ),
    );
  }

  void _exportData(String type) async {
    if (kDemo) return _showDemoNotice();
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
    if (kDemo) return _showDemoNotice();
    try {
      final result = await FileHandler().importFile(
        widget.table.id!,
        widget.table,
      );
      _loadItems();
      if (result != null && mounted) await _showImportReport(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _showImportReport(ImportResult result) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import complete'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.summary),
                if (result.skipped.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Skipped rows',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final issue in result.skipped.take(50))
                    Text(issue.toString()),
                  if (result.skipped.length > 50)
                    Text('...and ${result.skipped.length - 50} more'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildCardView(List<DynamicItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = gridColumnsForWidth(
          constraints.maxWidth.clamp(0, Breakpoints.contentMaxWidth).toDouble(),
          minTileWidth: 320,
        );
        if (columns == 1) {
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: items.length,
            itemBuilder: (context, index) => DynamicItemCard(
              table: widget.table,
              item: items[index],
              onEdit: () => _editItem(items[index]),
              onDelete: () => _deleteItem(items[index].id!),
              selectionMode: _selecting,
              selected: _selected.contains(items[index].id),
              onLongPress: () => _toggleSelect(items[index]),
              onToggleSelect: () => _toggleSelect(items[index]),
            ),
          );
        }
        // Wide screens: cards in a centred multi-column grid. Each card keeps
        // its own 16px horizontal margin, so the gutters come from there.
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 96),
          child: MaxWidthBox(
            child: LayoutBuilder(
              builder: (context, inner) {
                final tileWidth = (inner.maxWidth / columns).floorToDouble();
                return Wrap(
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: tileWidth,
                        child: DynamicItemCard(
                          table: widget.table,
                          item: item,
                          onEdit: () => _editItem(item),
                          onDelete: () => _deleteItem(item.id!),
                          selectionMode: _selecting,
                          selected: _selected.contains(item.id),
                          onLongPress: () => _toggleSelect(item),
                          onToggleSelect: () => _toggleSelect(item),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showFilterSheet() {
    final fields = widget.table.fields.where((f) => f.type != 'image');
    final controllers = {
      for (final f in fields)
        f.name: TextEditingController(text: _query.filters[f.name] ?? ''),
    };
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: Breakpoints.sheetMaxWidth),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter by field',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              for (final f in fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[f.name],
                    decoration: InputDecoration(
                      labelText: '${f.name} contains',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() => _query = _query.copyWith(filters: {}));
                      Navigator.pop(ctx);
                    },
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      setState(
                        () => _query = _query.copyWith(
                          filters: {
                            for (final e in controllers.entries)
                              if (e.value.text.trim().isNotEmpty)
                                e.key: e.value.text.trim(),
                          },
                        ),
                      );
                      Navigator.pop(ctx);
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      for (final c in controllers.values) {
        c.dispose();
      }
    });
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Sort',
      icon: Icon(
        Icons.sort,
        color: _query.sortField == null ? Colors.white : Colors.amber,
      ),
      onSelected: (field) => setState(
        () => _query = field.isEmpty
            ? _query.copyWith(clearSort: true)
            : _query.toggleSort(field),
      ),
      itemBuilder: (context) => [
        for (final f in widget.table.fields.where((f) => f.type != 'image'))
          PopupMenuItem(
            value: f.name,
            child: Row(
              children: [
                Expanded(child: Text(f.name)),
                if (_query.sortField == f.name)
                  Icon(
                    _query.ascending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 16,
                  ),
              ],
            ),
          ),
        if (_query.sortField != null)
          const PopupMenuItem(value: '', child: Text('Clear sort')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: _selecting
            ? _buildSelectionBar(visible)
            : AppBar(
                title: _searching
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        decoration: const InputDecoration(
                          hintText: 'Search all fields',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onChanged: (v) =>
                            setState(() => _query = _query.copyWith(search: v)),
                      )
                    : Text(
                        widget.table.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                backgroundColor: Colors.black,
                actions: [
                  IconButton(
                    tooltip: _searching ? 'Close search' : 'Search',
                    icon: Icon(
                      _searching ? Icons.close : Icons.search,
                      color: Colors.white,
                    ),
                    onPressed: () => setState(() {
                      if (_searching) {
                        _searchController.clear();
                        _query = _query.copyWith(search: '');
                      }
                      _searching = !_searching;
                    }),
                  ),
                  IconButton(
                    tooltip: 'Filter',
                    icon: Badge(
                      isLabelVisible: _query.activeFilterCount > 0,
                      label: Text('${_query.activeFilterCount}'),
                      child: const Icon(Icons.filter_list, color: Colors.white),
                    ),
                    onPressed: _showFilterSheet,
                  ),
                  if (!_showTableView) _buildSortMenu(),
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
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'xlsx',
                        child: Text(
                          'Export as XLSX',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
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
          child: visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _items.isEmpty
                              ? 'No items found. Add an item to get started.'
                              : 'No rows match your search or filters.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                        if (_items.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _query = _query.copyWith(search: '', filters: {});
                            }),
                            child: const Text('Clear search and filters'),
                          ),
                      ],
                    ),
                  ),
                )
              : _showTableView
              ? DynamicItemTable(
                  table: widget.table,
                  items: visible,
                  onEdit: _editItem,
                  onDelete: _deleteItem,
                  sortField: _query.sortField,
                  sortAscending: _query.ascending,
                  onSort: (f) => setState(() => _query = _query.toggleSort(f)),
                  selectionMode: _selecting,
                  selectedIds: _selected,
                  onToggleSelect: _toggleSelect,
                )
              : _buildCardView(visible),
        ),
        floatingActionButton: _selecting
            ? null
            : FloatingActionButton(
                tooltip: 'Add row',
                onPressed: _addItem,
                backgroundColor: Colors.grey[800],
                child: const Icon(Icons.add, color: Colors.white),
              ),
      ),
    );
  }
}
