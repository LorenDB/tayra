import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/widgets/cover_art.dart';
import 'package:tayra/core/widgets/popup_menu_row.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/favorites/favorites_provider.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/features/playlists/add_to_playlist_sheet.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/features/settings/settings_provider.dart';

/// Fixed height for [TrackListTile] with album art (padding + 48px art).
///
/// Used with [SliverFixedExtentList] / `itemExtent` so scrolling lists avoid
/// measuring every child during layout.
const double kTrackListTileExtent = 64.0;

/// Fixed height for [TrackListTile] without album art (track-number rows).
///
/// Vertical padding (8×2) plus title/subtitle column (~39 with theme line
/// heights) is 55; use 56 so [SliverFixedExtentList] has a 1px cushion.
const double kTrackListTileExtentCompact = 56.0;

/// A row widget for a single track in a list.
class TrackListTile extends ConsumerWidget {
  final Track track;
  final VoidCallback? onTap;
  final Future<void> Function()? onRemoveFromPlaylist;
  final bool showAlbumArt;
  final bool showTrackNumber;

  /// When set, overrides [track.position] for display purposes (e.g. for
  /// continuous numbering across multiple discs).
  final int? overridePosition;
  final Widget? trailing;
  final Color? dominantColor;

  /// Lightened variant of [dominantColor] that meets WCAG AA contrast against
  /// the dark background. Used for text and small icons. When omitted it falls
  /// back to [dominantColor] (or [AppTheme.primary]) — callers that pass
  /// [dominantColor] should also pass this.
  final Color? textColor;

  /// When non-null, passed to [FavoriteButton.isFavoriteOverride] so rows can
  /// skip per-id favorite membership watches (e.g. Favorites screen).
  final bool? isFavoriteOverride;

