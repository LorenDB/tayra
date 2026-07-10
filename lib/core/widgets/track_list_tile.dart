import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/widgets/cover_art.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/favorites/favorites_provider.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/features/playlists/add_to_playlist_sheet.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/features/settings/settings_provider.dart';

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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrentTrack = ref.watch(
      playerProvider.select((s) => s.currentTrack?.id == track.id),
    );

    // Membership selects on bulk in-memory sets — no per-row disk/DB I/O.
    // Only this tile rebuilds when *its* membership bit flips.
    final isCached = ref.watch(
      cachedAudioTrackIdsProvider.select((ids) => ids.contains(track.id)),
    );
    final isManual = ref.watch(
      manualTrackIdsProvider.select((ids) => ids.contains(track.id)),
    );

    // When the offline content filter is active, tracks that are not present
    // in the offline track ID set should be considered unplayable. We apply
    // a disabled visual treatment and prevent the tap handler in that case.
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

    // Isolate each row's paint from neighbors / scrolling header glow.
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isPlayable ? onTap : null,
          borderRadius: BorderRadius.circular(8),
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
                    imageUrl: track.coverUrl,
                    cacheKey: track.album?.coverUrl ?? track.coverUrl,
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
                // Cached/manual-downloaded indicator, then favorite button
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCached)
                        Icon(
                          Icons.download_done,
                          size: 18,
                          color:
                              isManual ? accent : AppTheme.onBackgroundSubtle,
                        ),
                      const SizedBox(width: 8),
                      trailing ?? FavoriteButton(trackId: track.id, size: 20),
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
      ),
    );
  }
}

class _TrackMenuButton extends ConsumerWidget {
  final Track track;
  final Future<void> Function()? onRemoveFromPlaylist;
  final bool enabled;

  const _TrackMenuButton({
    required this.track,
    this.onRemoveFromPlaylist,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumAvailable = track.album != null;
    final artistAvailable = track.artist != null;
    final isManual = ref.watch(
      manualTrackIdsProvider.select((ids) => ids.contains(track.id)),
    );
    final showPurge = ref.watch(
      settingsProvider.select((s) => s.effectiveShowPurgeCacheOption),
    );

    return PopupMenuButton<String>(
      enabled: enabled,
      icon: const Icon(
        Icons.more_vert,
        size: 18,
        color: AppTheme.onBackgroundSubtle,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      color: AppTheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected:
          enabled
              ? (value) async {
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
                      SnackBar(
                        content: Text('Added "${track.title}" to queue'),
                      ),
                    );
                    break;
                  case 'add_playlist':
                    showAddToPlaylistSheet(context, ref, trackIds: [track.id]);
                    break;
                  case 'toggle_manual':
                    try {
                      final mgr = ref.read(cacheManagerProvider);
                      await mgr.setManualDownloaded(
                        CacheType.track,
                        track.id,
                        !isManual,
                      );
                      // Ensure the cached file is marked protected/unprotected so
                      // the LRU eviction skips manually downloaded files.
                      final key = 'audio_${track.id}';
                      unawaited(mgr.setFileProtected(key, !isManual));
                      final manualNotifier = ref.read(
                        manualTrackIdsProvider.notifier,
                      );
                      if (!isManual) {
                        manualNotifier.add(track.id);
                      } else {
                        manualNotifier.remove(track.id);
                      }
                      // If the track wasn't cached and the user just enabled
                      // manual download, queue a background download.
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
                            audioSvc.cacheAudio(track, streamUrl, headers).then(
                              (file) {
                                if (file != null) {
                                  ref
                                      .read(
                                        cachedAudioTrackIdsProvider.notifier,
                                      )
                                      .add(track.id);
                                }
                              },
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Download queued for "${track.title}"',
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Download added for "${track.title}"',
                              ),
                            ),
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
                          const SnackBar(
                            content: Text('Failed to update download flag'),
                          ),
                        );
                      }
                    }
                    break;
                  case 'go_to_album':
                    if (albumAvailable) {
                      context.push('/album/${track.album!.id}');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Album not available')),
                      );
                    }
                    break;
                  case 'go_to_artist':
                    if (artistAvailable) {
                      context.push('/artist/${track.artist!.id}');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Artist not available')),
                      );
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
                      // Delete individual track metadata
                      await mgr.deleteMetadata('track_${track.id}');
                      // Delete cached audio file (DB entry + disk, including orphans)
                      await mgr.deleteAudioFilesOnDisk(track.id);
                      // Delete all paginated track-list pages that include this album
                      if (track.album != null) {
                        await mgr.deleteMetadataLike(
                          'tracks_p%_al${track.album!.id}_%',
                        );
                      }
                      ref
                          .read(cachedAudioTrackIdsProvider.notifier)
                          .remove(track.id);
                      ref
                          .read(manualTrackIdsProvider.notifier)
                          .remove(track.id);
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
              : null,
      itemBuilder:
          (context) => [
            PopupMenuItem(
              value: 'play_next',
              child: Row(
                children: [
                  Icon(
                    Icons.queue_play_next,
                    size: 20,
                    color: AppTheme.onBackground,
                  ),
                  const SizedBox(width: 12),
                  const Text('Play next'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'add_queue',
              child: Row(
                children: [
                  Icon(
                    Icons.playlist_add,
                    size: 20,
                    color: AppTheme.onBackground,
                  ),
                  const SizedBox(width: 12),
                  const Text('Add to queue'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'add_playlist',
              child: Row(
                children: [
                  Icon(
                    Icons.playlist_add_rounded,
                    size: 20,
                    color: AppTheme.onBackground,
                  ),
                  const SizedBox(width: 12),
                  const Text('Add to playlist'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle_manual',
              child: Row(
                children: [
                  Icon(
                    Icons.download_rounded,
                    size: 20,
                    color: AppTheme.onBackground,
                  ),
                  const SizedBox(width: 12),
                  Text(isManual ? 'Remove download' : 'Download'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'go_to_album',
              enabled: albumAvailable,
              child: Row(
                children: [
                  Icon(
                    Icons.album,
                    size: 20,
                    color:
                        albumAvailable
                            ? AppTheme.onBackground
                            : AppTheme.onBackgroundMuted,
                  ),
                  const SizedBox(width: 12),
                  const Text('Go to album'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'go_to_artist',
              enabled: artistAvailable,
              child: Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 20,
                    color:
                        artistAvailable
                            ? AppTheme.onBackground
                            : AppTheme.onBackgroundMuted,
                  ),
                  const SizedBox(width: 12),
                  const Text('Go to artist'),
                ],
              ),
            ),
            if (onRemoveFromPlaylist != null)
              PopupMenuItem(
                value: 'remove_from_playlist',
                child: Row(
                  children: [
                    Icon(
                      Icons.remove_circle_outline,
                      size: 20,
                      color: AppTheme.error,
                    ),
                    const SizedBox(width: 12),
                    const Text('Remove from playlist'),
                  ],
                ),
              ),
            if (showPurge)
              const PopupMenuItem(
                value: 'purge_cache',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_forever_rounded,
                      size: 20,
                      color: AppTheme.error,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Purge and refetch',
                      style: TextStyle(color: AppTheme.error),
                    ),
                  ],
                ),
              ),
          ],
    );
  }
}
