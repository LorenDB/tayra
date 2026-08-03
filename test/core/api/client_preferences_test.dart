import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/api/client_preferences.dart';

void main() {
  group('isSensitiveSettingsKey', () {
    test('strips tokens, passwords, secrets', () {
      expect(isSensitiveSettingsKey('access_token'), isTrue);
      expect(isSensitiveSettingsKey('refresh_token'), isTrue);
      expect(isSensitiveSettingsKey('nc_app_password'), isTrue);
      expect(isSensitiveSettingsKey('client_secret'), isTrue);
    });

    test('strips api_key patterns', () {
      expect(isSensitiveSettingsKey('groq_api_key'), isTrue);
      expect(isSensitiveSettingsKey('open_router_api_key'), isTrue);
      expect(isSensitiveSettingsKey('custom_endpoint_api_key'), isTrue);
      expect(isSensitiveSettingsKey('someApikeyValue'), isTrue);
    });

    test('allows ordinary preference keys', () {
      expect(isSensitiveSettingsKey('gapless_playback'), isFalse);
      expect(isSensitiveSettingsKey('browse_mode'), isFalse);
      expect(isSensitiveSettingsKey('tayra_device_uuid'), isFalse);
    });
  });
}
