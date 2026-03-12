import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funkwhale/core/api/api_repository.dart';
import 'package:funkwhale/core/api/models.dart';
import 'package:funkwhale/core/theme/app_theme.dart';
import 'package:funkwhale/core/widgets/track_list_tile.dart';
import 'package:funkwhale/core/widgets/shimmer_loading.dart';
import 'package:funkwhale/features/player/player_provider.dart';
import 'package:funkwhale/features/favorites/favorites_provider.dart';

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

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(funkwhaleApiProvider);
      final response = await api.getFavorites(page: 1);
      if (!mounted) return;
      setState(() {
        _favorites
          ..clear()
          ..addAll(response.results);
        _currentPage = 1;
        _hasMore = response.next != null;
        _isLoading = false;
      });
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
      final api = ref.read(funkwhaleApiProvider);
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
    ref.read(playerProvider.notifier).playTracks(shuffled);
  }

  void _playFromIndex(int index) {
    final tracks = _favorites.map((f) => f.track).toList();
    ref.read(playerProvider.notifier).playTracks(tracks, startIndex: index);
  }

  @override
  Widget build(BuildContext context) {
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: AppTheme.error.withValues(alpha: 0.7),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: AppTheme.onBackgroundMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: _loadFavorites, child: const Text('Retry')),
          ],
        ),
      );
    }

    // Empty state
    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              color: AppTheme.onBackgroundSubtle.withValues(alpha: 0.5),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'No favorites yet',
              style: TextStyle(
                color: AppTheme.onBackgroundMuted,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap the heart on any track to add it here',
              style: TextStyle(
                color: AppTheme.onBackgroundSubtle,
                fontSize: 13,
              ),
            ),
          ],
        ),
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
                    '${_favorites.length} tracks',
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
