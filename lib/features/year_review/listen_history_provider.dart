import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';

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
      // Fetch listen stats and all-favorites in parallel for performance.
      final api = ref.read(cachedFunkwhaleApiProvider);

      final statsF = ListenHistoryService.getYearStats(year);

      // Fetch all favorite pages. Silently swallow errors so an API outage
      // doesn't break the whole review screen.
      late List<Favorite> allFavorites;
      try {
        allFavorites = await fetchAllPages<Favorite>(
          (page) => api.getFavorites(page: page, pageSize: 100),
        );
      } catch (e) {
        debugPrint('yearReviewProvider: could not load favorites: $e');
        allFavorites = const [];
      }

      final stats = await statsF;

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

    final prefs = await SharedPreferences.getInstance();
    final dismissedYear = prefs.getInt(_keyBannerDismissedYear);
    if (dismissedYear == now.year && !forceVisible) {
      state = false;
      return;
    }

    final count = await ListenHistoryService.getTotalListenCount();
    state = count > 0;
  }

  /// Permanently hide the banner for this calendar year.
  Future<void> dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBannerDismissedYear, DateTime.now().year);
    state = false;
  }

  /// Force the banner visible regardless of date (for testing).
  Future<void> forceShow() async {
    final count = await ListenHistoryService.getTotalListenCount();
    state = count > 0;
  }
}
