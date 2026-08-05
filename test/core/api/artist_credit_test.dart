import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/api/models.dart';

void main() {
  group('joinArtistCredits', () {
    test('joins with joinphrase', () {
      final credits = [
        ArtistCredit(
          artist: const Artist(id: 1, name: 'Primary'),
          credit: 'Primary',
          joinphrase: ' feat. ',
          index: 0,
        ),
        ArtistCredit(
          artist: const Artist(id: 2, name: 'Guest'),
          credit: 'Guest',
          joinphrase: '',
          index: 1,
        ),
      ];
      expect(joinArtistCredits(credits), 'Primary feat. Guest');
    });

    test('empty list returns Unknown Artist', () {
      expect(joinArtistCredits(const []), 'Unknown Artist');
    });
  });

  group('Track.fromJson artist_credit', () {
    test('parses credits and sets primary artist', () {
      final track = Track.fromJson({
        'id': 9,
        'title': 'Song',
        'artist_credit': [
          {
            'credit': 'A',
            'joinphrase': ' & ',
            'index': 0,
            'artist': {'id': 1, 'name': 'A'},
          },
          {
            'credit': 'B',
            'joinphrase': '',
            'index': 1,
            'artist': {'id': 2, 'name': 'B'},
          },
        ],
      });
      expect(track.artist?.id, 1);
      expect(track.artistName, 'A & B');
      expect(track.artistCredit.length, 2);
    });

    test('falls back to legacy artist object', () {
      final track = Track.fromJson({
        'id': 1,
        'title': 'Old',
        'artist': {'id': 5, 'name': 'Solo'},
      });
      expect(track.artistName, 'Solo');
      expect(track.artistCredit, isEmpty);
    });
  });
}
