import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/cache/cache_manager.dart';

// ── Browse mode enum ────────────────────────────────────────────────────

enum BrowseMode { albums, artists }

// ── Settings state ──────────────────────────────────────────────────────

class SettingsState {
  final BrowseMode browseMode;
  final int cacheSizeLimitMB;
  final bool showAndroidAutoRecommendations;
  final bool useDynamicAlbumAccent;
  final bool gaplessPlayback;

  const SettingsState({
    this.browseMode = BrowseMode.albums,
    this.cacheSizeLimitMB = 500,
    this.showAndroidAutoRecommendations = true,
    this.useDynamicAlbumAccent = true,
    this.gaplessPlayback = true,
  });

  SettingsState copyWith({
    BrowseMode? browseMode,
    int? cacheSizeLimitMB,
    bool? showAndroidAutoRecommendations,
    bool? useDynamicAlbumAccent,
    bool? gaplessPlayback,
  }) {
    return SettingsState(
      browseMode: browseMode ?? this.browseMode,
      cacheSizeLimitMB: cacheSizeLimitMB ?? this.cacheSizeLimitMB,
      showAndroidAutoRecommendations:
          showAndroidAutoRecommendations ?? this.showAndroidAutoRecommendations,
      useDynamicAlbumAccent:
          useDynamicAlbumAccent ?? this.useDynamicAlbumAccent,
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
    );
  }
}

// ── Settings notifier ───────────────────────────────────────────────────

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<SettingsState> {
  static const _keyBrowseMode = 'browse_mode';
  static const _keyCacheSizeLimit = 'cache_max_size_mb';
  static const _keyShowAndroidAutoRecommendations = 'aa_show_recommendations';
  static const _keyUseDynamicAlbumAccent = 'use_dynamic_album_accent';
  static const _keyGaplessPlayback = 'gapless_playback';

  @override
  SettingsState build() {
    Future.microtask(() => _load());
    return const SettingsState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final modeStr = prefs.getString(_keyBrowseMode);
    BrowseMode browseMode = BrowseMode.albums;
    if (modeStr == 'artists') {
      browseMode = BrowseMode.artists;
    }

    // Normalize stored cache size preference. Older versions may have stored
    // the value in bytes (decimal or binary). Detect and convert to MB.
    final rawCache = prefs.getInt(_keyCacheSizeLimit);
    int cacheSizeMB;
    if (rawCache == null) {
      cacheSizeMB = 500;
    } else if (rawCache > 1000000) {
      // Looks like bytes were stored. Detect binary (base-1024) vs decimal.
      final mbFromBinary = rawCache / (1024 * 1024);
      final roundedBinary = mbFromBinary.roundToDouble();
      if ((mbFromBinary - roundedBinary).abs() < 0.01) {
        cacheSizeMB = roundedBinary.toInt();
      } else {
        cacheSizeMB = (rawCache / 1000000).round();
      }
    } else {
      cacheSizeMB = rawCache;
    }
    final showRecommendations =
        prefs.getBool(_keyShowAndroidAutoRecommendations) ?? true;
    final useDynamicAccent = prefs.getBool(_keyUseDynamicAlbumAccent) ?? true;
    final gapless = prefs.getBool(_keyGaplessPlayback) ?? true;

    state = state.copyWith(
      browseMode: browseMode,
      cacheSizeLimitMB: cacheSizeMB,
      showAndroidAutoRecommendations: showRecommendations,
      useDynamicAlbumAccent: useDynamicAccent,
      gaplessPlayback: gapless,
    );
  }

  Future<void> setBrowseMode(BrowseMode mode) async {
    state = state.copyWith(browseMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBrowseMode, mode.name);
  }

  Future<void> setCacheSizeLimit(int sizeMB) async {
    state = state.copyWith(cacheSizeLimitMB: sizeMB);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCacheSizeLimit, sizeMB);

    // Update cache manager configuration
    await CacheManager.instance.updateConfig(sizeMB);
  }

  Future<void> setShowAndroidAutoRecommendations(bool show) async {
    state = state.copyWith(showAndroidAutoRecommendations: show);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowAndroidAutoRecommendations, show);
  }

  Future<void> setUseDynamicAlbumAccent(bool use) async {
    state = state.copyWith(useDynamicAlbumAccent: use);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseDynamicAlbumAccent, use);
  }

  Future<void> setGaplessPlayback(bool enabled) async {
    state = state.copyWith(gaplessPlayback: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGaplessPlayback, enabled);
  }

  static Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBrowseMode);
    await prefs.remove(_keyCacheSizeLimit);
    await prefs.remove(_keyShowAndroidAutoRecommendations);
    await prefs.remove(_keyUseDynamicAlbumAccent);
    await prefs.remove(_keyGaplessPlayback);
  }
}
