import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
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
    await _loadFavorites();
    ref.read(favoriteTrackIdsProvider.notifier).refresh();
  }

  void _shuffleAll() {
    if (_favorites.isEmpty) return;
    final tracks = _favorites.map((f) => f.track).toList();
    final shuffled = List<Track>.from(tracks)..shuffle();
    ref
        .read(playerProvider.notifier)
        .playTracks(shuffled, source: 'favorites_shuffle');
  }

  void _playFromIndex(int index) {
    final tracks = _favorites.map((f) => f.track).toList();
    ref
        .read(playerProvider.notifier)
        .playTracks(tracks, startIndex: index, source: 'favorites_from_track');
  }

  String _buildStatsText() {
    if (_favorites.isEmpty) return '0 tracks';

    final count = _favorites.length;
    int totalDuration = 0;
    bool hasMissingDuration = false;

    for (final fav in _favorites) {
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
                    _buildStatsText(),
                    style: const TextStyle(
                      color: AppTheme.onBackgroundMuted,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  _ShuffleAllButton(onPressed: _shuffleAll),
                ],
              ),
            ),
          ),

          // Track list
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index >= _favorites.length) {
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

              final favorite = _favorites[index];
              return TrackListTile(
                track: favorite.track,
                onTap: () => _playFromIndex(index),
              );
            }, childCount: _favorites.length + (_isLoadingMore ? 1 : 0)),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shuffle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text(
                'Shuffle All',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
