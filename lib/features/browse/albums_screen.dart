import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:funkwhale/core/api/cached_api_repository.dart';
import 'package:funkwhale/core/theme/app_theme.dart';
import 'package:funkwhale/core/widgets/cover_art.dart';
import 'package:funkwhale/core/widgets/shimmer_loading.dart';

// ── Providers ───────────────────────────────────────────────────────────

final _albumsPageProvider =
    FutureProvider.family<PaginatedResponse<Album>, int>((ref, page) {
      final api = ref.watch(cachedFunkwhaleApiProvider);
      return api.getAlbums(page: page, pageSize: 30, ordering: 'title');
    });

// ── Screen ──────────────────────────────────────────────────────────────

class AlbumsScreen extends ConsumerStatefulWidget {
  const AlbumsScreen({super.key});

  @override
  ConsumerState<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends ConsumerState<AlbumsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Album> _albums = [];
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
    final result = await ref.read(_albumsPageProvider(nextPage).future);

    if (mounted) {
      setState(() {
        _albums.addAll(result.results);
        _currentPage = nextPage;
        _hasMore = result.next != null;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(_albumsPageProvider(1));
    final result = await ref.read(_albumsPageProvider(1).future);
    if (mounted) {
      setState(() {
        _albums
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
    final firstPage = ref.watch(_albumsPageProvider(1));

    return firstPage.when(
      loading: () => const ShimmerList(itemCount: 12),
      error:
          (error, stack) => _ErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(_albumsPageProvider(1)),
          ),
      data: (response) {
        // Seed the local list from the first page on initial load
        if (_albums.isEmpty && response.results.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _albums.isEmpty) {
              setState(() {
                _albums.addAll(response.results);
                _hasMore = response.next != null;
              });
            }
          });
          return RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surfaceContainer,
            onRefresh: _refresh,
            child: _AlbumGrid(
              albums: response.results,
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
          child: _AlbumGrid(
            albums: _albums,
            scrollController: _scrollController,
            hasMore: _hasMore,
            isLoadingMore: _isLoadingMore,
          ),
        );
      },
    );
  }
}

// ── Album grid ──────────────────────────────────────────────────────────

class _AlbumGrid extends StatelessWidget {
  final List<Album> albums;
  final ScrollController scrollController;
  final bool hasMore;
  final bool isLoadingMore;

  const _AlbumGrid({
    required this.albums,
    required this.scrollController,
    required this.hasMore,
    required this.isLoadingMore,
  });

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const Center(
        child: Text(
          'No albums found',
          style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 10,
        childAspectRatio: 0.68,
      ),
      itemCount: albums.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= albums.length) {
          return const _LoadingIndicator();
        }
        return _AlbumCard(album: albums[index]);
      },
    );
  }
}

// ── Album card ──────────────────────────────────────────────────────────

class _AlbumCard extends StatelessWidget {
  final Album album;

  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSize = constraints.maxWidth;

        return GestureDetector(
          onTap: () => context.push('/browse/album/${album.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CoverArtWidget(
                    imageUrl: album.coverUrl,
                    size: imageSize,
                    borderRadius: 10,
                    shadow: BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: imageSize * 0.35,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.title,
                      style: const TextStyle(
                        color: AppTheme.onBackground,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      album.artist?.name ?? 'Unknown Artist',
                      style: const TextStyle(
                        color: AppTheme.onBackgroundMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
              'Failed to load albums',
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
