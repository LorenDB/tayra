import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/platform/app_platform.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/local_file_image.dart';

/// Reusable cover art widget with rounded corners and placeholder.
///
/// Prefers a local [AudioCacheService] file when available so offline
/// browsing shows art even when [CachedNetworkImage]'s own disk cache
/// never saw the URL. Falls back to [CachedNetworkImage] (which may still
/// serve from its cache offline).
///
/// Decodes images at approximately [size] × device pixel ratio so list/grid
/// scroll does not pay full-resolution decode cost for tiny tiles.
///
/// Thumbnail-sized files (the 200px and 600px Funkwhale crops) are decoded
/// at their native size. Asking the JPEG codec to scale both axes paints
/// some of those files as a mostly gray bitmap.
class CoverArtWidget extends ConsumerStatefulWidget {
  final String? imageUrl;
  final double size;
  final double borderRadius;
  final IconData placeholderIcon;
  final BoxShadow? shadow;

  /// Disk-cache id for [imageUrl]. Must name the same bytes as [imageUrl].
  /// A different key makes the larger rendition reuse a smaller file forever.
  final String? cacheKey;

  const CoverArtWidget({
    super.key,
    this.imageUrl,
    this.size = 56,
    this.borderRadius = 8,
    this.placeholderIcon = Icons.album,
    this.shadow,
    this.cacheKey,
  });

  @override
  ConsumerState<CoverArtWidget> createState() => _CoverArtWidgetState();
}

class _CoverArtWidgetState extends ConsumerState<CoverArtWidget> {
  /// Local filesystem path when offline cache has the cover (native only).
  String? _localPath;
  String? _resolvedForUrl;
  int _resolveGen = 0;

  @override
  void initState() {
    super.initState();
    _resolveLocalFile();
  }

  @override
  void didUpdateWidget(covariant CoverArtWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheKey != widget.cacheKey) {
      _localPath = null;
      _resolvedForUrl = null;
      _resolveLocalFile();
    }
  }

  Future<void> _resolveLocalFile() async {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      _localPath = null;
      _resolvedForUrl = null;
      return;
    }

    // Web is online-only — always use network images.
    if (!AppPlatform.supportsOfflineCache || kIsWeb) {
      _localPath = null;
      _resolvedForUrl = null;
      return;
    }

    // file:// or absolute path — use directly.
    if (url.startsWith('file://')) {
      final path = Uri.parse(url).toFilePath();
      if (mounted && widget.imageUrl == url) {
        setState(() {
          _localPath = path;
          _resolvedForUrl = url;
        });
      }
      return;
    }
    if (url.startsWith('/')) {
      if (mounted && widget.imageUrl == url) {
        setState(() {
          _localPath = url;
          _resolvedForUrl = url;
        });
      }
      return;
    }

    final gen = ++_resolveGen;
    final file = await ref
        .read(audioCacheServiceProvider)
        .getCachedCoverArt(url);
    if (!mounted || gen != _resolveGen || widget.imageUrl != url) return;
    if (file != null) {
      setState(() {
        _localPath = file.path;
        _resolvedForUrl = url;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Cap decode dimension so very large cards still avoid multi-megapixel
    // bitmaps; 3× is enough for sharp art on high-DPI screens.
    final decodePx = (widget.size * dpr).round().clamp(32, 512);

    final url = widget.imageUrl;
    final localPath = (_resolvedForUrl == url) ? _localPath : null;

    final placeholder = _Placeholder(
      size: widget.size,
      icon: widget.placeholderIcon,
    );

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        color: AppTheme.surfaceContainerHigh,
        boxShadow: widget.shadow != null ? [widget.shadow!] : null,
      ),
      clipBehavior: Clip.antiAlias,
      child:
          localPath != null
              ? buildLocalFileImage(
                path: localPath,
                width: widget.size,
                height: widget.size,
                decodePx: decodePx,
                errorBuilder: (context, error, stackTrace) => placeholder,
              )
              : (url != null && url.isNotEmpty)
              ? Image(
                image: _ReliableCoverImage(
                  CachedNetworkImageProvider(
                    url,
                    // A cache key that does not match the URL aliases a large
                    // rendition onto a previously stored thumbnail.
                    cacheKey:
                        widget.cacheKey == null || widget.cacheKey == url
                            ? widget.cacheKey
                            : null,
                  ),
                  decodePx,
                ),
                fit: BoxFit.cover,
                width: widget.size,
                height: widget.size,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return placeholder;
                },
                errorBuilder: (context, error, stackTrace) => placeholder,
              )
              : placeholder,
    );
  }
}

/// Decode size for a cover.
///
/// Files that already fit in 1024px (medium and large Funkwhale crops) are
/// decoded natively. Scaling those JPEGs, especially on both axes, is what
/// returns a mostly gray bitmap. Larger originals are scaled on one axis
/// only, down to [maxDecodePx].
ui.TargetImageSize coverDecodeTarget({
  required int intrinsicWidth,
  required int intrinsicHeight,
  required int maxDecodePx,
}) {
  if (intrinsicWidth <= 1024 && intrinsicHeight <= 1024) {
    return const ui.TargetImageSize();
  }
  if (intrinsicWidth <= maxDecodePx && intrinsicHeight <= maxDecodePx) {
    return const ui.TargetImageSize();
  }
  if (intrinsicWidth >= intrinsicHeight) {
    final width = maxDecodePx.clamp(1, intrinsicWidth);
    return ui.TargetImageSize(width: width);
  }
  final height = maxDecodePx.clamp(1, intrinsicHeight);
  return ui.TargetImageSize(height: height);
}

class _ReliableCoverKey {
  final CachedNetworkImageProvider inner;
  final int maxDecodePx;

  const _ReliableCoverKey(this.inner, this.maxDecodePx);

  @override
  bool operator ==(Object other) =>
      other is _ReliableCoverKey &&
      other.inner == inner &&
      other.maxDecodePx == maxDecodePx;

  @override
  int get hashCode => Object.hash(inner, maxDecodePx);
}

class _ReliableCoverImage extends ImageProvider<_ReliableCoverKey> {
  final CachedNetworkImageProvider inner;
  final int maxDecodePx;

  const _ReliableCoverImage(this.inner, this.maxDecodePx);

  @override
  Future<_ReliableCoverKey> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(_ReliableCoverKey(inner, maxDecodePx));
  }

  @override
  ImageStreamCompleter loadImage(
    _ReliableCoverKey key,
    ImageDecoderCallback decode,
  ) {
    final completer = key.inner.loadImage(key.inner, (buffer, {getTargetSize}) {
      return decode(
        buffer,
        getTargetSize:
            (width, height) => coverDecodeTarget(
              intrinsicWidth: width,
              intrinsicHeight: height,
              maxDecodePx: key.maxDecodePx,
            ),
      );
    });
    completer.addEphemeralErrorListener((
      Object exception,
      StackTrace? stackTrace,
    ) {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
    });
    return completer;
  }
}

class _Placeholder extends StatelessWidget {
  final double size;
  final IconData icon;

  const _Placeholder({required this.size, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surfaceContainerHigh,
      child: Center(
        child: Icon(icon, color: AppTheme.onBackgroundSubtle, size: size * 0.4),
      ),
    );
  }
}
