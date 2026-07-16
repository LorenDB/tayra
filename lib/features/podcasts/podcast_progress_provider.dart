import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/cache/cache_database.dart';
import 'package:tayra/features/podcasts/podcast_progress_service.dart';

// ── Service provider ────────────────────────────────────────────────────

final podcastProgressServiceProvider = Provider<PodcastProgressService>((ref) {
  return PodcastProgressService(CacheDatabase.instance);
});

// ── Per-channel progress map ────────────────────────────────────────────

/// Live map of trackId → progress for a channel. Invalidate after mutations.
final channelEpisodeProgressProvider = FutureProvider.autoDispose
    .family<Map<int, PodcastEpisodeProgress>, String>((ref, channelUuid) async {
      final svc = ref.watch(podcastProgressServiceProvider);
      return svc.getProgressForChannel(channelUuid);
    });

/// Single-track progress (e.g. now-playing helpers).
final episodeProgressProvider = FutureProvider.autoDispose
    .family<PodcastEpisodeProgress?, int>((ref, trackId) async {
      final svc = ref.watch(podcastProgressServiceProvider);
      return svc.getProgress(trackId);
    });
