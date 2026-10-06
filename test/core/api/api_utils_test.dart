import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/api/api_client.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/models.dart';

void main() {
  group('formatTrackDuration', () {
    test('minutes and seconds below an hour', () {
      expect(formatTrackDuration(0), '0:00');
      expect(formatTrackDuration(7), '0:07');
      expect(formatTrackDuration(187), '3:07');
      expect(formatTrackDuration(3599), '59:59');
    });

    test('hours from one hour up', () {
      expect(formatTrackDuration(3600), '1:00:00');
      expect(formatTrackDuration(4503), '1:15:03');
      expect(formatTrackDuration(36000 + 61), '10:01:01');
    });

    test('never negative', () {
      expect(formatTrackDuration(-5), '0:00');
    });
  });

  test('formatTotalDuration switches to hours', () {
    expect(formatTotalDuration(59), '0 min');
    expect(formatTotalDuration(45 * 60), '45 min');
    expect(formatTotalDuration(3600 + 12 * 60), '1h 12m');
  });

  test('pluralizeTrack', () {
    expect(pluralizeTrack(0), '0 tracks');
    expect(pluralizeTrack(1), '1 track');
    expect(pluralizeTrack(2), '2 tracks');
  });

  test('formatDecimalMegabytes uses 1000 MB to the GB', () {
    expect(formatDecimalMegabytes(750), '750 MB');
    expect(formatDecimalMegabytes(1000), '1.0 GB');
    expect(formatDecimalMegabytes(2500), '2.5 GB');
  });

  test('sortTracksByDiscAndPosition orders by disc, then position', () {
    Track t(int id, {int? disc, int? position}) =>
        Track(id: id, title: '$id', discNumber: disc, position: position);
    final list = [
      t(1, disc: 2, position: 1),
      t(2, disc: 1, position: 2),
      t(3, position: 1),
      t(4, disc: 2),
    ];

    sortTracksByDiscAndPosition(list);

    expect(list.map((e) => e.id), [3, 2, 4, 1]);
  });

  test('fetchAllPages follows next links to the end', () async {
    final requested = <int>[];
    final all = await fetchAllPages<int>((page) async {
      requested.add(page);
      return PaginatedResponse<int>(
        count: 5,
        next: page < 3 ? 'next' : null,
        results: page < 3 ? [page * 10, page * 10 + 1] : [page * 10],
      );
    });

    expect(requested, [1, 2, 3]);
    expect(all, [10, 11, 20, 21, 30]);
  });

  test(
    'fetchAllPages stops on an empty page that still claims a next',
    () async {
      var calls = 0;
      final all = await fetchAllPages<int>((page) async {
        calls++;
        return PaginatedResponse<int>(
          count: 2,
          next: 'next',
          results: page == 1 ? [1, 2] : const [],
        );
      });

      expect(all, [1, 2]);
      expect(calls, 2);
    },
  );
}
