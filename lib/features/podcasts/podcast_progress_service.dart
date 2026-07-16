import 'package:sqflite/sqflite.dart';
import 'package:tayra/core/cache/cache_database.dart';

// ── Episode progress model ────────────────────────────────────────────────

/// Local resume / played state for a single podcast episode.
class PodcastEpisodeProgress {
  final int trackId;
  final String? channelUuid;
  final int positionMs;
  final int? durationMs;
  final bool completed;
  final DateTime updatedAt;

  const PodcastEpisodeProgress({
    required this.trackId,
    this.channelUuid,
    required this.positionMs,
    this.durationMs,
    required this.completed,
    required this.updatedAt,
  });

  Duration get position => Duration(milliseconds: positionMs);

  /// True when the episode has a meaningful resume point (>5s, not completed).
  bool get hasResumePosition => !completed && positionMs > 5000;

  double get progressFraction {
    final total = durationMs;
    if (total == null || total <= 0) return 0;
    return (positionMs / total).clamp(0.0, 1.0);
  }

  factory PodcastEpisodeProgress.fromRow(Map<String, dynamic> row) {
    return PodcastEpisodeProgress(
      trackId: row['track_id'] as int,
      channelUuid: row['channel_uuid'] as String?,
      positionMs: row['position_ms'] as int? ?? 0,
      durationMs: row['duration_ms'] as int?,
      completed: (row['completed'] as int? ?? 0) == 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at'] as int? ?? 0,
      ),
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────

/// Persists podcast episode progress in the local cache database.
///
/// Separate from listen history (year-in-review): this is only for resume UX
/// and played/unplayed filters.
class PodcastProgressService {
  PodcastProgressService(this._db);

  final CacheDatabase _db;

  /// Fraction of duration at/above which an episode is auto-marked played.
  static const completedThreshold = 0.90;

  Future<PodcastEpisodeProgress?> getProgress(int trackId) async {
    final db = await _db.database;
    final rows = await db.query(
      'podcast_episode_progress',
      where: 'track_id = ?',
      whereArgs: [trackId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PodcastEpisodeProgress.fromRow(rows.first);
  }

  Future<Map<int, PodcastEpisodeProgress>> getProgressForChannel(
    String channelUuid,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      'podcast_episode_progress',
      where: 'channel_uuid = ?',
      whereArgs: [channelUuid],
    );
    return {
      for (final row in rows)
        row['track_id'] as int: PodcastEpisodeProgress.fromRow(row),
    };
  }

  Future<Map<int, PodcastEpisodeProgress>> getAllProgress() async {
    final db = await _db.database;
    final rows = await db.query('podcast_episode_progress');
    return {
      for (final row in rows)
        row['track_id'] as int: PodcastEpisodeProgress.fromRow(row),
    };
  }

  /// Upsert playback position. Auto-marks completed when past threshold.
  Future<void> upsertPosition({
    required int trackId,
    String? channelUuid,
    required int positionMs,
    int? durationMs,
  }) async {
    final completed =
        durationMs != null &&
        durationMs > 0 &&
        positionMs >= (durationMs * completedThreshold).round();

    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('podcast_episode_progress', {
      'track_id': trackId,
      'channel_uuid': channelUuid,
      'position_ms': positionMs,
      'duration_ms': durationMs,
      'completed': completed ? 1 : 0,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markPlayed({
    required int trackId,
    String? channelUuid,
    int? durationMs,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await getProgress(trackId);
    final dur = durationMs ?? existing?.durationMs;
    await db.insert('podcast_episode_progress', {
      'track_id': trackId,
      'channel_uuid': channelUuid ?? existing?.channelUuid,
      'position_ms': dur ?? existing?.positionMs ?? 0,
      'duration_ms': dur,
      'completed': 1,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markUnplayed(int trackId) async {
    final db = await _db.database;
    final existing = await getProgress(trackId);
    if (existing == null) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('podcast_episode_progress', {
      'track_id': trackId,
      'channel_uuid': existing.channelUuid,
      'position_ms': 0,
      'duration_ms': existing.durationMs,
      'completed': 0,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clear(int trackId) async {
    final db = await _db.database;
    await db.delete(
      'podcast_episode_progress',
      where: 'track_id = ?',
      whereArgs: [trackId],
    );
  }
}
