import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/cover_art.dart';
import 'package:tayra/core/widgets/dot_separator.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/core/widgets/tag_chip_list.dart';

// ── Provider ────────────────────────────────────────────────────────────

final _artistDetailProvider = FutureProvider.family<Artist, int>((
  ref,
  artistId,
) {
  ref.keepAlive();
  final api = ref.watch(cachedFunkwhaleApiProvider);
  return api.getArtist(artistId);
});

// ── Screen ──────────────────────────────────────────────────────────────

class ArtistDetailScreen extends ConsumerWidget {
  final int artistId;

  const ArtistDetailScreen({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistAsync = ref.watch(_artistDetailProvider(artistId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: artistAsync.when(
        loading: () => const _ArtistDetailShimmer(),
        error:
            (error, stack) => DetailPageErrorBody(
              title: 'Failed to load artist',
              message: error.toString(),
              onRetry: () => ref.invalidate(_artistDetailProvider(artistId)),
            ),
        data:
            (artist) => RefreshIndicator(
              color: AppTheme.primary,
              backgroundColor: AppTheme.surfaceContainer,
              onRefresh: () async {
                ref.invalidate(_artistDetailProvider(artistId));
                await ref.read(_artistDetailProvider(artistId).future);
              },
              child: _ArtistDetailBody(artist: artist),
            ),
      ),
    );
  }
}

// ── Detail body ─────────────────────────────────────────────────────────

class _ArtistDetailBody extends StatelessWidget {
  final Artist artist;

  const _ArtistDetailBody({required this.artist});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Hero header ──
        SliverToBoxAdapter(child: _ArtistHeader(artist: artist)),

        // ── Info section ──
        SliverToBoxAdapter(child: _ArtistInfo(artist: artist)),

        // ── Albums header ──
        if (artist.albums.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text(
                'Albums',
                style: TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

        // ── Albums list ──
        if (artist.albums.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _AlbumListItem(album: artist.albums[index]),
              childCount: artist.albums.length,
            ),
          ),

        // ── Empty state ──
        if (artist.albums.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No albums available',
                  style: TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),

        // ── Bottom spacing ──
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ── Hero header with blurred background ─────────────────────────────────

class _ArtistHeader extends StatelessWidget {
  final Artist artist;

  const _ArtistHeader({required this.artist});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const headerHeight = 340.0;
    const imageSize = 160.0;

    return SizedBox(
      height: headerHeight,
      child: Stack(
        children: [
          // ── Blurred background image ──
          if (artist.coverUrl != null)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: artist.coverUrl!,
                fit: BoxFit.cover,
                width: screenWidth,
                height: headerHeight,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          // ── Gradient overlay ──
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.6),
                    AppTheme.primary.withValues(alpha: 0.3),
                    AppTheme.background.withValues(alpha: 0.85),
                    AppTheme.background,
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // ── Back button ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),

          // ── Centered artist image ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: (screenWidth - imageSize) / 2,
            child: CoverArtWidget(
              imageUrl: artist.coverUrl,
              size: imageSize,
              borderRadius: imageSize / 2,
              placeholderIcon: Icons.person,
              shadow: BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ),
          ),

          // ── Artist name ──
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Text(
              artist.name,
              style: const TextStyle(
                color: AppTheme.onBackground,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Artist info (track count, tags) ─────────────────────────────────────

class _ArtistInfo extends StatelessWidget {
  final Artist artist;

  const _ArtistInfo({required this.artist});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // ── Track count ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.music_note,
                color: AppTheme.onBackgroundMuted,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                pluralizeTrack(artist.tracksCount),
                style: const TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontSize: 14,
                ),
              ),
              if (artist.albums.isNotEmpty) ...[
                const SizedBox(width: 16),
                const Icon(
                  Icons.album,
                  color: AppTheme.onBackgroundMuted,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${artist.albums.length} ${artist.albums.length == 1 ? 'album' : 'albums'}',
                  style: const TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),

          // ── Tags ──
          if (artist.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            TagChipList(tags: artist.tags),
          ],
        ],
      ),
    );
  }
}

// ── Album list item ─────────────────────────────────────────────────────

class _AlbumListItem extends StatelessWidget {
  final Album album;

  const _AlbumListItem({required this.album});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/browse/album/${album.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              CoverArtWidget(
                imageUrl: album.coverUrl,
                size: 64,
                borderRadius: 8,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.title,
                      style: const TextStyle(
                        color: AppTheme.onBackground,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (album.releaseYear.isNotEmpty) ...[
                          Text(
                            album.releaseYear,
                            style: const TextStyle(
                              color: AppTheme.onBackgroundSubtle,
                              fontSize: 13,
                            ),
                          ),
                          const DotSeparator(),
                        ],
                        Text(
                          pluralizeTrack(album.tracksCount),
                          style: const TextStyle(
                            color: AppTheme.onBackgroundSubtle,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.onBackgroundSubtle,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shimmer loading state ───────────────────────────────────────────────

class _ArtistDetailShimmer extends StatelessWidget {
  const _ArtistDetailShimmer();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Simulate the header
          const SizedBox(height: 80),
          Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Simulate name
          Container(
            height: 24,
            width: 200,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 32),
          // Albums shimmer
          const Expanded(child: ShimmerList(itemCount: 6)),
        ],
      ),
    );
  }
}
