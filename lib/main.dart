import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page.dart';

// SharedPreferencesAsync is the newer API in shared_preferences. It reads
// straight from the platform each time, so there is no cache to go stale.
const _themeKey = 'isDark';

/// THE FIX (normal version of the app):
/// We AWAIT the saved theme BEFORE calling runApp(). That way the very first
/// frame is already drawn with the right theme, so there is no flash.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = SharedPreferencesAsync();
  final isDark = await prefs.getBool(_themeKey) ?? false;
  runApp(PocketNotesApp(initialIsDark: isDark));
}

class PocketNotesApp extends StatefulWidget {
  final bool initialIsDark;
  const PocketNotesApp({super.key, required this.initialIsDark});

  @override
  State<PocketNotesApp> createState() => _PocketNotesAppState();
}

class _PocketNotesAppState extends State<PocketNotesApp> {
  late bool _isDark = widget.initialIsDark;
  final _prefs = SharedPreferencesAsync();

  Future<void> _setDark(bool value) async {
    setState(() => _isDark = value);
    await _prefs.setBool(_themeKey, value); // saved, so it survives a kill
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Notes',
      theme: ThemeData(colorSchemeSeed: Colors.teal, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: Colors.teal, brightness: Brightness.dark),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: HomePage(isDark: _isDark, onThemeChanged: _setDark),
    );
  }
}
