import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/features/player/queue_screen.dart';

import 'player_harness.dart' show tracks;

/// A player frozen in one state, with no audio behind it.
class _StaticPlayer extends PlayerNotifier {
  _StaticPlayer(this._state);

  final PlayerState _state;

  @override
  PlayerState build() => _state;
}

void main() {
  testWidgets('a single upcoming track is counted in the singular', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith(
            () => _StaticPlayer(PlayerState(queue: tracks(2), currentIndex: 0)),
          ),
        ],
        child: const MaterialApp(home: QueueScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 track'), findsOneWidget);
    expect(find.text('1 tracks'), findsNothing);
  });
}
