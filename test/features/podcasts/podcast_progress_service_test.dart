import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/features/podcasts/podcast_progress_service.dart';

void main() {
  group('PodcastProgressService.chunkItems', () {
    test('chunks at size 500', () {
      final items = List.generate(1200, (i) => i);
      final chunks = PodcastProgressService.chunkItems(items, 500);
      expect(chunks, hasLength(3));
      expect(chunks[0], hasLength(500));
      expect(chunks[1], hasLength(500));
      expect(chunks[2], hasLength(200));
    });

    test('empty list yields no chunks', () {
      expect(PodcastProgressService.chunkItems(<int>[], 500), isEmpty);
    });
  });

  group('PodcastProgressService memory LWW', () {
    late PodcastProgressService svc;

    setUp(() {
      svc = PodcastProgressService.memoryOnly();
    });

    test('applyRemoteLww applies when local empty', () async {
      final applied = await svc.applyRemoteLww(
        trackId: 1,
        channelUuid: 'ch-1',
        positionMs: 10000,
        durationMs: 60000,
        completed: false,
        updatedAt: DateTime.utc(2026, 1, 2),
      );
      expect(applied, isTrue);
      final p = await svc.getProgress(1);
      expect(p?.positionMs, 10000);
      expect(p?.channelUuid, 'ch-1');
    });

    test('applyRemoteLww keeps equal-or-newer local', () async {
      await svc.upsertPosition(trackId: 2, positionMs: 5000, durationMs: 10000);
      final local = await svc.getProgress(2);
      expect(local, isNotNull);

      final applied = await svc.applyRemoteLww(
        trackId: 2,
        positionMs: 1000,
        completed: false,
        // Older than local (local is ~now)
        updatedAt: DateTime.utc(2020, 1, 1),
      );
      expect(applied, isFalse);
      final after = await svc.getProgress(2);
      expect(after?.positionMs, 5000);
    });

    test('applyRemoteLww replaces older local', () async {
      await svc.applyRemoteLww(
        trackId: 3,
        positionMs: 100,
        completed: false,
        updatedAt: DateTime.utc(2020, 1, 1),
      );
      final applied = await svc.applyRemoteLww(
        trackId: 3,
        positionMs: 9999,
        completed: true,
        updatedAt: DateTime.utc(2026, 6, 1),
      );
      expect(applied, isTrue);
      final p = await svc.getProgress(3);
      expect(p?.positionMs, 9999);
      expect(p?.completed, isTrue);
    });

    test('upsertPosition preserves channelUuid when omitted', () async {
      await svc.upsertPosition(
        trackId: 4,
        channelUuid: 'channel-a',
        positionMs: 1000,
        durationMs: 5000,
      );
      await svc.upsertPosition(trackId: 4, positionMs: 2000, durationMs: 5000);
      final p = await svc.getProgress(4);
      expect(p?.channelUuid, 'channel-a');
      expect(p?.positionMs, 2000);
    });

    test('toBulkItems wire format', () async {
      await svc.applyRemoteLww(
        trackId: 9,
        channelUuid: 'ch',
        positionMs: 12,
        durationMs: 100,
        completed: false,
        updatedAt: DateTime.utc(2026, 3, 1, 12),
      );
      final all = await svc.getAllProgress();
      final items = svc.toBulkItems(all.values, sourceDevice: 'dev');
      expect(items, hasLength(1));
      expect(items.single['track'], 9);
      expect(items.single['position_ms'], 12);
      expect(items.single['duration_ms'], 100);
      expect(items.single['completed'], isFalse);
      expect(items.single['channel_uuid'], 'ch');
      expect(items.single['source_device'], 'dev');
      expect(items.single['updated_at'], '2026-03-01T12:00:00.000Z');
    });
  });
}
