import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/analytics/analytics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // DO_NOT_TRACK in the environment switches analytics off for good, which
  // is the right behaviour but leaves nothing to exercise here.
  final doNotTrack = const {
    '1',
    'true',
  }.contains(Platform.environment['DO_NOT_TRACK']?.trim().toLowerCase());

  test('DO_NOT_TRACK in the environment wins over the stored choice', () async {
    SharedPreferences.setMockInitialValues({'analytics_enabled': true});
    await Analytics.loadEnabledFromPrefs();

    expect(Analytics.enabled, !doNotTrack);
  });

  test(
    'events tracked before the plugin is ready do not throw',
    () async {
      SharedPreferences.setMockInitialValues({});
      await Analytics.loadEnabledFromPrefs();
      expect(Analytics.enabled, isTrue);

      // The plugin cannot initialise in a unit test (no platform channels),
      // which is the same position events are in during app startup.
      // Tracking must neither throw here nor leave an unhandled async error
      // behind; either would fail this test.
      for (var i = 0; i < 20; i++) {
        Analytics.track('api_call', {'status': 200, 'endpoint': 'albums'});
      }
      await Analytics.initializeIfEnabled();
      Analytics.track('screen_view', {'screen': 'home'});
      await pumpEventQueue();
    },
    skip: doNotTrack ? 'DO_NOT_TRACK is set in this environment' : false,
  );

  test('opting out makes tracking a no-op', () async {
    SharedPreferences.setMockInitialValues({'analytics_enabled': false});
    await Analytics.loadEnabledFromPrefs();
    expect(Analytics.enabled, isFalse);

    Analytics.track('anything', {'email': 'someone@example.org'});
    await pumpEventQueue();
  });
}
