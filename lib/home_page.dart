import 'package:flutter/material.dart';

import 'song.dart';
import 'song_database.dart';

class HomePage extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;

  const HomePage({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _db = SongDatabase.instance; // the one shared database
  List<Song> _songs = [];

  // EXPERIMENT 2: this lives ONLY in memory (a plain State variable).
  // It is deliberately NOT saved anywhere, so a force-kill resets it.
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _load(); // list is loaded from sqflite when the app launches
  }

  Future<void> _load() async {
    final songs = await _db.getAll();
    if (!mounted) return;
    setState(() => _songs = songs);
  }

  /// Shows the add/edit dialog. Pass [existing] to edit, null to add.
  Future<void> _showSongDialog({Song? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final artistCtrl = TextEditingController(text: existing?.artist ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add song' : 'Edit song'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: artistCtrl,
              decoration: const InputDecoration(labelText: 'Artist'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    final title = titleCtrl.text.trim();
    final artist = artistCtrl.text.trim();
    if (title.isEmpty || artist.isEmpty) return;

    if (existing == null) {
      await _db.insert(Song(title: title, artist: artist));
    } else {
      await _db.update(Song(id: existing.id, title: title, artist: artist));
    }
    await _load();
  }

  Future<void> _delete(Song song) async {
    await _db.delete(song.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    // Experiment 2 filter. There is no "favorite" column in the table, so the
    // chip stands in with a visible rule: show only songs with an even id.
    // The rule doesn't matter; what matters is that the chip's on/off state
    // lives only in this State object's memory.
    final visible = _favoritesOnly
        ? _songs.where((s) => s.id != null && s.id!.isEven).toList()
        : _songs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocket Notes: Songs'),
        actions: [
          const Icon(Icons.light_mode, size: 18),
          Switch(
            value: widget.isDark,
            onChanged: widget.onThemeChanged, // circle this for screenshot #1
          ),
          const Icon(Icons.dark_mode, size: 18),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: const Text('Favorites only'),
                selected: _favoritesOnly,
                onSelected: (v) => setState(() => _favoritesOnly = v),
              ),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('No songs yet. Tap + to add one.'))
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final song = visible[i];
                      return ListTile(
                        leading: Text('#${song.id}'),
                        title: Text(song.title),
                        subtitle: Text(song.artist),
                        onTap: () => _showSongDialog(existing: song),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _delete(song),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSongDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
