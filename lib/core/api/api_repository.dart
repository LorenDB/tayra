import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funkwhale/core/api/api_client.dart';
import 'package:funkwhale/core/api/models.dart';
import 'package:funkwhale/core/auth/auth_provider.dart';

// ── Repository provider ─────────────────────────────────────────────────

final funkwhaleApiProvider = Provider<FunkwhaleApi>((ref) {
  return FunkwhaleApi(ref.watch(dioProvider), ref);
});

// ── API Repository ──────────────────────────────────────────────────────

class FunkwhaleApi {
  final Dio _dio;
  final Ref _ref;

  FunkwhaleApi(this._dio, this._ref);

  String get _baseUrl {
    final serverUrl = _ref.read(authStateProvider).serverUrl ?? '';
    return serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
  }

  // ── Albums ──────────────────────────────────────────────────────────

  Future<PaginatedResponse<Album>> getAlbums({
    int page = 1,
    int pageSize = 20,
    String ordering = '-creation_date',
    int? artist,
    String? scope,
    String? q,
  }) async {
    final response = await _dio.get(
      '$_baseUrl/api/v1/albums/',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'ordering': ordering,
        'playable': true,
        if (artist != null) 'artist': artist,
        if (scope != null) 'scope': scope,
        if (q != null) 'q': q,
      },
    );
    return PaginatedResponse.fromJson(response.data, Album.fromJson);
  }

  Future<Album> getAlbum(int id) async {
    final response = await _dio.get('$_baseUrl/api/v1/albums/$id/');
    return Album.fromJson(response.data);
  }

  // ── Artists ─────────────────────────────────────────────────────────

  Future<PaginatedResponse<Artist>> getArtists({
    int page = 1,
    int pageSize = 20,
    String ordering = 'name',
    bool? hasAlbums,
    String? scope,
    String? q,
  }) async {
    final response = await _dio.get(
      '$_baseUrl/api/v1/artists/',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'ordering': ordering,
        'playable': true,
        if (hasAlbums != null) 'has_albums': hasAlbums,
        if (scope != null) 'scope': scope,
        if (q != null) 'q': q,
      },
    );
    return PaginatedResponse.fromJson(response.data, Artist.fromJson);
  }

  Future<Artist> getArtist(int id) async {
    final response = await _dio.get('$_baseUrl/api/v1/artists/$id/');
    return Artist.fromJson(response.data);
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
  }) async {
    final response = await _dio.get(
      '$_baseUrl/api/v1/tracks/',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'ordering': ordering,
        'playable': true,
        if (album != null) 'album': album,
        if (artist != null) 'artist': artist,
        if (scope != null) 'scope': scope,
        if (q != null) 'q': q,
      },
    );
    return PaginatedResponse.fromJson(response.data, Track.fromJson);
  }

  Future<Track> getTrack(int id) async {
    final response = await _dio.get('$_baseUrl/api/v1/tracks/$id/');
    return Track.fromJson(response.data);
  }

  // ── Search ──────────────────────────────────────────────────────────

  Future<SearchResult> search(String query) async {
    final response = await _dio.get(
      '$_baseUrl/api/v1/search',
      queryParameters: {'q': query},
    );
    return SearchResult.fromJson(response.data);
  }

  // ── Favorites ───────────────────────────────────────────────────────

  Future<PaginatedResponse<Favorite>> getFavorites({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get(
      '$_baseUrl/api/v1/favorites/tracks/',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'ordering': '-creation_date',
      },
    );
    return PaginatedResponse.fromJson(response.data, Favorite.fromJson);
  }

  /// Returns a set of all favorited track IDs (optimized endpoint).
  Future<Set<int>> getAllFavoriteTrackIds() async {
    final response = await _dio.get('$_baseUrl/api/v1/favorites/tracks/all/');
    final results = response.data['results'] as List<dynamic>? ?? [];
    return results.map((e) => e['track'] as int).toSet();
  }

  Future<void> addFavorite(int trackId) async {
    await _dio.post(
      '$_baseUrl/api/v1/favorites/tracks/',
      data: {'track': trackId},
    );
  }

  Future<void> removeFavorite(int trackId) async {
    await _dio.post(
      '$_baseUrl/api/v1/favorites/tracks/remove/',
      data: {'track': trackId},
    );
  }

  // ── Playlists ───────────────────────────────────────────────────────

  Future<PaginatedResponse<Playlist>> getPlaylists({
    int page = 1,
    int pageSize = 20,
    String? scope,
  }) async {
    final response = await _dio.get(
      '$_baseUrl/api/v1/playlists/',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'ordering': '-modification_date',
        if (scope != null) 'scope': scope,
      },
    );
    return PaginatedResponse.fromJson(response.data, Playlist.fromJson);
  }

  Future<Playlist> getPlaylist(int id) async {
    final response = await _dio.get('$_baseUrl/api/v1/playlists/$id/');
    return Playlist.fromJson(response.data);
  }

  Future<PaginatedResponse<PlaylistTrack>> getPlaylistTracks(
    int id, {
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _dio.get(
      '$_baseUrl/api/v1/playlists/$id/tracks/',
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    return PaginatedResponse.fromJson(response.data, PlaylistTrack.fromJson);
  }

  Future<Playlist> createPlaylist({
    required String name,
    String privacyLevel = 'me',
  }) async {
    final response = await _dio.post(
      '$_baseUrl/api/v1/playlists/',
      data: {'name': name, 'privacy_level': privacyLevel},
    );
    return Playlist.fromJson(response.data);
  }

  Future<void> addTracksToPlaylist(int playlistId, List<int> trackIds) async {
    await _dio.post(
      '$_baseUrl/api/v1/playlists/$playlistId/add/',
      data: {'tracks': trackIds, 'allow_duplicates': false},
    );
  }

  Future<void> deletePlaylist(int id) async {
    await _dio.delete('$_baseUrl/api/v1/playlists/$id/');
  }

  // ── Listening history ───────────────────────────────────────────────

  Future<void> recordListening(int trackId) async {
    await _dio.post(
      '$_baseUrl/api/v1/history/listenings/',
      data: {'track': trackId},
    );
  }

  // ── Stream URL builder ──────────────────────────────────────────────

  String getStreamUrl(String listenUrl) {
    if (listenUrl.startsWith('http')) return listenUrl;
    return '$_baseUrl$listenUrl';
  }

  Map<String, String> get authHeaders {
    final token = _ref.read(authStateProvider).accessToken;
    if (token != null) {
      return {'Authorization': 'Bearer $token'};
    }
    return {};
  }
}
