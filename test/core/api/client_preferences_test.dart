import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/api/client_preferences.dart';

void main() {
  group('isAllowlistedPreferenceKey', () {
    test('allows design UX keys', () {
      expect(isAllowlistedPreferenceKey('browse_mode'), isTrue);
      expect(isAllowlistedPreferenceKey('gapless_playback'), isTrue);
      expect(isAllowlistedPreferenceKey('use_dynamic_album_accent'), isTrue);
      expect(isAllowlistedPreferenceKey('analytics_enabled'), isTrue);
      expect(isAllowlistedPreferenceKey('ai_enabled'), isTrue);
      expect(isAllowlistedPreferenceKey('ai_provider_type'), isTrue);
      expect(isAllowlistedPreferenceKey('cache_max_size_mb'), isTrue);
      expect(isAllowlistedPreferenceKey('cache_size_limit_mb'), isTrue);
    });

    test('rejects secrets even if name looks allowlisted', () {
      expect(isAllowlistedPreferenceKey('groq_api_key'), isFalse);
      expect(isAllowlistedPreferenceKey('open_router_api_key'), isFalse);
      expect(isAllowlistedPreferenceKey('custom_endpoint_api_key'), isFalse);
      expect(isAllowlistedPreferenceKey('access_token'), isFalse);
      expect(isAllowlistedPreferenceKey('nc_app_password'), isFalse);
      expect(isAllowlistedPreferenceKey('client_secret'), isFalse);
    });

    test('rejects non-allowlisted device-local keys', () {
      expect(isAllowlistedPreferenceKey('force_offline_mode'), isFalse);
      expect(isAllowlistedPreferenceKey('developer_mode_unlocked'), isFalse);
      expect(isAllowlistedPreferenceKey('groq_model'), isFalse);
    });
  });

  group('buildServerPreferencesPayload', () {
    test('strips secrets and maps cache key', () {
      final payload = buildServerPreferencesPayload({
        'browse_mode': 'albums',
        'gapless_playback': true,
        'cache_max_size_mb': 500,
        'groq_api_key': 'sk-secret',
        'access_token': 'tok',
        'force_offline_mode': true,
      });
      expect(payload, {
        'browse_mode': 'albums',
        'gapless_playback': true,
        'cache_size_limit_mb': 500,
      });
      expect(payload.containsKey('groq_api_key'), isFalse);
      expect(payload.containsKey('access_token'), isFalse);
      expect(payload.containsKey('force_offline_mode'), isFalse);
    });
  });

  group('filterAllowlistedPreferences', () {
    test('normalizes design cache alias to local key', () {
      final filtered = filterAllowlistedPreferences({
        'cache_size_limit_mb': 250,
        'browse_mode': 'artists',
        'open_router_api_key': 'nope',
      });
      expect(filtered, {'cache_max_size_mb': 250, 'browse_mode': 'artists'});
    });
  });
}
