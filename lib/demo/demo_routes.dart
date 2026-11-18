import 'package:flutter/material.dart';

import 'package:data_registration/demo/demo_config.dart';
import 'package:data_registration/demo/demo_data_store.dart';
import 'package:data_registration/screens/home_screen.dart';
import 'package:data_registration/services/item_query.dart';
import 'package:data_registration/screens/table_data_screen.dart';
import 'package:data_registration/screens/table_form_screen.dart';
import 'package:data_registration/screens/table_manager_screen.dart';

/// Builds the initial navigation stack for demo builds from DEMO_ROUTE, so a
/// screenshot can open straight onto any screen with a real back stack.
List<Route<dynamic>> demoInitialRoutes() {
  MaterialPageRoute<void> page(Widget w) =>
      MaterialPageRoute<void>(builder: (_) => w);

  final tables = DemoDataStore.instance.seededTables;
  final table = tables[demoTable.clamp(0, tables.length - 1)];
  final base = <Route<dynamic>>[
    page(const HomeScreen()),
    page(const TableManagerScreen()),
  ];

  switch (demoRoute) {
    case 'tables':
      return base;
    case 'data':
      return [...base, page(TableDataScreen(table: table))];
    case 'cards':
      return [
        ...base,
        page(TableDataScreen(table: table, initialCardView: true)),
      ];
    case 'add':
      return [
        ...base,
        page(TableDataScreen(table: table, autoOpen: TableDataAutoOpen.add)),
      ];
    case 'edit-row':
      return [
        ...base,
        page(TableDataScreen(table: table, autoOpen: TableDataAutoOpen.edit)),
      ];
    case 'detail':
      return [
        ...base,
        page(
          TableDataScreen(
            table: table,
            initialCardView: true,
            autoOpen: TableDataAutoOpen.detail,
          ),
        ),
      ];
    case 'search':
      return [
        ...base,
        page(
          TableDataScreen(
            table: table,
            initialQuery: const ItemQuery(
              search: 'B.Tech',
              sortField: 'Roll No',
              ascending: false,
            ),
          ),
        ),
      ];
    case 'filter':
      return [
        ...base,
        page(
          TableDataScreen(
            table: table,
            initialQuery: const ItemQuery(filters: {'Course': 'B.Tech'}),
            autoOpen: TableDataAutoOpen.filter,
          ),
        ),
      ];
    case 'select':
      return [
        ...base,
        page(
          TableDataScreen(
            table: table,
            initialCardView: true,
            autoOpen: TableDataAutoOpen.select,
          ),
        ),
      ];
    case 'undo':
      return [
        ...base,
        page(TableDataScreen(table: table, autoOpen: TableDataAutoOpen.undo)),
      ];
    case 'rules':
      return [...base, page(TableFormScreen(table: table, expandRules: true))];
    case 'create':
      return [...base, page(const TableFormScreen())];
    case 'edit':
      return [...base, page(TableFormScreen(table: table))];
    default:
      return [page(const HomeScreen())];
  }
}
