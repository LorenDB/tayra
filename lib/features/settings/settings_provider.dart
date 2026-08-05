import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/api/client_data_service.dart';
import 'package:tayra/core/api/client_preferences.dart';
import 'package:tayra/core/audio/audio_quality.dart';
import 'package:tayra/core/cache/cache_manager.dart';

// ── Browse mode enum ────────────────────────────────────────────────────

enum BrowseMode { albums, artists }

// ── Multi-disc display mode enum ─────────────────────────────────────────

enum MultiDiscDisplayMode { discSections, continuousNumbers }

// ── Settings state ──────────────────────────────────────────────────────

class SettingsState {
  final BrowseMode browseMode;
  final Set<int> mobilePinnedTabIndices;
  final int cacheSizeLimitMB;
  final bool useDynamicAlbumAccent;
  final bool gaplessPlayback;
  final bool showYearEndPrompts;
  final bool analyticsEnabled;
  final bool forceOfflineMode;
  final bool developerModeUnlocked;
  final bool showPurgeCacheOption;
  final MultiDiscDisplayMode multiDiscDisplayMode;
  final bool autoDownloadFavorites;
  final bool downloadWifiOnly;
  final bool autoDownloadPodcastEpisodes;
  final int autoDownloadPodcastEpisodeCount;

  /// Preferred streaming quality (resolved to a concrete tier at play time).
  final AudioQuality streamingQuality;

  /// Preferred quality for offline / background downloads.
  final AudioQuality downloadQuality;

  /// When true, step down streaming quality after sustained buffering.
  final bool autoQualityFallback;

  const SettingsState({
    this.browseMode = BrowseMode.albums,
    this.mobilePinnedTabIndices = const {2, 3, 5, 6},
    this.cacheSizeLimitMB = 500,
    this.useDynamicAlbumAccent = true,
    this.gaplessPlayback = true,
    this.showYearEndPrompts = true,
    this.analyticsEnabled = true,
    this.forceOfflineMode = false,
    this.developerModeUnlocked = false,
    this.showPurgeCacheOption = false,
    this.multiDiscDisplayMode = MultiDiscDisplayMode.discSections,
    this.autoDownloadFavorites = false,
    this.downloadWifiOnly = true,
    this.autoDownloadPodcastEpisodes = false,
    this.autoDownloadPodcastEpisodeCount = 3,
    this.streamingQuality = AudioQuality.auto,
    this.downloadQuality = AudioQuality.high,
    this.autoQualityFallback = true,
  });

  // Dev-mode settings are only active when developer mode is unlocked.
  // This acts as a master override so disabling dev mode immediately silences
  // all dev-only UI without needing to reset each individual setting.
  bool get effectiveShowPurgeCacheOption =>
      developerModeUnlocked && showPurgeCacheOption;

  SettingsState copyWith({
    BrowseMode? browseMode,
    Set<int>? mobilePinnedTabIndices,
    int? cacheSizeLimitMB,
    bool? useDynamicAlbumAccent,
    bool? gaplessPlayback,
    bool? showYearEndPrompts,
    bool? analyticsEnabled,
    bool? forceOfflineMode,
    bool? developerModeUnlocked,
    bool? showPurgeCacheOption,
    MultiDiscDisplayMode? multiDiscDisplayMode,
    bool? autoDownloadFavorites,
    bool? downloadWifiOnly,
    bool? autoDownloadPodcastEpisodes,
    int? autoDownloadPodcastEpisodeCount,
    AudioQuality? streamingQuality,
    AudioQuality? downloadQuality,
    bool? autoQualityFallback,
  }) {
    return SettingsState(
      browseMode: browseMode ?? this.browseMode,
      mobilePinnedTabIndices:
          mobilePinnedTabIndices ?? this.mobilePinnedTabIndices,
      cacheSizeLimitMB: cacheSizeLimitMB ?? this.cacheSizeLimitMB,
      useDynamicAlbumAccent:
          useDynamicAlbumAccent ?? this.useDynamicAlbumAccent,
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      showYearEndPrompts: showYearEndPrompts ?? this.showYearEndPrompts,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      forceOfflineMode: forceOfflineMode ?? this.forceOfflineMode,
      developerModeUnlocked:
          developerModeUnlocked ?? this.developerModeUnlocked,
      showPurgeCacheOption: showPurgeCacheOption ?? this.showPurgeCacheOption,
      multiDiscDisplayMode: multiDiscDisplayMode ?? this.multiDiscDisplayMode,
      autoDownloadFavorites:
          autoDownloadFavorites ?? this.autoDownloadFavorites,
      downloadWifiOnly: downloadWifiOnly ?? this.downloadWifiOnly,
      autoDownloadPodcastEpisodes:
          autoDownloadPodcastEpisodes ?? this.autoDownloadPodcastEpisodes,
      autoDownloadPodcastEpisodeCount:
          autoDownloadPodcastEpisodeCount ??
          this.autoDownloadPodcastEpisodeCount,
      streamingQuality: streamingQuality ?? this.streamingQuality,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      autoQualityFallback: autoQualityFallback ?? this.autoQualityFallback,
    );
  }
}

