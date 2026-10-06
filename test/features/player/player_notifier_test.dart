import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tayra/features/player/player_provider.dart';

import 'player_harness.dart';

void main() {
  group('starting a queue', () {
    test('gapless: the whole queue reaches the player and plays', () async {
      final h = await PlayerHarness.start();

      await h.player.playTracks(tracks(8), startIndex: 2);
      await settle();

      expect(h.state.currentTrack?.id, 3);
      expect(h.state.isPlaying, isTrue);
      expect(h.state.isLoading, isFalse);
      expect(h.native.playing, isTrue);
      h.expectPlaylistMirrorsQueue();
    });

    test('single source: only the current track is loaded', () async {
      final h = await PlayerHarness.start(gapless: false);

      await h.player.playTracks(tracks(4), startIndex: 1);
      await settle();

      expect(h.native.trackIds, [2]);
      expect(h.state.currentTrack?.id, 2);
      expect(h.state.isPlaying, isTrue);
    });

    test('adding to an empty queue starts playing it', () async {
      final h = await PlayerHarness.start();

      h.player.addToQueue(tracks(3));
      await settle();

      expect(h.state.currentIndex, 0);
      expect(h.state.isPlaying, isTrue);
      h.expectPlaylistMirrorsQueue();
    });
  });

  group('gapless skips', () {
    test('next under repeat-one moves to the next track', () async {
      final h = await PlayerHarness.start();
      await h.player.playTracks(tracks(5));
      await settle();
      h.player.toggleLoopMode(); // off → all
      h.player.toggleLoopMode(); // all → one
      await settle();
      expect(h.state.loopMode, LoopMode.one);

      await h.player.skipNext();
      await settle();

      expect(h.state.currentTrack?.id, 2);
      h.expectPlaylistMirrorsQueue();

      await h.player.skipPrevious();
      await settle();

      expect(h.state.currentTrack?.id, 1);
      h.expectPlaylistMirrorsQueue();
    });

    test(
      'a skip right after starting does not cut the playlist short',
      () async {
        final h = await PlayerHarness.start();
        // Hold the append of the rest of the playlist in mid-flight.
        final appending = Completer<void>();
        h.platform.onPlayerCreated = (native) => native.insertGate = appending;

        await h.player.playTracks(tracks(120));
        await settle();
        expect(
          h.native.trackIds,
          hasLength(3),
          reason: 'only the start window',
        );

        // The skip arrives while later tracks are still being appended.
        await h.player.skipNext();
        h.native.insertGate = null;
        appending.complete();
        await settle(60);

        expect(h.state.currentTrack?.id, 2);
        expect(h.native.trackIds, hasLength(120));
        h.expectPlaylistMirrorsQueue();
        expect(h.native.playing, isTrue);
      },
    );

    test('next while paused starts the next track', () async {
      final h = await PlayerHarness.start();
      await h.player.playTracks(tracks(3));
      await settle();
      await h.player.pause();
      await settle();
      expect(h.state.isPlaying, isFalse);

      await h.player.skipNext();
      await settle();

      expect(h.state.currentTrack?.id, 2);
      expect(h.state.isPlaying, isTrue);
      expect(h.native.playing, isTrue);
      h.expectPlaylistMirrorsQueue();
    });

    test('tapping a queue row while paused plays that track', () async {
      final h = await PlayerHarness.start();
      await h.player.playTracks(tracks(6));
      await settle();
      await h.player.pause();
      await settle();

      await h.player.jumpTo(4);
      await settle();

      expect(h.state.currentTrack?.id, 5);
      expect(h.state.isPlaying, isTrue);
      expect(h.native.playing, isTrue);
      h.expectPlaylistMirrorsQueue();
    });
  });

  group('end of the queue', () {
    Future<PlayerHarness> finishedQueue({bool gapless = true}) async {
      final h = await PlayerHarness.start(gapless: gapless);
      await h.player.playTracks(tracks(3), startIndex: 2);
      await settle();
      h.native.finishPlaylist();
      await settle();
      return h;
    }

    for (final gapless in [true, false]) {
      final mode = gapless ? 'gapless' : 'single source';

      test('$mode: parks on the first track, paused', () async {
        final h = await finishedQueue(gapless: gapless);

        expect(h.state.queueCompleted, isTrue);
        expect(h.state.currentIndex, 0);
        expect(h.state.isPlaying, isFalse);
        expect(h.state.isLoading, isFalse);
        expect(h.state.position, Duration.zero);
        expect(h.state.duration, const Duration(seconds: 180));
        expect(h.native.playing, isFalse, reason: 'play intent is cleared');
      });

      test('$mode: play starts over and shows as playing', () async {
        final h = await finishedQueue(gapless: gapless);

        await h.player.play();
        await settle();

        expect(h.state.currentTrack?.id, 1);
        expect(h.state.isPlaying, isTrue);
        expect(h.state.queueCompleted, isFalse);
        expect(h.native.playing, isTrue);
        expect(h.native.currentTrackId, 1);
      });

      test('$mode: a seek moves where play will start', () async {
        final h = await finishedQueue(gapless: gapless);

        await h.player.seekTo(const Duration(seconds: 60));
        await settle();
        expect(h.state.position, const Duration(seconds: 60));
        expect(
          h.native.playing,
          isFalse,
          reason: 'seeking must not start audio',
        );

        await h.player.play();
        await settle();

        expect(h.native.currentTrackId, 1);
        expect(h.native.position, const Duration(seconds: 60));
        expect(h.state.isPlaying, isTrue);
      });

      test('$mode: tapping a queue row plays it', () async {
        final h = await finishedQueue(gapless: gapless);

        await h.player.jumpTo(1);
        await settle();

        expect(h.state.currentTrack?.id, 2);
        expect(h.state.isPlaying, isTrue);
        expect(h.native.currentTrackId, 2);
        expect(h.native.playing, isTrue);
      });

      test('$mode: previous leaves it parked', () async {
        final h = await finishedQueue(gapless: gapless);

        await h.player.skipPrevious();
        await settle();

        expect(h.state.currentIndex, 0);
        expect(h.state.isPlaying, isFalse);
        expect(h.native.playing, isFalse);
      });

      test('$mode: a network change does not restart it', () async {
        final h = await finishedQueue(gapless: gapless);
        final loadsBefore = h.native.calls.where((c) => c == 'load').length;

        h.connectivity.add([ConnectivityResult.none]);
        await settle();
        h.connectivity.add([ConnectivityResult.wifi]);
        await settle();

        expect(h.state.isPlaying, isFalse);
        expect(h.native.playing, isFalse);
        expect(
          h.platform.players
              .expand((p) => p.calls)
              .where((c) => c == 'load')
              .length,
          loadsBefore,
        );
      });
    }

    test('single source: the next track follows when one ends', () async {
      final h = await PlayerHarness.start(gapless: false);
      await h.player.playTracks(tracks(3));
      await settle();

      h.native.finishPlaylist();
      await settle();

      expect(h.state.currentTrack?.id, 2);
      expect(h.state.isPlaying, isTrue);
      expect(h.native.currentTrackId, 2);
      expect(h.state.queueCompleted, isFalse);
    });

    test(
      'gapless: a playlist that fell short carries on from the queue',
      () async {
        final h = await PlayerHarness.start();
        await h.player.playTracks(tracks(6));
        await settle();
        // The native side lost the tail (as after a failed append).
        h.native.uris.removeRange(3, 6);
        h.native.index = 2;
        h.native.reportPosition(Duration.zero);
        await settle();
        expect(h.state.currentIndex, 2);

        h.native.finishPlaylist();
        await settle(30);

        expect(h.state.queueCompleted, isFalse);
        expect(h.state.currentTrack?.id, 4);
        expect(h.state.isPlaying, isTrue);
        h.expectPlaylistMirrorsQueue();
      },
    );
  });

  group('editing the queue (gapless)', () {
    test(
      'edits made while the playlist is still filling in land in order',
      () async {
        final h = await PlayerHarness.start();

        final started = h.player.playTracks(tracks(90));
        await Future<void>.delayed(Duration.zero);
        h.player.addToQueue([track(500)]);
        h.player.playNext(track(600));
        h.player.insertTracksNext([track(700), track(701)]);
        h.player.removeFromQueue(40);
        h.player.reorderQueue(10, 20);
        await started;
        await settle(60);

        expect(h.native.trackIds, h.queueIds);
        expect(h.queueIds.take(4), [1, 700, 701, 600]);
        expect(h.queueIds.last, 500);
        h.expectPlaylistMirrorsQueue();
      },
    );

    test('removing an upcoming track keeps the current one playing', () async {
      final h = await PlayerHarness.start();
      await h.player.playTracks(tracks(5), startIndex: 1);
      await settle();

      h.player.removeFromQueue(0);
      h.player.removeFromQueue(2);
      await settle();

      expect(h.queueIds, [2, 3, 5]);
      expect(h.state.currentTrack?.id, 2);
      expect(h.native.playing, isTrue);
      h.expectPlaylistMirrorsQueue();
    });

    test(
      'removing the current track plays the one that takes its place',
      () async {
        final h = await PlayerHarness.start();
        await h.player.playTracks(tracks(4), startIndex: 1);
        await settle();

        h.player.removeFromQueue(1);
        await settle();

        expect(h.queueIds, [1, 3, 4]);
        expect(h.state.currentTrack?.id, 3);
        expect(h.state.isPlaying, isTrue);
        expect(h.state.queueCompleted, isFalse);
        expect(h.handler.mediaItem.value?.id, '3');
        h.expectPlaylistMirrorsQueue();
      },
    );

    test(
      'removing the current last track falls back to the previous one',
      () async {
        final h = await PlayerHarness.start();
        await h.player.playTracks(tracks(3), startIndex: 2);
        await settle();

        h.player.removeFromQueue(2);
        await settle();

        expect(h.queueIds, [1, 2]);
        expect(h.state.currentTrack?.id, 2);
        expect(
          h.state.queueCompleted,
          isFalse,
          reason: 'not the end of the queue',
        );
        expect(h.state.isPlaying, isTrue);
        h.expectPlaylistMirrorsQueue();
      },
    );

    test('removing the current track while paused stays paused', () async {
      final h = await PlayerHarness.start();
      await h.player.playTracks(tracks(3));
      await settle();
      await h.player.pause();
      await settle();

      h.player.removeFromQueue(0);
      await settle();

      expect(h.state.currentTrack?.id, 2);
      expect(h.state.isPlaying, isFalse);
      expect(h.native.playing, isFalse);
      h.expectPlaylistMirrorsQueue();
    });

    test('removing the only track clears the queue for good', () async {
      final h = await PlayerHarness.start();
      await h.player.playTracks(tracks(1));
      await settle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('player_queue'), isNotNull);

      h.player.removeFromQueue(0);
      await settle();

      expect(h.state.queue, isEmpty);
      expect(h.state.currentTrack, isNull);
      expect(h.state.isPlaying, isFalse);
      expect(prefs.getString('player_queue'), isNull);
    });

    test('reordering and shuffling keep the player in step', () async {
      final h = await PlayerHarness.start();
      await h.player.playTracks(tracks(12), startIndex: 4);
      await settle();

      h.player.reorderQueue(4, 0); // move the playing track to the front
      h.player.reorderQueue(11, 2);
      await settle();
      expect(h.state.currentTrack?.id, 5);
      h.expectPlaylistMirrorsQueue();

      h.player.toggleShuffle();
      await settle(40);
      expect(h.state.currentTrack?.id, 5);
      expect(h.state.currentIndex, 0);
      h.expectPlaylistMirrorsQueue();

      h.player.toggleShuffle();
      await settle(40);
      expect(h.state.currentTrack?.id, 5);
      h.expectPlaylistMirrorsQueue();
      expect(h.native.playing, isTrue);
    });
  });

  group('single source edits', () {
    test('removing the current track loads the next one', () async {
      final h = await PlayerHarness.start(gapless: false);
      await h.player.playTracks(tracks(3));
      await settle();

      h.player.removeFromQueue(0);
      await settle();

      expect(h.queueIds, [2, 3]);
      expect(h.native.currentTrackId, 2);
      expect(h.state.isPlaying, isTrue);
    });

    test('removing the current track while paused waits for play', () async {
      final h = await PlayerHarness.start(gapless: false);
      await h.player.playTracks(tracks(3));
      await settle();
      await h.player.pause();
      await settle();

      h.player.removeFromQueue(0);
      await settle();

      expect(h.state.currentTrack?.id, 2);
      expect(h.state.isPlaying, isFalse);
      expect(h.native.playing, isFalse);
      expect(h.state.position, Duration.zero);

      await h.player.play();
      await settle();

      expect(h.native.currentTrackId, 2);
      expect(h.state.isPlaying, isTrue);
    });
  });

  group('restored queue', () {
    Map<String, Object> savedQueue({int index = 1, int positionMs = 30000}) {
      return {
        'player_queue': jsonEncode(
          tracks(3).map((t) => t.toPersistenceJson()).toList(),
        ),
        'player_current_index': index,
        'player_position': positionMs,
        'player_duration': 180000,
      };
    }

    test('comes back paused at the saved position without loading', () async {
      final h = await PlayerHarness.start(prefs: savedQueue());

      expect(h.queueIds, [1, 2, 3]);
      expect(h.state.currentTrack?.id, 2);
      expect(h.state.position, const Duration(seconds: 30));
      expect(h.state.isPlaying, isFalse);
      expect(h.platform.hasPlayer, isFalse);
    });

    for (final gapless in [true, false]) {
      final mode = gapless ? 'gapless' : 'single source';

      test('$mode: a seek before the first play is where it starts', () async {
        final h = await PlayerHarness.start(
          gapless: gapless,
          prefs: savedQueue(),
        );

        await h.player.seekTo(const Duration(seconds: 90));
        expect(h.state.position, const Duration(seconds: 90));
        await h.player.play();
        await settle();

        expect(h.native.currentTrackId, 2);
        expect(h.native.position, const Duration(seconds: 90));
        expect(h.state.isPlaying, isTrue);
      });

      test('$mode: play from the notification resumes it', () async {
        final h = await PlayerHarness.start(
          gapless: gapless,
          prefs: savedQueue(),
        );

        // What a headset button or the lock screen triggers.
        await h.handler.play();
        await settle();

        expect(h.native.currentTrackId, 2);
        expect(h.native.position, const Duration(seconds: 30));
        expect(h.native.playing, isTrue);
        expect(h.state.isPlaying, isTrue);
      });

      test('$mode: previous rewinds the restored track', () async {
        final h = await PlayerHarness.start(
          gapless: gapless,
          prefs: savedQueue(),
        );

        await h.player.skipPrevious();
        expect(h.state.position, Duration.zero);
        expect(h.state.currentTrack?.id, 2);

        await h.player.play();
        await settle();
        expect(h.native.currentTrackId, 2);
        expect(h.native.position, Duration.zero);
      });
    }

    test('removing the restored current track does not start audio', () async {
      final h = await PlayerHarness.start(prefs: savedQueue());

      h.player.removeFromQueue(1);
      await settle();

      expect(h.queueIds, [1, 3]);
      expect(h.state.currentTrack?.id, 3);
      expect(h.state.position, Duration.zero);
      expect(h.state.isPlaying, isFalse);
      expect(h.platform.hasPlayer, isFalse);

      await h.player.play();
      await settle();
      expect(h.native.currentTrackId, 3);
      expect(h.native.position, Duration.zero);
    });
  });

  group('signing out', () {
    test('stops playback and empties the queue', () async {
      final h = await PlayerHarness.start();
      await h.player.playTracks(tracks(3));
      await settle();

      h.auth.signOut();
      await settle();

      expect(h.state.queue, isEmpty);
      expect(h.state.isPlaying, isFalse);
      expect(h.platform.players.every((p) => !p.playing), isTrue);
    });

    test(
      'an expired session keeps the stored queue for the next sign-in',
      () async {
        final h = await PlayerHarness.start();
        await h.player.playTracks(tracks(3), startIndex: 1);
        await settle();
        final prefs = await SharedPreferences.getInstance();

        // Automatic logout does not wipe the stored queue.
        h.auth.signOut();
        await settle();
        expect(h.state.queue, isEmpty);
        expect(prefs.getString('player_queue'), isNotNull);

        h.auth.signIn();
        await settle();

        expect(h.queueIds, [1, 2, 3]);
        expect(h.state.currentTrack?.id, 2);
        expect(h.state.isPlaying, isFalse);
      },
    );
  });

  group('radio', () {
    setUp(() {
      PlayerNotifier.radioFetchInterval = const Duration(milliseconds: 20);
      addTearDown(() {
        PlayerNotifier.radioFetchInterval = const Duration(seconds: 4);
      });
    });

    /// Real time for a few radio ticks.
    Future<void> radioTicks() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await settle();
    }

    /// Waits (generously, for slow CI machines) until the radio timer has
    /// brought [condition] about.
    Future<void> eventually(bool Function() condition) async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!condition() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await settle();
    }

    for (final gapless in [true, false]) {
      final mode = gapless ? 'gapless' : 'single source';

      test('$mode: keeps a track queued ahead', () async {
        final h = await PlayerHarness.start(gapless: gapless);
        h.api.radioTracks.addAll(tracks(3));

        await h.player.startRadio(7);
        await eventually(() => h.state.queue.length >= 2);
        await radioTicks();

        expect(h.queueIds, [1, 2], reason: 'one ahead, not the whole radio');
        expect(h.state.currentTrack?.id, 1);
        expect(h.state.isPlaying, isTrue);
        expect(h.state.loadingRadioId, isNull);
      });

      test('$mode: carries on once a late track arrives', () async {
        final h = await PlayerHarness.start(gapless: gapless);
        h.api.radioTracks.add(track(1));
        await h.player.startRadio(7);
        await radioTicks();
        expect(h.queueIds, [1], reason: 'the server had nothing more yet');

        // The only track ends before the next one could be fetched.
        h.native.finishPlaylist();
        await settle();
        expect(h.state.isPlaying, isFalse);
        expect(h.state.queueCompleted, isFalse, reason: 'a radio never ends');

        h.api.radioTracks.add(track(2));
        await eventually(
          () => h.state.currentTrack?.id == 2 && h.state.isPlaying,
        );

        expect(h.state.currentTrack?.id, 2);
        expect(h.state.isPlaying, isTrue);
        expect(h.native.currentTrackId, 2);
        expect(h.native.playing, isTrue);
      });

      test('$mode: stays put when the user paused', () async {
        final h = await PlayerHarness.start(gapless: gapless);
        h.api.radioTracks.add(track(1));
        await h.player.startRadio(7);
        await radioTicks();
        await h.player.pause();
        h.native.finishPlaylist();
        await settle();

        h.api.radioTracks.add(track(2));
        await eventually(() => h.state.queue.length == 2);
        await radioTicks();

        expect(h.queueIds, [1, 2]);
        expect(h.state.currentTrack?.id, 1);
        expect(h.state.isPlaying, isFalse);
        expect(h.native.playing, isFalse);
      });
    }

    test('a track answered after the radio stopped is not queued', () async {
      final h = await PlayerHarness.start();
      h.api.radioTracks.add(track(1));
      await h.player.startRadio(7);
      await settle();

      // The top-up request is in flight when the user starts an album.
      final answering = Completer<void>();
      h.api.radioGate = answering;
      await radioTicks();
      await h.player.playTracks(tracks(3, from: 10));
      await settle();

      h.api.radioTracks.add(track(2));
      h.api.radioGate = null;
      answering.complete();
      await radioTicks();

      expect(h.queueIds, [10, 11, 12]);
      h.expectPlaylistMirrorsQueue();
    });
  });

  group('giving up on a load', () {
    test('cancelling is a pause: a network change does not retry it', () async {
      final h = await PlayerHarness.start(gapless: false);
      await h.player.playTracks(tracks(2));
      await settle();

      // The next track hangs while loading and the user taps the spinner.
      h.platform.onPlayerCreated = null;
      final gate = Completer<void>();
      h.native.loadGate = gate;
      final skipping = h.player.skipNext();
      await settle();
      expect(h.state.isLoading, isTrue);

      h.player.cancelOrRetryLoad();
      await settle();
      expect(h.state.isLoading, isFalse);
      expect(h.state.isPlaying, isFalse);

      h.native.loadGate = null;
      gate.complete();
      await skipping;
      await settle();
      final loads = h.native.calls.where((c) => c == 'load').length;

      h.connectivity.add([ConnectivityResult.none]);
      await settle();
      h.connectivity.add([ConnectivityResult.wifi]);
      await settle();

      expect(h.native.calls.where((c) => c == 'load').length, loads);
      expect(h.state.isPlaying, isFalse);
      expect(h.native.playing, isFalse);

      // Play is still the way back in.
      await h.player.play();
      await settle();
      expect(h.state.currentTrack?.id, 2);
      expect(h.state.isPlaying, isTrue);
    });
  });
}
