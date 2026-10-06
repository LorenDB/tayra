import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/features/player/play_control_button.dart';
import 'package:tayra/features/player/player_provider.dart';

/// Player double that never touches the platform audio handler.
class _RecordingPlayer extends PlayerNotifier {
  int cancelOrRetryCalls = 0;
  int toggleCalls = 0;

  @override
  PlayerState build() {
    return const PlayerState(isLoading: true, isPlaying: false);
  }

  @override
  void cancelOrRetryLoad() {
    cancelOrRetryCalls++;
  }

  @override
  Future<void> togglePlayPause() async {
    toggleCalls++;
  }
}

void main() {
  testWidgets(
    'mini-player and now-playing controls accept a tap while loading',
    (tester) async {
      final player = _RecordingPlayer();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [playerProvider.overrideWith(() => player)],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  PlaybackPlayButton(variant: PlaybackPlayButtonVariant.mini),
                  PlaybackPlayButton(
                    variant: PlaybackPlayButtonVariant.emphasis,
                    size: 72,
                    iconSize: 36,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));

      await tester.tap(find.byType(PlaybackPlayButton).first);
      await tester.tap(find.byType(PlaybackPlayButton).last);
      await tester.pump();

      expect(player.cancelOrRetryCalls, 2);
      expect(player.toggleCalls, 0);
    },
  );
}
