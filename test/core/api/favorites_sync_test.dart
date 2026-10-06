import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/cache/audio_cache_service.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/pending_favorite_ops.dart';

/// Server stand-in: favorites are a set, and each call can be scripted to
/// fail the way the real endpoint does.
class _FakeServer implements FunkwhaleApi {
  final Set<int> favorites = {};
  final List<String> calls = [];

  /// Track ids the server refuses to favorite (deleted tracks → 400).
  final Set<int> unknownTracks = {};

  /// When set, every call fails like a dropped connection.
  bool unreachable = false;

  /// When set, every call fails with this HTTP status.
  int? failWithStatus;

  DioException _error({int? status}) {
    final options = RequestOptions(path: '/api/v1/favorites/tracks/');
    return DioException(
      requestOptions: options,
      type:
          status == null
              ? DioExceptionType.connectionError
              : DioExceptionType.badResponse,
      response:
          status == null
              ? null
              : Response<dynamic>(requestOptions: options, statusCode: status),
    );
  }

  void _maybeFail() {
    if (unreachable) throw _error();
    final status = failWithStatus;
    if (status != null) throw _error(status: status);
  }

  @override
  Future<void> addFavorite(int trackId) async {
    calls.add('add:$trackId');
    _maybeFail();
    if (unknownTracks.contains(trackId)) throw _error(status: 400);
    favorites.add(trackId);
  }

  @override
  Future<void> removeFavorite(int trackId) async {
    calls.add('remove:$trackId');
    _maybeFail();
    // The real endpoint answers 400 when the track is not a favorite.
    if (!favorites.remove(trackId)) throw _error(status: 400);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory stand-in for the favorites table.
class _FakeCache implements CacheManager {
  final Set<int> favorites = {};

  @override
  Future<Set<int>> getFavorites() async => {...favorites};

  @override
  Future<void> addFavorite(int trackId) async => favorites.add(trackId);

  @override
  Future<void> removeFavorite(int trackId) async => favorites.remove(trackId);

  @override
  Future<void> setFavorites(Set<int> ids) async {
    favorites
      ..clear()
      ..addAll(ids);
  }

  @override
  Future<void> deleteMetadataLike(String likePattern) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoCovers implements AudioCacheService {
  @override
  Future<File?> cacheCoverArt(String coverUrl) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeServer server;
  late _FakeCache cache;
  late bool offline;
  late CachedFunkwhaleApi api;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = _FakeServer();
    cache = _FakeCache();
    offline = false;
    api = CachedFunkwhaleApi(
      server,
      cache,
      _NoCovers(),
      isOffline: () => offline,
    );
  });

  Future<List<int>> pendingIds() async =>
      (await PendingFavoriteOps.loadAll()).map((op) => op.trackId).toList();

  test('removing a favorite the server no longer has succeeds', () async {
    cache.favorites.add(7); // stale local copy; unfavorited on another device

    await api.removeFavorite(7);

    expect(cache.favorites, isEmpty);
    expect(await pendingIds(), isEmpty);
  });

  test('adding a track the server refuses is still an error', () async {
    server.unknownTracks.add(9);

    await expectLater(api.addFavorite(9), throwsA(isA<DioException>()));

    expect(cache.favorites, isEmpty);
    expect(await pendingIds(), isEmpty);
  });

  test('offline changes are queued and sent once back online', () async {
    server.favorites.add(2);
    cache.favorites.add(2);
    offline = true;

    await api.addFavorite(1);
    await api.removeFavorite(2);
    expect(server.calls, isEmpty);
    expect(cache.favorites, {1});
    expect(await pendingIds(), [1, 2]);

    offline = false;
    expect(await api.syncPendingFavorites(), 2);

    expect(server.favorites, {1});
    expect(await pendingIds(), isEmpty);
  });

  test(
    'a change the server rejects does not block the ones behind it',
    () async {
      offline = true;
      await api.addFavorite(1); // this track gets deleted before we sync
      await api.removeFavorite(2); // already unfavorited elsewhere
      await api.addFavorite(3);
      server.unknownTracks.add(1);
      offline = false;

      final handled = await api.syncPendingFavorites();

      expect(handled, 3);
      expect(server.calls, ['add:1', 'remove:2', 'add:3']);
      expect(server.favorites, {3});
      expect(cache.favorites, {3}, reason: 'the refused add is rolled back');
      expect(await pendingIds(), isEmpty);
    },
  );

  test('trouble reaching the server keeps everything queued', () async {
    offline = true;
    await api.addFavorite(1);
    await api.addFavorite(2);
    offline = false;

    for (final setup in <void Function()>[
      () => server.unreachable = true,
      () => server.failWithStatus = 503,
      () => server.failWithStatus = 429,
      () => server.failWithStatus = 401,
    ]) {
      server
        ..unreachable = false
        ..failWithStatus = null
        ..calls.clear();
      setup();

      expect(await api.syncPendingFavorites(), 0);
      expect(server.calls, ['add:1'], reason: 'stops at the first failure');
      expect(await pendingIds(), [1, 2]);
      expect(cache.favorites, {1, 2});
    }
  });
}
