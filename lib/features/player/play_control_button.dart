import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/player/player_provider.dart';

/// Visual shell shared by the mini-player and the now-playing transport.
enum PlaybackPlayButtonVariant {
  /// Compact icon button used in the mini-player bar.
  mini,

  /// Large accent circle used on the now-playing surface.
  emphasis,
}

/// Play / pause control. While the player is loading, the spinner stays a
/// button: a tap cancels the in-flight attempt back to a paused, retryable
/// state instead of being ignored.
class PlaybackPlayButton extends ConsumerWidget {
  final PlaybackPlayButtonVariant variant;
  final double size;
  final double iconSize;
  final Color accentColor;

  const PlaybackPlayButton({
    super.key,
    required this.variant,
    this.size = 36,
    this.iconSize = 32,
    this.accentColor = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(playerProvider.select((s) => s.isLoading));
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final tooltip = isLoading ? 'Stop loading' : (isPlaying ? 'Pause' : 'Play');

    if (variant == PlaybackPlayButtonVariant.mini) {
      return IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36),
        onPressed: () => _onPressed(ref, isLoading: isLoading),
        icon:
            isLoading
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.onBackground,
                  ),
                )
                : Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 32,
                  color: AppTheme.onBackground,
                ),
      );
    }

    final spinnerSize = iconSize * 0.44;
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onPressed(ref, isLoading: isLoading),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor,
            boxShadow:
                isLoading
                    ? null
                    : [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.4),
                        blurRadius: size * 0.25,
                        spreadRadius: 1,
                        offset: Offset(0, size * 0.0625),
                      ),
                    ],
          ),
          child: Center(
            child:
                isLoading
                    ? SizedBox(
                      width: spinnerSize,
                      height: spinnerSize,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                    : Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: iconSize,
                    ),
          ),
        ),
      ),
    );
  }

  void _onPressed(WidgetRef ref, {required bool isLoading}) {
    final notifier = ref.read(playerProvider.notifier);
    if (isLoading) {
      notifier.cancelOrRetryLoad();
      return;
    }
    notifier.togglePlayPause();
  }
}
