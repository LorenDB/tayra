import 'dart:async';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'dart:ui' as ui;
import 'package:flutter/scheduler.dart';
import 'package:tayra/core/api/api_utils.dart';
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
    with TickerProviderStateMixin {
  bool _isSeeking = false;
  double _seekValue = 0.0;

  late final AnimationController? _glowAnimController;
  Animation<double>? _glowAnimation;

  // Shader easter egg state
  ui.FragmentShader? _gridShader;
  ui.Image? _gridImage;
  Ticker? _shaderTicker;
  double _shaderElapsed = 0.0;
  bool _showGridEasterEgg = false;
  String? _shaderImageUrl; // last URL bound into the shader

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
    _shaderTicker?.dispose();
    _gridShader?.dispose();
    _gridImage?.dispose();
    super.dispose();
  }

  Future<void> _loadGridShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'assets/shaders/disco.frag',
      );
      if (mounted) {
        setState(() => _gridShader = program.fragmentShader());
      }
    } catch (_) {
      // Shader failed to load — ignore fallback
    }
  }

  Future<void> _bindImageToShader(ImageProvider imageProvider) async {
    try {
      final config = ImageConfiguration(
        bundle: DefaultAssetBundle.of(context),
        devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
      );
      final completer = Completer<ui.Image>();
      final stream = imageProvider.resolve(config);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          completer.complete(info.image.clone());
          stream.removeListener(listener);
        },
        onError: (e, _) {
          if (!completer.isCompleted) completer.completeError(e);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      final img = await completer.future;
      if (mounted) {
        _gridImage?.dispose();
        _gridImage = img;
        _gridShader?.setImageSampler(0, img);
        setState(() {});
      }
    } catch (_) {
      // ignore — shader keeps showing the previous image
    }
  }

  Future<void> _toggleGridEasterEgg({ImageProvider? imageProvider}) async {
    if (!_showGridEasterEgg) {
      try {
        Analytics.track('disco_easter_egg_triggered');
      } catch (_) {}
      if (_gridShader == null) await _loadGridShader();

      if (imageProvider != null) {
        await _bindImageToShader(imageProvider);
      }

      _shaderTicker ??= createTicker((elapsed) {
        setState(() => _shaderElapsed = elapsed.inMicroseconds / 1e6);
      });
      _shaderTicker!.start();
      setState(() => _showGridEasterEgg = true);
    } else {
      _shaderTicker?.stop();
      setState(() => _showGridEasterEgg = false);
    }

    // Provide immediate haptic feedback so the user feels the easter egg
    // activation. Use a light impact which is subtle but noticeable on
    // supported devices.
    try {
      HapticFeedback.lightImpact();
    } catch (_) {
      // Ignore haptic failures on platforms that don't support it.
    }
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

    // Use the unconditional provider for the glow so it remains tinted even
    // when the user disables dynamic accents. Other UI elements will use the
    // regular provider which respects the accessibility setting.
    final glowPaletteAsync = ref.watch(
      paletteColorsProviderUnconditional(
        encodePaletteKey(imageUrl, track.album?.coverUrl),
      ),
    );
    final paletteAsync = ref.watch(
      paletteColorsProvider(encodePaletteKey(imageUrl, track.album?.coverUrl)),
    );
    final accentColor = paletteAsync.maybeWhen(
      data: (color) => color,
      orElse: () => AppTheme.primary,
    );
    final glowColor = glowPaletteAsync.maybeWhen(
      data: (color) => color,
      orElse: () => AppTheme.primary,
    );

    final content =
        widget.layout == NowPlayingLayout.panel
            ? _buildPanelLayout(
              track,
              playerState,
              glowColor,
              paletteAsync,
              accentColor,
            )
            : _buildScreenLayout(
              track,
              playerState,
              glowColor,
              paletteAsync,
              accentColor,
            );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() < 300) return;
        if (v > 0) {
          HapticFeedback.lightImpact();
          try {
            Analytics.track('swipe_to_skip', {
              'direction': 'previous',
              'source': 'now_playing',
            });
          } catch (_) {}
          ref.read(playerProvider.notifier).skipPrevious();
        } else {
          HapticFeedback.lightImpact();
          try {
            Analytics.track('swipe_to_skip', {
              'direction': 'next',
              'source': 'now_playing',
            });
          } catch (_) {}
          ref.read(playerProvider.notifier).skipNext();
        }
      },
      child: content,
    );
  }

  Widget _buildScreenLayout(
    Track track,
    PlayerState playerState,
    Color glowColor,
    AsyncValue<Color> paletteAsync,
    Color accentColor,
  ) {
    return Column(
      children: [
        _buildScreenTopBar(track),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Compute the album art size from the true available space.
              // Reserve space for the surrounding fixed-height content:
              // top spacer(16) + gap(36) + track info(~80) + gap(28) +
              // seek bar(~54) + gap(20) + controls(~64) + bottom spacer(32) ≈ 330px
              const otherHeight = 330.0;
              final artFromH = (constraints.maxHeight - otherHeight).clamp(
                120.0,
                320.0,
              );
              // 32px horizontal padding on each side
              final artFromW = (constraints.maxWidth - 64).clamp(120.0, 320.0);
              final artSize = artFromH < artFromW ? artFromH : artFromW;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildScreenAlbumArt(track, glowColor, artSize),
                    const SizedBox(height: 36),
                    _buildTrackInfo(track, 22, 16, 13, 9, 4),
                    const SizedBox(height: 28),
                    _buildSeekBar(
                      playerState,
                      accentColor,
                      6,
                      16,
                      paletteAsync,
                    ),
                    const SizedBox(height: 20),
                    _buildTransportControls(
                      playerState,
                      accentColor,
                      64,
                      36,
                      34,
                      20,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPanelLayout(
    Track track,
    PlayerState playerState,
    Color glowColor,
    AsyncValue<Color> paletteAsync,
    Color accentColor,
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
                    child: _buildTrackInfo(track, 16, 13, 13, 3, 0),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSeekBar(
                      playerState,
                      accentColor,
                      5,
                      12,
                      paletteAsync,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildTransportControls(
                      playerState,
                      accentColor,
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

  Widget _buildScreenAlbumArt(Track track, Color glowColor, double outerSize) {
    final imageUrl = track.largeCoverUrl ?? track.coverUrl;
    final artSize = outerSize * (280.0 / 320.0);

    return AnimatedBuilder(
      animation: _glowAnimation!,
      builder: (context, child) {
        return SizedBox(
          width: outerSize,
          height: outerSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: outerSize,
                height: outerSize,
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
                width: artSize,
                height: artSize,
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
                child: _buildAlbumArtImage(imageUrl, artSize),
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
    final Widget imageWidget =
        imageUrl != null
            ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildPlaceholderArt(size),
              errorWidget: (context, url, error) => _buildPlaceholderArt(size),
              imageBuilder: (context, imageProvider) {
                // Image is fully decoded and ready. If the shader is active
                // and the URL changed, bind the raw ImageProvider directly —
                // no boundary snapshot needed, no flicker.
                if (_showGridEasterEgg && imageUrl != _shaderImageUrl) {
                  _shaderImageUrl = imageUrl;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _bindImageToShader(imageProvider);
                  });
                }
                return Image(image: imageProvider, fit: BoxFit.cover);
              },
            )
            : _buildPlaceholderArt(size);

    return GestureDetector(
      onLongPress: () {
        // Find the current ImageProvider from the cache to pass into the shader.
        final provider =
            imageUrl != null ? CachedNetworkImageProvider(imageUrl) : null;
        _toggleGridEasterEgg(imageProvider: provider);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageWidget,
          if (_showGridEasterEgg && _gridShader != null)
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(
                  shader: _gridShader!,
                  time: _shaderElapsed,
                  image: _gridImage,
                ),
              ),
            ),
        ],
      ),
    );
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

  Widget _buildSeekBar(
    PlayerState playerState,
    Color accentColor,
    double thumbRadius,
    double overlayRadius,
    AsyncValue<Color> paletteAsync,
  ) {
    final progress = _isSeeking ? _seekValue : playerState.progress;
    final currentPosition =
        _isSeeking
            ? Duration(
              milliseconds:
                  (_seekValue * playerState.duration.inMilliseconds).round(),
            )
            : playerState.position;

    final gradientSecondColor = AppTheme.gradientSecondColor(
      accentColor,
      paletteAsync,
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
            overlayColor: accentColor.withValues(alpha: 0.15),
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
                            colors: [accentColor, gradientSecondColor],
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
                formatTrackDuration(currentPosition.inSeconds),
                style: const TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                formatTrackDuration(playerState.duration.inSeconds),
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
    Color accentColor,
    double playButtonSize,
    double skipSize,
    double iconSize,
    double spacing,
  ) {
    final notifier = ref.read(playerProvider.notifier);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSecondaryControl(
            icon: Icons.shuffle_rounded,
            isActive: playerState.isShuffled,
            onPressed: () => notifier.toggleShuffle(),
            iconSize: iconSize - 10,
            accentColor: accentColor,
            // Use the app's secondary (green/teal) color for the shuffle
            // button when active instead of the dynamic accent color.
            activeColor: AppTheme.secondary,
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
            accentColor,
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
          _buildLoopControl(
            playerState.loopMode,
            accentColor,
            iconSize: iconSize - 10,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPauseButton(
    PlayerState playerState,
    Color accentColor,
    double size,
    double iconSize,
  ) {
    if (playerState.isLoading) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor),
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
          color: accentColor,
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.4),
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
    required Color accentColor,
    Color? activeColor,
  }) {
    final effectiveActiveColor = activeColor ?? accentColor;
    return IconButton(
      icon: Icon(icon, size: iconSize),
      color: isActive ? effectiveActiveColor : AppTheme.onBackgroundSubtle,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: iconSize + 8,
        minHeight: iconSize + 8,
      ),
    );
  }

  Widget _buildLoopControl(
    LoopMode loopMode,
    Color accentColor, {
    required double iconSize,
  }) {
    final IconData icon;
    final Color color;

    switch (loopMode) {
      case LoopMode.off:
        icon = Icons.repeat_rounded;
        color = AppTheme.onBackgroundSubtle;
        break;
      case LoopMode.all:
        icon = Icons.repeat_rounded;
        // Use the app primary color for the repeat button instead of the
        // dynamic album-art accent color.
        color = AppTheme.primary;
        break;
      case LoopMode.one:
        icon = Icons.repeat_one_rounded;
        // Use the app primary color for the repeat-one button as well.
        color = AppTheme.primary;
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

class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.shader,
    required this.time,
    required this.image,
  });

  final ui.FragmentShader shader;
  final double time;
  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    if (image != null) {
      shader.setImageSampler(0, image!);
    }
    shader
      ..setFloat(0, time)
      ..setFloat(1, size.width)
      ..setFloat(2, size.height);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.time != time || old.shader != shader || old.image != image;
}
