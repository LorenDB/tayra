import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/api/client_data_service.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/core/backup/nextcloud_backup_service.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/platform/app_platform.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';

// ── Constants ───────────────────────────────────────────────────────────

/// Server hard limit; keep in sync with [FunkwhaleApi.bulkListeningMaxItems].
const kBulkListeningChunkSize = FunkwhaleApi.bulkListeningMaxItems;

/// Prefs key: highest `listened_at` ms successfully bulk-uploaded.
///
/// Absent key means catch-up is **not armed** — historical migration stays
/// behind the settings/restore UI; bootstrap only seeds "now" then flushes
/// future offline listens.
const kListenHistoryBulkSyncedMsKey = 'listen_history_bulk_synced_ms';

/// UUID (any version) acceptable as server `source_device`.
final _deviceUuidRegex = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

// ── Provider ────────────────────────────────────────────────────────────

final listenHistoryImportServiceProvider = Provider<ListenHistoryImportService>(
  (ref) => ListenHistoryImportService(ref),
);

/// Bootstrap: after client-data is ready, flush offline listens on reconnect.
///
/// Watch from app startup (native only). Safe no-op when rich API is missing.
final listenHistoryImportBootstrapProvider = Provider<void>((ref) {
  if (!AppPlatform.supportsOfflineCache) return;

  ref.listen<AuthState>(authStateProvider, (previous, next) {
    if (next.isAuthenticated) {
      unawaited(ref.read(listenHistoryImportServiceProvider).catchUpIfNeeded());
    }
  });

  ref.listen<OfflineState>(offlineStateProvider, (previous, next) {
    final wasOffline = previous?.isOffline ?? true;
    if (wasOffline && !next.isOffline) {
      unawaited(ref.read(listenHistoryImportServiceProvider).catchUpIfNeeded());
    }
  });

  final auth = ref.read(authStateProvider);
  if (auth.isAuthenticated) {
    unawaited(ref.read(listenHistoryImportServiceProvider).catchUpIfNeeded());
  }
});

// ── Testable backend ────────────────────────────────────────────────────

/// Network + storage hooks for [ListenHistoryImportService].
class ListenHistoryImportBackend {
  const ListenHistoryImportBackend({
    required this.probeClientDataSupport,
    required this.upsertClientDevice,
    required this.bulkCreateListenings,
    required this.getDeviceUuid,
    required this.getDeviceName,
    required this.getAllListens,
    required this.getListensAfter,
    required this.getSyncedThroughMs,
    required this.setSyncedThroughMs,
    required this.isAuthenticated,
    required this.isOffline,
    required this.nowMs,
    this.loadNextcloudHistory,
  });

  final Future<bool> Function() probeClientDataSupport;
  final Future<void> Function({
    required String uuid,
    required String name,
    String clientId,
    String? clientVersion,
  })
  upsertClientDevice;
  final Future<BulkListeningResult> Function({
    required List<BulkListeningItem> items,
    String mode,
    int? dedupWindowSeconds,
  })
  bulkCreateListenings;
  final Future<String> Function() getDeviceUuid;
  final Future<String> Function() getDeviceName;
  final Future<List<ListenRecord>> Function() getAllListens;
  final Future<List<ListenRecord>> Function(int afterMs) getListensAfter;

  /// Highest successfully bulk-synced `listened_at` ms, or `null` if unset
  /// (catch-up not armed — do not treat as epoch 0).
  final Future<int?> Function() getSyncedThroughMs;
  final Future<void> Function(int ms) setSyncedThroughMs;
  final bool Function() isAuthenticated;
  final bool Function() isOffline;

  /// Clock for seeding watermark when catch-up first arms (tests inject).
  final int Function() nowMs;

  /// Optional: merge remote Nextcloud history into local DB, return added count.
  final Future<int> Function()? loadNextcloudHistory;
}

// ── Service ─────────────────────────────────────────────────────────────

