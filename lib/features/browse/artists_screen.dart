import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/layout/responsive.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/app_refresh_indicator.dart';
import 'package:tayra/core/widgets/cover_art.dart';
import 'package:tayra/core/widgets/empty_state.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/loading_indicator.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/features/browse/paginated_grid_mixin.dart';

// ── Providers ───────────────────────────────────────────────────────────

final artistsPageProvider =
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

class _ArtistsScreenState extends ConsumerState<ArtistsScreen>
    with PaginatedGridMixin<Artist, ArtistsScreen> {
  @override
  Future<PaginatedResponse<Artist>> fetchPage(int page) =>
      ref.read(artistsPageProvider(page).future);

  @override
  void invalidatePage(int page) => ref.invalidate(artistsPageProvider(page));

  @override
  Future<void> forceRefreshPage(int page) => ref
      .read(cachedFunkwhaleApiProvider)
      .getArtists(
        page: page,
        pageSize: 30,
        ordering: 'name',
        forceRefresh: true,
      );

  @override
  Widget build(BuildContext context) {
    final offlineFilterActive = ref.watch(offlineFilterActiveProvider);

    // Dedicated offline path: assemble artists from local cache (manual
    // downloads + artists of offline albums/tracks) without depending on
    // a previously fetched artists list page.
    if (offlineFilterActive) {
      final offlineArtistsAsync = ref.watch(offlineArtistsProvider);
      return offlineArtistsAsync.when(
        loading: () => const ShimmerList(showCircular: true, itemCount: 12),
        error:
            (error, stack) => CenteredErrorView(
              title: 'Failed to load offline artists',
              message: error.toString(),
              onRetry: () => ref.invalidate(offlineArtistsProvider),
            ),
        data: (artists) {
          return AppRefreshIndicator(
            onRefresh: () async {
              ref.invalidate(offlineArtistIdsProvider);
              ref.invalidate(offlineArtistsProvider);
            },
            child: _ArtistGrid(
              artists: artists,
              scrollController: scrollController,
              hasMore: false,
              isLoadingMore: false,
              offlineMode: true,
            ),
          );
        },
      );
    }

    final firstPage = ref.watch(artistsPageProvider(1));

    return firstPage.when(
      loading: () => const ShimmerList(showCircular: true, itemCount: 12),
      error:
          (error, stack) => CenteredErrorView(
            title: 'Failed to load artists',
            message: error.toString(),
            onRetry: () => ref.invalidate(artistsPageProvider(1)),
          ),
      data: (response) {
        seedIfEmpty(response);
        final allArtists = items.isEmpty ? response.results : items;

        return AppRefreshIndicator(
          onRefresh: refresh,
          child: _ArtistGrid(
            artists: allArtists,
            scrollController: scrollController,
            hasMore: items.isEmpty ? response.next != null : hasMore,
            isLoadingMore: isLoadingMore,
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
  final bool offlineMode;

  const _ArtistGrid({
    required this.artists,
    required this.scrollController,
    required this.hasMore,
    required this.isLoadingMore,
    this.offlineMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return EmptyState(
        icon: Icons.people_rounded,
        title: offlineMode ? 'No offline artists' : 'No artists found',
        subtitle:
            offlineMode
                ? 'Download albums or tracks to browse artists offline'
                : 'Pull down to refresh',
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
          return const PaginatedLoadingIndicator();
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
          // Stay on the Artists tab route so the shell keeps Artists highlighted
          // (pushing /browse/... switches the bottom-nav selection to Albums).
          onTap: () => context.push('/artists/artist/${artist.id}'),
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
