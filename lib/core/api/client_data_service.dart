import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/api/client_preferences.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/core/device/device_identity.dart';
import 'package:tayra/features/podcasts/podcast_progress_provider.dart';
import 'package:tayra/features/podcasts/podcast_progress_service.dart';

// ── Constants ───────────────────────────────────────────────────────────

/// OAuth / server client_id for this app (not the OAuth app client id).
const kTayraClientId = 'tayra';

/// Minimum gap between non-forced duration PATCHes (spec: ≥10–15s).
const kServerListenPatchInterval = Duration(seconds: 15);

/// Minimum gap between non-forced single-track progress PUTs.
const kServerProgressPutInterval = Duration(seconds: 15);

/// Bulk batch size for playback-progress migration (server max 500).
const kPlaybackProgressBulkChunk = 500;

/// SharedPreferences key for per-pref local change timestamps (ms).
const _prefLocalUpdatedMetaKey = 'tayra_pref_local_updated_ms';

// ── Provider ────────────────────────────────────────────────────────────

final clientDataServiceProvider = Provider<ClientDataService>((ref) {
  return ClientDataService(ref);
});

/// Side-effect bootstrap: register/upsert ClientDevice when authenticated.
///
/// Watch this from app startup so login and cold-start both trigger
/// registration without coupling AuthNotifier to the API layer.
/// Wire [ClientDataService.onPreferencesApplied] from main (settings reload)
/// to avoid a circular import with settings_provider.
final clientDataBootstrapProvider = Provider<void>((ref) {
  ref.listen<AuthState>(authStateProvider, (previous, next) {
    if (next.isAuthenticated) {
      unawaited(ref.read(clientDataServiceProvider).ensureReady());
    } else if (previous?.isAuthenticated == true) {
      ref.read(clientDataServiceProvider).reset();
    }
  });
  final auth = ref.read(authStateProvider);
  if (auth.isAuthenticated) {
    unawaited(ref.read(clientDataServiceProvider).ensureReady());
  }
});

// ── Testable backend ────────────────────────────────────────────────────

/// Network + device hooks for [ClientDataService] (live or fake in tests).
class ClientDataBackend {
  const ClientDataBackend({
    required this.probeClientDataSupport,
    required this.upsertClientDevice,
    required this.createRichListening,
    required this.patchListeningBySession,
    required this.recordListening,
    required this.getDeviceUuid,
    required this.getDeviceName,
    required this.getAppVersion,
    this.putPlaybackProgress,
    this.bulkUpsertPlaybackProgress,
    this.getPlaybackProgressPage,
    this.getPlaybackProgressForTrack,
    this.getClientPreferences,
    this.putClientPreferences,
    this.isAuthenticated = true,
  });

  final Future<bool> Function() probeClientDataSupport;
  final Future<void> Function({
    required String uuid,
    required String name,
    String clientId,
    String? clientVersion,
  })
  upsertClientDevice;
  final Future<Map<String, dynamic>> Function({
    required int trackId,
    int? durationSeconds,
    String? sourceDevice,
    String? clientSessionId,
  })
  createRichListening;
  final Future<void> Function(
    String clientSessionId, {
    int? durationSeconds,
    String? sourceDevice,
  })
  patchListeningBySession;
  final Future<void> Function(int trackId) recordListening;
  final Future<String> Function() getDeviceUuid;
  final Future<String> Function() getDeviceName;
  final Future<String> Function() getAppVersion;

  final Future<Map<String, dynamic>> Function({
    required int trackId,
    required int positionMs,
    int? durationMs,
    bool? completed,
    String? channelUuid,
    String? sourceDevice,
    DateTime? updatedAt,
  })?
  putPlaybackProgress;

  final Future<Map<String, dynamic>> Function(List<Map<String, dynamic>> items)?
  bulkUpsertPlaybackProgress;

  final Future<({List<Map<String, dynamic>> results, String? next})> Function({
    required int page,
    required int pageSize,
  })?
  getPlaybackProgressPage;

