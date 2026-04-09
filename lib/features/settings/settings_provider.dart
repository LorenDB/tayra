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

  const SettingsState({
    this.browseMode = BrowseMode.albums,
    this.cacheSizeLimitMB = 500,
    this.showAndroidAutoRecommendations = true,
  });

  SettingsState copyWith({
    BrowseMode? browseMode,
    int? cacheSizeLimitMB,
    bool? showAndroidAutoRecommendations,
  }) {
    return SettingsState(
      browseMode: browseMode ?? this.browseMode,
      cacheSizeLimitMB: cacheSizeLimitMB ?? this.cacheSizeLimitMB,
      showAndroidAutoRecommendations:
          showAndroidAutoRecommendations ?? this.showAndroidAutoRecommendations,
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

    final cacheSizeMB = prefs.getInt(_keyCacheSizeLimit) ?? 500;
    final showRecommendations =
        prefs.getBool(_keyShowAndroidAutoRecommendations) ?? true;

    state = state.copyWith(
      browseMode: browseMode,
      cacheSizeLimitMB: cacheSizeMB,
      showAndroidAutoRecommendations: showRecommendations,
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

  static Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBrowseMode);
    await prefs.remove(_keyCacheSizeLimit);
    await prefs.remove(_keyShowAndroidAutoRecommendations);
  }
}
