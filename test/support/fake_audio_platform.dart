// just_audio's platform interface is only a transitive dependency of the app;
// the fake native player below is the one place that implements it.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

/// Stand-in for the native just_audio player, so the real Dart-side
/// `AudioPlayer` (playlist bookkeeping, seek and loop-mode logic, event
/// streams) can be driven from tests.
///
/// The playlist is modelled the way ExoPlayer treats it: edits shift the
/// current index, removing the current item moves on to the next one, and
/// removing it when it is the last one ends playback.
class FakeJustAudioPlatform extends JustAudioPlatform {
  /// Every native player created so far; just_audio makes a new one each
  /// time it reactivates after `stop()`.
  final List<FakeNativePlayer> players = [];

  /// Applied to each newly created native player.
  void Function(FakeNativePlayer player)? onPlayerCreated;

  /// The native player currently in use.
  FakeNativePlayer get player => players.last;

  bool get hasPlayer => players.isNotEmpty;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = FakeNativePlayer(request.id);
    players.add(player);
    onPlayerCreated?.call(player);
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    for (final player in players.where((p) => p.id == request.id)) {
      player.release();
    }
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async {
    for (final player in players) {
      player.release();
    }
    return DisposeAllPlayersResponse();
  }
}

class FakeNativePlayer extends AudioPlayerPlatform {
  FakeNativePlayer(super.id);

  final _events = StreamController<PlaybackEventMessage>.broadcast();
  final _data = StreamController<PlayerDataMessage>.broadcast();

  /// The playlist as the native side holds it.
  final List<String> uris = [];

  int? index;
  Duration position = Duration.zero;
  bool playing = false;
  bool released = false;
  ProcessingStateMessage processingState = ProcessingStateMessage.idle;
  LoopModeMessage loopMode = LoopModeMessage.off;
  Duration itemDuration = const Duration(minutes: 3);

  /// Method names in call order, for assertions on what reached the player.
  final List<String> calls = [];

  /// While set, [load] stays in the loading state until it completes.
  Completer<void>? loadGate;

  /// While set, playlist inserts wait on it before being applied, which
  /// holds a queue's tail append in mid-flight.
  Completer<void>? insertGate;

  /// A load whose playlist contains one of these tracks fails like a dead
  /// stream. Keyed by track id: just_audio rewrites stream URLs that carry
  /// request headers to go through its local proxy, so the URI itself is not
  /// what the app asked for.
  final Set<int> failingTrackIds = {};

  Completer<void>? _playCompleter;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Stream<PlayerDataMessage> get playerDataMessageStream => _data.stream;

  /// Track ids in playlist order, read off `/listen/<id>/` stream URLs and
  /// `/cache/<id>.mp3` file paths.
  List<int> get trackIds => uris.map(trackIdOf).toList();

  int? get currentTrackId =>
      index != null && index! >= 0 && index! < uris.length
          ? trackIdOf(uris[index!])
          : null;

  static int trackIdOf(String uri) {
    final match = RegExp(r'/(?:listen|cache)/(\d+)').firstMatch(uri);
    if (match == null) throw StateError('No track id in $uri');
    return int.parse(match.group(1)!);
  }

  void _emit() {
    if (_events.isClosed) return;
    _events.add(
      PlaybackEventMessage(
        processingState: processingState,
        updateTime: DateTime.now(),
        updatePosition: position,
        bufferedPosition: position,
        duration: uris.isEmpty ? null : itemDuration,
        icyMetadata: null,
        currentIndex: index,
        androidAudioSessionId: null,
      ),
    );
  }

  // ── Test controls ───────────────────────────────────────────────────

  /// The current item played to its end with nothing after it.
  void finishPlaylist() {
    position = itemDuration;
    processingState = ProcessingStateMessage.completed;
    _emit();
  }

  /// Gapless transition into the next item.
  void advanceToNextItem() {
    index = index! + 1;
    position = Duration.zero;
    processingState = ProcessingStateMessage.ready;
    _emit();
  }

  void reportBuffering() {
    processingState = ProcessingStateMessage.buffering;
    _emit();
  }

  void reportReady() {
    processingState = ProcessingStateMessage.ready;
    _emit();
  }

  void reportPosition(Duration value) {
    position = value;
    _emit();
  }

  void release() {
    released = true;
    playing = false;
    _playCompleter?.complete();
    _playCompleter = null;
  }

  // ── Platform interface ──────────────────────────────────────────────

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    calls.add('load');
    final source = request.audioSourceMessage;
    final children =
        source is ConcatenatingAudioSourceMessage
            ? source.children
            : <AudioSourceMessage>[source];
    uris
      ..clear()
      ..addAll(children.map(_uriOf));
    index = uris.isEmpty ? null : (request.initialIndex ?? 0);
    position = request.initialPosition ?? Duration.zero;
    processingState = ProcessingStateMessage.loading;
    _emit();

