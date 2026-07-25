import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/features/year_review/listen_history_import_service.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';

void main() {
  group('ListenHistoryImportService mapping', () {
    test('local / null source_device → local device UUID', () {
      expect(
        ListenHistoryImportService.resolveSourceDeviceUuid(
          null,
          localDeviceUuid: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        ),
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      );
      expect(
        ListenHistoryImportService.resolveSourceDeviceUuid(
          'local',
          localDeviceUuid: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        ),
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      );
    });

    test('remote UUID is lowercased and kept', () {
      expect(
        ListenHistoryImportService.resolveSourceDeviceUuid(
          '550E8400-E29B-41D4-A716-446655440000',
          localDeviceUuid: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        ),
        '550e8400-e29b-41d4-a716-446655440000',
      );
    });

    test('legacy sanitized device id → null (not a UUID)', () {
      expect(
        ListenHistoryImportService.resolveSourceDeviceUuid(
          'samsung_sm_s908u',
          localDeviceUuid: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        ),
        isNull,
      );
    });

    test('mapRecord sets creation_date from listened_at and null session', () {
      final listened = DateTime.utc(2024, 1, 2, 10, 0, 0);
      final rec = ListenRecord(
        trackId: 42,
        trackTitle: 'T',
        artistName: 'A',
        albumTitle: 'Al',
        durationSeconds: 180,
        listenedAt: listened,
        sourceDevice: 'local',
      );
      final item = ListenHistoryImportService.mapRecord(
        rec,
        localDeviceUuid: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      )!;
      expect(item.trackId, 42);
      expect(item.durationSeconds, 180);
      expect(item.creationDate.toUtc(), listened);
      expect(item.sourceDevice, 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
      expect(item.clientSessionId, isNull);

      final json = item.toJson();
      expect(json['track'], 42);
      expect(json['creation_date'], '2024-01-02T10:00:00.000Z');
      expect(json['duration_seconds'], 180);
      expect(json['source_device'], 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
      expect(json['client_session_id'], isNull);
    });
  });

  group('ListenHistoryImportService bulk import', () {
    late _FakeBackend fake;
    late ListenHistoryImportService service;

    setUp(() {
      fake = _FakeBackend();
      service = ListenHistoryImportService.forTest(fake.backend);
    });

    test('registers all device UUIDs then chunks bulk ≤500', () async {
      // 501 records so we need 2 bulk calls
      final records = List.generate(501, (i) {
        final device = i.isEven
            ? 'local'
            : '11111111-1111-4111-8111-1111111111${(i % 10)}0';
        return ListenRecord(
          trackId: i + 1,
          trackTitle: 'T$i',
          artistName: 'A',
          albumTitle: 'Al',
          durationSeconds: 10 + i,
          listenedAt: DateTime.utc(2024, 1, 1).add(Duration(seconds: i)),
          sourceDevice: device,
        );
      });
      fake.records = records;

      final result = await service.importLocalHistory();

      expect(fake.probeCalls, 1);
      // local + unique remote UUIDs from even/odd pattern
      expect(fake.upsertedUuids, contains('device-uuid'));
      expect(fake.upsertedUuids.length, greaterThan(1));
      expect(fake.bulkCalls, 2);
      expect(fake.bulkCallSizes, [500, 1]);
      expect(fake.bulkModes, everyElement('enrich_or_create'));
      // client_session_id is null on every item
      for (final items in fake.bulkItems) {
        for (final it in items) {
          expect(it.clientSessionId, isNull);
          expect(it.toJson().containsKey('creation_date'), isTrue);
        }
      }
      expect(result.created, 501);
      expect(fake.syncedThroughMs, greaterThan(0));
    });

    test(
      're-runnable: second import still calls bulk (server dedups)',
      () async {
        fake.records = [
          ListenRecord(
            trackId: 1,
            trackTitle: 'T',
            artistName: 'A',
            albumTitle: 'Al',
            durationSeconds: 60,
            listenedAt: DateTime.utc(2024, 6, 1),
            sourceDevice: 'local',
          ),
        ];
        fake.bulkResult = const BulkListeningResult(
          created: 1,
          enriched: 0,
          skippedDuplicate: 0,
        );
        await service.importLocalHistory();
        fake.bulkResult = const BulkListeningResult(
          created: 0,
          enriched: 0,
          skippedDuplicate: 1,
        );
        final second = await service.importLocalHistory();
        expect(fake.bulkCalls, 2);
        expect(second.skippedDuplicate, 1);
      },
    );

    test('unsupported server → no bulk', () async {
      fake.probeResult = false;
      fake.records = [
        ListenRecord(
          trackId: 1,
          trackTitle: 'T',
          artistName: 'A',
          albumTitle: 'Al',
          listenedAt: DateTime.utc(2024, 1, 1),
        ),
      ];
      final result = await service.importLocalHistory();
      expect(result.totalProcessed, 0);
      expect(fake.bulkCalls, 0);
      expect(fake.upsertedUuids, isEmpty);
    });

    test('catch-up only uploads after watermark', () async {
      final early = DateTime.utc(2024, 1, 1);
      final late = DateTime.utc(2024, 6, 1);
      fake.syncedThroughMs = early.millisecondsSinceEpoch;
      fake.afterRecords = [
        ListenRecord(
          trackId: 9,
          trackTitle: 'Late',
          artistName: 'A',
          albumTitle: 'Al',
          durationSeconds: 30,
          listenedAt: late,
          sourceDevice: 'local',
        ),
      ];

      final result = await service.catchUpIfNeeded();

      expect(fake.getListensAfterCalls, 1);
      expect(fake.lastAfterMs, early.millisecondsSinceEpoch);
      expect(fake.bulkCalls, 1);
      expect(fake.bulkItems.single.single.trackId, 9);
      expect(result.created, 1);
      expect(fake.syncedThroughMs, late.millisecondsSinceEpoch);
    });

    test('offline → skip catch-up', () async {
      fake.offline = true;
      fake.afterRecords = [
        ListenRecord(
          trackId: 1,
          trackTitle: 'T',
          artistName: 'A',
          albumTitle: 'Al',
          listenedAt: DateTime.utc(2024, 1, 1),
        ),
      ];
      final result = await service.catchUpIfNeeded();
      expect(result.totalProcessed, 0);
      expect(fake.bulkCalls, 0);
    });

    test('includeNextcloud calls loader before bulk', () async {
      var loaded = false;
      fake.loadNextcloud = () async {
        loaded = true;
        return 3;
      };
      fake.records = [
        ListenRecord(
          trackId: 1,
          trackTitle: 'T',
          artistName: 'A',
          albumTitle: 'Al',
          listenedAt: DateTime.utc(2024, 1, 1),
          sourceDevice: 'local',
        ),
      ];
      await service.importLocalHistory(includeNextcloud: true);
      expect(loaded, isTrue);
      expect(fake.bulkCalls, 1);
    });
  });

  group('BulkListeningResult', () {
    test('fromJson + operator +', () {
      final a = BulkListeningResult.fromJson({
        'created': 2,
        'enriched': 1,
        'skipped_duplicate': 3,
        'errors': [
          {'index': 0, 'code': 'track_not_found', 'detail': 'missing'},
        ],
      });
      final b = const BulkListeningResult(created: 1, enriched: 2);
      final sum = a + b;
      expect(sum.created, 3);
      expect(sum.enriched, 3);
      expect(sum.skippedDuplicate, 3);
      expect(sum.errors, hasLength(1));
      expect(sum.errors.single.code, 'track_not_found');
    });
  });
}

class _FakeBackend {
  bool probeResult = true;
  int probeCalls = 0;
  bool offline = false;
  bool authenticated = true;
  int syncedThroughMs = 0;
  int getListensAfterCalls = 0;
  int? lastAfterMs;

  List<ListenRecord> records = const [];
  List<ListenRecord> afterRecords = const [];
  BulkListeningResult bulkResult = const BulkListeningResult(created: 1);
  Future<int> Function()? loadNextcloud;

  final upsertedUuids = <String>[];
  int bulkCalls = 0;
  final bulkCallSizes = <int>[];
  final bulkModes = <String>[];
  final bulkItems = <List<BulkListeningItem>>[];

  late final ListenHistoryImportBackend backend = ListenHistoryImportBackend(
    probeClientDataSupport: () async {
      probeCalls++;
      return probeResult;
    },
    upsertClientDevice:
        ({
          required String uuid,
          required String name,
          String clientId = 'tayra',
          String? clientVersion,
        }) async {
          upsertedUuids.add(uuid);
        },
    bulkCreateListenings:
        ({
          required List<BulkListeningItem> items,
          String mode = 'enrich_or_create',
          int? dedupWindowSeconds,
        }) async {
          bulkCalls++;
          bulkCallSizes.add(items.length);
          bulkModes.add(mode);
          bulkItems.add(List.of(items));
          if (bulkResult.created == 1 && bulkResult.enriched == 0) {
            // Default: report all as created for this chunk size.
            return BulkListeningResult(created: items.length);
          }
          return bulkResult;
        },
    getDeviceUuid: () async => 'device-uuid',
    getDeviceName: () async => 'Test Device',
    getAllListens: () async => records,
    getListensAfter: (afterMs) async {
      getListensAfterCalls++;
      lastAfterMs = afterMs;
      return afterRecords;
    },
    getSyncedThroughMs: () async => syncedThroughMs,
    setSyncedThroughMs: (ms) async {
      syncedThroughMs = ms;
    },
    isAuthenticated: () => authenticated,
    isOffline: () => offline,
    loadNextcloudHistory: () async {
      final fn = loadNextcloud;
      if (fn == null) return 0;
      return fn();
    },
  );
}
