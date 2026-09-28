import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/widgets/cover_art.dart';

void main() {
  const urls = CoverUrls(
    original: 'https://example.test/original.jpg',
    mediumSquareCrop: 'https://example.test/200.jpg',
    largeSquareCrop: 'https://example.test/600.jpg',
    smallSquareCrop: 'https://example.test/50.jpg',
  );

  group('CoverUrls.urlForPhysicalPx', () {
    test('list tiles stay on the 200px crop', () {
      expect(urls.urlForPhysicalPx(48), 'https://example.test/200.jpg');
      expect(urls.urlForPhysicalPx(200), 'https://example.test/200.jpg');
    });

    test('larger widgets use the 600px crop instead of the thumbnail', () {
      expect(urls.urlForPhysicalPx(201), 'https://example.test/600.jpg');
      expect(urls.urlForPhysicalPx(600), 'https://example.test/600.jpg');
      expect(urls.urlForBox(160, 3), 'https://example.test/600.jpg');
    });

    test('falls through when a rendition is missing', () {
      const largeOnly = CoverUrls(
        largeSquareCrop: 'https://example.test/600.jpg',
      );
      expect(largeOnly.urlForPhysicalPx(48), 'https://example.test/600.jpg');

      const originalOnly = CoverUrls(
        original: 'https://example.test/original.jpg',
      );
      expect(
        originalOnly.urlForPhysicalPx(800),
        'https://example.test/original.jpg',
      );
    });
  });

  group('coverDecodeTarget', () {
    test('decodes thumbnail crops at their native size', () {
      final target = coverDecodeTarget(
        intrinsicWidth: 600,
        intrinsicHeight: 600,
        maxDecodePx: 144,
      );
      expect(target.width, isNull);
      expect(target.height, isNull);
    });

    test('scales a large original on one axis only', () {
      final wide = coverDecodeTarget(
        intrinsicWidth: 3000,
        intrinsicHeight: 2000,
        maxDecodePx: 512,
      );
      expect(wide.width, 512);
      expect(wide.height, isNull);

      final tall = coverDecodeTarget(
        intrinsicWidth: 2000,
        intrinsicHeight: 3000,
        maxDecodePx: 512,
      );
      expect(tall.width, isNull);
      expect(tall.height, 512);
    });
  });
}
