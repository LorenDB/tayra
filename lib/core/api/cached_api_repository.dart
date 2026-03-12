import 'package:tayra/core/api/api_repository.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/api/api_client.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  CachedFunkwhaleApi(this._api, this._cache);

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

    if (!forceRefresh) {
      final hit = await _tryCache(
        cacheKey,
        (j) => PaginatedResponse.fromJson(j, Album.fromJson),
      );
      if (hit != null) return hit;
    }

    try {
      final response = await _api.getAlbums(
        page: page,
        pageSize: pageSize,
        ordering: ordering,
        artist: artist,
        scope: scope,
        q: q,
      );
      _cache
          .putMetadata(
            cacheKey,
            CacheType.recentAlbums,
            _paginatedResponseToJson(response, _albumToJson),
            ttl: const Duration(minutes: 5),
          )
          .catchError((_) {});
      return response;
    } catch (_) {
      final stale = await _cache.getMetadataStale(cacheKey);
      if (stale != null) {
        try {
          return PaginatedResponse.fromJson(stale, Album.fromJson);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<Album> getAlbum(int id, {bool forceRefresh = false}) async {
    final cacheKey = 'album_$id';

    if (!forceRefresh) {
      final hit = await _tryCache(cacheKey, Album.fromJson);
      if (hit != null) return hit;
    }

    try {
      final album = await _api.getAlbum(id);
      _cache
          .putMetadata(
            cacheKey,
            CacheType.album,
            _albumToJson(album),
            ttl: const Duration(hours: 1),
          )
          .catchError((_) {});
      return album;
    } catch (_) {
      final stale = await _cache.getMetadataStale(cacheKey);
      if (stale != null) {
        try {
          return Album.fromJson(stale);
        } catch (_) {}
      }
      rethrow;
    }
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

    if (!forceRefresh) {
      final hit = await _tryCache(
        cacheKey,
        (j) => PaginatedResponse.fromJson(j, Artist.fromJson),
      );
      if (hit != null) return hit;
    }

    try {
      final response = await _api.getArtists(
        page: page,
        pageSize: pageSize,
        ordering: ordering,
        hasAlbums: hasAlbums,
        scope: scope,
        q: q,
      );
      _cache
          .putMetadata(
            cacheKey,
            CacheType.recentArtists,
            _paginatedResponseToJson(response, _artistToJson),
            ttl: const Duration(minutes: 5),
          )
          .catchError((_) {});
      return response;
    } catch (_) {
      final stale = await _cache.getMetadataStale(cacheKey);
      if (stale != null) {
        try {
          return PaginatedResponse.fromJson(stale, Artist.fromJson);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<Artist> getArtist(int id, {bool forceRefresh = false}) async {
    final cacheKey = 'artist_$id';

    if (!forceRefresh) {
      final hit = await _tryCache(cacheKey, Artist.fromJson);
      if (hit != null) return hit;
    }

    try {
      final artist = await _api.getArtist(id);
      _cache
          .putMetadata(
            cacheKey,
            CacheType.artist,
            _artistToJson(artist),
            ttl: const Duration(hours: 1),
          )
          .catchError((_) {});
      return artist;
    } catch (_) {
      final stale = await _cache.getMetadataStale(cacheKey);
      if (stale != null) {
        try {
          return Artist.fromJson(stale);
        } catch (_) {}
      }
      rethrow;
    }
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

    if (!forceRefresh) {
      final hit = await _tryCache(
        cacheKey,
        (j) => PaginatedResponse.fromJson(j, Track.fromJson),
      );
      if (hit != null) return hit;
    }

    try {
      final response = await _api.getTracks(
        page: page,
        pageSize: pageSize,
        ordering: ordering,
        album: album,
        artist: artist,
        scope: scope,
        q: q,
      );
      _cache
          .putMetadata(
            cacheKey,
            CacheType.track,
            _paginatedResponseToJson(response, _trackToJson),
            ttl: const Duration(minutes: 5),
          )
          .catchError((_) {});
      return response;
    } catch (_) {
      final stale = await _cache.getMetadataStale(cacheKey);
      if (stale != null) {
        try {
          return PaginatedResponse.fromJson(stale, Track.fromJson);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<Track> getTrack(int id, {bool forceRefresh = false}) async {
    final cacheKey = 'track_$id';

    if (!forceRefresh) {
      final hit = await _tryCache(cacheKey, Track.fromJson);
      if (hit != null) return hit;
    }

    try {
      final track = await _api.getTrack(id);
      _cache
          .putMetadata(
            cacheKey,
            CacheType.track,
            _trackToJson(track),
            ttl: const Duration(hours: 1),
          )
          .catchError((_) {});
      return track;
    } catch (_) {
      final stale = await _cache.getMetadataStale(cacheKey);
      if (stale != null) {
        try {
          return Track.fromJson(stale);
        } catch (_) {}
      }
      rethrow;
    }
  }

  // ── Search ──────────────────────────────────────────────────────────

  Future<SearchResult> search(String query, {bool forceRefresh = false}) async {
    final cacheKey = 'search_$query';

    if (!forceRefresh) {
      final hit = await _tryCache(cacheKey, SearchResult.fromJson);
      if (hit != null) return hit;
    }

    try {
      final result = await _api.search(query);
      _cache
          .putMetadata(
            cacheKey,
            CacheType.searchResults,
            _searchResultToJson(result),
            ttl: const Duration(minutes: 2),
          )
          .catchError((_) {});
      return result;
    } catch (_) {
      final stale = await _cache.getMetadataStale(cacheKey);
      if (stale != null) {
        try {
          return SearchResult.fromJson(stale);
        } catch (_) {}
      }
      rethrow;
    }
  }

  // ── Favorites ───────────────────────────────────────────────────────

  Future<PaginatedResponse<Favorite>> getFavorites({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'favorites_p${page}_s$pageSize';

    if (!forceRefresh) {
      final hit = await _tryCache(
        cacheKey,
        (j) => PaginatedResponse.fromJson(j, Favorite.fromJson),
      );
      if (hit != null) return hit;
    }

    try {
      final response = await _api.getFavorites(page: page, pageSize: pageSize);
      _cache
          .putMetadata(
            cacheKey,
            CacheType.track, // reuse type for favorites list
            _paginatedResponseToJson(response, _favoriteToJson),
            ttl: const Duration(minutes: 5),
          )
          .catchError((_) {});
      return response;
    } catch (_) {
      final stale = await _cache.getMetadataStale(cacheKey);
      if (stale != null) {
        try {
          return PaginatedResponse.fromJson(stale, Favorite.fromJson);
        } catch (_) {}
      }
      rethrow;
    }
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
    final cacheKey = 'playlists_p${page}_s${pageSize}_sc$scope';

    if (!forceRefresh) {
      final hit = await _tryCache(
        cacheKey,
        (j) => PaginatedResponse.fromJson(j, Playlist.fromJson),
      );
      if (hit != null) return hit;
    }

    try {
      final response = await _api.getPlaylists(
        page: page,
        pageSize: pageSize,
        scope: scope,
      );
      _cache
          .putMetadata(
            cacheKey,
            CacheType.playlist,
            _paginatedResponseToJson(response, _playlistToJson),
            ttl: const Duration(minutes: 2),
          )
          .catchError((_) {});
      return response;
    } catch (_) {
      final stale = await _cache.getMetadataStale(cacheKey);
      if (stale != null) {
        try {
          return PaginatedResponse.fromJson(stale, Playlist.fromJson);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<Playlist> getPlaylist(int id, {bool forceRefresh = false}) async {
    final cacheKey = 'playlist_$id';

    if (!forceRefresh) {
      final hit = await _tryCache(cacheKey, Playlist.fromJson);
      if (hit != null) return hit;
    }

    try {
      final playlist = await _api.getPlaylist(id);
      _cache
          .putMetadata(
            cacheKey,
            CacheType.playlist,
            _playlistToJson(playlist),
            ttl: const Duration(minutes: 2),
          )
          .catchError((_) {});
      return playlist;
    } catch (_) {
      final stale = await _cache.getMetadataStale(cacheKey);
      if (stale != null) {
        try {
          return Playlist.fromJson(stale);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<PaginatedResponse<PlaylistTrack>> getPlaylistTracks(
    int id, {
    int page = 1,
    int pageSize = 50,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'playlist_tracks_${id}_p${page}_s$pageSize';

    if (!forceRefresh) {
      final hit = await _tryCache(
        cacheKey,
        (j) => PaginatedResponse.fromJson(j, PlaylistTrack.fromJson),
      );
      if (hit != null) return hit;
    }

    try {
      final response = await _api.getPlaylistTracks(
        id,
        page: page,
        pageSize: pageSize,
      );
      _cache
          .putMetadata(
            cacheKey,
            CacheType.playlist,
            _paginatedResponseToJson(response, _playlistTrackToJson),
            ttl: const Duration(minutes: 2),
          )
          .catchError((_) {});
      return response;
    } catch (_) {
      final stale = await _cache.getMetadataStale(cacheKey);
      if (stale != null) {
        try {
          return PaginatedResponse.fromJson(stale, PlaylistTrack.fromJson);
        } catch (_) {}
      }
      rethrow;
    }
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
              ? {'id': album.artist!.id, 'name': album.artist!.name}
              : null,
      'cover': album.cover != null ? _coverToJson(album.cover!) : null,
      'tracks_count': album.tracksCount,
      'creation_date': album.creationDate?.toIso8601String(),
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
  return CachedFunkwhaleApi(api, cache);
});
