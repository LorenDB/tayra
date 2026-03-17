import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Database schema for the local cache.
///
/// Tables:
/// - cache_metadata: Stores JSON metadata for albums, artists, tracks, playlists
/// - cache_files: Stores downloaded audio files and cover art
/// - cache_favorites: Stores favorite track IDs
class CacheDatabase {
  static const _databaseName = 'funkwhale_cache.db';
  static const _databaseVersion = 3;

  // Singleton pattern
  CacheDatabase._();
  static final CacheDatabase instance = CacheDatabase._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Metadata cache table - stores JSON data for API responses
    await db.execute('''
      CREATE TABLE cache_metadata (
        cache_key TEXT PRIMARY KEY,
        cache_type TEXT NOT NULL,
        data TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        last_accessed INTEGER NOT NULL,
        expires_at INTEGER
      )
    ''');

    // File cache table - stores downloaded files (audio, images)
    await db.execute('''
      CREATE TABLE cache_files (
        cache_key TEXT PRIMARY KEY,
        file_type TEXT NOT NULL,
        file_path TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        last_accessed INTEGER NOT NULL,
        resource_id INTEGER,
        resource_parent_type TEXT,
        resource_parent_id INTEGER,
        is_protected INTEGER DEFAULT 0
      )
    ''');

    // Favorites cache table - lightweight storage for favorite IDs
    await db.execute('''
      CREATE TABLE cache_favorites (
        track_id INTEGER PRIMARY KEY,
        added_at INTEGER NOT NULL
      )
    ''');

    // Manual downloads table - tracks resources manually marked by the user
    await db.execute('''
      CREATE TABLE cache_manual_downloads (
        resource_type TEXT NOT NULL,
        resource_id INTEGER PRIMARY KEY,
        added_at INTEGER NOT NULL
      )
    ''');

    // Download queue table - persists the background download queue so it
    // survives app restarts and tracks per-item state.
    await db.execute('''
      CREATE TABLE download_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        track_id INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'queued',
        added_at INTEGER NOT NULL,
        error TEXT
      )
    ''');

    // Indexes for efficient querying
    await db.execute(
      'CREATE INDEX idx_metadata_type ON cache_metadata(cache_type)',
    );
    await db.execute(
      'CREATE INDEX idx_metadata_accessed ON cache_metadata(last_accessed)',
    );
    await db.execute('CREATE INDEX idx_files_type ON cache_files(file_type)');
    await db.execute(
      'CREATE INDEX idx_files_accessed ON cache_files(last_accessed)',
    );
    await db.execute(
      'CREATE INDEX idx_files_resource ON cache_files(resource_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add manual downloads table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cache_manual_downloads (
          resource_type TEXT NOT NULL,
          resource_id INTEGER PRIMARY KEY,
          added_at INTEGER NOT NULL
        )
      ''');
      // Add new columns to cache_files for older databases so that
      // protection and parent linking work across migrations.
      try {
        await db.execute(
          "ALTER TABLE cache_files ADD COLUMN resource_parent_type TEXT",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE cache_files ADD COLUMN resource_parent_id INTEGER",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE cache_files ADD COLUMN is_protected INTEGER DEFAULT 0",
        );
      } catch (_) {}
    }
    if (oldVersion < 3) {
      // Add persistent download queue table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS download_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          track_id INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'queued',
          added_at INTEGER NOT NULL,
          error TEXT
        )
      ''');
      // Reset any items that were mid-download when the app was killed so
      // they get retried on the next startup.
      await db.execute(
        "UPDATE download_queue SET status = 'queued', error = NULL WHERE status = 'downloading'",
      );
    }
  }

  /// Close the database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Delete the entire database (for testing or complete cache clear)
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
