import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/core/backup/nextcloud_backup_service.dart';

// ── Constants ───────────────────────────────────────────────────────────

/// OAuth / server client_id for this app (not the OAuth app client id).
const kTayraClientId = 'tayra';

/// Minimum gap between non-forced duration PATCHes (spec: ≥10–15s).
const kServerListenPatchInterval = Duration(seconds: 15);

// ── Provider ────────────────────────────────────────────────────────────

final clientDataServiceProvider = Provider<ClientDataService>((ref) {
  return ClientDataService(ref);
});

/// Side-effect bootstrap: register/upsert ClientDevice when authenticated.
///
/// Watch this from app startup so login and cold-start both trigger
/// registration without coupling AuthNotifier to the API layer.
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
  final bool isAuthenticated;
}

// ── Service ─────────────────────────────────────────────────────────────

/// Feature detection, device registration, and rich listening dual-write.
///
/// Online path when supported:
/// 1. Upsert [ClientDevice] for this install UUID
/// 2. One rich POST per play session (no `creation_date` → server now)
/// 3. PATCH by-session every ≥15s / pause / end
/// 4. [endSession] on local listen finalize so the next play gets a new row
///
/// When unsupported (GET client-devices → 404): thin [recordListening] only.
/// Offline / network errors: swallow; SQLite remains the offline store.
class ClientDataService {
  ClientDataService(this._ref, {ClientDataBackend? backend})
    : _backendOverride = backend;

  final Ref? _ref;
  final ClientDataBackend? _backendOverride;

  bool? _richSupported;
  bool _deviceRegistered = false;
  Future<void>? _readyFuture;

  String? _activeSessionId;
  int? _activeTrackId;
  int _lastKnownSeconds = 0;
  int _lastPatchedSeconds = 0;
  DateTime? _lastPatchAt;

  /// Serializes start/end/sync so concurrent player call sites cannot
  /// double-POST or clear a session mid-create.
  Future<void> _tail = Future.value();

  /// Test-only construction without Riverpod.
  @visibleForTesting
  ClientDataService.forTest(ClientDataBackend backend)
    : _ref = null,
      _backendOverride = backend;

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
      isAuthenticated: ref.read(authStateProvider).isAuthenticated,
    );
  }

  bool get isRichActive =>
      _richSupported == true && _deviceRegistered && _activeSessionId != null;

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
    _clearActiveSession();
  }
}
