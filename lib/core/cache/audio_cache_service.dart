import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:funkwhale/core/cache/cache_manager.dart';
import 'package:funkwhale/core/api/models.dart';

/// Service for caching audio files and cover art
class AudioCacheService {
  final CacheManager _cache;
  final Dio _dio;

  AudioCacheService(this._cache, this._dio);

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
    try {
      // Check if already cached
      final existing = await getCachedAudio(track);
      if (existing != null) return existing;

      // Create temp file to download to
      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(
        tempDir.path,
        'download_audio_${track.id}_${DateTime.now().millisecondsSinceEpoch}.mp3',
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
      // Silent failure - audio caching is not critical
      return null;
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
      // Silent failure - cover art caching is not critical
      return null;
    }
  }

  /// Check if cover art is cached
  Future<bool> isCoverArtCached(String coverUrl) async {
    final key = _getCoverKey(coverUrl);
    final file = await _cache.getFile(key);
    return file != null;
  }

  /// Get cache key for a cover URL
  String _getCoverKey(String url) {
    // Use a hash of the URL as the key to keep it short
    // For simplicity, just use the last part of the path
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty) {
      return 'cover_${pathSegments.last.split('?').first}';
    }
    return 'cover_${url.hashCode}';
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
