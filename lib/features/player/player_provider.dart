import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/api/api_client.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/audio_cache_service.dart';
import 'package:tayra/features/player/queue_persistence_service.dart';

// ── Player state ────────────────────────────────────────────────────────

class PlayerState {
  final List<Track> queue;
  final int currentIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isShuffled;
  final LoopMode loopMode;
  final bool isLoading;

  const PlayerState({
    this.queue = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isShuffled = false,
    this.loopMode = LoopMode.off,
    this.isLoading = false,
  });

  Track? get currentTrack =>
      currentIndex >= 0 && currentIndex < queue.length
          ? queue[currentIndex]
          : null;

  bool get hasNext => currentIndex < queue.length - 1;
  bool get hasPrevious => currentIndex > 0;

  double get progress =>
      duration.inMilliseconds > 0
          ? position.inMilliseconds / duration.inMilliseconds
          : 0.0;

  PlayerState copyWith({
    List<Track>? queue,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isShuffled,
    LoopMode? loopMode,
    bool? isLoading,
  }) {
    return PlayerState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isShuffled: isShuffled ?? this.isShuffled,
      loopMode: loopMode ?? this.loopMode,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ── Audio handler (runs as foreground service) ──────────────────────────

/// A singleton audio handler that bridges just_audio with the OS media
/// session via audio_service. It manages the actual AudioPlayer and
/// exposes standard media controls (play, pause, skip, seek) to the OS
/// notification / lock screen.
class FunkwhaleAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  /// Callback invoked when a track completes. The PlayerNotifier sets this
  /// to wire up its queue-advance / loop logic.
  void Function()? onTrackCompleted;

  FunkwhaleAudioHandler() {
    // Forward playback state to the OS media session.
    _player.playbackEventStream
        .map(_transformPlaybackEvent)
        .pipe(playbackState);

    // Forward duration changes.
    _player.durationStream.listen((d) {
      final item = mediaItem.value;
      if (item != null && d != null) {
        mediaItem.add(item.copyWith(duration: d));
      }
    });

    // Listen for track completion.
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        onTrackCompleted?.call();
      }
    });
  }

  AudioPlayer get audioPlayer => _player;

  PlaybackState _transformPlaybackEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapProcessingState(_player.processingState),
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// Load and play a URL with auth headers, updating the media item metadata.
  Future<void> playUrl({
    required String url,
    required Map<String, String> headers,
    required MediaItem item,
  }) async {
    mediaItem.add(item);
    await _player.setAudioSource(
      AudioSource.uri(Uri.parse(url), headers: headers, tag: item.title),
    );
    await _player.play();
  }

  // ── Standard media controls (called from OS) ──────────────────────────

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    // Handled by PlayerNotifier which calls our handler indirectly.
    // We just need this override so the OS skip-next button works.
    // The PlayerNotifier hooks into customAction for this.
    await customAction('skipNext', {});
  }

  @override
  Future<void> skipToPrevious() async {
    await customAction('skipPrevious', {});
  }

  // Custom actions are dispatched to the PlayerNotifier.
  void Function(String, Map<String, dynamic>)? onCustomAction;

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    onCustomAction?.call(name, extras ?? {});
  }
}

// ── Provider for the singleton audio handler ────────────────────────────

final audioHandlerProvider = Provider<FunkwhaleAudioHandler>((ref) {
  // This will be overridden at app startup with the real initialized handler.
  throw UnimplementedError(
    'audioHandlerProvider must be overridden with the initialized handler',
  );
});

