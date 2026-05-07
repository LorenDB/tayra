import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';
import 'package:tayra/features/year_review/ai_summary_provider.dart';
import 'package:tayra/features/settings/settings_provider.dart';

// ── Providers ───────────────────────────────────────────────────────────

/// Available years that have listen data.
final availableYearsProvider = FutureProvider.autoDispose<List<int>>((
  ref,
) async {
  return await ListenHistoryService.getAvailableYears();
});

/// Year-in-review stats for a specific year, enriched with favorites data.
final yearReviewProvider = FutureProvider.autoDispose
    .family<YearReviewStats, int>((ref, year) async {
      final api = ref.read(cachedFunkwhaleApiProvider);

      // Fetch album IDs (local DB) and favorites (network) in parallel.
      final albumIdsF = ListenHistoryService.getDistinctAlbumIdsForYear(year);

      late List<Favorite> allFavorites;
      try {
        allFavorites = await fetchAllPages<Favorite>(
          (page) => api.getFavorites(page: page, pageSize: 100),
        );
      } catch (e) {
        debugPrint('yearReviewProvider: could not load favorites: $e');
        allFavorites = const [];
      }

      // Build album track counts map from the API for ratio-based sort.
      final albumIds = await albumIdsF;
      Map<int, int> albumTrackCounts = {};
      if (albumIds.isNotEmpty) {
        try {
          final response = await api.getAlbums(page: 1, pageSize: 500);
          for (final album in response.results) {
            if (album.tracksCount > 0) {
              albumTrackCounts[album.id] = album.tracksCount;
            }
          }
        } catch (e) {
          debugPrint(
            'yearReviewProvider: could not load album track counts: $e',
          );
        }
      }

      // Compute stats (local DB, fast) with ratio-based album sort.
      final stats = await ListenHistoryService.getYearStats(
        year,
        albumTrackCounts: albumTrackCounts,
      );

      // Partition top tracks into loved / unloved by matching against the
      // full favorites list by title + artist (TopItem only carries strings,
      // not IDs, so we can't use a Set<int> lookup here).
      final lovedTopTracks =
          stats.topTracks.where((t) {
            return allFavorites.any(
              (f) =>
                  f.track.title == t.name &&
                  (t.subtitle == null || f.track.artistName == t.subtitle),
            );
          }).toList();

      final unlovedTopTracks =
          stats.topTracks.where((t) {
            return !allFavorites.any(
              (f) =>
                  f.track.title == t.name &&
                  (t.subtitle == null || f.track.artistName == t.subtitle),
            );
          }).toList();

      // Tracks favorited specifically this year.
      final favoritedThisYear = await ListenHistoryService.getFavoritedThisYear(
        year,
        allFavorites,
      );

      return YearReviewStats(
        year: stats.year,
        totalListens: stats.totalListens,
        totalSeconds: stats.totalSeconds,
        uniqueTracks: stats.uniqueTracks,
        uniqueArtists: stats.uniqueArtists,
        uniqueAlbums: stats.uniqueAlbums,
        topTracks: stats.topTracks,
        topArtists: stats.topArtists,
        topAlbums: stats.topAlbums,
        monthlyBreakdown: stats.monthlyBreakdown,
        topTrack: stats.topTrack,
        topArtist: stats.topArtist,
        topAlbum: stats.topAlbum,
        favoritedThisYear: favoritedThisYear,
        lovedTopTracks: lovedTopTracks,
        unlovedTopTracks: unlovedTopTracks,
      );
    });

/// Total all-time listen count (used in settings to show data exists).
final totalListenCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return await ListenHistoryService.getTotalListenCount();
});

/// Listening stats for the past 7 days (used on the home screen).
final weeklyStatsProvider = FutureProvider.autoDispose<WeeklyStats>((ref) async {
  return ListenHistoryService.getWeekStats();
});

// ── Saturday stats visibility ────────────────────────────────────────────

const _keySaturdayStatsLastShown = 'saturday_stats_last_shown';

/// Whether the weekly stats section should be shown.
///
/// Returns true only on Saturdays when the stats haven't yet been shown
/// during the current calendar day.
final saturdayStatsVisibleProvider =
    NotifierProvider<SaturdayStatsNotifier, bool>(SaturdayStatsNotifier.new);

class SaturdayStatsNotifier extends Notifier<bool> {
  @override
  bool build() {
    Future.microtask(_evaluate);
    return false;
  }

  Future<void> _evaluate() async {
    final now = DateTime.now();
    if (now.weekday != DateTime.saturday) {
      state = false;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getString(_keySaturdayStatsLastShown);
    state = lastShown != _todayKey(now);
  }

  /// Call once the stats section has actually been rendered to the user.
  Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySaturdayStatsLastShown, _todayKey(DateTime.now()));
    state = false;
  }

  String _todayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ── Year-in-review banner ────────────────────────────────────────────────

/// The SharedPreferences key used to record which year's banner was dismissed.
const _keyBannerDismissedYear = 'year_review_banner_dismissed_year';

/// Whether the Year in Review banner should be shown on the home screen.
///
/// Returns `true` when ALL of the following hold:
///   • It is between December 15 and December 31 (inclusive), OR the hidden
///     test mode has been activated via 7 taps on the About tile.
///   • The user has not already dismissed the banner for the current year.
///   • There is at least one listen recorded (so the review is non-empty).
final yearReviewBannerVisibleProvider =
    NotifierProvider<YearReviewBannerNotifier, bool>(
      YearReviewBannerNotifier.new,
    );

class YearReviewBannerNotifier extends Notifier<bool> {
  @override
  bool build() {
    Future.microtask(() => _evaluate());
    return false;
  }

  Future<void> _evaluate({bool forceVisible = false}) async {
    final now = DateTime.now();
    final isPromptPeriod = forceVisible || (now.month == 12 && now.day >= 15);

    if (!isPromptPeriod) {
      state = false;
      return;
    }

    // Don't prompt at year end when the user has disabled year-end prompts
    try {
      final showPrompts = ref.read(settingsProvider).showYearEndPrompts;
      if (!showPrompts) {
        state = false;
        return;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final dismissedYear = prefs.getInt(_keyBannerDismissedYear);
    if (dismissedYear == now.year && !forceVisible) {
      state = false;
      return;
    }

    final count = await ListenHistoryService.getTotalListenCount();
    state = count > 0;
    // If the banner is visible for the current year, pregenerate the AI
    // summary in the background so it's ready when the user opens the
    // Year in Review. Also, ensure the previous calendar year's final
    // summary (if any) is saved permanently after the year ends.
    if (state) {
      try {
        // Pregenerate for the current calendar year.
        ref
            .read(aiSummaryProvider(now.year).notifier)
            .ensureGeneratedForBanner();
      } catch (_) {}
    }

    // Ensure final copy for previous year exists if needed.
    try {
      final prev = now.year - 1;
      ref.read(aiSummaryProvider(prev).notifier).ensureFinalSaved();
    } catch (_) {}
  }

  /// Permanently hide the banner for this calendar year.
  Future<void> dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBannerDismissedYear, DateTime.now().year);
    state = false;
  }

  /// Force the banner visible regardless of date (for testing).
  Future<void> forceShow() async {
    // Respect the user's preference to disable year-end prompts.
    try {
      final showPrompts = ref.read(settingsProvider).showYearEndPrompts;
      if (!showPrompts) {
        state = false;
        return;
      }
    } catch (_) {}

    final count = await ListenHistoryService.getTotalListenCount();
    state = count > 0;
  }
}
