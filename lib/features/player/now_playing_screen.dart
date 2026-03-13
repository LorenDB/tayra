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

/// Full-screen Now Playing screen with album art, controls, and seek bar.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  /// Whether the user is currently dragging the seek slider.
  bool _isSeeking = false;

  /// Slider value while seeking (0.0 – 1.0).
  double _seekValue = 0.0;

  late final AnimationController _glowAnimController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _glowAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowAnimController.dispose();
    super.dispose();
  }

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
    setState(() {
      _seekValue = value;
    });
  }

  void _onSeekEnd(double value) {
    final duration = ref.read(playerProvider).duration;
    final position = Duration(
      milliseconds: (value * duration.inMilliseconds).round(),
    );
    ref.read(playerProvider.notifier).seekTo(position);
    setState(() {
      _isSeeking = false;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final track = playerState.currentTrack;

    // Extract accent colors from the current track's cover art.
    final imageUrl = track?.largeCoverUrl ?? track?.coverUrl;
    final paletteAsync = ref.watch(albumPaletteProvider(imageUrl));
    final palette = paletteAsync.maybeWhen(
      data: (p) => p,
      orElse: () => const AlbumPalette(primary: AppTheme.primary),
    );
    final glowColor = palette.primary;
    final glowSecondaryColor = palette.secondary;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          // Swipe down to dismiss
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            context.pop();
          }
        },
        child: SafeArea(
          child:
              track == null
                  ? const Center(
                    child: Text(
                      'Nothing playing',
                      style: TextStyle(
                        color: AppTheme.onBackgroundMuted,
                        fontSize: 16,
                      ),
                    ),
                  )
                  : Column(
                    children: [
                      _buildTopBar(track),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              _buildAlbumArt(track, glowColor, glowSecondaryColor),
                              const SizedBox(height: 36),
                              _buildTrackInfo(track),
                              const SizedBox(height: 28),
                              _buildSeekBar(playerState, glowColor),
                              const SizedBox(height: 20),
                              _buildTransportControls(playerState, glowColor),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  // ── Top bar (back, favorite, queue) ──────────────────────────────────

  Widget _buildTopBar(Track track) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            color: AppTheme.onBackground,
            onPressed: () => context.pop(),
          ),
          Text(
            'NOW PLAYING',
            style: TextStyle(
              color: AppTheme.onBackgroundMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FavoriteButton(trackId: track.id, size: 28),
              IconButton(
                icon: const Icon(Icons.queue_music_rounded, size: 26),
                color: AppTheme.onBackgroundMuted,
                onPressed: () => context.push('/queue'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Album art with radial glow ───────────────────────────────────────

  Widget _buildAlbumArt(Track track, Color primaryColor, Color? secondaryColor) {
    final imageUrl = track.largeCoverUrl ?? track.coverUrl;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return SizedBox(
          width: 320,
          height: 320,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Radial glow behind the art; transitions from primary at the
              // centre to secondary (if available) towards the edge.
              Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [
                      primaryColor.withValues(
                        alpha: 0.25 * _glowAnimation.value,
                      ),
                      (secondaryColor ?? primaryColor).withValues(
                        alpha:
                            (secondaryColor != null ? 0.15 : 0.08) *
                            _glowAnimation.value,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Album art image
              Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child:
                    imageUrl != null
                        ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _buildPlaceholderArt(),
                          errorWidget: (_, __, ___) => _buildPlaceholderArt(),
                        )
                        : _buildPlaceholderArt(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderArt() {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.album_rounded,
        color: AppTheme.onBackgroundSubtle,
        size: 80,
      ),
    );
  }

  // ── Track info (title, artist, album) ────────────────────────────────

  Widget _buildTrackInfo(Track track) {
    return Column(
      children: [
        Text(
          track.title,
          style: const TextStyle(
            color: AppTheme.onBackground,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          track.artistName,
          style: const TextStyle(
            color: AppTheme.onBackgroundMuted,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (track.albumTitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            track.albumTitle,
            style: TextStyle(
              color: AppTheme.onBackgroundSubtle,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  // ── Seek bar / progress slider ───────────────────────────────────────

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
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 3,
            overlayColor: glowColor.withValues(alpha: 0.15),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDuration(playerState.duration),
                style: const TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontSize: 12,
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
        _buildSecondaryControl(
          icon: Icons.shuffle_rounded,
          isActive: playerState.isShuffled,
          onPressed: () => notifier.toggleShuffle(),
        ),
        const SizedBox(width: 20),
        // Previous
        _buildSkipControl(
          icon: Icons.skip_previous_rounded,
          enabled:
              playerState.hasPrevious || playerState.position.inSeconds > 3,
          onPressed: () => notifier.skipPrevious(),
        ),
        const SizedBox(width: 20),
        // Play / Pause
        _buildPlayPauseButton(playerState, glowColor),
        const SizedBox(width: 20),
        // Next
        _buildSkipControl(
          icon: Icons.skip_next_rounded,
          enabled: playerState.hasNext,
          onPressed: () => notifier.skipNext(),
        ),
        const SizedBox(width: 20),
        // Loop / Repeat
        _buildLoopControl(playerState.loopMode),
      ],
    );
  }

  Widget _buildPlayPauseButton(PlayerState playerState, Color glowColor) {
    if (playerState.isLoading) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(shape: BoxShape.circle, color: glowColor),
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).togglePlayPause(),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: glowColor,
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          playerState.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }

  Widget _buildSkipControl({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 36),
      color: enabled ? AppTheme.onBackground : AppTheme.onBackgroundSubtle,
      onPressed: enabled ? onPressed : null,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    );
  }

  Widget _buildSecondaryControl({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 24),
      color: isActive ? AppTheme.secondary : AppTheme.onBackgroundSubtle,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }

  Widget _buildLoopControl(LoopMode loopMode) {
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
      icon: Icon(icon, size: 24),
      color: color,
      onPressed: () => ref.read(playerProvider.notifier).toggleLoopMode(),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}