/// Import local / Nextcloud listen history to the server via bulk
/// `enrich_or_create`, and flush offline listens after reconnect.
///
/// Flow:
/// 1. Register every device UUID present in the batch (local + remote)
/// 2. Map [ListenRecord] → [BulkListeningItem] (ISO `creation_date`, etc.)
/// 3. POST chunks of ≤ [kBulkListeningChunkSize]
/// 4. Advance sync watermark (re-runs are idempotent)
class ListenHistoryImportService {
  ListenHistoryImportService(this._ref, {ListenHistoryImportBackend? backend})
    : _backendOverride = backend;

  final Ref? _ref;
  final ListenHistoryImportBackend? _backendOverride;

  /// Serializes full import / catch-up (same pattern as ClientDataService).
  Future<void> _tail = Future.value();
  bool _importing = false;

  @visibleForTesting
  ListenHistoryImportService.forTest(ListenHistoryImportBackend backend)
    : _ref = null,
      _backendOverride = backend;

  bool get isImporting => _importing;

  ListenHistoryImportBackend get _backend {
    final override = _backendOverride;
    if (override != null) return override;
    final ref = _ref!;
    final raw = ref.read(funkwhaleApiProvider);
    final cached = ref.read(cachedFunkwhaleApiProvider);
    return ListenHistoryImportBackend(
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
      bulkCreateListenings:
          ({
            required List<BulkListeningItem> items,
            String mode = 'enrich_or_create',
            int? dedupWindowSeconds,
          }) => cached.bulkCreateListenings(
            items: items,
            mode: mode,
            dedupWindowSeconds: dedupWindowSeconds,
          ),
      getDeviceUuid: getDeviceUuid,
      getDeviceName: getDeviceDisplayName,
      getAllListens: ListenHistoryService.getAllListens,
      getListensAfter: ListenHistoryService.getListensAfter,
      getSyncedThroughMs: () async {
        final prefs = await SharedPreferences.getInstance();
        // Null (missing key) means catch-up not armed — never default to 0.
        return prefs.getInt(kListenHistoryBulkSyncedMsKey);
      },
      setSyncedThroughMs: (ms) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(kListenHistoryBulkSyncedMsKey, ms);
      },
      isAuthenticated: () => ref.read(authStateProvider).isAuthenticated,
      isOffline: () => ref.read(offlineStateProvider).isOffline,
      nowMs: () => DateTime.now().millisecondsSinceEpoch,
      loadNextcloudHistory: () async {
        final nc = ref.read(nextcloudBackupProvider);
        if (!nc.isConnected ||
            nc.serverUrl == null ||
            nc.username == null ||
            nc.appPassword == null) {
          return 0;
        }
        final funkHost = ref.read(authStateProvider).serverUrl ?? '';
        if (funkHost.isEmpty) return 0;
        return NextcloudBackupService.syncRemoteHistory(
          ncServer: nc.serverUrl!,
          ncUser: nc.username!,
          ncAppPassword: nc.appPassword!,
          funkServerHost: funkHost,
        );
      },
    );
  }

  /// Whether the server supports client-data (devices + rich/bulk listenings).
  Future<bool> isRichSupported() async {
    if (!_backend.isAuthenticated()) return false;
    try {
      return await _backend.probeClientDataSupport();
    } catch (e) {
      debugPrint('ListenHistoryImportService probe failed: $e');
      return false;
    }
  }

  /// Map a local [ListenRecord] to a bulk item.
  ///
  /// - `listened_at` → ISO `creation_date`
  /// - `source_device` `'local'` / null → this install UUID
  /// - remote UUID kept; non-UUID legacy ids → null (server requires UUID)
  /// - `client_session_id` always null for historical rows
  @visibleForTesting
  static BulkListeningItem? mapRecord(
    ListenRecord record, {
    required String localDeviceUuid,
  }) {
    final source = resolveSourceDeviceUuid(
      record.sourceDevice,
      localDeviceUuid: localDeviceUuid,
    );
    return BulkListeningItem(
      trackId: record.trackId,
      creationDate: record.listenedAt,
      durationSeconds: record.durationSeconds,
      sourceDevice: source,
      clientSessionId: null,
    );
  }

  /// Resolve local `source_device` tag to a server device UUID, or null.
  @visibleForTesting
  static String? resolveSourceDeviceUuid(
    String? sourceDevice, {
    required String localDeviceUuid,
  }) {
    if (sourceDevice == null ||
        sourceDevice.isEmpty ||
        sourceDevice == 'local') {
      return localDeviceUuid;
    }
    if (_deviceUuidRegex.hasMatch(sourceDevice)) {
      return sourceDevice.toLowerCase();
    }
    // Legacy sanitized device id (e.g. samsung_sm_s908u) — not a UUID.
    return null;
  }

  static bool isDeviceUuid(String value) => _deviceUuidRegex.hasMatch(value);

  /// Full import of local SQLite history (and optionally Nextcloud first).
  ///
  /// Re-runnable: server `enrich_or_create` dedups / enriches stock rows.
  Future<BulkListeningResult> importLocalHistory({
    bool includeNextcloud = false,
  }) async {
    return _runExclusive(() async {
      if (!_backend.isAuthenticated()) return BulkListeningResult.empty;
      if (_backend.isOffline()) {
        debugPrint('ListenHistoryImportService: offline, skip full import');
        return BulkListeningResult.empty;
      }

      final supported = await _backend.probeClientDataSupport();
      if (!supported) return BulkListeningResult.empty;

      if (includeNextcloud) {
        final loader = _backend.loadNextcloudHistory;
        if (loader != null) {
          try {
            final n = await loader();
            debugPrint(
              'ListenHistoryImportService: merged $n Nextcloud records',
            );
          } catch (e) {
            debugPrint(
              'ListenHistoryImportService: Nextcloud merge failed: $e',
            );
          }
        }
      }

      final records = await _backend.getAllListens();
      return _importRecords(records, advanceWatermark: true);
    });
  }

  /// Offline catch-up: bulk-upload listens after the last sync watermark.
  ///
  /// Uses original `listened_at` timestamps (never looped single POST).
  ///
  /// When the watermark key is **unset**, seeds it to "now" and returns
  /// without bulk — full historical migration stays behind the settings /
  /// restore UI. Only listens after the armed watermark are auto-flushed.
  Future<BulkListeningResult> catchUpIfNeeded() async {
    return _runExclusive(() async {
      if (!_backend.isAuthenticated()) return BulkListeningResult.empty;
      if (_backend.isOffline()) return BulkListeningResult.empty;

      try {
        final supported = await _backend.probeClientDataSupport();
        if (!supported) return BulkListeningResult.empty;
      } catch (_) {
        return BulkListeningResult.empty;
      }

      final watermark = await _backend.getSyncedThroughMs();
      if (watermark == null) {
        // Arm catch-up at "now" so we never silently upload all history.
        final now = _backend.nowMs();
        await _backend.setSyncedThroughMs(now);
        debugPrint(
          'ListenHistoryImportService: catch-up armed at $now '
          '(no historical bulk; use settings upload for migration)',
        );
        return BulkListeningResult.empty;
      }

      final records = await _backend.getListensAfter(watermark);
      if (records.isEmpty) return BulkListeningResult.empty;

      debugPrint(
        'ListenHistoryImportService: catch-up ${records.length} listens '
        '(after $watermark)',
      );
      return _importRecords(records, advanceWatermark: true);
    });
  }

  /// Import an explicit list (tests / restore hooks).
  Future<BulkListeningResult> importRecords(List<ListenRecord> records) async {
    return _runExclusive(() => _importRecords(records, advanceWatermark: true));
  }

  Future<BulkListeningResult> _importRecords(
    List<ListenRecord> records, {
    required bool advanceWatermark,
  }) async {
    if (records.isEmpty) return BulkListeningResult.empty;

    final localUuid = await _backend.getDeviceUuid();
    final localName = await _backend.getDeviceName();
    await ListenHistoryService.loadDeviceDisplayNames();

    // Collect device UUID → display name for registration.
    final devices = <String, String>{localUuid: localName};
    for (final r in records) {
      final uuid = resolveSourceDeviceUuid(
        r.sourceDevice,
        localDeviceUuid: localUuid,
      );
      if (uuid == null || devices.containsKey(uuid)) continue;
      final name =
          ListenHistoryService.getCachedDeviceDisplayName(uuid) ??
          ListenHistoryService.resolveDeviceDisplayName(uuid);
      devices[uuid] = name;
    }

    // Devices must be registered before bulk references them (K15).
    for (final entry in devices.entries) {
      try {
        await _backend.upsertClientDevice(
          uuid: entry.key,
          name: entry.value,
          clientId: kTayraClientId,
        );
      } catch (e) {
        debugPrint(
          'ListenHistoryImportService: device upsert ${entry.key} failed: $e',
        );
        // Continue — bulk will report device_not_registered per row if needed.
      }
    }

    final items = <BulkListeningItem>[];
    for (final r in records) {
      final item = mapRecord(r, localDeviceUuid: localUuid);
      if (item != null) items.add(item);
    }
    if (items.isEmpty) return BulkListeningResult.empty;

    var aggregate = BulkListeningResult.empty;
    // Max creation_date of items covered by HTTP-successful chunks only.
    // Never advance past a failed chunk (would permanently skip catch-up rows).
    int? maxSuccessfulMs;

    for (var i = 0; i < items.length; i += kBulkListeningChunkSize) {
      final end = (i + kBulkListeningChunkSize).clamp(0, items.length);
      final chunk = items.sublist(i, end);
      try {
        final result = await _backend.bulkCreateListenings(
          items: chunk,
          mode: 'enrich_or_create',
        );
        // Re-index errors relative to the full list for clearer logs.
        if (result.errors.isNotEmpty && i > 0) {
          final shifted = BulkListeningResult(
            created: result.created,
            enriched: result.enriched,
            skippedDuplicate: result.skippedDuplicate,
            errors: [
              for (final e in result.errors)
                BulkListeningError(
                  index: e.index + i,
                  code: e.code,
                  detail: e.detail,
                ),
            ],
          );
          aggregate = aggregate + shifted;
        } else {
          aggregate = aggregate + result;
        }
        // HTTP success (including per-row errors) counts as uploaded chunk.
        for (final it in chunk) {
          final ms = it.creationDate.millisecondsSinceEpoch;
          if (maxSuccessfulMs == null || ms > maxSuccessfulMs) {
            maxSuccessfulMs = ms;
          }
        }
      } catch (e, st) {
        debugPrint('ListenHistoryImportService bulk chunk failed: $e\n$st');
        // Stop further chunks on hard failure; partial success kept.
        // Do not include this chunk (or later ones) in the watermark.
        break;
      }
    }

    if (advanceWatermark && maxSuccessfulMs != null) {
      final prev = await _backend.getSyncedThroughMs();
      // Always arm on first successful bulk; otherwise only move forward.
      if (prev == null || maxSuccessfulMs > prev) {
        await _backend.setSyncedThroughMs(maxSuccessfulMs);
      }
    }

    debugPrint(
      'ListenHistoryImportService: done created=${aggregate.created} '
      'enriched=${aggregate.enriched} '
      'skipped=${aggregate.skippedDuplicate} '
      'errors=${aggregate.errors.length}'
      '${maxSuccessfulMs != null ? ' watermark<=$maxSuccessfulMs' : ''}',
    );
    return aggregate;
  }

  Future<BulkListeningResult> _runExclusive(
    Future<BulkListeningResult> Function() op,
  ) {
    final completer = Completer<BulkListeningResult>();
    _tail = _tail
        .then((_) async {
          _importing = true;
          try {
            completer.complete(await op());
          } catch (e, st) {
            completer.completeError(e, st);
          } finally {
            _importing = false;
          }
        })
        .catchError((_) {});
    return completer.future;
  }
}
