import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:funkwhale/core/theme/app_theme.dart';
import 'package:funkwhale/core/theme/palette_provider.dart';
import 'package:funkwhale/features/player/player_provider.dart';

/// Persistent mini-player bar shown above the bottom nav.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final track = playerState.currentTrack;

    if (track == null) return const SizedBox.shrink();

    final imageUrl = track.coverUrl;
    final dominantColorAsync = ref.watch(dominantColorProvider(imageUrl));
    final accentColor = dominantColorAsync.valueOrNull ?? AppTheme.primary;

    return GestureDetector(
      onTap: () => context.push('/now-playing'),
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity! < -200) {
          context.push('/now-playing');
        }
      },
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
        ),
        child: Column(
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: playerState.progress,
              backgroundColor: Colors.transparent,
              color: accentColor,
              minHeight: 2,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Album art
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: AppTheme.surfaceContainerHigh,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child:
                          track.coverUrl != null
                              ? CachedNetworkImage(
                                imageUrl: track.coverUrl!,
                                fit: BoxFit.cover,
                                placeholder:
                                    (_, __) => const Icon(
                                      Icons.album,
                                      color: AppTheme.onBackgroundSubtle,
                                      size: 24,
                                    ),
                                errorWidget:
                                    (_, __, ___) => const Icon(
                                      Icons.album,
                                      color: AppTheme.onBackgroundSubtle,
                                      size: 24,
                                    ),
                              )
                              : const Icon(
                                Icons.album,
                                color: AppTheme.onBackgroundSubtle,
                                size: 24,
                              ),
                    ),
                    const SizedBox(width: 12),
                    // Track info
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: const TextStyle(
                              color: AppTheme.onBackground,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artistName,
                            style: const TextStyle(
                              color: AppTheme.onBackgroundMuted,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Controls
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, size: 28),
                      color: AppTheme.onBackground,
                      onPressed:
                          () =>
                              ref.read(playerProvider.notifier).skipPrevious(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36),
                    ),
                    playerState.isLoading
                        ? const SizedBox(
                          width: 36,
                          height: 36,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary,
                            ),
                          ),
                        )
                        : IconButton(
                          icon: Icon(
                            playerState.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 32,
                          ),
                          color: AppTheme.onBackground,
                          onPressed:
                              () =>
                                  ref
                                      .read(playerProvider.notifier)
                                      .togglePlayPause(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36),
                        ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 28),
                      color: AppTheme.onBackground,
                      onPressed:
                          () => ref.read(playerProvider.notifier).skipNext(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