    final gate = loadGate;
    if (gate != null) await gate.future;

    if (trackIds.any(failingTrackIds.contains)) {
      processingState = ProcessingStateMessage.idle;
      _emit();
      throw PlatformException(code: '404', message: 'Source error');
    }

    processingState = ProcessingStateMessage.ready;
    _emit();
    return LoadResponse(duration: uris.isEmpty ? null : itemDuration);
  }

  static String _uriOf(AudioSourceMessage message) {
    if (message is UriAudioSourceMessage) return message.uri;
    throw UnsupportedError('Unexpected source ${message.runtimeType}');
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    calls.add('play');
    if (playing) return PlayResponse();
    playing = true;
    // Like the real player, this only returns once playback stops.
    final completer = _playCompleter = Completer<void>();
    await completer.future;
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    calls.add('pause');
    playing = false;
    _playCompleter?.complete();
    _playCompleter = null;
    _emit();
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    final target = request.index;
    calls.add(target == null ? 'seek' : 'seek:$target');
    if (target != null) {
      if (target < 0 || target >= uris.length) {
        throw PlatformException(
          code: 'IllegalSeekPosition',
          message: 'No item $target in a playlist of ${uris.length}',
        );
      }
      index = target;
    }
    position = request.position ?? Duration.zero;
    if (processingState == ProcessingStateMessage.completed) {
      processingState = ProcessingStateMessage.ready;
    }
    _emit();
    return SeekResponse();
  }

  @override
  Future<ConcatenatingInsertAllResponse> concatenatingInsertAll(
    ConcatenatingInsertAllRequest request,
  ) async {
    calls.add('insert:${request.index}+${request.children.length}');
    final gate = insertGate;
    if (gate != null) await gate.future;
    uris.insertAll(request.index, request.children.map(_uriOf));
    final current = index;
    if (current != null && request.index <= current) {
      index = current + request.children.length;
    }
    _emit();
    return ConcatenatingInsertAllResponse();
  }

  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
    ConcatenatingRemoveRangeRequest request,
  ) async {
    final start = request.startIndex;
    final end = request.endIndex;
    calls.add('remove:$start-$end');
    final count = end - start;
    uris.removeRange(start, end);
    final current = index;
    if (current != null) {
      if (current >= end) {
        index = current - count;
      } else if (current >= start) {
        // The current item is gone: move on to what followed it, or end
        // playback when nothing did.
        position = Duration.zero;
        if (start < uris.length) {
          index = start;
        } else {
          index = uris.isEmpty ? null : 0;
          processingState = ProcessingStateMessage.completed;
        }
      }
    }
    _emit();
    return ConcatenatingRemoveRangeResponse();
  }

  @override
  Future<ConcatenatingMoveResponse> concatenatingMove(
    ConcatenatingMoveRequest request,
  ) async {
    final from = request.currentIndex;
    final to = request.newIndex;
    calls.add('move:$from>$to');
    uris.insert(to, uris.removeAt(from));
    final current = index;
    if (current != null) {
      if (current == from) {
        index = to;
      } else if (from < current && to >= current) {
        index = current - 1;
      } else if (from > current && to <= current) {
        index = current + 1;
      }
    }
    _emit();
    return ConcatenatingMoveResponse();
  }

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    loopMode = request.loopMode;
    return SetLoopModeResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async => SetSkipSilenceResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async => SetShuffleOrderResponse();

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
  setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async => SetAutomaticallyWaitsToMinimizeStallingResponse();

  @override
  Future<SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse>
  setCanUseNetworkResourcesForLiveStreamingWhilePaused(
    SetCanUseNetworkResourcesForLiveStreamingWhilePausedRequest request,
  ) async => SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse();

  @override
  Future<SetPreferredPeakBitRateResponse> setPreferredPeakBitRate(
    SetPreferredPeakBitRateRequest request,
  ) async => SetPreferredPeakBitRateResponse();

  @override
  Future<SetAllowsExternalPlaybackResponse> setAllowsExternalPlayback(
    SetAllowsExternalPlaybackRequest request,
  ) async => SetAllowsExternalPlaybackResponse();

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async => SetAndroidAudioAttributesResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    release();
    return DisposeResponse();
  }
}

/// Route the audio_session plugin's channel to a no-op so `AudioPlayer` can
/// be constructed and played in a unit test.
void mockAudioSessionChannel() {
  const channel = MethodChannel('com.ryanheise.audio_session');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => null);
}
