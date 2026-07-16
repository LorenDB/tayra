import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/cache/download_queue_service.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/features/settings/settings_provider.dart';

// ── Coordinator ─────────────────────────────────────────────────────────

/// Central helper for auto-offline rules: enqueue favorites / podcast episodes
/// and respect Wi‑Fi-only download gating.
class AutoOfflineCoordinator {
  AutoOfflineCoordinator(this._ref);

  final Ref _ref;

  DownloadQueueService get _queue => _ref.read(downloadQueueServiceProvider);
  CacheManager get _cache => _ref.read(cacheManagerProvider);
  SettingsState get _settings => _ref.read(settingsProvider);

  /// Whether the download queue is currently allowed to process items.
  bool get downloadsAllowed {
    final wifiOnly = _settings.downloadWifiOnly;
    final connectivity = _ref.read(connectivityResultProvider);
    return connectivity.when(
      data:
          (results) => connectivityAllowsDownloads(results, wifiOnly: wifiOnly),
      // Optimistic: allow until we know otherwise (queue will fail gracefully).
      loading: () => true,
      error: (_, _) => true,
    );
  }

  /// Mark [trackIds] as manual downloads and enqueue missing audio.
  Future<void> enqueueTracksForOffline(
    List<int> trackIds, {
    String source = 'auto',
  }) async {
    if (trackIds.isEmpty) return;

    final cached = _ref.read(cachedAudioTrackIdsProvider);
    final missing =
        trackIds.where((id) => !cached.contains(id)).toList(growable: false);
    if (missing.isEmpty) return;

    for (final id in missing) {
      try {
        await _cache.setManualDownloaded(CacheType.track, id, true);
      } catch (_) {}
    }
    try {
      _ref.read(manualTrackIdsProvider.notifier).addAll(missing);
    } catch (_) {}

    await _queue.enqueue(missing, _ref);
    Analytics.track('auto_download_enqueued', {
      'count': missing.length,
      'source': source,
    });
  }

  /// When auto-download favorites is on, enqueue every favorite not yet cached.
  Future<void> reconcileFavorites(Set<int> favoriteIds) async {
    if (!_settings.autoDownloadFavorites) return;
    if (favoriteIds.isEmpty) return;
    await enqueueTracksForOffline(
      favoriteIds.toList(),
      source: 'favorites_reconcile',
    );
  }

  /// Enqueue a single newly favorited track when the setting is on.
  Future<void> onFavoriteAdded(int trackId) async {
    if (!_settings.autoDownloadFavorites) return;
    await enqueueTracksForOffline([trackId], source: 'favorite_added');
  }

  /// For a manually-downloaded playlist, enqueue any tracks not yet cached.
  Future<void> syncManualPlaylistTracks(List<int> trackIds) async {
    if (trackIds.isEmpty) return;
    await enqueueTracksForOffline(trackIds, source: 'playlist_sync');
  }

  /// Enqueue the newest [count] episodes of a channel that are not cached.
  Future<void> enqueueLatestPodcastEpisodes({
    required String channelUuid,
    required List<Track> episodesNewestFirst,
    int? count,
  }) async {
    if (!_settings.autoDownloadPodcastEpisodes) return;
    final n = count ?? _settings.autoDownloadPodcastEpisodeCount;
    if (n <= 0 || episodesNewestFirst.isEmpty) return;

    final slice =
        episodesNewestFirst.take(n).map((e) => e.id).toList(growable: false);
    await enqueueTracksForOffline(slice, source: 'podcast_auto');
  }

  /// Fetch subscribed channels and auto-download latest N for each.
  Future<void> reconcileSubscribedPodcasts() async {
    if (!_settings.autoDownloadPodcastEpisodes) return;
    try {
      final api = _ref.read(cachedFunkwhaleApiProvider);
      if (api.isOffline) return;

      final response = await api.getChannels(
        pageSize: 50,
        subscribed: true,
        forceRefresh: true,
      );
      final n = _settings.autoDownloadPodcastEpisodeCount;

      for (final channel in response.results) {
        try {
          // First page is enough — API orders by -creation_date (newest first).
          final page = await api.getChannelTracks(
            channelUuid: channel.uuid,
            page: 1,
            pageSize: n.clamp(1, 50),
          );
          await enqueueLatestPodcastEpisodes(
            channelUuid: channel.uuid,
            episodesNewestFirst: page.results,
            count: n,
          );
        } catch (e) {
          debugPrint(
            'AutoOffline: podcast reconcile failed for ${channel.uuid}: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('AutoOffline: subscribed podcasts reconcile failed: $e');
    }
  }

  /// Kick the download queue if connectivity now allows downloads.
  void maybeResumeDownloads() {
    if (!downloadsAllowed) return;
    _queue.processIfIdle(_ref);
  }
}

/// Singleton-style provider for the coordinator.
final autoOfflineCoordinatorProvider = Provider<AutoOfflineCoordinator>((ref) {
  return AutoOfflineCoordinator(ref);
});
