import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';

void main() {
  group('YearReviewStats.fromServerJson', () {
    test('maps K14 payload fields into UI models', () {
      final stats = YearReviewStats.fromServerJson({
        'year': 2025,
        'total_listens': 4,
        'total_seconds': 150,
        'listens_with_duration': 2,
        'estimated_seconds': 850,
        'unique_tracks': 3,
        'unique_artists': 3,
        'unique_albums': 3,
        'top_tracks': [
          {
            'track_id': 1,
            'title': 'Song A',
            'artist_name': 'Artist A',
            'cover_url': 'https://example.com/a.jpg',
            'count': 2,
            'total_seconds': 150,
          },
          {
            'track_id': 2,
            'title': 'Song B',
            'artist_name': 'Artist B',
            'cover_url': null,
            'count': 1,
            'total_seconds': 0,
          },
        ],
        'top_artists': [
          {
            'artist_id': 10,
            'name': 'Artist A',
            'cover_url': null,
            'count': 2,
            'total_seconds': 150,
          },
        ],
        'top_albums': [
          {
            'album_id': 20,
            'title': 'Album A',
            'artist_name': 'Artist A',
            'cover_url': 'https://example.com/al.jpg',
            'count': 2,
            'total_seconds': 150,
          },
        ],
        'monthly': [
          {'month': 1, 'count': 2, 'total_seconds': 150},
          {'month': 3, 'count': 2, 'total_seconds': 0},
        ],
        'by_device': [
          {
            'device_uuid': '550e8400-e29b-41d4-a716-446655440000',
            'device_name': 'Pixel 8',
            'count': 2,
            'total_seconds': 150,
          },
          {
            'device_uuid': null,
            'device_name': null,
            'count': 2,
            'total_seconds': 0,
          },
        ],
      });

      expect(stats.fromServer, isTrue);
      expect(stats.year, 2025);
      expect(stats.totalListens, 4);
      expect(stats.totalSeconds, 150);
      expect(stats.listensWithDuration, 2);
      expect(stats.estimatedSeconds, 850);
      expect(stats.uniqueTracks, 3);
      expect(stats.uniqueArtists, 3);
      expect(stats.uniqueAlbums, 3);

      expect(stats.topTracks, hasLength(2));
      expect(stats.topTrack?.name, 'Song A');
      expect(stats.topTrack?.subtitle, 'Artist A');
      expect(stats.topTrack?.id, 1);
      expect(stats.topTrack?.count, 2);
      expect(stats.topTrack?.totalSeconds, 150);

      expect(stats.topArtist?.name, 'Artist A');
      expect(stats.topArtist?.id, 10);

      expect(stats.topAlbum?.name, 'Album A');
      expect(stats.topAlbum?.id, 20);
      expect(stats.topAlbum?.totalListens, 2);

      // Always 12 months; missing months are zero.
      expect(stats.monthlyBreakdown, hasLength(12));
      expect(stats.monthlyBreakdown[0].count, 2);
      expect(stats.monthlyBreakdown[0].totalSeconds, 150);
      expect(stats.monthlyBreakdown[2].count, 2);
      expect(stats.monthlyBreakdown[5].count, 0);
      expect(stats.peakMonth, 1);

      expect(stats.deviceStats, hasLength(2));
      expect(stats.deviceStats[0].displayName, 'Pixel 8');
      expect(
        stats.deviceStats[0].deviceId,
        '550e8400-e29b-41d4-a716-446655440000',
      );
      expect(stats.deviceStats[0].listenCount, 2);
      expect(stats.deviceStats[1].deviceId, 'unknown');
      expect(stats.deviceStats[1].displayName, 'Other devices');
    });

    test('empty year yields empty tops and zeroed months', () {
      final stats = YearReviewStats.fromServerJson({
        'year': 2024,
        'total_listens': 0,
        'total_seconds': 0,
        'listens_with_duration': 0,
        'estimated_seconds': 0,
        'unique_tracks': 0,
        'unique_artists': 0,
        'unique_albums': 0,
        'top_tracks': [],
        'top_artists': [],
        'top_albums': [],
        'monthly': [],
        'by_device': [],
      });

      expect(stats.isEmpty, isTrue);
      expect(stats.topTracks, isEmpty);
      expect(stats.topTrack, isNull);
      expect(stats.monthlyBreakdown, hasLength(12));
      expect(stats.deviceStats, isEmpty);
      expect(stats.fromServer, isTrue);
    });

    test('defensive parsing of partial / null fields', () {
      final stats = YearReviewStats.fromServerJson({
        'year': 2025,
        'top_tracks': [
          {'title': 'Bare'},
          'not-a-map',
        ],
        'top_artists': null,
        'top_albums': [
          {'album_id': 1, 'title': 'A', 'count': 5},
        ],
        'by_device': [
          {'device_uuid': '', 'device_name': '', 'count': 1},
        ],
      });

      expect(stats.totalListens, 0);
      expect(stats.topTracks.single.name, 'Bare');
      expect(stats.topTracks.single.count, 0);
      expect(stats.topArtists, isEmpty);
      expect(stats.topAlbums.single.totalListens, 5);
      expect(stats.deviceStats.single.deviceId, 'unknown');
      expect(stats.deviceStats.single.displayName, 'Other devices');
    });
  });
}
