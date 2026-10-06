import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/cache/auto_offline_coordinator.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/features/favorites/favorites_provider.dart';

class _FakeApi implements CachedFunkwhaleApi {
  Set<int> cached = {};
  Set<int> server = {};

  /// Holds the full favorites fetch open until completed.
  Completer<void>? fetchGate;

  bool failWrites = false;

  @override
  bool get isOffline => false;

  @override
  Future<Set<int>> getCachedFavoriteTrackIds() async => {...cached};

  @override
  Future<Set<int>> getAllFavoriteTrackIds() async {
    // The snapshot is taken when the request is made, as on a real server.
    final snapshot = {...server};
    final gate = fetchGate;
    if (gate != null) await gate.future;
    return snapshot;
  }

  @override
  Future<int> syncPendingFavorites() async => 0;

  @override
  Future<void> addFavorite(int trackId) async {
    if (failWrites) throw StateError('refused');
    server.add(trackId);
  }

  @override
  Future<void> removeFavorite(int trackId) async {
    if (failWrites) throw StateError('refused');
    server.remove(trackId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoAutoOffline implements AutoOfflineCoordinator {
  @override
  Future<void> reconcileFavorites(Set<int> favoriteIds) async {}

  @override
  Future<void> onFavoriteAdded(int trackId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeApi api;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = _FakeApi();
    container = ProviderContainer(
      overrides: [
        cachedFunkwhaleApiProvider.overrideWithValue(api),
        autoOfflineCoordinatorProvider.overrideWithValue(_NoAutoOffline()),
        connectivityResultProvider.overrideWith(
          (ref) => Stream.value([ConnectivityResult.wifi]),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Set<int> favorites() => container.read(favoriteTrackIdsProvider);
  FavoriteTrackIdsNotifier notifier() =>
      container.read(favoriteTrackIdsProvider.notifier);

  test('loads the cached ids first, then the server list', () async {
    api
      ..cached = {1}
      ..server = {1, 2}
      ..fetchGate = Completer<void>();
    container.listen(favoriteTrackIdsProvider, (_, _) {});
    await _settle();
    expect(favorites(), {1});

    api.fetchGate!.complete();
    await _settle();
    expect(favorites(), {1, 2});
  });

  test('a heart tapped while the list is loading survives the load', () async {
    api
      ..cached = {1}
      ..server = {1}
      ..fetchGate = Completer<void>();
    container.listen(favoriteTrackIdsProvider, (_, _) {});
    await _settle();

    // The fetch already has its (older) answer when the user taps.
    await notifier().toggle(5);
    await notifier().toggle(1);
    expect(favorites(), {5});

    api.fetchGate!.complete();
    await _settle();

    expect(favorites(), {5}, reason: 'the stale snapshot must not undo taps');
  });

  test('a refused change is rolled back, also across a reload', () async {
    api
      ..cached = {1}
      ..server = {1}
      ..fetchGate = Completer<void>();
    container.listen(favoriteTrackIdsProvider, (_, _) {});
    await _settle();

    api.failWrites = true;
    await expectLater(notifier().toggle(5), throwsStateError);
    expect(favorites(), {1});

    api.fetchGate!.complete();
    await _settle();
    expect(favorites(), {1});
  });

  test('taps after the load are not replayed onto a later refresh', () async {
    api.server = {1};
    container.listen(favoriteTrackIdsProvider, (_, _) {});
    await _settle();
    await notifier().toggle(2);
    expect(favorites(), {1, 2});

    // Removed on another device; a refresh has to be able to show that.
    api.server = {1};
    await notifier().refresh();

    expect(favorites(), {1});
  });
}
