import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tayra/core/theme/app_theme.dart';

/// Playlist cover art: user-set image when present, otherwise a collage of
/// the first up to 4 unique [covers] (album art derived from playlist tracks).
///
/// Layout by unique cover count:
/// - 1: full single image
/// - 2–3: diagonal strips at [_diagonalAngleDeg] (left → right)
/// - 4: 2×2 grid
class PlaylistMosaic extends StatelessWidget {
  final List<String> covers;
  final String? customCoverUrl;
  final double size;
  final double borderRadius;
  final IconData placeholderIcon;

  /// Cut angle from horizontal for 2–3 cover collages (`/` style, steep).
  static const double _diagonalAngleDeg = 70;

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
              : unique.length >= 4
              ? _buildGridMosaic(unique)
              : _buildDiagonalMosaic(unique),
    );
  }

  /// Diagonal strips progressing left → right.
  ///
  /// Boundaries are spaced along the diagonal parameter that spans the whole
  /// square (including corner wedges), so end strips do not look larger than
  /// middle ones. Two arts: 2/3 + 1/3. Three arts: equal thirds.
  ///
  /// Each cover is translated so its center sits on the strip's visible
  /// centerline midpoint, keeping album-art focus in frame.
  Widget _buildDiagonalMosaic(List<String> unique) {
    assert(unique.length == 2 || unique.length == 3);

    final layout = _DiagonalStripLayout(
      size: size,
      angleDegrees: _diagonalAngleDeg,
      // Relative widths along the full diagonal span (corners included).
      weights:
          unique.length == 2
              ? const <double>[2, 1]
              : const <double>[1, 1, 1],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < unique.length; i++)
          ClipPath(
            clipper: _DiagonalStripClipper(
              tStart: layout.boundaries[i],
              tEnd: layout.boundaries[i + 1],
              angleDegrees: _diagonalAngleDeg,
            ),
            child: Transform.translate(
              offset: layout.imageOffset(i),
              child: _coverImage(unique[i], size, size),
            ),
          ),
      ],
    );
  }

  /// 2×2 grid of the first 4 unique covers.
  Widget _buildGridMosaic(List<String> unique) {
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

/// Geometry for `/` diagonal strips covering a square.
///
/// Parameter [t] is the centerline x of a cut: a point (x, y) has
/// `t = x - (size/2 - y) / tan(angle)`. Over the square, [t] ranges
/// `[−δ, size+δ]` where `δ = (size/2) / tan(angle)` — the extra span is
/// exactly the corner wedges. Splitting that full range by [weights]
/// gives balanced strip widths (ends no longer dominate the middle).
class _DiagonalStripLayout {
  final double size;
  final double angleDegrees;
  final List<double> weights;

  /// Cut parameters from left of first strip through right of last.
  late final List<double> boundaries;

  _DiagonalStripLayout({
    required this.size,
    required this.angleDegrees,
    required this.weights,
  }) {
    final tanA = math.tan(angleDegrees * math.pi / 180);
    final delta = (size / 2) / tanA;
    final tMin = -delta;
    final tMax = size + delta;
    final totalWeight = weights.fold<double>(0, (a, b) => a + b);
    final span = tMax - tMin;

    final result = <double>[tMin];
    var acc = 0.0;
    for (final w in weights) {
      acc += w;
      result.add(tMin + span * (acc / totalWeight));
    }
    boundaries = result;
  }

  /// Translation that moves the image center onto this strip's visible
  /// centerline midpoint (clamped to the square).
  Offset imageOffset(int index) {
    final t0 = boundaries[index];
    final t1 = boundaries[index + 1];
    // Visible span along the horizontal centerline (y = size/2 ⇒ t = x).
    final left = t0.clamp(0.0, size);
    final right = t1.clamp(0.0, size);
    final cx = (left + right) / 2;
    return Offset(cx - size / 2, 0);
  }
}

/// Clips a parallelogram strip between two parallel `/` cuts at [tStart]
/// and [tEnd] (see [_DiagonalStripLayout]).
class _DiagonalStripClipper extends CustomClipper<Path> {
  final double tStart;
  final double tEnd;
  final double angleDegrees;

  const _DiagonalStripClipper({
    required this.tStart,
    required this.tEnd,
    required this.angleDegrees,
  });

  @override
  Path getClip(Size size) {
    final tanA = math.tan(angleDegrees * math.pi / 180);
    final halfH = size.height / 2;

    // x on a `/` cut with centerline parameter t at the given angle.
    double xAt(double t, double y) => t + (halfH - y) / tanA;

    return Path()
      ..moveTo(xAt(tStart, 0), 0)
      ..lineTo(xAt(tEnd, 0), 0)
      ..lineTo(xAt(tEnd, size.height), size.height)
      ..lineTo(xAt(tStart, size.height), size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _DiagonalStripClipper oldClipper) {
    return tStart != oldClipper.tStart ||
        tEnd != oldClipper.tEnd ||
        angleDegrees != oldClipper.angleDegrees;
  }
}
