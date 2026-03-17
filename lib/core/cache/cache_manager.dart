import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:tayra/core/cache/cache_database.dart';
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
    // Reconcile any files left on disk with the DB in case previous runs
    // copied files but failed to insert DB rows (prevents cached files from
    // being invisible to the UI).
    try {
      await reconcileAudioFiles();
    } catch (e) {
      debugPrint('CacheManager: reconcileAudioFiles failed: $e');
    }
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

    // Check if expired — return null but do NOT delete the row.
    // The stale row is kept so getMetadataStale() can serve it as an
    // offline fallback.  LRU eviction in _enforceLimit() handles removal.
    if (expiresAt != null &&
        expiresAt < DateTime.now().millisecondsSinceEpoch) {
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
    try {
      final parsed = jsonDecode(jsonStr);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (_) {}
    return <String, dynamic>{};
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
    try {
      final parsed = jsonDecode(jsonStr);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (_) {}
    return <String, dynamic>{};
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
    CacheType? resourceParentType,
    int? resourceParentId,
    bool isProtected = false,
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

    // Ensure optional columns exist (defensive migration for very old DBs)
    await _ensureCacheFilesColumns();

    // Insert DB row. If the DB insert fails for any reason, remove the
    // copied file to avoid leaving orphaned files on disk and rethrow so
    // callers can handle the failure.
    try {
      await db.insert('cache_files', {
        'cache_key': key,
        'file_type': type.name,
        'file_path': destPath,
        'size_bytes': sizeBytes,
        'created_at': now,
        'last_accessed': now,
        'resource_id': resourceId,
        'resource_parent_type': resourceParentType?.name,
        'resource_parent_id': resourceParentId,
        'is_protected': isProtected ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      // Attempt best-effort cleanup of the copied file
      try {
        if (await destFile.exists()) await destFile.delete();
      } catch (_) {}
      rethrow;
    }

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

  /// Mark cache file protected/unprotected by cache key.
  Future<void> setFileProtected(String key, bool protected) async {
    final db = await _db.database;
    await _ensureCacheFilesColumns();
    try {
      await db.update(
        'cache_files',
        {'is_protected': protected ? 1 : 0},
        where: 'cache_key = ?',
        whereArgs: [key],
      );
    } catch (e) {
      // Defensive migration: older DBs may lack the is_protected column.
      // Try to add the column and retry once.
      debugPrint(
        'setFileProtected failed, attempting to add is_protected column: $e',
      );
      try {
        await db.execute(
          "ALTER TABLE cache_files ADD COLUMN is_protected INTEGER DEFAULT 0",
        );
      } catch (_) {}
      // Retry update (ignore errors on retry)
      try {
        await db.update(
          'cache_files',
          {'is_protected': protected ? 1 : 0},
          where: 'cache_key = ?',
          whereArgs: [key],
        );
      } catch (_) {}
    }
  }

  /// Bulk set protection flag for all files that reference a given parent
  /// resource (album/playlist). This is faster than iterating per-file.
  Future<void> bulkSetFilesProtectedForParent(
    CacheType parentType,
    int parentId,
    bool protected,
  ) async {
    final db = await _db.database;
    await _ensureCacheFilesColumns();
    try {
      await db.update(
        'cache_files',
        {'is_protected': protected ? 1 : 0},
        where: 'resource_parent_type = ? AND resource_parent_id = ?',
        whereArgs: [parentType.name, parentId],
      );
    } catch (e) {
      // Defensive migration: add missing column then retry once.
      debugPrint(
        'bulkSetFilesProtectedForParent failed, attempting to add is_protected column: $e',
      );
      try {
        await db.execute(
          "ALTER TABLE cache_files ADD COLUMN is_protected INTEGER DEFAULT 0",
        );
      } catch (_) {}
      try {
        await db.update(
          'cache_files',
          {'is_protected': protected ? 1 : 0},
          where: 'resource_parent_type = ? AND resource_parent_id = ?',
          whereArgs: [parentType.name, parentId],
        );
      } catch (_) {}
    }
  }

  // ── Manual downloads operations ───────────────────────────────────────

  /// Mark or unmark a resource (track/album/playlist) as manually downloaded.
  Future<void> setManualDownloaded(
    CacheType type,
    int resourceId,
    bool value,
  ) async {
    final db = await _db.database;
    if (value) {
      await db.insert('cache_manual_downloads', {
        'resource_type': type.name,
        'resource_id': resourceId,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      try {
        await db.delete(
          'cache_manual_downloads',
          where: 'resource_id = ? AND resource_type = ?',
          whereArgs: [resourceId, type.name],
        );
      } catch (e) {
        debugPrint('setManualDownloaded delete failed: $e');
        // If delete fails due to missing table (very old DB), attempt to create
        try {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cache_manual_downloads (
              resource_type TEXT NOT NULL,
              resource_id INTEGER PRIMARY KEY,
              added_at INTEGER NOT NULL
            )
          ''');
          await db.delete(
            'cache_manual_downloads',
            where: 'resource_id = ? AND resource_type = ?',
            whereArgs: [resourceId, type.name],
          );
        } catch (_) {}
      }
    }
  }

  /// Check if a resource is manually downloaded
  Future<bool> isManualDownloaded(CacheType type, int resourceId) async {
    final db = await _db.database;
    final results = await db.query(
      'cache_manual_downloads',
      where: 'resource_id = ? AND resource_type = ?',
      whereArgs: [resourceId, type.name],
    );
    return results.isNotEmpty;
  }

  /// Return all track IDs that have been marked as manually downloaded.
  Future<List<int>> getManualDownloadedTrackIds() async {
    final db = await _db.database;
    final results = await db.query(
      'cache_manual_downloads',
      columns: ['resource_id'],
      where: 'resource_type = ?',
      whereArgs: [CacheType.track.name],
    );
    return results.map((r) => r['resource_id'] as int).toList();
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

  /// Check if an audio file for [trackId] exists on disk.
  ///
  /// This is the primary source-of-truth check — it scans the audio cache
  /// directory for any file whose name matches `audio_<trackId>.<ext>`.
  /// Checking the filesystem directly prevents DB/disk divergence (e.g. a
  /// file that exists but has no DB row will still be reported as cached).
  Future<bool> audioFileExistsOnDisk(int trackId) async {
    try {
      final audioDir = await _getCacheDir(FileType.audio);
      final prefix = 'audio_$trackId.';
      final entities = audioDir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (name.startsWith(prefix)) return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Private helper methods ─────────────────────────────────────────────

  /// Get cache directory for a specific file type
  Future<Directory> _getCacheDir(FileType type) async {
    // Use application support directory for persistent cache storage.
    // `getApplicationCacheDirectory` does not exist in `path_provider` and
    // caused cache initialization to fail on startup; using
    // `getApplicationSupportDirectory` provides a stable, persistent folder
    // appropriate for app-managed cache files across platforms.
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, type.name));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Ensure optional columns exist on the `cache_files` table. Uses
  /// `PRAGMA table_info` to detect existing columns and performs `ALTER TABLE`
  /// to add any missing columns. This avoids relying on exceptions from
  /// executing statements against older DB schemas.
  Future<void> _ensureCacheFilesColumns() async {
    final db = await _db.database;
    try {
      final info = await db.rawQuery("PRAGMA table_info('cache_files')");
      final existing = <String>{};
      for (final row in info) {
        final name = row['name'];
        if (name is String) existing.add(name);
      }

      if (!existing.contains('resource_parent_type')) {
        try {
          await db.execute(
            "ALTER TABLE cache_files ADD COLUMN resource_parent_type TEXT",
          );
        } catch (_) {}
      }
      if (!existing.contains('resource_parent_id')) {
        try {
          await db.execute(
            "ALTER TABLE cache_files ADD COLUMN resource_parent_id INTEGER",
          );
        } catch (_) {}
      }
      if (!existing.contains('is_protected')) {
        try {
          await db.execute(
            "ALTER TABLE cache_files ADD COLUMN is_protected INTEGER DEFAULT 0",
          );
        } catch (_) {}
      }
    } catch (e) {
      // Best-effort: if anything goes wrong querying PRAGMA, attempt
      // to add the columns defensively (older DBs on some platforms may
      // behave differently). Ignore all errors — this is purely a
      // defensive migration helper.
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
  }

  /// Reconcile audio files on disk with the database. This repairs cases
  /// where a file exists in the cache directory but the corresponding DB
  /// row is missing (e.g. leftover from earlier failures). It will insert
  /// a minimal DB row so providers like `isAudioCachedProvider` return
  /// true when the file is present.
  Future<void> reconcileAudioFiles() async {
    final db = await _db.database;
    final audioDir = await _getCacheDir(FileType.audio);
    final files = audioDir.listSync().whereType<File>();
    for (final file in files) {
      final name = p.basename(file.path);
      // Expect filenames like 'audio_<id>.<ext>'
      if (!name.startsWith('audio_')) continue;
      final key = p.basenameWithoutExtension(name); // audio_<id>
      final exists = await db.query(
        'cache_files',
        where: 'cache_key = ?',
        whereArgs: [key],
      );
      if (exists.isNotEmpty) continue;

      // Try to extract an integer resource_id from the key
      int? resourceId;
      try {
        final parts = key.split('_');
        if (parts.length >= 2) resourceId = int.tryParse(parts[1]);
      } catch (_) {
        resourceId = null;
      }

      final sizeBytes = await file.length();
      final now = DateTime.now().millisecondsSinceEpoch;
      try {
        await db.insert('cache_files', {
          'cache_key': key,
          'file_type': FileType.audio.name,
          'file_path': file.path,
          'size_bytes': sizeBytes,
          'created_at': now,
          'last_accessed': now,
          'resource_id': resourceId,
          'resource_parent_type': null,
          'resource_parent_id': null,
          'is_protected': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (e) {
        debugPrint(
          'reconcileAudioFiles: failed to insert row for ${file.path}: $e',
        );
      }
    }
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
      // Evict oldest audio files if over limit, but skip protected files
      final oldestAudio = await db.rawQuery(
        '''
        SELECT cache_key, size_bytes FROM cache_files
        WHERE file_type = ? AND (is_protected IS NULL OR is_protected = 0)
        ORDER BY last_accessed ASC
        LIMIT 1
      ''',
        [FileType.audio.name],
      );

      if (oldestAudio.isEmpty) break;

      final key = oldestAudio.first['cache_key'] as String;
      final size = oldestAudio.first['size_bytes'] as int;
      try {
        await deleteFile(key);
      } catch (e) {
        debugPrint('Cache: failed to evict audio file $key: $e');
        break;
      }
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
        try {
          await deleteFile(key);
        } catch (e) {
          debugPrint('Cache: failed to evict cover art $key: $e');
          break;
        }
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
