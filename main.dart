// Pocket Notes - Songs (title, artist)
// Packages: sqflite, path, shared_preferences (SharedPreferencesAsync)

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------
class Song {
  final int? id; // null until the database assigns one (AUTOINCREMENT)
  final String title;
  final String artist;

  Song({this.id, required this.title, required this.artist});

  Map<String, Object?> toMap() => {'id': id, 'title': title, 'artist': artist};

  factory Song.fromMap(Map<String, Object?> m) => Song(
        id: m['id'] as int?,
        title: m['title'] as String,
        artist: m['artist'] as String,
      );
}

// ---------------------------------------------------------------------------
// DATABASE: opened ONCE, the same instance is reused everywhere.
// We cache the Future (not just the Database) so two quick calls can never
// trigger two openDatabase() calls.
// ---------------------------------------------------------------------------
class SongDb {
  SongDb._(); // private constructor: nobody else can make another SongDb
  static final SongDb instance = SongDb._();

  Future<Database>? _dbFuture;
  Future<Database> get db => _dbFuture ??= _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'pocket_notes.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE songs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          artist TEXT NOT NULL
        )
      '''),
    );
  }

  Future<List<Song>> getAll() async {
    final d = await db;
    final rows = await d.query('songs', orderBy: 'id');
    return rows.map(Song.fromMap).toList();
  }

  Future<int> insert(Song s) async {
    final d = await db;
    return d.insert('songs', s.toMap()..remove('id'));
  }

  Future<int> update(Song s) async {
    final d = await db;
    return d.update(
      'songs',
      {'title': s.title, 'artist': s.artist},
      where: 'id = ?', // <- where
      whereArgs: [s.id], // <- whereArgs (no string-gluing)
    );
  }

  Future<int> delete(int id) async {
    final d = await db;
    return d.delete(
      'songs',
      where: 'id = ?', // <- where
      whereArgs: [id], // <- whereArgs
    );
  }
}

// ---------------------------------------------------------------------------
// STARTUP: read the saved theme BEFORE runApp so the first frame is correct.
// (Experiment 1: temporarily remove this await and load in initState instead.)
// ---------------------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = SharedPreferencesAsync();
  final isDark = await prefs.getBool('isDark') ?? false;
  runApp(PocketNotesApp(initialDark: isDark));
}

class PocketNotesApp extends StatefulWidget {
  final bool initialDark;
  const PocketNotesApp({super.key, required this.initialDark});

  @override
  State<PocketNotesApp> createState() => _PocketNotesAppState();
}

class _PocketNotesAppState extends State<PocketNotesApp> {
  late bool _dark = widget.initialDark;

  Future<void> _setDark(bool value) async {
    setState(() => _dark = value);
    await SharedPreferencesAsync().setBool('isDark', value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Notes',
      theme: ThemeData(colorSchemeSeed: Colors.teal, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: Colors.teal, brightness: Brightness.dark),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: SongsPage(isDark: _dark, onThemeChanged: _setDark),
    );
  }
}

// ---------------------------------------------------------------------------
// UI
// ---------------------------------------------------------------------------
class SongsPage extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  const SongsPage({super.key, required this.isDark, required this.onThemeChanged});

  @override
  State<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends State<SongsPage> {
  List<Song> _songs = [];

  // Experiment 2: NOT saved anywhere. Lives only in this State object (RAM).
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load(); // load records from sqflite on launch
  }

  Future<void> _load() async {
    final songs = await SongDb.instance.getAll();
    if (!mounted) return;
    setState(() => _songs = songs);
  }

  Future<void> _showEditor({Song? existing}) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final artist = TextEditingController(text: existing?.artist ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add song' : 'Edit song'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: artist, decoration: const InputDecoration(labelText: 'Artist')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (saved != true || title.text.trim().isEmpty || artist.text.trim().isEmpty) return;

    final song = Song(id: existing?.id, title: title.text.trim(), artist: artist.text.trim());
    if (existing == null) {
      await SongDb.instance.insert(song);
    } else {
      await SongDb.instance.update(song);
    }
    await _load();
  }

  Future<void> _delete(Song s) async {
    await SongDb.instance.delete(s.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _songs.where((s) {
      final q = _search.toLowerCase();
      return s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocket Notes: Songs'),
        actions: [
          Icon(widget.isDark ? Icons.dark_mode : Icons.light_mode),
          Switch(value: widget.isDark, onChanged: widget.onThemeChanged),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search (not saved)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? const Center(child: Text('No songs yet. Tap + to add one.'))
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (_, i) {
                      final s = shown[i];
                      return ListTile(
                        leading: Text('${s.id}'),
                        title: Text(s.title),
                        subtitle: Text(s.artist),
                        onTap: () => _showEditor(existing: s),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _delete(s),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
