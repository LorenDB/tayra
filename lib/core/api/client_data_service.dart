import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

// ── Service ─────────────────────────────────────────────────────────────

/// Feature detection, device registration, and rich listening dual-write.
///
/// Online path when supported:
/// 1. Upsert [ClientDevice] for this install UUID
/// 2. One rich POST per play session (no `creation_date` → server now)
/// 3. PATCH by-session every ≥15s / pause / end
///
/// When unsupported (GET client-devices → 404): thin [recordListening] only.
/// Offline / network errors: swallow; SQLite remains the offline store.
class ClientDataService {
  ClientDataService(this._ref);

  final Ref _ref;

  bool? _richSupported;
  bool _deviceRegistered = false;
  Future<void>? _readyFuture;

  String? _activeSessionId;
  int? _activeTrackId;
  int _lastKnownSeconds = 0;
  int _lastPatchedSeconds = 0;
  DateTime? _lastPatchAt;

  CachedFunkwhaleApi get _api => _ref.read(cachedFunkwhaleApiProvider);

  FunkwhaleApi get _rawApi => _ref.read(funkwhaleApiProvider);

  bool get isRichActive =>
      _richSupported == true && _deviceRegistered && _activeSessionId != null;

  /// Probe support + register this device. Safe to call repeatedly.
  Future<void> ensureReady() async {
    final auth = _ref.read(authStateProvider);
    if (!auth.isAuthenticated) return;

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
    final supported = await _rawApi.probeClientDataSupport();
    _richSupported = supported;
    if (!supported) return;
    await _registerDevice();
  }

  Future<void> _registerDevice() async {
    final uuid = await getDeviceUuid();
    final name = await getDeviceDisplayName();
    await _rawApi.upsertClientDevice(
      uuid: uuid,
      name: name,
      clientId: kTayraClientId,
    );
    _deviceRegistered = true;
  }

  /// Start a server-side listen for [track].
  ///
  /// Rich path: one POST with device + new session UUID (no creation_date).
  /// Thin fallback: stock track-only scrobble.
  Future<void> recordTrackStarted(Track track) async {
    await ensureReady();

    // Same track already has an active rich session — do not double-POST.
    if (_activeTrackId == track.id && _activeSessionId != null) {
      return;
    }

    // Best-effort final patch for previous session before switching.
    if (_activeSessionId != null &&
        _activeTrackId != null &&
        _activeTrackId != track.id &&
        _lastKnownSeconds > _lastPatchedSeconds) {
      await _patchActive(force: true);
    }

    _activeTrackId = track.id;
    _lastKnownSeconds = 0;
    _lastPatchedSeconds = 0;
    _lastPatchAt = null;

    if (_richSupported == true && _deviceRegistered) {
      final sessionId = _generateUuidV4();
      _activeSessionId = sessionId;
      try {
        final deviceUuid = await getDeviceUuid();
        await _api.createRichListening(
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
          await _api.createRichListening(
            trackId: track.id,
            sourceDevice: await getDeviceUuid(),
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
      await _api.recordListening(track.id);
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

  Future<void> _patchActive({required bool force}) async {
    final sessionId = _activeSessionId;
    if (sessionId == null) return;
    final seconds = _lastKnownSeconds;
    if (seconds <= 0) return;
    if (seconds <= _lastPatchedSeconds && !force) return;
    if (seconds == _lastPatchedSeconds) return;

    try {
      await _api.patchListeningBySession(sessionId, durationSeconds: seconds);
      _lastPatchedSeconds = seconds;
      _lastPatchAt = DateTime.now();
    } catch (e) {
      debugPrint('ClientDataService patch failed: $e');
    }
  }

  /// Clear cached capability / session state (logout).
  void reset() {
    _richSupported = null;
    _deviceRegistered = false;
    _readyFuture = null;
    _activeSessionId = null;
    _activeTrackId = null;
    _lastKnownSeconds = 0;
    _lastPatchedSeconds = 0;
    _lastPatchAt = null;
  }
}

String _generateUuidV4() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20, 32)}';
}
