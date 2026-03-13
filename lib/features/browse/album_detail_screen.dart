import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/theme/palette_provider.dart';
import 'package:tayra/core/widgets/cover_art.dart';
import 'package:tayra/core/widgets/track_list_tile.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/features/player/player_provider.dart';

// ── Providers ───────────────────────────────────────────────────────────

final _albumDetailProvider = FutureProvider.family<Album, int>((ref, albumId) {
  final api = ref.watch(cachedFunkwhaleApiProvider);
  return api.getAlbum(albumId);
});

final _albumTracksProvider = FutureProvider.family<List<Track>, int>((
  ref,
  albumId,
) async {
  final api = ref.watch(cachedFunkwhaleApiProvider);
  final response = await api.getTracks(
    album: albumId,
    ordering: 'position',
    pageSize: 100,
  );
  return response.results;
});

// ── Screen ──────────────────────────────────────────────────────────────

class AlbumDetailScreen extends ConsumerWidget {
  final int albumId;

  const AlbumDetailScreen({super.key, required this.albumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumAsync = ref.watch(_albumDetailProvider(albumId));
    final tracksAsync = ref.watch(_albumTracksProvider(albumId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: albumAsync.when(
        loading: () => const _AlbumDetailShimmer(),
        error:
            (error, stack) => _ErrorBody(
              message: error.toString(),
              onRetry: () {
                ref.invalidate(_albumDetailProvider(albumId));
                ref.invalidate(_albumTracksProvider(albumId));
              },
            ),
        data:
            (album) => RefreshIndicator(
              color: AppTheme.primary,
              backgroundColor: AppTheme.surfaceContainer,
              onRefresh: () async {
                ref.invalidate(_albumDetailProvider(albumId));
                ref.invalidate(_albumTracksProvider(albumId));
                await Future.wait([
                  ref.read(_albumDetailProvider(albumId).future),
                  ref.read(_albumTracksProvider(albumId).future),
                ]);
              },
              child: _AlbumDetailBody(album: album, tracksAsync: tracksAsync),
            ),
      ),
    );
  }
}

// ── Detail body ─────────────────────────────────────────────────────────

class _AlbumDetailBody extends ConsumerWidget {
  final Album album;
  final AsyncValue<List<Track>> tracksAsync;

  const _AlbumDetailBody({required this.album, required this.tracksAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = album.largeCoverUrl ?? album.coverUrl;
    final dominantColorAsync = ref.watch(dominantColorProvider(imageUrl));
    final glowColor = dominantColorAsync.maybeWhen(
      data: (color) => color,
      orElse: () => AppTheme.primary,
    );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Album header with glow ──
        SliverToBoxAdapter(
          child: _AlbumHeader(album: album, glowColor: glowColor),
        ),

        // ── Album info ──
        SliverToBoxAdapter(child: _AlbumInfo(album: album)),

        // ── Action buttons ──
        SliverToBoxAdapter(
          child: _ActionButtons(album: album, tracksAsync: tracksAsync),
        ),

        // ── Track list ──
        tracksAsync.when(
          loading:
              () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: ShimmerList(itemCount: 6, itemHeight: 56),
                ),
              ),
          error:
              (error, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Failed to load tracks: $error',
                      style: const TextStyle(
                        color: AppTheme.onBackgroundMuted,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          data: (tracks) {
            if (tracks.isEmpty) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No tracks available',
                      style: TextStyle(
                        color: AppTheme.onBackgroundMuted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final track = tracks[index];
                return TrackListTile(
                  track: track,
                  showTrackNumber: true,
                  showAlbumArt: false,
                  onTap: () {
                    ref
                        .read(playerProvider.notifier)
                        .playTracks(
                          tracks,
                          startIndex: index,
                          source: 'album_detail_from_track',
                        );
                  },
                );
              }, childCount: tracks.length),
            );
          },
        ),

        // ── Bottom spacing ──
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ── Album header with cover art and glow ────────────────────────────────

class _AlbumHeader extends StatelessWidget {
  final Album album;
  final Color glowColor;

  const _AlbumHeader({required this.album, required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    const artSize = 240.0;

    return Stack(
      children: [
        // ── Gradient glow background ──
        Container(
          height: topPadding + artSize + 100,
          decoration: BoxDecoration(gradient: AppTheme.coverGlow(glowColor)),
        ),

        // ── Back button ──
        Positioned(
          top: topPadding + 8,
          left: 8,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),

        // ── Centered album art ──
        Positioned(
          top: topPadding + 48,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.35),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: CoverArtWidget(
                imageUrl: album.largeCoverUrl ?? album.coverUrl,
                size: artSize,
                borderRadius: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Album metadata ──────────────────────────────────────────────────────

class _AlbumInfo extends StatelessWidget {
  final Album album;

  const _AlbumInfo({required this.album});

  String _formatDuration(int? totalSeconds) {
    if (totalSeconds == null || totalSeconds == 0) return '';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Title ──
          Text(
            album.title,
            style: const TextStyle(
              color: AppTheme.onBackground,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          // ── Artist name (tappable) ──
          if (album.artist != null)
            GestureDetector(
              onTap: () => context.push('/browse/artist/${album.artist!.id}'),
              child: Text(
                album.artist!.name,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 10),

          // ── Metadata row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (album.releaseYear.isNotEmpty) ...[
                Text(
                  album.releaseYear,
                  style: const TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 13,
                  ),
                ),
                const _DotSeparator(),
              ],
              Text(
                '${album.tracksCount} ${album.tracksCount == 1 ? 'track' : 'tracks'}',
                style: const TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontSize: 13,
                ),
              ),
              if (album.duration != null && album.duration! > 0) ...[
                const _DotSeparator(),
                Text(
                  _formatDuration(album.duration),
                  style: const TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),

          // ── Tags ──
          if (album.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children:
                  album.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: AppTheme.onBackgroundMuted,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Play All / Shuffle buttons ──────────────────────────────────────────

class _ActionButtons extends ConsumerWidget {
  final Album album;
  final AsyncValue<List<Track>> tracksAsync;

  const _ActionButtons({required this.album, required this.tracksAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = tracksAsync.maybeWhen(
      data: (tracks) => tracks,
      orElse: () => <Track>[],
    );
    final hasTracks = tracks.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // ── Play All ──
          Expanded(
            child: SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed:
                    hasTracks
                        ? () {
                          ref
                              .read(playerProvider.notifier)
                              .playTracks(
                                tracks,
                                source: 'album_detail_play_all',
                              );
                        }
                        : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('Play All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.primary.withValues(
                    alpha: 0.3,
                  ),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ── Shuffle ──
          Expanded(
            child: SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed:
                    hasTracks
                        ? () {
                          final shuffled = List<Track>.from(tracks)..shuffle();
                          ref
                              .read(playerProvider.notifier)
                              .playTracks(
                                shuffled,
                                source: 'album_detail_shuffle',
                              );
                        }
                        : null,
                icon: const Icon(Icons.shuffle_rounded, size: 20),
                label: const Text('Shuffle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.onBackground,
                  disabledForegroundColor: AppTheme.onBackgroundSubtle
                      .withValues(alpha: 0.4),
                  side: BorderSide(
                    color:
                        hasTracks
                            ? AppTheme.onBackgroundSubtle
                            : AppTheme.onBackgroundSubtle.withValues(
                              alpha: 0.3,
                            ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dot separator ───────────────────────────────────────────────────────

class _DotSeparator extends StatelessWidget {
  const _DotSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '\u2022',
        style: TextStyle(color: AppTheme.onBackgroundSubtle, fontSize: 13),
      ),
    );
  }
}

// ── Shimmer loading state ───────────────────────────────────────────────

class _AlbumDetailShimmer extends StatelessWidget {
  const _AlbumDetailShimmer();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          SizedBox(height: topPadding + 48),
          // Album art placeholder
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Title placeholder
          Container(
            height: 22,
            width: 220,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 10),
          // Artist placeholder
          Container(
            height: 16,
            width: 140,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 24),
          // Buttons placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tracks shimmer
          const Expanded(child: ShimmerList(itemCount: 8, itemHeight: 56)),
        ],
      ),
    );
  }
}

// ── Error body ──────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.error,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load album',
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
            ),
          ),
        ],
      ),
    );
  }
}
