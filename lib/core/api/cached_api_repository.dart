import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/api_client.dart';
import 'package:tayra/core/api/api_repository.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/cache/audio_cache_service.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/cache/pending_favorite_ops.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';

// Re-export types so consumers only need to import cached_api_repository.dart
export 'package:tayra/core/api/api_repository.dart'
    show funkwhaleApiProvider, FunkwhaleApi;
export 'package:tayra/core/api/api_client.dart' show PaginatedResponse;
export 'package:tayra/core/api/models.dart';

/// Thrown when a metadata key is not available in the local cache while offline.
class OfflineCacheMissException implements Exception {
  final String cacheKey;

  OfflineCacheMissException(this.cacheKey);

  @override
  String toString() => 'Not available offline';
}

/// Cached API repository that wraps FunkwhaleApi with caching layer.
///
/// Strategy for reads (stale-while-revalidate):
///  1. If offline (or force-offline), serve any cached entry immediately
///     (ignoring TTL) and never dial the network.
///  2. If online and any cache entry exists (fresh *or* expired), return it
///     immediately so the UI never waits on the network when we have data.
///  3. Simultaneously revalidate in the background when connected. On
///     success the cache is updated; if the payload changed, [metadataUpdates]
///     emits the cache key so Riverpod providers / screens can insert/remove
///     items without a full-screen reload.
///  4. On a cold cache miss, wait for the network. If the network fails,
///     rethrow (no data to show).
///  5. [forceRefresh] still blocks on the network (pull-to-refresh).
class CachedFunkwhaleApi {
  final FunkwhaleApi _api;
  final CacheManager _cache;
  final AudioCacheService _audioCache;

  /// Returns true when the app should not hit the network (no connectivity or
  /// forced offline mode). Injected so unit tests can override it.
  final bool Function() _isOffline;

  /// Broadcast stream of metadata cache keys that were revalidated with a
  /// *different* payload. Listeners should re-read the key (or invalidate
  /// their Riverpod provider) so the UI inserts/removes items.
  final StreamController<String> _metadataUpdates =
      StreamController<String>.broadcast();

  /// In-flight background revalidations, keyed by cache key.
  final Map<String, Future<void>> _inFlightRevalidations = {};

  /// Last successful network write time per key — used to debounce soft
  /// revalidation so invalidate→reload loops cannot thrash the API.
  final Map<String, DateTime> _lastNetworkSuccess = {};

  /// Minimum gap between background revalidations of the same key.
  static const Duration _minRevalidateInterval = Duration(seconds: 20);

  CachedFunkwhaleApi(
    this._api,
    this._cache,
    this._audioCache, {
    bool Function()? isOffline,
  }) : _isOffline = isOffline ?? (() => false);

  bool get isOffline => _isOffline();

  /// Emits cache keys whose metadata changed after a background revalidate.
  Stream<String> get metadataUpdates => _metadataUpdates.stream;

  // ── Generic cache-or-fetch helpers ──────────────────────────────────

  /// Try to serve [cacheKey] from the metadata cache. Returns `null` on miss
  /// or parse error.  Does NOT respect TTL – caller decides whether to also
  /// hit the network.
  Future<T?> _tryCache<T>(
    String cacheKey,
    T Function(Map<String, dynamic>) fromJson, {
    bool allowStale = false,
  }) async {
    final cached =
        allowStale
            ? await _cache.getMetadataStale(cacheKey)
            : await _cache.getMetadata(cacheKey);
    if (cached == null) return null;
    try {
      return fromJson(cached);
    } catch (_) {
      return null;
    }
  }

  /// Random-ordered list keys reshuffle on every network hit; soft-revalidating
  /// them would constantly reorder carousels. Only revalidate when stale.
  static bool _isRandomListKey(String cacheKey) =>
      cacheKey.contains('_orandom');

  /// Generic cache-or-fetch with stale-while-revalidate.
  Future<T> _cachedFetch<T>({
    required String cacheKey,
    required CacheType cacheType,
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(T) toJson,
    required Future<T> Function() fetch,
    required Duration ttl,
    bool forceRefresh = false,
    List<String?> Function(T)? coverUrls,
  }) async {
    // Offline / force-offline: never dial the network. Serve any cached
    // entry (fresh or expired) immediately so cold boot doesn't wait on
    // connectTimeout.
    if (_isOffline()) {
      final offlineHit = await _tryCache(cacheKey, fromJson, allowStale: true);
      if (offlineHit != null) return offlineHit;
      throw OfflineCacheMissException(cacheKey);
    }

    if (!forceRefresh) {
      // Prefer a non-expired entry, but fall back to expired (stale) so the
      // UI paints immediately while we revalidate in the background.
      final fresh = await _tryCache(cacheKey, fromJson, allowStale: false);
      if (fresh != null) {
        // Soft revalidate while data is still "fresh" so lists stay current
        // without blocking first paint. Skip pure-random lists (see above).
        if (!_isRandomListKey(cacheKey)) {
          _scheduleBackgroundRevalidate(
            cacheKey: cacheKey,
            cacheType: cacheType,
            fromJson: fromJson,
            toJson: toJson,
            fetch: fetch,
            ttl: ttl,
            previous: fresh,
            coverUrls: coverUrls,
          );
        }
        return fresh;
      }

      final stale = await _tryCache(cacheKey, fromJson, allowStale: true);
      if (stale != null) {
        // Expired cache: show it now, always refresh in the background.
        _scheduleBackgroundRevalidate(
          cacheKey: cacheKey,
          cacheType: cacheType,
          fromJson: fromJson,
          toJson: toJson,
          fetch: fetch,
          ttl: ttl,
          previous: stale,
          coverUrls: coverUrls,
        );
        return stale;
      }
    }

    // Cold miss, or forceRefresh: wait for the network.
    return _fetchAndStore(
      cacheKey: cacheKey,
      cacheType: cacheType,
      fromJson: fromJson,
      toJson: toJson,
      fetch: fetch,
      ttl: ttl,
      coverUrls: coverUrls,
    );
  }

