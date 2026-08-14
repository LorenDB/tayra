import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tayra/features/player/playback_errors.dart';

void main() {
  group('isPlayInterruptedError', () {
    test('accepts PlayerInterruptedException', () {
      expect(
        isPlayInterruptedError(
          PlayerInterruptedException('Loading interrupted'),
        ),
        isTrue,
      );
    });

    test('accepts Chrome play() AbortError variants', () {
      expect(
        isPlayInterruptedError(
          Exception(
            'AbortError: The play() request was interrupted because '
            'the media was removed from the document.',
          ),
        ),
        isTrue,
      );
      expect(
        isPlayInterruptedError(
          Exception(
            'AbortError: The play() request was interrupted by a new load request.',
          ),
        ),
        isTrue,
      );
    });

    test('rejects unrelated load failures', () {
      expect(
        isPlayInterruptedError(Exception('Track has no listen URL')),
        isFalse,
      );
      expect(isPlayInterruptedError(Exception('HTTP 404')), isFalse);
    });
  });
}
