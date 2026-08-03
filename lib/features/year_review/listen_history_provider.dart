import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/platform/app_platform.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';

// ── Providers ───────────────────────────────────────────────────────────

/// Available years that have listen data.
///
/// - **Native:** local SQLite years (dual-write keeps this warm online/offline).
/// - **Web / online-only:** probe recent years via stats API (no year-list
///   endpoint); fall back to the current calendar year for navigation.
final availableYearsProvider = FutureProvider.autoDispose<List<int>>((
  ref,
) async {
  if (AppPlatform.supportsOfflineCache) {
    return ListenHistoryService.getAvailableYears();
  }

  final offline = ref.watch(offlineStateProvider).isOffline;
  if (offline) return [DateTime.now().year];

  try {
    final years = await _serverYearsWithListens(ref);
    if (years.isNotEmpty) return years;
  } catch (e) {
    debugPrint('availableYearsProvider: server probe failed: $e');
  }
  return [DateTime.now().year];
});

/// Year-in-review stats for a specific year, enriched with favorites data.
///
/// Source of truth:
/// - **Web / online-only:** server stats API always (no SQLite fallback).
/// - **Native online:** prefer server when available; fall back to SQLite.
/// - **Native offline:** local [ListenHistoryService] only.
final yearReviewProvider = FutureProvider.autoDispose
    .family<YearReviewStats, int>((ref, year) async {
      final offline = ref.read(offlineStateProvider).isOffline;
      final api = ref.read(cachedFunkwhaleApiProvider);

      if (!offline) {
        try {
          final stats = await _loadServerYearReview(ref, api, year);
          return stats;
        } on DioException catch (e) {
          final code = e.response?.statusCode;
          debugPrint(
            'yearReviewProvider: server stats failed '
            '(HTTP $code): $e',
          );
          // 404 = stats action missing (older server). Other network errors
          // also fall back on native; web has no local store.
          if (!AppPlatform.supportsOfflineCache) rethrow;
        } catch (e) {
          debugPrint('yearReviewProvider: server stats failed: $e');
          if (!AppPlatform.supportsOfflineCache) rethrow;
        }
      } else if (!AppPlatform.supportsOfflineCache) {
        throw StateError('Year in Review requires a network connection on web');
      }

      return _loadLocalYearReview(ref, api, year);
    });

/// Total all-time listen count (used in settings to show data exists).
///
/// Online: current-year server total when stats API is available (best-effort
/// signal; full all-time is not exposed server-side). Offline/native: SQLite.
final totalListenCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final offline = ref.watch(offlineStateProvider).isOffline;
  if (!offline) {
    try {
      final api = ref.read(cachedFunkwhaleApiProvider);
      final year = DateTime.now().year;
      final json = await api.getListeningStats(year: year, limit: 1);
      final current = (json['total_listens'] as num?)?.toInt() ?? 0;
      // Include previous year so year-end / Jan banner still sees history.
      final prevJson = await api.getListeningStats(year: year - 1, limit: 1);
      final prev = (prevJson['total_listens'] as num?)?.toInt() ?? 0;
      final sum = current + prev;
      if (sum > 0 || !AppPlatform.supportsOfflineCache) return sum;
    } catch (e) {
      debugPrint('totalListenCountProvider: server failed: $e');
      if (!AppPlatform.supportsOfflineCache) return 0;
    }
  }
  if (!AppPlatform.supportsOfflineCache) return 0;
  return ListenHistoryService.getTotalListenCount();
});

/// Listening stats for the past 7 days (used on the home screen).
final weeklyStatsProvider = FutureProvider.autoDispose<WeeklyStats>((
  ref,
) async {
  if (!AppPlatform.supportsOfflineCache) {
    return const WeeklyStats(playCount: 0, totalSeconds: 0, topArtistPlays: 0);
  }
  return ListenHistoryService.getWeekStats();
});

// ── Server / local loaders ──────────────────────────────────────────────

