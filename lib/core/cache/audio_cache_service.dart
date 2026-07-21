import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:tayra/core/api/http_client_factory.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/cache/cache_manager.dart';

/// Service for caching audio files and cover art
class AudioCacheService {
  final CacheManager _cache;

  /// Dedicated Dio instance for file downloads — no receive timeout so that
  /// large audio files (which can take several minutes on slow connections)
  /// are not incorrectly aborted.
  final Dio _dio = createDio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      // No receiveTimeout: audio files can be very large and take a long
      // time to download. The shared dioProvider sets receiveTimeout=30s
      // which silently killed every background cache download.
    ),
  );

  /// In-flight audio downloads by track id. Concurrent callers share the same
  /// future instead of returning null and treating a race as failure.
  final Map<int, Future<File?>> _audioFutures = {};

  /// Cap concurrent cover downloads so list/page fetches cannot flood the
  /// network and disk while the user is scrolling.
  static const int _maxConcurrentCoverDownloads = 3;
  int _activeCoverDownloads = 0;
  final List<Completer<void>> _coverWaiters = [];

  /// In-flight cover downloads by URL so concurrent list cells await the same
  /// download rather than missing art until a later rebuild.
  final Map<String, Future<File?>> _coverFutures = {};

  AudioCacheService(this._cache);

  Future<void> _acquireCoverSlot() async {
    if (_activeCoverDownloads < _maxConcurrentCoverDownloads) {
      _activeCoverDownloads++;
      return;
    }
    final waiter = Completer<void>();
    _coverWaiters.add(waiter);
    await waiter.future;
    _activeCoverDownloads++;
  }

  void _releaseCoverSlot() {
    _activeCoverDownloads = (_activeCoverDownloads - 1).clamp(
      0,
      _maxConcurrentCoverDownloads,
    );
    if (_coverWaiters.isNotEmpty) {
      final next = _coverWaiters.removeAt(0);
      if (!next.isCompleted) next.complete();
    }
  }

  /// Release resources. Call when the service is no longer needed.
  void dispose() {
    _dio.close(force: true);
  }

  /// Get cached audio file for a track, or null if not cached
  Future<File?> getCachedAudio(Track track) async {
    final key = 'audio_${track.id}';
    return await _cache.getFile(key);
  }

  /// Download and cache an audio file for a track.
  ///
  /// Concurrent callers for the same track share one in-flight future.
  Future<File?> cacheAudio(
    Track track,
    String streamUrl,
    Map<String, String> authHeaders, {
    void Function(int, int)? onProgress,
  }) {
    final existingFuture = _audioFutures[track.id];
    if (existingFuture != null) return existingFuture;

    final future = _cacheAudioImpl(
      track,
      streamUrl,
      authHeaders,
      onProgress: onProgress,
    );
    _audioFutures[track.id] = future;
    future.whenComplete(() {
      if (identical(_audioFutures[track.id], future)) {
        _audioFutures.remove(track.id);
      }
    });
    return future;
  }

  Future<File?> _cacheAudioImpl(
    Track track,
    String streamUrl,
    Map<String, String> authHeaders, {
    void Function(int, int)? onProgress,
  }) async {
    File? tempFile;
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
      tempFile = File(tempPath);

      // Download the file
      await _dio.download(
        streamUrl,
        tempPath,
        options: Options(headers: authHeaders),
        onReceiveProgress: onProgress,
      );

      // Cache the file. If the track or its album is manually marked as
      // downloaded, persist the file as protected immediately so the LRU
      // eviction skips it.
      final key = 'audio_${track.id}';
      final isTrackManual = await _cache.isManualDownloaded(
        CacheType.track,
        track.id,
      );
      final isAlbumManual =
          track.album != null
              ? await _cache.isManualDownloaded(
                CacheType.album,
                track.album!.id,
              )
              : false;
      final isProtected = isTrackManual || isAlbumManual;
      await _cache.putFile(
        key,
        FileType.audio,
        tempFile,
        resourceId: track.id,
        resourceParentType: track.album != null ? CacheType.album : null,
        resourceParentId: track.album?.id,
        isProtected: isProtected,
        albumTitle: track.album?.title,
        albumArtistName: track.album?.artist?.name ?? track.artistName,
        albumCoverUrl: track.album?.coverUrl ?? track.coverUrl,
      );

      // Return the cached file
      return await _cache.getFile(key);
    } catch (e) {
      debugPrint(
        'AudioCacheService: failed to cache audio for track ${track.id}: $e',
      );
      return null;
    } finally {
      // Always remove the temp download (success path copies into the cache).
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  /// Check if an audio file is cached.
  ///
  /// The filesystem is the primary source of truth: if the file exists on
  /// disk (matching `audio_<trackId>.*`) the track is considered cached,
  /// regardless of whether a DB row is present.  This prevents false-negatives
  /// caused by DB/filesystem divergence (e.g. a successful download where the
  /// DB insert subsequently failed).
  Future<bool> isAudioCached(int trackId) async {
    // Filesystem check first — fast and authoritative.
    if (await _cache.audioFileExistsOnDisk(trackId)) return true;
    // Fall back to DB in case the audio dir isn't readable for some reason.
    final key = 'audio_$trackId';
    final file = await _cache.getFile(key);
    return file != null;
  }

  /// Delete cached audio for a track
  Future<void> deleteCachedAudio(int trackId) async {
    final key = 'audio_$trackId';
    await _cache.deleteFile(key);
  }

  /// In-memory path cache so list tiles do not re-hit SQLite for the same URL
  /// during a scroll session. Values are absolute paths, or `null` for a known
  /// miss (so we do not keep probing).
  final Map<String, String?> _coverPathMemory = {};

  /// Get cached cover art file, or null if not cached.
  ///
  /// Results are memoized in-process for the lifetime of this service so
  /// dense grids (e.g. offline albums) do not re-query SQLite per rebuild.
  Future<File?> getCachedCoverArt(String coverUrl) async {
    if (coverUrl.isEmpty) return null;
    if (_coverPathMemory.containsKey(coverUrl)) {
      final path = _coverPathMemory[coverUrl];
      if (path == null) return null;
      final file = File(path);
      if (await file.exists()) return file;
      _coverPathMemory.remove(coverUrl);
    }
    final key = coverCacheKey(coverUrl);
    final file = await _cache.getFile(key);
    _coverPathMemory[coverUrl] = file?.path;
    return file;
  }

  /// Download and cache cover art.
  ///
  /// Concurrent callers for the same URL share one in-flight future.
  Future<File?> cacheCoverArt(String coverUrl) {
    if (coverUrl.isEmpty) return Future.value(null);
    final existingFuture = _coverFutures[coverUrl];
    if (existingFuture != null) return existingFuture;

    final future = _cacheCoverArtImpl(coverUrl);
    _coverFutures[coverUrl] = future;
    future.whenComplete(() {
      if (identical(_coverFutures[coverUrl], future)) {
        _coverFutures.remove(coverUrl);
      }
    });
    return future;
  }

  Future<File?> _cacheCoverArtImpl(String coverUrl) async {
    File? tempFile;
    try {
      // Check if already cached (cheap) before taking a concurrency slot.
      final existing = await getCachedCoverArt(coverUrl);
      if (existing != null) return existing;

      await _acquireCoverSlot();
      try {
        // Re-check after waiting for a slot — another download may have won.
        final existingAfterWait = await getCachedCoverArt(coverUrl);
        if (existingAfterWait != null) return existingAfterWait;

        // Create temp file to download to
        final tempDir = await getTemporaryDirectory();
        final extension =
            p.extension(coverUrl).split('?').first; // Remove query params
        final tempPath = p.join(
          tempDir.path,
          'download_cover_${DateTime.now().millisecondsSinceEpoch}$extension',
        );
        tempFile = File(tempPath);

        // Download the file
        await _dio.download(coverUrl, tempPath);

        // Cache the file
        final key = coverCacheKey(coverUrl);
        await _cache.putFile(key, FileType.coverArt, tempFile);

        // Return the cached file
        final cached = await _cache.getFile(key);
        rememberCoverPath(coverUrl, cached?.path);
        return cached;
      } finally {
        _releaseCoverSlot();
      }
    } catch (e) {
      debugPrint(
        'AudioCacheService: failed to cache cover art for $coverUrl: $e',
      );
      return null;
    } finally {
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  /// Check if cover art is cached
  Future<bool> isCoverArtCached(String coverUrl) async {
    final file = await getCachedCoverArt(coverUrl);
    return file != null;
  }

  /// Invalidate the in-memory cover path entry after a successful download
  /// so subsequent [getCachedCoverArt] calls see the new file.
  void rememberCoverPath(String coverUrl, String? path) {
    _coverPathMemory[coverUrl] = path;
  }

  /// Delete cached cover art for a given URL, including in-memory state
  /// so that subsequent [getCachedCoverArt] calls re-query from disk.
  Future<void> deleteCachedCoverArt(String coverUrl) async {
    if (coverUrl.isEmpty) return;
    _coverPathMemory.remove(coverUrl);
    _coverFutures.remove(coverUrl);
    await _cache.deleteFile(coverCacheKey(coverUrl));
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
  /// Funkwhale cover URLs often use a generic filename like `cover.jpg` and
  /// may include query parameters to request resized variants.  Use the
  /// full path _and_ query string when present so different thumbnail
  /// sizes get separate cache keys instead of colliding.
  String coverCacheKey(String url) {
    final uri = Uri.parse(url);
    final pathAndQuery = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    return 'cover_${pathAndQuery.hashCode.toRadixString(16)}';
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
        // Fire and forget — don't await
        unawaited(cacheAudio(track, streamUrl, authHeaders));
      }
    }
  }
}
