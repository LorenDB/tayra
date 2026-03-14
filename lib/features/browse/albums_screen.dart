import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/layout/responsive.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/album_card.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/features/browse/paginated_grid_mixin.dart';

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

class _AlbumsScreenState extends ConsumerState<AlbumsScreen>
    with PaginatedGridMixin<Album, AlbumsScreen> {
  @override
  Future<PaginatedResponse<Album>> fetchPage(int page) =>
      ref.read(_albumsPageProvider(page).future);

  @override
  void invalidatePage(int page) => ref.invalidate(_albumsPageProvider(page));

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
        seedIfEmpty(response);
        return RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surfaceContainer,
          onRefresh: refresh,
          child: _AlbumGrid(
            albums: items.isEmpty ? response.results : items,
            scrollController: scrollController,
            hasMore: items.isEmpty ? response.next != null : hasMore,
            isLoadingMore: items.isEmpty ? false : isLoadingMore,
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

    final columns = Responsive.gridColumnCount(context, minItemWidth: 120);

    return GridView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 16,
        crossAxisSpacing: 10,
        childAspectRatio: 0.68,
      ),
      itemCount: albums.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= albums.length) {
          return const _LoadingIndicator();
        }
        return AlbumCard(
          album: albums[index],
          onTap: () => context.push('/browse/album/${albums[index].id}'),
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
