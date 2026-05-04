import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/cache/cache_manager.dart';

// ── Browse mode enum ────────────────────────────────────────────────────

enum BrowseMode { albums, artists }

// ── AI provider type enum ───────────────────────────────────────────────

enum AiProviderType { geminiNano, groq, openRouter, custom }

extension AiProviderTypeX on AiProviderType {
  String get displayName {
    switch (this) {
      case AiProviderType.geminiNano:
        return 'On-device (Gemini Nano)';
      case AiProviderType.groq:
        return 'Groq';
      case AiProviderType.openRouter:
        return 'OpenRouter';
      case AiProviderType.custom:
        return 'Custom endpoint';
    }
  }
}

// ── Settings state ──────────────────────────────────────────────────────

class SettingsState {
  final BrowseMode browseMode;
  final int cacheSizeLimitMB;
  final bool androidAutoEnabled;
  final bool useDynamicAlbumAccent;
  final bool gaplessPlayback;
  final bool aiEnabled;
  final bool aiDownloadPromptShown;
  final bool showYearEndPrompts;
  final bool analyticsEnabled;
  final bool forceOfflineMode;
  final bool developerModeUnlocked;
  final AiProviderType aiProviderType;
  final String groqApiKey;
  final String groqModel;
  final String openRouterApiKey;
  final String openRouterModel;
  final String customEndpointUrl;
  final String customEndpointApiKey;
  final String customModelName;

  const SettingsState({
    this.browseMode = BrowseMode.albums,
    this.cacheSizeLimitMB = 500,
    this.androidAutoEnabled = true,
    this.useDynamicAlbumAccent = true,
    this.gaplessPlayback = true,
    this.aiEnabled = true,
    this.aiDownloadPromptShown = false,
    this.showYearEndPrompts = true,
    this.analyticsEnabled = true,
    this.forceOfflineMode = false,
    this.developerModeUnlocked = false,
    this.aiProviderType = AiProviderType.geminiNano,
    this.groqApiKey = '',
    this.groqModel = 'llama-3.1-8b-instant',
    this.openRouterApiKey = '',
    this.openRouterModel = 'meta-llama/llama-3.1-8b-instruct:free',
    this.customEndpointUrl = '',
    this.customEndpointApiKey = '',
    this.customModelName = 'gpt-4o-mini',
  });

  bool get isAiProviderConfigured {
    if (!aiEnabled) return false;
    switch (aiProviderType) {
      case AiProviderType.geminiNano:
        return true; // actual availability checked async via MethodChannel
      case AiProviderType.groq:
        return groqApiKey.isNotEmpty;
      case AiProviderType.openRouter:
        return openRouterApiKey.isNotEmpty;
      case AiProviderType.custom:
        return customEndpointUrl.isNotEmpty;
    }
  }

