import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/cache/cache_database.dart';
import 'package:tayra/core/api/models.dart';

// ── Listen history record ───────────────────────────────────────────────

/// A single listen event stored in the local database.
class ListenRecord {
  final int? id;
  final int trackId;
  final String trackTitle;
  final int? artistId;
  final String artistName;
  final int? albumId;
  final String albumTitle;
  final String? coverUrl;
  final int? durationSeconds;
  final DateTime listenedAt;
  final String? sourceDevice;

  const ListenRecord({
    this.id,
    required this.trackId,
    required this.trackTitle,
    this.artistId,
    required this.artistName,
    this.albumId,
    required this.albumTitle,
    this.coverUrl,
    this.durationSeconds,
    required this.listenedAt,
    this.sourceDevice,
  });

  Map<String, dynamic> toMap() {
    return {
      'track_id': trackId,
      'track_title': trackTitle,
      'artist_id': artistId,
      'artist_name': artistName,
      'album_id': albumId,
      'album_title': albumTitle,
      'cover_url': coverUrl,
      'duration_seconds': durationSeconds,
      'listened_at': listenedAt.millisecondsSinceEpoch,
      if (sourceDevice != null) 'source_device': sourceDevice,
    };
  }

  factory ListenRecord.fromMap(Map<String, dynamic> map) {
    return ListenRecord(
      id: map['id'] as int?,
      trackId: map['track_id'] as int,
      trackTitle: map['track_title'] as String,
      artistId: map['artist_id'] as int?,
      artistName: map['artist_name'] as String,
      albumId: map['album_id'] as int?,
      albumTitle: map['album_title'] as String,
      coverUrl: map['cover_url'] as String?,
      durationSeconds: map['duration_seconds'] as int?,
      listenedAt: DateTime.fromMillisecondsSinceEpoch(
        map['listened_at'] as int,
      ),
      sourceDevice: map['source_device'] as String?,
    );
  }

  /// Create a ListenRecord from a Track. If [listenedSeconds] is provided
  /// it will be stored in the record; otherwise the track's full duration
  /// (if available) will be used.
  factory ListenRecord.fromTrack(Track track, {int? listenedSeconds}) {
    return ListenRecord(
      trackId: track.id,
      trackTitle: track.title,
      artistId: track.artist?.id,
      artistName: track.artistName,
      albumId: track.album?.id,
      albumTitle: track.albumTitle,
      coverUrl: track.coverUrl,
      durationSeconds: listenedSeconds ?? track.duration,
      listenedAt: DateTime.now(),
      sourceDevice: 'local',
    );
  }

  ListenRecord copyWith({
    int? id,
    int? trackId,
    String? trackTitle,
    int? artistId,
    String? artistName,
    int? albumId,
    String? albumTitle,
    String? coverUrl,
    int? durationSeconds,
    DateTime? listenedAt,
    String? sourceDevice,
  }) {
    return ListenRecord(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      trackTitle: trackTitle ?? this.trackTitle,
      artistId: artistId ?? this.artistId,
      artistName: artistName ?? this.artistName,
      albumId: albumId ?? this.albumId,
      albumTitle: albumTitle ?? this.albumTitle,
      coverUrl: coverUrl ?? this.coverUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      listenedAt: listenedAt ?? this.listenedAt,
      sourceDevice: sourceDevice ?? this.sourceDevice,
    );
  }

  /// Map for safe backup/restore JSON export (no id, no source_device).
  Map<String, dynamic> toMapForBackup() =>
      toMap()
        ..remove('id')
        ..remove('source_device');

  factory ListenRecord.fromBackupMap(Map<String, dynamic> map) {
    return ListenRecord.fromMap({
      ...map,
      if (!map.containsKey('id')) 'id': null,
    });
  }
}

// ── Year in review stats models ─────────────────────────────────────────

class TopItem {
  final String name;
  final String? subtitle;
  final String? coverUrl;
  final int count;
  final int? totalSeconds;

  /// Total listen rows (COUNT(*)), populated for album results to compute
  /// play-through counts. Null for tracks and artists.
  final int? totalListens;

  /// The number of tracks on this album (from the API), populated for album
  /// results. Null for tracks and artists.
  final int? albumTrackCount;

  const TopItem({
    required this.name,
    this.subtitle,
    this.coverUrl,
    required this.count,
    this.totalSeconds,
    this.totalListens,
    this.albumTrackCount,
  });
}

class MonthlyListens {
  final int month;
  final int count;
  final int totalSeconds;

  const MonthlyListens({
    required this.month,
    required this.count,
    required this.totalSeconds,
  });
}

/// A track the user favorited, enriched with listen count for the year.
class FavoritedTrack {
  final int trackId;
  final String trackTitle;
  final String artistName;
  final String? coverUrl;

  /// How many times this track was played in the year (may be 0 if never
  /// played in that year despite being a favourite).
  final int listenCount;

  const FavoritedTrack({
    required this.trackId,
    required this.trackTitle,
    required this.artistName,
    this.coverUrl,
    required this.listenCount,
  });
}

