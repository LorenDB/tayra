import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/api/api_client.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/audio_cache_service.dart';
import 'package:tayra/features/player/queue_persistence_service.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';

// ── Android Auto browse tree constants ──────────────────────────────────

/// Media ID prefixes for the Android Auto browse tree. Each browsable
/// or playable node in the tree uses a structured ID so that [getChildren]
/// and [playFromMediaId] can parse the type and numeric identifier.
class _BrowseIds {
  static const root = 'root';
  static const recentRoot = 'recent';

  // Top-level category IDs
  static const recentAlbums = 'recent_albums';
  static const artists = 'artists';
  static const playlists = 'playlists';
  static const favorites = 'favorites';

  // Prefixed IDs for child items
  static const albumPrefix = 'album_';
  static const artistPrefix = 'artist_';
  static const playlistPrefix = 'playlist_';
  static const trackPrefix = 'track_';

  // Composite IDs for tracks within a context
  static const albumTrackPrefix = 'album_track_';
  static const playlistTrackPrefix = 'playlist_track_';
  static const favoriteTrackPrefix = 'fav_track_';
}

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
///
/// Also serves as the Android Auto media browse tree provider via the
/// [getChildren], [getMediaItem], [playFromMediaId], and [search]
/// overrides. The browse tree is populated lazily from the Funkwhale
/// API once [api] is injected by the [PlayerNotifier].
class FunkwhaleAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  /// The Funkwhale API client, injected after Riverpod initialisation.
  /// Android Auto browse methods return empty results until this is set.
  CachedFunkwhaleApi? api;

  /// The browse mode setting (albums or artists), injected after init.
  /// Determines what the second category in Android Auto displays.
  BrowseMode browseMode = BrowseMode.albums;

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

  // ── Android Auto browse tree ──────────────────────────────────────────

  /// Callback that starts playback of a list of tracks from index 0.
  /// Set by [PlayerNotifier] so the handler can trigger queue playback
  /// without a direct Riverpod dependency.
  Future<void> Function(List<Track> tracks, {int startIndex})? onPlayTracks;

  /// Build the browse tree children for [parentMediaId].
  ///
  /// Called by the Android media session (via audio_service) when Android
  /// Auto or another media browser requests the contents of a node.
  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    final apiClient = api;
    if (apiClient == null) return [];

    try {
      // ── Root categories ───────────────────────────────────────────
      if (parentMediaId == _BrowseIds.root ||
          parentMediaId == _BrowseIds.recentRoot) {
        // Build category list based on browse mode setting.
        final categories = <MediaItem>[];

        // Add the primary browse category based on user preference
        if (browseMode == BrowseMode.albums) {
          categories.add(
            MediaItem(
              id: _BrowseIds.recentAlbums,
              title: 'Albums',
              playable: false,
              extras: {
                AndroidContentStyle.playableHintKey:
                    AndroidContentStyle.gridItemHintValue,
                AndroidContentStyle.browsableHintKey:
                    AndroidContentStyle.gridItemHintValue,
              },
            ),
          );
        } else {
          categories.add(
            MediaItem(
              id: _BrowseIds.artists,
              title: 'Artists',
              playable: false,
              extras: {
                AndroidContentStyle.playableHintKey:
                    AndroidContentStyle.gridItemHintValue,
                AndroidContentStyle.browsableHintKey:
                    AndroidContentStyle.gridItemHintValue,
              },
            ),
          );
        }

        // Add remaining categories (always in same order)
        categories.add(
          MediaItem(
            id: _BrowseIds.playlists,
            title: 'Playlists',
            playable: false,
            extras: {
              AndroidContentStyle.playableHintKey:
                  AndroidContentStyle.listItemHintValue,
              AndroidContentStyle.browsableHintKey:
                  AndroidContentStyle.listItemHintValue,
            },
          ),
        );
        categories.add(
          MediaItem(
            id: _BrowseIds.favorites,
            title: 'Favorites',
            playable: false,
            extras: {
              AndroidContentStyle.playableHintKey:
                  AndroidContentStyle.listItemHintValue,
              AndroidContentStyle.browsableHintKey:
                  AndroidContentStyle.listItemHintValue,
            },
          ),
        );

        return categories;
      }

      // ── Recent Albums (grid of albums) ────────────────────────────
      if (parentMediaId == _BrowseIds.recentAlbums) {
        final response = await apiClient.getAlbums(
          ordering: '-creation_date',
          pageSize: 25,
        );
        return response.results
            .map((album) => _albumToMediaItem(album))
            .toList();
      }

      // ── Artists (grid of artists) ─────────────────────────────────
      if (parentMediaId == _BrowseIds.artists) {
        final response = await apiClient.getArtists(
          ordering: 'name',
          pageSize: 50,
          hasAlbums: true,
        );
        return response.results
            .map((artist) => _artistToMediaItem(artist))
            .toList();
      }

      // ── Playlists (list of playlists) ─────────────────────────────
      if (parentMediaId == _BrowseIds.playlists) {
        final response = await apiClient.getPlaylists(
          scope: 'me',
          pageSize: 50,
        );
        return response.results
            .map((playlist) => _playlistToMediaItem(playlist))
            .toList();
      }

      // ── Favorites (list of tracks) ────────────────────────────────
      if (parentMediaId == _BrowseIds.favorites) {
        final response = await apiClient.getFavorites(pageSize: 50);
        return response.results
            .map(
              (fav) => _trackToMediaItem(
                fav.track,
                idPrefix: _BrowseIds.favoriteTrackPrefix,
              ),
            )
            .toList();
      }

      // ── Album detail → tracks ─────────────────────────────────────
      if (parentMediaId.startsWith(_BrowseIds.albumPrefix)) {
        final albumId = int.tryParse(
          parentMediaId.substring(_BrowseIds.albumPrefix.length),
        );
        if (albumId == null) return [];
        final response = await apiClient.getTracks(
          album: albumId,
          ordering: 'position',
          pageSize: 100,
        );
        return response.results
            .map(
              (track) => _trackToMediaItem(
                track,
                idPrefix: _BrowseIds.albumTrackPrefix,
              ),
            )
            .toList();
      }

      // ── Artist detail → albums ────────────────────────────────────
      if (parentMediaId.startsWith(_BrowseIds.artistPrefix)) {
        final artistId = int.tryParse(
          parentMediaId.substring(_BrowseIds.artistPrefix.length),
        );
        if (artistId == null) return [];
        final response = await apiClient.getAlbums(
          artist: artistId,
          ordering: '-creation_date',
          pageSize: 50,
        );
        return response.results
            .map((album) => _albumToMediaItem(album))
            .toList();
      }

      // ── Playlist detail → tracks ──────────────────────────────────
      if (parentMediaId.startsWith(_BrowseIds.playlistPrefix)) {
        final playlistId = int.tryParse(
          parentMediaId.substring(_BrowseIds.playlistPrefix.length),
        );
        if (playlistId == null) return [];
        final response = await apiClient.getPlaylistTracks(
          playlistId,
          pageSize: 100,
        );
        return response.results
            .map(
              (pt) => _trackToMediaItem(
                pt.track,
                idPrefix: _BrowseIds.playlistTrackPrefix,
              ),
            )
            .toList();
      }
    } catch (_) {
      // Return empty on any API error – Android Auto will show
      // "Something went wrong" which is acceptable.
    }

    return [];
  }

  /// Return metadata for a single media item by ID. Android Auto
  /// may call this to display details for an item in the browse tree.
  @override
  Future<MediaItem> getMediaItem(String mediaId) async {
    final apiClient = api;
    if (apiClient == null) {
      return MediaItem(id: mediaId, title: 'Loading...');
    }

    try {
      // Album
      if (mediaId.startsWith(_BrowseIds.albumPrefix) &&
          !mediaId.startsWith(_BrowseIds.albumTrackPrefix)) {
        final id = int.tryParse(
          mediaId.substring(_BrowseIds.albumPrefix.length),
        );
        if (id != null) {
          final album = await apiClient.getAlbum(id);
          return _albumToMediaItem(album);
        }
      }

      // Track (any prefix)
      final trackId = _extractTrackId(mediaId);
      if (trackId != null) {
        final track = await apiClient.getTrack(trackId);
        return _trackToMediaItem(track, idPrefix: _BrowseIds.trackPrefix);
      }
    } catch (_) {
      // Fall through to default
    }

    return MediaItem(id: mediaId, title: 'Unknown');
  }

  /// Start playback when a user taps a playable item in Android Auto.
  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final apiClient = api;
    if (apiClient == null) return;

    try {
      // ── Single track tap from favorites ───────────────────────────
      if (mediaId.startsWith(_BrowseIds.favoriteTrackPrefix)) {
        final trackId = int.tryParse(
          mediaId.substring(_BrowseIds.favoriteTrackPrefix.length),
        );
        if (trackId == null) return;
        // Load entire favorites list and find the tapped track's position.
        final response = await apiClient.getFavorites(pageSize: 50);
        final tracks = response.results.map((f) => f.track).toList();
        final index = tracks.indexWhere((t) => t.id == trackId);
        await onPlayTracks?.call(tracks, startIndex: index >= 0 ? index : 0);
        return;
      }

      // ── Single track tap from an album ────────────────────────────
      if (mediaId.startsWith(_BrowseIds.albumTrackPrefix)) {
        final trackId = int.tryParse(
          mediaId.substring(_BrowseIds.albumTrackPrefix.length),
        );
        if (trackId == null) return;
        // Determine which album this track belongs to and load all tracks.
        final track = await apiClient.getTrack(trackId);
        if (track.album != null) {
          final response = await apiClient.getTracks(
            album: track.album!.id,
            ordering: 'position',
            pageSize: 100,
          );
          final tracks = response.results;
          final index = tracks.indexWhere((t) => t.id == trackId);
          await onPlayTracks?.call(tracks, startIndex: index >= 0 ? index : 0);
        } else {
          await onPlayTracks?.call([track]);
        }
        return;
      }

      // ── Single track tap from a playlist ──────────────────────────
      if (mediaId.startsWith(_BrowseIds.playlistTrackPrefix)) {
        final trackId = int.tryParse(
          mediaId.substring(_BrowseIds.playlistTrackPrefix.length),
        );
        if (trackId == null) return;
        // We don't know the playlist ID from the track prefix, so just
        // play the single track. A more sophisticated approach would
        // encode the playlist ID in the media ID.
        final track = await apiClient.getTrack(trackId);
        await onPlayTracks?.call([track]);
        return;
      }

      // ── Generic track prefix ──────────────────────────────────────
      if (mediaId.startsWith(_BrowseIds.trackPrefix)) {
        final trackId = int.tryParse(
          mediaId.substring(_BrowseIds.trackPrefix.length),
        );
        if (trackId == null) return;
        final track = await apiClient.getTrack(trackId);
        await onPlayTracks?.call([track]);
        return;
      }
    } catch (_) {
      // Silently fail – Android Auto will show a playback error toast.
    }
  }

  /// Search the Funkwhale library from Android Auto's search interface.
  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    final apiClient = api;
    if (apiClient == null || query.trim().isEmpty) return [];

    try {
      final result = await apiClient.search(query);
      final items = <MediaItem>[];

      // Albums first (browsable)
      for (final album in result.albums.take(5)) {
        items.add(_albumToMediaItem(album));
      }

      // Artists (browsable)
      for (final artist in result.artists.take(5)) {
        items.add(_artistToMediaItem(artist));
      }

      // Tracks (playable)
      for (final track in result.tracks.take(10)) {
        items.add(_trackToMediaItem(track, idPrefix: _BrowseIds.trackPrefix));
      }

      return items;
    } catch (_) {
      return [];
    }
  }

  // ── Helpers: model → MediaItem ────────────────────────────────────────

  MediaItem _albumToMediaItem(Album album) {
    return MediaItem(
      id: '${_BrowseIds.albumPrefix}${album.id}',
      title: album.title,
      artist: album.artist?.name,
      artUri: album.coverUrl != null ? Uri.tryParse(album.coverUrl!) : null,
      playable: false,
      extras: {
        AndroidContentStyle.playableHintKey:
            AndroidContentStyle.listItemHintValue,
      },
    );
  }

  MediaItem _artistToMediaItem(Artist artist) {
    return MediaItem(
      id: '${_BrowseIds.artistPrefix}${artist.id}',
      title: artist.name,
      artUri: artist.coverUrl != null ? Uri.tryParse(artist.coverUrl!) : null,
      playable: false,
      extras: {
        AndroidContentStyle.browsableHintKey:
            AndroidContentStyle.gridItemHintValue,
      },
    );
  }

  MediaItem _playlistToMediaItem(Playlist playlist) {
    return MediaItem(
      id: '${_BrowseIds.playlistPrefix}${playlist.id}',
      title: playlist.name,
      displaySubtitle: '${playlist.tracksCount} tracks',
      playable: false,
      extras: {
        AndroidContentStyle.playableHintKey:
            AndroidContentStyle.listItemHintValue,
      },
    );
  }

  MediaItem _trackToMediaItem(Track track, {required String idPrefix}) {
    return MediaItem(
      id: '$idPrefix${track.id}',
      title: track.title,
      artist: track.artistName,
      album: track.albumTitle,
      artUri: track.coverUrl != null ? Uri.tryParse(track.coverUrl!) : null,
      duration:
          track.duration != null ? Duration(seconds: track.duration!) : null,
      playable: true,
    );
  }

  /// Extract the numeric track ID from any track-prefixed media ID.
  int? _extractTrackId(String mediaId) {
    for (final prefix in [
      _BrowseIds.albumTrackPrefix,
      _BrowseIds.playlistTrackPrefix,
      _BrowseIds.favoriteTrackPrefix,
      _BrowseIds.trackPrefix,
    ]) {
      if (mediaId.startsWith(prefix)) {
        return int.tryParse(mediaId.substring(prefix.length));
      }
    }
    return null;
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
    config: AudioServiceConfig(
      androidNotificationChannelId: 'dev.lorendb.tayra.player',
      androidNotificationChannelName: 'Tayra Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidBrowsableRootExtras: {
        AndroidContentStyle.supportedKey: true,
        AndroidContentStyle.browsableHintKey:
            AndroidContentStyle.gridItemHintValue,
        AndroidContentStyle.playableHintKey:
            AndroidContentStyle.listItemHintValue,
      },
    ),
  );
  return handler;
}

