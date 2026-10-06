import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/cache/audio_cache_service.dart';
import 'package:tayra/core/cache/cache_manager.dart';

void main() {
  final service = AudioCacheService(CacheManager.instance);
  tearDownAll(service.dispose);

  test('the key is a SHA-1 of path and query', () {
    // A content hash is the same on every platform and Dart release, which
    // String.hashCode (the old key) does not promise.
    const url = 'https://pod.example/media/attachments/ab/cd/cover.jpg';
    final expected = sha1.convert(
      utf8.encode('/media/attachments/ab/cd/cover.jpg'),
    );

    expect(service.coverCacheKey(url), 'cover_$expected');
    expect(
      service.coverCacheKey(url),
      matches(RegExp(r'^cover_[0-9a-f]{40}$')),
    );
  });

  test('the host does not matter, the path and query do', () {
    final a = service.coverCacheKey('https://pod.example/media/a/cover.jpg');

    expect(service.coverCacheKey('http://other.host/media/a/cover.jpg'), a);
    expect(
      service.coverCacheKey('https://pod.example/media/b/cover.jpg'),
      isNot(a),
    );
    expect(
      service.coverCacheKey('https://pod.example/media/a/cover.jpg?size=200'),
      isNot(a),
    );
    expect(
      service.coverCacheKey('https://pod.example/media/a/cover.jpg?size=600'),
      isNot(
        service.coverCacheKey('https://pod.example/media/a/cover.jpg?size=200'),
      ),
    );
  });

  test('many covers get distinct keys', () {
    final keys = <String>{
      for (var i = 0; i < 20000; i++)
        service.coverCacheKey('https://pod.example/media/att/$i/cover.jpg'),
    };
    expect(keys, hasLength(20000));
  });

  test('covers cached under the old key format can still be found', () {
    const url = 'https://pod.example/media/a/cover.jpg?size=200';
    final legacy = service.legacyCoverCacheKey(url);

    expect(legacy, startsWith('cover_'));
    expect(legacy, isNot(service.coverCacheKey(url)));
    expect(
      legacy,
      'cover_${'/media/a/cover.jpg?size=200'.hashCode.toRadixString(16)}',
    );
  });
}
