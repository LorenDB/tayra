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

enum NowPlayingLayout { screen, panel }

class NowPlayingContent extends ConsumerStatefulWidget {
  final NowPlayingLayout layout;
  final bool showBackButton;
  final VoidCallback? onQueuePressed;

  const NowPlayingContent({
    super.key,
    required this.layout,
    this.showBackButton = false,
    this.onQueuePressed,
  });

  @override
  ConsumerState<NowPlayingContent> createState() => _NowPlayingContentState();
}

class _NowPlayingContentState extends ConsumerState<NowPlayingContent>
    with SingleTickerProviderStateMixin {
  bool _isSeeking = false;
  double _seekValue = 0.0;

  late final AnimationController? _glowAnimController;
  Animation<double>? _glowAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.layout == NowPlayingLayout.screen) {
      _glowAnimController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4),
      )..repeat(reverse: true);
      _glowAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _glowAnimController!, curve: Curves.easeInOut),
      );
    } else {
      _glowAnimController = null;
      _glowAnimation = null;
    }
  }

  @override
  void dispose() {
    _glowAnimController?.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final track = playerState.currentTrack;

    if (track == null) {
      if (widget.layout == NowPlayingLayout.panel) {
        return const SizedBox.shrink();
      }
      return Center(
        child: Text(
          'Nothing playing',
          style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 16),
        ),
      );
    }

    final imageUrl = track.largeCoverUrl ?? track.coverUrl;
    final dominantColorAsync = ref.watch(dominantColorProvider(imageUrl));
    final glowColor = dominantColorAsync.maybeWhen(
      data: (color) => color,
      orElse: () => AppTheme.primary,
    );

    if (widget.layout == NowPlayingLayout.panel) {
      return _buildPanelLayout(
        track,
        playerState,
        glowColor,
        dominantColorAsync,
      );
    }
    return _buildScreenLayout(
      track,
      playerState,
      glowColor,
      dominantColorAsync,
    );
  }

  Widget _buildScreenLayout(
    Track track,
    PlayerState playerState,
    Color glowColor,
    AsyncValue<Color> dominantColorAsync,
  ) {
    return Column(
      children: [
        _buildScreenTopBar(track),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildScreenAlbumArt(track, glowColor),
                const SizedBox(height: 36),
                _buildTrackInfo(track, 22, 16, 13, 6, 4),
                const SizedBox(height: 28),
                _buildSeekBar(
                  playerState,
                  glowColor,
                  6,
                  16,
                  dominantColorAsync,
                ),
                const SizedBox(height: 20),
                _buildTransportControls(playerState, glowColor, 64, 36, 34, 20),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelLayout(
    Track track,
    PlayerState playerState,
    Color glowColor,
    AsyncValue<Color> dominantColorAsync,
  ) {
    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          _buildPanelHeader(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildPanelAlbumArt(track, glowColor),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildTrackInfo(track, 16, 13, 3, 3, 0),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSeekBar(
                      playerState,
                      glowColor,
                      5,
                      12,
                      dominantColorAsync,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildTransportControls(
                      playerState,
                      glowColor,
                      48,
                      30,
                      28,
                      8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenTopBar(Track track) {
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
          const Text(
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
                onPressed:
                    widget.onQueuePressed ?? () => context.push('/queue'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Padding(
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
            onPressed: widget.onQueuePressed ?? () => context.push('/queue'),
            tooltip: 'Queue',
          ),
        ],
      ),
    );
  }

  Widget _buildScreenAlbumArt(Track track, Color glowColor) {
    final imageUrl = track.largeCoverUrl ?? track.coverUrl;

    return AnimatedBuilder(
      animation: _glowAnimation!,
      builder: (context, child) {
        return SizedBox(
          width: 320,
          height: 320,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [
                      glowColor.withValues(alpha: 0.25 * _glowAnimation!.value),
                      glowColor.withValues(alpha: 0.08 * _glowAnimation!.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.3),
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
                child: _buildAlbumArtImage(imageUrl, 280),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPanelAlbumArt(Track track, Color glowColor) {
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
        child: _buildAlbumArtImage(imageUrl, null),
      ),
    );
  }

  Widget _buildAlbumArtImage(String? imageUrl, double? size) {
    if (imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildPlaceholderArt(size),
        errorWidget: (_, __, ___) => _buildPlaceholderArt(size),
      );
    }
    return _buildPlaceholderArt(size);
  }

  Widget _buildPlaceholderArt(double? size) {
    final width = size ?? double.infinity;
    final height = size ?? double.infinity;
    final iconSize = size != null ? size * 0.285 : 64.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: size != null ? BorderRadius.circular(16) : null,
      ),
      child: Center(
        child: Icon(
          Icons.album_rounded,
          color: AppTheme.onBackgroundSubtle,
          size: iconSize,
        ),
      ),
    );
  }

  Widget _buildTrackInfo(
    Track track,
    double titleSize,
    double artistSize,
    double albumSize,
    double titleSpacing,
    double albumSpacing,
  ) {
    return Column(
      children: [
        Text(
          track.title,
          style: TextStyle(
            color: AppTheme.onBackground,
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            letterSpacing: titleSize > 20 ? -0.3 : -0.2,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: titleSpacing),
        Text(
          track.artistName,
          style: TextStyle(
            color: AppTheme.onBackgroundMuted,
            fontSize: artistSize,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (track.albumTitle.isNotEmpty) ...[
          SizedBox(height: albumSpacing),
          Text(
            track.albumTitle,
            style: TextStyle(
              color: AppTheme.onBackgroundSubtle,
              fontSize: albumSize,
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

  Color _getGradientSecondColor(
    Color baseColor,
    AsyncValue<Color> dominantColorAsync,
  ) {
    // If a custom color was extracted from album art
    final hasCustomColor =
        dominantColorAsync.hasValue &&
        dominantColorAsync.value != AppTheme.primary;

    if (hasCustomColor) {
      final hsl = HSLColor.fromColor(baseColor);
      return hsl
          .withLightness((hsl.lightness + 0.18).clamp(0.0, 1.0))
          .toColor();
    } else {
      // Fallback to primary theme → use primaryLight
      return AppTheme.primaryLight;
    }
  }

  Widget _buildSeekBar(
    PlayerState playerState,
    Color glowColor,
    double thumbRadius,
    double overlayRadius,
    AsyncValue<Color> dominantColorAsync,
  ) {
    final progress = _isSeeking ? _seekValue : playerState.progress;
    final currentPosition =
        _isSeeking
            ? Duration(
              milliseconds:
                  (_seekValue * playerState.duration.inMilliseconds).round(),
            )
            : playerState.position;

    final gradientSecondColor = _getGradientSecondColor(
      glowColor,
      dominantColorAsync,
    );

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Colors.transparent,
            inactiveTrackColor: AppTheme.surfaceContainerHighest,
            thumbColor: Colors.white,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumbRadius),
            trackHeight: 3,
            overlayColor: glowColor.withValues(alpha: 0.15),
            overlayShape: RoundSliderOverlayShape(overlayRadius: overlayRadius),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const trackHeight = 3.0;
              final totalWidth = constraints.maxWidth;
              // Flutter's Slider insets its track by the overlay radius on
              // each side so the thumb glow never clips the widget edges.
              // Mirror that same inset here so the gradient aligns exactly
              // with the Slider thumb position.
              final inset = overlayRadius;
              final trackWidth = totalWidth - inset * 2;
              final filledWidth = trackWidth * progress.clamp(0.0, 1.0);
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Gradient active track – inset to match Slider's track
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: inset),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: trackHeight,
                        width: filledWidth,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [glowColor, gradientSecondColor],
                          ),
                          borderRadius: BorderRadius.circular(trackHeight / 2),
                        ),
                      ),
                    ),
                  ),
                  // Transparent slider for interaction & thumb rendering
                  Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChangeStart: _onSeekStart,
                    onChanged: _onSeekUpdate,
                    onChangeEnd: _onSeekEnd,
                  ),
                ],
              );
            },
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

  Widget _buildTransportControls(
    PlayerState playerState,
    Color glowColor,
    double playButtonSize,
    double skipSize,
    double iconSize,
    double spacing,
  ) {
    final notifier = ref.read(playerProvider.notifier);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSecondaryControl(
          icon: Icons.shuffle_rounded,
          isActive: playerState.isShuffled,
          onPressed: () => notifier.toggleShuffle(),
          iconSize: iconSize - 10,
        ),
        SizedBox(width: spacing),
        _buildSkipControl(
          icon: Icons.skip_previous_rounded,
          enabled:
              playerState.hasPrevious || playerState.position.inSeconds > 3,
          onPressed: () => notifier.skipPrevious(),
          iconSize: skipSize,
        ),
        SizedBox(width: spacing),
        _buildPlayPauseButton(
          playerState,
          glowColor,
          playButtonSize,
          iconSize + 4,
        ),
        SizedBox(width: spacing),
        _buildSkipControl(
          icon: Icons.skip_next_rounded,
          enabled: playerState.hasNext,
          onPressed: () => notifier.skipNext(),
          iconSize: skipSize,
        ),
        SizedBox(width: spacing),
        _buildLoopControl(playerState.loopMode, iconSize: iconSize - 10),
      ],
    );
  }

  Widget _buildPlayPauseButton(
    PlayerState playerState,
    Color glowColor,
    double size,
    double iconSize,
  ) {
    if (playerState.isLoading) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: glowColor),
        child: Center(
          child: SizedBox(
            width: iconSize * 0.44,
            height: iconSize * 0.44,
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
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: glowColor,
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.4),
              blurRadius: size * 0.25,
              spreadRadius: 1,
              offset: Offset(0, size * 0.0625),
            ),
          ],
        ),
        child: Icon(
          playerState.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }

  Widget _buildSkipControl({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
    required double iconSize,
  }) {
    return IconButton(
      icon: Icon(icon, size: iconSize),
      color: enabled ? AppTheme.onBackground : AppTheme.onBackgroundSubtle,
      onPressed: enabled ? onPressed : null,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: iconSize + 12,
        minHeight: iconSize + 12,
      ),
    );
  }

  Widget _buildSecondaryControl({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    required double iconSize,
  }) {
    return IconButton(
      icon: Icon(icon, size: iconSize),
      color: isActive ? AppTheme.secondary : AppTheme.onBackgroundSubtle,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: iconSize + 8,
        minHeight: iconSize + 8,
      ),
    );
  }

  Widget _buildLoopControl(LoopMode loopMode, {required double iconSize}) {
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
      icon: Icon(icon, size: iconSize),
      color: color,
      onPressed: () => ref.read(playerProvider.notifier).toggleLoopMode(),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: iconSize + 8,
        minHeight: iconSize + 8,
      ),
    );
  }
}
