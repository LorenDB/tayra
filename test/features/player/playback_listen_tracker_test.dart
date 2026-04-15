import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/features/player/playback_listen_tracker.dart';

void main() {
  group('PlaybackListenTracker', () {
    test(
      'pause and resume updates one row instead of splitting listens',
      () async {
        final inserts = <_InsertCall>[];
        final updates = <_UpdateCall>[];

        final tracker = PlaybackListenTracker(
          persistIntervalSeconds: 1,
          insertListenRecord: (
            track, {
            required listenedSeconds,
            required listenedAt,
          }) async {
            inserts.add(
              _InsertCall(
                trackId: track.id,
                listenedSeconds: listenedSeconds,
                listenedAt: listenedAt,
              ),
            );
            return 41;
          },
          updateListenRecord: (id, listenedSeconds) async {
            updates.add(_UpdateCall(id: id, listenedSeconds: listenedSeconds));
          },
        );

        final track = _track(id: 1, duration: 300);
        await tracker.activate(track, isPlaying: true);
        await tracker.updatePosition(const Duration(seconds: 3));
        await tracker.setPlaying(false, position: const Duration(seconds: 3));
        await tracker.setPlaying(true, position: const Duration(seconds: 3));
        await tracker.updatePosition(const Duration(seconds: 8));
        await tracker.finalize(position: const Duration(seconds: 8));

        expect(inserts, hasLength(1));
        expect(inserts.single.trackId, 1);
        expect(inserts.single.listenedSeconds, 3);
        expect(updates, [_UpdateCall(id: 41, listenedSeconds: 8)]);
      },
    );

    test('forward seek does not count skipped audio', () async {
      final inserts = <_InsertCall>[];
      final updates = <_UpdateCall>[];

      final tracker = PlaybackListenTracker(
        persistIntervalSeconds: 1,
        insertListenRecord: (
          track, {
          required listenedSeconds,
          required listenedAt,
        }) async {
          inserts.add(
            _InsertCall(
              trackId: track.id,
              listenedSeconds: listenedSeconds,
              listenedAt: listenedAt,
            ),
          );
          return 7;
        },
        updateListenRecord: (id, listenedSeconds) async {
          updates.add(_UpdateCall(id: id, listenedSeconds: listenedSeconds));
        },
      );

      await tracker.activate(_track(id: 2, duration: 300), isPlaying: true);
      await tracker.updatePosition(const Duration(seconds: 10));
      await tracker.handleSeek(
        previousPosition: const Duration(seconds: 10),
        newPosition: const Duration(seconds: 90),
      );
      await tracker.updatePosition(const Duration(seconds: 95));
      await tracker.finalize(position: const Duration(seconds: 95));

      expect(inserts, hasLength(1));
      expect(inserts.single.listenedSeconds, 10);
      expect(updates, [_UpdateCall(id: 7, listenedSeconds: 15)]);
    });

    test(
      'switching tracks finalizes the first session and starts a new row',
      () async {
        final inserts = <_InsertCall>[];
        final updates = <_UpdateCall>[];
        var nextId = 100;

        final tracker = PlaybackListenTracker(
          persistIntervalSeconds: 1,
          insertListenRecord: (
            track, {
            required listenedSeconds,
            required listenedAt,
          }) async {
            inserts.add(
              _InsertCall(
                trackId: track.id,
                listenedSeconds: listenedSeconds,
                listenedAt: listenedAt,
              ),
            );
            return nextId++;
          },
          updateListenRecord: (id, listenedSeconds) async {
            updates.add(_UpdateCall(id: id, listenedSeconds: listenedSeconds));
          },
        );

        await tracker.activate(_track(id: 10, duration: 200), isPlaying: true);
        await tracker.updatePosition(const Duration(seconds: 4));
        await tracker.activate(_track(id: 11, duration: 250), isPlaying: true);
        await tracker.updatePosition(const Duration(seconds: 6));
        await tracker.finalize(position: const Duration(seconds: 6));

        expect(inserts, [
          isA<_InsertCall>()
              .having((c) => c.trackId, 'trackId', 10)
              .having((c) => c.listenedSeconds, 'listenedSeconds', 4),
          isA<_InsertCall>()
              .having((c) => c.trackId, 'trackId', 11)
              .having((c) => c.listenedSeconds, 'listenedSeconds', 6),
        ]);
        expect(updates, isEmpty);
      },
    );
  });
}

Track _track({required int id, required int duration}) {
  return Track(
    id: id,
    title: 'Track $id',
    artist: Artist(id: id, name: 'Artist $id'),
    album: Album(id: id, title: 'Album $id'),
    listenUrl: 'https://example.com/$id',
    uploads: [Upload(uuid: 'upload-$id', duration: duration)],
  );
}

class _InsertCall {
  const _InsertCall({
    required this.trackId,
    required this.listenedSeconds,
    required this.listenedAt,
  });

  final int trackId;
  final int listenedSeconds;
  final DateTime listenedAt;
}

class _UpdateCall {
  const _UpdateCall({required this.id, required this.listenedSeconds});

  final int id;
  final int listenedSeconds;

  @override
  bool operator ==(Object other) {
    return other is _UpdateCall &&
        other.id == id &&
        other.listenedSeconds == listenedSeconds;
  }

  @override
  int get hashCode => Object.hash(id, listenedSeconds);
}
