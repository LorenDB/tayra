import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/theme/palette_provider.dart';
import 'package:tayra/core/widgets/cover_art.dart';
import 'package:tayra/core/widgets/dot_separator.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/core/widgets/tag_chip_list.dart';
import 'package:tayra/core/widgets/track_list_tile.dart';
import 'package:tayra/core/cache/download_queue_service.dart';
import 'package:tayra/features/player/player_provider.dart';

// ── Providers ───────────────────────────────────────────────────────────

final _albumDetailProvider = FutureProvider.family<Album, int>((ref, albumId) {
  ref.keepAlive();
  final api = ref.watch(cachedFunkwhaleApiProvider);
  return api.getAlbum(albumId);
});

// Tracks are loaded page-by-page and emitted incrementally so the UI can
// render the first batch immediately without waiting for all pages.
class _AlbumTracksNotifier extends AsyncNotifier<List<Track>> {
  final int albumId;

  _AlbumTracksNotifier(this.albumId);

  @override
  Future<List<Track>> build() async {
    ref.keepAlive();
    return _fetchAllPages();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchAllPages);
  }

  Future<List<Track>> _fetchAllPages() async {
    final api = ref.read(cachedFunkwhaleApiProvider);
    final allTracks = <Track>[];
    int page = 1;
    while (true) {
      final response = await api.getTracks(
        album: albumId,
        ordering: 'position',
        pageSize: 100,
        page: page,
      );
      allTracks.addAll(response.results);
      sortTracksByDiscAndPosition(allTracks);
      // Emit after each page so the UI shows tracks as they arrive.
      state = AsyncData(List<Track>.unmodifiable(allTracks));
      if (response.next == null) break;
      page++;
    }
    return List<Track>.unmodifiable(allTracks);
  }
}

final _albumTracksProvider =
    AsyncNotifierProvider.family<_AlbumTracksNotifier, List<Track>, int>(
      (int albumId) => _AlbumTracksNotifier(albumId),
    );

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
            (error, stack) => DetailPageErrorBody(
              title: 'Failed to load album',
              message: error.toString(),
              onRetry: () {
                ref.invalidate(_albumDetailProvider(albumId));
                ref.read(_albumTracksProvider(albumId).notifier).reload();
              },
            ),
        data: (album) {
          final imageUrl = album.largeCoverUrl ?? album.coverUrl;
          final paletteAsync = ref.watch(paletteColorsProvider(imageUrl));
          final dominantColor = paletteAsync.maybeWhen(
            data: (color) => color,
            orElse: () => AppTheme.primary,
          );
          // Text-safe variant: same hue/saturation but lightened enough to
          // meet WCAG AA (4.5:1) against the AMOLED black background. Used
          // for text, small icons, and outlined-button foregrounds where the
          // accent color itself may be too dark to read.
          final textColor = lightenForText(dominantColor);

          return RefreshIndicator(
            color: dominantColor,
            backgroundColor: AppTheme.surfaceContainer,
            onRefresh: () async {
              ref.invalidate(_albumDetailProvider(albumId));
              ref.read(_albumTracksProvider(albumId).notifier).reload();
              await ref.read(_albumDetailProvider(albumId).future);
            },
            child: _AlbumDetailBody(
              album: album,
              tracksAsync: tracksAsync,
              dominantColor: dominantColor,
              textColor: textColor,
            ),
          );
        },
      ),
    );
  }
}

// ── Detail body ─────────────────────────────────────────────────────────

class _AlbumDetailBody extends ConsumerWidget {
  final Album album;
  final AsyncValue<List<Track>> tracksAsync;
  final Color dominantColor;
  final Color textColor;

