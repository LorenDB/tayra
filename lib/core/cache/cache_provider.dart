import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/cache/audio_cache_service.dart';
import 'package:tayra/core/cache/cache_manager.dart';

/// Provider for the cache manager instance
final cacheManagerProvider = Provider<CacheManager>((ref) {
  return CacheManager.instance;
});

/// Provider for the audio/cover-art cache service (singleton)
final audioCacheServiceProvider = Provider<AudioCacheService>((ref) {
  return AudioCacheService(CacheManager.instance);
});

/// Provider that reports whether a given track ID has cached audio.
final isAudioCachedProvider = FutureProvider.family<bool, int>((
  ref,
  trackId,
) async {
  final svc = ref.watch(audioCacheServiceProvider);
  return await svc.isAudioCached(trackId);
});

/// Provider that reports whether a given resource (track) has been marked as
/// manually downloaded by the user.
final isManualTrackProvider = FutureProvider.family<bool, int>((
  ref,
  trackId,
) async {
  final mgr = ref.watch(cacheManagerProvider);
  return await mgr.isManualDownloaded(CacheType.track, trackId);
});

// Providers for other resource types (album, playlist)
final isManualAlbumProvider = FutureProvider.family<bool, int>((
  ref,
  albumId,
) async {
  final mgr = ref.watch(cacheManagerProvider);
  return await mgr.isManualDownloaded(CacheType.album, albumId);
});

final isManualPlaylistProvider = FutureProvider.family<bool, int>((
  ref,
  playlistId,
) async {
  final mgr = ref.watch(cacheManagerProvider);
  return await mgr.isManualDownloaded(CacheType.playlist, playlistId);
});

/// Provider for cache statistics (autoDispose so it refreshes each time the
/// settings screen is opened rather than showing stale numbers).
final cacheStatsProvider = FutureProvider.autoDispose<CacheStats>((ref) async {
  final cache = ref.watch(cacheManagerProvider);
  return await cache.getStats();
});

/// Provider for current cache size limit in MB
final cacheSizeLimitProvider = FutureProvider<int>((ref) async {
  final config = await CacheConfig.load();
  // Return limit in decimal MB (1 MB = 1,000,000 bytes) to match UI slider
  return config.maxTotalSizeBytes ~/ 1000000;
});