  /// Blocking network fetch that updates the metadata cache on success and
  /// falls back to any stale cache entry on failure.
  Future<T> _fetchAndStore<T>({
    required String cacheKey,
    required CacheType cacheType,
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(T) toJson,
    required Future<T> Function() fetch,
    required Duration ttl,
    List<String?> Function(T)? coverUrls,
  }) async {
    try {
      final result = await fetch();
      _lastNetworkSuccess[cacheKey] = DateTime.now();
      try {
        await _cache.putMetadata(cacheKey, cacheType, toJson(result), ttl: ttl);
      } catch (e) {
        debugPrint('Cache: failed to write metadata for $cacheKey: $e');
      }
      if (coverUrls != null) {
        _scheduleCoverCaching(coverUrls(result));
      }
      return result;
    } catch (_) {
      final stale = await _cache.getMetadataStale(cacheKey);
      if (stale != null) {
        try {
          return fromJson(stale);
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Fire-and-forget revalidation. Dedupes in-flight work and debounces
  /// repeats so provider invalidate loops cannot hammer the server.
  void _scheduleBackgroundRevalidate<T>({
    required String cacheKey,
    required CacheType cacheType,
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(T) toJson,
    required Future<T> Function() fetch,
    required Duration ttl,
    required T previous,
    List<String?> Function(T)? coverUrls,
  }) {
    if (_isOffline()) return;
    if (_inFlightRevalidations.containsKey(cacheKey)) return;

    final last = _lastNetworkSuccess[cacheKey];
    if (last != null &&
        DateTime.now().difference(last) < _minRevalidateInterval) {
      return;
    }

    final future = _runBackgroundRevalidate(
      cacheKey: cacheKey,
      cacheType: cacheType,
      fromJson: fromJson,
      toJson: toJson,
      fetch: fetch,
      ttl: ttl,
      previous: previous,
      coverUrls: coverUrls,
    );
    _inFlightRevalidations[cacheKey] = future;
    unawaited(
      future.whenComplete(() {
        _inFlightRevalidations.remove(cacheKey);
      }),
    );
  }

  Future<void> _runBackgroundRevalidate<T>({
    required String cacheKey,
    required CacheType cacheType,
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(T) toJson,
    required Future<T> Function() fetch,
    required Duration ttl,
    required T previous,
    List<String?> Function(T)? coverUrls,
  }) async {
    try {
      final result = await fetch();
      if (_isOffline()) return;

      final newJson = toJson(result);
      final oldJson = toJson(previous);
      final changed = !_jsonMapsEqual(oldJson, newJson);

      try {
        await _cache.putMetadata(cacheKey, cacheType, newJson, ttl: ttl);
      } catch (e) {
        debugPrint('Cache: failed to write metadata for $cacheKey: $e');
      }
      _lastNetworkSuccess[cacheKey] = DateTime.now();

      if (coverUrls != null) {
        _scheduleCoverCaching(coverUrls(result));
      }

      if (changed && !_metadataUpdates.isClosed) {
        _metadataUpdates.add(cacheKey);
      }
    } catch (e) {
      // Silent: the UI already has cached data. Next open will retry.
      debugPrint('Cache: background revalidate failed for $cacheKey: $e');
    }
  }

  /// Structural equality for JSON-like maps/lists used for change detection.
  static bool _jsonMapsEqual(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key)) return false;
        if (!_jsonMapsEqual(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_jsonMapsEqual(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  /// Kick off background cover-art downloads for a list of URLs (nulls ignored).
  void _scheduleCoverCaching(List<String?> urls) {
    for (final url in urls) {
      if (url != null && url.isNotEmpty) {
        _audioCache.cacheCoverArt(url).catchError((Object e) {
          debugPrint('CachedFunkwhaleApi: cover art cache failed for $url: $e');
          return null;
        });
      }
    }
  }

  // ── Albums ──────────────────────────────────────────────────────────

  Future<PaginatedResponse<Album>> getAlbums({
    int page = 1,
    int pageSize = 20,
    String ordering = '-creation_date',
    int? artist,
    String? scope,
    String? q,
    List<String>? tag,
    int? minDuration,
    int? maxDuration,
    String? library,
    bool forceRefresh = false,
  }) async {
    final tagSuffix =
        (tag != null && tag.isNotEmpty) ? '_t${tag.join(',')}' : '';
    final durationSuffix = '_dmin${minDuration}_dmax$maxDuration';
    final librarySuffix = library != null ? '_lib$library' : '';
    final baseSuffix =
        '_s${pageSize}_o${ordering}_a${artist}_sc${scope}_q$q$tagSuffix$durationSuffix$librarySuffix';
    final cacheKey = 'albums_p$page$baseSuffix';

    return _cachedFetch(
      cacheKey: cacheKey,
      cacheType: CacheType.recentAlbums,
      fromJson: (j) => PaginatedResponse.fromJson(j, Album.fromJson),
      toJson: (r) => _paginatedResponseToJson(r, _albumToJson),
      fetch:
          () => _api.getAlbums(
            page: page,
            pageSize: pageSize,
            ordering: ordering,
            artist: artist,
            scope: scope,
            q: q,
            tag: tag,
            minDuration: minDuration,
            maxDuration: maxDuration,
            library: library,
          ),
      ttl: const Duration(hours: 1),
      forceRefresh: forceRefresh,
      // List pages: rely on CachedNetworkImage; don't fan out cover downloads.
    );
  }

  Future<Album> getAlbum(int id, {bool forceRefresh = false}) async {
    return _cachedFetch(
      cacheKey: 'album_$id',
      cacheType: CacheType.album,
      fromJson: Album.fromJson,
      toJson: _albumToJson,
      fetch: () => _api.getAlbum(id),
      ttl: const Duration(hours: 24),
      forceRefresh: forceRefresh,
      coverUrls:
          (a) => [
            a.coverUrl,
            a.largeCoverUrl,
            a.artist?.coverUrl,
            ...a.tracks.map((t) => t.coverUrl),
          ],
    );
  }

  Future<void> createAlbumMutation(int id, Map<String, dynamic> payload) async {
    await _api.createAlbumMutation(id, payload);
    await _cache.deleteMetadata('album_$id');
  }

  // ── Artists ─────────────────────────────────────────────────────────

  Future<PaginatedResponse<Artist>> getArtists({
    int page = 1,
    int pageSize = 20,
    String ordering = 'name',
    bool? hasAlbums,
    String? scope,
    String? q,
    bool forceRefresh = false,
  }) async {
    final baseSuffix =
        '_s${pageSize}_o${ordering}_h${hasAlbums}_sc${scope}_q$q';
    final cacheKey = 'artists_p$page$baseSuffix';

    // Cache all pages so offline browsing beyond page 1 is possible. Rely on
    // CacheManager's eviction policy to bound storage.

    return _cachedFetch(
      cacheKey: cacheKey,
      cacheType: CacheType.recentArtists,
      fromJson: (j) => PaginatedResponse.fromJson(j, Artist.fromJson),
      toJson: (r) => _paginatedResponseToJson(r, _artistToJson),
      fetch:
          () => _api.getArtists(
            page: page,
            pageSize: pageSize,
            ordering: ordering,
            hasAlbums: hasAlbums,
            scope: scope,
            q: q,
          ),
      ttl: const Duration(hours: 1),
      forceRefresh: forceRefresh,
    );
  }

  Future<Artist> getArtist(int id, {bool forceRefresh = false}) async {
    return _cachedFetch(
      cacheKey: 'artist_$id',
      cacheType: CacheType.artist,
      fromJson: Artist.fromJson,
      toJson: _artistToJson,
      fetch: () => _api.getArtist(id),
      ttl: const Duration(hours: 24),
      forceRefresh: forceRefresh,
      coverUrls: (a) => [a.coverUrl, ...a.albums.map((al) => al.coverUrl)],
    );
  }

  // ── Tracks ──────────────────────────────────────────────────────────

  Future<PaginatedResponse<Track>> getTracks({
    int page = 1,
    int pageSize = 20,
    String ordering = '-creation_date',
    int? album,
    int? artist,
    String? scope,
    String? q,
    bool forceRefresh = false,
  }) async {
    final baseSuffix =
        '_s${pageSize}_o${ordering}_al${album}_ar${artist}_sc${scope}_q$q';
    final cacheKey = 'tracks_p$page$baseSuffix';

    // Cache all pages so offline browsing beyond page 1 is possible. Rely on
    // CacheManager's eviction policy to bound storage.

    return _cachedFetch(
      cacheKey: cacheKey,
      cacheType: CacheType.track,
      fromJson: (j) => PaginatedResponse.fromJson(j, Track.fromJson),
      toJson: (r) => _paginatedResponseToJson(r, _trackToJson),
      fetch:
          () => _api.getTracks(
            page: page,
            pageSize: pageSize,
            ordering: ordering,
            album: album,
            artist: artist,
            scope: scope,
            q: q,
          ),
      ttl: const Duration(hours: 1),
      forceRefresh: forceRefresh,
    );
  }

  Future<Track> getTrack(int id, {bool forceRefresh = false}) async {
    return _cachedFetch(
      cacheKey: 'track_$id',
      cacheType: CacheType.track,
      fromJson: Track.fromJson,
      toJson: _trackToJson,
      fetch: () => _api.getTrack(id),
      ttl: const Duration(hours: 24),
      forceRefresh: forceRefresh,
      coverUrls: (t) => [t.coverUrl],
    );
  }

  // ── Tags ────────────────────────────────────────────────────────────

  Future<PaginatedResponse<Tag>> getTags({
    int page = 1,
    int pageSize = 100,
    String ordering = 'name',
    String? q,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'tags_p${page}_s${pageSize}_o${ordering}_q$q';
    return _cachedFetch(
      cacheKey: cacheKey,
      cacheType: CacheType.tags,
      fromJson: (j) => PaginatedResponse.fromJson(j, Tag.fromJson),
      toJson: (r) => _paginatedResponseToJson(r, _tagToJson),
      fetch:
          () => _api.getTags(
            page: page,
            pageSize: pageSize,
            ordering: ordering,
            q: q,
          ),
      ttl: const Duration(hours: 6),
      forceRefresh: forceRefresh,
    );
  }

  // ── Search ──────────────────────────────────────────────────────────

  Future<SearchResult> search(String query, {bool forceRefresh = false}) async {
    return _cachedFetch(
      cacheKey: 'search_$query',
      cacheType: CacheType.searchResults,
      fromJson: SearchResult.fromJson,
      toJson: _searchResultToJson,
      fetch: () => _api.search(query),
      ttl: const Duration(minutes: 10),
      forceRefresh: forceRefresh,
      coverUrls:
          (r) => [
            ...r.albums.map((a) => a.coverUrl),
            ...r.artists.map((a) => a.coverUrl),
            ...r.tracks.map((t) => t.coverUrl),
          ],
    );
  }

  // ── Favorites ───────────────────────────────────────────────────────

  Future<PaginatedResponse<Favorite>> getFavorites({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    final baseSuffix = '_s$pageSize';
    final cacheKey = 'favorites_p$page$baseSuffix';

    // Cache all pages so offline browsing beyond page 1 is possible. Rely on
    // CacheManager's eviction policy to bound storage.

    return _cachedFetch(
      cacheKey: cacheKey,
      cacheType: CacheType.track, // reuse type for favorites list
      fromJson: (j) => PaginatedResponse.fromJson(j, Favorite.fromJson),
      toJson: (r) => _paginatedResponseToJson(r, _favoriteToJson),
      fetch: () => _api.getFavorites(page: page, pageSize: pageSize),
      ttl: const Duration(hours: 1),
      forceRefresh: forceRefresh,
    );
  }

  Future<Set<int>> getCachedFavoriteTrackIds() async {
    try {
      return await _mergePendingIntoFavorites(await _cache.getFavorites());
    } catch (_) {
      return {};
    }
  }

  Future<Set<int>> getAllFavoriteTrackIds() async {
    if (_isOffline()) {
      return await _mergePendingIntoFavorites(await _cache.getFavorites());
    }
    try {
      final ids = await _api.getAllFavoriteTrackIds();
      // Merge offline/pending mutations so a refresh cannot wipe hearts the
      // user toggled while offline before syncPendingFavorites runs.
      final merged = await _mergePendingIntoFavorites(ids);
      // Atomically replace cached favorites in a single transaction so
      // concurrent reads never see a partially-cleared set.
      await _cache.setFavorites(merged);
      return merged;
    } catch (_) {
      // Offline fallback – return whatever we have cached (+ pending)
      try {
        return await _mergePendingIntoFavorites(await _cache.getFavorites());
      } catch (_) {}
      rethrow;
    }
  }

  /// Apply [PendingFavoriteOps] on top of a favorite ID set.
  Future<Set<int>> _mergePendingIntoFavorites(Set<int> base) async {
    final pending = await PendingFavoriteOps.loadAll();
    if (pending.isEmpty) return base;
    final merged = Set<int>.from(base);
    for (final op in pending) {
      if (op.add) {
        merged.add(op.trackId);
      } else {
        merged.remove(op.trackId);
      }
    }
    return merged;
  }

  Future<void> addFavorite(int trackId) async {
    if (_isOffline()) {
      await _applyFavoriteLocally(trackId, add: true);
      await PendingFavoriteOps.enqueue(trackId: trackId, add: true);
      return;
    }
    try {
      await _api.addFavorite(trackId);
      await _applyFavoriteLocally(trackId, add: true);
      // Drop any stale pending op for this track after a successful write.
      await PendingFavoriteOps.remove(trackId);
    } on DioException catch (e) {
      if (_isNetworkFailure(e)) {
        await _applyFavoriteLocally(trackId, add: true);
        await PendingFavoriteOps.enqueue(trackId: trackId, add: true);
        return;
      }
      rethrow;
    }
  }

  Future<void> removeFavorite(int trackId) async {
    if (_isOffline()) {
      await _applyFavoriteLocally(trackId, add: false);
      await PendingFavoriteOps.enqueue(trackId: trackId, add: false);
      return;
    }
    try {
      await _api.removeFavorite(trackId);
      await _applyFavoriteLocally(trackId, add: false);
      await PendingFavoriteOps.remove(trackId);
    } on DioException catch (e) {
      if (_isNetworkFailure(e)) {
        await _applyFavoriteLocally(trackId, add: false);
        await PendingFavoriteOps.enqueue(trackId: trackId, add: false);
        return;
      }
      rethrow;
    }
  }

  Future<void> _applyFavoriteLocally(int trackId, {required bool add}) async {
    if (add) {
      await _cache.addFavorite(trackId);
    } else {
      await _cache.removeFavorite(trackId);
    }
    // Invalidate paginated favorites list so the next getFavorites() call
    // does not serve a page that is out of date with the local set.
    await _cache.deleteMetadataLike('favorites_p%');
  }

  static bool _isNetworkFailure(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown;
  }

  /// Flush any favorite mutations that were queued while offline.
  ///
  /// Returns the number of ops successfully synced. Stops on the first
  /// hard failure so remaining ops are retried later.
  Future<int> syncPendingFavorites() async {
    if (_isOffline()) return 0;
    final ops = await PendingFavoriteOps.loadAll();
    if (ops.isEmpty) return 0;

    var synced = 0;
    for (final op in ops) {
      try {
        if (op.add) {
          await _api.addFavorite(op.trackId);
          await _cache.addFavorite(op.trackId);
        } else {
          await _api.removeFavorite(op.trackId);
          await _cache.removeFavorite(op.trackId);
        }
        await PendingFavoriteOps.remove(op.trackId);
        synced++;
      } catch (e) {
        debugPrint(
          'CachedFunkwhaleApi: pending favorite sync failed for '
          '${op.trackId}: $e',
        );
        // Keep the op for a later attempt.
        break;
      }
    }
    if (synced > 0) {
      await _cache.deleteMetadataLike('favorites_p%');
    }
    return synced;
  }

  // ── Playlists ───────────────────────────────────────────────────────

  Future<PaginatedResponse<Playlist>> getPlaylists({
    int page = 1,
    int pageSize = 20,
    String? scope,
    bool forceRefresh = false,
  }) async {
    final baseSuffix = '_s${pageSize}_sc$scope';
    final cacheKey = 'playlists_p$page$baseSuffix';

    // Cache all pages so offline browsing beyond page 1 is possible. Rely on
    // CacheManager's eviction policy to bound storage.

    return _cachedFetch(
      cacheKey: cacheKey,
      cacheType: CacheType.playlist,
      fromJson: (j) => PaginatedResponse.fromJson(j, Playlist.fromJson),
      toJson: (r) => _paginatedResponseToJson(r, _playlistToJson),
      fetch:
          () => _api.getPlaylists(page: page, pageSize: pageSize, scope: scope),
      ttl: const Duration(hours: 1),
      forceRefresh: forceRefresh,
      coverUrls:
          (r) =>
              r.results
                  .expand((p) => <String?>[p.coverUrl, ...p.albumCovers])
                  .toList(),
    );
  }

  Future<Playlist> getPlaylist(int id, {bool forceRefresh = false}) async {
    return _cachedFetch(
      cacheKey: 'playlist_$id',
      cacheType: CacheType.playlist,
      fromJson: Playlist.fromJson,
      toJson: _playlistToJson,
      fetch: () => _api.getPlaylist(id),
      ttl: const Duration(hours: 1),
      forceRefresh: forceRefresh,
      coverUrls: (p) => <String?>[p.coverUrl, ...p.albumCovers],
    );
  }

  /// Patch a playlist (rename, cover, etc.) and update cached metadata
  /// in-place so list/detail UIs refresh without a manual pull-to-refresh.
  Future<Playlist> patchPlaylist(int id, Map<String, dynamic> body) async {
    final res = await _api.patchPlaylist(id, body);
    // Directly cache the API response so the UI sees the new name/covers
    // immediately on the next read without a network round trip.
    await _cache.putMetadata(
      'playlist_$id',
      CacheType.playlist,
      _playlistToJson(res),
      ttl: const Duration(hours: 1),
    );
    _emitMetadataUpdate('playlist_$id');
    // Also rewrite any cached list pages that include this playlist — list
    // keys use a different pageSize than a naive refetch and would otherwise
    // keep serving the pre-edit cover until a cold restart.
    await _upsertInPaginatedCaches(
      keyLike: 'playlists_p%',
      cacheType: CacheType.playlist,
      id: id,
      itemJson: _playlistToJson(res),
    );
    _scheduleCoverCaching(<String?>[res.customCoverUrl, ...res.albumCovers]);
    unawaited(refetchPlaylistsAfterWrite());
    return res;
  }

  // Helper to refresh playlists list cache after a write operation.
  //
  // Must match [playlistsProvider] (pageSize 50, scope me) so the same cache
  // keys the list reads are updated. Emits [metadataUpdates] after each page
  // so Riverpod re-reads without a full app restart.
  Future<void> refetchPlaylistsAfterWrite() async {
    try {
      var page = 1;
      // Safety cap — extremely large libraries still get page 1 updated.
      while (page <= 20) {
        final res = await getPlaylists(
          page: page,
          pageSize: 50,
          scope: 'me',
          forceRefresh: true,
        );
        _emitMetadataUpdate('playlists_p${page}_s50_scme');
        if (res.next == null || res.results.isEmpty) break;
        page++;
      }
    } catch (_) {}
  }

  void _emitMetadataUpdate(String key) {
    if (!_metadataUpdates.isClosed) {
      _metadataUpdates.add(key);
    }
  }

  /// Replace an entity (by `id`) inside every cached paginated list matching
  /// [keyLike], then notify listeners so UIs pick up cover/name changes.
  ///
  /// Returns true when at least one cached page was rewritten.
  Future<bool> _upsertInPaginatedCaches({
    required String keyLike,
    required CacheType cacheType,
    required int id,
    required Map<String, dynamic> itemJson,
  }) async {
    final keys = await _cache.listMetadataKeysLike(keyLike);
    var any = false;
    for (final key in keys) {
      try {
        final cached = await _cache.getMetadataStale(key);
        if (cached == null) continue;
        final results = cached['results'];
        if (results is! List) continue;
        var changed = false;
        final nextResults = <dynamic>[];
        for (final item in results) {
          if (item is Map && (item['id'] as num?)?.toInt() == id) {
            nextResults.add(itemJson);
            changed = true;
          } else {
            nextResults.add(item);
          }
        }
        if (!changed) continue;
        any = true;
        final updated = Map<String, dynamic>.from(cached);
        updated['results'] = nextResults;
        await _cache.putMetadata(
          key,
          cacheType,
          updated,
          ttl: const Duration(hours: 1),
        );
        _emitMetadataUpdate(key);
      } catch (e) {
        debugPrint('Cache: failed to upsert $id into $key: $e');
      }
    }
    return any;
  }

  Future<PaginatedResponse<PlaylistTrack>> getPlaylistTracks(
    int id, {
    int page = 1,
    int pageSize = 50,
    bool forceRefresh = false,
  }) async {
    final baseSuffix = '_s$pageSize';
    final cacheKey = 'playlist_tracks_${id}_p$page$baseSuffix';

    // Cache all pages so offline browsing beyond page 1 is possible. Rely on
    // CacheManager's eviction policy to bound storage.

    return _cachedFetch(
      cacheKey: cacheKey,
      cacheType: CacheType.playlist,
      fromJson: (j) => PaginatedResponse.fromJson(j, PlaylistTrack.fromJson),
      toJson: (r) => _paginatedResponseToJson(r, _playlistTrackToJson),
      fetch: () => _api.getPlaylistTracks(id, page: page, pageSize: pageSize),
      ttl: const Duration(hours: 1),
      forceRefresh: forceRefresh,
    );
  }

  // ── Listenings ──────────────────────────────────────────────────────

  Future<PaginatedResponse<Listening>> getListenings({
    int page = 1,
    int pageSize = 20,
    String ordering = '-creation_date',
    bool richOnly = false,
    bool forceRefresh = false,
  }) async {
    final baseSuffix = '_s${pageSize}_o$ordering${richOnly ? '_rich' : '_all'}';
    final cacheKey = 'listenings_p$page$baseSuffix';

    // Cache all pages so offline browsing beyond page 1 is possible. Rely on
    // CacheManager's eviction policy to bound storage.

    return _cachedFetch(
      cacheKey: cacheKey,
      cacheType: CacheType.track,
      fromJson:
          (j) => PaginatedResponse.fromJson(
            j,
            Listening.fromJson,
            skipMalformed: true,
          ),
      toJson: (r) => _paginatedResponseToJson(r, _listeningToJson),
      fetch:
          () => _api.getListenings(
            page: page,
            pageSize: pageSize,
            ordering: ordering,
            richOnly: richOnly,
          ),
      ttl: const Duration(hours: 1),
      forceRefresh: forceRefresh,
    );
  }

  /// Update the cached Playlist metadata in-place after a successful mutation
  /// so the next read from cache shows the fresh data immediately.
  Future<void> _updatePlaylistCache({
    required int playlistId,
    int? tracksCountDelta,
    int? tracksCount,
    int? duration,
  }) async {
    try {
      final cacheKey = 'playlist_$playlistId';
      final cached = await _cache.getMetadataStale(cacheKey);
      if (cached == null) return;
      final playlist = Playlist.fromJson(cached);
      final newCount =
          tracksCount ??
          (tracksCountDelta != null
              ? playlist.tracksCount + tracksCountDelta
              : playlist.tracksCount);
      final updated = Playlist(
        id: playlist.id,
        name: playlist.name,
        tracksCount: newCount < 0 ? 0 : newCount,
        duration: duration ?? playlist.duration,
        isPlayable: playlist.isPlayable,
        albumCovers: playlist.albumCovers,
        cover: playlist.cover,
        privacyLevel: playlist.privacyLevel,
        creationDate: playlist.creationDate,
        modificationDate: DateTime.now(),
      );
      await _cache.putMetadata(
        cacheKey,
        CacheType.playlist,
        _playlistToJson(updated),
        ttl: const Duration(hours: 1),
      );
    } catch (_) {
      // Best-effort — a cache miss is harmless; next read fetches from network.
    }
  }

  // ── Write operations (pass-through, invalidate cache) ───────────────

  Future<Playlist> createPlaylist({
    required String name,
    String privacyLevel = 'me',
    String? coverUuid,
  }) async {
    final result = await _api.createPlaylist(
      name: name,
      privacyLevel: privacyLevel,
      coverUuid: coverUuid,
    );
    unawaited(refetchPlaylistsAfterWrite());
    return result;
  }

  /// Upload an image attachment used as playlist/radio cover art.
  Future<Cover> createAttachment({
    required List<int> bytes,
    required String fileName,
  }) async {
    return _api.createAttachment(bytes: bytes, fileName: fileName);
  }

  Future<Radio> patchRadio(int id, Map<String, dynamic> body) async {
    final res = await _api.patchRadio(id, body);
    // Rewrite list pages in place so cover art updates without a restart.
    final upserted = await _upsertInPaginatedCaches(
      keyLike: 'radios_p%',
      cacheType: CacheType.radio,
      id: id,
      itemJson: _radioToJson(res),
    );
    if (!upserted) {
      // Radio wasn't in any cached page — drop list caches and notify so the
      // radios screen reloads from the network.
      await _cache.deleteMetadataLike('radios_p%');
      _emitMetadataUpdate('radios_p1');
    }
    _scheduleCoverCaching(<String?>[res.coverUrl]);
    return res;
  }

  Future<void> addTracksToPlaylist(int playlistId, List<int> trackIds) async {
    await _api.addTracksToPlaylist(playlistId, trackIds);
    // Increment cached track count so the list/detail screens show the new
    // count immediately without a network round trip.
    await _updatePlaylistCache(
      playlistId: playlistId,
      tracksCountDelta: trackIds.length,
    );
    // Invalidate all track page caches for this playlist.
    await _cache.deleteMetadataLike('playlist_tracks_${playlistId}_p%');
    unawaited(refetchPlaylistsAfterWrite());
  }

  Future<void> removeTrackFromPlaylist(int playlistId, int index) async {
    await _api.removeTrackFromPlaylist(playlistId, index);
    // Decrement cached track count so the list/detail screens show the
    // updated count immediately.
    await _updatePlaylistCache(playlistId: playlistId, tracksCountDelta: -1);
    // Invalidate all track page caches for this playlist.
    await _cache.deleteMetadataLike('playlist_tracks_${playlistId}_p%');
    unawaited(refetchPlaylistsAfterWrite());
  }

  Future<void> deletePlaylist(int id) async {
    await _api.deletePlaylist(id);
    await _cache.deleteMetadata('playlist_$id');
    unawaited(refetchPlaylistsAfterWrite());
  }

  /// Remove all tracks from a playlist and invalidate track caches.
  Future<void> clearPlaylist(int id) async {
    await _api.clearPlaylist(id);
    // Reset cached track count and duration to zero so the list/detail screens
    // show the empty state immediately.
    await _updatePlaylistCache(playlistId: id, tracksCount: 0, duration: 0);
    // Invalidate all track page caches for this playlist.
    await _cache.deleteMetadataLike('playlist_tracks_${id}_p%');
    unawaited(refetchPlaylistsAfterWrite());
  }

  /// Move a track in a playlist and invalidate track order caches.
  Future<void> moveTrackInPlaylist(
    int playlistId,
    int index,
    int newIndex,
  ) async {
    await _api.moveTrackInPlaylist(playlistId, index, newIndex);
    // Invalidate all track page caches for this playlist.
    await _cache.deleteMetadataLike('playlist_tracks_${playlistId}_p%');
    // Refresh the playlist list cache so modification_date updates.
    unawaited(refetchPlaylistsAfterWrite());
  }

  /// Invalidate all cached track and album list pages. Call this after a
  /// successful upload so browse screens show the newly imported content.
  Future<void> invalidateTrackAndAlbumCaches() async {
    await _cache.deleteMetadataLike('tracks_p%');
    await _cache.deleteMetadataLike('albums_p%');
  }

  // ── Pass-through methods ────────────────────────────────────────────

  Future<void> recordListening(int trackId) async {
    await _api.recordListening(trackId);
  }

  Future<Map<String, dynamic>> createRichListening({
    required int trackId,
    int? durationSeconds,
    String? sourceDevice,
    String? clientSessionId,
  }) => _api.createRichListening(
    trackId: trackId,
    durationSeconds: durationSeconds,
    sourceDevice: sourceDevice,
    clientSessionId: clientSessionId,
  );

  Future<void> patchListeningBySession(
    String clientSessionId, {
    int? durationSeconds,
    String? sourceDevice,
  }) => _api.patchListeningBySession(
    clientSessionId,
    durationSeconds: durationSeconds,
    sourceDevice: sourceDevice,
  );

  Future<void> patchListening(
    int listeningId, {
    int? durationSeconds,
    String? sourceDevice,
  }) => _api.patchListening(
    listeningId,
    durationSeconds: durationSeconds,
    sourceDevice: sourceDevice,
  );

  Future<bool> probeClientDataSupport() => _api.probeClientDataSupport();

  Future<Map<String, dynamic>> upsertClientDevice({
    required String uuid,
    required String name,
    String clientId = 'tayra',
    String? clientVersion,
  }) => _api.upsertClientDevice(
    uuid: uuid,
    name: name,
    clientId: clientId,
    clientVersion: clientVersion,
  );

  Future<BulkListeningResult> bulkCreateListenings({
    required List<BulkListeningItem> items,
    String mode = 'enrich_or_create',
    int? dedupWindowSeconds,
  }) => _api.bulkCreateListenings(
    items: items,
    mode: mode,
    dedupWindowSeconds: dedupWindowSeconds,
  );

  Future<PaginatedResponse<Map<String, dynamic>>> getPlaybackProgress({
    int page = 1,
    int pageSize = 100,
    String? channelUuid,
    bool? completed,
  }) => _api.getPlaybackProgress(
    page: page,
    pageSize: pageSize,
    channelUuid: channelUuid,
    completed: completed,
  );

  Future<Map<String, dynamic>?> getPlaybackProgressForTrack(int trackId) =>
      _api.getPlaybackProgressForTrack(trackId);

  Future<Map<String, dynamic>> putPlaybackProgress({
    required int trackId,
    required int positionMs,
    int? durationMs,
    bool? completed,
    String? channelUuid,
    String? sourceDevice,
    DateTime? updatedAt,
  }) => _api.putPlaybackProgress(
    trackId: trackId,
    positionMs: positionMs,
    durationMs: durationMs,
    completed: completed,
    channelUuid: channelUuid,
    sourceDevice: sourceDevice,
    updatedAt: updatedAt,
  );

  Future<Map<String, dynamic>> bulkUpsertPlaybackProgress(
    List<Map<String, dynamic>> items,
  ) => _api.bulkUpsertPlaybackProgress(items);

  Future<void> deletePlaybackProgress(int trackId) =>
      _api.deletePlaybackProgress(trackId);

  Future<List<Map<String, dynamic>>> getClientPreferences({
    required String clientId,
    String? deviceUuid,
  }) => _api.getClientPreferences(clientId: clientId, deviceUuid: deviceUuid);

  Future<Map<String, dynamic>> putClientPreferences({
    required String clientId,
    required Map<String, dynamic> preferences,
    String? deviceUuid,
    String mode = 'merge',
  }) => _api.putClientPreferences(
    clientId: clientId,
    preferences: preferences,
    deviceUuid: deviceUuid,
    mode: mode,
  );

  /// Year-in-review stats (not cached — aggregates change with each listen).
  Future<Map<String, dynamic>> getListeningStats({
    required int year,
    int limit = 10,
  }) => _api.getListeningStats(year: year, limit: limit);

  String getStreamUrl(String listenUrl, {bool appendListenToken = true}) =>
      _api.getStreamUrl(listenUrl, appendListenToken: appendListenToken);

  Map<String, String> get authHeaders => _api.authHeaders;

  Future<void> ensureListenToken() => _api.ensureListenToken();

  // ── Channels / Podcasts ──────────────────────────────────────────────

  Future<PaginatedResponse<Channel>> getChannels({
    int page = 1,
    int pageSize = 50,
    String ordering = '-creation_date',
    String? q,
    bool? subscribed,
    bool forceRefresh = false,
  }) async {
    final cacheKey =
        'channels_p${page}_s${pageSize}_o${ordering}_q${q}_sub$subscribed';
    return _cachedFetch(
      cacheKey: cacheKey,
      cacheType: CacheType.channel,
      fromJson: (j) => PaginatedResponse.fromJson(j, Channel.fromJson),
      toJson: (r) => _paginatedResponseToJson(r, _channelToJson),
      fetch:
          () => _api.getChannels(
            page: page,
            pageSize: pageSize,
            ordering: ordering,
            q: q,
            subscribed: subscribed,
          ),
      ttl: const Duration(hours: 1),
      forceRefresh: forceRefresh,
    );
  }

  Future<Channel> getChannel(String uuid, {bool forceRefresh = false}) async {
    return _cachedFetch(
      cacheKey: 'channel_$uuid',
      cacheType: CacheType.channel,
      fromJson: Channel.fromJson,
      toJson: _channelToJson,
      fetch: () => _api.getChannel(uuid),
      ttl: const Duration(hours: 1),
      forceRefresh: forceRefresh,
      coverUrls: (c) => [c.artist.coverUrl],
    );
  }

  Future<PaginatedResponse<Track>> getChannelTracks({
    required String channelUuid,
    int page = 1,
    int pageSize = 50,
    String ordering = '-creation_date',
    bool forceRefresh = false,
  }) async {
    final cacheKey =
        'channel_tracks_${channelUuid}_p${page}_s${pageSize}_o$ordering';
    return _cachedFetch(
      cacheKey: cacheKey,
      cacheType: CacheType.track,
      fromJson: (j) => PaginatedResponse.fromJson(j, Track.fromJson),
      toJson: (r) => _paginatedResponseToJson(r, _trackToJson),
      fetch:
          () => _api.getChannelTracks(
            channelUuid: channelUuid,
            page: page,
            pageSize: pageSize,
            ordering: ordering,
          ),
      ttl: const Duration(hours: 1),
      forceRefresh: forceRefresh,
    );
  }

  Future<Channel> subscribeChannel(String uuid) async {
    final channel = await _api.subscribeChannel(uuid);
    await _cache.putMetadata(
      'channel_$uuid',
      CacheType.channel,
      _channelToJson(channel),
      ttl: const Duration(hours: 1),
    );
    return channel;
  }

  Future<void> unsubscribeChannel(String uuid) async {
    await _api.unsubscribeChannel(uuid);
  }

  Future<Channel> subscribeChannelRss(String rssUrl) async {
    final channel = await _api.subscribeChannelRss(rssUrl);
    await _cache.putMetadata(
      'channel_${channel.uuid}',
      CacheType.channel,
      _channelToJson(channel),
      ttl: const Duration(hours: 1),
    );
    return channel;
  }

  // ── Radios ────────────────────────────────────────────────────────────

  Future<PaginatedResponse<Radio>> getRadios({
    int page = 1,
    int pageSize = 20,
    String ordering = '-creation_date',
    String? q,
    String? scope,
    String? name,
    bool forceRefresh = false,
  }) async {
    final cacheKey =
        'radios_p${page}_s${pageSize}_o${ordering}_q${q}_sc${scope}_n$name';
    return _cachedFetch(
      cacheKey: cacheKey,
      cacheType: CacheType.radio,
      fromJson: (j) => PaginatedResponse.fromJson(j, Radio.fromJson),
      toJson: (r) => _paginatedResponseToJson(r, _radioToJson),
      fetch:
          () => _api.getRadios(
            page: page,
            pageSize: pageSize,
            ordering: ordering,
            q: q,
            scope: scope,
            name: name,
          ),
      ttl: const Duration(hours: 1),
      forceRefresh: forceRefresh,
      coverUrls: (r) => r.results.map((radio) => radio.coverUrl).toList(),
    );
  }

  Future<Track> getRadioTrack(int id) async {
    return _api.getRadioTrack(id);
  }

  Future<RadioSession> createRadioSession(Map<String, dynamic> body) async {
    return _api.createRadioSession(body);
  }

  Future<RadioSessionTrackCreate> getNextRadioTrack(
    int session, {
    int? count,
  }) async {
    return _api.getNextRadioTrack(session, count: count);
  }

  Future<dynamic> postNextRadioTrackRaw(int session, {int? count}) async {
    return _api.postNextRadioTrackRaw(session, count: count);
  }

  // ── Libraries ─────────────────────────────────────────────────────────

  Future<PaginatedResponse<Library>> getLibraries({
    int page = 1,
    int pageSize = 50,
    String? scope,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'libraries_p${page}_s${pageSize}_sc$scope';
    return _cachedFetch(
      cacheKey: cacheKey,
      cacheType: CacheType.library,
      fromJson: (j) => PaginatedResponse.fromJson(j, Library.fromJson),
      toJson: (r) => _paginatedResponseToJson(r, _libraryToJson),
      fetch:
          () => _api.getLibraries(page: page, pageSize: pageSize, scope: scope),
      ttl: const Duration(hours: 6),
      forceRefresh: forceRefresh,
    );
  }

  // ── Serialization helpers ───────────────────────────────────────────

  Map<String, dynamic> _paginatedResponseToJson<T>(
    PaginatedResponse<T> response,
    Map<String, dynamic> Function(T) itemToJson,
  ) {
    return {
      'count': response.count,
      'next': response.next,
      'previous': response.previous,
      'results': response.results.map(itemToJson).toList(),
    };
  }

  Map<String, dynamic> _albumToJson(Album album) {
    return {
      'id': album.id,
      'title': album.title,
      'release_date': album.releaseDate,
      'artist':
          album.artist != null
              ? {
                'id': album.artist!.id,
                'name': album.artist!.name,
                'cover':
                    album.artist!.cover != null
                        ? _coverToJson(album.artist!.cover!)
                        : null,
              }
              : null,
      'cover': album.cover != null ? _coverToJson(album.cover!) : null,
      'tracks_count': album.tracksCount,
      'duration': album.duration,
      'is_playable': album.isPlayable,
      'tags': album.tags,
      'creation_date': album.creationDate?.toIso8601String(),
      'tracks': album.tracks.map(_trackToJson).toList(),
    };
  }

  Map<String, dynamic> _tagToJson(Tag tag) {
    return {
      'name': tag.name,
      'creation_date': tag.creationDate?.toIso8601String(),
    };
  }

  Map<String, dynamic> _artistToJson(Artist artist) {
    return {
      'id': artist.id,
      'name': artist.name,
      'mbid': artist.mbid,
      'content_category': artist.contentCategory,
      'cover': artist.cover != null ? _coverToJson(artist.cover!) : null,
      'tracks_count': artist.tracksCount,
      'albums': artist.albums.map(_albumToJson).toList(),
      'tags': artist.tags,
      'creation_date': artist.creationDate?.toIso8601String(),
    };
  }

  Map<String, dynamic> _trackToJson(Track track) {
    return {
      'id': track.id,
      'title': track.title,
      'position': track.position,
      'disc_number': track.discNumber,
      'is_playable': track.isPlayable,
      'tags': track.tags,
      'artist':
          track.artist != null
              ? {'id': track.artist!.id, 'name': track.artist!.name}
              : null,
      'album':
          track.album != null
              ? {
                'id': track.album!.id,
                'title': track.album!.title,
                'cover':
                    track.album!.cover != null
                        ? _coverToJson(track.album!.cover!)
                        : null,
              }
              : null,
      'listen_url': track.listenUrl,
      'cover': track.cover != null ? _coverToJson(track.cover!) : null,
      'uploads':
          track.uploads
              .map(
                (u) => {
                  'uuid': u.uuid,
                  'duration': u.duration,
                  'bitrate': u.bitrate,
                  'size': u.size,
                  'mimetype': u.mimetype,
                  'listen_url': u.listenUrl,
                },
              )
              .toList(),
      'creation_date': track.creationDate?.toIso8601String(),
    };
  }

  Map<String, dynamic> _coverToJson(Cover cover) {
    return {
      'uuid': cover.uuid,
      'urls': {
        'original': cover.urls.original,
        'medium_square_crop': cover.urls.mediumSquareCrop,
        'small_square_crop': cover.urls.smallSquareCrop,
        'large_square_crop': cover.urls.largeSquareCrop,
      },
    };
  }

  Map<String, dynamic> _playlistToJson(Playlist playlist) {
    return {
      'id': playlist.id,
      'name': playlist.name,
      'privacy_level': playlist.privacyLevel,
      'tracks_count': playlist.tracksCount,
      'duration': playlist.duration,
      'is_playable': playlist.isPlayable,
      'album_covers': playlist.albumCovers,
      'cover': playlist.cover != null ? _coverToJson(playlist.cover!) : null,
      'creation_date': playlist.creationDate?.toIso8601String(),
      'modification_date': playlist.modificationDate?.toIso8601String(),
    };
  }

  Map<String, dynamic> _playlistTrackToJson(PlaylistTrack pt) {
    return {
      'track': _trackToJson(pt.track),
      'index': pt.index,
      'creation_date': pt.creationDate?.toIso8601String(),
    };
  }

  Map<String, dynamic> _favoriteToJson(Favorite fav) {
    return {
      'id': fav.id,
      'track': _trackToJson(fav.track),
      'creation_date': fav.creationDate?.toIso8601String(),
    };
  }

  Map<String, dynamic> _listeningToJson(Listening listening) {
    return {
      'id': listening.id,
      'track': _trackToJson(listening.track),
      'created': listening.created?.toIso8601String(),
    };
  }

  Map<String, dynamic> _searchResultToJson(SearchResult result) {
    return {
      'albums': result.albums.map(_albumToJson).toList(),
      'artists': result.artists.map(_artistToJson).toList(),
      'tracks': result.tracks.map(_trackToJson).toList(),
    };
  }

  Map<String, dynamic> _radioToJson(Radio radio) => radio.toJson();

  Map<String, dynamic> _channelToJson(Channel channel) => channel.toJson();

  Map<String, dynamic> _libraryToJson(Library lib) {
    return {
      'uuid': lib.uuid,
      'name': lib.name,
      'description': lib.description,
      'privacy_level': lib.privacyLevel,
      'uploads_count': lib.uploadsCount,
      'size': lib.size,
      'creation_date': lib.creationDate?.toIso8601String(),
    };
  }
}

// ── Provider ────────────────────────────────────────────────────────────

final cachedFunkwhaleApiProvider = Provider<CachedFunkwhaleApi>((ref) {
  final api = ref.watch(funkwhaleApiProvider);
  final cache = CacheManager.instance;
  final audioCache = ref.watch(audioCacheServiceProvider);
  return CachedFunkwhaleApi(
    api,
    cache,
    audioCache,
    isOffline: () {
      // Prefer the combined offline signal (no interface + force offline).
      // Use read (not watch) so the API instance is not rebuilt on every
      // connectivity flap — the getter is evaluated per request.
      return ref.read(offlineStateProvider).isOffline;
    },
  );
});

/// Keep a Riverpod provider in sync with background metadata revalidation.
///
/// Call at the start of a [FutureProvider] / [AsyncNotifier.build] body.
/// When a matching cache key is revalidated with new data, this provider is
/// invalidated and re-reads the (now fresh) cache immediately — so lists
/// insert/remove items without a loading flash.
///
/// [matches] typically checks a cache-key prefix, e.g.
/// `(key) => key.startsWith('albums_p1')`.
void watchMetadataRevalidation(
  Ref ref,
  bool Function(String cacheKey) matches,
) {
  final api = ref.watch(cachedFunkwhaleApiProvider);
  final sub = api.metadataUpdates.listen((key) {
    if (matches(key)) {
      ref.invalidateSelf();
    }
  });
  ref.onDispose(sub.cancel);
}
