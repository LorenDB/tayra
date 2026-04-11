import 'package:flutter/foundation.dart';
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
    );
  }
}

// ── Year in review stats models ─────────────────────────────────────────

class TopItem {
  final String name;
  final String? subtitle;
  final String? coverUrl;
  final int count;
  final int? totalSeconds;

  const TopItem({
    required this.name,
    this.subtitle,
    this.coverUrl,
    required this.count,
    this.totalSeconds,
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

// ── Listen history service ──────────────────────────────────────────────

/// Service that manages local listen history storage and computes
/// year-in-review statistics. Data is stored in the app's SQLite database.
class ListenHistoryService {
  static const _tableName = 'listen_history';

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
        listened_at INTEGER NOT NULL
      )
    ''');
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
      final db = await CacheDatabase.instance.database;
      final record = ListenRecord.fromTrack(
        track,
        listenedSeconds: listenedSeconds,
      );
      await db.insert(_tableName, record.toMap());
    } catch (_) {
      // Non-critical — silently fail
    }
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
    return results.map((row) => row['year'] as int).toList();
  }

  /// Compute year-in-review statistics for the given year.
  static Future<YearReviewStats> getYearStats(int year) async {
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
      int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;
      int? _toNullableInt(dynamic v) => v == null ? null : (v as num).toInt();
      double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
      String? _toString(dynamic v) => v as String?;

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
      final totalListens = _toInt(totals['total_listens']);
      final totalSeconds = _toInt(totals['total_seconds']);
      final uniqueTracks = _toInt(totals['unique_tracks']);
      final uniqueArtists = _toInt(totals['unique_artists']);
      final uniqueAlbums = _toInt(totals['unique_albums']);

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
                  count: _toInt(row['play_count']),
                  totalSeconds: _toNullableInt(row['total_seconds']),
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
                  count: _toInt(row['play_count']),
                  totalSeconds: _toNullableInt(row['total_seconds']),
                ),
              )
              .toList();

      // Top albums (by engagement score: rewards both variety and repeats)
      // Formula: SUM(play_count + 1) for each unique track
      // - More unique tracks = more terms in the sum
      // - More plays per track = higher contribution
      final topAlbumsResult = await db.rawQuery(
        '''
      SELECT
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
      LIMIT 10
    ''',
        [startMs, endMs, startMs, endMs],
      );

      final topAlbums =
          topAlbumsResult
              .map(
                (row) => TopItem(
                  name: row['album_title'] as String,
                  subtitle: row['artist_name'] as String?,
                  coverUrl: row['cover_url'] as String?,
                  // engagement_score may be returned as int/double/null
                  count: _toDouble(row['engagement_score']).round(),
                  totalSeconds: _toNullableInt(row['total_seconds']),
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
        final month = _toInt(row['month']);
        monthMap[month] = MonthlyListens(
          month: month,
          count: _toInt(row['listen_count']),
          totalSeconds: _toInt(row['total_seconds']),
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

  /// Get the total listen count (all time).
  static Future<int> getTotalListenCount() async {
    final db = await CacheDatabase.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName',
    );
    return result.first['count'] as int;
  }

  /// Clear all listen history data.
  static Future<void> clearAll() async {
    final db = await CacheDatabase.instance.database;
    await db.delete(_tableName);
  }
}
