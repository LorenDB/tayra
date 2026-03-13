import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:tayra/core/theme/app_theme.dart';

/// Extracts a dominant color from a network image URL.
///
/// Returns [AppTheme.primary] as fallback if extraction fails or the URL is
/// null / empty.
final dominantColorProvider = FutureProvider.family<Color, String?>((
  ref,
  imageUrl,
) async {
  if (imageUrl == null || imageUrl.isEmpty) return AppTheme.primary;

  try {
    final imageProvider = CachedNetworkImageProvider(imageUrl);
    final palette = await PaletteGenerator.fromImageProvider(
      imageProvider,
      size: const ui.Size(100, 100), // down-sample for speed
      maximumColorCount: 16,
    );

    // Prefer vibrant, then dominant, then fall back to our theme primary.
    final color =
        palette.vibrantColor?.color ??
        palette.dominantColor?.color ??
        AppTheme.primary;

    return _ensureContrast(color);
  } catch (_) {
    return AppTheme.primary;
  }
});

/// Adjusts [color] so it has sufficient contrast against both the AMOLED black
/// background and the white icons rendered on top of it.
///
/// Strategy:
///   1. Enforce a minimum saturation so the color is never muddy.
///   2. Clamp lightness so the color always has a WCAG contrast ratio ≥ 3.0:1
///      against white (icon color) — this caps how bright it can get.
///   3. Raise lightness until the contrast ratio against pure black also
///      reaches 3.0:1, staying within the white-contrast ceiling.
///      If both constraints cannot be satisfied simultaneously (extremely
///      narrow hue), fall back to [AppTheme.primary].
Color _ensureContrast(Color color) {
  const double minContrastRatio = 3.0;
  const double minSaturation = 0.35;
  const double lightnessStep = 0.02;

  var hsl = HSLColor.fromColor(color);

  // 1. Boost saturation if too grey.
  if (hsl.saturation < minSaturation) {
    hsl = hsl.withSaturation(minSaturation);
  }

  // 2. Find the maximum lightness that still gives 3:1 contrast against white.
  //    White has luminance 1.0, so contrast = 1.05 / (l + 0.05) >= 3.0
  //    → l <= (1.05 / 3.0) - 0.05 ≈ 0.30.
  const double maxLightnessForWhiteContrast = 1.05 / minContrastRatio - 0.05;

  if (hsl.lightness > maxLightnessForWhiteContrast) {
    hsl = hsl.withLightness(maxLightnessForWhiteContrast);
  }

  // 3. Raise lightness until contrast against black is acceptable, staying
  //    within the ceiling established above.
  while (_contrastOnBlack(hsl.toColor()) < minContrastRatio &&
      hsl.lightness < maxLightnessForWhiteContrast) {
    hsl = hsl.withLightness(
      (hsl.lightness + lightnessStep).clamp(0.0, maxLightnessForWhiteContrast),
    );
  }

  // If after all adjustments neither constraint is satisfiable (the two
  // contrast windows don't overlap for this hue), use the theme primary.
  if (_contrastOnBlack(hsl.toColor()) < minContrastRatio) {
    return AppTheme.primary;
  }

  return hsl.toColor();
}

/// Returns the WCAG contrast ratio of [color] against pure black.
double _contrastOnBlack(Color color) {
  // Relative luminance of the color (black has luminance 0).
  final l = _relativeLuminance(color);
  // contrast = (lighter + 0.05) / (darker + 0.05); black is always darker.
  return (l + 0.05) / 0.05;
}

/// WCAG 2.1 relative luminance for an sRGB color.
double _relativeLuminance(Color color) {
  double linearize(double v) {
    return v <= 0.03928
        ? v / 12.92
        : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);
  }

  final r = linearize(color.r);
  final g = linearize(color.g);
  final b = linearize(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