  SettingsState copyWith({
    BrowseMode? browseMode,
    int? cacheSizeLimitMB,
    bool? androidAutoEnabled,
    bool? useDynamicAlbumAccent,
    bool? gaplessPlayback,
    bool? aiEnabled,
    bool? aiDownloadPromptShown,
    bool? showYearEndPrompts,
    bool? analyticsEnabled,
    bool? forceOfflineMode,
    bool? developerModeUnlocked,
    AiProviderType? aiProviderType,
    String? groqApiKey,
    String? groqModel,
    String? openRouterApiKey,
    String? openRouterModel,
    String? customEndpointUrl,
    String? customEndpointApiKey,
    String? customModelName,
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
      showYearEndPrompts: showYearEndPrompts ?? this.showYearEndPrompts,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      forceOfflineMode: forceOfflineMode ?? this.forceOfflineMode,
      developerModeUnlocked: developerModeUnlocked ?? this.developerModeUnlocked,
      aiProviderType: aiProviderType ?? this.aiProviderType,
      groqApiKey: groqApiKey ?? this.groqApiKey,
      groqModel: groqModel ?? this.groqModel,
      openRouterApiKey: openRouterApiKey ?? this.openRouterApiKey,
      openRouterModel: openRouterModel ?? this.openRouterModel,
      customEndpointUrl: customEndpointUrl ?? this.customEndpointUrl,
      customEndpointApiKey: customEndpointApiKey ?? this.customEndpointApiKey,
      customModelName: customModelName ?? this.customModelName,
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
  static const _keyShowYearEndPrompts = 'show_year_end_prompts';
  static const _keyAnalyticsEnabled = 'analytics_enabled';
  static const _keyForceOfflineMode = 'force_offline_mode';
  static const _keyDeveloperModeUnlocked = 'developer_mode_unlocked';
  static const _keyAiProviderType = 'ai_provider_type';
  static const _keyGroqApiKey = 'groq_api_key';
  static const _keyGroqModel = 'groq_model';
  static const _keyOpenRouterApiKey = 'open_router_api_key';
  static const _keyOpenRouterModel = 'open_router_model';
  static const _keyCustomEndpointUrl = 'custom_endpoint_url';
  static const _keyCustomEndpointApiKey = 'custom_endpoint_api_key';
  static const _keyCustomModelName = 'custom_model_name';

  // On non-Android platforms, AI defaults to off and Groq is the default provider.
  static bool get _defaultAiEnabled =>
      defaultTargetPlatform == TargetPlatform.android;
  static AiProviderType get _defaultAiProviderType =>
      defaultTargetPlatform == TargetPlatform.android
          ? AiProviderType.geminiNano
          : AiProviderType.groq;

  @override
  SettingsState build() {
    Future.microtask(() => _load());
    return SettingsState(
      aiEnabled: _defaultAiEnabled,
      aiProviderType: _defaultAiProviderType,
    );
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
    final aiEnabled = prefs.getBool(_keyAiEnabled) ?? _defaultAiEnabled;
    final aiDownloadPromptShown =
        prefs.getBool(_keyAiDownloadPromptShown) ?? false;
    final showYearEndPrompts = prefs.getBool(_keyShowYearEndPrompts) ?? true;
    final analyticsEnabled = prefs.getBool(_keyAnalyticsEnabled) ?? true;
    final forceOfflineMode = prefs.getBool(_keyForceOfflineMode) ?? false;
    final developerModeUnlocked =
        prefs.getBool(_keyDeveloperModeUnlocked) ?? false;

    final providerTypeStr = prefs.getString(_keyAiProviderType);
    AiProviderType aiProviderType = _defaultAiProviderType;
    if (providerTypeStr != null) {
      aiProviderType = AiProviderType.values.firstWhere(
        (e) => e.name == providerTypeStr,
        orElse: () => _defaultAiProviderType,
      );
    }

    final groqApiKey = prefs.getString(_keyGroqApiKey) ?? '';
    final groqModel =
        prefs.getString(_keyGroqModel) ?? 'llama-3.1-8b-instant';
    final openRouterApiKey = prefs.getString(_keyOpenRouterApiKey) ?? '';
    final openRouterModel = prefs.getString(_keyOpenRouterModel) ??
        'meta-llama/llama-3.1-8b-instruct:free';
    final customEndpointUrl = prefs.getString(_keyCustomEndpointUrl) ?? '';
    final customEndpointApiKey =
        prefs.getString(_keyCustomEndpointApiKey) ?? '';
    final customModelName =
        prefs.getString(_keyCustomModelName) ?? 'gpt-4o-mini';

    state = state.copyWith(
      browseMode: browseMode,
      cacheSizeLimitMB: cacheSizeMB,
      androidAutoEnabled: showRecommendations,
      useDynamicAlbumAccent: useDynamicAccent,
      gaplessPlayback: gapless,
      aiEnabled: aiEnabled,
      aiDownloadPromptShown: aiDownloadPromptShown,
      showYearEndPrompts: showYearEndPrompts,
      analyticsEnabled: analyticsEnabled,
      forceOfflineMode: forceOfflineMode,
      developerModeUnlocked: developerModeUnlocked,
      aiProviderType: aiProviderType,
      groqApiKey: groqApiKey,
      groqModel: groqModel,
      openRouterApiKey: openRouterApiKey,
      openRouterModel: openRouterModel,
      customEndpointUrl: customEndpointUrl,
      customEndpointApiKey: customEndpointApiKey,
      customModelName: customModelName,
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

  Future<void> setShowYearEndPrompts(bool show) async {
    state = state.copyWith(showYearEndPrompts: show);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowYearEndPrompts, show);
  }

  Future<void> setAnalyticsEnabled(bool enabled) async {
    state = state.copyWith(analyticsEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAnalyticsEnabled, enabled);
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

  Future<void> setAiProviderType(AiProviderType type) async {
    state = state.copyWith(aiProviderType: type);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAiProviderType, type.name);
  }

  Future<void> setGroqApiKey(String key) async {
    state = state.copyWith(groqApiKey: key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGroqApiKey, key);
  }

  Future<void> setGroqModel(String model) async {
    state = state.copyWith(groqModel: model);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGroqModel, model);
  }

  Future<void> setOpenRouterApiKey(String key) async {
    state = state.copyWith(openRouterApiKey: key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOpenRouterApiKey, key);
  }

  Future<void> setOpenRouterModel(String model) async {
    state = state.copyWith(openRouterModel: model);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOpenRouterModel, model);
  }

  Future<void> setCustomEndpointUrl(String url) async {
    state = state.copyWith(customEndpointUrl: url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomEndpointUrl, url);
  }

  Future<void> setCustomEndpointApiKey(String key) async {
    state = state.copyWith(customEndpointApiKey: key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomEndpointApiKey, key);
  }

  Future<void> setCustomModelName(String model) async {
    state = state.copyWith(customModelName: model);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomModelName, model);
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
    await prefs.remove(_keyShowYearEndPrompts);
    await prefs.remove(_keyAnalyticsEnabled);
    await prefs.remove(_keyForceOfflineMode);
    await prefs.remove(_keyDeveloperModeUnlocked);
    await prefs.remove(_keyAiProviderType);
    await prefs.remove(_keyGroqApiKey);
    await prefs.remove(_keyGroqModel);
    await prefs.remove(_keyOpenRouterApiKey);
    await prefs.remove(_keyOpenRouterModel);
    await prefs.remove(_keyCustomEndpointUrl);
    await prefs.remove(_keyCustomEndpointApiKey);
    await prefs.remove(_keyCustomModelName);
  }
}
