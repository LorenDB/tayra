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
  static const _databaseVersion = 1;

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
        resource_id INTEGER
      )
    ''');

    // Favorites cache table - lightweight storage for favorite IDs
    await db.execute('''
      CREATE TABLE cache_favorites (
        track_id INTEGER PRIMARY KEY,
        added_at INTEGER NOT NULL
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
    // Handle future schema migrations here
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
