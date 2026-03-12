import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:funkwhale/core/cache/cache_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache types for different kinds of data
enum CacheType {
  album,
  artist,
  track,
  playlist,
  recentAlbums,
  recentArtists,
  searchResults,
}

/// File types for cached files
enum FileType { audio, coverArt }

/// Configuration for cache limits
class CacheConfig {
  /// Maximum total cache size in bytes (default: 500 MB)
  final int maxTotalSizeBytes;

  /// Maximum size for audio files in bytes (default: 300 MB)
  final int maxAudioSizeBytes;

  /// Maximum size for metadata and images in bytes (default: 200 MB)
  final int maxMetadataSizeBytes;

  const CacheConfig({
    this.maxTotalSizeBytes = 500 * 1024 * 1024, // 500 MB
    this.maxAudioSizeBytes = 300 * 1024 * 1024, // 300 MB
    this.maxMetadataSizeBytes = 200 * 1024 * 1024, // 200 MB
  });

  /// Load config from SharedPreferences
  static Future<CacheConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final maxSizeMB = prefs.getInt('cache_max_size_mb') ?? 500;
    final maxTotalBytes = maxSizeMB * 1024 * 1024;

    // Allocate 60% to audio, 40% to metadata/images
    final maxAudioBytes = (maxTotalBytes * 0.6).toInt();
    final maxMetadataBytes = (maxTotalBytes * 0.4).toInt();

    return CacheConfig(
      maxTotalSizeBytes: maxTotalBytes,
      maxAudioSizeBytes: maxAudioBytes,
      maxMetadataSizeBytes: maxMetadataBytes,
    );
  }

  /// Save config to SharedPreferences
  static Future<void> save(int maxSizeMB) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cache_max_size_mb', maxSizeMB);
  }
}

/// Main cache manager with LRU eviction
class CacheManager {
  final CacheDatabase _db = CacheDatabase.instance;
  CacheConfig _config = const CacheConfig();

  // Singleton pattern
  CacheManager._();
  static final CacheManager instance = CacheManager._();

  /// Initialize the cache manager
  Future<void> initialize() async {
    _config = await CacheConfig.load();
  }

  /// Update cache configuration
  Future<void> updateConfig(int maxSizeMB) async {
    await CacheConfig.save(maxSizeMB);
    _config = await CacheConfig.load();
    await _enforceLimit();
  }

  // ── Metadata cache operations ──────────────────────────────────────────

