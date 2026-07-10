import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/layout/responsive.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/album_card.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/loading_indicator.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/features/browse/paginated_grid_mixin.dart';

// ── Filter state ─────────────────────────────────────────────────────────

enum AlbumSortMode {
  titleAsc,
  titleDesc,
  releaseDateNewest,
  releaseDateOldest,
  dateAddedNewest,
  dateAddedOldest,
}

extension AlbumSortModeX on AlbumSortMode {
  String get label {
    switch (this) {
      case AlbumSortMode.titleAsc:
        return 'Title (A–Z)';
      case AlbumSortMode.titleDesc:
        return 'Title (Z–A)';
      case AlbumSortMode.releaseDateNewest:
        return 'Release date (newest)';
      case AlbumSortMode.releaseDateOldest:
        return 'Release date (oldest)';
      case AlbumSortMode.dateAddedNewest:
        return 'Date added (newest)';
      case AlbumSortMode.dateAddedOldest:
        return 'Date added (oldest)';
    }
  }

  String get apiOrdering {
    switch (this) {
      case AlbumSortMode.titleAsc:
        return 'title';
      case AlbumSortMode.titleDesc:
        return '-title';
      case AlbumSortMode.releaseDateNewest:
        return '-release_date';
      case AlbumSortMode.releaseDateOldest:
        return 'release_date';
      case AlbumSortMode.dateAddedNewest:
        return '-creation_date';
      case AlbumSortMode.dateAddedOldest:
        return 'creation_date';
    }
  }
}

class AlbumsFilter {
  final AlbumSortMode sortMode;
  final List<String> tags;

  const AlbumsFilter({
    this.sortMode = AlbumSortMode.titleAsc,
    this.tags = const [],
  });

  bool get isActive => sortMode != AlbumSortMode.titleAsc || tags.isNotEmpty;

  AlbumsFilter copyWith({AlbumSortMode? sortMode, List<String>? tags}) {
    return AlbumsFilter(
      sortMode: sortMode ?? this.sortMode,
      tags: tags ?? this.tags,
    );
  }
}

class AlbumsFilterNotifier extends Notifier<AlbumsFilter> {
  @override
  AlbumsFilter build() => const AlbumsFilter();

  void setSortMode(AlbumSortMode sortMode) =>
      state = state.copyWith(sortMode: sortMode);
  void setTags(List<String> tags) => state = state.copyWith(tags: tags);
  void reset() => state = const AlbumsFilter();
}

final albumsFilterProvider =
    NotifierProvider<AlbumsFilterNotifier, AlbumsFilter>(
      AlbumsFilterNotifier.new,
    );

// ── Providers ───────────────────────────────────────────────────────────

final albumsPageProvider = FutureProvider.family<PaginatedResponse<Album>, int>(
  (ref, page) async {
    final api = ref.watch(cachedFunkwhaleApiProvider);
    final filter = ref.watch(albumsFilterProvider);

    if (filter.tags.length <= 1) {
      return api.getAlbums(
        page: page,
        pageSize: 30,
        ordering: filter.sortMode.apiOrdering,
        tag: filter.tags.isEmpty ? null : filter.tags,
      );
    }

    // OR semantics: one request per tag in parallel, then deduplicate by id.
    final responses = await Future.wait(
      filter.tags.map(
        (tag) => api.getAlbums(
          page: page,
          pageSize: 30,
          ordering: filter.sortMode.apiOrdering,
          tag: [tag],
        ),
      ),
    );

    final seen = <int>{};
    final merged = <Album>[];
    for (final response in responses) {
      for (final album in response.results) {
        if (seen.add(album.id)) merged.add(album);
      }
    }

    return PaginatedResponse(
      count: merged.length,
      next: responses.any((r) => r.next != null) ? 'or' : null,
      previous: null,
      results: merged,
    );
  },
);

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
      ref.read(albumsPageProvider(page).future);

  @override
  void invalidatePage(int page) => ref.invalidate(albumsPageProvider(page));

  @override
  Future<void> forceRefreshPage(int page) {
    final filter = ref.read(albumsFilterProvider);
    return ref
        .read(cachedFunkwhaleApiProvider)
        .getAlbums(
          page: page,
          pageSize: 30,
          ordering: filter.sortMode.apiOrdering,
          tag: filter.tags.isEmpty ? null : filter.tags,
          forceRefresh: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(albumsFilterProvider, (prev, next) {
      resetPagination();
    });
    final offlineFilterActive = ref.watch(offlineFilterActiveProvider);
    if (offlineFilterActive) {
      final offlineAlbumsAsync = ref.watch(offlineAlbumsProvider);

      return offlineAlbumsAsync.when(
        loading: () => const ShimmerList(itemCount: 12),
        error:
            (error, stack) => CenteredErrorView(
              title: 'Failed to load offline albums',
              message: error.toString(),
              onRetry: () => ref.invalidate(offlineAlbumsProvider),
            ),
        data: (albums) {
          return RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surfaceContainer,
            onRefresh: () async {
              ref.invalidate(offlineAlbumIdsProvider);
              ref.invalidate(offlineAlbumsProvider);
            },
            child: _AlbumGrid(
              albums: albums,
              scrollController: scrollController,
              hasMore: false,
              isLoadingMore: false,
              emptyLabel: 'No offline albums found',
            ),
          );
        },
      );
    }

    final firstPage = ref.watch(albumsPageProvider(1));

    return firstPage.when(
      loading: () => const ShimmerList(itemCount: 12),
      error:
          (error, stack) => CenteredErrorView(
            title: 'Failed to load albums',
            message: error.toString(),
            onRetry: () => ref.invalidate(albumsPageProvider(1)),
          ),
      data: (response) {
        seedIfEmpty(response);
        final allAlbums = items.isEmpty ? response.results : items;

        return RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surfaceContainer,
          onRefresh: refresh,
          child: _AlbumGrid(
            albums: allAlbums,
            scrollController: scrollController,
            hasMore: items.isEmpty ? response.next != null : hasMore,
            isLoadingMore: isLoadingMore,
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
  final String emptyLabel;

  const _AlbumGrid({
    required this.albums,
    required this.scrollController,
    required this.hasMore,
    required this.isLoadingMore,
    this.emptyLabel = 'No albums found',
  });

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
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
          return const PaginatedLoadingIndicator();
        }
        return RepaintBoundary(
          child: AlbumCard(
            album: albums[index],
            onTap: () => context.push('/browse/album/${albums[index].id}'),
            // Drop shadows during grid scroll — major composite cost.
            showShadow: false,
          ),
        );
      },
    );
  }
}