  const TrackListTile({
    super.key,
    required this.track,
    this.onTap,
    this.showAlbumArt = true,
    this.showTrackNumber = false,
    this.overridePosition,
    this.trailing,
    this.onRemoveFromPlaylist,
    this.dominantColor,
    this.textColor,
    this.isFavoriteOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch a narrow provider so position ticks do not re-run a select on
    // every visible list row.
    final isCurrentTrack = ref.watch(currentPlayingTrackIdProvider) == track.id;

    // Offline filter: short-circuit avoids the second watch when inactive.
    final offlineFilterActive = ref.watch(offlineFilterActiveProvider);
    final isPlayable =
        !offlineFilterActive ||
        ref.watch(
          offlineTrackIdsProvider.select((ids) => ids.contains(track.id)),
        );

    final accent = textColor ?? dominantColor ?? AppTheme.primary;
    final titleColor =
        isCurrentTrack
            ? accent
            : (isPlayable
                ? AppTheme.onBackground
                : AppTheme.onBackground.withValues(alpha: 0.5));
    final subtitleColor =
        isCurrentTrack
            ? accent.withValues(alpha: 0.8)
            : (isPlayable
                ? AppTheme.onBackgroundMuted
                : AppTheme.onBackgroundMuted.withValues(alpha: 0.5));
    final numberColor =
        isCurrentTrack
            ? accent
            : (isPlayable
                ? AppTheme.onBackgroundSubtle
                : AppTheme.onBackgroundSubtle.withValues(alpha: 0.5));

    // GestureDetector instead of Material/InkWell: splash ink + Material
    // layers per row were a major Favorites scroll cost.
    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isPlayable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (showTrackNumber && !showAlbumArt)
                SizedBox(
                  width: 32,
                  child: Text(
                    '${overridePosition ?? track.position ?? ''}',
                    style: TextStyle(
                      color: numberColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (showAlbumArt) ...[
                CoverArtWidget(
                  imageUrl: track.thumbCoverUrl,
                  cacheKey: track.album?.thumbCoverUrl ?? track.thumbCoverUrl,
                  size: 48,
                  borderRadius: 6,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artistName,
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (track.duration != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    formatTrackDuration(track.duration!),
                    style: TextStyle(
                      color:
                          isPlayable
                              ? AppTheme.onBackgroundSubtle
                              : AppTheme.onBackgroundSubtle.withValues(
                                alpha: 0.5,
                              ),
                      fontSize: 12,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Defer cache membership watches until after first paint.
                    _DeferredCacheIndicator(trackId: track.id, accent: accent),
                    const SizedBox(width: 8),
                    trailing ??
                        FavoriteButton(
                          trackId: track.id,
                          size: 20,
                          isFavoriteOverride: isFavoriteOverride,
                        ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              _TrackMenuButton(
                track: track,
                onRemoveFromPlaylist: onRemoveFromPlaylist,
                enabled: isPlayable,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the download-done icon only after the first frame, so initial list
/// layout/scroll doesn't pay N× membership selects during mount.
class _DeferredCacheIndicator extends ConsumerStatefulWidget {
  final int trackId;
  final Color accent;

  const _DeferredCacheIndicator({required this.trackId, required this.accent});

  @override
  ConsumerState<_DeferredCacheIndicator> createState() =>
      _DeferredCacheIndicatorState();
}

class _DeferredCacheIndicatorState
    extends ConsumerState<_DeferredCacheIndicator> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Fixed-width slot so rows don't jump when the icon appears.
    if (!_ready) return const SizedBox(width: 18);

    final isCached = ref.watch(
      cachedAudioTrackIdsProvider.select((ids) => ids.contains(widget.trackId)),
    );
    if (!isCached) return const SizedBox(width: 18);

    final isManual = ref.watch(
      manualTrackIdsProvider.select((ids) => ids.contains(widget.trackId)),
    );
    return SizedBox(
      width: 18,
      child: Icon(
        Icons.download_done,
        size: 18,
        color: isManual ? widget.accent : AppTheme.onBackgroundSubtle,
      ),
    );
  }
}

/// Lightweight overflow menu — no [PopupMenuButton] element per row.
/// State (manual download, purge setting) is read only when the menu opens.
class _TrackMenuButton extends ConsumerWidget {
  final Track track;
  final Future<void> Function()? onRemoveFromPlaylist;
  final bool enabled;

  const _TrackMenuButton({
    required this.track,
    this.onRemoveFromPlaylist,
    this.enabled = true,
  });

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    if (!enabled) return;

    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset(box.size.width, 0), ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final isManual = ref.read(
      manualTrackIdsProvider.select((ids) => ids.contains(track.id)),
    );
    final showPurge = ref.read(
      settingsProvider.select((s) => s.effectiveShowPurgeCacheOption),
    );
    final albumAvailable = track.album != null;
    final artistAvailable = track.artist != null;

    final value = await showMenu<String>(
      context: context,
      position: position,
      color: AppTheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        const PopupMenuItem(
          value: 'play_next',
          child: PopupMenuRow(icon: Icons.queue_play_next, label: 'Play next'),
        ),
        const PopupMenuItem(
          value: 'add_queue',
          child: PopupMenuRow(icon: Icons.playlist_add, label: 'Add to queue'),
        ),
        const PopupMenuItem(
          value: 'add_playlist',
          child: PopupMenuRow(
            icon: Icons.playlist_add_rounded,
            label: 'Add to playlist',
          ),
        ),
        PopupMenuItem(
          value: 'toggle_manual',
          child: PopupMenuRow(
            icon: Icons.download_rounded,
            label: isManual ? 'Remove download' : 'Download',
          ),
        ),
        PopupMenuItem(
          value: 'go_to_album',
          enabled: albumAvailable,
          child: PopupMenuRow(
            icon: Icons.album,
            label: 'Go to album',
            muted: !albumAvailable,
          ),
        ),
        PopupMenuItem(
          value: 'go_to_artist',
          enabled: artistAvailable,
          child: PopupMenuRow(
            icon: Icons.person,
            label: 'Go to artist',
            muted: !artistAvailable,
          ),
        ),
        if (onRemoveFromPlaylist != null)
          const PopupMenuItem(
            value: 'remove_from_playlist',
            child: PopupMenuRow(
              icon: Icons.remove_circle_outline,
              label: 'Remove from playlist',
              destructive: true,
            ),
          ),
        if (showPurge)
          const PopupMenuItem(
            value: 'purge_cache',
            child: PopupMenuRow(
              icon: Icons.delete_forever_rounded,
              label: 'Purge and refetch',
              destructive: true,
            ),
          ),
      ],
    );

    if (value == null || !context.mounted) return;
    await _handleMenuAction(
      context: context,
      ref: ref,
      value: value,
      isManual: isManual,
    );
  }

  Future<void> _handleMenuAction({
    required BuildContext context,
    required WidgetRef ref,
    required String value,
    required bool isManual,
  }) async {
    final player = ref.read(playerProvider.notifier);
    switch (value) {
      case 'play_next':
        player.playNext(track);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playing "${track.title}" next')),
        );
        break;
      case 'add_queue':
        player.addToQueue([track]);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "${track.title}" to queue')),
        );
        break;
      case 'add_playlist':
        showAddToPlaylistSheet(context, ref, trackIds: [track.id]);
        break;
      case 'toggle_manual':
        try {
          final mgr = ref.read(cacheManagerProvider);
          await mgr.setManualDownloaded(CacheType.track, track.id, !isManual);
          final key = 'audio_${track.id}';
          unawaited(mgr.setFileProtected(key, !isManual));
          final manualNotifier = ref.read(manualTrackIdsProvider.notifier);
          if (!isManual) {
            manualNotifier.add(track.id);
          } else {
            manualNotifier.remove(track.id);
          }
          final wasCached = ref
              .read(cachedAudioTrackIdsProvider)
              .contains(track.id);
          if (!context.mounted) return;
          if (!wasCached && !isManual) {
            final api = ref.read(cachedFunkwhaleApiProvider);
            if (track.listenUrl != null) {
              final streamUrl = api.getStreamUrl(track.listenUrl!);
              final headers = api.authHeaders;
              final audioSvc = ref.read(audioCacheServiceProvider);
              unawaited(
                audioSvc.cacheAudio(track, streamUrl, headers).then((file) {
                  if (file != null) {
                    ref
                        .read(cachedAudioTrackIdsProvider.notifier)
                        .add(track.id);
                  }
                }),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Download queued for "${track.title}"')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Download added for "${track.title}"')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  !isManual
                      ? 'Download added for "${track.title}"'
                      : 'Download removed for "${track.title}"',
                ),
              ),
            );
          }
        } catch (e, st) {
          debugPrint('Track toggle manual failed: $e');
          debugPrintStack(stackTrace: st);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update download flag')),
            );
          }
        }
        break;
      case 'go_to_album':
        if (track.album != null) {
          context.push('/album/${track.album!.id}');
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Album not available')));
        }
        break;
      case 'go_to_artist':
        if (track.artist != null) {
          context.push('/artist/${track.artist!.id}');
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Artist not available')));
        }
        break;
      case 'remove_from_playlist':
        if (onRemoveFromPlaylist != null) {
          try {
            await onRemoveFromPlaylist!();
          } catch (e) {
            debugPrint('Remove from playlist action failed: $e');
          }
        }
        break;
      case 'purge_cache':
        try {
          final mgr = CacheManager.instance;
          await mgr.deleteMetadata('track_${track.id}');
          await mgr.deleteAudioFilesOnDisk(track.id);
          if (track.album != null) {
            await mgr.deleteMetadataLike('tracks_p%_al${track.album!.id}_%');
          }
          ref.read(cachedAudioTrackIdsProvider.notifier).remove(track.id);
          ref.read(manualTrackIdsProvider.notifier).remove(track.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cache purged for "${track.title}" — pull to refresh',
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('Purge cache failed: $e');
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No provider watches here — keeps the menu icon out of rebuild storms.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => _openMenu(context, ref) : null,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(
          Icons.more_vert,
          size: 18,
          color:
              enabled
                  ? AppTheme.onBackgroundSubtle
                  : AppTheme.onBackgroundSubtle.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
