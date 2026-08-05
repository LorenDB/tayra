/// Streaming / download audio quality tiers for the multi-quality ladder.
///
/// Maps to server `?quality=` on listen URLs (and to concrete encode profiles
/// server-side). [AudioQuality.auto] is resolved client-side to a concrete tier.
library;

import 'package:flutter/foundation.dart';
import 'package:tayra/core/platform/app_platform.dart';

// ── Enum ────────────────────────────────────────────────────────────────

/// User-facing playback / download quality preference.
enum AudioQuality {
  /// Platform-aware default (web forces lossy; native prefers original).
  auto,

  /// Source file as uploaded (may be FLAC / high bitrate).
  original,

  /// Near-transparent lossy (~256–320 kbps).
  high,

  /// Balanced streaming (~128–160 kbps).
  medium,

  /// Data saver / emergency (~64–96 kbps).
  low,
}

// ── Extensions ──────────────────────────────────────────────────────────

extension AudioQualityX on AudioQuality {
  /// Wire value for `?quality=` (never `auto` — resolve first).
  String get apiValue {
    switch (this) {
      case AudioQuality.auto:
        return 'auto';
      case AudioQuality.original:
        return 'original';
      case AudioQuality.high:
        return 'high';
      case AudioQuality.medium:
        return 'medium';
      case AudioQuality.low:
        return 'low';
    }
  }

  String get label {
    switch (this) {
      case AudioQuality.auto:
        return 'Auto';
      case AudioQuality.original:
        return 'Original';
      case AudioQuality.high:
        return 'High';
      case AudioQuality.medium:
        return 'Medium';
      case AudioQuality.low:
        return 'Data saver';
    }
  }

  String get subtitle {
    switch (this) {
      case AudioQuality.auto:
        return 'Adapts to platform and network conditions';
      case AudioQuality.original:
        return 'Best quality (may use more data)';
      case AudioQuality.high:
        return 'Near-transparent lossy';
      case AudioQuality.medium:
        return 'Balanced quality and bandwidth';
      case AudioQuality.low:
        return 'Lowest bandwidth for slow networks';
    }
  }

  /// Next lower tier for stall fallback, or null if already lowest.
  AudioQuality? get lowerTier {
    switch (this) {
      case AudioQuality.auto:
        return null;
      case AudioQuality.original:
        return AudioQuality.high;
      case AudioQuality.high:
        return AudioQuality.medium;
      case AudioQuality.medium:
        return AudioQuality.low;
      case AudioQuality.low:
        return null;
    }
  }

  static AudioQuality? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final q in AudioQuality.values) {
      if (q.name == value || q.apiValue == value) return q;
    }
    return null;
  }
}

// ── Resolution ──────────────────────────────────────────────────────────

/// Resolve [preferred] into a concrete tier the server understands.
///
/// - Web never uses [AudioQuality.original] (browser FLAC support is uneven).
/// - [AudioQuality.auto] → original on native/desktop, high on web.
AudioQuality resolveStreamingQuality(AudioQuality preferred) {
  if (preferred == AudioQuality.auto) {
    if (kIsWeb || AppPlatform.isWeb) {
      return AudioQuality.high;
    }
    return AudioQuality.original;
  }
  if ((kIsWeb || AppPlatform.isWeb) && preferred == AudioQuality.original) {
    return AudioQuality.high;
  }
  return preferred;
}