  const _AlbumDetailBody({
    required this.album,
    required this.tracksAsync,
    required this.dominantColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Album header with glow ──
        SliverToBoxAdapter(
          child: _AlbumHeader(
            album: album,
            glowColor: dominantColor,
            tracksAsync: tracksAsync,
          ),
        ),

        // ── Album info ──
        SliverToBoxAdapter(
          child: tracksAsync.when(
            data:
                (tracks) => _AlbumInfo(
                  album: album,
                  dominantColor: dominantColor,
                  textColor: textColor,
                  totalDuration: tracks.fold<int>(
                    0,
                    (sum, track) => sum + (track.duration ?? 0),
                  ),
                ),
            loading: () => _AlbumInfo(album: album),
            error: (_, _) => _AlbumInfo(album: album),
          ),
        ),

        // ── Action buttons ──
        SliverToBoxAdapter(
          child: _ActionButtons(
            album: album,
            tracksAsync: tracksAsync,
            dominantColor: dominantColor,
            textColor: textColor,
          ),
        ),

        // ── Track list ──
        tracksAsync.when(
          loading:
              () => const SliverFillRemaining(
                hasScrollBody: false,
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
                  dominantColor: dominantColor,
                  textColor: textColor,
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

class _AlbumHeader extends ConsumerWidget {
  final Album album;
  final Color glowColor;
  final AsyncValue<List<Track>> tracksAsync;

  const _AlbumHeader({
    required this.album,
    required this.glowColor,
    required this.tracksAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    const artSize = 240.0;

    final isManualAsync = ref.watch(isManualAlbumProvider(album.id));
    final isManual = isManualAsync.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );

    Future<void> toggleDownload() async {
      // Ensure we have the full list of tracks (wait for paging to finish
      // if necessary) so downloads are queued for every track.
      final tracks = await ref.read(_albumTracksProvider(album.id).future);
      final mgr = ref.read(cacheManagerProvider);
      try {
        final current = await ref.read(isManualAlbumProvider(album.id).future);
        await mgr.setManualDownloaded(CacheType.album, album.id, !current);
        // Also mark/unmark each track at the track level so the UI shows
        // per-track downloaded indicators and protection is applied per-file.
        final albumTracks = await ref.read(
          _albumTracksProvider(album.id).future,
        );
        for (final t in albumTracks) {
          try {
            await mgr.setManualDownloaded(CacheType.track, t.id, !current);
            ref.invalidate(isManualTrackProvider(t.id));
          } catch (_) {}
        }
        await mgr.bulkSetFilesProtectedForParent(
          CacheType.album,
          album.id,
          !current,
        );
        ref.invalidate(isManualAlbumProvider(album.id));

        if (!current) {
          // Enabling: queue background downloads, invalidating cache indicator
          // per-track as each download completes so the UI updates live.
          final queue = ref.read(downloadQueueServiceProvider);
          final trackIds =
              tracks
                  .where((t) => t.listenUrl != null)
                  .map((t) => t.id)
                  .toList();
          unawaited(queue.enqueue(trackIds, ref));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Download queued for "${album.title}"')),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Download removed for "${album.title}"')),
            );
          }
        }
      } catch (e, st) {
        debugPrint('Album toggle manual failed: $e');
        debugPrintStack(stackTrace: st);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update download flag')),
          );
        }
      }
    }

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

        // ── Three-dot menu (top-right) ──
        Positioned(
          top: topPadding + 8,
          right: 8,
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: AppTheme.surfaceContainer,
            onSelected: (value) {
              if (value == 'download') toggleDownload();
            },
            itemBuilder:
                (_) => [
                  PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(
                          isManual
                              ? Icons.download_done_rounded
                              : Icons.download_rounded,
                          size: 20,
                          color: AppTheme.onBackground,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isManual ? 'Remove download' : 'Download',
                          style: const TextStyle(color: AppTheme.onBackground),
                        ),
                      ],
                    ),
                  ),
                ],
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
  final int? totalDuration;
  final Color? dominantColor;
  final Color? textColor;

  const _AlbumInfo({
    required this.album,
    this.totalDuration,
    this.dominantColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final displayDuration =
        (album.duration != null && album.duration! > 0)
            ? album.formattedDuration
            : (totalDuration != null && totalDuration! > 0)
            ? formatTotalDuration(totalDuration!)
            : null;

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
                style: TextStyle(
                  color: textColor ?? dominantColor ?? AppTheme.primary,
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
                const DotSeparator(),
              ],
              Text(
                pluralizeTrack(album.tracksCount),
                style: const TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontSize: 13,
                ),
              ),
              if (displayDuration != null) ...[
                const DotSeparator(),
                Text(
                  displayDuration,
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
            TagChipList(tags: album.tags),
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
  final Color dominantColor;
  final Color textColor;

  const _ActionButtons({
    required this.album,
    required this.tracksAsync,
    required this.dominantColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = tracksAsync.asData?.value ?? [];

    void playAll() {
      if (tracks.isEmpty) return;
      ref
          .read(playerProvider.notifier)
          .playTracks(tracks, source: 'album_detail_play_all');
    }

    void shuffleAll() {
      if (tracks.isEmpty) return;
      final shuffled = List<Track>.from(tracks)..shuffle();
      ref
          .read(playerProvider.notifier)
          .playTracks(shuffled, source: 'album_detail_shuffle');
    }

    // Use simple, non-gradient buttons: primary is an ElevatedButton, secondary
    // is an OutlinedButton. This matches the requested simple icon button
    // layout (no gradient styles).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // ── Play All ──
          Expanded(
            child: SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: tracks.isNotEmpty ? playAll : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('Play All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: dominantColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: dominantColor.withValues(alpha: 0.3),
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
                onPressed: tracks.isNotEmpty ? shuffleAll : null,
                icon: const Icon(Icons.shuffle_rounded, size: 20),
                label: const Text('Shuffle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      tracks.isNotEmpty
                          ? textColor
                          : AppTheme.onBackgroundSubtle.withValues(alpha: 0.4),
                  disabledForegroundColor: AppTheme.onBackgroundSubtle
                      .withValues(alpha: 0.4),
                  side: BorderSide(
                    color:
                        tracks.isNotEmpty
                            ? textColor
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