// ── Player notifier ─────────────────────────────────────────────────────

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);

class PlayerNotifier extends Notifier<PlayerState> {
  late final FunkwhaleAudioHandler _handler;
  final List<StreamSubscription> _subscriptions = [];

  @override
  PlayerState build() {
    _handler = ref.read(audioHandlerProvider);
    _init();
    Future.microtask(() => _restoreQueue());
    ref.onDispose(() {
      for (final sub in _subscriptions) {
        sub.cancel();
      }
    });
    return const PlayerState();
  }

  AudioPlayer get audioPlayer => _handler.audioPlayer;

  void _init() {
    // Note: API and browse mode are injected in main.dart before runApp,
    // so the handler works even when launched directly from Android Auto.

    // Wire up Android Auto playback to our queue logic.
    _handler.onPlayTracks = (tracks, {int startIndex = 0}) async {
      await playTracks(tracks, startIndex: startIndex);
    };

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
        state = state.copyWith(isPlaying: isPlaying);
      }),
    );

    // Listen to position.
    _subscriptions.add(
      _handler.audioPlayer.positionStream.listen((position) {
        state = state.copyWith(position: position);
      }),
    );

    // Listen to duration.
    _subscriptions.add(
      _handler.audioPlayer.durationStream.listen((duration) {
        if (duration != null) {
          state = state.copyWith(duration: duration);
        }
      }),
    );

    // Listen to player state for loading.
    _subscriptions.add(
      _handler.audioPlayer.playerStateStream.listen((playerState) {
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
    try {
      final savedState = await QueuePersistenceService.restoreQueue();
      if (savedState == null || savedState.queue.isEmpty) return;

      // Validate current index is within bounds
      final validIndex = savedState.currentIndex.clamp(
        0,
        savedState.queue.length - 1,
      );

      // Restore queue and playback state
      state = state.copyWith(
        queue: savedState.queue,
        currentIndex: validIndex,
        isShuffled: savedState.isShuffled,
        loopMode: _parseLoopMode(savedState.loopMode),
      );

      // Try to restore the track and position
      if (validIndex < savedState.queue.length) {
        try {
          await _loadTrackOnly(savedState.queue[validIndex]);
          if (savedState.position.inSeconds > 0) {
            await _handler.audioPlayer.seek(savedState.position);
          }
        } catch (e) {
          // Failed to load track - queue is still valid, just reset to start
          state = state.copyWith(position: Duration.zero);
        }
      }
    } catch (e) {
      // Failed to restore - clear corrupted state
      await QueuePersistenceService.clearQueue();
      state = const PlayerState();
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

  CachedFunkwhaleApi get _api => ref.read(cachedFunkwhaleApiProvider);

  AudioCacheService get _audioCache =>
      AudioCacheService(CacheManager.instance, ref.read(dioProvider));

  /// Play a list of tracks starting at the given index.
  Future<void> playTracks(
    List<Track> tracks, {
    int startIndex = 0,
    String? source,
  }) async {
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
    Aptabase.instance.trackEvent('play_tracks', {
      'count': tracks.length,
      'start_index': startIndex,
      'source': source ?? 'unknown',
    });
  }

  /// Add tracks to the end of the queue.
  void addToQueue(List<Track> tracks) {
    if (tracks.isEmpty) return;
    state = state.copyWith(queue: [...state.queue, ...tracks]);
    _saveQueue();
    Aptabase.instance.trackEvent('add_to_queue', {'count': tracks.length});
  }

  /// Insert a track to play next.
  void playNext(Track track) {
    if (state.queue.isEmpty) {
      playTracks([track], source: 'play_next');
      return;
    }
    final newQueue = List<Track>.from(state.queue);
    newQueue.insert(state.currentIndex + 1, track);
    state = state.copyWith(queue: newQueue);
    _saveQueue();
    Aptabase.instance.trackEvent('play_next');
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
    Aptabase.instance.trackEvent('remove_from_queue');
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
      if (listenUrl == null) {
        debugPrint(
          'Track ${track.id} "${track.title}" has no listen URL. Uploads: ${track.uploads.length}',
        );
        throw Exception('Track has no listen URL');
      }

      final streamUrl = _api.getStreamUrl(listenUrl);
      debugPrint(
        'Loading track ${track.id}: listenUrl=$listenUrl, streamUrl=$streamUrl',
      );
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

        // Record locally for year-in-review stats.
        ListenHistoryService.recordListen(track);
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('Failed to load track: $e');
      state = state.copyWith(isLoading: false);

      // If this was supposed to auto-play and we have more tracks, skip to next
      if (autoPlay && state.hasNext) {
        // Wait a moment to avoid rapid-fire failures
        await Future.delayed(const Duration(milliseconds: 500));
        skipNext();
      } else if (autoPlay && !state.hasNext) {
        // No more tracks - clear the queue to stop infinite loading
        debugPrint('No more playable tracks in queue, clearing player state');
        state = const PlayerState();
      }
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
          _saveQueue(); // Save state after looping back to start
        }
        break;
      case LoopMode.off:
        if (state.hasNext) {
          skipNext();
        } else {
          state = state.copyWith(isPlaying: false);
          _saveQueue(); // Save final state when queue ends
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
    Aptabase.instance.trackEvent('toggle_play_pause', {
      'action': state.isPlaying ? 'pause' : 'play',
    });
  }

  Future<void> skipNext() async {
    if (!state.hasNext) return;
    final newIndex = state.currentIndex + 1;
    state = state.copyWith(currentIndex: newIndex, isLoading: true);
    await _loadAndPlay(state.queue[newIndex]);
    _saveQueue();
    Aptabase.instance.trackEvent('skip_next');
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
    Aptabase.instance.trackEvent('skip_previous');
  }

  Future<void> seekTo(Duration position) async {
    await _handler.seek(position);
    _saveQueue(); // Save position
    Aptabase.instance.trackEvent('seek', {
      'position_seconds': position.inSeconds,
    });
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
    Aptabase.instance.trackEvent('toggle_shuffle', {
      'enabled': state.isShuffled,
    });
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
    Aptabase.instance.trackEvent('toggle_loop_mode', {
      'mode': state.loopMode.name,
    });
  }

  /// Jump to a specific index in the queue.
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    state = state.copyWith(currentIndex: index, isLoading: true);
    await _loadAndPlay(state.queue[index]);
    _saveQueue();
    Aptabase.instance.trackEvent('jump_to_queue', {'index': index});
  }
}
