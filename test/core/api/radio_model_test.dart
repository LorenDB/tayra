import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/api/models.dart';

void main() {
  group('Radio.fromJson config', () {
    test('parses filter list config', () {
      final radio = Radio.fromJson({
        'id': 42,
        'name': 'Indie mix',
        'is_public': true,
        'description': 'Cool stuff',
        'user': {'id': 7, 'username': 'alice'},
        'config': [
          {
            'type': 'artist',
            'ids': [1, 2],
            'names': ['A', 'B'],
          },
          {
            'type': 'tag',
            'names': ['indie'],
            'not': true,
          },
        ],
      });

      expect(radio.id, 42);
      expect(radio.isCustom, isTrue);
      expect(radio.config, isNotNull);
      expect(radio.config, hasLength(2));
      expect(radio.config![0]['type'], 'artist');
      expect(radio.config![0]['ids'], [1, 2]);
      expect(radio.config![1]['type'], 'tag');
      expect(radio.config![1]['not'], isTrue);
    });

    test('accepts single map config defensively', () {
      final radio = Radio.fromJson({
        'id': 1,
        'name': 'Solo',
        'config': {
          'type': 'tag',
          'names': ['rock'],
        },
      });

      expect(radio.config, hasLength(1));
      expect(radio.config!.first['type'], 'tag');
    });

    test('null config when missing', () {
      final radio = Radio.fromJson({'id': 1, 'name': 'Empty'});
      expect(radio.config, isNull);
      expect(radio.isCustom, isFalse);
    });
  });

  group('RadioFilterValidation.fromJson', () {
    test('parses candidates and errors', () {
      final v = RadioFilterValidation.fromJson({
        'errors': ['No artist matching ids'],
        'candidates': {
          'count': null,
          'sample': null,
        },
      });
      expect(v.isValid, isFalse);
      expect(v.errors, isNotEmpty);
      expect(v.candidateCount, isNull);
    });

    test('parses sample tracks', () {
      final v = RadioFilterValidation.fromJson({
        'errors': [],
        'candidates': {
          'count': 2,
          'sample': [
            {'id': 10, 'title': 'Song A', 'artist': null, 'album': null},
            {'id': 11, 'title': 'Song B', 'artist': null, 'album': null},
          ],
        },
      });
      expect(v.isValid, isTrue);
      expect(v.candidateCount, 2);
      expect(v.sample, hasLength(2));
      expect(v.sample.first.title, 'Song A');
    });
  });
}
