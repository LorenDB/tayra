import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/layout/responsive.dart';
import 'package:tayra/core/widgets/app_refresh_indicator.dart';
import 'package:tayra/core/widgets/album_card.dart';
import 'package:tayra/core/widgets/empty_state.dart';
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
  durationShortest,
  durationLongest,
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
      case AlbumSortMode.durationShortest:
        return 'Duration (shortest)';
      case AlbumSortMode.durationLongest:
        return 'Duration (longest)';
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
      case AlbumSortMode.durationShortest:
        return 'duration';
      case AlbumSortMode.durationLongest:
        return '-duration';
    }
  }
}

/// Preset duration ranges for the albums filter sheet (seconds).
enum AlbumDurationPreset {
  any,
  under30Min,
  min30To60,
  hour1To2,
  over2Hours,
}

extension AlbumDurationPresetX on AlbumDurationPreset {
  String get label {
    switch (this) {
      case AlbumDurationPreset.any:
        return 'Any length';
      case AlbumDurationPreset.under30Min:
        return 'Under 30 min';
      case AlbumDurationPreset.min30To60:
        return '30–60 min';
      case AlbumDurationPreset.hour1To2:
        return '1–2 hours';
      case AlbumDurationPreset.over2Hours:
        return 'Over 2 hours';
    }
  }

  /// Inclusive minimum duration in seconds, or null for no lower bound.
  int? get minDuration {
    switch (this) {
      case AlbumDurationPreset.any:
      case AlbumDurationPreset.under30Min:
        return null;
      case AlbumDurationPreset.min30To60:
        return 30 * 60;
      case AlbumDurationPreset.hour1To2:
        return 60 * 60;
      case AlbumDurationPreset.over2Hours:
        return 2 * 60 * 60;
    }
  }

  /// Inclusive maximum duration in seconds, or null for no upper bound.
  int? get maxDuration {
    switch (this) {
      case AlbumDurationPreset.any:
      case AlbumDurationPreset.over2Hours:
        return null;
      case AlbumDurationPreset.under30Min:
        return 30 * 60 - 1;
      case AlbumDurationPreset.min30To60:
        return 60 * 60;
      case AlbumDurationPreset.hour1To2:
        return 2 * 60 * 60;
    }
  }
}

class AlbumsFilter {
  final AlbumSortMode sortMode;
  final List<String> tags;
  final AlbumDurationPreset durationPreset;
  final String? libraryId;

  const AlbumsFilter({
    this.sortMode = AlbumSortMode.titleAsc,
    this.tags = const [],
    this.durationPreset = AlbumDurationPreset.any,
    this.libraryId,
  });

  int? get minDuration => durationPreset.minDuration;
  int? get maxDuration => durationPreset.maxDuration;

  bool get isActive =>
      sortMode != AlbumSortMode.titleAsc ||
      tags.isNotEmpty ||
      durationPreset != AlbumDurationPreset.any ||
      libraryId != null;

  AlbumsFilter copyWith({
    AlbumSortMode? sortMode,
    List<String>? tags,
    AlbumDurationPreset? durationPreset,
    String? libraryId,
    bool clearLibrary = false,
  }) {
    return AlbumsFilter(
      sortMode: sortMode ?? this.sortMode,
      tags: tags ?? this.tags,
      durationPreset: durationPreset ?? this.durationPreset,
      libraryId: clearLibrary ? null : (libraryId ?? this.libraryId),
    );
  }
}

class AlbumsFilterNotifier extends Notifier<AlbumsFilter> {
  @override
  AlbumsFilter build() => const AlbumsFilter();

  void setSortMode(AlbumSortMode sortMode) =>
      state = state.copyWith(sortMode: sortMode);
  void setTags(List<String> tags) => state = state.copyWith(tags: tags);
  void setDurationPreset(AlbumDurationPreset preset) =>
      state = state.copyWith(durationPreset: preset);
  void setLibrary(String? libraryId) =>
      state = state.copyWith(libraryId: libraryId, clearLibrary: libraryId == null);
  void reset() => state = const AlbumsFilter();
}

final albumsFilterProvider =
    NotifierProvider<AlbumsFilterNotifier, AlbumsFilter>(
      AlbumsFilterNotifier.new,
    );

// ── Providers ───────────────────────────────────────────────────────────

final albumsPageProvider = FutureProvider.family<PaginatedResponse<Album>, int>(
  (ref, page) async {
    // Background revalidation for this page updates the grid without shimmer.
    watchMetadataRevalidation(ref, (key) => key.startsWith('albums_p$page'));
    final api = ref.watch(cachedFunkwhaleApiProvider);
    final filter = ref.watch(albumsFilterProvider);

    if (filter.tags.length <= 1) {
      return api.getAlbums(
        page: page,
        pageSize: 30,
        ordering: filter.sortMode.apiOrdering,
        tag: filter.tags.isEmpty ? null : filter.tags,
        minDuration: filter.minDuration,
        maxDuration: filter.maxDuration,
        library: filter.libraryId,
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
          minDuration: filter.minDuration,
          maxDuration: filter.maxDuration,
          library: filter.libraryId,
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
          minDuration: filter.minDuration,
          maxDuration: filter.maxDuration,
          library: filter.libraryId,
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
          return AppRefreshIndicator(
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
        seedOrUpdateFirstPage(response, idOf: (a) => a.id);
        final allAlbums = items.isEmpty ? response.results : items;

        return AppRefreshIndicator(
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
      return EmptyState(
        icon: Icons.album_rounded,
        title: emptyLabel,
        subtitle: 'Pull down to refresh',
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
