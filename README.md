# DataDazzle

A Flutter mobile app for building your own data tables and moving data in and out of them. Define a table, add rows, and import or export as CSV, XLSX or ODS. Everything is stored locally in SQLite.

## Features

- **Custom tables**: create tables with your own fields, then edit or remove them.
- **Dynamic forms**: add and edit rows through forms generated from the table definition.
- **Two views**: spreadsheet-style table view and card-based view.
- **Import and export**: CSV, XLSX and ODS files.
- **Local storage**: data lives in an on-device SQLite database, no account needed.

## Tech stack

- Flutter and Dart
- `sqflite` for the local database
- `csv`, `excel` and `file_picker` for import and export, `path_provider` and `open_file` for saved files

## Project structure

```
lib/
  models/     table_definition, item, dynamic_item
  services/   database_helper.dart (SQLite), file_handler.dart (import/export)
  screens/    home, table manager, table form, table data
  widgets/    dynamic_item_card, dynamic_item_form, dynamic_item_table
```

## Getting started

```bash
flutter pub get
flutter run
```

Requires Flutter with Dart SDK 3.8 or newer.
