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

  /// Release resources. Called when the provider is disposed.
  void dispose() {
    _stateController.close();
  }

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
    if (trackIds.isEmpty) return;
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Batch-check which IDs are already queued or downloading.
    final placeholders = trackIds.map((_) => '?').join(',');
    final existing = await db.rawQuery(
      "SELECT track_id FROM download_queue WHERE track_id IN ($placeholders)"
      " AND status IN ('queued', 'downloading')",
      trackIds,
    );
    final existingIds = existing.map((r) => r['track_id'] as int).toSet();

    await db.transaction((txn) async {
      for (final id in trackIds) {
        if (existingIds.contains(id)) continue;
        await txn.insert('download_queue', {
          'track_id': id,
          'status': 'queued',
          'added_at': now,
          'error': null,
        });
      }
    });
    await _emitState();
    // Telemetry: user or system enqueued downloads
    Analytics.track('download_enqueued', {'count': trackIds.length});
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
    // Omit numeric track_id per policy
    Analytics.track('download_removed');
  }

  /// Retry all failed items.
  Future<void> retryFailed(dynamic reader) async {
    final db = await _db.database;
    await db.update('download_queue', {
      'status': 'queued',
      'error': null,
    }, where: "status = 'failed'");
    await _emitState();
    Analytics.track('download_retry_requested');
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
              if (track.listenUrl == null) {
                // Track has no stream URL — cannot download. Mark as failed so
                // the user sees a clear status rather than a phantom "completed".
                await db.update(
                  'download_queue',
                  {'status': 'failed', 'error': 'no_stream_url'},
                  where: 'id = ?',
                  whereArgs: [item.id],
                );
                Analytics.track('download_failed', {
                  'had_error': true,
                  'error_type': 'no_stream_url',
                });
                await _emitState();
                continue;
              }
              // Omit numeric track_id per policy
              Analytics.track('download_started');
              await audioSvc.cacheAudio(
                track,
                api.getStreamUrl(track.listenUrl!),
                api.authHeaders,
              );

              // Mark completed and invalidate the cached provider so the UI
              // updates immediately.
              await db.update(
                'download_queue',
                {'status': 'completed'},
                where: 'id = ?',
                whereArgs: [item.id],
              );
              // Omit numeric track_id per policy
              Analytics.track('download_completed');
              try {
                ref
                    .read(cachedAudioTrackIdsProvider.notifier)
                    .add(item.trackId);
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
              // Use analytics wrapper to avoid sending raw error strings.
              // Keep only a lightweight indicator that an error occurred.
              // Numeric IDs may be acceptable here; if not, consider
              // removing or hashing them in the future.
              Analytics.track('download_failed', {
                'had_error': true,
                'error_type': e.runtimeType.toString(),
              });
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
  final svc = DownloadQueueService(CacheDatabase.instance);
  ref.onDispose(svc.dispose);
  return svc;
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
