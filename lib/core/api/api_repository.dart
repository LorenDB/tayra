import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/api_client.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/auth/auth_provider.dart';

// ── Repository provider ─────────────────────────────────────────────────

final funkwhaleApiProvider = Provider<FunkwhaleApi>((ref) {
  return FunkwhaleApi(ref.watch(dioProvider), ref);
});

// ── API Repository ──────────────────────────────────────────────────────

class FunkwhaleApi {
  final Dio _dio;
  final Ref _ref;
  String? _lastRadioSessionCookie;

  FunkwhaleApi(this._dio, this._ref);

  /// Cookie returned by the last successful radio session creation (if any).
  String? get lastRadioSessionCookie => _lastRadioSessionCookie;

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
        'include': 'uploads',
        if (album != null) 'album': album,
        if (artist != null) 'artist': artist,
        if (scope != null) 'scope': scope,
        if (q != null) 'q': q,
      },
    );
    return PaginatedResponse.fromJson(response.data, Track.fromJson);
  }

  Future<Track> getTrack(int id) async {
    final response = await _dio.get(
      '$_baseUrl/api/v1/tracks/$id/',
      queryParameters: {'include': 'uploads'},
    );
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

  /// Patch (partial update) a playlist. Used for renaming / updating metadata.
  Future<Playlist> patchPlaylist(int id, Map<String, dynamic> body) async {
    final response = await _dio.patch(
      '$_baseUrl/api/v1/playlists/$id/',
      data: body,
    );
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

  /// Remove a track from a playlist by its playlist position index.
  ///
  /// Funkwhale v1.4.0 removes by index: POST /api/v1/playlists/{id}/remove/
  /// with body {"index": <int>}. The schema.yml incorrectly references
  /// PlaylistRequest for this body, but the actual implementation uses index.
  Future<void> removeTrackFromPlaylist(int playlistId, int index) async {
    final url = '$_baseUrl/api/v1/playlists/$playlistId/remove/';

    try {
      // Ensure we send JSON content-type (matches the official client/curl)
      // and do not throw on non-2xx status codes (match Fuel/.awaitByteArrayResponseResult)
      final response = await _dio.post(
        url,
        data: {'index': index},
        options: Options(
          contentType: Headers.jsonContentType,
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (err) {
      rethrow;
    }
  }

  Future<void> deletePlaylist(int id) async {
    await _dio.delete('$_baseUrl/api/v1/playlists/$id/');
  }

  /// Remove all tracks from a playlist.
  Future<void> clearPlaylist(int id) async {
    await _dio.delete('$_baseUrl/api/v1/playlists/$id/clear/');
  }

  /// Move a track within a playlist from [index] to [newIndex] (0-based).
  Future<void> moveTrackInPlaylist(
    int playlistId,
    int index,
    int newIndex,
  ) async {
    await _dio.post(
      '$_baseUrl/api/v1/playlists/$playlistId/move/',
      data: {'index': index, 'new_index': newIndex},
    );
  }

  // ── Listening history ───────────────────────────────────────────────

  Future<void> recordListening(int trackId) async {
    await _dio.post(
      '$_baseUrl/api/v1/history/listenings/',
      data: {'track': trackId},
    );
  }

  Future<PaginatedResponse<Listening>> getListenings({
    int page = 1,
    int pageSize = 20,
    String ordering = '-created',
  }) async {
    final response = await _dio.get(
      '$_baseUrl/api/v1/history/listenings/',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'ordering': ordering,
      },
    );
    return PaginatedResponse.fromJson(response.data, Listening.fromJson);
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

  // ── Radios ─────────────────────────────────────────────────────────

  Future<PaginatedResponse<Radio>> getRadios({
    int page = 1,
    int pageSize = 20,
    String ordering = '-creation_date',
    String? q,
    String? scope,
    String? name,
  }) async {
    final response = await _dio.get(
      '$_baseUrl/api/v1/radios/radios/',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'ordering': ordering,
        if (q != null) 'q': q,
        if (scope != null) 'scope': scope,
        if (name != null) 'name': name,
      },
    );

    // The API may return either a paginated object with `results` or a
    // plain list of radios. Be flexible and accept both shapes.
    final data = response.data;
    if (data is List<dynamic>) {
      final results =
          data.map<Radio>((e) {
            if (e is Map<String, dynamic>) return Radio.fromJson(e);
            if (e is List && e.isNotEmpty && e.first is Map<String, dynamic>) {
              return Radio.fromJson(e.first as Map<String, dynamic>);
            }
            throw StateError(
              'Unexpected radio list item type: ${e.runtimeType}',
            );
          }).toList();
      return PaginatedResponse(
        count: results.length,
        next: null,
        previous: null,
        results: results,
      );
    }

    if (data is Map<String, dynamic> && data['results'] is List<dynamic>) {
      return PaginatedResponse.fromJson(data, Radio.fromJson);
    }

    throw StateError('Unexpected radios response shape: ${data.runtimeType}');
  }

  Future<Radio> createRadio({required Map<String, dynamic> body}) async {
    final response = await _dio.post(
      '$_baseUrl/api/v1/radios/radios/',
      data: body,
    );
    return Radio.fromJson(response.data);
  }

  Future<Radio> getRadio(int id) async {
    final response = await _dio.get('$_baseUrl/api/v1/radios/radios/$id/');
    return Radio.fromJson(response.data);
  }

  Future<Radio> updateRadio(int id, Map<String, dynamic> body) async {
    final response = await _dio.put(
      '$_baseUrl/api/v1/radios/radios/$id/',
      data: body,
    );
    return Radio.fromJson(response.data);
  }

  Future<Radio> patchRadio(int id, Map<String, dynamic> body) async {
    final response = await _dio.patch(
      '$_baseUrl/api/v1/radios/radios/$id/',
      data: body,
    );
    return Radio.fromJson(response.data);
  }

  Future<void> deleteRadio(int id) async {
    await _dio.delete('$_baseUrl/api/v1/radios/radios/$id/');
  }

  Future<Track> getRadioTrack(int id) async {
    final opts =
        _lastRadioSessionCookie != null
            ? Options(headers: {'cookie': _lastRadioSessionCookie})
            : null;
    final response = await _dio.get(
      '$_baseUrl/api/v1/radios/radios/$id/tracks/',
      options: opts,
    );

    final data = response.data;
    // Common full track payload
    if (data is Map<String, dynamic>) {
      if (data.containsKey('id') && data.containsKey('listen_url')) {
        return Track.fromJson(data);
      }
      if (data.containsKey('track')) {
        final t = data['track'];
        if (t is Map<String, dynamic>) return Track.fromJson(t);
        if (t is int) return getTrack(t);
        if (t is String && int.tryParse(t) != null)
          return getTrack(int.parse(t));
      }
      if (data.containsKey('results') &&
          data['results'] is List &&
          (data['results'] as List).isNotEmpty) {
        final first = (data['results'] as List).first;
        if (first is Map<String, dynamic>) return Track.fromJson(first);
        if (first is int) return getTrack(first);
      }
      // If it's a simple id map like {"id": 123}
      if (data.containsKey('id') && data.keys.length == 1) {
        final idVal = data['id'];
        if (idVal is int) return getTrack(idVal);
        if (idVal is String && int.tryParse(idVal) != null)
          return getTrack(int.parse(idVal));
      }
    }

    if (data is int) return getTrack(data);
    if (data is String && int.tryParse(data) != null)
      return getTrack(int.parse(data));
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is Map<String, dynamic>) return Track.fromJson(first);
      if (first is int) return getTrack(first);
    }

    // Fallback: try to parse as track map and hope for the best
    return Track.fromJson(data as Map<String, dynamic>);
  }

  Future<Filter> getRadioFilters() async {
    final response = await _dio.get('$_baseUrl/api/v1/radios/radios/filters/');
    final data = response.data;
    if (data is Map<String, dynamic>) return Filter.fromJson(data);
    if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
      return Filter.fromJson(data.first as Map<String, dynamic>);
    }
    throw StateError('Unexpected radio filters response: ${data.runtimeType}');
  }

  Future<Radio> validateRadio(Map<String, dynamic> body) async {
    final response = await _dio.post(
      '$_baseUrl/api/v1/radios/radios/validate/',
      data: body,
    );
    return Radio.fromJson(response.data);
  }

  Future<RadioSession> createRadioSession(Map<String, dynamic> body) async {
    dynamic _fromResponse(dynamic data) {
      if (data is Map<String, dynamic>) return RadioSession.fromJson(data);
      if (data is int) return RadioSession(id: data);
      if (data is String) {
        final parsed = int.tryParse(data);
        if (parsed != null) return RadioSession(id: parsed);
      }
      throw StateError(
        'Unexpected radio session response: ${data.runtimeType}',
      );
    }

    try {
      final response = await _dio.post(
        '$_baseUrl/api/v1/radios/sessions/',
        data: body,
      );
      // Capture set-cookie header if provided by server
      final setCookie = response.headers.map['set-cookie'];
      if (setCookie != null && setCookie.isNotEmpty) {
        _lastRadioSessionCookie = setCookie.join(';');
      }
      return _fromResponse(response.data);
    } on DioException catch (e) {
      // Some Funkwhale instances are picky about the request encoding.
      // Log diagnostics and retry as form-encoded (matches schema alternatives).
      // The caller should already surface the exception, but a retry here
      // improves compatibility with servers that expect x-www-form-urlencoded.
      // Primary attempt failed; continue with compatibility retries silently.

      // Retry as form-encoded
      try {
        final opts = Options(contentType: Headers.formUrlEncodedContentType);
        final response = await _dio.post(
          '$_baseUrl/api/v1/radios/sessions/',
          data: body,
          options: opts,
        );
        final setCookie = response.headers.map['set-cookie'];
        if (setCookie != null && setCookie.isNotEmpty) {
          _lastRadioSessionCookie = setCookie.join(';');
        }
        return _fromResponse(response.data);
      } on DioException catch (e2) {
        // Mask authorization header when printing
        final headers = Map.of(e2.requestOptions.headers);
        if (headers.containsKey('Authorization')) {
          headers['Authorization'] = 'REDACTED';
        }
        // Form-encoded retry failed; proceed to minimal-body retry silently.

        // As a last attempt try a minimal body (only radio_type) which some
        // Funkwhale instances accept for generic radios.
        try {
          final response = await _dio.post(
            '$_baseUrl/api/v1/radios/sessions/',
            data: {'radio_type': body['radio_type']},
          );
          final setCookie = response.headers.map['set-cookie'];
          if (setCookie != null && setCookie.isNotEmpty) {
            _lastRadioSessionCookie = setCookie.join(';');
          }
          return _fromResponse(response.data);
        } on DioException catch (e3) {
          final headers3 = Map.of(e3.requestOptions.headers);
          if (headers3.containsKey('Authorization'))
            headers3['Authorization'] = 'REDACTED';
          // Minimal-body attempt also failed; rethrow so caller can handle.
          rethrow;
        }
      }
    }
  }

  Future<RadioSession> getRadioSession(int id) async {
    final response = await _dio.get('$_baseUrl/api/v1/radios/sessions/$id/');
    return RadioSession.fromJson(response.data);
  }

  // ── Libraries ───────────────────────────────────────────────────────

  Future<PaginatedResponse<Library>> getLibraries({
    int page = 1,
    int pageSize = 50,
    String? scope,
  }) async {
    final response = await _dio.get(
      '$_baseUrl/api/v1/libraries/',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (scope != null) 'scope': scope,
      },
    );
    return PaginatedResponse.fromJson(response.data, Library.fromJson);
  }

  Future<Library> createLibrary({
    required String name,
    String privacyLevel = 'me',
    String? description,
  }) async {
    final response = await _dio.post(
      '$_baseUrl/api/v1/libraries/',
      data: {
        'name': name,
        'privacy_level': privacyLevel,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    return Library.fromJson(response.data);
  }

  // ── Uploads ─────────────────────────────────────────────────────────

  Future<UploadForOwner> createUpload({
    required String libraryUuid,
    required String filePath,
    required String fileName,
    Map<String, dynamic>? importMetadata,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final formData = FormData.fromMap({
      'library': libraryUuid,
      'audio_file': await MultipartFile.fromFile(filePath, filename: fileName),
      if (importMetadata != null) 'import_metadata': jsonEncode(importMetadata),
    });

    final response = await _dio.post(
      '$_baseUrl/api/v1/uploads/',
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(
        sendTimeout: const Duration(minutes: 30),
        receiveTimeout: const Duration(minutes: 5),
        contentType: 'multipart/form-data',
      ),
    );
    return UploadForOwner.fromJson(response.data);
  }

  /// Fetches the current state of an upload by its import reference.
  ///
  /// Uses the list endpoint filtered by import_reference rather than the
  /// retrieve endpoint (`GET /api/v1/uploads/<uuid>/`), because the retrieve
  /// endpoint is backed by `playable_by()` which only returns uploads with
  /// import_status "finished" or "skipped" — it 404s while the upload is
  /// still pending or errored.
  Future<UploadForOwner?> getUploadByReference(String importReference) async {
    final response = await _dio.get(
      '$_baseUrl/api/v1/uploads/',
      queryParameters: {'import_reference': importReference, 'page_size': 1},
    );
    final results = response.data['results'] as List<dynamic>? ?? [];
    if (results.isEmpty) return null;
    return UploadForOwner.fromJson(results.first as Map<String, dynamic>);
  }

  // ── Radio tracks ────────────────────────────────────────────────────

  Future<RadioSessionTrackCreate> getNextRadioTrack(
    int session, {
    int? count,
  }) async {
    final headers = <String, dynamic>{};
    if (_lastRadioSessionCookie != null)
      headers['cookie'] = _lastRadioSessionCookie;
    final response = await _dio.post(
      '$_baseUrl/api/v1/radios/tracks/',
      data: {'session': session, if (count != null) 'count': count},
      options: Options(headers: headers),
    );
    return RadioSessionTrackCreate.fromJson(response.data);
  }

  /// Post to the radios/tracks endpoint and return the raw response body.
  /// Some servers return a Track object, others a small serializer object;
  /// callers may need to handle both shapes, so provide the raw dynamic
  /// response here.
  Future<dynamic> postNextRadioTrackRaw(int session, {int? count}) async {
    final headers = <String, dynamic>{};
    if (_lastRadioSessionCookie != null)
      headers['cookie'] = _lastRadioSessionCookie;
    final response = await _dio.post(
      '$_baseUrl/api/v1/radios/tracks/',
      data: {'session': session, if (count != null) 'count': count},
      options: Options(headers: headers),
    );
    return response.data;
  }
}
