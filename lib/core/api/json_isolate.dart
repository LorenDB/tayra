import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tayra/core/api/api_client.dart';
import 'package:tayra/core/api/models.dart';

/// Parse large paginated JSON payloads off the UI isolate.
///
/// Dio already decodes JSON to Maps on the main isolate; for big `results`
/// arrays the expensive part is nested [fromJson] graph construction, which
/// we move to a background isolate via a JSON round-trip.
const int kIsolateParseMinResults = 15;

Future<PaginatedResponse<Track>> parseTracksPage(dynamic data) {
  return _parsePage(data, _parseTracksPageIsolate);
}

Future<PaginatedResponse<Album>> parseAlbumsPage(dynamic data) {
  return _parsePage(data, _parseAlbumsPageIsolate);
}

Future<PaginatedResponse<Artist>> parseArtistsPage(dynamic data) {
  return _parsePage(data, _parseArtistsPageIsolate);
}

Future<PaginatedResponse<Favorite>> parseFavoritesPage(dynamic data) {
  return _parsePage(data, _parseFavoritesPageIsolate);
}

Future<PaginatedResponse<PlaylistTrack>> parsePlaylistTracksPage(dynamic data) {
  return _parsePage(data, _parsePlaylistTracksPageIsolate);
}

Future<PaginatedResponse<T>> _parsePage<T>(
  dynamic data,
  PaginatedResponse<T> Function(String) isolateEntry,
) async {
  if (data is! Map) {
    return PaginatedResponse<T>(count: 0, results: const []);
  }
  final map = Map<String, dynamic>.from(data);
  final results = map['results'];
  final count = results is List ? results.length : 0;
  if (count < kIsolateParseMinResults) {
    // Small pages: local parse is cheaper than isolate spin-up.
    return isolateEntry(jsonEncode(map));
  }
  return compute(isolateEntry, jsonEncode(map));
}

PaginatedResponse<Track> _parseTracksPageIsolate(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return PaginatedResponse.fromJson(json, Track.fromJson);
}

PaginatedResponse<Album> _parseAlbumsPageIsolate(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return PaginatedResponse.fromJson(json, Album.fromJson);
}

PaginatedResponse<Artist> _parseArtistsPageIsolate(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return PaginatedResponse.fromJson(json, Artist.fromJson);
}

PaginatedResponse<Favorite> _parseFavoritesPageIsolate(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return PaginatedResponse.fromJson(json, Favorite.fromJson);
}

PaginatedResponse<PlaylistTrack> _parsePlaylistTracksPageIsolate(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return PaginatedResponse.fromJson(json, PlaylistTrack.fromJson);
}
