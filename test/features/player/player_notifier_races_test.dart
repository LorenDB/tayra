import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import 'package:tayra/core/api/models.dart';

import 'player_harness.dart';

/// Scenarios where requests overlap or a load goes wrong.
void main() {
  group('gapless playback', () {
    test('follows the player into the next track', () async {
      final h = await PlayerHarness.start();
      await h.player.playTracks(tracks(4));
      await settle();

      h.native.advanceToNextItem();
      await settle();

      expect(h.state.currentTrack?.id, 2);
      expect(h.handler.mediaItem.value?.id, '2');
      expect(h.state.isPlaying, isTrue);
      h.expectPlaylistMirrorsQueue();
    });

    test('next on the last track wraps around under repeat-all', () async {
      final h = await PlayerHarness.start();
      await h.player.playTracks(tracks(3), startIndex: 2);
      await settle();
      h.player.toggleLoopMode(); // off → all
      await settle();
      expect(h.state.loopMode, LoopMode.all);

      await h.player.skipNext();
      await settle();

      expect(h.state.currentTrack?.id, 1);
      expect(h.state.isPlaying, isTrue);
      h.expectPlaylistMirrorsQueue();

      await h.player.skipPrevious();
      await settle();
      expect(h.state.currentTrack?.id, 3);
      h.expectPlaylistMirrorsQueue();
    });

    test('next on the last track without repeat does nothing', () async {
      final h = await PlayerHarness.start();
      await h.player.playTracks(tracks(2), startIndex: 1);
      await settle();

      await h.player.skipNext();
      await settle();

      expect(h.state.currentTrack?.id, 2);
      expect(h.state.isPlaying, isTrue);
      expect(h.state.isLoading, isFalse);
      h.expectPlaylistMirrorsQueue();
    });

    test('shuffle play starts a shuffled queue the player mirrors', () async {
      final h = await PlayerHarness.start();

      await h.player.playTracks(tracks(30), startIndex: 7, shuffle: true);
      await settle(40);

      expect(h.state.isShuffled, isTrue);
      expect(h.state.currentTrack?.id, 8, reason: 'the tapped track leads');
      expect(h.queueIds.toSet(), {for (var i = 1; i <= 30; i++) i});
      expect(h.state.unshuffledQueue.map((t) => t.id), [
        for (var i = 1; i <= 30; i++) i,
      ]);
      h.expectPlaylistMirrorsQueue();
    });

    test('jumping past what has been appended so far still lands', () async {
      final h = await PlayerHarness.start();
      final appending = Completer<void>();
      h.platform.onPlayerCreated = (native) => native.insertGate = appending;
      await h.player.playTracks(tracks(60));
      await settle();
      expect(h.native.trackIds, hasLength(3));

      // Row 40 is not in the native playlist yet.
      final jumping = h.player.jumpTo(40);
      await settle();
      for (final native in h.platform.players) {
        native.insertGate = null;
      }
      appending.complete();
      await jumping;
      await settle(60);

      expect(h.state.currentTrack?.id, 41);
      expect(h.state.isPlaying, isTrue);
      h.expectPlaylistMirrorsQueue();
    });

    test('removing the current track mid-append stays consistent', () async {
      final h = await PlayerHarness.start();
      final appending = Completer<void>();
      h.platform.onPlayerCreated = (native) => native.insertGate = appending;
      await h.player.playTracks(tracks(50));
      await settle();

      h.player.removeFromQueue(0);
      h.player.addToQueue([track(900)]);
      await settle();
      h.native.insertGate = null;
      appending.complete();
      await settle(60);

      expect(h.queueIds.first, 2);
      expect(h.queueIds.last, 900);
      expect(h.state.currentTrack?.id, 2);
      expect(h.state.isPlaying, isTrue);
      h.expectPlaylistMirrorsQueue();
    });
  });

  group('overlapping requests', () {
    for (final gapless in [true, false]) {
      final mode = gapless ? 'gapless' : 'single source';

      test('$mode: the later of two queues wins', () async {
        final h = await PlayerHarness.start(gapless: gapless);

        final first = h.player.playTracks(tracks(5));
        final second = h.player.playTracks(tracks(5, from: 100), startIndex: 2);
        await Future.wait([first, second]);
        await settle(30);

        expect(h.queueIds, [100, 101, 102, 103, 104]);
        expect(h.state.currentTrack?.id, 102);
        expect(h.native.currentTrackId, 102);
        expect(h.state.isPlaying, isTrue);
        expect(h.state.isLoading, isFalse);
        if (gapless) h.expectPlaylistMirrorsQueue();
      });

      test('$mode: a new queue during a slow load replaces it', () async {
        final h = await PlayerHarness.start(gapless: gapless);
        await h.player.playTracks(tracks(3));
        await settle();

        final slow = Completer<void>();
        h.native.loadGate = slow;
        final first = h.player.playTracks(tracks(3, from: 50));
        await settle();
        expect(h.state.isLoading, isTrue);

        h.native.loadGate = null;
        final second = h.player.playTracks(tracks(3, from: 70), startIndex: 1);
        slow.complete();
        await Future.wait([first, second]);
        await settle(30);

        expect(h.queueIds, [70, 71, 72]);
        expect(h.state.currentTrack?.id, 71);
        expect(h.native.currentTrackId, 71);
        expect(h.state.isPlaying, isTrue);
        expect(h.state.isLoading, isFalse);
      });

      test('$mode: clearing the queue during a load leaves nothing', () async {
        final h = await PlayerHarness.start(gapless: gapless);
        await h.player.playTracks(tracks(3));
        await settle();

        final slow = Completer<void>();
        h.native.loadGate = slow;
        final loading = h.player.playTracks(tracks(3, from: 50));
        await settle();
        final clearing = h.player.playTracks(const []);
        for (final native in h.platform.players) {
          native.loadGate = null;
        }
        slow.complete();
        await Future.wait([loading, clearing]);
        await settle(30);

        expect(h.state.queue, isEmpty);
        expect(h.state.isPlaying, isFalse);
        expect(h.state.isLoading, isFalse);
        expect(h.platform.players.every((p) => !p.playing), isTrue);
      });
    }
  });

  group('a track that will not load', () {
    test('single source: playback stops there and play retries', () async {
      final h = await PlayerHarness.start(gapless: false);
      await h.player.playTracks(tracks(3));
      await settle();
      h.native.failingTrackIds.add(2);

      await h.player.skipNext();
      await settle();

      expect(h.state.currentTrack?.id, 2, reason: 'no silent skip past it');
      expect(h.state.isPlaying, isFalse);
      expect(h.state.isLoading, isFalse);

      // The stream recovers; play tries the same track again.
      for (final native in h.platform.players) {
        native.failingTrackIds.clear();
      }
      await h.player.play();
      await settle();

      expect(h.native.currentTrackId, 2);
      expect(h.state.isPlaying, isTrue);
    });

    test('single source: removing it carries on with the next track', () async {
      final h = await PlayerHarness.start(gapless: false);
      h.platform.onPlayerCreated = (native) {
        native.failingTrackIds.add(2);
      };
      await h.player.playTracks(tracks(3));
      await settle();
      h.native.failingTrackIds.add(2);
      await h.player.skipNext();
      await settle();
      expect(h.state.isPlaying, isFalse);

      // The user was listening; dropping the broken track should not leave
      // them in silence.
      h.player.removeFromQueue(1);
      await settle();

      expect(h.queueIds, [1, 3]);
      expect(h.state.currentTrack?.id, 3);
      expect(h.native.currentTrackId, 3);
      expect(h.state.isPlaying, isTrue);
    });

    test('single source: the network coming back retries it once', () async {
      final h = await PlayerHarness.start(gapless: false);
      h.platform.onPlayerCreated = (native) {
        native.failingTrackIds.add(2);
      };
      await h.player.playTracks(tracks(3));
      await settle();
      h.native.failingTrackIds.add(2);
      await h.player.skipNext();
      await settle();
      expect(h.state.isPlaying, isFalse);

      h.connectivity.add([ConnectivityResult.none]);
      await settle();
      h.platform.onPlayerCreated = null;
      for (final native in h.platform.players) {
        native.failingTrackIds.clear();
      }
      h.connectivity.add([ConnectivityResult.wifi]);
      await settle(30);

      expect(h.state.currentTrack?.id, 2);
      expect(h.native.currentTrackId, 2);
      expect(h.state.isPlaying, isTrue);
    });
  });

  group('external controls', () {
    test('stop from the system is not undone by a network change', () async {
      final h = await PlayerHarness.start(gapless: false);
      await h.player.playTracks(tracks(2));
      await settle();

      await h.handler.stop();
      await settle();
      expect(h.state.isPlaying, isFalse);
      final players = h.platform.players.length;

      h.connectivity.add([ConnectivityResult.none]);
      await settle();
      h.connectivity.add([ConnectivityResult.wifi]);
      await settle(30);

      expect(h.state.isPlaying, isFalse);
      expect(h.platform.players, hasLength(players));
      expect(h.platform.players.every((p) => !p.playing), isTrue);
    });

    test('play with nothing queued is ignored', () async {
      final h = await PlayerHarness.start();

      await h.handler.play();
      await settle();

      expect(h.state.isPlaying, isFalse);
      expect(h.audio.playing, isFalse);
    });
  });

  group('restored podcast', () {
    Track episode(int id) {
      return Track.fromJson({
        'id': id,
        'title': 'Episode $id',
        'listen_url': '/api/v1/listen/$id/',
        'artist': {'id': 9, 'name': 'Show', 'content_category': 'podcast'},
        'uploads': [
          {'uuid': 'u$id', 'duration': 3600},
        ],
      });
    }

    test('skip-back and skip-ahead move from the saved position', () async {
      final h = await PlayerHarness.start(
        prefs: {
          'player_queue': jsonEncode([episode(1).toPersistenceJson()]),
          'player_current_index': 0,
          'player_position': 1200000,
          'player_duration': 3600000,
        },
      );
      expect(h.state.currentTrack?.isPodcast, isTrue);
      expect(h.state.position, const Duration(minutes: 20));

      await h.player.seekBy(const Duration(seconds: 30));
      expect(h.state.position, const Duration(minutes: 20, seconds: 30));

      await h.player.seekBy(const Duration(seconds: -10));
      expect(h.state.position, const Duration(minutes: 20, seconds: 20));

      await h.player.play();
      await settle();
      expect(h.native.position, const Duration(minutes: 20, seconds: 20));
      expect(h.state.isPlaying, isTrue);
    });
  });
}
