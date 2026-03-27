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
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/cache/cache_manager.dart';

/// A row widget for a single track in a list.
class TrackListTile extends ConsumerWidget {
  final Track track;
  final VoidCallback? onTap;
  final Future<void> Function()? onRemoveFromPlaylist;
  final bool showAlbumArt;
  final bool showTrackNumber;
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
    this.trailing,
    this.onRemoveFromPlaylist,
    this.dominantColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final isCurrentTrack = playerState.currentTrack?.id == track.id;

    final isCachedAsync = ref.watch(isAudioCachedProvider(track.id));
    final isManualAsync = ref.watch(isManualTrackProvider(track.id));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (showTrackNumber && !showAlbumArt)
                SizedBox(
                  width: 32,
                  child: Text(
                    '${track.position ?? ''}',
                    style: TextStyle(
                      color:
                          isCurrentTrack
                              ? textColor ?? dominantColor ?? AppTheme.primary
                              : AppTheme.onBackgroundSubtle,
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
                        color:
                            isCurrentTrack
                                ? textColor ?? dominantColor ?? AppTheme.primary
                                : AppTheme.onBackground,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artistName,
                      style: TextStyle(
                        color:
                            isCurrentTrack
                                ? (textColor ??
                                        dominantColor ??
                                        AppTheme.primary)
                                    .withValues(alpha: 0.8)
                                : AppTheme.onBackgroundMuted,
                        fontSize: 12,
                      ),
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
                    style: const TextStyle(
                      color: AppTheme.onBackgroundSubtle,
                      fontSize: 12,
                    ),
                  ),
                ),
              // Show cached/manual-downloaded indicator, then favorite button
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cached indicator
                    isCachedAsync.when(
                      data: (isCached) {
                        if (!isCached) return const SizedBox.shrink();
                        // If manually downloaded, color with accent; otherwise muted
                        final isManual = isManualAsync.asData?.value ?? false;
                        return Icon(
                          Icons.download_done,
                          size: 18,
                          color:
                              isManual
                                  ? (textColor ??
                                      dominantColor ??
                                      AppTheme.primary)
                                  : AppTheme.onBackgroundSubtle,
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackMenuButton extends ConsumerWidget {
  final Track track;
  final Future<void> Function()? onRemoveFromPlaylist;

  const _TrackMenuButton({required this.track, this.onRemoveFromPlaylist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumAvailable = track.album != null;
    final artistAvailable = track.artist != null;
    final isManualAsync = ref.watch(isManualTrackProvider(track.id));

    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        size: 18,
        color: AppTheme.onBackgroundSubtle,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      color: AppTheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
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
              final isManual = isManualAsync.asData?.value ?? false;
              await mgr.setManualDownloaded(
                CacheType.track,
                track.id,
                !isManual,
              );
              // Ensure the cached file is marked protected/unprotected so
              // the LRU eviction skips manually downloaded files.
              final key = 'audio_${track.id}';
              unawaited(mgr.setFileProtected(key, !isManual));
              // Refresh manual flag provider
              ref.invalidate(isManualTrackProvider(track.id));
              // If the track wasn't cached and the user just enabled
              // manual download, queue a background download.
              final wasCached = await ref.read(
                isAudioCachedProvider(track.id).future,
              );
              if (!wasCached && !isManual) {
                final api = ref.read(cachedFunkwhaleApiProvider);
                if (track.listenUrl != null) {
                  final streamUrl = api.getStreamUrl(track.listenUrl!);
                  final headers = api.authHeaders;
                  final audioSvc = ref.read(audioCacheServiceProvider);
                  unawaited(
                    audioSvc.cacheAudio(track, streamUrl, headers).then((file) {
                      if (file != null)
                        ref.invalidate(isAudioCachedProvider(track.id));
                    }),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Download queued for "${track.title}"'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Download added for "${track.title}"'),
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
        }
      },
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
                  Text(
                    isManualAsync.asData?.value == true
                        ? 'Remove download'
                        : 'Download',
                  ),
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
          ],
    );
  }
}
