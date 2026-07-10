import 'package:tayra/core/analytics/analytics.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/easter_eggs/super_sonic_aura.dart';
import 'package:tayra/core/easter_eggs/super_sonic_ids.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/theme/palette_provider.dart';
import 'package:tayra/features/player/player_provider.dart';

/// Persistent mini-player bar shown above the bottom nav.
class MiniPlayer extends ConsumerWidget {
  /// Called when the user taps or swipes up on the mini-player.
  /// If null, defaults to pushing the `/now-playing` route.
  final VoidCallback? onTap;

  const MiniPlayer({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Select only the fields that affect the static parts of the mini-player
    // (track identity, playback state). Progress is handled by a child widget
    // so position ticks don't rebuild the whole bar.
    final (track, isPlaying, isLoading) = ref.watch(
      playerProvider.select((s) => (s.currentTrack, s.isPlaying, s.isLoading)),
    );

    if (track == null) return const SizedBox.shrink();

    final imageUrl = track.coverUrl;
    final paletteAsync = ref.watch(
      paletteColorsProvider(encodePaletteKey(imageUrl, track.album?.coverUrl)),
    );
    final accentColor = paletteAsync.maybeWhen(
      data: (color) => color,
      orElse: () => AppTheme.primary,
    );
    final gradientSecondColor = AppTheme.gradientSecondColor(
      accentColor,
      paletteAsync,
    );
    final superSonicActive = isSuperSonicMusic(track.mbid);

    return GestureDetector(
      onTap: () => onTap != null ? onTap!() : context.push('/now-playing'),
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity! < -200) {
          onTap != null ? onTap!() : context.push('/now-playing');
        }
      },
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        // Require a reasonably quick swipe to avoid accidental skips.
        if (v.abs() < 300) return;
        if (v > 0) {
          HapticFeedback.lightImpact();
          Analytics.track('swipe_to_skip', {
            'direction': 'previous',
            'source': 'mini_player',
          });
          ref.read(playerProvider.notifier).skipPrevious();
        } else {
          HapticFeedback.lightImpact();
          Analytics.track('swipe_to_skip', {
            'direction': 'next',
            'source': 'mini_player',
          });
          ref.read(playerProvider.notifier).skipNext();
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
            // Progress bar in its own widget — updates 5x/sec without
            // rebuilding the track-info and controls below.
            _MiniPlayerProgressBar(
              accentColor: accentColor,
              gradientSecondColor: gradientSecondColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Album art
                    SuperSonicAura(
                      active: superSonicActive,
                      glowPadding: superSonicActive ? 5 : 0,
                      artRadius: 6,
                      canvasOverflow: 18,
                      child: Container(
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
                                      (context, url) => const Icon(
                                        Icons.album,
                                        color: AppTheme.onBackgroundSubtle,
                                        size: 24,
                                      ),
                                  errorWidget:
                                      (context, url, error) => const Icon(
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
                    isLoading
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
                            isPlaying
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

// ── Progress bar ────────────────────────────────────────────────────────────

class _MiniPlayerProgressBar extends ConsumerWidget {
  final Color accentColor;
  final Color gradientSecondColor;

  const _MiniPlayerProgressBar({
    required this.accentColor,
    required this.gradientSecondColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(playerProvider.select((s) => s.progress));

    return LayoutBuilder(
      builder: (context, constraints) {
        const barHeight = 2.0;
        final filledWidth = constraints.maxWidth * progress.clamp(0.0, 1.0);
        return SizedBox(
          height: barHeight,
          width: constraints.maxWidth,
          child: Stack(
            children: [
              Container(height: barHeight, color: Colors.transparent),
              Container(
                height: barHeight,
                width: filledWidth,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor, gradientSecondColor],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
