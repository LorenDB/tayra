import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:tayra/core/theme/app_theme.dart';

/// Holds the primary and optional secondary accent colors extracted from an
/// album image.
///
/// [secondary] is populated only when a second palette candidate is found
/// that is both harmonious with [primary] and suitable for accent use (see
/// [albumPaletteProvider] for the filtering criteria).
class AlbumPalette {
  final Color primary;
  final Color? secondary;

  const AlbumPalette({required this.primary, this.secondary});
}

/// Extracts up to two accent colors from a network image URL to enable
/// gradient effects.  The [AlbumPalette.secondary] color is only set when a
/// second palette candidate is found that:
///   • is not near-black (lightness ≥ 0.12) or near-white (lightness ≤ 0.90),
///   • has a minimum saturation of 0.20,
///   • has a hue that differs from the primary by 10–75 °.
///
/// Both colors are contrast-adjusted for the AMOLED background before being
/// returned.  Falls back to [AppTheme.primary] when extraction fails.
final albumPaletteProvider = FutureProvider.family<AlbumPalette, String?>((
  ref,
  imageUrl,
) async {
  if (imageUrl == null || imageUrl.isEmpty) {
    return const AlbumPalette(primary: AppTheme.primary);
  }

  try {
    final imageProvider = CachedNetworkImageProvider(imageUrl);
    final palette = await PaletteGenerator.fromImageProvider(
      imageProvider,
      size: const ui.Size(100, 100), // down-sample for speed
      maximumColorCount: 16,
    );

    // Primary: prefer vibrant → dominant → theme primary.
    final rawPrimary =
        palette.vibrantColor?.color ??
        palette.dominantColor?.color ??
        AppTheme.primary;
    final primary = _ensureContrast(rawPrimary);

    // Candidate pool for the secondary color (tried in preference order).
    final candidates = <Color?>[
      palette.lightVibrantColor?.color,
      palette.darkVibrantColor?.color,
      palette.mutedColor?.color,
      palette.lightMutedColor?.color,
      palette.darkMutedColor?.color,
    ];

    Color? secondary;
    for (final candidate in candidates) {
      if (candidate == null) continue;
      if (_isSuitableSecondary(candidate, primary)) {
        secondary = _ensureContrast(candidate);
        break;
      }
    }

    return AlbumPalette(primary: primary, secondary: secondary);
  } catch (_) {
    return const AlbumPalette(primary: AppTheme.primary);
  }
});

/// Extracts a dominant color from a network image URL.
///
/// Returns [AppTheme.primary] as fallback if extraction fails or the URL is
/// null / empty.
final dominantColorProvider = FutureProvider.family<Color, String?>((
  ref,
  imageUrl,
) async {
  final albumPalette = await ref.watch(albumPaletteProvider(imageUrl).future);
  return albumPalette.primary;
});

/// Returns true when [candidate] can serve as a harmonious second gradient
/// color alongside [primary].
///
/// Rejects candidates that are:
///   • near-black (lightness < 0.12) or near-white (lightness > 0.90) — these
///     produce gradients that disappear against the AMOLED background or wash
///     out to white,
///   • low-saturation / grey (saturation < 0.20),
///   • too close in hue to [primary] (< 10 °) — indistinguishable from it,
///   • too far in hue from [primary] (> 75 °) — would look dissimilar.
bool _isSuitableSecondary(Color candidate, Color primary) {
  final hsl = HSLColor.fromColor(candidate);

  // Reject near-black / near-white.
  if (hsl.lightness < 0.12 || hsl.lightness > 0.90) return false;

  // Reject low saturation (muddy/grey).
  if (hsl.saturation < 0.20) return false;

  // Compute circular hue distance (0–180 °).
  final primaryHue = HSLColor.fromColor(primary).hue;
  final diff = (hsl.hue - primaryHue).abs();
  final circularDiff = diff > 180 ? 360 - diff : diff;

  // Require 10–75 ° apart: visually distinct yet harmonious.
  return circularDiff >= 10 && circularDiff <= 75;
}

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
