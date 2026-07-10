import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tayra/core/theme/app_theme.dart';

/// Reusable cover art widget with rounded corners and placeholder.
///
/// Decodes images at approximately [size] × device pixel ratio so list/grid
/// scroll does not pay full-resolution decode cost for tiny tiles.
class CoverArtWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Cap decode dimension so very large cards still avoid multi-megapixel
    // bitmaps; 3× is enough for sharp art on high-DPI screens.
    final decodePx = (size * dpr).round().clamp(32, 512);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: AppTheme.surfaceContainerHigh,
        boxShadow: shadow != null ? [shadow!] : null,
      ),
      clipBehavior: Clip.antiAlias,
      child:
          imageUrl != null && imageUrl!.isNotEmpty
              ? Image(
                image: ResizeImage(
                  CachedNetworkImageProvider(imageUrl!, cacheKey: cacheKey),
                  width: decodePx,
                  height: decodePx,
                  allowUpscaling: false,
                  policy: ResizeImagePolicy.fit,
                ),
                fit: BoxFit.cover,
                width: size,
                height: size,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
                // Show placeholder until the first image frame is available.
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (frame == null && !wasSynchronouslyLoaded) {
                    return _Placeholder(size: size, icon: placeholderIcon);
                  }
                  return child;
                },
                errorBuilder:
                    (context, error, stackTrace) =>
                        _Placeholder(size: size, icon: placeholderIcon),
              )
              : _Placeholder(size: size, icon: placeholderIcon),
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
