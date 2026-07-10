import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/theme/app_theme.dart';

/// Reusable cover art widget with rounded corners and placeholder.
///
/// Prefers a local [AudioCacheService] file when available so offline
/// browsing shows art even when [CachedNetworkImage]'s own disk cache
/// never saw the URL. Falls back to [CachedNetworkImage] (which may still
/// serve from its cache offline).
///
/// Decodes images at approximately [size] × device pixel ratio so list/grid
/// scroll does not pay full-resolution decode cost for tiny tiles.
class CoverArtWidget extends ConsumerStatefulWidget {
  final String? imageUrl;
  final double size;
  final double borderRadius;
  final IconData placeholderIcon;
  final BoxShadow? shadow;

  /// Optional cache key to force using an alternative cache entry
  /// (useful when the detail view requests a larger URL but a smaller
  /// version was already cached under a different URL).
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
  File? _localFile;
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
    if (oldWidget.imageUrl != widget.imageUrl) {
      _localFile = null;
      _resolvedForUrl = null;
      _resolveLocalFile();
    }
  }

  Future<void> _resolveLocalFile() async {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      _localFile = null;
      _resolvedForUrl = null;
      return;
    }

    // file:// or absolute path — use directly.
    if (url.startsWith('file://')) {
      final file = File(Uri.parse(url).toFilePath());
      if (await file.exists() && mounted && widget.imageUrl == url) {
        setState(() {
          _localFile = file;
          _resolvedForUrl = url;
        });
      }
      return;
    }
    if (url.startsWith('/')) {
      final file = File(url);
      if (await file.exists() && mounted && widget.imageUrl == url) {
        setState(() {
          _localFile = file;
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
        _localFile = file;
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
    final local = (_resolvedForUrl == url) ? _localFile : null;

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
          local != null
              ? Image.file(
                local,
                fit: BoxFit.cover,
                width: widget.size,
                height: widget.size,
                cacheWidth: decodePx,
                cacheHeight: decodePx,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
                errorBuilder:
                    (context, error, stackTrace) => _Placeholder(
                      size: widget.size,
                      icon: widget.placeholderIcon,
                    ),
              )
              : (url != null && url.isNotEmpty)
              ? Image(
                image: ResizeImage(
                  CachedNetworkImageProvider(url, cacheKey: widget.cacheKey),
                  width: decodePx,
                  height: decodePx,
                  allowUpscaling: false,
                  policy: ResizeImagePolicy.fit,
                ),
                fit: BoxFit.cover,
                width: widget.size,
                height: widget.size,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
                // Show placeholder until the first image frame is available.
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (frame == null && !wasSynchronouslyLoaded) {
                    return _Placeholder(
                      size: widget.size,
                      icon: widget.placeholderIcon,
                    );
                  }
                  return child;
                },
                errorBuilder:
                    (context, error, stackTrace) => _Placeholder(
                      size: widget.size,
                      icon: widget.placeholderIcon,
                    ),
              )
              : _Placeholder(size: widget.size, icon: widget.placeholderIcon),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double size;
  final IconData icon;

  const _Placeholder({required this.size, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: AppTheme.surfaceContainerHigh,
      child: Icon(icon, color: AppTheme.onBackgroundSubtle, size: size * 0.4),
    );
  }
}
