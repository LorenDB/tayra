import 'package:sqflite/sqflite.dart';
import 'package:tayra/core/cache/cache_database.dart';
import 'package:tayra/core/platform/app_platform.dart';

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

  PodcastEpisodeProgress copyWith({
    int? trackId,
    String? channelUuid,
    int? positionMs,
    int? durationMs,
    bool? completed,
    DateTime? updatedAt,
  }) {
    return PodcastEpisodeProgress(
      trackId: trackId ?? this.trackId,
      channelUuid: channelUuid ?? this.channelUuid,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      completed: completed ?? this.completed,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────

/// Persists podcast episode progress for resume UX and played filters.
///
/// Native: SQLite (`podcast_episode_progress`) plus an in-memory overlay.
/// Web: in-memory only (server is source of truth; hydrated by client-data
/// pull / single-track GET). Always update memory so web resume works.
class PodcastProgressService {
  PodcastProgressService(this._db) : _memoryOnly = false;

  /// Memory-only instance (web SoT / unit tests; no SQLite).
  PodcastProgressService.memoryOnly() : _db = null, _memoryOnly = true;

  final CacheDatabase? _db;
  final bool _memoryOnly;

  /// In-memory store (web SoT cache + native write-through overlay).
  final Map<int, PodcastEpisodeProgress> _memory = {};

  /// Fraction of duration at/above which an episode is auto-marked played.
  static const completedThreshold = 0.90;

  bool get _useSqlite =>
      !_memoryOnly && _db != null && AppPlatform.supportsOfflineCache;

  /// Snapshot of all known progress (memory; may be incomplete until hydrated).
  Map<int, PodcastEpisodeProgress> get memorySnapshot =>
      Map.unmodifiable(_memory);

  Future<PodcastEpisodeProgress?> getProgress(int trackId) async {
    final mem = _memory[trackId];
    if (mem != null) return mem;
    if (!_useSqlite) return null;

    final db = await _db!.database;
    final rows = await db.query(
      'podcast_episode_progress',
      where: 'track_id = ?',
      whereArgs: [trackId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final progress = PodcastEpisodeProgress.fromRow(rows.first);
    _memory[trackId] = progress;
    return progress;
  }

  Future<Map<int, PodcastEpisodeProgress>> getProgressForChannel(
    String channelUuid,
  ) async {
    if (!_useSqlite) {
      return {
        for (final e in _memory.entries)
          if (e.value.channelUuid == channelUuid) e.key: e.value,
      };
    }

    final db = await _db!.database;
    final rows = await db.query(
      'podcast_episode_progress',
      where: 'channel_uuid = ?',
      whereArgs: [channelUuid],
    );
    final out = <int, PodcastEpisodeProgress>{};
    for (final row in rows) {
      final p = PodcastEpisodeProgress.fromRow(row);
      _memory[p.trackId] = p;
      out[p.trackId] = p;
    }
    // Merge memory rows for this channel that may not be in SQLite yet (web
    // hybrid / race). Memory wins only if already present above.
    for (final e in _memory.entries) {
      if (e.value.channelUuid == channelUuid) {
        out.putIfAbsent(e.key, () => e.value);
      }
    }
    return out;
  }

  Future<Map<int, PodcastEpisodeProgress>> getAllProgress() async {
    if (!_useSqlite) {
      return Map<int, PodcastEpisodeProgress>.from(_memory);
    }

    final db = await _db!.database;
    final rows = await db.query('podcast_episode_progress');
    final out = <int, PodcastEpisodeProgress>{};
    for (final row in rows) {
      final p = PodcastEpisodeProgress.fromRow(row);
      _memory[p.trackId] = p;
      out[p.trackId] = p;
    }
    // Include pure-memory rows not yet in SQLite.
    for (final e in _memory.entries) {
      out.putIfAbsent(e.key, () => e.value);
    }
    return out;
  }

  /// Upsert playback position. Auto-marks completed when past threshold.
  ///
  /// When [channelUuid] is omitted, preserves any existing channel binding.
  Future<void> upsertPosition({
    required int trackId,
    String? channelUuid,
    required int positionMs,
    int? durationMs,
  }) async {
    final existing = await getProgress(trackId);
    final completed =
        durationMs != null &&
        durationMs > 0 &&
        positionMs >= (durationMs * completedThreshold).round();
    final now = DateTime.now();
    final progress = PodcastEpisodeProgress(
      trackId: trackId,
      channelUuid: channelUuid ?? existing?.channelUuid,
      positionMs: positionMs,
      durationMs: durationMs ?? existing?.durationMs,
      completed: completed,
      updatedAt: now,
    );
    await _write(progress);
  }

  Future<void> markPlayed({
    required int trackId,
    String? channelUuid,
    int? durationMs,
  }) async {
    final existing = await getProgress(trackId);
    final dur = durationMs ?? existing?.durationMs;
    final progress = PodcastEpisodeProgress(
      trackId: trackId,
      channelUuid: channelUuid ?? existing?.channelUuid,
      positionMs: dur ?? existing?.positionMs ?? 0,
      durationMs: dur,
      completed: true,
      updatedAt: DateTime.now(),
    );
    await _write(progress);
  }

  Future<void> markUnplayed(int trackId) async {
    final existing = await getProgress(trackId);
    if (existing == null) {
      return;
    }
    final progress = PodcastEpisodeProgress(
      trackId: trackId,
      channelUuid: existing.channelUuid,
      positionMs: 0,
      durationMs: existing.durationMs,
      completed: false,
      updatedAt: DateTime.now(),
    );
    await _write(progress);
  }

  Future<void> clear(int trackId) async {
    _memory.remove(trackId);
    if (!_useSqlite) return;
    final db = await _db!.database;
    await db.delete(
      'podcast_episode_progress',
      where: 'track_id = ?',
      whereArgs: [trackId],
    );
  }

  /// Apply a remote progress row using last-write-wins on [updatedAt].
  ///
  /// Returns true when the local row was inserted or updated.
  Future<bool> applyRemoteLww({
    required int trackId,
    String? channelUuid,
    required int positionMs,
    int? durationMs,
    required bool completed,
    required DateTime updatedAt,
  }) async {
    final existing = await getProgress(trackId);
    if (existing != null && !existing.updatedAt.isBefore(updatedAt)) {
      // Local is equal or newer — keep it.
      return false;
    }
    final progress = PodcastEpisodeProgress(
      trackId: trackId,
      channelUuid: channelUuid ?? existing?.channelUuid,
      positionMs: positionMs,
      durationMs: durationMs ?? existing?.durationMs,
      completed: completed,
      updatedAt: updatedAt,
    );
    await _write(progress);
    return true;
  }

  /// Seed / replace memory from a progress map (e.g. channel fetch on web).
  void putAllInMemory(Iterable<PodcastEpisodeProgress> rows) {
    for (final row in rows) {
      final existing = _memory[row.trackId];
      if (existing != null && !existing.updatedAt.isBefore(row.updatedAt)) {
        continue;
      }
      _memory[row.trackId] = row;
    }
  }

  Future<void> _write(PodcastEpisodeProgress progress) async {
    _memory[progress.trackId] = progress;
    if (!_useSqlite) return;
    final db = await _db!.database;
    await db.insert('podcast_episode_progress', {
      'track_id': progress.trackId,
      'channel_uuid': progress.channelUuid,
      'position_ms': progress.positionMs,
      'duration_ms': progress.durationMs,
      'completed': progress.completed ? 1 : 0,
      'updated_at': progress.updatedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Wire format for `POST /api/v1/playback-progress/bulk/` items.
  List<Map<String, dynamic>> toBulkItems(
    Iterable<PodcastEpisodeProgress> rows, {
    String? sourceDevice,
  }) {
    return [
      for (final row in rows)
        {
          'track': row.trackId,
          'position_ms': row.positionMs,
          if (row.durationMs != null) 'duration_ms': row.durationMs,
          'completed': row.completed,
          if (row.channelUuid != null && row.channelUuid!.isNotEmpty)
            'channel_uuid': row.channelUuid,
          if (sourceDevice != null) 'source_device': sourceDevice,
          'updated_at': row.updatedAt.toUtc().toIso8601String(),
        },
    ];
  }

  /// Split [items] into chunks of at most [chunkSize] (server bulk max 500).
  static List<List<T>> chunkItems<T>(List<T> items, int chunkSize) {
    if (chunkSize <= 0) {
      throw ArgumentError.value(chunkSize, 'chunkSize', 'must be > 0');
    }
    if (items.isEmpty) return const [];
    final out = <List<T>>[];
    for (var i = 0; i < items.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, items.length);
      out.add(items.sublist(i, end));
    }
    return out;
  }
}