Future<YearReviewStats> _loadServerYearReview(
  Ref ref,
  CachedFunkwhaleApi api,
  int year,
) async {
  final favoritesF = _loadFavorites(api);
  final jsonF = api.getListeningStats(year: year, limit: 10);

  final json = await jsonF;
  var stats = YearReviewStats.fromServerJson(json);

  // Enrich top albums with track counts for play-through UI.
  final albumIds = stats.topAlbums.map((a) => a.id).whereType<int>().toList();
  if (albumIds.isNotEmpty) {
    try {
      final response = await api.getAlbums(page: 1, pageSize: 500);
      final counts = <int, int>{};
      for (final album in response.results) {
        if (album.tracksCount > 0) counts[album.id] = album.tracksCount;
      }
      final enriched =
          stats.topAlbums
              .map(
                (a) =>
                    a.id != null && counts.containsKey(a.id)
                        ? a.copyWith(albumTrackCount: counts[a.id!])
                        : a,
              )
              .toList();
      stats = stats.copyWith(
        topAlbums: enriched,
        topAlbum: enriched.isNotEmpty ? enriched.first : null,
      );
    } catch (e) {
      debugPrint('yearReviewProvider: album track counts: $e');
    }
  }

  final allFavorites = await favoritesF;
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

  // Favorited-this-year still needs local listen rows for play counts when
  // offline cache exists; on web we skip (API has no per-favorite listen map).
  List<FavoritedTrack> favoritedThisYear = const [];
  if (AppPlatform.supportsOfflineCache) {
    try {
      favoritedThisYear = await ListenHistoryService.getFavoritedThisYear(
        year,
        allFavorites,
      );
    } catch (_) {}
  }

  return stats.copyWith(
    favoritedThisYear: favoritedThisYear,
    lovedTopTracks: lovedTopTracks,
    unlovedTopTracks: unlovedTopTracks,
  );
}

Future<YearReviewStats> _loadLocalYearReview(
  Ref ref,
  CachedFunkwhaleApi api,
  int year,
) async {
  final favoritesF = _loadFavorites(api);

  // Remote-device history is synced into the local DB by the background
  // sync job, so getListensForYear already includes cross-device data.
  final combined = await ListenHistoryService.getListensForYear(year);

  // Make sure remote device display names (captured from backups) are
  // available before DeviceStat.displayName is read by the UI.
  await ListenHistoryService.loadDeviceDisplayNames();

  final stats = ListenHistoryService.computeStatsFromRecords(year, combined);
  final allFavorites = await favoritesF;

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
    deviceStats: stats.deviceStats,
    fromServer: false,
  );
}

Future<List<Favorite>> _loadFavorites(CachedFunkwhaleApi api) async {
  try {
    return await fetchAllPages<Favorite>(
      (page) => api.getFavorites(page: page, pageSize: 100),
    );
  } catch (e) {
    debugPrint('yearReviewProvider: could not load favorites: $e');
    return const [];
  }
}

/// Probe recent years via the stats endpoint (no dedicated year-list API).
///
/// Sequential so a 404 (unsupported server) stops immediately. Caps at five
/// years to avoid hammering expensive aggregates.
Future<List<int>> _serverYearsWithListens(Ref ref) async {
  final api = ref.read(cachedFunkwhaleApiProvider);
  final current = DateTime.now().year;
  final found = <int>[];
  for (var i = 0; i < 5; i++) {
    final y = current - i;
    try {
      final json = await api.getListeningStats(year: y, limit: 1);
      final total = (json['total_listens'] as num?)?.toInt() ?? 0;
      if (total > 0) found.add(y);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) rethrow;
      // Transient error for one year — keep scanning.
    } catch (_) {}
  }
  return found;
}

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
    await prefs.setString(
      _keySaturdayStatsLastShown,
      _todayKey(DateTime.now()),
    );
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

    final count = await ref.read(totalListenCountProvider.future);
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
    // Respect the user's preference to disable year-end prompts.
    try {
      final showPrompts = ref.read(settingsProvider).showYearEndPrompts;
      if (!showPrompts) {
        state = false;
        return;
      }
    } catch (_) {}

    final count = await ref.read(totalListenCountProvider.future);
    state = count > 0;
  }
}
