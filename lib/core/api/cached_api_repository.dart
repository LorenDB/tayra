import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/api_client.dart';
import 'package:tayra/core/api/api_repository.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/cache/audio_cache_service.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/cache_provider.dart';

// Re-export types so consumers only need to import cached_api_repository.dart
export 'package:tayra/core/api/api_repository.dart'
    show funkwhaleApiProvider, FunkwhaleApi;
export 'package:tayra/core/api/api_client.dart' show PaginatedResponse;
export 'package:tayra/core/api/models.dart';

/// Cached API repository that wraps FunkwhaleApi with caching layer.
///
/// Strategy for reads:
///  1. If a non-expired cache entry exists, return it immediately.
///  2. Otherwise try the network.  On success, update the cache and return.
///  3. If the network fails, serve *stale* (expired) cache data if available,
///     so the user can still browse offline.
class CachedFunkwhaleApi {
  final FunkwhaleApi _api;
  final CacheManager _cache;
  final AudioCacheService _audioCache;

  CachedFunkwhaleApi(this._api, this._cache, this._audioCache);

  // ── Generic cache-or-fetch helpers ──────────────────────────────────

  /// Try to serve [cacheKey] from the metadata cache. Returns `null` on miss
  /// or parse error.  Does NOT respect TTL – caller decides whether to also
  /// hit the network.
  Future<T?> _tryCache<T>(
    String cacheKey,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final cached = await _cache.getMetadata(cacheKey);
    if (cached == null) return null;
    try {
      return fromJson(cached);
    } catch (_) {
      return null;
    }
  }

  /// Generic cache-or-fetch pattern used by every read method:
  ///  1. Return a fresh cache hit immediately (unless [forceRefresh]).
  ///  2. On cache miss, call [fetch] and write the result to the cache.
  ///  3. On network failure, fall back to a stale cache entry if available.
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
    if (!forceRefresh) {
      final hit = await _tryCache(cacheKey, fromJson);
      if (hit != null) return hit;
    }

