import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/cache/cache_manager.dart';

/// Provider for the cache manager instance
final cacheManagerProvider = Provider<CacheManager>((ref) {
  return CacheManager.instance;
});

/// Provider for cache statistics
final cacheStatsProvider = FutureProvider<CacheStats>((ref) async {
  final cache = ref.watch(cacheManagerProvider);
  return await cache.getStats();
});

/// Provider for current cache size limit in MB
final cacheSizeLimitProvider = FutureProvider<int>((ref) async {
  final config = await CacheConfig.load();
  return config.maxTotalSizeBytes ~/ (1024 * 1024);
});
