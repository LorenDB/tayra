import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/cache/cache_database.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1),
    );
    CacheDatabase.instance.debugSetDatabase(db);
    await ListenHistoryService.ensureTable();
  });

  tearDown(() async {
    await db.close();
    CacheDatabase.instance.debugSetDatabase(null);
  });

  Track track(int id) => Track(
    id: id,
    title: 'T$id',
    artist: Artist(id: id, name: 'A$id'),
    album: Album(id: id, title: 'Al$id'),
    listenUrl: 'https://example.com/$id',
  );

  group('ListenHistoryService sync + retention', () {
    test('new inserts are pending until markListenSynced', () async {
      final id = await ListenHistoryService.insertListen(
        track(1),
        listenedSeconds: 30,
        listenedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(id, greaterThan(0));

      final pending = await ListenHistoryService.getPendingSyncListens(
        olderThan: DateTime.now(),
        limit: 10,
      );
      expect(pending, hasLength(1));
      expect(pending.single.id, id);
      expect(pending.single.isSynced, isFalse);

      await ListenHistoryService.markListenSynced(
        id,
        clientSessionId: '11111111-1111-4111-8111-111111111111',
        serverListeningId: 99,
      );

      final after = await ListenHistoryService.getPendingSyncListens(
        olderThan: DateTime.now(),
        limit: 10,
      );
      expect(after, isEmpty);
      expect(await ListenHistoryService.getPendingSyncCount(), 0);
    });

    test('pending skips recent rows when olderThan is in the past', () async {
      await ListenHistoryService.insertListen(
        track(2),
        listenedSeconds: 20,
        listenedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      );
      final pending = await ListenHistoryService.getPendingSyncListens(
        olderThan: DateTime.now().subtract(kListenHistorySyncGrace),
        limit: 10,
      );
      expect(pending, isEmpty);
    });

    test('purge only removes synced rows past cutoff', () async {
      final old = DateTime.now().subtract(const Duration(days: 40));
      final recent = DateTime.now().subtract(const Duration(days: 5));

      final oldSynced = await ListenHistoryService.insertListen(
        track(10),
        listenedSeconds: 40,
        listenedAt: old,
      );
      final oldPending = await ListenHistoryService.insertListen(
        track(11),
        listenedSeconds: 40,
        listenedAt: old,
      );
      final recentSynced = await ListenHistoryService.insertListen(
        track(12),
        listenedSeconds: 40,
        listenedAt: recent,
      );

      await ListenHistoryService.markListensSynced([oldSynced, recentSynced]);

      final purged = await ListenHistoryService.purgeSyncedPastRetention(
        retention: const Duration(days: 30),
      );
      expect(purged, 1);

      // old pending kept, recent synced kept
      expect(await ListenHistoryService.getPendingSyncCount(), 1);
      final years = await ListenHistoryService.getAvailableYears();
      expect(years, isNotEmpty);

      final all = await ListenHistoryService.getAllListens();
      final ids = all.map((r) => r.id).toSet();
      expect(ids.contains(oldSynced), isFalse);
      expect(ids.contains(oldPending), isTrue);
      expect(ids.contains(recentSynced), isTrue);
    });

    test('ensureClientSessionId is stable across calls', () async {
      final id = await ListenHistoryService.insertListen(
        track(3),
        listenedSeconds: 10,
        listenedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      final a = await ListenHistoryService.ensureClientSessionId(id);
      final b = await ListenHistoryService.ensureClientSessionId(id);
      expect(a, isNotNull);
      expect(a, b);
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(a!),
        isTrue,
      );
    });

    test('backup export strips sync bookkeeping', () {
      final rec = ListenRecord(
        id: 5,
        trackId: 1,
        trackTitle: 'T',
        artistName: 'A',
        albumTitle: 'Al',
        durationSeconds: 10,
        listenedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        sourceDevice: 'local',
        syncedAt: DateTime.fromMillisecondsSinceEpoch(2000),
        clientSessionId: 'sess',
        serverListeningId: 7,
      );
      final map = rec.toMapForBackup();
      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('source_device'), isFalse);
      expect(map.containsKey('synced_at'), isFalse);
      expect(map.containsKey('client_session_id'), isFalse);
      expect(map.containsKey('server_listening_id'), isFalse);
      expect(map['track_id'], 1);
    });
  });
}
