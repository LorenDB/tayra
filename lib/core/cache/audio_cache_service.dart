import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/api/models.dart';

/// Service for caching audio files and cover art
class AudioCacheService {
  final CacheManager _cache;

  /// Dedicated Dio instance for file downloads — no receive timeout so that
  /// large audio files (which can take several minutes on slow connections)
  /// are not incorrectly aborted.
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      // No receiveTimeout: audio files can be very large and take a long
      // time to download. The shared dioProvider sets receiveTimeout=30s
      // which silently killed every background cache download.
    ),
  );

  /// Track IDs currently being downloaded to prevent duplicate concurrent
  /// downloads of the same audio file (e.g. if the user skips back quickly).
  final Set<int> _inProgressAudio = {};

  AudioCacheService(this._cache);

  /// Get cached audio file for a track, or null if not cached
  Future<File?> getCachedAudio(Track track) async {
    final key = 'audio_${track.id}';
    return await _cache.getFile(key);
  }

  /// Download and cache an audio file for a track
  Future<File?> cacheAudio(
    Track track,
    String streamUrl,
    Map<String, String> authHeaders, {
    void Function(int, int)? onProgress,
  }) async {
    // Bail out if a download for this track is already in progress.
    if (_inProgressAudio.contains(track.id)) return null;

    // Mark as in-progress immediately (before any await) to prevent a second
    // concurrent call from slipping past the guard above.
    _inProgressAudio.add(track.id);

    try {
      // Check if already cached
      final existing = await getCachedAudio(track);
      if (existing != null) return existing;

      // Create temp file to download to
      final tempDir = await getTemporaryDirectory();
      final ext = _audioExtension(track);
      final tempPath = p.join(
        tempDir.path,
        'download_audio_${track.id}_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      final tempFile = File(tempPath);

      // Download the file
      await _dio.download(
        streamUrl,
        tempPath,
        options: Options(headers: authHeaders),
        onReceiveProgress: onProgress,
      );

      // Cache the file
      final key = 'audio_${track.id}';
      await _cache.putFile(key, FileType.audio, tempFile, resourceId: track.id);

      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      // Return the cached file
      return await _cache.getFile(key);
    } catch (e) {
      debugPrint(
        'AudioCacheService: failed to cache audio for track ${track.id}: $e',
      );
      return null;
    } finally {
      _inProgressAudio.remove(track.id);
    }
  }

  /// Check if an audio file is cached
  Future<bool> isAudioCached(int trackId) async {
    final key = 'audio_$trackId';
    final file = await _cache.getFile(key);
    return file != null;
  }

  /// Delete cached audio for a track
  Future<void> deleteCachedAudio(int trackId) async {
    final key = 'audio_$trackId';
    await _cache.deleteFile(key);
  }

  /// Get cached cover art file, or null if not cached
  Future<File?> getCachedCoverArt(String coverUrl) async {
    final key = _getCoverKey(coverUrl);
    return await _cache.getFile(key);
  }

  /// Download and cache cover art
  Future<File?> cacheCoverArt(String coverUrl) async {
    try {
      // Check if already cached
      final existing = await getCachedCoverArt(coverUrl);
      if (existing != null) return existing;

      // Create temp file to download to
      final tempDir = await getTemporaryDirectory();
      final extension =
          p.extension(coverUrl).split('?').first; // Remove query params
      final tempPath = p.join(
        tempDir.path,
        'download_cover_${DateTime.now().millisecondsSinceEpoch}$extension',
      );
      final tempFile = File(tempPath);

      // Download the file
      await _dio.download(coverUrl, tempPath);

      // Cache the file
      final key = _getCoverKey(coverUrl);
      await _cache.putFile(key, FileType.coverArt, tempFile);

      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      // Return the cached file
      return await _cache.getFile(key);
    } catch (e) {
      debugPrint(
        'AudioCacheService: failed to cache cover art for $coverUrl: $e',
      );
      return null;
    }
  }

  /// Check if cover art is cached
  Future<bool> isCoverArtCached(String coverUrl) async {
    final key = _getCoverKey(coverUrl);
    final file = await _cache.getFile(key);
    return file != null;
  }

  /// Derive a file extension for an audio track's temp download file.
  ///
  /// Uses the MIME type from the track's first upload if available, so that
  /// FLAC, Ogg/Opus, AAC, etc. get the right extension rather than always
  /// `.mp3`.  Falls back to `.mp3` when no MIME type is known.
  String _audioExtension(Track track) {
    final mime = track.uploads.isNotEmpty ? track.uploads.first.mimetype : null;
    if (mime == null) return '.mp3';
    const mimeToExt = {
      'audio/mpeg': '.mp3',
      'audio/mp3': '.mp3',
      'audio/flac': '.flac',
      'audio/x-flac': '.flac',
      'audio/ogg': '.ogg',
      'audio/opus': '.opus',
      'audio/aac': '.aac',
      'audio/mp4': '.m4a',
      'audio/x-m4a': '.m4a',
      'audio/wav': '.wav',
      'audio/x-wav': '.wav',
      'audio/webm': '.webm',
    };
    // Strip codec parameter (e.g. "audio/ogg; codecs=opus" → "audio/ogg")
    final baseType = mime.split(';').first.trim().toLowerCase();
    return mimeToExt[baseType] ?? '.mp3';
  }

  /// Get cache key for a cover URL.
  ///
  /// Funkwhale cover URLs typically end in a generic filename like
  /// `cover.jpg`, so using only the last path segment causes every album
  /// and artist cover to collide on the same key.  Instead we hash the
  /// full path (without query string) to produce a stable, unique key.
  String _getCoverKey(String url) {
    final uri = Uri.parse(url);
    // Use the full path without query params for uniqueness.
    final path = uri.path;
    return 'cover_${path.hashCode.toRadixString(16)}';
  }

  /// Pre-cache tracks from an album (background operation)
  Future<void> preCacheAlbum(
    List<Track> tracks,
    String Function(String) getStreamUrl,
    Map<String, String> authHeaders,
  ) async {
    // Cache up to 10 tracks from the album in the background
    final tracksToCache = tracks.take(10);

    for (final track in tracksToCache) {
      if (track.listenUrl != null) {
        final streamUrl = getStreamUrl(track.listenUrl!);
        // Fire and forget - don't await
        cacheAudio(track, streamUrl, authHeaders);
      }
    }
  }
}
