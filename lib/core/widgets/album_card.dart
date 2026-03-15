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
class AlbumCard extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;
  final double? width;
  final bool showGradientOverlay;

  const AlbumCard({
    super.key,
    required this.album,
    required this.onTap,
    this.width,
    this.showGradientOverlay = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = width ?? constraints.maxWidth;
        const double reservedHeightForText = 8.0 + 2.0 + 20.0 + 18.0; // spacers + estimated text heights (title + artist)
        final double availableForArt = constraints.maxHeight.isFinite
            ? constraints.maxHeight - reservedHeightForText
            : maxWidth;
        final double artSize = math.max(0.0, math.min(maxWidth, availableForArt)).toDouble();

        return GestureDetector(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover art + optional gradient overlay
              Stack(
                children: [
                  CoverArtWidget(
                    imageUrl: album.coverUrl,
                    size: artSize,
                    borderRadius: 10,
                    shadow: BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ),
                  if (showGradientOverlay)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
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
      },
    );

    if (width != null) {
      card = SizedBox(width: width, child: card);
    }

    return card;
  }
}
