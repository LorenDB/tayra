import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:tayra/core/theme/app_theme.dart';

final paletteColorsProvider = FutureProvider.family<Color, String?>((
  ref,
  imageUrl,
) async {
  if (imageUrl == null || imageUrl.isEmpty) return AppTheme.primary;

  try {
    final imageProvider = CachedNetworkImageProvider(imageUrl);
    final palette = await PaletteGenerator.fromImageProvider(
      imageProvider,
      size: const ui.Size(100, 100),
      maximumColorCount: 24,
    );

    final color = _extractBestColor(palette);
    return color;
  } catch (_) {
    return AppTheme.primary;
  }
});

List<PaletteColor> _getCandidateColors(PaletteGenerator palette) {
  return [
    palette.vibrantColor,
    palette.lightVibrantColor,
    palette.darkVibrantColor,
    palette.mutedColor,
    palette.lightMutedColor,
    palette.dominantColor,
  ].whereType<PaletteColor>().toList();
}

Color _extractBestColor(PaletteGenerator palette) {
  final candidates = _getCandidateColors(palette);

  if (candidates.isEmpty) return AppTheme.primary;

  candidates.sort((a, b) => b.population.compareTo(a.population));

  for (final candidate in candidates) {
    final adjusted = _ensureContrast(candidate.color, minimumContrast: 2.5);
    if (adjusted != null) {
      return adjusted;
    }
  }

  return AppTheme.primary;
}

Color? _ensureContrast(Color color, {double minimumContrast = 2.5}) {
  const double minSaturation = 0.25;
  const double lightnessStep = 0.02;
  final double maxLightnessForWhiteContrast = 1.05 / minimumContrast - 0.05;

  var hsl = HSLColor.fromColor(color);

  if (hsl.saturation < minSaturation) {
    hsl = hsl.withSaturation(minSaturation);
  }

  if (hsl.lightness > maxLightnessForWhiteContrast) {
    hsl = hsl.withLightness(maxLightnessForWhiteContrast);
  }

  while (_contrastOnBlack(hsl.toColor()) < minimumContrast &&
      hsl.lightness < maxLightnessForWhiteContrast) {
    hsl = hsl.withLightness(
      (hsl.lightness + lightnessStep).clamp(0.0, maxLightnessForWhiteContrast),
    );
  }

  if (_contrastOnBlack(hsl.toColor()) < minimumContrast) {
    return null;
  }

  return hsl.toColor();
}

double _contrastOnBlack(Color color) {
  final l = _relativeLuminance(color);
  return (l + 0.05) / 0.05;
}

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

@Deprecated('Use paletteColorsProvider instead')
final dominantColorProvider = FutureProvider.family<Color, String?>((
  ref,
  imageUrl,
) async {
  if (imageUrl == null || imageUrl.isEmpty) return AppTheme.primary;

  try {
    final imageProvider = CachedNetworkImageProvider(imageUrl);
    final palette = await PaletteGenerator.fromImageProvider(
      imageProvider,
      size: const ui.Size(100, 100),
      maximumColorCount: 16,
    );

    final color =
        palette.vibrantColor?.color ??
        palette.dominantColor?.color ??
        AppTheme.primary;

    return _ensureContrast(color, minimumContrast: 3.0) ?? AppTheme.primary;
  } catch (_) {
    return AppTheme.primary;
  }
});
