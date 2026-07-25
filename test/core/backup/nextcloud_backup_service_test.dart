import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/backup/nextcloud_backup_service.dart';

void main() {
  group('getDeviceUuid', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('generates a valid lowercase UUID v4 on first call', () async {
      final uuid = await getDeviceUuid();

      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(uuid),
        isTrue,
        reason: '$uuid is not a valid lowercase UUID v4',
      );
    });

    test('is stable across repeated calls within the same install', () async {
      final first = await getDeviceUuid();
      final second = await getDeviceUuid();

      expect(second, first);
    });

    test('is unique across fresh installs (different random UUIDs)', () async {
      final first = await getDeviceUuid();

      // Simulate a fresh install by clearing prefs + forgetting the
      // (non-persistent) in-process cache of a second install.
      SharedPreferences.setMockInitialValues({});
      final second = await getDeviceUuid();

      expect(second, isNot(first));
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(second),
        isTrue,
      );
    });

    test('preserves an existing valid UUID from storage', () async {
      const preset = '550e8400-e29b-41d4-a716-446655440000';
      SharedPreferences.setMockInitialValues({'tayra_device_uuid': preset});

      final uuid = await getDeviceUuid();

      expect(uuid, preset);
    });

    test('regenerates when stored value is malformed', () async {
      SharedPreferences.setMockInitialValues({
        'tayra_device_uuid': 'not-a-uuid',
      });

      final uuid = await getDeviceUuid();

      expect(uuid, isNot('not-a-uuid'));
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(uuid),
        isTrue,
      );
    });
  });

  group('isSensitiveSettingsKey', () {
    test('strips tokens, passwords, secrets', () {
      expect(isSensitiveSettingsKey('access_token'), isTrue);
      expect(isSensitiveSettingsKey('refresh_token'), isTrue);
      expect(isSensitiveSettingsKey('nc_app_password'), isTrue);
      expect(isSensitiveSettingsKey('client_secret'), isTrue);
    });

    test('strips api_key patterns (AI keys)', () {
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
