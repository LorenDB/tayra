import 'dart:async';

import 'package:aptabase_flutter/aptabase_flutter.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/cache/download_queue_service.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/empty_state.dart';
import 'package:tayra/core/widgets/error_state.dart';
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

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
      _isLoading = true;
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
      });
      // If the global favorite IDs provider contains IDs that are not present
      // in the fetched first page (this can happen when favorites are added
      // from other screens while this screen was not visible), perform a
      // forced refresh to ensure the first page reflects recent additions.
      final providerIds = ref.read(favoriteTrackIdsProvider);
      final loadedIds = _favorites.map((f) => f.track.id).toSet();
      final missing = providerIds.difference(loadedIds);
      if (missing.isNotEmpty) {
        try {
          final fresh = await api.getFavorites(page: 1, forceRefresh: true);
          if (!mounted) return;
          setState(() {
            _favorites
              ..clear()
              ..addAll(fresh.results);
            _currentPage = 1;
            _hasMore = fresh.next != null;
            _isLoading = false;
          });
        } catch (_) {
          // Ignore forced refresh failures — we already have a usable list.
        }
      }
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
    final shuffled = List<Track>.from(tracks)..shuffle();
    ref
        .read(playerProvider.notifier)
        .playTracks(shuffled, source: 'favorites_shuffle');
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

    Aptabase.instance.trackEvent('favorites_download_all', {
      'count': trackIds.length,
    });
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
        });
      }

      // If favorites were added elsewhere, force-refresh the paginated
      // favorites list from the network so the local cached page picks up
      // the new items.
      if (added.isNotEmpty) {
        _loadFavorites(forceRefresh: true);
      }
    });
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text(
          'Favorites',
          style: TextStyle(
            color: AppTheme.onBackground,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
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
                    child: Row(
                      children: [
                        Icon(
                          Icons.download_rounded,
                          color: AppTheme.onBackground,
                        ),
                        SizedBox(width: 12),
                        Text('Download all'),
                      ],
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

    // Apply offline filter if active
    final offlineFilterActive = ref.read(offlineFilterActiveProvider);
    final offlineTrackIds =
        offlineFilterActive
            ? ref.read(offlineTrackIdsProvider).asData?.value ?? const <int>{}
            : null;
    final displayFavorites =
        offlineTrackIds != null
            ? _favorites
                .where((f) => offlineTrackIds.contains(f.track.id))
                .toList()
            : _favorites;

    if (displayFavorites.isEmpty && offlineFilterActive) {
      return const EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No offline favorites',
        subtitle: 'Download tracks to listen when offline',
      );
    }

    // Favorites list
    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surfaceContainer,
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

          // Track list
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index >= displayFavorites.length) {
                // Loading more indicator
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                );
              }

              final favorite = displayFavorites[index];
              return TrackListTile(
                track: favorite.track,
                onTap: () => _playDisplayedFromIndex(displayFavorites, index),
              );
            }, childCount: displayFavorites.length + (_isLoadingMore ? 1 : 0)),
          ),

          // Bottom padding for mini player
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

// ── Shuffle All Button ──────────────────────────────────────────────────

class _ShuffleAllButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ShuffleAllButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    // Primary-looking gradient button for Shuffle All (pill-shaped).
    final deco =
        enabled
            ? BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(22),
            )
            : BoxDecoration(
              color: AppTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(22),
            );

    return Container(
      height: 44,
      decoration: deco,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.shuffle_rounded, size: 20),
        label: const Text('Shuffle All'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
