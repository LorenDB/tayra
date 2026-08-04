import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tayra/core/api/client_data_service.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/cache/cache_database.dart';
import 'package:tayra/features/podcasts/podcast_progress_service.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ClientDataService', () {
    late _FakeApi api;
    late ClientDataService service;
    late PodcastProgressService progress;
    late Database db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // In-memory DB so ensureReady → listen bulk/purge does not hit path_provider.
      db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1),
      );
      CacheDatabase.instance.debugSetDatabase(db);
      await ListenHistoryService.ensureTable();

      api = _FakeApi();
      progress = PodcastProgressService.memoryOnly();
      service = ClientDataService.forTest(
        api.backend,
        progressService: progress,
      );
    });

    tearDown(() async {
      // Drain background ensureReady → listen sync while the DB is still open.
      try {
        await service.syncPendingListensAndPurge();
      } catch (_) {}
      service.reset();
      CacheDatabase.instance.debugSetDatabase(null);
      await db.close();
    });

    Track track(int id) => Track(
      id: id,
      title: 'T$id',
      artist: Artist(id: id, name: 'A$id'),
      album: Album(id: id, title: 'Al$id'),
      listenUrl: 'https://example.com/$id',
    );

    test('probe 404 → thin recordListening only, no rich create', () async {
      api.probeResult = false;

      await service.recordTrackStarted(track(1));

      expect(api.probeCalls, 1);
      expect(api.upsertCalls, 0);
      expect(api.richCreates, isEmpty);
      expect(api.thinRecords, [1]);
      expect(service.debugActiveSessionId, isNull);
    });

    test(
      'rich success → one create, no thin, no creation_date field',
      () async {
        await service.recordTrackStarted(track(7));

        expect(api.thinRecords, isEmpty);
        expect(api.richCreates, hasLength(1));
        final body = api.richCreates.single;
        expect(body['trackId'], 7);
        expect(body['sourceDevice'], 'device-uuid');
        expect(body['clientSessionId'], isNotNull);
        expect(body.containsKey('creationDate'), isFalse);
        expect(body.containsKey('creation_date'), isFalse);
        expect(service.debugActiveSessionId, isNotNull);
        expect(service.debugActiveTrackId, 7);
        expect(api.upsertCalls, 1);
        expect(api.lastClientVersion, '9.9.9');
      },
    );

    test('second start of same track without endSession is no-op', () async {
      await service.recordTrackStarted(track(1));
      final session = service.debugActiveSessionId;
      await service.recordTrackStarted(track(1));

      expect(api.richCreates, hasLength(1));
      expect(service.debugActiveSessionId, session);
    });

    test('endSession then same track starts a new session', () async {
      await service.recordTrackStarted(track(1));
      await service.syncDuration(1, 20, force: true);
      final first = service.debugActiveSessionId;
      await service.endSession();

      expect(service.debugActiveSessionId, isNull);
      expect(api.patches, hasLength(1));
      expect(api.patches.single.seconds, 20);

      await service.recordTrackStarted(track(1));
      expect(api.richCreates, hasLength(2));
      expect(service.debugActiveSessionId, isNot(first));
    });

    test('concurrent recordTrackStarted serializes to one create', () async {
      api.createDelay = const Duration(milliseconds: 30);

      final a = service.recordTrackStarted(track(3));
      final b = service.recordTrackStarted(track(3));
      await Future.wait([a, b]);

      expect(api.richCreates, hasLength(1));
      expect(api.thinRecords, isEmpty);
    });

    test('PATCH skipped inside 15s unless force', () async {
      await service.recordTrackStarted(track(1));

      await service.syncDuration(1, 5);
      expect(api.patches, hasLength(1));

      await service.syncDuration(1, 10);
      expect(api.patches, hasLength(1), reason: 'throttled non-force');

      await service.syncDuration(1, 12, force: true);
      expect(api.patches, hasLength(2));
      expect(api.patches.last.seconds, 12);
    });

    test('device re-register once on create failure then succeeds', () async {
      api.failCreatesBeforeSuccess = 1;

      await service.recordTrackStarted(track(2));

      expect(api.upsertCalls, 2); // ensureReady + retry
      expect(api.richCreates, hasLength(1));
      expect(api.thinRecords, isEmpty);
      expect(service.debugActiveSessionId, isNotNull);
    });

    test('patch 404 recovers via re-create same session', () async {
      await service.recordTrackStarted(track(4));
      final session = service.debugActiveSessionId!;
      api.patchThrows404 = true;

      await service.syncDuration(4, 30, force: true);

      expect(api.richCreates, hasLength(2));
      expect(api.richCreates.last['clientSessionId'], session);
      expect(api.richCreates.last['durationSeconds'], 30);
      api.patchThrows404 = false;

      await service.syncDuration(4, 45, force: true);
      expect(api.patches.last.seconds, 45);
    });

    test('reset clears capability and session (logout)', () async {
      await service.recordTrackStarted(track(1));
      service.reset();

      expect(service.debugActiveSessionId, isNull);
      expect(service.debugActiveTrackId, isNull);
      expect(service.debugRichSupported, isNull);

      api.probeResult = false;
      await service.recordTrackStarted(track(9));
      expect(api.probeCalls, 2, reason: 're-probes after reset');
      expect(api.thinRecords, contains(9));
    });

    test('bulk progress chunks at 500 and push-before-pull order', () async {
      // Register first with empty local store (drain ensureReady sync).
      await service.ensureReady();
      await service.syncProgressAndPreferences();

      // Seed 501 local rows so bulk must emit two chunks.
      for (var i = 1; i <= 501; i++) {
        await progress.applyRemoteLww(
          trackId: i,
          positionMs: i,
          completed: false,
          updatedAt: DateTime.utc(2026, 1, 1).add(Duration(seconds: i)),
        );
      }
      api.remoteProgressPages = [
        [
          {
            'track': 999,
            'position_ms': 42,
            'completed': false,
            'updated_at': '2026-07-01T00:00:00.000Z',
          },
        ],
      ];
      api.bulkChunks.clear();
      api.eventLog.clear();

      await service.syncPodcastProgress();

      expect(api.bulkChunks, hasLength(2));
      expect(api.bulkChunks[0], hasLength(500));
      expect(api.bulkChunks[1], hasLength(1));
      // Pull applied remote row into memory store.
      final remote = await progress.getProgress(999);
      expect(remote?.positionMs, 42);
      final bulkIdx = api.eventLog.indexOf('bulk');
      final pullIdx = api.eventLog.indexOf('progress_page');
      expect(bulkIdx, greaterThanOrEqualTo(0));
      expect(pullIdx, greaterThan(bulkIdx));
    });

    test('pushPlaybackProgress 409 applies server body via LWW', () async {
      await service.ensureReady();
      await progress.upsertPosition(
        trackId: 5,
        positionMs: 1000,
        durationMs: 10000,
      );

      api.putProgressConflict = {
        'track': 5,
        'position_ms': 8000,
        'duration_ms': 10000,
        'completed': false,
        'updated_at': '2030-01-01T00:00:00.000Z',
      };

      await service.pushPlaybackProgress(
        trackId: 5,
        positionMs: 2000,
        durationMs: 10000,
        force: true,
      );

      final after = await progress.getProgress(5);
      expect(after?.positionMs, 8000);
    });

    test('markEpisodePlayed dual-writes force PUT with completed', () async {
      await service.ensureReady();
      await service.markEpisodePlayed(
        trackId: 8,
        channelUuid: 'ch-8',
        durationMs: 120000,
      );

      final local = await progress.getProgress(8);
      expect(local?.completed, isTrue);
      expect(local?.channelUuid, 'ch-8');
      expect(api.progressPuts, hasLength(1));
      final put = api.progressPuts.single;
      expect(put['trackId'], 8);
      expect(put['completed'], isTrue);
      expect(put['channelUuid'], 'ch-8');
      expect(put['force'], isNull); // force is client-side only
    });

    test('prefs sync strips secrets and first-sync seeds meta', () async {
      SharedPreferences.setMockInitialValues({
        'browse_mode': 'artists',
        'gapless_playback': true,
        'groq_api_key': 'sk-secret-never',
        'access_token': 'tok',
      });
      api.remotePrefs = [
        {
          'key': 'browse_mode',
          'value': 'albums',
          // Older than first-sync seed (≈now) so local wins.
          'updated_at': '2020-01-01T00:00:00.000Z',
        },
        {
          'key': 'analytics_enabled',
          'value': false,
          'updated_at': '2030-01-01T00:00:00.000Z',
        },
      ];

      await service.ensureReady();
      await service.syncAllowlistedPreferences();

      final prefs = await SharedPreferences.getInstance();
      // Local first-sync seed prevents older remote browse_mode clobber.
      expect(prefs.getString('browse_mode'), 'artists');
      // Newer remote key applied.
      expect(prefs.getBool('analytics_enabled'), isFalse);

      // PUT must never include secrets.
      expect(api.prefsPuts, isNotEmpty);
      for (final put in api.prefsPuts) {
        final body = put['preferences'] as Map<String, dynamic>;
        expect(body.containsKey('groq_api_key'), isFalse);
        expect(body.containsKey('access_token'), isFalse);
        expect(body['browse_mode'], 'artists');
      }
    });

    test('pushAllowlistedPreference rejects api keys', () async {
      await service.ensureReady();
      await service.pushAllowlistedPreference('groq_api_key', 'sk-x');
      expect(api.prefsPuts, isEmpty);
    });

    test(
      'linkLocalListenToServer marks row when rich session active',
      () async {
        await service.recordTrackStarted(track(42));
        expect(service.debugActiveSessionId, isNotNull);

        final recordId = await ListenHistoryService.insertListen(
          track(42),
          listenedSeconds: 12,
          listenedAt: DateTime.now(),
        );
        await service.linkLocalListenToServer(recordId: recordId, trackId: 42);

        expect(await ListenHistoryService.getPendingSyncCount(), 0);
        final all = await ListenHistoryService.getAllListens();
        expect(all.single.isSynced, isTrue);
        expect(all.single.clientSessionId, service.debugActiveSessionId);
      },
    );

    test(
      'syncPendingListensAndPurge bulk-uploads then purges old synced',
      () async {
        final old = DateTime.now().subtract(const Duration(days: 45));
        final id = await ListenHistoryService.insertListen(
          track(99),
          listenedSeconds: 55,
          listenedAt: old,
        );

        await service.ensureReady();
        // Coalesce with ensureReady's background sync, then run once more.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await service.syncPendingListensAndPurge();

        expect(api.listenBulkChunks, isNotEmpty);
        final item = api.listenBulkChunks.first.single;
        expect(item['track'], 99);
        expect(item['duration_seconds'], 55);
        expect(item['source_device'], 'device-uuid');
        expect(item['client_session_id'], isNotNull);
        expect(item['creation_date'], isNotNull);

        // Marked synced then purged (past 30d retention).
        expect(await ListenHistoryService.getPendingSyncCount(), 0);
        final remaining = await ListenHistoryService.getAllListens();
        expect(remaining.any((r) => r.id == id), isFalse);
      },
    );
  });
}

