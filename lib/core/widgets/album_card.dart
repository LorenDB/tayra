import 'package:flutter/material.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/cover_art.dart';
import 'dart:math' as math;

/// A card widget that displays an album's cover art, title, and artist name.
///
/// Parameters:
/// - [album] — the album to display.
/// - [onTap] — called when the card is tapped.
/// - [width] — fixed card width; `null` means layout-driven (fill parent).
/// - [showGradientOverlay] — whether to render the bottom gradient overlay on
///   the cover art (default `true`). Pass `false` for contexts where the
///   overlay would look out of place (e.g. a plain search result list).
/// - [showShadow] — cover drop shadow. Prefer `false` in dense scrolling
///   grids/carousels (shadows are expensive to composite while scrolling).
class AlbumCard extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;
  final double? width;
  final bool showGradientOverlay;
  final bool showShadow;

  const AlbumCard({
    super.key,
    required this.album,
    required this.onTap,
    this.width,
    this.showGradientOverlay = true,
    this.showShadow = true,
  });

  static const double _reservedHeightForText = 8.0 + 2.0 + 20.0 + 18.0;

  @override
  Widget build(BuildContext context) {
    // Fixed-width path (home carousels): skip LayoutBuilder so scrolling
    // horizontal lists don't re-measure every card on each parent layout.
    if (width != null) {
      final artSize = width!;
      return SizedBox(
        width: width,
        child: _AlbumCardBody(
          album: album,
          onTap: onTap,
          artSize: artSize,
          showGradientOverlay: showGradientOverlay,
          showShadow: showShadow,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double availableForArt =
            constraints.maxHeight.isFinite
                ? constraints.maxHeight - _reservedHeightForText
                : maxWidth;
        final double artSize =
            math.max(0.0, math.min(maxWidth, availableForArt)).toDouble();

        return _AlbumCardBody(
          album: album,
          onTap: onTap,
          artSize: artSize,
          showGradientOverlay: showGradientOverlay,
          showShadow: showShadow,
        );
      },
    );
  }
}

class _AlbumCardBody extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;
  final double artSize;
  final bool showGradientOverlay;
  final bool showShadow;

  const _AlbumCardBody({
    required this.album,
    required this.onTap,
    required this.artSize,
    required this.showGradientOverlay,
    required this.showShadow,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CoverArtWidget(
                imageUrl: album.thumbCoverUrl ?? album.coverUrl,
                cacheKey: album.thumbCoverUrl ?? album.coverUrl,
                size: artSize,
                borderRadius: 10,
                shadow:
                    showShadow
                        ? BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                        : null,
              ),
              if (showGradientOverlay)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: artSize * 0.4,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            album.title,
            style: const TextStyle(
              color: AppTheme.onBackground,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            album.artist?.name ?? 'Unknown Artist',
            style: const TextStyle(
              color: AppTheme.onBackgroundMuted,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
