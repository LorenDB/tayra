import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/cache/cache_manager.dart';

// ── Browse mode enum ────────────────────────────────────────────────────

enum BrowseMode { albums, artists }

// ── Settings state ──────────────────────────────────────────────────────

class SettingsState {
  final BrowseMode browseMode;
  final int cacheSizeLimitMB;
  final bool androidAutoEnabled;
  final bool useDynamicAlbumAccent;
  final bool gaplessPlayback;
  final bool aiEnabled;
  final bool aiDownloadPromptShown;
  final bool forceOfflineMode;

  const SettingsState({
    this.browseMode = BrowseMode.albums,
    this.cacheSizeLimitMB = 500,
    this.androidAutoEnabled = true,
    this.useDynamicAlbumAccent = true,
    this.gaplessPlayback = true,
    this.aiEnabled = true,
    this.aiDownloadPromptShown = false,
    this.forceOfflineMode = false,
  });

  SettingsState copyWith({
    BrowseMode? browseMode,
    int? cacheSizeLimitMB,
    bool? androidAutoEnabled,
    bool? useDynamicAlbumAccent,
    bool? gaplessPlayback,
    bool? aiEnabled,
    bool? aiDownloadPromptShown,
    bool? forceOfflineMode,
  }) {
    return SettingsState(
      browseMode: browseMode ?? this.browseMode,
      cacheSizeLimitMB: cacheSizeLimitMB ?? this.cacheSizeLimitMB,
      androidAutoEnabled: androidAutoEnabled ?? this.androidAutoEnabled,
      useDynamicAlbumAccent:
          useDynamicAlbumAccent ?? this.useDynamicAlbumAccent,
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      aiDownloadPromptShown:
          aiDownloadPromptShown ?? this.aiDownloadPromptShown,
      forceOfflineMode: forceOfflineMode ?? this.forceOfflineMode,
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
  static const _keyAndroidAutoEnabled = 'aa_android_auto_enabled';
  static const _keyUseDynamicAlbumAccent = 'use_dynamic_album_accent';
  static const _keyGaplessPlayback = 'gapless_playback';
  static const _keyAiEnabled = 'ai_enabled';
  static const _keyAiDownloadPromptShown = 'ai_download_prompt_shown';
  static const _keyForceOfflineMode = 'force_offline_mode';

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
    final showRecommendations = prefs.getBool(_keyAndroidAutoEnabled) ?? true;
    final useDynamicAccent = prefs.getBool(_keyUseDynamicAlbumAccent) ?? true;
    final gapless = prefs.getBool(_keyGaplessPlayback) ?? true;
    final aiEnabled = prefs.getBool(_keyAiEnabled) ?? true;
    final aiDownloadPromptShown =
        prefs.getBool(_keyAiDownloadPromptShown) ?? false;
    final forceOfflineMode = prefs.getBool(_keyForceOfflineMode) ?? false;

    state = state.copyWith(
      browseMode: browseMode,
      cacheSizeLimitMB: cacheSizeMB,
      androidAutoEnabled: showRecommendations,
      useDynamicAlbumAccent: useDynamicAccent,
      gaplessPlayback: gapless,
      aiEnabled: aiEnabled,
      aiDownloadPromptShown: aiDownloadPromptShown,
      forceOfflineMode: forceOfflineMode,
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

  Future<void> setAndroidAutoEnabled(bool enabled) async {
    state = state.copyWith(androidAutoEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAndroidAutoEnabled, enabled);
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

  Future<void> setAiEnabled(bool enabled) async {
    state = state.copyWith(aiEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAiEnabled, enabled);
  }

  Future<void> setAiDownloadPromptShown(bool shown) async {
    state = state.copyWith(aiDownloadPromptShown: shown);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAiDownloadPromptShown, shown);
  }

  Future<void> setForceOfflineMode(bool enabled) async {
    state = state.copyWith(forceOfflineMode: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyForceOfflineMode, enabled);
  }

  static Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBrowseMode);
    await prefs.remove(_keyCacheSizeLimit);
    await prefs.remove(_keyAndroidAutoEnabled);
    await prefs.remove(_keyUseDynamicAlbumAccent);
    await prefs.remove(_keyGaplessPlayback);
    await prefs.remove(_keyAiEnabled);
    await prefs.remove(_keyAiDownloadPromptShown);
    await prefs.remove(_keyForceOfflineMode);
  }
}
