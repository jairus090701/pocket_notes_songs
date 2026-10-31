// EXPERIMENT 1 ONLY: "the wrong-theme flash".
//
// How to use: temporarily replace the contents of lib/main.dart with this
// file (keep a copy of the fixed version!), cold start the app, screenshot
// the wrong-theme frame, then PUT THE FIX BACK (restore the original main.dart).
//
// The difference: runApp() is called IMMEDIATELY with a default (light)
// theme, and the saved value is read later in initState, then applied with
// setState. The first frame is therefore drawn before the saved theme is known.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page.dart';

const _themeKey = 'isDark';

void main() {
  // NOTE: no await here. The first screen is drawn right away.
  runApp(const PocketNotesApp());
}

class PocketNotesApp extends StatefulWidget {
  const PocketNotesApp({super.key});

  @override
  State<PocketNotesApp> createState() => _PocketNotesAppState();
}

class _PocketNotesAppState extends State<PocketNotesApp> {
  bool _isDark = false; // default guess: light, BEFORE we know the real value
  final _prefs = SharedPreferencesAsync();

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    // The 2-second delay makes the wrong frame easy to screenshot.
    // Remove Future.delayed if you want the "natural" tiny flash.
    await Future.delayed(const Duration(seconds: 2));
    final saved = await _prefs.getBool(_themeKey) ?? false;
    if (!mounted) return;
    setState(() => _isDark = saved);
  }

  Future<void> _setDark(bool value) async {
    setState(() => _isDark = value);
    await _prefs.setBool(_themeKey, value);
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