  final Future<Map<String, dynamic>?> Function(int trackId)?
  getPlaybackProgressForTrack;

  final Future<List<Map<String, dynamic>>> Function({
    required String clientId,
    String? deviceUuid,
  })?
  getClientPreferences;

  final Future<Map<String, dynamic>> Function({
    required String clientId,
    required Map<String, dynamic> preferences,
    String? deviceUuid,
    String mode,
  })?
  putClientPreferences;

  final bool isAuthenticated;
}
// ── Service ─────────────────────────────────────────────────────────────

/// Feature detection, device registration, rich listening dual-write,
/// podcast progress sync, and allowlisted client-preferences sync.
///
/// Online path when supported:
/// 1. Upsert [ClientDevice] for this install UUID
/// 2. One rich POST per play session (no `creation_date` → server now)
/// 3. PATCH by-session every ≥15s / pause / end
/// 4. [endSession] on local listen finalize so the next play gets a new row
/// 5. Bulk push + pull podcast progress (LWW by `updated_at`)
/// 6. Merge allowlisted prefs (never secrets / API keys)
///
/// When unsupported (GET client-devices → 404): thin [recordListening] only.
/// Offline / network errors: swallow; SQLite remains the offline store.
class ClientDataService {
  ClientDataService(
    this._ref, {
    ClientDataBackend? backend,
    PodcastProgressService? progressService,
  }) : _backendOverride = backend,
       _progressOverride = progressService;

  final Ref? _ref;
  final ClientDataBackend? _backendOverride;
  final PodcastProgressService? _progressOverride;

  bool? _richSupported;
  bool _deviceRegistered = false;
  Future<void>? _readyFuture;
  Future<void>? _syncFuture;

  String? _activeSessionId;
  int? _activeTrackId;
  int _lastKnownSeconds = 0;
  int _lastPatchedSeconds = 0;
  DateTime? _lastPatchAt;

  // Runtime single-track progress PUT throttle
  int? _lastProgressTrackId;
  int _lastProgressPositionMs = -1;
  DateTime? _lastProgressPutAt;

  /// Serializes start/end/sync so concurrent player call sites cannot
  /// double-POST or clear a session mid-create.
  Future<void> _tail = Future.value();

  /// Test-only construction without Riverpod.
  @visibleForTesting
  ClientDataService.forTest(
    ClientDataBackend backend, {
    PodcastProgressService? progressService,
  }) : _ref = null,
       _backendOverride = backend,
       _progressOverride = progressService;

  PodcastProgressService get _progress {
    final override = _progressOverride;
    if (override != null) return override;
    // Shared Riverpod instance so web in-memory cache is visible to UI.
    final ref = _ref;
    if (ref != null) {
      return ref.read(podcastProgressServiceProvider);
    }
    // Fallback for tests without a progress override.
    return PodcastProgressService.memoryOnly();
  }

  ClientDataBackend get _backend {
    final override = _backendOverride;
    if (override != null) return override;
    final ref = _ref!;
    final cached = ref.read(cachedFunkwhaleApiProvider);
    final raw = ref.read(funkwhaleApiProvider);
    return ClientDataBackend(
      probeClientDataSupport: raw.probeClientDataSupport,
      upsertClientDevice: ({
        required String uuid,
        required String name,
        String clientId = kTayraClientId,
        String? clientVersion,
      }) async {
        await raw.upsertClientDevice(
          uuid: uuid,
          name: name,
          clientId: clientId,
          clientVersion: clientVersion,
        );
      },
      createRichListening: cached.createRichListening,
      patchListeningBySession: cached.patchListeningBySession,
      recordListening: cached.recordListening,
      getDeviceUuid: getDeviceUuid,
      getDeviceName: getDeviceDisplayName,
      getAppVersion: () async {
        final info = await PackageInfo.fromPlatform();
        return info.version;
      },
      putPlaybackProgress: cached.putPlaybackProgress,
      bulkUpsertPlaybackProgress: cached.bulkUpsertPlaybackProgress,
      getPlaybackProgressPage: ({
        required int page,
        required int pageSize,
      }) async {
        final pageData = await cached.getPlaybackProgress(
          page: page,
          pageSize: pageSize,
        );
        return (results: pageData.results, next: pageData.next);
      },
      getPlaybackProgressForTrack: cached.getPlaybackProgressForTrack,
      getClientPreferences: cached.getClientPreferences,
      putClientPreferences: cached.putClientPreferences,
      isAuthenticated: ref.read(authStateProvider).isAuthenticated,
    );
  }

