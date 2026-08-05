// ── Sensitive key denylist ──────────────────────────────────────────────

/// Prefs keys (or substrings) that must never leave the device in a
/// client-preferences sync. Includes tokens, passwords, and secrets.
bool isSensitiveSettingsKey(String key) {
  final k = key.toLowerCase();
  if (k.contains('token')) return true;
  if (k.contains('password')) return true;
  if (k.contains('secret')) return true;
  if (k.contains('api_key') || k.contains('apikey')) return true;
  if (k == 'server_url' ||
      k == 'access_token' ||
      k == 'refresh_token' ||
      k == 'client_id' ||
      k == 'client_secret') {
    return true;
  }
  // Legacy Nextcloud login material (keys may still exist on upgraded installs)
  if (k.startsWith('nc_') &&
      (k.contains('password') ||
          k.contains('token') ||
          k.contains('secret') ||
          k.contains('login'))) {
    return true;
  }
  return false;
}

// ── Allowlist (safe keys only) ──────────────────────────────────────────

/// Preference keys Tayra may upload to `client-preferences`.
///
/// Matches the rich-client-data design allowlist (local SharedPreferences
/// names). Secrets / API keys / tokens are never included — see also
/// [isSensitiveSettingsKey] which is always applied as a hard denylist.
///
/// Note: design text uses `cache_size_limit_mb`; Tayra stores
/// `cache_max_size_mb` — both are accepted on pull, only the local name
/// is pushed.
const Set<String> kAllowlistedPreferenceKeys = {
  'browse_mode',
  'gapless_playback',
  'use_dynamic_album_accent',
  'show_year_end_prompts',
  'analytics_enabled',
  'multi_disc_display_mode',
  'mobile_pinned_tab_indices',
  'cache_max_size_mb',
  'cache_size_limit_mb', // design alias (pull only)
  'auto_download_favorites',
  'download_wifi_only',
  'auto_download_podcast_episodes',
  'auto_download_podcast_episode_count',
  'streaming_quality',
  'download_quality',
  'auto_quality_fallback',
};

/// Keys we write to SharedPreferences when pulling from the server.
/// Maps design alias → local storage key.
String canonicalLocalPreferenceKey(String key) {
  if (key == 'cache_size_limit_mb') return 'cache_max_size_mb';
  return key;
}

/// Server key for a local prefs key (normalize cache name for push).
String canonicalServerPreferenceKey(String localKey) {
  if (localKey == 'cache_max_size_mb') return 'cache_size_limit_mb';
  return localKey;
}

/// True when [key] may be uploaded / applied as a client preference.
///
/// Allowlist ∩ ¬denylist. Secrets never pass even if mistakenly allowlisted.
bool isAllowlistedPreferenceKey(String key) {
  if (isSensitiveSettingsKey(key)) return false;
  final local = canonicalLocalPreferenceKey(key);
  return kAllowlistedPreferenceKeys.contains(key) ||
      kAllowlistedPreferenceKeys.contains(local);
}

/// Filter a prefs map to allowlisted, non-sensitive entries only.
///
/// Keys are normalized to local SharedPreferences names.
Map<String, dynamic> filterAllowlistedPreferences(Map<String, dynamic> source) {
  final out = <String, dynamic>{};
  for (final entry in source.entries) {
    if (!isAllowlistedPreferenceKey(entry.key)) continue;
    final localKey = canonicalLocalPreferenceKey(entry.key);
    // Prefer first-seen; design alias + local name should not both appear.
    out.putIfAbsent(localKey, () => entry.value);
  }
  return out;
}

/// Build the payload for PUT client-preferences from a local prefs map.
///
/// Uses server-canonical key names; drops secrets and non-allowlisted keys.
Map<String, dynamic> buildServerPreferencesPayload(
  Map<String, dynamic> localPrefs,
) {
  final filtered = filterAllowlistedPreferences(localPrefs);
  final out = <String, dynamic>{};
  for (final entry in filtered.entries) {
    out[canonicalServerPreferenceKey(entry.key)] = entry.value;
  }
  return out;
}