/// Initialize the audio handler. Call once at app startup before runApp.
Future<FunkwhaleAudioHandler> initAudioHandler() async {
  final handler = await AudioService.init(
    builder: () => FunkwhaleAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'dev.lorendb.tayra.player',
      androidNotificationChannelName: 'Tayra Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
  return handler;
}

// ── Player notifier ─────────────────────────────────────────────────────

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((
  ref,
) {
  return PlayerNotifier(ref);
});

class PlayerNotifier extends StateNotifier<PlayerState> {
  final Ref _ref;
  late final FunkwhaleAudioHandler _handler;
  final List<StreamSubscription> _subscriptions = [];

  PlayerNotifier(this._ref) : super(const PlayerState()) {
    _handler = _ref.read(audioHandlerProvider);
    _init();
    _restoreQueue();
  }

  AudioPlayer get audioPlayer => _handler.audioPlayer;

  void _init() {
    // Wire up OS skip buttons to our queue logic.
    _handler.onCustomAction = (name, extras) {
      switch (name) {
        case 'skipNext':
          skipNext();
          break;
        case 'skipPrevious':
          skipPrevious();
          break;
      }
    };

    // Wire up track completion.
    _handler.onTrackCompleted = _onTrackCompleted;

    // Listen to playback state.
    _subscriptions.add(
      _handler.audioPlayer.playingStream.listen((isPlaying) {
        if (mounted) {
          state = state.copyWith(isPlaying: isPlaying);
        }
      }),
    );

    // Listen to position.
    _subscriptions.add(
      _handler.audioPlayer.positionStream.listen((position) {
        if (mounted) {
          state = state.copyWith(position: position);
        }
      }),
    );

    // Listen to duration.
    _subscriptions.add(
      _handler.audioPlayer.durationStream.listen((duration) {
        if (mounted && duration != null) {
          state = state.copyWith(duration: duration);
        }
      }),
    );

    // Listen to player state for loading.
    _subscriptions.add(
      _handler.audioPlayer.playerStateStream.listen((playerState) {
        if (!mounted) return;
        state = state.copyWith(
          isLoading:
              playerState.processingState == ProcessingState.loading ||
              playerState.processingState == ProcessingState.buffering,
        );
      }),
    );
  }

  /// Restore the queue state from persistent storage on app launch.
  Future<void> _restoreQueue() async {
    final savedState = await QueuePersistenceService.restoreQueue();
    if (savedState == null || savedState.queue.isEmpty) return;

    // Restore queue and playback state
    state = state.copyWith(
      queue: savedState.queue,
      currentIndex: savedState.currentIndex,
      isShuffled: savedState.isShuffled,
      loopMode: _parseLoopMode(savedState.loopMode),
    );

    // Seek to saved position but don't auto-play
    if (savedState.position.inSeconds > 0) {
      try {
        await _loadTrackOnly(savedState.queue[savedState.currentIndex]);
        await _handler.audioPlayer.seek(savedState.position);
      } catch (_) {
        // Failed to restore - clear corrupted state
        await QueuePersistenceService.clearQueue();
      }
    }
  }

  /// Save the current queue state to persistent storage.
  Future<void> _saveQueue() async {
    if (state.queue.isEmpty) return;

    await QueuePersistenceService.saveQueue(
      queue: state.queue,
      currentIndex: state.currentIndex,
      position: state.position,
      isShuffled: state.isShuffled,
      loopMode: _loopModeToString(state.loopMode),
    );
  }

  String _loopModeToString(LoopMode mode) {
    switch (mode) {
      case LoopMode.off:
        return 'off';
      case LoopMode.all:
        return 'all';
      case LoopMode.one:
        return 'one';
    }
  }

  LoopMode _parseLoopMode(String mode) {
    switch (mode) {
      case 'all':
        return LoopMode.all;
      case 'one':
        return LoopMode.one;
      default:
        return LoopMode.off;
    }
  }

  CachedFunkwhaleApi get _api => _ref.read(cachedFunkwhaleApiProvider);

  AudioCacheService get _audioCache =>
      AudioCacheService(CacheManager.instance, _ref.read(dioProvider));

  /// Play a list of tracks starting at the given index.
  Future<void> playTracks(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) {
      state = const PlayerState();
      await _handler.audioPlayer.stop();
      await QueuePersistenceService.clearQueue();
      return;
    }

    state = state.copyWith(
      queue: tracks,
      currentIndex: startIndex,
      isLoading: true,
    );

    await _loadAndPlay(tracks[startIndex]);
    _saveQueue(); // Save queue after loading new tracks
  }

  /// Add tracks to the end of the queue.
  void addToQueue(List<Track> tracks) {
    if (tracks.isEmpty) return;
    state = state.copyWith(queue: [...state.queue, ...tracks]);
    _saveQueue();
  }

  /// Insert a track to play next.
  void playNext(Track track) {
    if (state.queue.isEmpty) {
      playTracks([track]);
      return;
    }
    final newQueue = List<Track>.from(state.queue);
    newQueue.insert(state.currentIndex + 1, track);
    state = state.copyWith(queue: newQueue);
    _saveQueue();
  }

  /// Remove track at index from the queue.
  void removeFromQueue(int index) {
    if (index < 0 || index >= state.queue.length) return;
    final newQueue = List<Track>.from(state.queue);
    newQueue.removeAt(index);

    var newIndex = state.currentIndex;
    if (index < state.currentIndex) {
      newIndex--;
    } else if (index == state.currentIndex) {
      if (newIndex >= newQueue.length) newIndex = newQueue.length - 1;
    }
    state = state.copyWith(queue: newQueue, currentIndex: newIndex);
    _saveQueue();
  }

  Future<void> _loadAndPlay(Track track) async {
    await _loadTrack(track, autoPlay: true);
  }

  /// Load a track without playing (for queue restoration).
  Future<void> _loadTrackOnly(Track track) async {
    await _loadTrack(track, autoPlay: false);
  }

  Future<void> _loadTrack(Track track, {required bool autoPlay}) async {
    try {
      final listenUrl = track.listenUrl;
      if (listenUrl == null) return;

      final streamUrl = _api.getStreamUrl(listenUrl);
      final headers = _api.authHeaders;

      // Build the MediaItem for the notification.
      final mediaItem = MediaItem(
        id: track.id.toString(),
        title: track.title,
        artist: track.artistName,
        album: track.albumTitle,
        artUri: track.coverUrl != null ? Uri.tryParse(track.coverUrl!) : null,
        duration:
            track.duration != null ? Duration(seconds: track.duration!) : null,
      );

      // Check audio cache first — play from local file if available.
      final cachedFile = await _audioCache.getCachedAudio(track);
      if (cachedFile != null) {
        _handler.mediaItem.add(mediaItem);
        await _handler.audioPlayer.setAudioSource(
          AudioSource.uri(Uri.parse(cachedFile.uri.toString())),
        );
        if (autoPlay) {
          await _handler.audioPlayer.play();
        }
      } else {
        // Stream from server.
        _handler.mediaItem.add(mediaItem);
        await _handler.audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(streamUrl),
            headers: headers,
            tag: mediaItem.title,
          ),
        );
        if (autoPlay) {
          await _handler.audioPlayer.play();
        }

        // Cache the audio file in the background for next time.
        _audioCache.cacheAudio(track, streamUrl, headers);
      }

      // Record listening history only if auto-playing.
      if (autoPlay) {
        try {
          await _api.recordListening(track.id);
        } catch (_) {
          // Non-critical
        }
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void _onTrackCompleted() {
    switch (state.loopMode) {
      case LoopMode.one:
        _handler.audioPlayer.seek(Duration.zero);
        _handler.audioPlayer.play();
        break;
      case LoopMode.all:
        if (state.hasNext) {
          skipNext();
        } else {
          final newIndex = 0;
          state = state.copyWith(currentIndex: newIndex);
          _loadAndPlay(state.queue[newIndex]);
        }
        break;
      case LoopMode.off:
        if (state.hasNext) {
          skipNext();
        } else {
          state = state.copyWith(isPlaying: false);
        }
        break;
    }
  }

  Future<void> play() => _handler.play();
  Future<void> pause() => _handler.pause();

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> skipNext() async {
    if (!state.hasNext) return;
    final newIndex = state.currentIndex + 1;
    state = state.copyWith(currentIndex: newIndex, isLoading: true);
    await _loadAndPlay(state.queue[newIndex]);
    _saveQueue();
  }

  Future<void> skipPrevious() async {
    if (state.position.inSeconds > 3) {
      await _handler.audioPlayer.seek(Duration.zero);
      return;
    }
    if (!state.hasPrevious) {
      await _handler.audioPlayer.seek(Duration.zero);
      return;
    }
    final newIndex = state.currentIndex - 1;
    state = state.copyWith(currentIndex: newIndex, isLoading: true);
    await _loadAndPlay(state.queue[newIndex]);
    _saveQueue();
  }

  Future<void> seekTo(Duration position) async {
    await _handler.seek(position);
    _saveQueue(); // Save position
  }

  void toggleShuffle() {
    state = state.copyWith(isShuffled: !state.isShuffled);
    if (state.isShuffled) {
      final current = state.currentTrack;
      final newQueue = List<Track>.from(state.queue);
      if (current != null) newQueue.remove(current);
      newQueue.shuffle();
      if (current != null) newQueue.insert(0, current);
      state = state.copyWith(queue: newQueue, currentIndex: 0);
    }
    _saveQueue();
  }

  void toggleLoopMode() {
    switch (state.loopMode) {
      case LoopMode.off:
        state = state.copyWith(loopMode: LoopMode.all);
        break;
      case LoopMode.all:
        state = state.copyWith(loopMode: LoopMode.one);
        break;
      case LoopMode.one:
        state = state.copyWith(loopMode: LoopMode.off);
        break;
    }
    _saveQueue();
  }

  /// Jump to a specific index in the queue.
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    state = state.copyWith(currentIndex: index, isLoading: true);
    await _loadAndPlay(state.queue[index]);
    _saveQueue();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