  bool get isRichActive =>
      _richSupported == true && _deviceRegistered && _activeSessionId != null;

  /// True when client-data API is available and this device is registered.
  bool get isClientDataReady => _richSupported == true && _deviceRegistered;

  @visibleForTesting
  String? get debugActiveSessionId => _activeSessionId;

  @visibleForTesting
  int? get debugActiveTrackId => _activeTrackId;

  @visibleForTesting
  bool? get debugRichSupported => _richSupported;

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _tail.then((_) => operation());
    _tail = next.catchError((_) {});
    return next;
  }

  /// Probe support + register this device. Safe to call repeatedly.
  ///
  /// When client-data is available, also kicks off a background progress +
  /// preferences sync (does not block readiness).
  Future<void> ensureReady() async {
    if (!_backend.isAuthenticated) return;

    _readyFuture ??= _doEnsureReady();
    try {
      await _readyFuture;
    } catch (e, st) {
      debugPrint('ClientDataService.ensureReady failed: $e\n$st');
      // Allow retry after network / probe failure.
      _readyFuture = null;
    }
  }

  Future<void> _doEnsureReady() async {
    final supported = await _backend.probeClientDataSupport();
    _richSupported = supported;
    if (!supported) return;
    await _registerDevice();
    // Progress + prefs sync after device is registered (non-blocking).
    unawaited(syncProgressAndPreferences());
  }

  Future<void> _registerDevice() async {
    final uuid = await _backend.getDeviceUuid();
    final name = await _backend.getDeviceName();
    String? version;
    try {
      version = await _backend.getAppVersion();
    } catch (_) {}
    await _backend.upsertClientDevice(
      uuid: uuid,
      name: name,
      clientId: kTayraClientId,
      clientVersion: version,
    );
    _deviceRegistered = true;
  }

  /// Start a server-side listen for [track].
  ///
  /// Rich path: one POST with device + new session UUID (no creation_date).
  /// Thin fallback: stock track-only scrobble.
  /// Concurrent callers are serialized; same still-open session is a no-op.
  Future<void> recordTrackStarted(Track track) {
    return _serialize(() => _recordTrackStartedImpl(track));
  }

  Future<void> _recordTrackStartedImpl(Track track) async {
    await ensureReady();

    // Same track already has an active rich session — do not double-POST.
    if (_activeTrackId == track.id && _activeSessionId != null) {
      return;
    }

    // Best-effort final patch for previous session before switching.
    if (_activeSessionId != null &&
        _activeTrackId != null &&
        _activeTrackId != track.id) {
      await _patchActive(force: true);
      _clearActiveSession();
    }

    // Synchronous claim before first network await so a concurrent same-
    // track start that already entered the serialize queue still no-ops
    // after we assign the session id below.
    _activeTrackId = track.id;
    _lastKnownSeconds = 0;
    _lastPatchedSeconds = 0;
    _lastPatchAt = null;

    if (_richSupported == true && _deviceRegistered) {
      final sessionId = generateUuidV4();
      _activeSessionId = sessionId;
      try {
        final deviceUuid = await _backend.getDeviceUuid();
        await _backend.createRichListening(
          trackId: track.id,
          sourceDevice: deviceUuid,
          clientSessionId: sessionId,
        );
        return;
      } catch (e) {
        debugPrint('ClientDataService rich create failed: $e');
        // Device may have been soft-deleted server-side — re-register once.
        try {
          await _registerDevice();
          await _backend.createRichListening(
            trackId: track.id,
            sourceDevice: await _backend.getDeviceUuid(),
            clientSessionId: sessionId,
          );
          return;
        } catch (e2) {
          debugPrint('ClientDataService rich create retry failed: $e2');
          _activeSessionId = null;
        }
      }
    }

    // Thin stock path (unsupported server or rich create failed).
    _activeSessionId = null;
    try {
      await _backend.recordListening(track.id);
    } catch (_) {}
  }

  /// Push duration to the server for the active rich session.
  ///
  /// Non-forced updates are throttled to [kServerListenPatchInterval].
  /// Forced updates (pause / end / track change) always send when duration
  /// advanced past the last patched value.
  Future<void> syncDuration(
    int trackId,
    int durationSeconds, {
    bool force = false,
  }) {
    return _serialize(
      () => _syncDurationImpl(trackId, durationSeconds, force: force),
    );
  }

  Future<void> _syncDurationImpl(
    int trackId,
    int durationSeconds, {
    required bool force,
  }) async {
    if (_activeSessionId == null || _activeTrackId != trackId) return;
    if (durationSeconds <= 0) return;

    _lastKnownSeconds = durationSeconds;
    if (durationSeconds <= _lastPatchedSeconds) return;

    if (!force) {
      final last = _lastPatchAt;
      if (last != null &&
          DateTime.now().difference(last) < kServerListenPatchInterval) {
        return;
      }
    }

    await _patchActive(force: force);
  }

  /// Force-PATCH (optional) then clear the active rich session.
  ///
  /// Call when the local listen finalizes so replaying the same track
  /// opens a new server row instead of PATCHing the previous session.
  Future<void> endSession({bool forcePatch = true}) {
    return _serialize(() => _endSessionImpl(forcePatch: forcePatch));
  }

  Future<void> _endSessionImpl({required bool forcePatch}) async {
    if (_activeSessionId == null) {
      _clearActiveSession();
      return;
    }
    if (forcePatch) {
      await _patchActive(force: true);
    }
    _clearActiveSession();
  }

  void _clearActiveSession() {
    _activeSessionId = null;
    _activeTrackId = null;
    _lastKnownSeconds = 0;
    _lastPatchedSeconds = 0;
    _lastPatchAt = null;
  }

  Future<void> _patchActive({required bool force}) async {
    final sessionId = _activeSessionId;
    final trackId = _activeTrackId;
    if (sessionId == null || trackId == null) return;
    final seconds = _lastKnownSeconds;
    if (seconds <= 0) return;
    if (seconds <= _lastPatchedSeconds && !force) return;
    if (seconds == _lastPatchedSeconds) return;

    try {
      await _backend.patchListeningBySession(
        sessionId,
        durationSeconds: seconds,
      );
      _lastPatchedSeconds = seconds;
      _lastPatchAt = DateTime.now();
    } on DioException catch (e) {
      debugPrint('ClientDataService patch failed: $e');
      // Row lost (e.g. server restart / purge): re-POST same session for merge.
      if (e.response?.statusCode == 404) {
        await _recoverSessionByRecreate(trackId, sessionId, seconds);
      }
    } catch (e) {
      debugPrint('ClientDataService patch failed: $e');
    }
  }

  Future<void> _recoverSessionByRecreate(
    int trackId,
    String sessionId,
    int seconds,
  ) async {
    try {
      final deviceUuid = await _backend.getDeviceUuid();
      await _backend.createRichListening(
        trackId: trackId,
        durationSeconds: seconds,
        sourceDevice: deviceUuid,
        clientSessionId: sessionId,
      );
      _lastPatchedSeconds = seconds;
      _lastPatchAt = DateTime.now();
    } catch (e) {
      debugPrint('ClientDataService session recreate failed: $e');
    }
  }

  /// Clear cached capability / session state (logout).
  void reset() {
    _richSupported = null;
    _deviceRegistered = false;
    _readyFuture = null;
    _syncFuture = null;
    _lastProgressTrackId = null;
    _lastProgressPositionMs = -1;
    _lastProgressPutAt = null;
    _clearActiveSession();
  }

  // ── Progress + preferences sync ─────────────────────────────────────

  /// Full migration/sync: push local progress, pull remote LWW, merge prefs.
  ///
  /// Safe to call repeatedly; concurrent calls coalesce on one future.
  Future<void> syncProgressAndPreferences() async {
    if (!_backend.isAuthenticated) return;
    await ensureReady();
    if (!isClientDataReady) return;

    _syncFuture ??= _doSyncProgressAndPreferences();
    try {
      await _syncFuture;
    } catch (e, st) {
      debugPrint(
        'ClientDataService.syncProgressAndPreferences failed: $e\n$st',
      );
    } finally {
      _syncFuture = null;
    }
  }

  Future<void> _doSyncProgressAndPreferences() async {
    await syncPodcastProgress();
    final prefsApplied = await syncAllowlistedPreferences();
    if (prefsApplied) {
      // Notify listeners via optional hook so settings UI reloads without a
      // circular import on settings_provider.
      final onApplied = onPreferencesApplied;
      if (onApplied != null) {
        try {
          await onApplied();
        } catch (e) {
          debugPrint('ClientDataService onPreferencesApplied failed: $e');
        }
      }
    }
  }

  /// Optional hook invoked after remote prefs were written to SharedPreferences.
  Future<void> Function()? onPreferencesApplied;

  /// Push local podcast progress (bulk LWW) then pull remote into local store
  /// (SQLite on native, in-memory on web).
  Future<void> syncPodcastProgress() async {
    if (!isClientDataReady) return;
    // Push whatever we already know (native SQLite + memory, or web memory).
    await _pushLocalProgressBulk();
    await _pullRemoteProgress();
  }

  Future<void> _pushLocalProgressBulk() async {
    final bulk = _backend.bulkUpsertPlaybackProgress;
    if (bulk == null) return;

    final local = _progress;
    final all = await local.getAllProgress();
    if (all.isEmpty) return;

    final deviceUuid = await _backend.getDeviceUuid();
    final items = local.toBulkItems(all.values, sourceDevice: deviceUuid);
    final chunks = PodcastProgressService.chunkItems(
      items,
      kPlaybackProgressBulkChunk,
    );
    for (final chunk in chunks) {
      try {
        await bulk(chunk);
      } catch (e) {
        debugPrint('ClientDataService progress bulk chunk failed: $e');
      }
    }
  }

  Future<void> _pullRemoteProgress() async {
    final pageFn = _backend.getPlaybackProgressPage;
    if (pageFn == null) return;

    // Always apply into PodcastProgressService (memory on web, SQLite+memory
    // on native) so resume UX has a server-hydrated source of truth.
    final local = _progress;

    var page = 1;
    const pageSize = 100;
    var pages = 0;
    const maxPages = 100; // hard cap: 10k rows

    while (pages < maxPages) {
      pages++;
      final ({List<Map<String, dynamic>> results, String? next}) pageData;
      try {
        pageData = await pageFn(page: page, pageSize: pageSize);
      } catch (e) {
        debugPrint('ClientDataService progress pull failed: $e');
        return;
      }
      if (pageData.results.isEmpty) break;

      for (final row in pageData.results) {
        await _applyRemoteProgressRow(local, row);
      }

      if (pageData.next == null || pageData.next!.isEmpty) break;
      page++;
    }
  }

  Future<void> _applyRemoteProgressRow(
    PodcastProgressService local,
    Map<String, dynamic> row,
  ) async {
    final trackId = (row['track'] as num?)?.toInt();
    if (trackId == null) return;
    final positionMs = (row['position_ms'] as num?)?.toInt() ?? 0;
    final durationMs = (row['duration_ms'] as num?)?.toInt();
    final completed = row['completed'] as bool? ?? false;
    final channelUuid = row['channel_uuid']?.toString();
    final updatedAt =
        _parseDateTime(row['updated_at']) ?? DateTime.now().toUtc();
    try {
      await local.applyRemoteLww(
        trackId: trackId,
        channelUuid: channelUuid,
        positionMs: positionMs,
        durationMs: durationMs,
        completed: completed,
        updatedAt: updatedAt,
      );
    } catch (e) {
      debugPrint('ClientDataService apply remote progress failed: $e');
    }
  }

  /// Single-track progress PUT (throttled unless [force]).
  ///
  /// Call after local [PodcastProgressService.upsertPosition] / markPlayed.
  Future<void> pushPlaybackProgress({
    required int trackId,
    required int positionMs,
    int? durationMs,
    bool? completed,
    String? channelUuid,
    DateTime? updatedAt,
    bool force = false,
  }) async {
    if (!_backend.isAuthenticated) return;
    await ensureReady();
    if (!isClientDataReady) return;
    final put = _backend.putPlaybackProgress;
    if (put == null) return;

    if (!force) {
      final lastAt = _lastProgressPutAt;
      if (_lastProgressTrackId == trackId &&
          positionMs == _lastProgressPositionMs) {
        return;
      }
      if (lastAt != null &&
          _lastProgressTrackId == trackId &&
          DateTime.now().difference(lastAt) < kServerProgressPutInterval) {
        return;
      }
    }

    try {
      final deviceUuid = await _backend.getDeviceUuid();
      await put(
        trackId: trackId,
        positionMs: positionMs,
        durationMs: durationMs,
        completed: completed,
        channelUuid: channelUuid,
        sourceDevice: deviceUuid,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      );
      _lastProgressTrackId = trackId;
      _lastProgressPositionMs = positionMs;
      _lastProgressPutAt = DateTime.now();
    } on DioException catch (e) {
      // 409 = server has newer row — apply server body into local/memory store.
      if (e.response?.statusCode == 409) {
        final body = e.response?.data;
        if (body is Map && body['progress'] is Map) {
          final progress = Map<String, dynamic>.from(body['progress'] as Map);
          await _applyRemoteProgressRow(_progress, progress);
        }
        return;
      }
      debugPrint('ClientDataService pushPlaybackProgress failed: $e');
    } catch (e) {
      debugPrint('ClientDataService pushPlaybackProgress failed: $e');
    }
  }

  /// Local mark played + server dual-write (force). Used by podcast UI.
  Future<void> markEpisodePlayed({
    required int trackId,
    String? channelUuid,
    int? durationMs,
  }) async {
    await _progress.markPlayed(
      trackId: trackId,
      channelUuid: channelUuid,
      durationMs: durationMs,
    );
    final after = await _progress.getProgress(trackId);
    await pushPlaybackProgress(
      trackId: trackId,
      positionMs: after?.positionMs ?? durationMs ?? 0,
      durationMs: after?.durationMs ?? durationMs,
      completed: true,
      channelUuid: channelUuid ?? after?.channelUuid,
      updatedAt: after?.updatedAt,
      force: true,
    );
  }

  /// Local mark unplayed + server dual-write (force).
  Future<void> markEpisodeUnplayed(int trackId) async {
    final before = await _progress.getProgress(trackId);
    await _progress.markUnplayed(trackId);
    final after = await _progress.getProgress(trackId);
    if (after == null && before == null) return;
    await pushPlaybackProgress(
      trackId: trackId,
      positionMs: 0,
      durationMs: after?.durationMs ?? before?.durationMs,
      completed: false,
      channelUuid: after?.channelUuid ?? before?.channelUuid,
      updatedAt: after?.updatedAt,
      force: true,
    );
  }

  /// Fetch single-track progress from the API into the local/memory store.
  ///
  /// Used on web (and as a fallback) when opening a podcast episode before
  /// play so resume position is available without SQLite.
  Future<PodcastEpisodeProgress?> fetchAndCacheProgressForTrack(
    int trackId,
  ) async {
    if (!_backend.isAuthenticated) return _progress.getProgress(trackId);
    await ensureReady();
    if (!isClientDataReady) return _progress.getProgress(trackId);

    final getOne = _backend.getPlaybackProgressForTrack;
    if (getOne != null) {
      try {
        final row = await getOne(trackId);
        if (row != null) {
          await _applyRemoteProgressRow(_progress, row);
        }
      } catch (e) {
        debugPrint('ClientDataService fetch progress for track failed: $e');
      }
    }
    return _progress.getProgress(trackId);
  }

  /// Sync allowlisted account-level preferences (LWW by local meta vs remote
  /// `updated_at`). Never uploads secrets / API keys.
  ///
  /// Returns true when any remote value was applied to SharedPreferences
  /// (caller should reload [SettingsNotifier] state).
  Future<bool> syncAllowlistedPreferences() async {
    if (!isClientDataReady) return false;
    final getPrefs = _backend.getClientPreferences;
    final putPrefs = _backend.putClientPreferences;
    if (getPrefs == null || putPrefs == null) return false;

    List<Map<String, dynamic>> remoteRows;
    try {
      remoteRows = await getPrefs(clientId: kTayraClientId);
    } catch (e) {
      debugPrint('ClientDataService getClientPreferences failed: $e');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final localMeta = _readPrefLocalMeta(prefs);
    // First-ever prefs sync on this install: treat current local values as
    // "just written" so we don't clobber them with older remote rows, and so
    // we push them when the server is empty.
    if (localMeta.isEmpty) {
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      for (final key in _snapshotLocalAllowlisted(prefs).keys) {
        localMeta[key] = nowMs;
      }
      if (localMeta.isNotEmpty) {
        await _writePrefLocalMeta(prefs, localMeta);
      }
    }

    final toApply = <String, dynamic>{};
    final remoteUpdated = <String, DateTime>{};

    for (final row in remoteRows) {
      final key = row['key']?.toString();
      if (key == null || !isAllowlistedPreferenceKey(key)) continue;
      final localKey = canonicalLocalPreferenceKey(key);
      final remoteAt = _parseDateTime(row['updated_at']);
      if (remoteAt != null) remoteUpdated[localKey] = remoteAt;
      final localAtMs = localMeta[localKey];
      final localAt =
          localAtMs != null
              ? DateTime.fromMillisecondsSinceEpoch(localAtMs, isUtc: true)
              : null;
      // Remote wins when strictly newer than our last local change.
      if (localAt == null || (remoteAt != null && remoteAt.isAfter(localAt))) {
        toApply[localKey] = row['value'];
        if (remoteAt != null) {
          localMeta[localKey] = remoteAt.millisecondsSinceEpoch;
        }
      }
    }

    var applied = false;
    if (toApply.isNotEmpty) {
      await _applyPreferencesToLocal(prefs, toApply);
      await _writePrefLocalMeta(prefs, localMeta);
      applied = true;
    }

    // Push local allowlisted keys that are missing remotely or locally newer.
    final localSnapshot = _snapshotLocalAllowlisted(prefs);
    final toPush = <String, dynamic>{};
    for (final entry in localSnapshot.entries) {
      final serverKey = canonicalServerPreferenceKey(entry.key);
      final localAtMs = localMeta[entry.key];
      final remoteAt = remoteUpdated[entry.key];
      if (remoteAt == null) {
        toPush[serverKey] = entry.value;
        continue;
      }
      if (localAtMs != null) {
        final localAt = DateTime.fromMillisecondsSinceEpoch(
          localAtMs,
          isUtc: true,
        );
        if (localAt.isAfter(remoteAt)) {
          toPush[serverKey] = entry.value;
        }
      }
    }

    if (toPush.isNotEmpty) {
      // Final safety strip (never secrets).
      final safe = buildServerPreferencesPayload(toPush);
      if (safe.isNotEmpty) {
        try {
          await putPrefs(
            clientId: kTayraClientId,
            preferences: safe,
            mode: 'merge',
          );
        } catch (e) {
          debugPrint('ClientDataService putClientPreferences failed: $e');
        }
      }
    }
    return applied;
  }

  /// Push a single allowlisted preference after a local settings change.
  ///
  /// No-ops for non-allowlisted / sensitive keys and when client-data is
  /// unavailable.
  Future<void> pushAllowlistedPreference(String key, dynamic value) async {
    if (!isAllowlistedPreferenceKey(key)) return;
    if (!_backend.isAuthenticated) return;

    final prefs = await SharedPreferences.getInstance();
    final meta = _readPrefLocalMeta(prefs);
    meta[canonicalLocalPreferenceKey(key)] =
        DateTime.now().toUtc().millisecondsSinceEpoch;
    await _writePrefLocalMeta(prefs, meta);

    await ensureReady();
    if (!isClientDataReady) return;
    final putPrefs = _backend.putClientPreferences;
    if (putPrefs == null) return;

    final payload = buildServerPreferencesPayload({key: value});
    if (payload.isEmpty) return;
    try {
      await putPrefs(
        clientId: kTayraClientId,
        preferences: payload,
        mode: 'merge',
      );
    } catch (e) {
      debugPrint('ClientDataService pushAllowlistedPreference failed: $e');
    }
  }

  /// Push all current allowlisted local prefs (e.g. after a full local restore).
  Future<void> pushAllAllowlistedPreferences() async {
    if (!_backend.isAuthenticated) return;
    await ensureReady();
    if (!isClientDataReady) return;
    final putPrefs = _backend.putClientPreferences;
    if (putPrefs == null) return;

    final prefs = await SharedPreferences.getInstance();
    final snapshot = _snapshotLocalAllowlisted(prefs);
    final payload = buildServerPreferencesPayload(snapshot);
    if (payload.isEmpty) return;

    final meta = _readPrefLocalMeta(prefs);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final k in snapshot.keys) {
      meta[k] = now;
    }
    await _writePrefLocalMeta(prefs, meta);

    try {
      await putPrefs(
        clientId: kTayraClientId,
        preferences: payload,
        mode: 'merge',
      );
    } catch (e) {
      debugPrint('ClientDataService pushAllAllowlistedPreferences failed: $e');
    }
  }

  Map<String, dynamic> _snapshotLocalAllowlisted(SharedPreferences prefs) {
    final out = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (!isAllowlistedPreferenceKey(key)) continue;
      final localKey = canonicalLocalPreferenceKey(key);
      final v = prefs.get(key);
      if (v != null) out[localKey] = v;
    }
    return out;
  }

  Future<void> _applyPreferencesToLocal(
    SharedPreferences prefs,
    Map<String, dynamic> values,
  ) async {
    for (final entry in values.entries) {
      final key = canonicalLocalPreferenceKey(entry.key);
      if (!isAllowlistedPreferenceKey(key)) continue;
      final v = entry.value;
      if (v == null) continue;
      if (v is bool) {
        await prefs.setBool(key, v);
      } else if (v is int) {
        await prefs.setInt(key, v);
      } else if (v is double) {
        await prefs.setDouble(key, v);
      } else if (v is String) {
        await prefs.setString(key, v);
      } else if (v is List) {
        // mobile_pinned_tab_indices is stored as comma-separated string locally.
        if (key == 'mobile_pinned_tab_indices') {
          await prefs.setString(key, v.map((e) => e.toString()).join(','));
        }
      } else {
        // JSON-ish numbers from server may arrive as num.
        if (v is num) {
          if (v is double || v % 1 != 0) {
            await prefs.setDouble(key, v.toDouble());
          } else {
            await prefs.setInt(key, v.toInt());
          }
        } else {
          await prefs.setString(key, v.toString());
        }
      }
    }
  }

  Map<String, int> _readPrefLocalMeta(SharedPreferences prefs) {
    final raw = prefs.getString(_prefLocalUpdatedMetaKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, int>{};
      for (final e in decoded.entries) {
        final ms = e.value;
        if (ms is int) {
          out[e.key.toString()] = ms;
        } else if (ms is num) {
          out[e.key.toString()] = ms.toInt();
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writePrefLocalMeta(
    SharedPreferences prefs,
    Map<String, int> meta,
  ) async {
    await prefs.setString(_prefLocalUpdatedMetaKey, jsonEncode(meta));
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toUtc();
    }
    return null;
  }
}
