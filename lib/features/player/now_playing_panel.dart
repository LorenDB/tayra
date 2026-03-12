import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/theme/palette_provider.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/features/favorites/favorites_provider.dart';

/// A side-panel version of the now-playing screen for desktop layouts.
/// Designed to sit in a ~340px wide column alongside the main content.
class NowPlayingPanel extends ConsumerStatefulWidget {
  const NowPlayingPanel({super.key});

  @override
  ConsumerState<NowPlayingPanel> createState() => _NowPlayingPanelState();
}

class _NowPlayingPanelState extends ConsumerState<NowPlayingPanel> {
  bool _isSeeking = false;
  double _seekValue = 0.0;

  // ── Helpers ──────────────────────────────────────────────────────────

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _onSeekStart(double value) {
    setState(() {
      _isSeeking = true;
      _seekValue = value;
    });
  }

  void _onSeekUpdate(double value) {
    setState(() => _seekValue = value);
  }

  void _onSeekEnd(double value) {
    final duration = ref.read(playerProvider).duration;
    final position = Duration(
      milliseconds: (value * duration.inMilliseconds).round(),
    );
    ref.read(playerProvider.notifier).seekTo(position);
    setState(() => _isSeeking = false);
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final track = playerState.currentTrack;

    if (track == null) return const SizedBox.shrink();

    final imageUrl = track.largeCoverUrl ?? track.coverUrl;
    final dominantColorAsync = ref.watch(dominantColorProvider(imageUrl));
    final glowColor = dominantColorAsync.valueOrNull ?? AppTheme.primary;

    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                const Text(
                  'NOW PLAYING',
                  style: TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.queue_music_rounded, size: 22),
                  color: AppTheme.onBackgroundMuted,
                  onPressed: () => context.push('/queue'),
                  tooltip: 'Queue',
                ),
              ],
            ),
          ),

          // ── Album art ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildAlbumArt(track, glowColor),
          ),

          const SizedBox(height: 20),

          // ── Track info ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildTrackInfo(track),
          ),

          const SizedBox(height: 16),

          // ── Seek bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSeekBar(playerState, glowColor),
          ),

          const SizedBox(height: 8),

          // ── Transport controls ──
          _buildTransportControls(playerState, glowColor),

          const Spacer(),
        ],
      ),
    );
  }

  // ── Album art ────────────────────────────────────────────────────────

  Widget _buildAlbumArt(Track track, Color glowColor) {
    final imageUrl = track.largeCoverUrl ?? track.coverUrl;

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.25),
              blurRadius: 30,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child:
            imageUrl != null
                ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _buildPlaceholder(),
                  errorWidget: (_, __, ___) => _buildPlaceholder(),
                )
                : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.surfaceContainerHigh,
      child: const Center(
        child: Icon(
          Icons.album_rounded,
          color: AppTheme.onBackgroundSubtle,
          size: 64,
        ),
      ),
    );
  }

  // ── Track info ───────────────────────────────────────────────────────

  Widget _buildTrackInfo(Track track) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: const TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artistName,
                    style: const TextStyle(
                      color: AppTheme.onBackgroundMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            FavoriteButton(trackId: track.id, size: 24),
          ],
        ),
      ],
    );
  }

  // ── Seek bar ─────────────────────────────────────────────────────────

  Widget _buildSeekBar(PlayerState playerState, Color glowColor) {
    final progress = _isSeeking ? _seekValue : playerState.progress;
    final currentPosition =
        _isSeeking
            ? Duration(
              milliseconds:
                  (_seekValue * playerState.duration.inMilliseconds).round(),
            )
            : playerState.position;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: glowColor,
            inactiveTrackColor: AppTheme.surfaceContainerHighest,
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            trackHeight: 3,
            overlayColor: glowColor.withValues(alpha: 0.15),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChangeStart: _onSeekStart,
            onChanged: _onSeekUpdate,
            onChangeEnd: _onSeekEnd,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(currentPosition),
                style: const TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDuration(playerState.duration),
                style: const TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Transport controls ───────────────────────────────────────────────

  Widget _buildTransportControls(PlayerState playerState, Color glowColor) {
    final notifier = ref.read(playerProvider.notifier);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Shuffle
        IconButton(
          icon: const Icon(Icons.shuffle_rounded, size: 20),
          color:
              playerState.isShuffled
                  ? AppTheme.secondary
                  : AppTheme.onBackgroundSubtle,
          onPressed: () => notifier.toggleShuffle(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          tooltip: 'Shuffle',
        ),
        const SizedBox(width: 8),
        // Previous
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, size: 30),
          color: AppTheme.onBackground,
          onPressed: () => notifier.skipPrevious(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        const SizedBox(width: 8),
        // Play / Pause
        _PlayPauseButton(
          playerState: playerState,
          glowColor: glowColor,
          onPressed: () => notifier.togglePlayPause(),
        ),
        const SizedBox(width: 8),
        // Next
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, size: 30),
          color: AppTheme.onBackground,
          onPressed: playerState.hasNext ? () => notifier.skipNext() : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        const SizedBox(width: 8),
        // Loop
        _LoopButton(
          loopMode: playerState.loopMode,
          onPressed: () => notifier.toggleLoopMode(),
        ),
      ],
    );
  }
}

// ── Play/Pause button ───────────────────────────────────────────────────

class _PlayPauseButton extends StatelessWidget {
  final PlayerState playerState;
  final Color glowColor;
  final VoidCallback onPressed;

  const _PlayPauseButton({
    required this.playerState,
    required this.glowColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (playerState.isLoading) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(shape: BoxShape.circle, color: glowColor),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: glowColor,
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.35),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          playerState.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

// ── Loop button ─────────────────────────────────────────────────────────

class _LoopButton extends StatelessWidget {
  final LoopMode loopMode;
  final VoidCallback onPressed;

  const _LoopButton({required this.loopMode, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;

    switch (loopMode) {
      case LoopMode.off:
        icon = Icons.repeat_rounded;
        color = AppTheme.onBackgroundSubtle;
        break;
      case LoopMode.all:
        icon = Icons.repeat_rounded;
        color = AppTheme.secondary;
        break;
      case LoopMode.one:
        icon = Icons.repeat_one_rounded;
        color = AppTheme.secondary;
        break;
    }

    return IconButton(
      icon: Icon(icon, size: 20),
      color: color,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      tooltip: 'Repeat',
    );
  }
}