class _PatchCall {
  _PatchCall(this.sessionId, this.seconds);
  final String sessionId;
  final int seconds;
}

class _FakeApi {
  bool probeResult = true;
  int probeCalls = 0;
  int upsertCalls = 0;
  String? lastClientVersion;
  int failCreatesBeforeSuccess = 0;
  int _remainingCreateFailures = -1;
  bool patchThrows404 = false;
  Duration? createDelay;

  final richCreates = <Map<String, dynamic>>[];
  final thinRecords = <int>[];
  final patches = <_PatchCall>[];

  final bulkChunks = <List<Map<String, dynamic>>>[];
  final listenBulkChunks = <List<Map<String, dynamic>>>[];
  final progressPuts = <Map<String, dynamic>>[];
  final prefsPuts = <Map<String, dynamic>>[];
  final eventLog = <String>[];
  int nextListeningId = 1000;

  List<List<Map<String, dynamic>>> remoteProgressPages = const [];
  List<Map<String, dynamic>> remotePrefs = const [];
  Map<String, dynamic>? putProgressConflict;

  late final ClientDataBackend backend = ClientDataBackend(
    probeClientDataSupport: () async {
      probeCalls++;
      return probeResult;
    },
    upsertClientDevice: ({
      required String uuid,
      required String name,
      String clientId = kTayraClientId,
      String? clientVersion,
    }) async {
      upsertCalls++;
      lastClientVersion = clientVersion;
    },
    createRichListening: ({
      required int trackId,
      int? durationSeconds,
      String? sourceDevice,
      String? clientSessionId,
    }) async {
      if (createDelay != null) {
        await Future<void>.delayed(createDelay!);
      }
      if (_remainingCreateFailures < 0 && failCreatesBeforeSuccess > 0) {
        _remainingCreateFailures = failCreatesBeforeSuccess;
      }
      if (_remainingCreateFailures > 0) {
        _remainingCreateFailures--;
        throw DioException(
          requestOptions: RequestOptions(path: '/listenings/'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/listenings/'),
            statusCode: 400,
          ),
        );
      }
      final body = <String, dynamic>{
        'id': nextListeningId++,
        'trackId': trackId,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (sourceDevice != null) 'sourceDevice': sourceDevice,
        if (clientSessionId != null) 'clientSessionId': clientSessionId,
      };
      richCreates.add(body);
      return body;
    },
    patchListeningBySession: (
      String clientSessionId, {
      int? durationSeconds,
      String? sourceDevice,
    }) async {
      if (patchThrows404) {
        throw DioException(
          requestOptions: RequestOptions(path: '/by-session/'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/by-session/'),
            statusCode: 404,
          ),
        );
      }
      patches.add(_PatchCall(clientSessionId, durationSeconds ?? 0));
    },
    recordListening: (trackId) async {
      thinRecords.add(trackId);
    },
    bulkCreateListenings: ({
      required List<Map<String, dynamic>> items,
      String mode = 'enrich_or_create',
      int? dedupWindowSeconds,
    }) async {
      listenBulkChunks.add(List<Map<String, dynamic>>.from(items));
      eventLog.add('listen_bulk');
      return {
        'created': items.length,
        'enriched': 0,
        'skipped_duplicate': 0,
        'errors': <dynamic>[],
      };
    },
    getDeviceUuid: () async => 'device-uuid',
    getDeviceName: () async => 'Test Device',
    getAppVersion: () async => '9.9.9',
    putPlaybackProgress: ({
      required int trackId,
      required int positionMs,
      int? durationMs,
      bool? completed,
      String? channelUuid,
      String? sourceDevice,
      DateTime? updatedAt,
    }) async {
      if (putProgressConflict != null) {
        throw DioException(
          requestOptions: RequestOptions(path: '/playback-progress/'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/playback-progress/'),
            statusCode: 409,
            data: {
              'code': 'progress_conflict',
              'progress': putProgressConflict,
            },
          ),
        );
      }
      final body = <String, dynamic>{
        'trackId': trackId,
        'positionMs': positionMs,
        if (durationMs != null) 'durationMs': durationMs,
        if (completed != null) 'completed': completed,
        if (channelUuid != null) 'channelUuid': channelUuid,
        if (sourceDevice != null) 'sourceDevice': sourceDevice,
      };
      progressPuts.add(body);
      eventLog.add('put_progress');
      return body;
    },
    bulkUpsertPlaybackProgress: (items) async {
      bulkChunks.add(List<Map<String, dynamic>>.from(items));
      eventLog.add('bulk');
      return {
        'created': items.length,
        'updated': 0,
        'skipped': 0,
        'errors': <dynamic>[],
      };
    },
    getPlaybackProgressPage: ({
      required int page,
      required int pageSize,
    }) async {
      eventLog.add('progress_page');
      if (page > remoteProgressPages.length) {
        return (results: <Map<String, dynamic>>[], next: null);
      }
      final results = remoteProgressPages[page - 1];
      final hasNext = page < remoteProgressPages.length;
      return (results: results, next: hasNext ? 'page=${page + 1}' : null);
    },
    getClientPreferences: ({
      required String clientId,
      String? deviceUuid,
    }) async {
      eventLog.add('get_prefs');
      return remotePrefs;
    },
    putClientPreferences: ({
      required String clientId,
      required Map<String, dynamic> preferences,
      String? deviceUuid,
      String mode = 'merge',
    }) async {
      prefsPuts.add({
        'clientId': clientId,
        'preferences': Map<String, dynamic>.from(preferences),
        'mode': mode,
      });
      eventLog.add('put_prefs');
      return {'count': preferences.length};
    },
  );
}