  /// Get metadata from cache
  Future<Map<String, dynamic>?> getMetadata(String key) async {
    final db = await _db.database;
    final results = await db.query(
      'cache_metadata',
      where: 'cache_key = ?',
      whereArgs: [key],
    );

    if (results.isEmpty) return null;

    final row = results.first;
    final expiresAt = row['expires_at'] as int?;

    // Check if expired
    if (expiresAt != null &&
        expiresAt < DateTime.now().millisecondsSinceEpoch) {
      await deleteMetadata(key);
      return null;
    }

    // Update last accessed time
    await db.update(
      'cache_metadata',
      {'last_accessed': DateTime.now().millisecondsSinceEpoch},
      where: 'cache_key = ?',
      whereArgs: [key],
    );

    final jsonStr = row['data'] as String;
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  /// Put metadata into cache
  Future<void> putMetadata(
    String key,
    CacheType type,
    Map<String, dynamic> data, {
    Duration? ttl,
  }) async {
    final db = await _db.database;
    final jsonStr = jsonEncode(data);
    final sizeBytes = jsonStr.length;
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = ttl != null ? now + ttl.inMilliseconds : null;

    await db.insert('cache_metadata', {
      'cache_key': key,
      'cache_type': type.name,
      'data': jsonStr,
      'size_bytes': sizeBytes,
      'created_at': now,
      'last_accessed': now,
      'expires_at': expiresAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await _enforceLimit();
  }

  /// Get metadata from cache, ignoring TTL expiration (for offline fallback)
  Future<Map<String, dynamic>?> getMetadataStale(String key) async {
    final db = await _db.database;
    final results = await db.query(
      'cache_metadata',
      where: 'cache_key = ?',
      whereArgs: [key],
    );

    if (results.isEmpty) return null;

    final row = results.first;

    // Update last accessed time
    await db.update(
      'cache_metadata',
      {'last_accessed': DateTime.now().millisecondsSinceEpoch},
      where: 'cache_key = ?',
      whereArgs: [key],
    );

    final jsonStr = row['data'] as String;
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  /// Delete metadata from cache
  Future<void> deleteMetadata(String key) async {
    final db = await _db.database;
    await db.delete('cache_metadata', where: 'cache_key = ?', whereArgs: [key]);
  }

  // ── File cache operations ──────────────────────────────────────────────

  /// Get file path from cache
  Future<File?> getFile(String key) async {
    final db = await _db.database;
    final results = await db.query(
      'cache_files',
      where: 'cache_key = ?',
      whereArgs: [key],
    );

    if (results.isEmpty) return null;

    final row = results.first;
    final filePath = row['file_path'] as String;
    final file = File(filePath);

    if (!await file.exists()) {
      await deleteFile(key);
      return null;
    }

    // Update last accessed time
    await db.update(
      'cache_files',
      {'last_accessed': DateTime.now().millisecondsSinceEpoch},
      where: 'cache_key = ?',
      whereArgs: [key],
    );

    return file;
  }

  /// Put file into cache
  Future<void> putFile(
    String key,
    FileType type,
    File sourceFile, {
    int? resourceId,
  }) async {
    final db = await _db.database;
    final cacheDir = await _getCacheDir(type);
    final extension = p.extension(sourceFile.path);
    final filename = '$key$extension';
    final destPath = p.join(cacheDir.path, filename);

    // Copy file to cache directory
    final destFile = await sourceFile.copy(destPath);
    final sizeBytes = await destFile.length();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert('cache_files', {
      'cache_key': key,
      'file_type': type.name,
      'file_path': destPath,
      'size_bytes': sizeBytes,
      'created_at': now,
      'last_accessed': now,
      'resource_id': resourceId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await _enforceLimit();
  }

  /// Delete file from cache
  Future<void> deleteFile(String key) async {
    final db = await _db.database;
    final results = await db.query(
      'cache_files',
      columns: ['file_path'],
      where: 'cache_key = ?',
      whereArgs: [key],
    );

    if (results.isNotEmpty) {
      final filePath = results.first['file_path'] as String;
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await db.delete('cache_files', where: 'cache_key = ?', whereArgs: [key]);
  }

  // ── Favorites cache operations ─────────────────────────────────────────

  /// Get all favorite track IDs
  Future<Set<int>> getFavorites() async {
    final db = await _db.database;
    final results = await db.query('cache_favorites');
    return results.map((row) => row['track_id'] as int).toSet();
  }

  /// Add track to favorites
  Future<void> addFavorite(int trackId) async {
    final db = await _db.database;
    await db.insert('cache_favorites', {
      'track_id': trackId,
      'added_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Remove track from favorites
  Future<void> removeFavorite(int trackId) async {
    final db = await _db.database;
    await db.delete(
      'cache_favorites',
      where: 'track_id = ?',
      whereArgs: [trackId],
    );
  }

  // ── Cache statistics and management ────────────────────────────────────

  /// Get current cache size statistics
  Future<CacheStats> getStats() async {
    final db = await _db.database;

    // Get metadata size
    final metadataResult = await db.rawQuery(
      'SELECT COALESCE(SUM(size_bytes), 0) as total FROM cache_metadata',
    );
    final metadataSize = metadataResult.first['total'] as int;

    // Get file sizes by type
    final audioResult = await db.rawQuery(
      'SELECT COALESCE(SUM(size_bytes), 0) as total FROM cache_files WHERE file_type = ?',
      [FileType.audio.name],
    );
    final audioSize = audioResult.first['total'] as int;

    final imageResult = await db.rawQuery(
      'SELECT COALESCE(SUM(size_bytes), 0) as total FROM cache_files WHERE file_type = ?',
      [FileType.coverArt.name],
    );
    final imageSize = imageResult.first['total'] as int;

    // Get counts
    final metadataCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM cache_metadata'),
        ) ??
        0;

    final audioCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM cache_files WHERE file_type = ?',
            [FileType.audio.name],
          ),
        ) ??
        0;

    final imageCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM cache_files WHERE file_type = ?',
            [FileType.coverArt.name],
          ),
        ) ??
        0;

    return CacheStats(
      metadataSize: metadataSize,
      audioSize: audioSize,
      imageSize: imageSize,
      totalSize: metadataSize + audioSize + imageSize,
      metadataCount: metadataCount,
      audioCount: audioCount,
      imageCount: imageCount,
      maxTotalSize: _config.maxTotalSizeBytes,
      maxAudioSize: _config.maxAudioSizeBytes,
      maxMetadataSize: _config.maxMetadataSizeBytes,
    );
  }

  /// Clear all cache
  Future<void> clearAll() async {
    final db = await _db.database;

    // Delete all files
    final fileResults = await db.query('cache_files');
    for (final row in fileResults) {
      final filePath = row['file_path'] as String;
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Clear all tables
    await db.delete('cache_metadata');
    await db.delete('cache_files');
    // Keep favorites - they're not large and users expect them to persist
  }

  /// Clear only audio files
  Future<void> clearAudio() async {
    final db = await _db.database;
    final results = await db.query(
      'cache_files',
      where: 'file_type = ?',
      whereArgs: [FileType.audio.name],
    );

    for (final row in results) {
      final filePath = row['file_path'] as String;
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await db.delete(
      'cache_files',
      where: 'file_type = ?',
      whereArgs: [FileType.audio.name],
    );
  }

  // ── Private helper methods ─────────────────────────────────────────────

  /// Get cache directory for a specific file type
  Future<Directory> _getCacheDir(FileType type) async {
    final appDir = await getApplicationCacheDirectory();
    final dir = Directory(p.join(appDir.path, type.name));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Enforce cache size limits using LRU eviction
  Future<void> _enforceLimit() async {
    final db = await _db.database;

    // Check audio file size
    final audioResult = await db.rawQuery(
      'SELECT COALESCE(SUM(size_bytes), 0) as total FROM cache_files WHERE file_type = ?',
      [FileType.audio.name],
    );
    var audioSize = audioResult.first['total'] as int;

    // Evict oldest audio files if over limit
    while (audioSize > _config.maxAudioSizeBytes) {
      final oldestAudio = await db.query(
        'cache_files',
        where: 'file_type = ?',
        whereArgs: [FileType.audio.name],
        orderBy: 'last_accessed ASC',
        limit: 1,
      );

      if (oldestAudio.isEmpty) break;

      final key = oldestAudio.first['cache_key'] as String;
      final size = oldestAudio.first['size_bytes'] as int;
      await deleteFile(key);
      audioSize -= size;
    }

    // Check metadata + image size
    final metadataResult = await db.rawQuery(
      'SELECT COALESCE(SUM(size_bytes), 0) as total FROM cache_metadata',
    );
    var metadataSize = metadataResult.first['total'] as int;

    final imageResult = await db.rawQuery(
      'SELECT COALESCE(SUM(size_bytes), 0) as total FROM cache_files WHERE file_type = ?',
      [FileType.coverArt.name],
    );
    var imageSize = imageResult.first['total'] as int;
    var metadataAndImageSize = metadataSize + imageSize;

    // Evict oldest images first (prefer keeping metadata for offline browsing)
    while (metadataAndImageSize > _config.maxMetadataSizeBytes) {
      final oldestImage = await db.query(
        'cache_files',
        where: 'file_type = ?',
        whereArgs: [FileType.coverArt.name],
        orderBy: 'last_accessed ASC',
        limit: 1,
      );

      if (oldestImage.isNotEmpty) {
        final key = oldestImage.first['cache_key'] as String;
        final size = oldestImage.first['size_bytes'] as int;
        await deleteFile(key);
        metadataAndImageSize -= size;
        continue;
      }

      // If no more images, evict oldest metadata
      final oldestMetadata = await db.query(
        'cache_metadata',
        orderBy: 'last_accessed ASC',
        limit: 1,
      );

      if (oldestMetadata.isEmpty) break;

      final key = oldestMetadata.first['cache_key'] as String;
      final size = oldestMetadata.first['size_bytes'] as int;
      await deleteMetadata(key);
      metadataAndImageSize -= size;
    }
  }
}

/// Cache statistics
class CacheStats {
  final int metadataSize;
  final int audioSize;
  final int imageSize;
  final int totalSize;
  final int metadataCount;
  final int audioCount;
  final int imageCount;
  final int maxTotalSize;
  final int maxAudioSize;
  final int maxMetadataSize;

  const CacheStats({
    required this.metadataSize,
    required this.audioSize,
    required this.imageSize,
    required this.totalSize,
    required this.metadataCount,
    required this.audioCount,
    required this.imageCount,
    required this.maxTotalSize,
    required this.maxAudioSize,
    required this.maxMetadataSize,
  });

  double get usedPercentage =>
      maxTotalSize > 0 ? (totalSize / maxTotalSize) * 100 : 0;

  String get totalSizeMB => (totalSize / (1024 * 1024)).toStringAsFixed(1);
  String get maxTotalSizeMB =>
      (maxTotalSize / (1024 * 1024)).toStringAsFixed(0);
  String get audioSizeMB => (audioSize / (1024 * 1024)).toStringAsFixed(1);
  String get metadataSizeMB =>
      (metadataSize / (1024 * 1024)).toStringAsFixed(1);
  String get imageSizeMB => (imageSize / (1024 * 1024)).toStringAsFixed(1);
}
