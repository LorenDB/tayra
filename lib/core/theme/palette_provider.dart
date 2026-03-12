import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:funkwhale/core/theme/app_theme.dart';

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

    // Ensure the color isn't too dark (would be invisible on AMOLED black)
    // or too desaturated. If it is, boost saturation and lightness slightly.
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness < 0.25 || hsl.saturation < 0.2) {
      return hsl
          .withSaturation((hsl.saturation + 0.3).clamp(0.0, 1.0))
          .withLightness((hsl.lightness + 0.15).clamp(0.0, 0.6))
          .toColor();
    }

    return color;
  } catch (_) {
    return AppTheme.primary;
  }
});
