import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/widgets/cover_art.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/favorites/favorites_provider.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/features/playlists/add_to_playlist_sheet.dart';
import 'package:tayra/core/api/models.dart';

/// A row widget for a single track in a list.
class TrackListTile extends ConsumerWidget {
  final Track track;
  final VoidCallback? onTap;
  final bool showAlbumArt;
  final bool showTrackNumber;
  final Widget? trailing;

  const TrackListTile({
    super.key,
    required this.track,
    this.onTap,
    this.showAlbumArt = true,
    this.showTrackNumber = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final isCurrentTrack = playerState.currentTrack?.id == track.id;

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
                              ? AppTheme.primary
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
                                ? AppTheme.primary
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
                                ? AppTheme.primaryLight
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
                    _formatDuration(track.duration!),
                    style: const TextStyle(
                      color: AppTheme.onBackgroundSubtle,
                      fontSize: 12,
                    ),
                  ),
                ),
              trailing ?? FavoriteButton(trackId: track.id, size: 20),
              const SizedBox(width: 4),
              _TrackMenuButton(track: track),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _TrackMenuButton extends ConsumerWidget {
  final Track track;

  const _TrackMenuButton({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      onSelected: (value) {
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
        }
      },
      itemBuilder:
          (context) => [
            const PopupMenuItem(
              value: 'play_next',
              child: Row(
                children: [
                  Icon(
                    Icons.queue_play_next,
                    size: 20,
                    color: AppTheme.onBackground,
                  ),
                  SizedBox(width: 12),
                  Text('Play next'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'add_queue',
              child: Row(
                children: [
                  Icon(
                    Icons.playlist_add,
                    size: 20,
                    color: AppTheme.onBackground,
                  ),
                  SizedBox(width: 12),
                  Text('Add to queue'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'add_playlist',
              child: Row(
                children: [
                  Icon(
                    Icons.playlist_add_rounded,
                    size: 20,
                    color: AppTheme.onBackground,
                  ),
                  SizedBox(width: 12),
                  Text('Add to playlist'),
                ],
              ),
            ),
          ],
    );
  }
}
