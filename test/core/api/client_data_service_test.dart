import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/api/client_data_service.dart';
import 'package:tayra/core/api/models.dart';

void main() {
  group('ClientDataService', () {
    late _FakeApi api;
    late ClientDataService service;

    setUp(() {
      api = _FakeApi();
      service = ClientDataService.forTest(api.backend);
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
    getDeviceUuid: () async => 'device-uuid',
    getDeviceName: () async => 'Test Device',
    getAppVersion: () async => '9.9.9',
  );
}