// ── Weekly stats model ──────────────────────────────────────────────────

class WeeklyStats {
  final int playCount;
  final int totalSeconds;
  final String? topArtistName;
  final int topArtistPlays;
  final String? topTrackTitle;
  final String? topTrackArtist;

  const WeeklyStats({
    required this.playCount,
    required this.totalSeconds,
    this.topArtistName,
    required this.topArtistPlays,
    this.topTrackTitle,
    this.topTrackArtist,
  });

  bool get hasData => playCount > 0;

  String get formattedTime {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

// ── Intermediate album row for sorting ────────────────────────────────────

class _AlbumRow {
  final int albumId;
  final String title;
  final String? artistName;
  final String? coverUrl;
  final int uniqueTracks;
  final int engagementScore;
  final int? totalSeconds;
  final int totalListens;

  const _AlbumRow({
    required this.albumId,
    required this.title,
    this.artistName,
    this.coverUrl,
    required this.uniqueTracks,
    required this.engagementScore,
    this.totalSeconds,
    required this.totalListens,
  });
}

class YearReviewStats {
  final int year;
  final int totalListens;
  final int totalSeconds;
  final int uniqueTracks;
  final int uniqueArtists;
  final int uniqueAlbums;
  final List<TopItem> topTracks;
  final List<TopItem> topArtists;
  final List<TopItem> topAlbums;
  final List<MonthlyListens> monthlyBreakdown;
  final TopItem? topTrack;
  final TopItem? topArtist;
  final TopItem? topAlbum;

  /// Tracks the user favourited during this year, sorted by listen count desc.
  ///
  /// Empty when the Favourites API is unavailable (e.g. offline) or when the
  /// user has not favourited anything this year.
  final List<FavoritedTrack> favoritedThisYear;

  /// The subset of [topTracks] that the user currently has favourited.
  /// Derived from [topTracks] × current favourite IDs at stats-fetch time.
  final List<TopItem> lovedTopTracks;

  /// The subset of [topTracks] that the user has NOT favourited — tracks they
  /// played heavily but never favorited.
  final List<TopItem> unlovedTopTracks;

  /// Per-device listen breakdown for this year.
  final List<DeviceStat> deviceStats;

  const YearReviewStats({
    required this.year,
    required this.totalListens,
    required this.totalSeconds,
    required this.uniqueTracks,
    required this.uniqueArtists,
    required this.uniqueAlbums,
    required this.topTracks,
    required this.topArtists,
    required this.topAlbums,
    required this.monthlyBreakdown,
    this.topTrack,
    this.topArtist,
    this.topAlbum,
    this.favoritedThisYear = const [],
    this.lovedTopTracks = const [],
    this.unlovedTopTracks = const [],
    this.deviceStats = const [],
  });

  bool get isEmpty => totalListens == 0;

  String get formattedTotalTime {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours hr $minutes min';
    }
    return '$minutes min';
  }

  int get peakMonth {
    if (monthlyBreakdown.isEmpty) return 0;
    var peak = monthlyBreakdown.first;
    for (final m in monthlyBreakdown) {
      if (m.count > peak.count) peak = m;
    }
    return peak.month;
  }
}

// ── Device stats model ──────────────────────────────────────────────────

class DeviceStat {
  final String deviceId;
  final int listenCount;
  final int totalSeconds;

  const DeviceStat({
    required this.deviceId,
    required this.listenCount,
    required this.totalSeconds,
  });

  String get displayName =>
      ListenHistoryService.resolveDeviceDisplayName(deviceId);

  double percentageOf(int total) => total > 0 ? listenCount / total : 0.0;
}

// ── Listen history service ──────────────────────────────────────────────

/// Service that manages local listen history storage and computes
/// year-in-review statistics. Data is stored in the app's SQLite database.
class ListenHistoryService {
  static const _tableName = 'listen_history';

  // ── Device display-name cache ──────────────────────────────────────────
  //
  // Remote backups carry a human-readable device name (see
  // NextcloudBackupService.getDeviceDisplayName) alongside the sanitized
  // device id used in filenames / source_device.  We persist a deviceId →
  // display-name map in SharedPreferences so the year-review screen can
  // render "Samsung SM-S908U" instead of guessing from "samsung_sm_s908u".
  static const _deviceNamesKey = 'tayra_device_display_names';
  static Map<String, String> _deviceDisplayNames = {};
  static bool _deviceNamesLoaded = false;