// ── Settings notifier ───────────────────────────────────────────────────

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<SettingsState> {
  static const _keyBrowseMode = 'browse_mode';
  static const _keyMobilePinnedTabIndices = 'mobile_pinned_tab_indices';
  static const _keyCacheSizeLimit = 'cache_max_size_mb';
  static const _keyUseDynamicAlbumAccent = 'use_dynamic_album_accent';
  static const _keyGaplessPlayback = 'gapless_playback';
  static const _keyShowYearEndPrompts = 'show_year_end_prompts';
  static const _keyAnalyticsEnabled = 'analytics_enabled';
  static const _keyForceOfflineMode = 'force_offline_mode';
  static const _keyDeveloperModeUnlocked = 'developer_mode_unlocked';
  static const _keyShowPurgeCacheOption = 'show_purge_cache_option';
  static const _keyMultiDiscDisplayMode = 'multi_disc_display_mode';
  static const _keyAutoDownloadFavorites = 'auto_download_favorites';
  static const _keyDownloadWifiOnly = 'download_wifi_only';
  static const _keyAutoDownloadPodcastEpisodes =
      'auto_download_podcast_episodes';
  static const _keyAutoDownloadPodcastEpisodeCount =
      'auto_download_podcast_episode_count';
  static const _keyStreamingQuality = 'streaming_quality';
  static const _keyDownloadQuality = 'download_quality';
  static const _keyAutoQualityFallback = 'auto_quality_fallback';

  @override
  SettingsState build() {
    Future.microtask(() => _load());
    return const SettingsState();
  }

  /// Re-read SharedPreferences into state (after remote prefs pull).
  Future<void> reloadFromPrefs() => _load();

  void _schedulePreferenceSync(String key, dynamic value) {
    if (!isAllowlistedPreferenceKey(key)) return;
    unawaited(
      ref
          .read(clientDataServiceProvider)
          .pushAllowlistedPreference(key, value)
          .catchError((_) {}),
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final modeStr = prefs.getString(_keyBrowseMode);
    BrowseMode browseMode = BrowseMode.albums;
    if (modeStr == 'artists') {
      browseMode = BrowseMode.artists;
    }

    final pinnedStr = prefs.getString(_keyMobilePinnedTabIndices);
    Set<int> mobilePinnedTabIndices = const {2, 3, 5, 6};
    if (pinnedStr != null && pinnedStr.isNotEmpty) {
      final parsed =
          pinnedStr
              .split(',')
              .map((s) => int.tryParse(s.trim()))
              .whereType<int>()
              .where((i) => i >= 1 && i <= 6)
              .toSet();
      if (parsed.isNotEmpty) mobilePinnedTabIndices = parsed;
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
    final useDynamicAccent = prefs.getBool(_keyUseDynamicAlbumAccent) ?? true;
    final gapless = prefs.getBool(_keyGaplessPlayback) ?? true;
    final showYearEndPrompts = prefs.getBool(_keyShowYearEndPrompts) ?? true;
    final analyticsEnabled = prefs.getBool(_keyAnalyticsEnabled) ?? true;
    final forceOfflineMode = prefs.getBool(_keyForceOfflineMode) ?? false;
    final developerModeUnlocked =
        prefs.getBool(_keyDeveloperModeUnlocked) ?? false;
    final showPurgeCacheOption =
        prefs.getBool(_keyShowPurgeCacheOption) ?? false;

    final multiDiscModeStr = prefs.getString(_keyMultiDiscDisplayMode);
    MultiDiscDisplayMode multiDiscDisplayMode =
        MultiDiscDisplayMode.discSections;
    if (multiDiscModeStr != null) {
      multiDiscDisplayMode = MultiDiscDisplayMode.values.firstWhere(
        (e) => e.name == multiDiscModeStr,
        orElse: () => MultiDiscDisplayMode.discSections,
      );
    }

    final autoDownloadFavorites =
        prefs.getBool(_keyAutoDownloadFavorites) ?? false;
    final downloadWifiOnly = prefs.getBool(_keyDownloadWifiOnly) ?? true;
    final autoDownloadPodcastEpisodes =
        prefs.getBool(_keyAutoDownloadPodcastEpisodes) ?? false;
    final rawPodcastCount = prefs.getInt(_keyAutoDownloadPodcastEpisodeCount);
    final autoDownloadPodcastEpisodeCount =
        (rawPodcastCount != null &&
                const {1, 3, 5, 10}.contains(rawPodcastCount))
            ? rawPodcastCount
            : 3;

    final streamingQuality =
        AudioQualityX.tryParse(prefs.getString(_keyStreamingQuality)) ??
        AudioQuality.auto;
    final downloadQuality =
        AudioQualityX.tryParse(prefs.getString(_keyDownloadQuality)) ??
        AudioQuality.high;
    final autoQualityFallback = prefs.getBool(_keyAutoQualityFallback) ?? true;

    state = state.copyWith(
      browseMode: browseMode,
      mobilePinnedTabIndices: mobilePinnedTabIndices,
      cacheSizeLimitMB: cacheSizeMB,
      useDynamicAlbumAccent: useDynamicAccent,
      gaplessPlayback: gapless,
      showYearEndPrompts: showYearEndPrompts,
      analyticsEnabled: analyticsEnabled,
      forceOfflineMode: forceOfflineMode,
      developerModeUnlocked: developerModeUnlocked,
      showPurgeCacheOption: showPurgeCacheOption,
      multiDiscDisplayMode: multiDiscDisplayMode,
      autoDownloadFavorites: autoDownloadFavorites,
      downloadWifiOnly: downloadWifiOnly,
      autoDownloadPodcastEpisodes: autoDownloadPodcastEpisodes,
      autoDownloadPodcastEpisodeCount: autoDownloadPodcastEpisodeCount,
      streamingQuality: streamingQuality,
      downloadQuality: downloadQuality,
      autoQualityFallback: autoQualityFallback,
    );
  }

  Future<void> setMobilePinnedTabIndices(Set<int> indices) async {
    state = state.copyWith(mobilePinnedTabIndices: indices);
    final prefs = await SharedPreferences.getInstance();
    final stored = indices.join(',');
    await prefs.setString(_keyMobilePinnedTabIndices, stored);
    _schedulePreferenceSync(_keyMobilePinnedTabIndices, stored);
  }

  Future<void> setBrowseMode(BrowseMode mode) async {
    state = state.copyWith(browseMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBrowseMode, mode.name);
    _schedulePreferenceSync(_keyBrowseMode, mode.name);
  }

  Future<void> setCacheSizeLimit(int sizeMB) async {
    state = state.copyWith(cacheSizeLimitMB: sizeMB);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCacheSizeLimit, sizeMB);

    // Update cache manager configuration
    await CacheManager.instance.updateConfig(sizeMB);
    _schedulePreferenceSync(_keyCacheSizeLimit, sizeMB);
  }

  Future<void> setUseDynamicAlbumAccent(bool use) async {
    state = state.copyWith(useDynamicAlbumAccent: use);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseDynamicAlbumAccent, use);
    _schedulePreferenceSync(_keyUseDynamicAlbumAccent, use);
  }

  Future<void> setGaplessPlayback(bool enabled) async {
    state = state.copyWith(gaplessPlayback: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGaplessPlayback, enabled);
    _schedulePreferenceSync(_keyGaplessPlayback, enabled);
  }

  Future<void> setShowYearEndPrompts(bool show) async {
    state = state.copyWith(showYearEndPrompts: show);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowYearEndPrompts, show);
    _schedulePreferenceSync(_keyShowYearEndPrompts, show);
  }

  Future<void> setAnalyticsEnabled(bool enabled) async {
    state = state.copyWith(analyticsEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAnalyticsEnabled, enabled);
    _schedulePreferenceSync(_keyAnalyticsEnabled, enabled);
  }

  Future<void> setForceOfflineMode(bool enabled) async {
    state = state.copyWith(forceOfflineMode: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyForceOfflineMode, enabled);
  }

  Future<void> setDeveloperModeUnlocked(bool unlocked) async {
    state = state.copyWith(developerModeUnlocked: unlocked);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDeveloperModeUnlocked, unlocked);
  }

  Future<void> disableDeveloperMode() async {
    state = state.copyWith(
      developerModeUnlocked: false,
      showPurgeCacheOption: false,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDeveloperModeUnlocked, false);
    await prefs.setBool(_keyShowPurgeCacheOption, false);
  }

  Future<void> setShowPurgeCacheOption(bool show) async {
    state = state.copyWith(showPurgeCacheOption: show);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowPurgeCacheOption, show);
  }

  Future<void> setMultiDiscDisplayMode(MultiDiscDisplayMode mode) async {
    state = state.copyWith(multiDiscDisplayMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMultiDiscDisplayMode, mode.name);
    _schedulePreferenceSync(_keyMultiDiscDisplayMode, mode.name);
  }

  Future<void> setAutoDownloadFavorites(bool enabled) async {
    state = state.copyWith(autoDownloadFavorites: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoDownloadFavorites, enabled);
    _schedulePreferenceSync(_keyAutoDownloadFavorites, enabled);
  }

  Future<void> setDownloadWifiOnly(bool enabled) async {
    state = state.copyWith(downloadWifiOnly: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDownloadWifiOnly, enabled);
    _schedulePreferenceSync(_keyDownloadWifiOnly, enabled);
  }

  Future<void> setAutoDownloadPodcastEpisodes(bool enabled) async {
    state = state.copyWith(autoDownloadPodcastEpisodes: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoDownloadPodcastEpisodes, enabled);
    _schedulePreferenceSync(_keyAutoDownloadPodcastEpisodes, enabled);
  }

  Future<void> setAutoDownloadPodcastEpisodeCount(int count) async {
    final safe = const {1, 3, 5, 10}.contains(count) ? count : 3;
    state = state.copyWith(autoDownloadPodcastEpisodeCount: safe);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAutoDownloadPodcastEpisodeCount, safe);
    _schedulePreferenceSync(_keyAutoDownloadPodcastEpisodeCount, safe);
  }

  Future<void> setStreamingQuality(AudioQuality quality) async {
    state = state.copyWith(streamingQuality: quality);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStreamingQuality, quality.name);
    _schedulePreferenceSync(_keyStreamingQuality, quality.name);
  }

  Future<void> setDownloadQuality(AudioQuality quality) async {
    // Downloads should be a concrete tier, not Auto.
    final concrete = quality == AudioQuality.auto ? AudioQuality.high : quality;
    state = state.copyWith(downloadQuality: concrete);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDownloadQuality, concrete.name);
    _schedulePreferenceSync(_keyDownloadQuality, concrete.name);
  }

  Future<void> setAutoQualityFallback(bool enabled) async {
    state = state.copyWith(autoQualityFallback: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoQualityFallback, enabled);
    _schedulePreferenceSync(_keyAutoQualityFallback, enabled);
  }

  static Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBrowseMode);
    await prefs.remove(_keyMobilePinnedTabIndices);
    await prefs.remove(_keyCacheSizeLimit);
    await prefs.remove(_keyUseDynamicAlbumAccent);
    await prefs.remove(_keyGaplessPlayback);
    await prefs.remove(_keyShowYearEndPrompts);
    await prefs.remove(_keyAnalyticsEnabled);
    await prefs.remove(_keyForceOfflineMode);
    await prefs.remove(_keyDeveloperModeUnlocked);
    await prefs.remove(_keyShowPurgeCacheOption);
    await prefs.remove(_keyMultiDiscDisplayMode);
    await prefs.remove(_keyAutoDownloadFavorites);
    await prefs.remove(_keyDownloadWifiOnly);
    await prefs.remove(_keyAutoDownloadPodcastEpisodes);
    await prefs.remove(_keyAutoDownloadPodcastEpisodeCount);
    await prefs.remove(_keyStreamingQuality);
    await prefs.remove(_keyDownloadQuality);
    await prefs.remove(_keyAutoQualityFallback);
  }
}
