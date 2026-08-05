import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/audio/audio_quality.dart';

void main() {
  group('audioCacheKey', () {
    test('namespaces by quality', () {
      expect(audioCacheKey(42, AudioQuality.high), 'audio_42_q_high');
      expect(audioCacheKey(42, AudioQuality.medium), 'audio_42_q_medium');
      expect(legacyAudioCacheKey(42), 'audio_42');
    });
  });

  group('isMeteredConnectivity', () {
    test('mobile only is metered', () {
      expect(isMeteredConnectivity([ConnectivityResult.mobile]), isTrue);
    });

    test('wifi is not metered', () {
      expect(isMeteredConnectivity([ConnectivityResult.wifi]), isFalse);
    });

    test('wifi + mobile is not metered', () {
      expect(
        isMeteredConnectivity([
          ConnectivityResult.wifi,
          ConnectivityResult.mobile,
        ]),
        isFalse,
      );
    });
  });

  group('resolveStreamingQuality', () {
    test('auto unmetered native prefers original', () {
      expect(
        resolveStreamingQuality(AudioQuality.auto, onMeteredNetwork: false),
        // On pure unit tests kIsWeb is false → original when unmetered.
        AudioQuality.original,
      );
    });

    test('auto metered prefers medium', () {
      expect(
        resolveStreamingQuality(AudioQuality.auto, onMeteredNetwork: true),
        AudioQuality.medium,
      );
    });
  });

  group('ttfaMsBucket', () {
    test('buckets durations', () {
      expect(ttfaMsBucket(100), '0_250');
      expect(ttfaMsBucket(400), '250_500');
      expect(ttfaMsBucket(1500), '1000_2000');
      expect(ttfaMsBucket(12000), '10000_plus');
    });
  });
}
