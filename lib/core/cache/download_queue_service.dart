import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/cache/cache_database.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/cached_api_repository.dart';

/// Per-item download states mirroring the SQLite `status` column.
enum DownloadStatus { queued, downloading, completed, failed }

/// A single entry in the persistent download queue.
class DownloadQueueItem {
  final int id; // SQLite row id
  final int trackId;
  final DownloadStatus status;
  final DateTime addedAt;
  final String? error;

  const DownloadQueueItem({
    required this.id,
    required this.trackId,
    required this.status,
    required this.addedAt,
    this.error,
  });

  static DownloadStatus _statusFrom(String s) {
    return switch (s) {
      'downloading' => DownloadStatus.downloading,
      'completed' => DownloadStatus.completed,
      'failed' => DownloadStatus.failed,
      _ => DownloadStatus.queued,
    };
  }

  factory DownloadQueueItem.fromRow(Map<String, dynamic> row) {
    return DownloadQueueItem(
      id: row['id'] as int,
      trackId: row['track_id'] as int,
      status: _statusFrom(row['status'] as String),
      addedAt: DateTime.fromMillisecondsSinceEpoch(row['added_at'] as int),
      error: row['error'] as String?,
    );
  }
}

// ── DownloadQueueService ────────────────────────────────────────────────────

/// Persistent, sequential background download queue.
///
/// - Queue state lives in the `download_queue` SQLite table so it survives
///   app restarts.
/// - On startup, any items that were `downloading` (killed mid-download) are
///   automatically reset to `queued` by the v3 DB migration and retried here.
/// - Exposes a [StreamController]-backed stream so the UI can observe state.
class DownloadQueueService {
  final CacheDatabase _db;
  bool _running = false;

  /// Stream of the current queue state (emitted after every state change).
  final _stateController =
      StreamController<List<DownloadQueueItem>>.broadcast();

  Stream<List<DownloadQueueItem>> get queueStream => _stateController.stream;

  DownloadQueueService(this._db);

  // ── Public API ───────────────────────────────────────────────────────────

  /// Load persisted queue and start processing.
  /// [reader] must be a [ProviderContainer] or [WidgetRef].
  Future<void> init(dynamic reader) async {
    // Reset any items stuck in 'downloading' state from a previous run.
    // (The DB migration also does this, but be defensive.)
    await _resetStuckItems();
    await _emitState();
    _processQueue(reader);
  }

  /// Add one or many track IDs to the queue.
  Future<void> enqueue(List<int> trackIds, dynamic reader) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final id in trackIds) {
      // Skip if this track is already queued or downloading (idempotent).
      final existing = await db.query(
        'download_queue',
        where: "track_id = ? AND status IN ('queued', 'downloading')",
        whereArgs: [id],
      );
      if (existing.isNotEmpty) continue;
      await db.insert('download_queue', {
        'track_id': id,
        'status': 'queued',
        'added_at': now,
        'error': null,
      });
    }
    await _emitState();
    // Telemetry: user or system enqueued downloads
    try {
      Analytics.track('download_enqueued', {'count': trackIds.length});
    } catch (_) {}
    _processQueue(reader);
  }

  /// Remove a track from the queue entirely (cancels if queued, no-op if
  /// already downloading or completed).
  Future<void> remove(int trackId) async {
    final db = await _db.database;
    await db.delete(
      'download_queue',
      where: "track_id = ? AND status = 'queued'",
      whereArgs: [trackId],
    );
    await _emitState();
    try {
      // Omit numeric track_id per policy
      Analytics.track('download_removed');
    } catch (_) {}
  }

  /// Retry all failed items.
  Future<void> retryFailed(dynamic reader) async {
    final db = await _db.database;
    await db.update('download_queue', {
      'status': 'queued',
      'error': null,
    }, where: "status = 'failed'");
    await _emitState();
    try {
      Analytics.track('download_retry_requested');
    } catch (_) {}
    _processQueue(reader);
  }

  /// Return the current queue snapshot.
  Future<List<DownloadQueueItem>> snapshot() async {
    final db = await _db.database;
    final rows = await db.query(
      'download_queue',
      where: "status != 'completed'",
      orderBy: 'added_at ASC',
    );
    return rows.map(DownloadQueueItem.fromRow).toList();
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<void> _resetStuckItems() async {
    final db = await _db.database;
    await db.update('download_queue', {
      'status': 'queued',
      'error': null,
    }, where: "status = 'downloading'");
  }

  Future<void> _emitState() async {
    if (_stateController.isClosed) return;
    try {
      final items = await snapshot();
      _stateController.add(items);
    } catch (_) {}
  }

  void _processQueue(dynamic ref) {
    if (_running) return;
    _running = true;
    unawaited(
      Future(() async {
        final api = ref.read(cachedFunkwhaleApiProvider);
        final audioSvc = ref.read(audioCacheServiceProvider);
        try {
          while (true) {
            final db = await _db.database;

            // Fetch next queued item
            final rows = await db.query(
              'download_queue',
              where: "status = 'queued'",
              orderBy: 'added_at ASC',
              limit: 1,
            );
            if (rows.isEmpty) break;

            final item = DownloadQueueItem.fromRow(rows.first);

            // Mark as downloading
            await db.update(
              'download_queue',
              {'status': 'downloading'},
              where: 'id = ?',
              whereArgs: [item.id],
            );
            await _emitState();

            try {
              final track = await api.getTrack(item.trackId);
              if (track.listenUrl != null) {
                try {
                  // Omit numeric track_id per policy
                  Analytics.track('download_started');
                } catch (_) {}
                await audioSvc.cacheAudio(
                  track,
                  api.getStreamUrl(track.listenUrl!),
                  api.authHeaders,
                );
              }

              // Mark completed and invalidate the cached provider so the UI
              // updates immediately.
              await db.update(
                'download_queue',
                {'status': 'completed'},
                where: 'id = ?',
                whereArgs: [item.id],
              );
              try {
                // Omit numeric track_id per policy
                Analytics.track('download_completed');
              } catch (_) {}
              try {
                ref.invalidate(isAudioCachedProvider(item.trackId));
              } catch (_) {}
            } catch (e, st) {
              debugPrint(
                'DownloadQueue: failed to download track ${item.trackId}: $e',
              );
              debugPrintStack(stackTrace: st);
              await db.update(
                'download_queue',
                {'status': 'failed', 'error': e.runtimeType.toString()},
                where: 'id = ?',
                whereArgs: [item.id],
              );
              try {
                // Use analytics wrapper to avoid sending raw error strings.
                // Keep only a lightweight indicator that an error occurred.
                // Numeric IDs may be acceptable here; if not, consider
                // removing or hashing them in the future.
                Analytics.track('download_failed', {
                  'had_error': true,
                  'error_type': e.runtimeType.toString(),
                });
              } catch (_) {}
            }
            await _emitState();
          }
        } finally {
          _running = false;
        }
      }),
    );
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

/// Riverpod provider for the download queue service (singleton)
final downloadQueueServiceProvider = Provider<DownloadQueueService>((ref) {
  return DownloadQueueService(CacheDatabase.instance);
});

// Alias kept for backwards-compat with existing call sites.
final downloadQueueProvider = downloadQueueServiceProvider;

/// Stream provider that exposes live queue state (active + failed items).
final downloadQueueStateProvider = StreamProvider<List<DownloadQueueItem>>((
  ref,
) {
  final svc = ref.watch(downloadQueueServiceProvider);
  return svc.queueStream;
});
