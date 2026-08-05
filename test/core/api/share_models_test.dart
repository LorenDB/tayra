import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/api/models.dart';

void main() {
  group('ShareLink.fromJson', () {
    test('parses owner share payload', () {
      final link = ShareLink.fromJson({
        'uuid': '11111111-1111-1111-1111-111111111111',
        'token': 'secret-token-value',
        'url': 'http://example.com/share/secret-token-value',
        'object_type': 'album',
        'object_id': 42,
        'label': 'friends',
        'creation_date': '2026-01-01T00:00:00Z',
        'expiration_date': null,
      });
      expect(link.uuid, '11111111-1111-1111-1111-111111111111');
      expect(link.token, 'secret-token-value');
      expect(link.objectType, 'album');
      expect(link.objectId, 42);
      expect(link.label, 'friends');
      expect(link.isExpired, isFalse);
      expect(link.url, contains('/share/'));
    });

    test('isExpired when past expiration', () {
      final link = ShareLink.fromJson({
        'uuid': '11111111-1111-1111-1111-111111111111',
        'token': 't',
        'url': 'http://example.com/share/t',
        'object_type': 'playlist',
        'object_id': 1,
        'expiration_date': '2020-01-01T00:00:00Z',
      });
      expect(link.isExpired, isTrue);
    });
  });

  group('PublicShare.fromJson', () {
    test('parses album share with tracks', () {
      final share = PublicShare.fromJson({
        'object_type': 'album',
        'object_id': 7,
        'expiration_date': null,
        'item': {
          'id': 7,
          'title': 'Test Album',
          'artist': {'id': 1, 'name': 'Artist'},
          'cover': null,
          'tracks_count': 1,
        },
        'tracks': [
          {
            'id': 99,
            'title': 'Track One',
            'position': 1,
            'disc_number': 1,
            'listen_url': '/api/v1/listen/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/',
            'is_playable': true,
            'artist': {'id': 1, 'name': 'Artist'},
            'album': {'id': 7, 'title': 'Test Album'},
            'uploads': [
              {
                'uuid': 'u1',
                'duration': 180,
              }
            ],
          },
        ],
      });
      expect(share.objectType, 'album');
      expect(share.objectId, 7);
      expect(share.title, 'Test Album');
      expect(share.subtitle, 'Artist');
      expect(share.tracks, hasLength(1));
      expect(share.tracks.first.listenUrl, contains('/listen/'));
      expect(share.tracks.first.duration, 180);
    });

    test('parses playlist share', () {
      final share = PublicShare.fromJson({
        'object_type': 'playlist',
        'object_id': 3,
        'item': {
          'id': 3,
          'name': 'My Mix',
          'tracks_count': 0,
        },
        'tracks': [],
      });
      expect(share.title, 'My Mix');
      expect(share.subtitle, 'Playlist');
      expect(share.album, isNull);
      expect(share.playlist, isNotNull);
    });
  });
}
