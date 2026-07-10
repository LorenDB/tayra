import 'dart:async';

import 'package:tayra/core/analytics/analytics.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/cache/download_queue_service.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/app_refresh_indicator.dart';
import 'package:tayra/core/widgets/empty_state.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/loading_indicator.dart';
import 'package:tayra/core/widgets/pill_action_button.dart';
import 'package:tayra/core/widgets/popup_menu_row.dart';
import 'package:tayra/core/widgets/track_list_tile.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/features/favorites/favorites_provider.dart';
import 'package:tayra/features/search/search_screen.dart';
import 'package:tayra/core/layout/responsive.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final List<Favorite> _favorites = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _error;

  // Cached offline-filtered view so scrolling doesn't re-filter every build.
  List<Favorite> _displayCache = const [];
  bool? _displayOfflineActive;
  Set<int>? _displayOfflineIds;
  int _favoritesEpoch = 0;
  int _displayEpoch = -1;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _invalidateDisplayCache() {
    _favoritesEpoch++;
  }

  List<Favorite> _displayFavorites({
    required bool offlineFilterActive,
    Set<int>? offlineTrackIds,
  }) {
    if (_displayEpoch == _favoritesEpoch &&
        _displayOfflineActive == offlineFilterActive &&
        identical(_displayOfflineIds, offlineTrackIds)) {
      return _displayCache;
    }
    _displayEpoch = _favoritesEpoch;
    _displayOfflineActive = offlineFilterActive;
    _displayOfflineIds = offlineTrackIds;
    if (!offlineFilterActive || offlineTrackIds == null) {
      _displayCache = _favorites;
    } else {
      _displayCache = _favorites
          .where((f) => offlineTrackIds.contains(f.track.id))
          .toList(growable: false);
    }
    return _displayCache;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadFavorites({bool forceRefresh = false}) async {
    setState(() {
      // Only show full-screen shimmer on initial load; pull-to-refresh keeps
      // the existing list visible under the RefreshIndicator spinner.
      if (!forceRefresh || _favorites.isEmpty) _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(cachedFunkwhaleApiProvider);
      final response = await api.getFavorites(
        page: 1,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _favorites
          ..clear()
          ..addAll(response.results);
        _currentPage = 1;
        _hasMore = response.next != null;
        _isLoading = false;
        _invalidateDisplayCache();
      });
      // Do NOT force-refresh when global favorite IDs aren't all on page 1 —
      // that is normal for multi-page libraries and caused a second fetch
      // plus scroll jumps ("bounce") at the end of the first page. New
      // favorites added elsewhere are handled by the provider listener below.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load favorites';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final api = ref.read(cachedFunkwhaleApiProvider);
      final nextPage = _currentPage + 1;
      final response = await api.getFavorites(page: nextPage);
      if (!mounted) return;
      setState(() {
        _favorites.addAll(response.results);
        _currentPage = nextPage;
        _hasMore = response.next != null;
        _isLoadingMore = false;
        _invalidateDisplayCache();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load more favorites')),
      );
    }
  }

  Future<void> _onRefresh() async {
    await _loadFavorites(forceRefresh: true);
    ref.read(favoriteTrackIdsProvider.notifier).refresh();
  }

  void _shuffleDisplayed(List<Favorite> displayed) {
    if (displayed.isEmpty) return;
    final tracks = displayed.map((f) => f.track).toList();
    ref
        .read(playerProvider.notifier)
        .playTracks(tracks, source: 'favorites_shuffle', shuffle: true);
  }

  void _playDisplayedFromIndex(List<Favorite> displayed, int index) {
    final tracks = displayed.map((f) => f.track).toList();
    ref
        .read(playerProvider.notifier)
        .playTracks(tracks, startIndex: index, source: 'favorites_from_track');
  }

  Future<void> _downloadAll() async {
    // Collect all track IDs from the already-loaded favorites, then also
    // fetch any remaining pages so nothing is missed.
    final trackIds = <int>{};
    for (final fav in _favorites) {
      trackIds.add(fav.track.id);
    }

    // If there are more pages we haven't loaded yet, fetch all remaining IDs
    // via the lightweight "all IDs" endpoint.
    if (_hasMore) {
      try {
        final api = ref.read(cachedFunkwhaleApiProvider);
        final allIds = await api.getAllFavoriteTrackIds();
        trackIds.addAll(allIds);
      } catch (_) {
        // Fall back to only the already-loaded tracks if the fetch fails.
      }
    }

    if (trackIds.isEmpty) return;

    Analytics.track('favorites_download_all', {'count': trackIds.length});
    final queue = ref.read(downloadQueueServiceProvider);
    unawaited(queue.enqueue(trackIds.toList(), ref));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading all favorites')),
      );
    }
  }

  String _buildStatsText([List<Favorite>? favs]) {
    final list = favs ?? _favorites;
    if (list.isEmpty) return '0 tracks';

    final count = list.length;
    int totalDuration = 0;
    bool hasMissingDuration = false;

    for (final fav in list) {
      final d = fav.track.duration;
      if (d != null) {
        totalDuration += d;
      } else {
        hasMissingDuration = true;
      }
    }

    final parts = <String>[];
    parts.add(pluralizeTrack(count));

    if (totalDuration > 0) {
      final durationStr = formatTotalDuration(totalDuration);
      parts.add(hasMissingDuration ? '~ $durationStr' : durationStr);
    }

    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    // Keep the visible favorites list in sync with the global favorite IDs
    // provider. Must register this listener during build (ConsumerState) so
    // Riverpod can manage the listener lifecycle safely.
    ref.listen<Set<int>>(favoriteTrackIdsProvider, (previous, next) {
      if (!mounted) return;

      final prev = previous ?? <int>{};

      final removed = prev.difference(next);
      final added = next.difference(prev);

      // Remove unfavorited tracks immediately from the visible list.
      if (removed.isNotEmpty) {
        setState(() {
          _favorites.removeWhere((f) => removed.contains(f.track.id));
          _invalidateDisplayCache();
        });
      }

      // New favorites from other screens: refresh once (not the old
      // "missing from page 1" double-fetch path).
      if (added.isNotEmpty) {
        _loadFavorites(forceRefresh: true);
      }
    });
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Favorites'),
        actions: [
          if (!Responsive.useSideNavigation(context))
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => SearchScreen.show(context),
            ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppTheme.onBackground,
            ),
            color: AppTheme.surfaceContainer,
            onSelected: (value) {
              if (value == 'download_all') _downloadAll();
            },
            itemBuilder:
                (_) => [
                  const PopupMenuItem(
                    value: 'download_all',
                    child: PopupMenuRow(
                      icon: Icons.download_rounded,
                      label: 'Download all',
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Initial loading
    if (_isLoading) {
      return const ShimmerList(itemCount: 10);
    }

    // Error state
    if (_error != null && _favorites.isEmpty) {
      return InlineErrorState(message: _error!, onRetry: _loadFavorites);
    }

    // Empty state
    if (_favorites.isEmpty) {
      return const EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'No favorites yet',
        subtitle: 'Tap the heart on any track to add it here',
      );
    }

    // Apply offline filter if active (cached until inputs change).
    final offlineFilterActive = ref.watch(offlineFilterActiveProvider);
    final offlineTrackIds =
        offlineFilterActive ? ref.watch(offlineTrackIdsProvider) : null;
    final displayFavorites = _displayFavorites(
      offlineFilterActive: offlineFilterActive,
      offlineTrackIds: offlineTrackIds,
    );

    if (displayFavorites.isEmpty && offlineFilterActive) {
      return const EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No offline favorites',
        subtitle: 'Download tracks to listen when offline',
      );
    }

    // Favorites list
    return AppRefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Shuffle All button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Text(
                    _buildStatsText(displayFavorites),
                    style: const TextStyle(
                      color: AppTheme.onBackgroundMuted,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  _ShuffleAllButton(
                    onPressed: () => _shuffleDisplayed(displayFavorites),
                  ),
                ],
              ),
            ),
          ),

          // Track list — fixed extent so scroll layout skips child measurement.
          SliverFixedExtentList(
            itemExtent: kTrackListTileExtent,
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final favorite = displayFavorites[index];
                return TrackListTile(
                  track: favorite.track,
                  // Always favorited on this screen — skip N provider watches.
                  isFavoriteOverride: true,
                  onTap: () => _playDisplayedFromIndex(displayFavorites, index),
                );
              },
              childCount: displayFavorites.length,
              // Don't keep off-screen rows alive (saves element/state cost).
              addAutomaticKeepAlives: false,
            ),
          ),

          if (_isLoadingMore)
            const SliverToBoxAdapter(child: PaginatedLoadingIndicator()),

          // Bottom padding for mini player
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

// ── Shuffle All Button ──────────────────────────────────────────────────

class _ShuffleAllButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _ShuffleAllButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return PillActionButton(
      icon: Icons.shuffle_rounded,
      label: 'Shuffle All',
      onPressed: onPressed,
      useGradient: true,
      iconSize: 20,
    );
  }
}
