import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:tayra/core/cache/cache_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aptabase_flutter/aptabase_flutter.dart';

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
    // Use decimal bytes for alignment with UI slider (1 MB = 1,000,000 bytes)
    this.maxTotalSizeBytes = 500 * 1000000, // 500 MB
    this.maxAudioSizeBytes = 300 * 1000000, // 300 MB
    this.maxMetadataSizeBytes = 200 * 1000000, // 200 MB
  });

  /// Load config from SharedPreferences
  static Future<CacheConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Read stored preference. Older versions mistakenly stored the value in
    // bytes instead of MB — detect that and normalize to MB.
    final rawValue = prefs.getInt('cache_max_size_mb');
    int maxSizeMB;
    if (rawValue == null) {
      maxSizeMB = 500;
    } else if (rawValue > 1000000) {
      // Looks like bytes were stored. Older versions used base-1024 when
      // converting MB->bytes (MB * 1024 * 1024). Detect that and recover
      // the original MB if possible, otherwise fall back to decimal MB.
      final mbFromBinary = rawValue / (1024 * 1024);
      final roundedBinary = mbFromBinary.roundToDouble();
      if ((mbFromBinary - roundedBinary).abs() < 0.01) {
        // Very close to an integer — assume it was binary MB
        maxSizeMB = roundedBinary.toInt();
      } else {
        // Otherwise treat stored value as decimal bytes
        maxSizeMB = (rawValue / 1000000).round();
      }
    } else {
      maxSizeMB = rawValue;
    }

    // Convert MB (decimal) to bytes
    final maxTotalBytes = maxSizeMB * 1000000;

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
  // Queue used to serialize calls to the eviction routine. Multiple
  // concurrent writes may call the eviction logic; chaining via this
  // future ensures only one eviction runs at a time and avoids races.
  Future<void> _enforceQueue = Future.value();

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
    // After reconciling files that may have been left on disk, ensure the
    // cache size limits are enforced. This handles the case where files
    // existed on disk (or old DB rows) and the total size now exceeds the
    // configured limit on startup.
    try {
      await _enforceLimit();
    } catch (e) {
      debugPrint('CacheManager: _enforceLimit failed during initialize: $e');
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
    // Use UTF-8 byte length for accurate size accounting (jsonStr.length
    // returns UTF-16 code units which doesn't reflect actual storage bytes).
    final sizeBytes = utf8.encode(jsonStr).length;
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

    // Ensure the destination directory exists (belt-and-suspenders — _getCacheDir
    // should have created it, but on macOS the directory may not be present if
    // the app container is newly created or the path_provider returns an
    // unexpected temp directory that shares the same cache root).
    await Directory(p.dirname(destPath)).create(recursive: true);

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
    // Telemetry: manual download flag changed (fires for both add and remove)
    try {
      Aptabase.instance.trackEvent('manual_download_toggled', {
        'resource_type': type.name,
        'enabled': value,
      });
    } catch (_) {}
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

    // Read preference directly to ensure the UI shows the value the user
    // selected in the settings slider (stored as MB). Handle legacy stored
    // values that might be in bytes.
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getInt('cache_max_size_mb');
    int maxSizeMB;
    if (rawValue == null) {
      maxSizeMB = _config.maxTotalSizeBytes ~/ 1000000;
    } else if (rawValue > 1000000) {
      // If prefs contains bytes, try to detect binary vs decimal storage.
      final mbFromBinary = rawValue / (1024 * 1024);
      final roundedBinary = mbFromBinary.roundToDouble();
      if ((mbFromBinary - roundedBinary).abs() < 0.01) {
        maxSizeMB = roundedBinary.toInt();
      } else {
        maxSizeMB = (rawValue / 1000000).round();
      }
    } else {
      maxSizeMB = rawValue;
    }

    final maxTotalBytes = maxSizeMB * 1000000;

    return CacheStats(
      metadataSize: metadataSize,
      audioSize: audioSize,
      imageSize: imageSize,
      totalSize: metadataSize + audioSize + imageSize,
      metadataCount: metadataCount,
      audioCount: audioCount,
      imageCount: imageCount,
      maxTotalSize: maxTotalBytes,
      maxTotalSizeMB: maxSizeMB,
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
    final appDir = await getApplicationCacheDirectory();
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
  ///
  /// Wrapper that serializes eviction runs. It chains executions onto
  /// [_enforceQueue] so concurrent callers are executed sequentially.
  Future<void> _enforceLimit() {
    final run = _enforceQueue.then((_) async {
      try {
        await _enforceLimitInternal();
      } catch (e, st) {
        debugPrint('Cache: _enforceLimitInternal failed: $e $st');
      }
    });
    // Ensure any errors do not break the queue chain.
    _enforceQueue = run.catchError((_) {});
    return run;
  }

  // ── Listen-history-aware eviction scoring ───────────────────────────
  //
  // Instead of pure LRU, audio eviction uses a composite score that
  // factors in how often the user listens to each track. The score is:
  //
  //   eviction_score = last_accessed
  //                    + (all_time_plays × _kPlayBonusMs)
  //                    + (recent_plays   × _kRecentPlayBonusMs)
  //
  // Lower score → evicted first. Each all-time play adds 1 day of
  // "freshness"; each play in the last 90 days adds an extra 7 days.
  // Protected (manually downloaded) files are always skipped.

  /// Bonus added per all-time play (1 day in milliseconds).
  static const _kPlayBonusMs = 86400000;

  /// Extra bonus per play in the last 90 days (7 days in milliseconds).
  static const _kRecentPlayBonusMs = 7 * 86400000;

  /// Cutoff for "recent" plays — 90 days in milliseconds.
  static const _kRecentWindowMs = 90 * 86400000;

  // Actual eviction implementation. Kept separate so the wrapper can
  // serialize calls and handle errors without exposing the internal
  // implementation to callers.
  Future<void> _enforceLimitInternal() async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final recentCutoff = now - _kRecentWindowMs;

    // Check audio file size
    final audioResult = await db.rawQuery(
      'SELECT COALESCE(SUM(size_bytes), 0) as total FROM cache_files WHERE file_type = ?',
      [FileType.audio.name],
    );
    var audioSize = audioResult.first['total'] as int;

    // Evict audio files scored by listen history + recency.
    while (audioSize > _config.maxAudioSizeBytes) {
      final candidates = await db.rawQuery(
        '''
        SELECT
          cf.cache_key,
          cf.size_bytes,
          cf.last_accessed
            + COALESCE(lh.all_time_plays, 0) * $_kPlayBonusMs
            + COALESCE(lh.recent_plays, 0)   * $_kRecentPlayBonusMs
            AS eviction_score
        FROM cache_files cf
        LEFT JOIN (
          SELECT
            track_id,
            COUNT(*) AS all_time_plays,
            SUM(CASE WHEN listened_at >= ? THEN 1 ELSE 0 END) AS recent_plays
          FROM listen_history
          GROUP BY track_id
        ) lh ON lh.track_id = cf.resource_id
        WHERE cf.file_type = ?
          AND (cf.is_protected IS NULL OR cf.is_protected = 0)
        ORDER BY eviction_score ASC
        LIMIT 1
      ''',
        [recentCutoff, FileType.audio.name],
      );

      if (candidates.isEmpty) break;

      final key = candidates.first['cache_key'] as String;
      final size = candidates.first['size_bytes'] as int;
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

    // Finally, enforce the overall total cache size limit.
    //
    // Eviction priority (tracks dropped first, album data preserved):
    //   1. Non-protected audio files (scored by listen history)
    //   2. Cover art images (LRU)
    //   3. Metadata (LRU)
    var totalResult = await db.rawQuery(
      'SELECT COALESCE(SUM(size_bytes), 0) as total FROM cache_files',
    );
    final filesTotal = totalResult.first['total'] as int;
    final metaResult = await db.rawQuery(
      'SELECT COALESCE(SUM(size_bytes), 0) as total FROM cache_metadata',
    );
    var totalSize = (filesTotal) + (metaResult.first['total'] as int);

    while (totalSize > _config.maxTotalSizeBytes) {
      // Phase 1: try to evict non-protected audio (scored by listen history)
      final audioCandidate = await db.rawQuery(
        '''
        SELECT
          cf.cache_key,
          cf.size_bytes,
          cf.last_accessed
            + COALESCE(lh.all_time_plays, 0) * $_kPlayBonusMs
            + COALESCE(lh.recent_plays, 0)   * $_kRecentPlayBonusMs
            AS eviction_score
        FROM cache_files cf
        LEFT JOIN (
          SELECT
            track_id,
            COUNT(*) AS all_time_plays,
            SUM(CASE WHEN listened_at >= ? THEN 1 ELSE 0 END) AS recent_plays
          FROM listen_history
          GROUP BY track_id
        ) lh ON lh.track_id = cf.resource_id
        WHERE cf.file_type = ?
          AND (cf.is_protected IS NULL OR cf.is_protected = 0)
        ORDER BY eviction_score ASC
        LIMIT 1
      ''',
        [recentCutoff, FileType.audio.name],
      );

      if (audioCandidate.isNotEmpty) {
        final key = audioCandidate.first['cache_key'] as String;
        final size = audioCandidate.first['size_bytes'] as int;
        try {
          await deleteFile(key);
        } catch (e) {
          debugPrint('Cache: failed to evict audio $key: $e');
          break;
        }
        totalSize -= size;
        continue;
      }

      // Phase 2: no more audio — evict cover art (LRU)
      final imageCandidate = await db.rawQuery('''
        SELECT cache_key, size_bytes FROM cache_files
        WHERE file_type = ?
          AND (is_protected IS NULL OR is_protected = 0)
        ORDER BY last_accessed ASC
        LIMIT 1
      ''', [FileType.coverArt.name]);

      if (imageCandidate.isNotEmpty) {
        final key = imageCandidate.first['cache_key'] as String;
        final size = imageCandidate.first['size_bytes'] as int;
        try {
          await deleteFile(key);
        } catch (e) {
          debugPrint('Cache: failed to evict cover art $key: $e');
          break;
        }
        totalSize -= size;
        continue;
      }

      // Phase 3: no more files — evict metadata (LRU)
      final metaCandidate = await db.query(
        'cache_metadata',
        orderBy: 'last_accessed ASC',
        limit: 1,
      );

      if (metaCandidate.isEmpty) break;

      final key = metaCandidate.first['cache_key'] as String;
      final size = metaCandidate.first['size_bytes'] as int;
      try {
        await deleteMetadata(key);
      } catch (e) {
        debugPrint('Cache: failed to evict metadata $key: $e');
        break;
      }
      totalSize -= size;
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
  final int maxTotalSizeMB;
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
    required this.maxTotalSizeMB,
    required this.maxAudioSize,
    required this.maxMetadataSize,
  });

  double get usedPercentage =>
      maxTotalSize > 0 ? (totalSize / maxTotalSize) * 100 : 0;

  // Legacy getters (keep for API compatibility) but use decimal MB
  String get totalSizeMB => (totalSize / 1000000.0).toStringAsFixed(1);
  // legacy string getter removed; prefer using `maxTotalSizeMB` (int) and
  // `maxTotalSizeDisplay` for human-readable text.
  String get audioSizeMB => (audioSize / 1000000.0).toStringAsFixed(1);
  String get metadataSizeMB => (metadataSize / 1000000.0).toStringAsFixed(1);
  String get imageSizeMB => (imageSize / 1000000.0).toStringAsFixed(1);

  // Human-friendly display values. Show GB when size is 1 GB or larger.
  // Use base-10 (SI) units so displayed MB/GB align with the settings slider
  // which works in decimal MB (e.g. 5000 MB = 5 GB). 1 MB = 1,000,000 bytes.
  String _formatBytesReadable(int bytes) {
    final mb = bytes / 1000000.0; // decimal MB
    if (mb >= 1000.0) {
      final gb = mb / 1000.0;
      return '${gb.toStringAsFixed(1)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  String get totalSizeDisplay => _formatBytesReadable(totalSize);
  // Prefer to display the configured MB value so it matches the slider.
  String get maxTotalSizeDisplay {
    final mb = maxTotalSizeMB;
    if (mb >= 1000) {
      return '${(mb / 1000.0).toStringAsFixed(1)} GB';
    }
    return '$mb MB';
  }

  String get audioSizeDisplay => _formatBytesReadable(audioSize);
  String get metadataSizeDisplay => _formatBytesReadable(metadataSize);
  String get imageSizeDisplay => _formatBytesReadable(imageSize);
}
