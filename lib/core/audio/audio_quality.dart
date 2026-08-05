/// Streaming / download audio quality tiers for the multi-quality ladder.
///
/// Maps to server `?quality=` on listen URLs (and to concrete encode profiles
/// server-side). [AudioQuality.auto] is resolved client-side to a concrete tier.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:tayra/core/platform/app_platform.dart';

// ── Enum ────────────────────────────────────────────────────────────────

/// User-facing playback / download quality preference.
enum AudioQuality {
  /// Platform- and network-aware default.
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
        return 'Adapts to platform and network (lower on cellular)';
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

  /// Cache key segment for on-disk audio files (`audio_{id}_q_{this}`).
  String get cacheKeySegment {
    switch (this) {
      case AudioQuality.auto:
        // Auto must be resolved before caching.
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

  static AudioQuality? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final q in AudioQuality.values) {
      if (q.name == value || q.apiValue == value) return q;
    }
    return null;
  }
}

// ── Cache keys ──────────────────────────────────────────────────────────

/// Namespaced disk/DB key for a track at a concrete quality tier.
///
/// Format: `audio_{trackId}_q_{quality}` (e.g. `audio_42_q_high`).
/// Legacy keys used `audio_{trackId}` only — [legacyAudioCacheKey].
String audioCacheKey(int trackId, AudioQuality quality) {
  final resolved = quality == AudioQuality.auto ? AudioQuality.high : quality;
  return 'audio_${trackId}_q_${resolved.cacheKeySegment}';
}

/// Pre-quality-ladder cache key (still read as a fallback).
String legacyAudioCacheKey(int trackId) => 'audio_$trackId';

/// All quality-namespaced keys for [trackId] (excludes legacy).
List<String> allQualityAudioCacheKeys(int trackId) {
  return [
    for (final q in AudioQuality.values)
      if (q != AudioQuality.auto) audioCacheKey(trackId, q),
  ];
}

// ── Network helpers ─────────────────────────────────────────────────────

/// True when the active connection looks metered (cellular) and no
/// unmetered interface (wifi / ethernet / vpn) is present.
bool isMeteredConnectivity(List<ConnectivityResult> results) {
  final hasUnmetered = results.any(
    (r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn,
  );
  if (hasUnmetered) return false;
  return results.any((r) => r == ConnectivityResult.mobile);
}

// ── Resolution ──────────────────────────────────────────────────────────

/// Resolve [preferred] into a concrete tier the server understands.
///
/// - Web never uses [AudioQuality.original] (browser FLAC support is uneven).
/// - [AudioQuality.auto] on native: original on unmetered, medium on cellular.
/// - [AudioQuality.auto] on web: high on unmetered, medium on cellular.
AudioQuality resolveStreamingQuality(
  AudioQuality preferred, {
  bool? onMeteredNetwork,
}) {
  if (preferred == AudioQuality.auto) {
    final metered = onMeteredNetwork ?? false;
    if (kIsWeb || AppPlatform.isWeb) {
      return metered ? AudioQuality.medium : AudioQuality.high;
    }
    return metered ? AudioQuality.medium : AudioQuality.original;
  }
  if ((kIsWeb || AppPlatform.isWeb) && preferred == AudioQuality.original) {
    return AudioQuality.high;
  }
  return preferred;
}

/// Bucket a millisecond duration for non-PII analytics histograms.
String ttfaMsBucket(int ms) {
  if (ms < 250) return '0_250';
  if (ms < 500) return '250_500';
  if (ms < 1000) return '500_1000';
  if (ms < 2000) return '1000_2000';
  if (ms < 5000) return '2000_5000';
  if (ms < 10000) return '5000_10000';
  return '10000_plus';
}