  static Future<void> _loadDeviceDisplayNames() async {
    if (_deviceNamesLoaded) return;
    _deviceNamesLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_deviceNamesKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _deviceDisplayNames = decoded.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          );
        }
      }
    } catch (_) {}
  }

  /// Ensure the device display-name cache is populated.  Call before reading
  /// [DeviceStat.displayName] so remote device names captured from backups
  /// are available without a fallback to the sanitized-id heuristic.
  static Future<void> loadDeviceDisplayNames() => _loadDeviceDisplayNames();

  /// Synchronously resolve a device id to a display name, using the cached
  /// remote-device-name map when available and falling back to a
  /// best-effort rendering of the sanitized id.  Call
  /// [loadDeviceDisplayNames] first to warm the cache.
  static String resolveDeviceDisplayName(String deviceId) {
    if (deviceId.isEmpty || deviceId == 'local') return 'This Device';
    final stored = _deviceDisplayNames[deviceId];
    if (stored != null && stored.isNotEmpty) return stored;
    return _formatDeviceId(deviceId);
  }

  /// Returns the cached display name for a remote device id, or `null` if
  /// no name has been recorded yet (so the caller can decide whether to
  /// fetch it from a backup).  `'local'` and empty ids resolve to
  /// `'This Device'`.
  static String? getCachedDeviceDisplayName(String deviceId) {
    if (deviceId.isEmpty || deviceId == 'local') return 'This Device';
    return _deviceDisplayNames[deviceId];
  }

  /// Record the human-readable name for a remote device id, persisted across
  /// launches.  Called when ingesting remote listening-history backups.
  static Future<void> setDeviceDisplayName(String deviceId, String name) async {
    if (deviceId.isEmpty || name.isEmpty || deviceId == 'local') return;
    await _loadDeviceDisplayNames();
    if (_deviceDisplayNames[deviceId] == name) return;
    _deviceDisplayNames[deviceId] = name;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceNamesKey, jsonEncode(_deviceDisplayNames));
    } catch (_) {}
  }

  /// Best-effort rendering of a sanitized device id when no display name was
  /// captured from a backup.  Words that look like model numbers (contain a
  /// digit) are upper-cased so "samsung_sm_s908u" → "Samsung SM S908U".
  static String _formatDeviceId(String deviceId) {
    return deviceId
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) {
          if (w.isEmpty) return '';
          if (RegExp(r'\d').hasMatch(w)) return w.toUpperCase();
          return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  /// Ensure the listen_history table exists. Called during app init.
  static Future<void> ensureTable() async {
    final db = await CacheDatabase.instance.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        track_id INTEGER NOT NULL,
        track_title TEXT NOT NULL,
        artist_id INTEGER,
        artist_name TEXT NOT NULL,
        album_id INTEGER,
        album_title TEXT NOT NULL,
        cover_url TEXT,
        duration_seconds INTEGER,
        listened_at INTEGER NOT NULL,
        source_device TEXT
      )
    ''');
    // Migrate: add source_device column for existing tables
    try {
      await db.execute('ALTER TABLE $_tableName ADD COLUMN source_device TEXT');
    } catch (_) {
      // Column already exists — ignore
    }
    // Any NULL source_device rows are this device's own listens from before
    // the column existed (or ingested by an older build that didn't tag
    // remote records). Tag them as 'local' so a later remote-history sync
    // can never claim them for another device via the dedup backfill.
    await db.execute(
      "UPDATE $_tableName SET source_device = 'local' "
      'WHERE source_device IS NULL',
    );
    // Index for year-based queries
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_listen_history_listened_at
      ON $_tableName(listened_at)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_listen_history_track_id
      ON $_tableName(track_id)
    ''');
  }

  /// Record a listen event for the given track.
  /// Record a listen event for the given track. [listenedSeconds] should be
  /// the number of seconds the user actually listened to this play session.
  /// If omitted the track's full duration (if available) will be stored.
  static Future<void> recordListen(Track track, {int? listenedSeconds}) async {
    try {
      await insertListen(track, listenedSeconds: listenedSeconds);
    } catch (_) {
      // Non-critical — silently fail
    }
  }

  /// Insert a listen row and return its database id.
  static Future<int> insertListen(
    Track track, {
    int? listenedSeconds,
    DateTime? listenedAt,
  }) async {
    final db = await CacheDatabase.instance.database;
    final record = ListenRecord.fromTrack(
      track,
      listenedSeconds: listenedSeconds,
    ).copyWith(listenedAt: listenedAt ?? DateTime.now());
    return db.insert(_tableName, record.toMap());
  }

  /// Update the listened duration for an existing row.
  static Future<void> updateListenDuration(int id, int listenedSeconds) async {
    final db = await CacheDatabase.instance.database;
    await db.update(
      _tableName,
      {'duration_seconds': listenedSeconds},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get all available years that have listen data.
  static Future<List<int>> getAvailableYears() async {
    final db = await CacheDatabase.instance.database;
    final results = await db.rawQuery('''
      SELECT DISTINCT
        CAST(strftime('%Y', listened_at / 1000, 'unixepoch') AS INTEGER) as year
      FROM $_tableName
      ORDER BY year DESC
    ''');
    return results.map((row) => (row['year'] as num).toInt()).toList();
  }

  /// Return distinct album IDs that have listens for the given year.
  static Future<List<int>> getDistinctAlbumIdsForYear(int year) async {
    final db = await CacheDatabase.instance.database;
    final startMs = DateTime(year).millisecondsSinceEpoch;
    final endMs = DateTime(year + 1).millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT album_id FROM $_tableName
      WHERE listened_at >= ? AND listened_at < ? AND album_id IS NOT NULL
    ''',
      [startMs, endMs],
    );
    return rows
        .map((r) => (r['album_id'] as num).toInt())
        .where((id) => id > 0)
        .toList();
  }

  /// Compute year-in-review statistics for the given year.
  ///
  /// [albumTrackCounts] maps album_id → total track count (from the API).
  /// When provided, top albums are sorted by `unique_tracks / albumTrackCounts[album_id]`
  /// (completion ratio). Falls back to engagement-score sort when null.
  static Future<YearReviewStats> getYearStats(
    int year, {
    Map<int, int>? albumTrackCounts,
  }) async {
    // Wrap the whole function in a try/catch so errors surface to logs
    // and we can see the exact exception when the UI shows the generic
    // "Could not load review data" message.
    try {
      final db = await CacheDatabase.instance.database;

      // Time range for the year
      final startMs = DateTime(year).millisecondsSinceEpoch;
      final endMs = DateTime(year + 1).millisecondsSinceEpoch;

      // Helper converters for SQLite result values (sqflite may return
      // ints or doubles for numeric columns, and values can be null).
      int toInt(dynamic v) => (v as num?)?.toInt() ?? 0;
      int? toNullableInt(dynamic v) => v == null ? null : (v as num).toInt();
      double toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

      // Total listens & time
      final totalsResult = await db.rawQuery(
        '''
      SELECT
        COUNT(*) as total_listens,
        COALESCE(SUM(duration_seconds), 0) as total_seconds,
        COUNT(DISTINCT track_id) as unique_tracks,
        COUNT(DISTINCT artist_name) as unique_artists,
        COUNT(DISTINCT album_title) as unique_albums
      FROM $_tableName
      WHERE listened_at >= ? AND listened_at < ?
    ''',
        [startMs, endMs],
      );

      final totals = totalsResult.first;
      final totalListens = toInt(totals['total_listens']);
      final totalSeconds = toInt(totals['total_seconds']);
      final uniqueTracks = toInt(totals['unique_tracks']);
      final uniqueArtists = toInt(totals['unique_artists']);
      final uniqueAlbums = toInt(totals['unique_albums']);

      // Top tracks (by play count)
      final topTracksResult = await db.rawQuery(
        '''
      SELECT
        track_title,
        artist_name,
        cover_url,
        COUNT(*) as play_count,
        COALESCE(SUM(duration_seconds), 0) as total_seconds
      FROM $_tableName
      WHERE listened_at >= ? AND listened_at < ?
      GROUP BY track_id
      ORDER BY play_count DESC
      LIMIT 10
    ''',
        [startMs, endMs],
      );

      final topTracks =
          topTracksResult
              .map(
                (row) => TopItem(
                  name: row['track_title'] as String,
                  subtitle: row['artist_name'] as String?,
                  coverUrl: row['cover_url'] as String?,
                  count: toInt(row['play_count']),
                  totalSeconds: toNullableInt(row['total_seconds']),
                ),
              )
              .toList();

      // Top artists (by play count)
      final topArtistsResult = await db.rawQuery(
        '''
      SELECT
        artist_name,
        COUNT(*) as play_count,
        COALESCE(SUM(duration_seconds), 0) as total_seconds,
        (SELECT cover_url FROM $_tableName t2
         WHERE t2.artist_name = $_tableName.artist_name
           AND t2.cover_url IS NOT NULL
           AND t2.listened_at >= ? AND t2.listened_at < ?
         ORDER BY t2.listened_at DESC LIMIT 1) as cover_url
      FROM $_tableName
      WHERE listened_at >= ? AND listened_at < ?
      GROUP BY artist_name
      ORDER BY play_count DESC
      LIMIT 10
    ''',
        [startMs, endMs, startMs, endMs],
      );

      final topArtists =
          topArtistsResult
              .map(
                (row) => TopItem(
                  name: row['artist_name'] as String,
                  coverUrl: row['cover_url'] as String?,
                  count: toInt(row['play_count']),
                  totalSeconds: toNullableInt(row['total_seconds']),
                ),
              )
              .toList();

      // Top albums — sorted by completion ratio: unique_tracks / album_track_count.
      // When [albumTrackCounts] is not available, falls back to engagement score.
      final topAlbumsResult = await db.rawQuery(
        '''
      SELECT
        album_id,
        album_title,
        artist_name,
        cover_url,
        COUNT(DISTINCT track_id) as unique_tracks,
        COUNT(*) as total_plays,
        COALESCE(SUM(duration_seconds), 0) as total_seconds,
        (
          SELECT SUM(play_count + 1)
          FROM (
            SELECT track_id, COUNT(*) as play_count
            FROM $_tableName t2
            WHERE t2.album_id = $_tableName.album_id
              AND t2.listened_at >= ? AND t2.listened_at < ?
            GROUP BY t2.track_id
          )
        ) as engagement_score
      FROM $_tableName
      WHERE listened_at >= ? AND listened_at < ?
        AND album_title != ''
      GROUP BY album_id
      ORDER BY engagement_score DESC
      LIMIT 50
    ''',
        [startMs, endMs, startMs, endMs],
      );

      // Build intermediate album data rows for sorting.
      final albumRows =
          topAlbumsResult
              .map(
                (row) => _AlbumRow(
                  albumId: toInt(row['album_id']),
                  title: row['album_title'] as String,
                  artistName: row['artist_name'] as String?,
                  coverUrl: row['cover_url'] as String?,
                  uniqueTracks: toInt(row['unique_tracks']),
                  engagementScore: toDouble(row['engagement_score']).round(),
                  totalSeconds: toNullableInt(row['total_seconds']),
                  totalListens: toInt(row['total_plays']),
                ),
              )
              .toList();

      // Sort by completion ratio when track counts are available.
      if (albumTrackCounts != null && albumTrackCounts.isNotEmpty) {
        albumRows.sort((a, b) {
          final aTotal = albumTrackCounts[a.albumId] ?? 0;
          final bTotal = albumTrackCounts[b.albumId] ?? 0;
          final aRatio = aTotal > 0 ? a.uniqueTracks / aTotal : 0.0;
          final bRatio = bTotal > 0 ? b.uniqueTracks / bTotal : 0.0;
          // Sort descending by ratio, then by unique tracks as tiebreaker.
          final cmp = bRatio.compareTo(aRatio);
          if (cmp != 0) return cmp;
          return b.uniqueTracks.compareTo(a.uniqueTracks);
        });
      } else {
        albumRows.sort(
          (a, b) => b.engagementScore.compareTo(a.engagementScore),
        );
      }

      final topAlbums =
          albumRows
              .take(10)
              .map(
                (row) => TopItem(
                  name: row.title,
                  subtitle: row.artistName,
                  coverUrl: row.coverUrl,
                  count:
                      albumTrackCounts != null
                          ? row.uniqueTracks
                          : row.engagementScore,
                  totalSeconds: row.totalSeconds,
                  totalListens: row.totalListens,
                  albumTrackCount:
                      albumTrackCounts != null
                          ? albumTrackCounts[row.albumId]
                          : null,
                ),
              )
              .toList();

      // Monthly breakdown
      final monthlyResult = await db.rawQuery(
        '''
      SELECT
        CAST(strftime('%m', listened_at / 1000, 'unixepoch') AS INTEGER) as month,
        COUNT(*) as listen_count,
        COALESCE(SUM(duration_seconds), 0) as total_seconds
      FROM $_tableName
      WHERE listened_at >= ? AND listened_at < ?
      GROUP BY month
      ORDER BY month
    ''',
        [startMs, endMs],
      );

      // Fill in all 12 months (even months with zero listens)
      final monthMap = <int, MonthlyListens>{};
      for (final row in monthlyResult) {
        final month = toInt(row['month']);
        monthMap[month] = MonthlyListens(
          month: month,
          count: toInt(row['listen_count']),
          totalSeconds: toInt(row['total_seconds']),
        );
      }
      final monthlyBreakdown = List.generate(12, (i) {
        final month = i + 1;
        return monthMap[month] ??
            MonthlyListens(month: month, count: 0, totalSeconds: 0);
      });

      return YearReviewStats(
        year: year,
        totalListens: totalListens,
        totalSeconds: totalSeconds,
        uniqueTracks: uniqueTracks,
        uniqueArtists: uniqueArtists,
        uniqueAlbums: uniqueAlbums,
        topTracks: topTracks,
        topArtists: topArtists,
        topAlbums: topAlbums,
        monthlyBreakdown: monthlyBreakdown,
        topTrack: topTracks.isNotEmpty ? topTracks.first : null,
        topArtist: topArtists.isNotEmpty ? topArtists.first : null,
        topAlbum: topAlbums.isNotEmpty ? topAlbums.first : null,
      );
    } catch (e, st) {
      // Use debugPrint so this shows up in Android logs during development.
      // Re-throw so Riverpod still surfaces the error to the UI provider
      // (which currently displays a generic message).
      debugPrint('YearReviewService.getYearStats error: $e\n$st');
      rethrow;
    }
  }

  /// Return the top track IDs for the given year ordered by play count.
  /// Useful for creating playlists from a user's most-listened tracks.
  static Future<List<int>> getTopTrackIdsForYear(
    int year, {
    int limit = 25,
  }) async {
    final db = await CacheDatabase.instance.database;
    final startMs = DateTime(year).millisecondsSinceEpoch;
    final endMs = DateTime(year + 1).millisecondsSinceEpoch;

    final rows = await db.rawQuery(
      '''
      SELECT track_id, COUNT(*) as play_count
      FROM $_tableName
      WHERE listened_at >= ? AND listened_at < ?
      GROUP BY track_id
      ORDER BY play_count DESC
      LIMIT ?
    ''',
      [startMs, endMs, limit],
    );

    // Convert possible numeric types to int
    return rows.map<int>((r) => (r['track_id'] as num).toInt()).toList();
  }

  /// Fetch the tracks the user favourited during [year], enriched with their
  /// listen count for that year.
  ///
  /// [allFavorites] is the full list of [Favorite] objects (already fetched
  /// from the server). We filter by [creationDate] here so that the caller can
  /// reuse the same list for other purposes without re-fetching.
  ///
  /// The returned list is sorted descending by listen count, then by title.
  static Future<List<FavoritedTrack>> getFavoritedThisYear(
    int year,
    List<dynamic /* Favorite */> allFavorites,
  ) async {
    // Filter favourites to those created in [year]. We import models.dart so
    // Favorite is available; the dynamic type lets callers from the provider
    // layer pass the list without a circular import.
    // The caller is responsible for passing Favorite objects.
    final db = await CacheDatabase.instance.database;
    final startMs = DateTime(year).millisecondsSinceEpoch;
    final endMs = DateTime(year + 1).millisecondsSinceEpoch;

    // Pre-load listen counts for this year keyed by track_id so we can do a
    // single DB query rather than one per favourite.
    final countRows = await db.rawQuery(
      '''
      SELECT track_id, COUNT(*) as play_count
      FROM $_tableName
      WHERE listened_at >= ? AND listened_at < ?
      GROUP BY track_id
    ''',
      [startMs, endMs],
    );

    final listenCountByTrackId = <int, int>{
      for (final row in countRows)
        (row['track_id'] as num).toInt(): (row['play_count'] as num).toInt(),
    };

    final result = <FavoritedTrack>[];
    for (final fav in allFavorites) {
      // Defensive: only include favourites created this year.
      final created = fav.creationDate as DateTime?;
      if (created == null) continue;
      if (created.year != year) continue;

      final track = fav.track;
      final trackId = track.id as int;
      result.add(
        FavoritedTrack(
          trackId: trackId,
          trackTitle: track.title as String,
          artistName: track.artistName as String,
          coverUrl: track.coverUrl as String?,
          listenCount: listenCountByTrackId[trackId] ?? 0,
        ),
      );
    }

    // Sort by listen count desc, then alphabetically as a tiebreaker.
    result.sort((a, b) {
      final cmp = b.listenCount.compareTo(a.listenCount);
      if (cmp != 0) return cmp;
      return a.trackTitle.compareTo(b.trackTitle);
    });

    return result;
  }

  /// Get listening stats for the past 7 days.
  static Future<WeeklyStats> getWeekStats() async {
    try {
      final db = await CacheDatabase.instance.database;
      final now = DateTime.now();
      final startMs =
          now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
      final endMs = now.millisecondsSinceEpoch;

      final totalsResult = await db.rawQuery(
        '''
        SELECT COUNT(*) as play_count,
               COALESCE(SUM(duration_seconds), 0) as total_seconds
        FROM $_tableName
        WHERE listened_at >= ? AND listened_at < ?
        ''',
        [startMs, endMs],
      );

      final topArtistResult = await db.rawQuery(
        '''
        SELECT artist_name, COUNT(*) as play_count
        FROM $_tableName
        WHERE listened_at >= ? AND listened_at < ?
        GROUP BY artist_name
        ORDER BY play_count DESC
        LIMIT 1
        ''',
        [startMs, endMs],
      );

      final topTrackResult = await db.rawQuery(
        '''
        SELECT track_title, artist_name, COUNT(*) as play_count
        FROM $_tableName
        WHERE listened_at >= ? AND listened_at < ?
        GROUP BY track_id
        ORDER BY play_count DESC
        LIMIT 1
        ''',
        [startMs, endMs],
      );

      final totals = totalsResult.first;
      return WeeklyStats(
        playCount: (totals['play_count'] as num).toInt(),
        totalSeconds: (totals['total_seconds'] as num).toInt(),
        topArtistName:
            topArtistResult.isNotEmpty
                ? topArtistResult.first['artist_name'] as String?
                : null,
        topArtistPlays:
            topArtistResult.isNotEmpty
                ? (topArtistResult.first['play_count'] as num).toInt()
                : 0,
        topTrackTitle:
            topTrackResult.isNotEmpty
                ? topTrackResult.first['track_title'] as String?
                : null,
        topTrackArtist:
            topTrackResult.isNotEmpty
                ? topTrackResult.first['artist_name'] as String?
                : null,
      );
    } catch (_) {
      return const WeeklyStats(
        playCount: 0,
        totalSeconds: 0,
        topArtistPlays: 0,
      );
    }
  }

  /// Get the total listen count (all time).
  static Future<int> getTotalListenCount() async {
    final db = await CacheDatabase.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName',
    );
    return (result.first['count'] as num).toInt();
  }

  /// Clear all listen history data.
  static Future<void> clearAll() async {
    final db = await CacheDatabase.instance.database;
    await db.delete(_tableName);
  }

  /// Clear only remote-device listen history (synced from Nextcloud).
  ///
  /// Local listens — those tagged `source_device = 'local'` (this device's
  /// own recordings, plus records restored by the rectifier from this
  /// device's own cloud backup) — are preserved.  Every other
  /// `source_device` value (a remote device's UUID, or a legacy sanitized
  /// deviceId from pre-UUID backups) is deleted.
  static Future<int> clearRemote() async {
    final db = await CacheDatabase.instance.database;
    return db.delete(
      _tableName,
      where: 'source_device IS NOT NULL AND source_device != ?',
      whereArgs: ['local'],
    );
  }

  /// Compute YearReviewStats purely from a provided list of ListenRecords (e.g. merged across devices).
  /// This does not hit the DB; used for combining with / replacing local queries in cross-device.
  static YearReviewStats computeStatsFromRecords(
    int year,
    List<ListenRecord> records,
  ) {
    // Filter exactly to year (defensive even if caller already filtered)
    final start = DateTime(year).millisecondsSinceEpoch;
    final end = DateTime(year + 1).millisecondsSinceEpoch;
    final filtered =
        records.where((r) {
          final ms = r.listenedAt.millisecondsSinceEpoch;
          return ms >= start && ms < end;
        }).toList();

    final totalListens = filtered.length;
    final totalSeconds = filtered.fold<int>(
      0,
      (s, r) => s + (r.durationSeconds ?? 0),
    );
    final uniqueTracks = filtered.map((r) => r.trackId).toSet().length;
    final uniqueArtists = filtered.map((r) => r.artistName).toSet().length;
    final uniqueAlbums =
        filtered
            .where((r) => r.albumId != null)
            .map((r) => r.albumTitle)
            .toSet()
            .length;

    // top tracks
    final Map<int, List<ListenRecord>> byTrack = {};
    for (final r in filtered) {
      byTrack.putIfAbsent(r.trackId, () => []).add(r);
    }
    final topTracks =
        byTrack.entries.map((e) {
            final recs = e.value;
            final first = recs.first;
            return TopItem(
              name: first.trackTitle,
              subtitle: first.artistName,
              coverUrl: first.coverUrl,
              count: recs.length,
              totalSeconds: recs.fold<int>(
                0,
                (s, x) => s + (x.durationSeconds ?? 0),
              ),
            );
          }).toList()
          ..sort((a, b) => b.count.compareTo(a.count));

    // top artists
    final Map<String, List<ListenRecord>> byArtist = {};
    for (final r in filtered) {
      byArtist.putIfAbsent(r.artistName, () => []).add(r);
    }
    final topArtists =
        byArtist.entries.map((e) {
            final recs = e.value;
            return TopItem(
              name: e.key,
              coverUrl:
                  recs
                      .firstWhere(
                        (x) => x.coverUrl != null,
                        orElse: () => recs.first,
                      )
                      .coverUrl,
              count: recs.length,
              totalSeconds: recs.fold<int>(
                0,
                (s, x) => s + (x.durationSeconds ?? 0),
              ),
            );
          }).toList()
          ..sort((a, b) => b.count.compareTo(a.count));

    // albums similar, simplified without extra album count data
    final Map<int?, List<ListenRecord>> byAlbum = {};
    for (final r in filtered) {
      byAlbum.putIfAbsent(r.albumId, () => []).add(r);
    }
    final albumItems =
        byAlbum.entries.where((e) => e.key != null).map((e) {
            final recs = e.value;
            final first = recs.first;
            final ut = recs.map((r) => r.trackId).toSet().length;
            return TopItem(
              name: first.albumTitle,
              subtitle: first.artistName,
              coverUrl: first.coverUrl,
              count:
                  ut, // use unique tracks as score proxy when no trackcount ratio
              totalSeconds: recs.fold<int>(
                0,
                (s, x) => s + (x.durationSeconds ?? 0),
              ),
              totalListens: recs.length,
            );
          }).toList()
          ..sort(
            (a, b) => (b.totalListens ?? 0).compareTo(a.totalListens ?? 0),
          );

    // monthly
    final monthMap = <int, List<ListenRecord>>{};
    for (final r in filtered) {
      monthMap.putIfAbsent(r.listenedAt.month, () => []).add(r);
    }
    final monthlyBreakdown = List.generate(12, (i) {
      final m = i + 1;
      final recs = monthMap[m] ?? [];
      final sec = recs.fold(0, (s, x) => s + (x.durationSeconds ?? 0));
      return MonthlyListens(month: m, count: recs.length, totalSeconds: sec);
    });

    // Per-device breakdown
    final deviceMap = <String, List<ListenRecord>>{};
    for (final r in filtered) {
      final key = r.sourceDevice ?? 'local';
      deviceMap.putIfAbsent(key, () => []).add(r);
    }
    final deviceStats =
        deviceMap.entries
            .map(
              (e) => DeviceStat(
                deviceId: e.key,
                listenCount: e.value.length,
                totalSeconds: e.value.fold(
                  0,
                  (s, x) => s + (x.durationSeconds ?? 0),
                ),
              ),
            )
            .toList()
          ..sort((a, b) => b.listenCount.compareTo(a.listenCount));

    return YearReviewStats(
      year: year,
      totalListens: totalListens,
      totalSeconds: totalSeconds,
      uniqueTracks: uniqueTracks,
      uniqueArtists: uniqueArtists,
      uniqueAlbums: uniqueAlbums,
      topTracks: topTracks.take(10).toList(),
      topArtists: topArtists.take(10).toList(),
      topAlbums: albumItems.take(10).toList(),
      monthlyBreakdown: monthlyBreakdown,
      topTrack: topTracks.isNotEmpty ? topTracks.first : null,
      topArtist: topArtists.isNotEmpty ? topArtists.first : null,
      topAlbum: albumItems.isNotEmpty ? albumItems.first : null,
      deviceStats: deviceStats,
    );
  }

  /// Fetch all listen records for a given calendar year.
  /// Used by backup export.
  static Future<List<ListenRecord>> getListensForYear(int year) async {
    final db = await CacheDatabase.instance.database;
    final startMs = DateTime(year).millisecondsSinceEpoch;
    final endMs = DateTime(year + 1).millisecondsSinceEpoch;
    final rows = await db.query(
      _tableName,
      where: 'listened_at >= ? AND listened_at < ?',
      whereArgs: [startMs, endMs],
      orderBy: 'listened_at ASC',
    );
    return rows.map(ListenRecord.fromMap).toList();
  }

  /// Return per-device listen stats for a given year, ordered by count desc.
  static Future<List<DeviceStat>> getDeviceStats(int year) async {
    await _loadDeviceDisplayNames();
    final db = await CacheDatabase.instance.database;
    final startMs = DateTime(year).millisecondsSinceEpoch;
    final endMs = DateTime(year + 1).millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      '''
      SELECT
        COALESCE(source_device, 'local') as device_id,
        COUNT(*) as listen_count,
        COALESCE(SUM(duration_seconds), 0) as total_seconds
      FROM $_tableName
      WHERE listened_at >= ? AND listened_at < ?
      GROUP BY device_id
      ORDER BY listen_count DESC
    ''',
      [startMs, endMs],
    );
    return rows
        .map(
          (r) => DeviceStat(
            deviceId: r['device_id'] as String,
            listenCount: (r['listen_count'] as num).toInt(),
            totalSeconds: (r['total_seconds'] as num).toInt(),
          ),
        )
        .toList();
  }

  /// Insert a ListenRecord by map (for restore from backup). Ignores id.
  static Future<void> insertRawListen(ListenRecord record) async {
    final db = await CacheDatabase.instance.database;
    final map = record.toMap();
    map.remove('id');
    // Restoring from a backup file is always a current-device operation:
    // the user picked a backup to merge into this device's local history.
    // Tag as 'local' so cache-clear preserves it and the year-review groups
    // it under "This Device".
    map['source_device'] = 'local';
    await db.insert(_tableName, map);
  }

  /// Bulk-insert external (remote device) listen records, skipping
  /// duplicates that already exist locally.  Dedup key is (track_id,
  /// listened_at) — two listens on the same track at the same second are
  /// treated as the same event.  [sourceDevice] tags every inserted row
  /// so the per-device breakdown can be shown in the year review.
  static Future<int> insertRemoteRecords(
    List<ListenRecord> records, {
    String sourceDevice = 'remote',
  }) async {
    if (records.isEmpty) return 0;
    final db = await CacheDatabase.instance.database;
    int inserted = 0;
    final batch = db.batch();
    for (final rec in records) {
      // Dedup: skip inserting a remote listen that already exists locally
      // (same track + timestamp).  We intentionally do NOT backfill
      // source_device on pre-existing NULL rows here — doing so would
      // mis-attribute this device's own local listens to whichever remote
      // device happens to share a track+timestamp.  Local NULL rows are
      // tagged 'local' at migration time (see ensureTable).
      batch.execute(
        'INSERT INTO $_tableName '
        '(track_id, track_title, artist_id, artist_name, album_id, album_title, cover_url, duration_seconds, listened_at, source_device) '
        'SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ? '
        'WHERE NOT EXISTS ('
        '  SELECT 1 FROM $_tableName WHERE track_id = ? AND listened_at = ?'
        ')',
        [
          rec.trackId,
          rec.trackTitle,
          rec.artistId,
          rec.artistName,
          rec.albumId,
          rec.albumTitle,
          rec.coverUrl,
          rec.durationSeconds,
          rec.listenedAt.millisecondsSinceEpoch,
          sourceDevice,
          rec.trackId,
          rec.listenedAt.millisecondsSinceEpoch,
        ],
      );
    }
    final results = await batch.commit(noResult: false);
    for (final r in results) {
      if (r is int) inserted += r;
    }
    return inserted;
  }
}
