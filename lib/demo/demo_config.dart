/// Compile-time demo mode, used for screenshots and the web preview.
///
///   flutter run -d chrome --dart-define=DEMO=true
///   flutter build web --release --dart-define=DEMO=true --dart-define=DEMO_ROUTE=data
///
/// DEMO_ROUTE: home | tables | data | cards | add | edit-row | detail | create | edit
///             search | filter | select | undo | rules
/// DEMO_TABLE: index of the seeded table to open (0 Students, 1 Inventory,
///             2 Customers, 3 Event Registrations).
const bool kDemo = bool.fromEnvironment('DEMO');
const String kDemoRoute = String.fromEnvironment(
  'DEMO_ROUTE',
  defaultValue: 'home',
);
const int kDemoTable = int.fromEnvironment('DEMO_TABLE', defaultValue: 0);

/// On the web the route/table can also be picked at runtime with query
/// parameters, e.g. `/?route=data&table=1`, so one build covers every screen.
String get demoRoute => Uri.base.queryParameters['route'] ?? kDemoRoute;
int get demoTable =>
    int.tryParse(Uri.base.queryParameters['table'] ?? '') ?? kDemoTable;
