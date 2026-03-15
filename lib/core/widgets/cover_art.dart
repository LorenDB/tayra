import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tayra/core/theme/app_theme.dart';

/// Reusable cover art widget with rounded corners and placeholder.
class CoverArtWidget extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double borderRadius;
  final IconData placeholderIcon;
  final BoxShadow? shadow;

  const CoverArtWidget({
    super.key,
    this.imageUrl,
    this.size = 56,
    this.borderRadius = 8,
    this.placeholderIcon = Icons.album,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
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
              ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                placeholder:
                    (context, url) =>
                        _Placeholder(size: size, icon: placeholderIcon),
                errorWidget:
                    (context, url, error) =>
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
