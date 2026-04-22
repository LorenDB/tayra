// 'dart:ui' import not needed; palette generation uses Flutter image providers.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/settings/settings_provider.dart';

/// Encode/decode helper for the provider family key.
/// Format: "<imageUrl>|||<cacheKey>". Both parts may be empty.
String encodePaletteKey(String? imageUrl, String? cacheKey) {
  final u = imageUrl ?? '';
  final k = cacheKey ?? '';
  return '$u|||$k';
}

String? _decImageUrl(String? encoded) {
  if (encoded == null || encoded.isEmpty) return null;
  final parts = encoded.split('|||');
  return parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : null;
}

String? _decCacheKey(String? encoded) {
  if (encoded == null || encoded.isEmpty) return null;
  final parts = encoded.split('|||');
  return parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
}

final paletteColorsProvider = FutureProvider.family<Color, String?>((
  ref,
  encodedKey,
) async {
  final imageUrl = _decImageUrl(encodedKey);
  final cacheKey = _decCacheKey(encodedKey);
  // If the user has disabled dynamic album accents for accessibility, return
  // the app primary color immediately to avoid palette generation work.
  final settings = ref.watch(settingsProvider);
  if (settings.useDynamicAlbumAccent == false) return AppTheme.primary;
  if (imageUrl == null || imageUrl.isEmpty) return AppTheme.primary;

  try {
    // Wrap with ResizeImage so palette generation decodes a separate 100×100
    // ui.Image instead of sharing the GPU texture that CoverArtWidget renders.
    // Without this, PaletteGenerator.fromImageProvider resolves the same
    // cached GPU texture that is concurrently being composited, causing Skia's
    // "GrBackendTextureImageGenerator: Trying to use texture on two GrContexts!"
    // assertion on some devices.
    final imageProvider = ResizeImage(
      CachedNetworkImageProvider(imageUrl, cacheKey: cacheKey),
      width: 100,
      height: 100,
      allowUpscaling: false,
    );
    final palette = await PaletteGenerator.fromImageProvider(
      imageProvider,
      maximumColorCount: 24,
    );

    final color = _extractBestColor(palette);
    return color;
  } catch (_) {
    return AppTheme.primary;
  }
});

/// Like [paletteColorsProvider] but always generates a palette regardless of
/// the user's accessibility setting. Used for visual elements that should
/// remain tinted (e.g. the now playing art glow) even when accents are
/// disabled.
final paletteColorsProviderUnconditional =
    FutureProvider.family<Color, String?>((ref, encodedKey) async {
      final imageUrl = _decImageUrl(encodedKey);
      final cacheKey = _decCacheKey(encodedKey);
      if (imageUrl == null || imageUrl.isEmpty) return AppTheme.primary;

      try {
        final imageProvider = ResizeImage(
          CachedNetworkImageProvider(imageUrl, cacheKey: cacheKey),
          width: 100,
          height: 100,
          allowUpscaling: false,
        );
        final palette = await PaletteGenerator.fromImageProvider(
          imageProvider,
          maximumColorCount: 24,
        );

        final color = _extractBestColor(palette);
        return color;
      } catch (_) {
        return AppTheme.primary;
      }
    });

List<PaletteColor> _getCandidateColors(PaletteGenerator palette) {
  // lightVibrantColor and lightMutedColor are excluded: on dark UIs they tend
  // to be washed-out and are rarely better than the vibrant/muted variants.
  return [
    palette.vibrantColor,
    palette.darkVibrantColor,
    palette.mutedColor,
    palette.dominantColor,
  ].whereType<PaletteColor>().toList();
}

/// Returns a perceptual chroma proxy for [color] in the range [0, 1].
///
/// This is not true CAM16/HCT chroma — it's an HSL approximation that weights
/// saturation down near the lightness extremes (near-black and near-white),
/// where high saturation produces colors that look muddy or pastel rather than
/// vivid. The result correlates well with perceived colorfulness for the purpose
/// of accent color selection.
double _chromaProxy(Color color) {
  final hsl = HSLColor.fromColor(color);
  // A lightness of 0.5 is maximally vivid; 0.0 and 1.0 are black/white.
  // (1 - |lightness - 0.5| * 2) maps 0.5 → 1.0 and 0.0/1.0 → 0.0.
  final lightnessFactor = (1 - (hsl.lightness - 0.5).abs() * 2).clamp(0.0, 1.0);
  return hsl.saturation * lightnessFactor;
}

Color _extractBestColor(PaletteGenerator palette) {
  final candidates = _getCandidateColors(palette);

  if (candidates.isEmpty) return AppTheme.primary;

  // Sort by perceptual chroma (vividness) rather than pixel population.
  // Population-first ordering causes muted backgrounds to be preferred over
  // vivid accent colors, which is the opposite of what we want.
  candidates.sort((a, b) => _chromaProxy(b.color).compareTo(_chromaProxy(a.color)));

  for (final candidate in candidates) {
    final hsl = HSLColor.fromColor(candidate.color);
    // Hard-reject low-saturation colors. Attempting to rescue a desaturated
    // color by bumping its saturation produces artificial muddy tones (e.g.
    // the grayish-red fallback this logic was introduced to fix).
    if (hsl.saturation < 0.3) continue;

    final adjusted = _ensureContrast(candidate.color, minimumContrast: 2.5);
    if (adjusted != null) return adjusted;
  }

  // No candidate survived the saturation gate and contrast check — fall back
  // to the app primary rather than returning a mangled rescue color.
  return AppTheme.primary;
}

Color? _ensureContrast(Color color, {double minimumContrast = 2.5}) {
  const double lightnessStep = 0.02;
  final double maxLightnessForWhiteContrast = 1.05 / minimumContrast - 0.05;

  var hsl = HSLColor.fromColor(color);

  // Do NOT force a minimum saturation here. Artificially boosting the
  // saturation of a low-chroma color changes its perceived identity and
  // produces the muddy rescue colors we are trying to avoid. Low-saturation
  // candidates are now rejected upstream in _extractBestColor instead.

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

/// Ensures [color] meets WCAG AA contrast (4.5:1) against a black background,
/// which is required for body text and small icons.
///
/// If the color is already bright enough it is returned unchanged. Otherwise
/// the HSL lightness is increased in small steps until the threshold is met,
/// preserving the original hue and saturation so the color family stays the
/// same. Passing [minimumContrast] lets callers override the target ratio
/// (e.g. 3.0 for large/bold text, 4.5 for normal text, 7.0 for AAA).
Color lightenForText(Color color, {double minimumContrast = 4.5}) {
  const double lightnessStep = 0.02;
  var hsl = HSLColor.fromColor(color);

  while (_contrastOnBlack(hsl.toColor()) < minimumContrast &&
      hsl.lightness < 1.0) {
    hsl = hsl.withLightness((hsl.lightness + lightnessStep).clamp(0.0, 1.0));
  }

  return hsl.toColor();
}

@Deprecated('Use paletteColorsProvider instead')
final dominantColorProvider = FutureProvider.family<Color, String?>((
  ref,
  imageUrl,
) async {
  if (imageUrl == null || imageUrl.isEmpty) return AppTheme.primary;

  try {
    final imageProvider = ResizeImage(
      CachedNetworkImageProvider(imageUrl),
      width: 100,
      height: 100,
      allowUpscaling: false,
    );
    final palette = await PaletteGenerator.fromImageProvider(
      imageProvider,
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