import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/cache/audio_cache_service.dart';
import 'package:tayra/core/cache/cache_provider.dart';
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
  final List<Track> unshuffledQueue;
  final int currentIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isShuffled;
  final LoopMode loopMode;
  final bool isLoading;
  final int? loadingRadioId;

  const PlayerState({
    this.queue = const [],
    this.unshuffledQueue = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isShuffled = false,
    this.loopMode = LoopMode.off,
    this.isLoading = false,
    this.loadingRadioId,
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
    List<Track>? unshuffledQueue,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isShuffled,
    LoopMode? loopMode,
    bool? isLoading,
    int? loadingRadioId,
    bool clearLoadingRadioId = false,
  }) {
    return PlayerState(
      queue: queue ?? this.queue,
      unshuffledQueue: unshuffledQueue ?? this.unshuffledQueue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isShuffled: isShuffled ?? this.isShuffled,
      loopMode: loopMode ?? this.loopMode,
      isLoading: isLoading ?? this.isLoading,
      loadingRadioId:
          clearLoadingRadioId ? null : (loadingRadioId ?? this.loadingRadioId),
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

  /// Whether Android Auto integration is enabled at all. When false the
  /// browse/search/playback callbacks return empty results / no-ops so the
  /// system will not be able to interact with the app via Android Auto.
  bool androidAutoEnabled = true;

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
      if (!androidAutoEnabled) return [];

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
        final allTracks = await fetchAllPages(
          (page) => apiClient.getTracks(
            album: albumId,
            ordering: 'position',
            pageSize: 100,
            page: page,
          ),
        );
        sortTracksByDiscAndPosition(allTracks);
        return allTracks
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
        final allPlaylistTracks = await fetchAllPages(
          (page) => apiClient.getPlaylistTracks(
            playlistId,
            page: page,
            pageSize: 100,
          ),
        );
        allPlaylistTracks.sort(
          (a, b) => (a.index ?? 0).compareTo(b.index ?? 0),
        );
        return allPlaylistTracks
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
    if (!androidAutoEnabled) return MediaItem(id: mediaId, title: 'Unknown');
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
    if (!androidAutoEnabled) return;
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
          final allTracks = await fetchAllPages(
            (page) => apiClient.getTracks(
              album: track.album!.id,
              ordering: 'position',
              pageSize: 100,
              page: page,
            ),
          );
          sortTracksByDiscAndPosition(allTracks);
          final index = allTracks.indexWhere((t) => t.id == trackId);
          await onPlayTracks?.call(
            allTracks,
            startIndex: index >= 0 ? index : 0,
          );
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
    if (!androidAutoEnabled) return [];
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
      androidNotificationOngoing: false,
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

/// Async provider that exposes the persisted list of stashed queues.
/// Invalidated whenever a stash is added, restored, or deleted.
final stashedQueuesProvider = FutureProvider<List<StashedQueue>>((ref) async {
  return QueuePersistenceService.loadStashes();
});

class PlayerNotifier extends Notifier<PlayerState> {
  late final FunkwhaleAudioHandler _handler;
  late final AudioCacheService _audioCache;
  final List<StreamSubscription> _subscriptions = [];
  // Map of trackId -> last recorded timestamp (ms) to debounce duplicate
  // local listen records when multiple events fire during a track transition.
  final Map<int, int> _lastRecordedAtMs = {};

  /// Position to seek to the first time play() is called after a queue
  /// restore.  Set by [_restoreQueue] and cleared once the seek is done.
  Duration? _pendingRestorePosition;

  /// Whether the player currently has a multi-source gapless playlist
  /// loaded via [AudioPlayer.setAudioSources].
  bool _gaplessActive = false;

  @override
  PlayerState build() {
    _handler = ref.read(audioHandlerProvider);
    _audioCache = ref.read(audioCacheServiceProvider);
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
        if (!isPlaying) {
          // Save position when paused
          _saveQueue();
          // Try to record partial listen on pause; ignore failures.
          try {
            _recordCurrentTrackListen();
          } catch (_) {}
        }
      }),
    );

    // Listen to position.
    _subscriptions.add(
      _handler.audioPlayer.positionStream.listen((position) {
        state = state.copyWith(position: position);
        // Save position periodically (every 2 seconds) to persistence
        if (position.inSeconds % 2 == 0 && position.inSeconds > 0) {
          _saveQueue();
        }
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

    _subscriptions.add(
      _handler.audioPlayer.currentIndexStream.listen((index) {
        // When gapless playback is active and the player auto-advances to a
        // new track (index changed without a manual skip), update our state.
        if (_gaplessActive &&
            index != null &&
            index != state.currentIndex &&
            index >= 0 &&
            index < state.queue.length) {
          // Record listen for the track we just left.
          try {
            _recordCurrentTrackListen();
          } catch (_) {}

          state = state.copyWith(currentIndex: index);

          final newTrack = state.currentTrack;
          if (newTrack != null) {
            _updateMediaItemForTrack(newTrack);
            // Record server-side listen for new track.
            _api.recordListening(newTrack.id).catchError((_) {});
          }

          _saveQueue();
        }

        // Proactively prefetch radio tracks when near end of current track
        _maybePrefetchRadioTrack();
      }),
    );

    // Sync initial playback state to avoid missing the first play event
    // due to a race between stream subscription and playback starting.
    Future.microtask(() {
      state = state.copyWith(isPlaying: _handler.audioPlayer.playing);
    });
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
        unshuffledQueue: savedState.unshuffledQueue,
        currentIndex: validIndex,
        isShuffled: savedState.isShuffled,
        loopMode: _parseLoopMode(savedState.loopMode),
      );

      // Restore the saved playback position so it can be seeked to once the
      // user taps play.  We intentionally do NOT call setAudioSource here
      // because just_audio will buffer a network stream indefinitely when
      // no play() follows, causing the UI to spin forever.
      //
      // _pendingRestorePosition being non-null is the signal that the audio
      // source has not been loaded yet.  We always set it (even to zero) so
      // that play() knows it must call _loadAndPlay first.
      _pendingRestorePosition = savedState.position;
      if (savedState.position.inSeconds > 0) {
        // Reflect the position in the UI immediately so the scrubber shows
        // where the user left off before they press play.
        state = state.copyWith(position: savedState.position);
      }
    } catch (e) {
      // Failed to restore - clear corrupted state
      await QueuePersistenceService.clearQueue();
      _gaplessActive = false;
      state = const PlayerState();
    }
  }

  /// Save the current queue state to persistent storage.
  Future<void> _saveQueue() async {
    if (state.queue.isEmpty) return;

    await QueuePersistenceService.saveQueue(
      queue: state.queue,
      unshuffledQueue: state.unshuffledQueue,
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

  bool get _isGaplessEnabled => ref.read(settingsProvider).gaplessPlayback;

  /// Build a single [AudioSource] for a track, preferring cached local files.
  Future<AudioSource> _audioSourceForTrack(Track track) async {
    final listenUrl = track.listenUrl;
    if (listenUrl == null) {
      throw Exception('Track ${track.id} has no listen URL');
    }

    final cachedFile = await _audioCache.getCachedAudio(track);
    if (cachedFile != null) {
      return AudioSource.uri(cachedFile.uri);
    }

    final streamUrl = _api.getStreamUrl(listenUrl);
    return AudioSource.uri(Uri.parse(streamUrl), headers: _api.authHeaders);
  }

  /// Load all queue tracks into the player as a multi-source playlist
  /// for gapless playback.  Returns true on success, false on failure
  /// (caller should fall back to single-track loading).
  Future<bool> _loadGaplessSource(
    int startIndex, {
    Duration? initialPosition,
  }) async {
    try {
      final sources = <AudioSource>[];
      for (final track in state.queue) {
        sources.add(await _audioSourceForTrack(track));
      }

      // Update notification metadata for the starting track.
      _updateMediaItemForTrack(state.queue[startIndex]);

      await _handler.audioPlayer.setAudioSources(
        sources,
        initialIndex: startIndex,
        initialPosition: initialPosition,
      );

      // Sync the player's loop mode so it can handle looping natively.
      _handler.audioPlayer.setLoopMode(state.loopMode);

      _gaplessActive = true;
      return true;
    } catch (e) {
      debugPrint('Failed to build gapless source: $e');
      _gaplessActive = false;
      return false;
    }
  }

  /// Update the OS media notification for the given track.
  void _updateMediaItemForTrack(Track track) {
    _handler.mediaItem.add(
      MediaItem(
        id: track.id.toString(),
        title: track.title,
        artist: track.artistName,
        album: track.albumTitle,
        artUri: track.coverUrl != null ? Uri.tryParse(track.coverUrl!) : null,
        duration:
            track.duration != null ? Duration(seconds: track.duration!) : null,
      ),
    );
  }

  // Radio session state (when playing a radio stream)
  int? _radioSessionId;
  int? _radioId;
  Timer? _radioFetchTimer;
  bool _isPrefetchingRadioTrack = false;

  Future<Track?> _parseTrackFromRaw(dynamic raw) async {
    try {
      // Direct track map
      if (raw is Map<String, dynamic>) {
        // Common full track payload with listen_url
        if (raw.containsKey('id') && raw.containsKey('listen_url')) {
          return Track.fromJson(raw);
        }

        // Wrapped track: { "track": {...} } or { "track": 123 }
        if (raw.containsKey('track')) {
          final trackVal = raw['track'];
          if (trackVal is Map<String, dynamic>) {
            return Track.fromJson(trackVal);
          }
          if (trackVal is int) {
            try {
              return await _api.getTrack(trackVal);
            } catch (_) {
              return null;
            }
          }
          if (trackVal is String && int.tryParse(trackVal) != null) {
            try {
              return await _api.getTrack(int.parse(trackVal));
            } catch (_) {
              return null;
            }
          }
        }

        // Sometimes APIs return { "results": [...] } or similar
        if (raw.containsKey('results') &&
            raw['results'] is List &&
            (raw['results'] as List).isNotEmpty) {
          final first = (raw['results'] as List).first;
          // Recurse to parse the first element
          return await _parseTrackFromRaw(first);
        }

        // Occasionally the server returns just an id inside a map, e.g. {"id": 123}
        if (raw.containsKey('id') && raw.keys.length == 1) {
          final idVal = raw['id'];
          if (idVal is int) {
            try {
              return await _api.getTrack(idVal);
            } catch (_) {
              return null;
            }
          }
          if (idVal is String && int.tryParse(idVal) != null) {
            try {
              return await _api.getTrack(int.parse(idVal));
            } catch (_) {
              return null;
            }
          }
        }
      }

      // List responses
      if (raw is List && raw.isNotEmpty) {
        final first = raw.first;
        // If the first element is a map, try to parse it as a track
        if (first is Map<String, dynamic>) {
          return Track.fromJson(first);
        }
        // If list of ids
        if (first is int) {
          try {
            return await _api.getTrack(first);
          } catch (_) {
            return null;
          }
        }
        if (first is String && int.tryParse(first) != null) {
          try {
            return await _api.getTrack(int.parse(first));
          } catch (_) {
            return null;
          }
        }
      }

      // Raw is a plain int -> treat as track id
      if (raw is int) {
        try {
          return await _api.getTrack(raw);
        } catch (_) {
          return null;
        }
      }

      // Raw is a numeric string -> treat as id
      if (raw is String && int.tryParse(raw) != null) {
        try {
          return await _api.getTrack(int.parse(raw));
        } catch (_) {
          return null;
        }
      }
    } catch (_) {
      // Swallow parse errors silently in production; defensive parsing
      // paths above will fallback to other strategies.
    }
    return null;
  }

  /// Start radio playback for a given radio id. This creates a radio session
  /// on the server, fetches the initial track, prefetches a small buffer of
  /// upcoming tracks and then starts a background fetcher to keep the queue
  /// populated.
  Future<void> startRadio(int radioId) async {
    state = state.copyWith(loadingRadioId: radioId);
    try {
      try {
        Aptabase.instance.trackEvent('radio_start_requested', {
          'radio_id': radioId,
        });
      } catch (_) {}
      // related_object_id must be sent as an integer. Sending it as a
      // string caused a server 500 on some Funkwhale instances.
      RadioSession session;
      try {
        // Follow the official Funkwhale Android client: for radios from the
        // radios list we should create a session with radio_type='custom'
        // and include `custom_radio` with the radio id.
        session = await _api.createRadioSession({
          'radio_type': 'custom',
          'custom_radio': radioId,
        });
      } on DioException catch (e) {
        // Log detailed diagnostics and retry with the schema-expected
        // string form. Some servers are inconsistent; this will surface
        // the server response body for debugging.
        debugPrint(
          'createRadioSession DioException: '
          'status=${e.response?.statusCode}, '
          'data=${e.response?.data}, '
          'request=${e.requestOptions.data}',
        );

        try {
          session = await _api.createRadioSession({
            'radio_type': 'radio',
            'related_object_id': radioId.toString(),
          });
        } on DioException catch (e2) {
          debugPrint(
            'createRadioSession retry failed: '
            'status=${e2.response?.statusCode}, '
            'data=${e2.response?.data}, '
            'request=${e2.requestOptions.data}',
          );
          rethrow;
        }
      }

      _radioSessionId = session.id;
      _radioId = radioId;
      try {
        Aptabase.instance.trackEvent('radio_session_created', {
          'radio_id': radioId,
          'used_session': true,
        });
      } catch (_) {}

      // Fetch the first track (raw) and try to parse it.
      final rawFirst = await _api.postNextRadioTrackRaw(_radioSessionId!);
      Track? first = await _parseTrackFromRaw(rawFirst);
      if (first == null) {
        // Fallback to the radio sample endpoint
        try {
          first = await _api.getRadioTrack(radioId);
        } catch (_) {}
      }
      if (first == null) throw Exception('No track returned for radio');

      // Play the initial track (this replaces the current queue).
      await playTracks([first], source: 'radio');
      state = state.copyWith(clearLoadingRadioId: true);
      try {
        Aptabase.instance.trackEvent('radio_started', {
          'radio_id': radioId,
          'source': 'session',
        });
      } catch (_) {}

      // A second track will automatically be preloaded by the subscription that
      // watches the current index of the queue
    } catch (e) {
      // If session creation fails (500 on some servers) fall back to a
      // session-less strategy: repeatedly call the radio sample endpoint
      // GET /api/v1/radios/radios/{id}/tracks/ which many servers support.
      debugPrint('startRadio encountered error creating session: $e');

      try {
        // First attempt to get one track via the sample endpoint.
        final first = await _api.getRadioTrack(radioId);
        if (first == null) throw Exception('No radio sample track');

        _radioSessionId = null;
        _radioId = radioId;

        await playTracks([first], source: 'radio-fallback');
        state = state.copyWith(clearLoadingRadioId: true);
        try {
          Aptabase.instance.trackEvent('radio_started', {
            'radio_id': radioId,
            'source': 'fallback',
          });
        } catch (_) {}

        // Prefetch only one upcoming track using the sample endpoint.
        try {
          final t = await _api.getRadioTrack(radioId);
          if (t != null) addToQueue([t]);
        } catch (_) {}

        // Periodic fetcher to keep queue populated.
        _radioFetchTimer?.cancel();
        _radioFetchTimer = Timer.periodic(const Duration(seconds: 4), (
          _,
        ) async {
          try {
            // Keep exactly one track ahead of the currently playing track.
            final ahead = state.queue.length - state.currentIndex - 1;
            if (ahead < 1) {
              final t = await _api.getRadioTrack(radioId);
              if (t != null) addToQueue([t]);
            }
          } catch (_) {
            try {
              Aptabase.instance.trackEvent('radio_fetch_error', {
                'radio_id': radioId,
              });
            } catch (_) {}
            // ignore repeated failures
          }
        });
        return;
      } catch (fallbackErr) {
        // Fallback failed silently.
      }
    }
  }

  /// Stop radio background fetcher and clear radio session state. Does not
  /// modify the current queue so the user can keep listening if desired.
  Future<void> stopRadio() async {
    _radioFetchTimer?.cancel();
    _radioFetchTimer = null;
    _radioSessionId = null;
    _radioId = null;
    _isPrefetchingRadioTrack = false;
    try {
      Aptabase.instance.trackEvent('radio_stopped');
    } catch (_) {}
  }

  Future<void> _maybePrefetchRadioTrack() async {
    if (_radioSessionId == null && _radioId == null) return;
    if (_isPrefetchingRadioTrack) return;
    if (state.currentIndex < state.queue.length - 1) return;

    _isPrefetchingRadioTrack = true;

    try {
      if (_radioSessionId != null) {
        final raw = await _api.postNextRadioTrackRaw(_radioSessionId!);
        final t = await _parseTrackFromRaw(raw);
        if (t != null) addToQueue([t]);
      } else if (_radioId != null) {
        final t = await _api.getRadioTrack(_radioId!);
        if (t != null) addToQueue([t]);
      }
    } catch (_) {}

    _isPrefetchingRadioTrack = false;
  }

  /// Play a list of tracks starting at the given index.
  Future<void> playTracks(
    List<Track> tracks, {
    int startIndex = 0,
    String? source,
  }) async {
    if (tracks.isEmpty) {
      _gaplessActive = false;
      state = const PlayerState();
      await _handler.audioPlayer.stop();
      await QueuePersistenceService.clearQueue();
      return;
    }

    _pendingRestorePosition = null;
    state = state.copyWith(
      queue: tracks,
      currentIndex: startIndex,
      isLoading: true,
    );

    if (_isGaplessEnabled) {
      final loaded = await _loadGaplessSource(startIndex);
      if (loaded) {
        await _handler.audioPlayer.play();
        state = state.copyWith(isLoading: false);
        try {
          await _api.recordListening(tracks[startIndex].id);
        } catch (_) {}
      } else {
        // Fall back to single-track loading.
        await _loadAndPlay(tracks[startIndex]);
      }
    } else {
      _gaplessActive = false;
      await _loadAndPlay(tracks[startIndex]);
    }

    _saveQueue();

    // Pre-cache cover art and audio for queued tracks in the background.
    _preCacheCoverArt(tracks);
    _preCacheAudio(tracks, startIndex);
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
    // Sync gapless source.
    if (_gaplessActive) {
      for (final track in tracks) {
        _audioSourceForTrack(track).then(
          (source) => _handler.audioPlayer.addAudioSource(source),
          onError: (_) {},
        );
      }
    }
    _saveQueue();
    Aptabase.instance.trackEvent('add_to_queue', {'count': tracks.length});
  }

  /// Insert a track to play next.
  void playNext(Track track) {
    if (state.queue.isEmpty) {
      playTracks([track], source: 'play_next');
      return;
    }
    final insertIndex = state.currentIndex + 1;
    final newQueue = List<Track>.from(state.queue);
    newQueue.insert(insertIndex, track);
    state = state.copyWith(queue: newQueue);
    // Sync gapless source.
    if (_gaplessActive) {
      _audioSourceForTrack(track).then(
        (source) => _handler.audioPlayer.insertAudioSource(insertIndex, source),
        onError: (_) {},
      );
    }
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
    // Sync gapless source.
    if (_gaplessActive) {
      _handler.audioPlayer.removeAudioSourceAt(index);
    }
    _saveQueue();
    Aptabase.instance.trackEvent('remove_from_queue');
  }

  /// Reorder tracks in the queue.
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.queue.length) return;
    if (newIndex < 0 || newIndex >= state.queue.length) return;

    final newQueue = List<Track>.from(state.queue);
    final track = newQueue.removeAt(oldIndex);

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    newQueue.insert(newIndex, track);

    var newCurrentIndex = state.currentIndex;
    if (oldIndex == state.currentIndex) {
      newCurrentIndex = newIndex;
    } else if (oldIndex < state.currentIndex &&
        newIndex >= state.currentIndex) {
      newCurrentIndex--;
    } else if (oldIndex > state.currentIndex &&
        newIndex <= state.currentIndex) {
      newCurrentIndex++;
    }

    state = state.copyWith(queue: newQueue, currentIndex: newCurrentIndex);
    // Sync gapless source.
    if (_gaplessActive) {
      _handler.audioPlayer.moveAudioSource(oldIndex, newIndex);
    }
    _saveQueue();
    Aptabase.instance.trackEvent('reorder_queue');
  }

  // ── Queue stash ─────────────────────────────────────────────────────────

  /// Snapshot the current queue + playback position, persist it as a stash,
  /// then clear the active queue so the user can play something else.
  Future<void> stashQueue() async {
    if (state.queue.isEmpty) return;

    final stash = StashedQueue(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      queue: List<Track>.from(state.queue),
      unshuffledQueue: List<Track>.from(state.unshuffledQueue),
      currentIndex: state.currentIndex,
      position: state.position,
      isShuffled: state.isShuffled,
      loopMode: _loopModeToString(state.loopMode),
      savedAt: DateTime.now(),
    );

    await QueuePersistenceService.addStash(stash);
    ref.invalidate(stashedQueuesProvider);
    try {
      Aptabase.instance.trackEvent('queue_stashed', {
        'track_count': state.queue.length,
      });
    } catch (_) {}

    // Clear the active queue.
    await playTracks([], source: 'stash');
  }

  /// Restore a previously stashed queue by [id], replacing the active queue.
  Future<void> restoreStash(String id) async {
    final stashes = await QueuePersistenceService.loadStashes();
    final stash = stashes.firstWhere(
      (s) => s.id == id,
      orElse: () => throw StateError('Stash not found'),
    );
    if (stash.queue.isEmpty) return;

    await QueuePersistenceService.removeStash(id);
    ref.invalidate(stashedQueuesProvider);
    try {
      Aptabase.instance.trackEvent('stash_restored');
    } catch (_) {}

    // Load the stashed tracks and seek to the saved position.
    await playTracks(
      stash.queue,
      startIndex: stash.currentIndex,
      source: 'stash_restore',
    );

    if (stash.position.inMilliseconds > 0) {
      await seekTo(stash.position);
    }
  }

  /// Delete a stash by [id] without restoring it.
  Future<void> deleteStash(String id) async {
    await QueuePersistenceService.removeStash(id);
    ref.invalidate(stashedQueuesProvider);
  }

  Future<void> _loadAndPlay(Track track, {Duration? initialPosition}) async {
    // Before loading a new track, record how long the currently-playing
    // track was listened to (so skips and partial listens are tracked
    // accurately). Ignore errors — this is non-critical.
    try {
      await _recordCurrentTrackListen(nextTrack: track);
    } catch (_) {}

    await _loadTrack(track, autoPlay: true, initialPosition: initialPosition);
  }

  /// Record the currently-playing track into local listen history using the
  /// player's current position as the listened duration. This is used to
  /// capture skipped/partial listens accurately.
  Future<void> _recordCurrentTrackListen({Track? nextTrack}) async {
    final current = state.currentTrack;
    if (current == null) return;

    // If the next track to load is the same as the current one (initial
    // load or reload), don't record a listen for it now.
    if (nextTrack != null && current.id == nextTrack.id) return;

    // Use the UI-updated position which tracks the player's position stream.
    final listenedSeconds = state.position.inSeconds;
    if (listenedSeconds <= 0) return; // nothing to record

    // Debounce duplicate records for the same track within a short window.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastMs = _lastRecordedAtMs[current.id];
    if (lastMs != null && nowMs - lastMs < 5000) return;
    try {
      await ListenHistoryService.recordListen(
        current,
        listenedSeconds: listenedSeconds,
      );
      _lastRecordedAtMs[current.id] = nowMs;
    } catch (_) {
      // Non-critical — swallow failures
    }
  }

  Future<void> _loadTrack(
    Track track, {
    required bool autoPlay,
    Duration? initialPosition,
  }) async {
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
        try {
          await _handler.audioPlayer.setAudioSource(
            AudioSource.uri(cachedFile.uri),
            initialPosition: initialPosition,
          );
        } catch (_) {
          try {
            await _handler.audioPlayer.setAudioSource(
              AudioSource.uri(Uri.file(cachedFile.path)),
              initialPosition: initialPosition,
            );
          } catch (_) {
            // Stream from server as a final fallback
            _handler.mediaItem.add(mediaItem);
            await _handler.audioPlayer.setAudioSource(
              AudioSource.uri(
                Uri.parse(streamUrl),
                headers: headers,
                tag: mediaItem.title,
              ),
              initialPosition: initialPosition,
            );
            if (autoPlay) {
              await _handler.audioPlayer.play();
            }
            return;
          }
        }

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
          initialPosition: initialPosition,
        );
        if (autoPlay) {
          await _handler.audioPlayer.play();
        }

        // Cache the audio file in the background for next time.
        _audioCache.cacheAudio(track, streamUrl, headers);
      }

      // Cache cover art in the background (fire-and-forget).
      final coverUrl = track.coverUrl;
      if (coverUrl != null) {
        _audioCache.cacheCoverArt(coverUrl);
      }

      // Record listening history only if auto-playing.
      if (autoPlay) {
        try {
          await _api.recordListening(track.id);
        } catch (_) {
          // Non-critical
        }
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
        _gaplessActive = false;
        state = const PlayerState();
      }
    }
  }

  /// Pre-cache cover art for all tracks in the queue (background, fire-and-forget).
  void _preCacheCoverArt(List<Track> tracks) {
    for (final track in tracks) {
      final coverUrl = track.coverUrl;
      if (coverUrl != null) {
        _audioCache.cacheCoverArt(coverUrl);
      }
    }
  }

  /// Pre-cache audio files for upcoming tracks in the queue so that
  /// subsequent tracks play from local storage without buffering.
  /// Downloads are sequential to avoid saturating the connection while the
  /// current track is still streaming.
  void _preCacheAudio(List<Track> tracks, int startIndex) {
    final headers = _api.authHeaders;
    // Cache the tracks *after* startIndex (the current track is already being
    // cached / played inside _loadTrack).
    final upcoming = tracks.skip(startIndex + 1);
    for (final track in upcoming) {
      final listenUrl = track.listenUrl;
      if (listenUrl != null) {
        final streamUrl = _api.getStreamUrl(listenUrl);
        _audioCache.cacheAudio(track, streamUrl, headers);
      }
    }
  }

  void _onTrackCompleted() {
    if (_gaplessActive) {
      // With gapless, the player's native loop mode handles LoopMode.one
      // and LoopMode.all.  ProcessingState.completed only fires for
      // LoopMode.off when the last track in the queue finishes.
      state = state.copyWith(isPlaying: false);
      _saveQueue();
      return;
    }

    // Record the completed track using its full duration. This handles the
    // case where _loadAndPlay (and thus _recordCurrentTrackListen) is never
    // called — e.g. the last track in the queue with LoopMode.off. It also
    // ensures the debounce window from a recent pause does not cause the
    // natural completion to be missed. The debounce timestamp is cleared so
    // the _recordCurrentTrackListen call inside _loadAndPlay (for the next
    // track) can still fire normally.
    final completedTrack = state.currentTrack;
    if (completedTrack != null) {
      final durationSeconds =
          state.duration.inSeconds > 0
              ? state.duration.inSeconds
              : completedTrack.duration;
      // Clear debounce so this forced record always goes through.
      _lastRecordedAtMs.remove(completedTrack.id);
      ListenHistoryService.recordListen(
        completedTrack,
        listenedSeconds: durationSeconds,
      );
      _lastRecordedAtMs[completedTrack.id] =
          DateTime.now().millisecondsSinceEpoch;
    }

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

  Future<void> play() async {
    // If the queue was just restored from storage, no audio source has been
    // loaded yet.  Load and play the current track, then seek to where the
    // user left off.
    if (_pendingRestorePosition != null) {
      final seekTo = _pendingRestorePosition!;
      _pendingRestorePosition = null;
      final track = state.currentTrack;
      if (track != null) {
        state = state.copyWith(isLoading: true);
        if (_isGaplessEnabled) {
          final loaded = await _loadGaplessSource(
            state.currentIndex,
            initialPosition: seekTo,
          );
          if (loaded) {
            await _handler.audioPlayer.play();
            state = state.copyWith(isLoading: false);
            return;
          }
        }
        await _loadAndPlay(track, initialPosition: seekTo);
        return;
      }
    }
    await _handler.play();
  }

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
    _pendingRestorePosition = null;

    if (_gaplessActive) {
      try {
        await _recordCurrentTrackListen();
      } catch (_) {}
      final newIndex = state.currentIndex + 1;
      state = state.copyWith(currentIndex: newIndex);
      _updateMediaItemForTrack(state.queue[newIndex]);
      await _handler.audioPlayer.seekToNext();
      try {
        await _api.recordListening(state.queue[newIndex].id);
      } catch (_) {}
    } else if (_isGaplessEnabled) {
      // Gapless was just turned on — build the full playlist from this track.
      final newIndex = state.currentIndex + 1;
      state = state.copyWith(currentIndex: newIndex, isLoading: true);
      final loaded = await _loadGaplessSource(newIndex);
      if (loaded) {
        await _handler.audioPlayer.play();
        state = state.copyWith(isLoading: false);
        try {
          await _api.recordListening(state.queue[newIndex].id);
        } catch (_) {}
      } else {
        await _loadAndPlay(state.queue[newIndex]);
      }
    } else {
      final newIndex = state.currentIndex + 1;
      state = state.copyWith(currentIndex: newIndex, isLoading: true);
      await _loadAndPlay(state.queue[newIndex]);
    }

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

    _pendingRestorePosition = null;

    if (_gaplessActive) {
      try {
        await _recordCurrentTrackListen();
      } catch (_) {}
      final newIndex = state.currentIndex - 1;
      state = state.copyWith(currentIndex: newIndex);
      _updateMediaItemForTrack(state.queue[newIndex]);
      await _handler.audioPlayer.seekToPrevious();
      try {
        await _api.recordListening(state.queue[newIndex].id);
      } catch (_) {}
    } else {
      final newIndex = state.currentIndex - 1;
      state = state.copyWith(currentIndex: newIndex, isLoading: true);
      await _loadAndPlay(state.queue[newIndex]);
    }

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
    if (!state.isShuffled) {
      // Turning shuffle ON: save the original order, then shuffle
      final current = state.currentTrack;
      final newQueue = List<Track>.from(state.queue);
      if (current != null) newQueue.remove(current);
      newQueue.shuffle();
      if (current != null) newQueue.insert(0, current);
      state = state.copyWith(
        isShuffled: true,
        unshuffledQueue: List<Track>.from(state.queue),
        queue: newQueue,
        currentIndex: 0,
      );
    } else {
      // Turning shuffle OFF: restore the original order, keeping current track
      final current = state.currentTrack;
      final restored =
          state.unshuffledQueue.isNotEmpty
              ? List<Track>.from(state.unshuffledQueue)
              : List<Track>.from(state.queue);
      final newIndex =
          current != null ? restored.indexOf(current) : state.currentIndex;
      state = state.copyWith(
        isShuffled: false,
        unshuffledQueue: [],
        queue: restored,
        currentIndex: newIndex >= 0 ? newIndex : 0,
      );
    }
    // Rebuild gapless source with the new queue order, preserving the
    // current playback position so the transition is seamless.
    if (_gaplessActive) {
      final pos = _handler.audioPlayer.position;
      _loadGaplessSource(state.currentIndex, initialPosition: pos).then((ok) {
        if (ok) _handler.audioPlayer.play();
      });
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
    // Sync loop mode to the player when gapless is active so that
    // just_audio handles looping natively within the concatenation.
    if (_gaplessActive) {
      _handler.audioPlayer.setLoopMode(state.loopMode);
    }
    _saveQueue();
    Aptabase.instance.trackEvent('toggle_loop_mode', {
      'mode': state.loopMode.name,
    });
  }

  /// Jump to a specific index in the queue.
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    _pendingRestorePosition = null;

    if (_gaplessActive) {
      try {
        await _recordCurrentTrackListen();
      } catch (_) {}
      state = state.copyWith(currentIndex: index);
      _updateMediaItemForTrack(state.queue[index]);
      await _handler.audioPlayer.seek(Duration.zero, index: index);
      try {
        await _api.recordListening(state.queue[index].id);
      } catch (_) {}
    } else {
      state = state.copyWith(currentIndex: index, isLoading: true);
      await _loadAndPlay(state.queue[index]);
    }

    _saveQueue();
    Aptabase.instance.trackEvent('jump_to_queue', {'index': index});
  }
}
