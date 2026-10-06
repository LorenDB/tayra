import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/features/player/now_playing_content.dart';
import 'package:tayra/features/player/player_provider.dart';

void main() {
  test('speeds are written in their shortest form', () {
    expect(formatPlaybackSpeed(1.0), '1');
    expect(formatPlaybackSpeed(2.0), '2');
    expect(formatPlaybackSpeed(0.5), '0.5');
    expect(formatPlaybackSpeed(0.75), '0.75');
    expect(formatPlaybackSpeed(1.25), '1.25');
    expect(formatPlaybackSpeed(1.5), '1.5');
    expect(formatPlaybackSpeed(10.0), '10');
  });

  test('every preset has a clean label', () {
    for (final speed in PlayerNotifier.speedPresets) {
      final label = formatPlaybackSpeed(speed);
      expect(label, isNot(endsWith('.')), reason: '$speed');
      expect(double.parse(label), speed);
    }
  });
}
