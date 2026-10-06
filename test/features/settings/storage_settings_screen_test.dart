import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/features/settings/storage_settings_screen.dart';

/// Records limit changes instead of applying them to the real cache.
class _RecordingSettings extends SettingsNotifier {
  final List<int> appliedLimits = [];

  @override
  SettingsState build() => const SettingsState(cacheSizeLimitMB: 5000);

  @override
  Future<void> setCacheSizeLimit(int sizeMB) async {
    appliedLimits.add(sizeMB);
    state = state.copyWith(cacheSizeLimitMB: sizeMB);
  }
}

void main() {
  testWidgets(
    'the cache limit is applied when the slider is released, not on the way',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = _RecordingSettings();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(() => settings),
            // Left loading: the stats tile is not what is under test.
            cacheStatsProvider.overrideWith(
              (ref) => Completer<CacheStats>().future,
            ),
          ],
          child: const MaterialApp(home: StorageSettingsScreen()),
        ),
      );
      await tester.scrollUntilVisible(find.byType(Slider), 200);
      await tester.pump();

      final track = tester.getRect(find.byType(Slider));
      final y = track.center.dy;

      // Grab the thumb at the 5 GB end and sweep down to the minimum. Each
      // value passed over would, if applied, evict cached audio down to it.
      final gesture = await tester.startGesture(Offset(track.right - 24, y));
      await gesture.moveTo(Offset(track.center.dx, y));
      await tester.pump();
      await gesture.moveTo(Offset(track.left + 24, y));
      await tester.pump();

      expect(settings.appliedLimits, isEmpty);
      expect(find.text('500 MB'), findsWidgets, reason: 'the label previews');

      // Settle most of the way back up and let go.
      await gesture.moveTo(Offset(track.right - 24, y));
      await tester.pump();
      await gesture.moveTo(Offset(track.left + track.width * 0.8, y));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(settings.appliedLimits, hasLength(1));
      final applied = settings.appliedLimits.single;
      expect(applied, inInclusiveRange(3500, 4750));
      expect(applied % 250, 0, reason: 'stops are 250 MB apart');
    },
  );

  testWidgets('releasing on the current value applies nothing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = _RecordingSettings();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => settings),
          cacheStatsProvider.overrideWith(
            (ref) => Completer<CacheStats>().future,
          ),
        ],
        child: const MaterialApp(home: StorageSettingsScreen()),
      ),
    );
    await tester.scrollUntilVisible(find.byType(Slider), 200);
    await tester.pump();

    final track = tester.getRect(find.byType(Slider));
    final y = track.center.dy;
    final gesture = await tester.startGesture(Offset(track.right - 24, y));
    await gesture.moveTo(Offset(track.left + 24, y));
    await tester.pump();
    await gesture.moveTo(Offset(track.right - 24, y));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(settings.appliedLimits, isEmpty);
  });
}
