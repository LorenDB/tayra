import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/models.dart';
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

// ── Bulk track ID sets ──────────────────────────────────────────────────
//
// List tiles used to fire per-row FutureProviders that each listed the audio
// cache directory and/or hit SQLite. That blocked the UI isolate during scroll.
// These notifiers load once and support incremental add/remove so download
// indicators stay live without re-scanning disk for every visible row.

/// All track IDs that have a cached audio file (from the cache DB).
final cachedAudioTrackIdsProvider =
    NotifierProvider<CachedAudioTrackIdsNotifier, Set<int>>(
      CachedAudioTrackIdsNotifier.new,
    );

class CachedAudioTrackIdsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    Future.microtask(refresh);
    return const {};
  }

  Future<void> refresh() async {
    try {
      final ids = await ref.read(cacheManagerProvider).getCachedAudioTrackIds();
      state = ids.toSet();
    } catch (_) {}
  }

  void add(int trackId) {
    if (state.contains(trackId)) return;
    state = {...state, trackId};
  }

  void remove(int trackId) {
    if (!state.contains(trackId)) return;
    state = {...state}..remove(trackId);
  }

  void addAll(Iterable<int> trackIds) {
    final next = {...state, ...trackIds};
    if (next.length == state.length && next.containsAll(state)) return;
    state = next;
  }

  void removeAll(Iterable<int> trackIds) {
    final next = {...state}..removeAll(trackIds);
    if (next.length == state.length) return;
    state = next;
  }
}

/// All track IDs marked as manually downloaded by the user.
final manualTrackIdsProvider =
    NotifierProvider<ManualTrackIdsNotifier, Set<int>>(
      ManualTrackIdsNotifier.new,
    );

class ManualTrackIdsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    Future.microtask(refresh);
    return const {};
  }

  Future<void> refresh() async {
    try {
      final ids =
          await ref.read(cacheManagerProvider).getManualDownloadedTrackIds();
      state = ids.toSet();
    } catch (_) {}
  }

  void add(int trackId) {
    if (state.contains(trackId)) return;
    state = {...state, trackId};
  }

  void remove(int trackId) {
    if (!state.contains(trackId)) return;
    state = {...state}..remove(trackId);
  }

  void addAll(Iterable<int> trackIds) {
    final next = {...state, ...trackIds};
    if (next.length == state.length && next.containsAll(state)) return;
    state = next;
  }

  void removeAll(Iterable<int> trackIds) {
    final next = {...state}..removeAll(trackIds);
    if (next.length == state.length) return;
    state = next;
  }
}

/// Whether a track has cached audio. Backed by [cachedAudioTrackIdsProvider]
/// so list UIs share one bulk membership set instead of N directory scans.
final isAudioCachedProvider = Provider.family<bool, int>((ref, trackId) {
  return ref.watch(
    cachedAudioTrackIdsProvider.select((ids) => ids.contains(trackId)),
  );
});

/// Whether a track is marked as manually downloaded. Backed by
/// [manualTrackIdsProvider] (bulk set) for the same reason.
final isManualTrackProvider = Provider.family<bool, int>((ref, trackId) {
  return ref.watch(
    manualTrackIdsProvider.select((ids) => ids.contains(trackId)),
  );
});

// ── Bulk album / playlist manual-download sets ──────────────────────────
//
// Same pattern as tracks: load once into memory so detail headers and grids
// never issue a per-id SQLite query during build/scroll.

/// All album IDs marked as manually downloaded.
final manualAlbumIdsProvider =
    NotifierProvider<ManualAlbumIdsNotifier, Set<int>>(
      ManualAlbumIdsNotifier.new,
    );

class ManualAlbumIdsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    Future.microtask(refresh);
    return const {};
  }

  Future<void> refresh() async {
    try {
      final ids = await ref
          .read(cacheManagerProvider)
          .getManualDownloadedIds(CacheType.album);
      state = ids.toSet();
    } catch (_) {}
  }

  void add(int albumId) {
    if (state.contains(albumId)) return;
    state = {...state, albumId};
  }

  void remove(int albumId) {
    if (!state.contains(albumId)) return;
    state = {...state}..remove(albumId);
  }
}

/// All playlist IDs marked as manually downloaded.
final manualPlaylistIdsProvider =
    NotifierProvider<ManualPlaylistIdsNotifier, Set<int>>(
      ManualPlaylistIdsNotifier.new,
    );

class ManualPlaylistIdsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    Future.microtask(refresh);
    return const {};
  }

  Future<void> refresh() async {
    try {
      final ids = await ref
          .read(cacheManagerProvider)
          .getManualDownloadedIds(CacheType.playlist);
      state = ids.toSet();
    } catch (_) {}
  }

  void add(int playlistId) {
    if (state.contains(playlistId)) return;
    state = {...state, playlistId};
  }

  void remove(int playlistId) {
    if (!state.contains(playlistId)) return;
    state = {...state}..remove(playlistId);
  }
}

/// Whether an album is marked as manually downloaded (in-memory set).
final isManualAlbumProvider = Provider.family<bool, int>((ref, albumId) {
  return ref.watch(
    manualAlbumIdsProvider.select((ids) => ids.contains(albumId)),
  );
});

/// Whether a playlist is marked as manually downloaded (in-memory set).
final isManualPlaylistProvider = Provider.family<bool, int>((ref, playlistId) {
  return ref.watch(
    manualPlaylistIdsProvider.select((ids) => ids.contains(playlistId)),
  );
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

// ── Offline availability providers ──────────────────────────────────────

/// All track IDs that are playable offline (cached audio or manually downloaded).
///
/// Derived from the bulk in-memory sets when possible so offline filtering does
/// not issue a separate full-table scan while list tiles are scrolling.
final offlineTrackIdsProvider = Provider<Set<int>>((ref) {
  final cached = ref.watch(cachedAudioTrackIdsProvider);
  final manual = ref.watch(manualTrackIdsProvider);
  if (manual.isEmpty) return cached;
  if (cached.isEmpty) return manual;
  return {...cached, ...manual};
});

/// All album IDs that have at least one offline-available track.
final offlineAlbumIdsProvider = FutureProvider<Set<int>>((ref) async {
  final mgr = ref.watch(cacheManagerProvider);
  return await mgr.getOfflineAlbumIds();
});

/// All cached album metadata available locally.
final cachedAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final mgr = ref.watch(cacheManagerProvider);
  return await mgr.getCachedAlbums();
});

/// All cached album metadata that is available offline.
final offlineAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final mgr = ref.watch(cacheManagerProvider);
  return await mgr.getOfflineAlbums();
});

/// All artist IDs that are marked as manually downloaded offline.
final offlineArtistIdsProvider = FutureProvider<Set<int>>((ref) async {
  final mgr = ref.watch(cacheManagerProvider);
  return await mgr.getOfflineArtistIds();
});
