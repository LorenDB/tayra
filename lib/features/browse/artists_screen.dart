import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:funkwhale/core/api/cached_api_repository.dart';
import 'package:funkwhale/core/layout/responsive.dart';
import 'package:funkwhale/core/theme/app_theme.dart';
import 'package:funkwhale/core/widgets/cover_art.dart';
import 'package:funkwhale/core/widgets/shimmer_loading.dart';

// ── Providers ───────────────────────────────────────────────────────────

final _artistsPageProvider =
    FutureProvider.family<PaginatedResponse<Artist>, int>((ref, page) {
      final api = ref.watch(cachedFunkwhaleApiProvider);
      return api.getArtists(page: page, pageSize: 30, ordering: 'name');
    });

// ── Screen ──────────────────────────────────────────────────────────────

class ArtistsScreen extends ConsumerStatefulWidget {
  const ArtistsScreen({super.key});

  @override
  ConsumerState<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends ConsumerState<ArtistsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Artist> _artists = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    // Trigger the provider for the next page
    final result = await ref.read(_artistsPageProvider(nextPage).future);

    if (mounted) {
      setState(() {
        _artists.addAll(result.results);
        _currentPage = nextPage;
        _hasMore = result.next != null;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(_artistsPageProvider(1));
    final result = await ref.read(_artistsPageProvider(1).future);
    if (mounted) {
      setState(() {
        _artists
          ..clear()
          ..addAll(result.results);
        _currentPage = 1;
        _hasMore = result.next != null;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstPage = ref.watch(_artistsPageProvider(1));

    return firstPage.when(
      loading: () => const ShimmerList(showCircular: true, itemCount: 12),
      error:
          (error, stack) => _ErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(_artistsPageProvider(1)),
          ),
      data: (response) {
        // Seed the local list from the first page on initial load
        if (_artists.isEmpty && response.results.isNotEmpty) {
          // Use addPostFrameCallback to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _artists.isEmpty) {
              setState(() {
                _artists.addAll(response.results);
                _hasMore = response.next != null;
              });
            }
          });
          // Show first page results directly while local list populates
          return RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surfaceContainer,
            onRefresh: _refresh,
            child: _ArtistGrid(
              artists: response.results,
              scrollController: _scrollController,
              hasMore: response.next != null,
              isLoadingMore: false,
            ),
          );
        }

        return RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surfaceContainer,
          onRefresh: _refresh,
          child: _ArtistGrid(
            artists: _artists,
            scrollController: _scrollController,
            hasMore: _hasMore,
            isLoadingMore: _isLoadingMore,
          ),
        );
      },
    );
  }
}

// ── Artist grid ─────────────────────────────────────────────────────────

class _ArtistGrid extends StatelessWidget {
  final List<Artist> artists;
  final ScrollController scrollController;
  final bool hasMore;
  final bool isLoadingMore;

  const _ArtistGrid({
    required this.artists,
    required this.scrollController,
    required this.hasMore,
    required this.isLoadingMore,
  });

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return const Center(
        child: Text(
          'No artists found',
          style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 16),
        ),
      );
    }

    final columns = Responsive.gridColumnCount(context, minItemWidth: 140);

    return GridView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: artists.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= artists.length) {
          return const _LoadingIndicator();
        }
        return _ArtistCard(artist: artists[index]);
      },
    );
  }
}

// ── Artist card ─────────────────────────────────────────────────────────

class _ArtistCard extends StatelessWidget {
  final Artist artist;

  const _ArtistCard({required this.artist});

  @override
  Widget build(BuildContext context) {
    // Calculate a size that fits the grid column
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSize = constraints.maxWidth;

        return GestureDetector(
          onTap: () => context.push('/browse/artist/${artist.id}'),
          child: Column(
            children: [
              CoverArtWidget(
                imageUrl: artist.coverUrl,
                size: imageSize,
                borderRadius: imageSize / 2,
                placeholderIcon: Icons.person,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  artist.name,
                  style: const TextStyle(
                    color: AppTheme.onBackground,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Loading indicator ───────────────────────────────────────────────────

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
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
}

// ── Error view ──────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load artists',
              style: TextStyle(
                color: AppTheme.onBackground,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: AppTheme.onBackgroundMuted,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
