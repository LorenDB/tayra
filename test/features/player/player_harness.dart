// The fake native player is installed through just_audio's platform
// interface, which the app only depends on transitively.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show AudioPlayer;
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart'
    show JustAudioPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/api/client_data_service.dart';
import 'package:tayra/core/audio/audio_quality.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/core/cache/audio_cache_service.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/features/settings/settings_provider.dart';

import '../../support/fake_audio_platform.dart';

const _server = 'https://pod.example';

/// A playable track whose stream URL carries its id, so the fake native
/// player's playlist can be read back as track ids.
Track track(int id, {int seconds = 180}) {
  return Track(
    id: id,
    title: 'Track $id',
    listenUrl: '/api/v1/listen/$id/',
    uploads: [Upload(uuid: 'upload-$id', duration: seconds)],
  );
}

List<Track> tracks(int count, {int from = 1}) => [
  for (var i = 0; i < count; i++) track(from + i),
];

/// The real [PlayerNotifier] and the real just_audio `AudioPlayer`, wired to
/// a fake native player and to stand-ins for the network and disk.
class PlayerHarness {
  PlayerHarness._(
    this.container,
    this.platform,
    this.handler,
    this.auth,
    this.api,
  );

  final ProviderContainer container;
  final FakeJustAudioPlatform platform;
  final FunkwhaleAudioHandler handler;
  final FakeAuth auth;
  final FakeApi api;
  final connectivity = StreamController<List<ConnectivityResult>>.broadcast();

  PlayerNotifier get player => container.read(playerProvider.notifier);
  PlayerState get state => container.read(playerProvider);
  FakeNativePlayer get native => platform.player;
  AudioPlayer get audio => handler.audioPlayer;

  List<int> get queueIds => state.queue.map((t) => t.id).toList();

  /// The app's queue and the native playlist agree on tracks, order and the
  /// current item.
  void expectPlaylistMirrorsQueue() {
    expect(native.trackIds, queueIds, reason: 'native playlist order');
    expect(native.index, state.currentIndex, reason: 'current index');
    expect(native.currentTrackId, state.currentTrack?.id);
  }

  static Future<PlayerHarness> start({
    bool gapless = true,
    bool signedIn = true,
    Map<String, Object> prefs = const {},
  }) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockAudioSessionChannel();
    SharedPreferences.setMockInitialValues({
      'gapless_playback': gapless,
      ...prefs,
    });

    final platform = FakeJustAudioPlatform();
    JustAudioPlatform.instance = platform;
    final handler = FunkwhaleAudioHandler();
    final auth = FakeAuth(signedIn: signedIn);
    final api = FakeApi();

    late final PlayerHarness harness;
    final container = ProviderContainer(
      overrides: [
        audioHandlerProvider.overrideWithValue(handler),
        audioCacheServiceProvider.overrideWithValue(_NoAudioCache()),
        cachedFunkwhaleApiProvider.overrideWithValue(api),
        clientDataServiceProvider.overrideWithValue(_FakeClientData()),
        authStateProvider.overrideWith(() => auth),
        connectivityResultProvider.overrideWith((ref) async* {
          yield [ConnectivityResult.wifi];
          yield* harness.connectivity.stream;
        }),
      ],
    );
    harness = PlayerHarness._(container, platform, handler, auth, api);

    addTearDown(() async {
      container.dispose();
      await harness.connectivity.close();
      await handler.audioPlayer.dispose();
    });

    // Settings load asynchronously (as they do before runApp); have them in
    // place before the notifier reads them.
    container.read(settingsProvider);
    await settle();
    // Build the notifier and keep it listened to, as main() does: Riverpod
    // pauses a provider's own subscriptions (connectivity, sign-out) while
    // nothing listens to it. Then let connectivity and the queue restore
    // settle.
    container.listen(playerProvider, (previous, next) {});
    await settle();
    return harness;
  }
}

/// Let queued microtasks, zero-delay timers and stream events run dry.
Future<void> settle([int rounds = 12]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class FakeAuth extends AuthNotifier {
  FakeAuth({required this.signedIn});

  final bool signedIn;

  @override
  AuthState build() {
    return signedIn
        ? const AuthState(serverUrl: _server, accessToken: 'access-token')
        : const AuthState();
  }

  void signOut() => state = const AuthState();

  void signIn() {
    state = const AuthState(serverUrl: _server, accessToken: 'access-token');
  }
}

class _NoAudioCache extends AudioCacheService {
  _NoAudioCache() : super(CacheManager.instance);

  @override
  Future<File?> getCachedAudio(Track track, {AudioQuality? quality}) async {
    return null;
  }

  @override
  Future<File?> cacheCoverArt(String coverUrl) async => null;

  @override
  Future<File?> cacheAudio(
    Track track,
    String streamUrl,
    Map<String, String> authHeaders, {
    AudioQuality quality = AudioQuality.high,
    void Function(int, int)? onProgress,
  }) async {
    return null;
  }
}

class FakeApi implements CachedFunkwhaleApi {
  /// Tracks the radio endpoint hands out, in order. Empty means the server
  /// has nothing to offer yet and the request fails.
  final List<Track> radioTracks = [];

  /// While set, a radio request waits on it before answering.
  Completer<void>? radioGate;

  @override
  Future<RadioSession> createRadioSession(Map<String, dynamic> body) async {
    return const RadioSession(id: 1);
  }

  @override
  Future<dynamic> postNextRadioTrackRaw(int session, {int? count}) async {
    final gate = radioGate;
    if (gate != null) await gate.future;
    if (radioTracks.isEmpty) throw StateError('No radio track available');
    return radioTracks.removeAt(0).toPersistenceJson();
  }

  @override
  Future<Track> getRadioTrack(int id) async {
    if (radioTracks.isEmpty) throw StateError('No radio track available');
    return radioTracks.removeAt(0);
  }

  @override
  Future<void> ensureStreamAuth() async {}

  @override
  Future<void> ensureListenToken({bool force = false}) async {}

  @override
  Map<String, String> get authHeaders => const {
    'Authorization': 'Bearer access-token',
  };

  @override
  String getStreamUrl(
    String listenUrl, {
    bool? appendListenToken,
    AudioQuality? quality,
    bool forDownload = false,
    String? shareToken,
  }) {
    return '$_server$listenUrl';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeClientData implements ClientDataService {
  @override
  Future<void> recordTrackStarted(Track track) async {}

  @override
  Future<void> endSession({bool forcePatch = true}) async {}

  @override
  Future<void> linkLocalListenToServer({
    required int recordId,
    required int trackId,
  }) async {}

  @override
  Future<void> syncDuration(
    int trackId,
    int durationSeconds, {
    bool force = false,
  }) async {}

  @override
  Future<void> markEpisodePlayed({
    required int trackId,
    String? channelUuid,
    int? durationMs,
  }) async {}

  @override
  Future<void> pushPlaybackProgress({
    required int trackId,
    required int positionMs,
    int? durationMs,
    bool? completed,
    String? channelUuid,
    DateTime? updatedAt,
    bool force = false,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
