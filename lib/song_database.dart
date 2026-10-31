import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'song.dart';

/// Singleton wrapper around the one and only database connection.
///
/// WHY ONCE? Every call to openDatabase() creates a new connection to the
/// same file. Several connections can cause "database is locked" errors,
/// waste memory, and can show stale data. So we open it one time, keep the
/// Future in a static field, and everyone who calls [database] gets the
/// same instance back.
class SongDatabase {
  SongDatabase._(); // no one can create extra instances
  static final SongDatabase instance = SongDatabase._();

  static const String tableName = 'songs';

  // Caching the Future (not the result) also protects us if two callers ask
  // for the database at the same moment: both receive the same Future.
  Future<Database>? _dbFuture;

  Future<Database> get database => _dbFuture ??= _open();

  Future<Database> _open() async {
    final dbPath = p.join(await getDatabasesPath(), 'pocket_notes.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            artist TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Create
  Future<int> insert(Song song) async {
    final db = await database;
    return db.insert(tableName, song.toMap());
  }

  /// Read all, oldest first (so the first record you add stays on top).
  Future<List<Song>> getAll() async {
    final db = await database;
    final rows = await db.query(tableName, orderBy: 'id ASC');
    // Handy for Part 3 #7 (database proof): shows the raw rows in the console.
    // ignore: avoid_print
    print('DB rows: $rows');
    return rows.map(Song.fromMap).toList();
  }

  /// Update. where + whereArgs: the ? is filled in safely by sqflite,
  /// we never glue the id into the SQL string ourselves.
  Future<int> update(Song song) async {
    final db = await database;
    return db.update(
      tableName,
      song.toMap(),
      where: 'id = ?',
      whereArgs: [song.id],
    );
  }

  /// Delete. Screenshot #8 for the activity: circle `where` and `whereArgs`.
  Future<int> delete(int id) async {
    final db = await database;
    return db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
