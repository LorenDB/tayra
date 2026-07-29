import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tayra/core/theme/app_theme.dart';

/// Playlist cover art: user-set image when present, otherwise a collage of
/// the first up to 4 unique [covers] (album art derived from playlist tracks).
class PlaylistMosaic extends StatelessWidget {
  final List<String> covers;
  final String? customCoverUrl;
  final double size;
  final double borderRadius;
  final IconData placeholderIcon;

  const PlaylistMosaic({
    super.key,
    required this.covers,
    this.customCoverUrl,
    required this.size,
    this.borderRadius = 8,
    this.placeholderIcon = Icons.queue_music_rounded,
  });

  /// First up to 4 non-empty unique cover URLs, preserving order.
  static List<String> uniqueCovers(List<String> covers, {int max = 4}) {
    final result = <String>[];
    final seen = <String>{};
    for (final url in covers) {
      if (url.isEmpty || !seen.add(url)) continue;
      result.add(url);
      if (result.length >= max) break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final unique = uniqueCovers(covers);
    final hasCustom = customCoverUrl != null && customCoverUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          hasCustom
              ? _coverImage(customCoverUrl!, size, size)
              : unique.isEmpty
              ? Center(
                child: Icon(
                  placeholderIcon,
                  color: AppTheme.onBackgroundSubtle,
                  size: size * 0.4,
                ),
              )
              : unique.length == 1
              ? _coverImage(unique[0], size, size)
              : _buildMosaic(unique),
    );
  }

  /// 2×2 grid of the first unique covers (2–4). Empty cells stay solid.
  Widget _buildMosaic(List<String> unique) {
    final halfSize = size / 2;
    String? at(int i) => i < unique.length ? unique[i] : null;

    Widget cell(String? url) {
      if (url == null) {
        return SizedBox(
          width: halfSize,
          height: halfSize,
          child: const ColoredBox(color: AppTheme.surfaceContainerHigh),
        );
      }
      return _coverImage(url, halfSize, halfSize);
    }

    return Column(
      children: [
        Row(children: [cell(at(0)), cell(at(1))]),
        Row(children: [cell(at(2)), cell(at(3))]),
      ],
    );
  }

  Widget _coverImage(String url, double w, double h) {
    return CachedNetworkImage(
      imageUrl: url,
      width: w,
      height: h,
      fit: BoxFit.cover,
      placeholder:
          (context, url) => Container(
            width: w,
            height: h,
            color: AppTheme.surfaceContainerHigh,
          ),
      errorWidget:
          (context, url, error) => Container(
            width: w,
            height: h,
            color: AppTheme.surfaceContainerHigh,
            child: Icon(
              Icons.album_rounded,
              color: AppTheme.onBackgroundSubtle,
              size: w * 0.4,
            ),
          ),
    );
  }
}
