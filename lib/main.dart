import 'package:data_registration/demo/demo_config.dart';
import 'package:data_registration/demo/demo_routes.dart';
import 'package:data_registration/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DataDazzle',
      debugShowCheckedModeBanner: false,
      theme: _darkTheme,
      home: const HomeScreen(),
      onGenerateInitialRoutes: kDemo ? (_) => demoInitialRoutes() : null,
    );
  }
}

/// One dark theme for the whole app (grey-on-black with an amber accent), so
/// sheets, dialogs, menus, switches and snackbars match the screens instead of
/// falling back to the light Material defaults.
final ThemeData _darkTheme = () {
  const surface = Color(0xFF262626);
  const accent = Colors.amber;
  final scheme = ColorScheme.dark(
    primary: accent,
    onPrimary: Colors.black,
    secondary: accent,
    surface: surface,
    onSurface: Colors.white,
    error: Colors.redAccent,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: Colors.white),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Colors.grey[900],
      contentTextStyle: const TextStyle(color: Colors.white),
      actionTextColor: accent,
      behavior: SnackBarBehavior.floating,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? accent : Colors.grey,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? accent.withValues(alpha: 0.35)
            : Colors.white12,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white70),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: accent, width: 2),
      ),
    ),
  );
}();