    try {
      final result = await fetch();
      try {
        await _cache.putMetadata(cacheKey, cacheType, toJson(result), ttl: ttl);
      } catch (e) {
        debugPrint('Cache: failed to write metadata for $cacheKey: $e');
      }
      // Fire-and-forget cover art caching for the fresh network result.
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
    bool forceRefresh = false,
  }) async {
    final cacheKey =
        'albums_p${page}_s${pageSize}_o${ordering}_'
        'a${artist}_sc${scope}_q$q';
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
          ),
      ttl: const Duration(hours: 1),
      forceRefresh: forceRefresh,
      coverUrls: (r) => r.results.map((a) => a.coverUrl).toList(),
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
    final cacheKey =
        'artists_p${page}_s${pageSize}_o${ordering}_'
        'h${hasAlbums}_sc${scope}_q$q';
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
      coverUrls: (r) => r.results.map((a) => a.coverUrl).toList(),
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
    final cacheKey =
        'tracks_p${page}_s${pageSize}_o${ordering}_'
        'al${album}_ar${artist}_sc${scope}_q$q';
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
      coverUrls: (r) => r.results.map((t) => t.coverUrl).toList(),
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
    return _cachedFetch(
      cacheKey: 'favorites_p${page}_s$pageSize',
      cacheType: CacheType.track, // reuse type for favorites list
      fromJson: (j) => PaginatedResponse.fromJson(j, Favorite.fromJson),
      toJson: (r) => _paginatedResponseToJson(r, _favoriteToJson),
      fetch: () => _api.getFavorites(page: page, pageSize: pageSize),
      ttl: const Duration(hours: 1),
      forceRefresh: forceRefresh,
      coverUrls: (r) => r.results.map((f) => f.track.coverUrl).toList(),
    );
  }

  Future<Set<int>> getAllFavoriteTrackIds({bool forceRefresh = false}) async {
    // Try cached favorites first
    if (!forceRefresh) {
      try {
        final cached = await _cache.getFavorites();
        if (cached.isNotEmpty) return cached;
      } catch (_) {}
    }

    try {
      final ids = await _api.getAllFavoriteTrackIds();
      // Update cache – clear and rebuild
      final currentIds = await _cache.getFavorites();
      for (final id in currentIds) {
        await _cache.removeFavorite(id);
      }
      for (final id in ids) {
        await _cache.addFavorite(id);
      }
      return ids;
    } catch (_) {
      // Offline fallback – return whatever we have cached
      try {
        return await _cache.getFavorites();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> addFavorite(int trackId) async {
    await _api.addFavorite(trackId);
    await _cache.addFavorite(trackId);
  }

  Future<void> removeFavorite(int trackId) async {
    await _api.removeFavorite(trackId);
    await _cache.removeFavorite(trackId);
  }

  // ── Playlists ───────────────────────────────────────────────────────

  Future<PaginatedResponse<Playlist>> getPlaylists({
    int page = 1,
    int pageSize = 20,
    String? scope,
    bool forceRefresh = false,
  }) async {
    return _cachedFetch(
      cacheKey: 'playlists_p${page}_s${pageSize}_sc$scope',
      cacheType: CacheType.playlist,
      fromJson: (j) => PaginatedResponse.fromJson(j, Playlist.fromJson),
      toJson: (r) => _paginatedResponseToJson(r, _playlistToJson),
      fetch:
          () => _api.getPlaylists(page: page, pageSize: pageSize, scope: scope),
      ttl: const Duration(hours: 1),
      forceRefresh: forceRefresh,
      coverUrls:
          (r) =>
              r.results.expand((p) => p.albumCovers).cast<String?>().toList(),
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
      coverUrls: (p) => p.albumCovers.cast<String?>().toList(),
    );
  }

  Future<PaginatedResponse<PlaylistTrack>> getPlaylistTracks(
    int id, {
    int page = 1,
    int pageSize = 50,
    bool forceRefresh = false,
  }) async {
    return _cachedFetch(
      cacheKey: 'playlist_tracks_${id}_p${page}_s$pageSize',
      cacheType: CacheType.playlist,
      fromJson: (j) => PaginatedResponse.fromJson(j, PlaylistTrack.fromJson),
      toJson: (r) => _paginatedResponseToJson(r, _playlistTrackToJson),
      fetch: () => _api.getPlaylistTracks(id, page: page, pageSize: pageSize),
      ttl: const Duration(hours: 1),
      forceRefresh: forceRefresh,
      coverUrls: (r) => r.results.map((pt) => pt.track.coverUrl).toList(),
    );
  }

  // ── Write operations (pass-through, invalidate cache) ───────────────

  Future<Playlist> createPlaylist({
    required String name,
    String privacyLevel = 'me',
  }) async {
    return await _api.createPlaylist(name: name, privacyLevel: privacyLevel);
  }

  Future<void> addTracksToPlaylist(int playlistId, List<int> trackIds) async {
    await _api.addTracksToPlaylist(playlistId, trackIds);
    await _cache.deleteMetadata('playlist_$playlistId');
  }

  Future<void> deletePlaylist(int id) async {
    await _api.deletePlaylist(id);
    await _cache.deleteMetadata('playlist_$id');
  }

  // ── Pass-through methods ────────────────────────────────────────────

  Future<void> recordListening(int trackId) async {
    await _api.recordListening(trackId);
  }

  String getStreamUrl(String listenUrl) => _api.getStreamUrl(listenUrl);

  Map<String, String> get authHeaders => _api.authHeaders;

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
        'large_square_crop': cover.urls.largSquareCrop,
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

  Map<String, dynamic> _searchResultToJson(SearchResult result) {
    return {
      'albums': result.albums.map(_albumToJson).toList(),
      'artists': result.artists.map(_artistToJson).toList(),
      'tracks': result.tracks.map(_trackToJson).toList(),
    };
  }
}

// ── Provider ────────────────────────────────────────────────────────────

final cachedFunkwhaleApiProvider = Provider<CachedFunkwhaleApi>((ref) {
  final api = ref.watch(funkwhaleApiProvider);
  final cache = CacheManager.instance;
  final audioCache = ref.watch(audioCacheServiceProvider);
  return CachedFunkwhaleApi(api, cache, audioCache);
});
