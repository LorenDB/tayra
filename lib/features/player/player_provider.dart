import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:tayra/core/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/cache/audio_cache_service.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/features/favorites/favorites_provider.dart';
import 'package:tayra/features/player/playback_listen_tracker.dart';
import 'package:tayra/features/player/queue_persistence_service.dart';
import 'package:tayra/features/settings/settings_provider.dart';

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
  final double playbackSpeed;
  final bool queueCompleted;

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
    this.playbackSpeed = 1.0,
    this.queueCompleted = false,
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
    double? playbackSpeed,
    bool? queueCompleted,
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
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      queueCompleted: queueCompleted ?? this.queueCompleted,
    );
  }
}

/// Current track id only. List rows should watch this instead of selecting on
/// [playerProvider] so position/duration ticks do not re-run selectors for
/// every visible [TrackListTile].
final currentPlayingTrackIdProvider = Provider<int?>((ref) {
  return ref.watch(playerProvider.select((s) => s.currentTrack?.id));
});

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

  /// Queue boundary flags — updated by PlayerNotifier so the OS media
  /// session doesn't advertise skip buttons that would be no-ops.
  bool hasNext = false;
  bool hasPrevious = false;

  /// Callback invoked when a track completes. The PlayerNotifier sets this
  /// to wire up its queue-advance / loop logic.
  void Function()? onTrackCompleted;

  FunkwhaleAudioHandler() {
    // Forward playback state to the OS media session.
    // handleError prevents a mid-stream PlayerException (e.g. network drop
    // while buffering) from closing the pipe and killing the OS notification.
    _player.playbackEventStream
        .map(_transformPlaybackEvent)
        .handleError((Object e) {
          debugPrint('FunkwhaleAudioHandler: playbackEventStream error: $e');
        })
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
    final controls = [
      if (hasPrevious) MediaControl.skipToPrevious,
      if (_player.playing) MediaControl.pause else MediaControl.play,
      if (hasNext) MediaControl.skipToNext,
    ];
    return PlaybackState(
      controls: controls,
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: List.generate(controls.length, (i) => i),
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

  /// Callback invoked when the user explicitly pauses via external media
  /// controls (e.g. earbud button, notification). The PlayerNotifier sets
  /// this to prevent spurious interruption events from auto-resuming.
  void Function()? onUserPaused;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() {
    onUserPaused?.call();
    return _player.pause();
  }

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
      androidStopForegroundOnPause: false,
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
  late final PlaybackListenTracker _listenTracker;
  final List<StreamSubscription> _subscriptions = [];

  /// Position to seek to the first time play() is called after a queue
  /// restore.  Set by [_restoreQueue] and cleared once the seek is done.
  Duration? _pendingRestorePosition;

  /// Listen session to resume after a queue restore. Consumed by the first
  /// [_activateListenForTrack] call that matches the session's track ID.
  PersistedListenSession? _pendingRestoreListenSession;

  /// If the active queue was restored from a stash, keep that stash's name
  /// here so re-stashing the same active queue preserves the name.
  String? _activeStashName;

  /// Whether the player currently has a multi-source gapless playlist
  /// loaded via [AudioPlayer.setAudioSources].
  bool _gaplessActive = false;

  /// Watchdog timer that fires if the player stays in loading/buffering for
  /// too long without transitioning to ready.  Restarted on every buffering
  /// event; cancelled when the player reaches a non-buffering state.
  Timer? _bufferingWatchdog;

  /// Timestamp recorded when the app enters the background (paused lifecycle
  /// state). Used by [onAppResumed] to detect stale audio sources.
  DateTime? _appPausedAt;

  /// Whether playback was active when an audio interruption (e.g. phone call)
  /// began. Used to decide whether to auto-resume when the interruption ends.
  bool _wasPlayingBeforeInterruption = false;

  /// Whether an audio interruption is currently in progress.
  bool _interrupted = false;

  /// When true, ignore [AudioPlayer.currentIndexStream] updates. Set around
  /// queue reorders so a transient player index doesn't get treated as a
  /// track change (which would desync UI / re-record listens mid-song).
  bool _ignorePlayerIndexUpdates = false;

  /// Whether the user explicitly paused playback (via UI or external media
  /// controls). Prevents spurious interruption events and radio-timer
  /// recovery from auto-resuming after the user's intentional pause.
  bool _userPaused = false;

  /// Whether the loaded audio source is in a broken state (e.g. a mid-stream
  /// network drop or a failed load). The next call to [play] will reload the
  /// current track from its position instead of trying to resume the stale
  /// source, which would be a no-op and leave the user unable to recover
  /// without restarting the app.
  bool _needsReload = false;

  /// Last position (in whole seconds) at which the queue was saved.
  /// Prevents multiple saves within the same 2-second window.
  int _lastSavedPositionSeconds = -1;

  /// Last time we published a position update into [PlayerState] for UI.
  DateTime? _lastPositionUiPublish;
  static const Duration _positionUiMinInterval = Duration(milliseconds: 200);

  @override
  PlayerState build() {
    _handler = ref.read(audioHandlerProvider);
    _audioCache = ref.read(audioCacheServiceProvider);
    _listenTracker = PlaybackListenTracker(
      onSessionPersisted: (trackId, recordId, persistedSeconds, listenedAt) {
        QueuePersistenceService.saveListenSession(
          trackId: trackId,
          recordId: recordId,
          persistedSeconds: persistedSeconds,
          listenedAt: listenedAt,
        );
      },
    );
    _init();
    Future.microtask(() => _restoreQueue());
    Future.microtask(() => _loadPlaybackSpeed());
    ref.onDispose(() {
      unawaited(
        _listenTracker.dispose(position: _handler.audioPlayer.position),
      );
      for (final sub in _subscriptions) {
        sub.cancel();
      }
      _bufferingWatchdog?.cancel();
      _bufferingWatchdog = null;
      _radioFetchTimer?.cancel();
      _radioFetchTimer = null;
    });
    return const PlayerState();
  }

  AudioPlayer get audioPlayer => _handler.audioPlayer;

  @override
  set state(PlayerState value) {
    super.state = value;
    _handler.hasNext = value.hasNext;
    _handler.hasPrevious = value.hasPrevious;
  }

  void _init() {
    // Note: API and browse mode are injected in main.dart before runApp,
    // so the handler works even when launched directly from Android Auto.

    // Wire up Android Auto playback to our queue logic.
    _handler.onPlayTracks = (tracks, {int startIndex = 0}) async {
      await playTracks(tracks, startIndex: startIndex);
    };

    // Wire up OS skip buttons and Wear OS commands to our queue logic.
    _handler.onCustomAction = (name, extras) {
      switch (name) {
        case 'skipNext':
          skipNext();
          break;
        case 'skipPrevious':
          skipPrevious();
          break;
        case 'startPlaylist':
          _handleWearStartPlaylist(extras);
          break;
        case 'startPlaylistShuffled':
          _handleWearStartPlaylistShuffled(extras);
          break;
        case 'startRadio':
          _handleWearStartRadio(extras);
          break;
        case 'startRadioShuffled':
          _handleWearStartRadioShuffled(extras);
          break;
        case 'startInstanceRadio':
          _handleWearStartInstanceRadio(extras);
          break;
        case 'startInstanceRadioShuffled':
          _handleWearStartInstanceRadioShuffled(extras);
          break;
        case 'requestBrowseData':
          _handleWearRequestBrowseData();
          break;
        case 'toggleFavorite':
          _handleWearToggleFavorite();
          break;
      }
    };

    // Wire up track completion.
    _handler.onTrackCompleted = _onTrackCompleted;

    // Prevent spurious interruption events from auto-resuming after the user
    // explicitly pauses via external media controls (earbuds, notification).
    _handler.onUserPaused = () {
      _userPaused = true;
    };

    // Listen to playback state.
    _subscriptions.add(
      _handler.audioPlayer.playingStream.listen((isPlaying) async {
        // In gapless mode the player's playing flag stays true after the
        // queue completes (it's an intent flag on ConcatenatingAudioSource).
        // Guard against the playingStream overwriting isPlaying back to true
        // after _onTrackCompleted has set it to false.
        if (isPlaying && state.queueCompleted) {
          return;
        }
        state = state.copyWith(isPlaying: isPlaying);
        if (!isPlaying) {
          // Save position when paused
          _saveQueue();
          try {
            await _listenTracker.setPlaying(
              false,
              position: _handler.audioPlayer.position,
            );
          } catch (_) {}
        } else {
          try {
            await _listenTracker.setPlaying(
              true,
              position: _handler.audioPlayer.position,
            );
          } catch (_) {}
        }
      }),
    );

    // Listen to position. Throttle Riverpod UI updates (~5 Hz) so list
    // scrolling elsewhere isn't contending with 20–60 Hz state copies.
    // Persistence + listen tracking still use the true position cadence.
    _subscriptions.add(
      _handler.audioPlayer.positionStream.listen((position) {
        // When no audio source has been loaded yet (e.g. after a queue restore
        // on startup) the idle player emits zero positions. Ignore them so
        // they don't overwrite the restored position in the UI.
        if (_pendingRestorePosition != null) {
          return;
        }
        // When the queue has ended (not playing, at index 0, position already
        // reset) ignore any trailing position events from the completed player
        // so they don't overwrite the reset back to Duration.zero.
        if (!state.isPlaying &&
            state.currentIndex == 0 &&
            state.position == Duration.zero &&
            position > Duration.zero) {
          return;
        }

        final now = DateTime.now();
        final shouldPublishUi =
            _lastPositionUiPublish == null ||
            now.difference(_lastPositionUiPublish!) >= _positionUiMinInterval ||
            // Always publish near zero so "reset" states feel instant.
            position.inMilliseconds < 50 ||
            (position - state.position).inMilliseconds.abs() > 1500;
        if (shouldPublishUi) {
          _lastPositionUiPublish = now;
          state = state.copyWith(position: position);
        }

        // Save position/index only (not the full track list) every 2 seconds.
        // Full queue serialization is reserved for structural changes.
        final secs = position.inSeconds;
        if (secs % 2 == 0 && secs > 0 && secs != _lastSavedPositionSeconds) {
          _lastSavedPositionSeconds = secs;
          unawaited(_saveQueueProgress(position: position));
        }
        // Do not await — keep the position stream non-blocking for scroll/UI.
        unawaited(_listenTracker.updatePosition(position).catchError((_) {}));
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
      _handler.audioPlayer.playerStateStream.listen(
        (playerState) {
          final ps = playerState.processingState;
          debugPrint(
            'PlayerNotifier: processingState=$ps, playing=${playerState.playing}',
          );

          final isLoading =
              ps == ProcessingState.loading || ps == ProcessingState.buffering;
          state = state.copyWith(isLoading: isLoading);

          if (isLoading) {
            // Start / reset the watchdog: if still loading after 30 s, skip.
            _bufferingWatchdog?.cancel();
            _bufferingWatchdog = Timer(const Duration(seconds: 30), () {
              if (state.isLoading) {
                debugPrint(
                  'PlayerNotifier: track load timed out after 30 s '
                  '(processingState=$ps). Attempting recovery.',
                );
                _handler.audioPlayer.pause().catchError((_) {});
                state = state.copyWith(isLoading: false);
                // Do NOT auto-skip when a track stays stuck in loading/buffering.
                // Instead inform the user and pause playback so they can act.
                final ctx = shellNavigatorKey.currentContext;
                if (ctx != null) {
                  final title = state.currentTrack?.title ?? 'track';
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Unable to load "$title". Tap play to retry.',
                      ),
                    ),
                  );
                } else {
                  debugPrint(
                    'PlayerNotifier: no navigation context to show SnackBar',
                  );
                }
                // Ensure player is stopped and internal flags reflect paused state.
                _gaplessActive = false;
                // Source is likely stale; reload on next play().
                _needsReload = true;
                state = state.copyWith(isLoading: false, isPlaying: false);
              }
            });
          } else {
            _bufferingWatchdog?.cancel();
            _bufferingWatchdog = null;
          }
        },
        onError: (Object e) {
          debugPrint('PlayerNotifier: playerStateStream error: $e');
          _bufferingWatchdog?.cancel();
          _bufferingWatchdog = null;
          state = state.copyWith(isLoading: false);
        },
      ),
    );

    // Listen for PlayerException errors from just_audio (e.g. HTTP errors,
    // mid-stream network drops). These are separate from processingState
    // changes so the buffering watchdog never sees them.
    _subscriptions.add(
      _handler.audioPlayer.errorStream.listen((error) {
        debugPrint('PlayerNotifier: audioPlayer error: $error');
        _bufferingWatchdog?.cancel();
        _bufferingWatchdog = null;
        _gaplessActive = false;
        // Mark the source as broken so the next play() reloads it from the
        // current position instead of no-op'ing on the stale source.
        _needsReload = true;
        _handler.audioPlayer.pause().catchError((_) {});
        state = state.copyWith(isLoading: false, isPlaying: false);
        final ctx = shellNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          final title = state.currentTrack?.title ?? 'track';
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('Unable to play "$title". Tap play to retry.'),
            ),
          );
        }
      }),
    );

    _subscriptions.add(
      _handler.audioPlayer.currentIndexStream.listen((index) {
        // Skip while reordering — moveAudioSource can emit intermediate
        // indices that would otherwise look like a track change.
        if (_ignorePlayerIndexUpdates) return;

        // When gapless playback is active and the player auto-advances to a
        // new track (index changed without a manual skip), update our state.
        if (_gaplessActive &&
            index != null &&
            index != state.currentIndex &&
            index >= 0 &&
            index < state.queue.length) {
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

    _subscriptions.add(
      _handler.audioPlayer.positionDiscontinuityStream.listen((event) async {
        final previousIndex = event.previousEvent.currentIndex;
        final nextIndex = event.event.currentIndex;

        if (event.reason == PositionDiscontinuityReason.seek) {
          final isTrackChange =
              previousIndex != null &&
              nextIndex != null &&
              previousIndex != nextIndex;
          if (isTrackChange) {
            return;
          }

          try {
            await _listenTracker.handleSeek(
              previousPosition: event.previousEvent.updatePosition,
              newPosition: event.event.updatePosition,
            );
          } catch (_) {}
          return;
        }

        if (event.reason == PositionDiscontinuityReason.autoAdvance) {
          try {
            await _listenTracker.finalize(
              position: event.previousEvent.updatePosition,
            );
          } catch (_) {}

          _pendingRestoreListenSession = null;

          if (nextIndex != null &&
              nextIndex >= 0 &&
              nextIndex < state.queue.length) {
            try {
              await _listenTracker.activate(
                state.queue[nextIndex],
                position: event.event.updatePosition,
                isPlaying: _handler.audioPlayer.playing,
              );
            } catch (_) {}
          }
        }
      }),
    );

    // ── Audio session & interruption handling ─────────────────────────
    // just_audio manages AudioSession.configure/setActive internally.
    // We only listen for interruption / becomingNoisy events here.
    Future.microtask(() async {
      try {
        final session = await AudioSession.instance;

        _subscriptions.add(
          session.interruptionEventStream.listen((event) {
            if (event.begin) {
              _wasPlayingBeforeInterruption = state.isPlaying && !_userPaused;
              _interrupted = true;
              _userPaused = false;
              _handler.audioPlayer.pause();
            } else {
              // Only auto-resume if _interrupted is still true, meaning the
              // user hasn't manually resumed playback during the interruption
              // (play() clears _interrupted when the user explicitly acts).
              final shouldAutoResume = _interrupted && !_userPaused;
              _interrupted = false;
              _userPaused = false;
              switch (event.type) {
                case AudioInterruptionType.pause:
                case AudioInterruptionType.duck:
                  if (shouldAutoResume && _wasPlayingBeforeInterruption) {
                    play();
                  }
                  break;
                case AudioInterruptionType.unknown:
                  break;
              }
              _wasPlayingBeforeInterruption = false;
            }
          }),
        );

        _subscriptions.add(
          session.becomingNoisyEventStream.listen((_) {
            pause();
          }),
        );
      } catch (e) {
        debugPrint('PlayerNotifier: AudioSession init error: $e');
      }
    });

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

      // Derive duration from the saved state or from the track metadata.
      final currentTrack =
          validIndex >= 0 && validIndex < savedState.queue.length
              ? savedState.queue[validIndex]
              : null;
      final trackDuration =
          savedState.duration ??
          (currentTrack?.duration != null
              ? Duration(seconds: currentTrack!.duration!)
              : null);

      // Restore queue and playback state
      state = state.copyWith(
        queue: savedState.queue,
        unshuffledQueue: savedState.unshuffledQueue,
        currentIndex: validIndex,
        isShuffled: savedState.isShuffled,
        loopMode: _parseLoopMode(savedState.loopMode),
        position: savedState.position,
        duration: trackDuration ?? Duration.zero,
        queueCompleted: savedState.isCompleted,
      );

      // When the queue completed at save time, the persisted position is the
      // end of the last track — not a valid resume point. Reset to zero so
      // playback starts from the beginning of track 0 on restore.
      final restorePosition =
          savedState.isCompleted ? Duration.zero : savedState.position;

      // Restore the saved playback position so it can be seeked to once the
      // user taps play.  We intentionally do NOT call setAudioSource here
      // because just_audio will buffer a network stream indefinitely when
      // no play() follows, causing the UI to spin forever.
      //
      // _pendingRestorePosition being non-null is the signal that the audio
      // source has not been loaded yet.  We always set it (even to zero) so
      // that play() knows it must call _loadAndPlay first.
      _pendingRestorePosition = restorePosition;
      _pendingRestoreListenSession = savedState.listenSession;
    } catch (e) {
      // Failed to restore - clear corrupted state
      await QueuePersistenceService.clearQueue();
      _gaplessActive = false;
      state = const PlayerState();
    }
  }

  /// Save the current queue state to persistent storage.
  ///
  /// Call on structural changes (play new list, reorder, shuffle, etc.).
  /// For periodic position updates use [_saveQueueProgress] instead.
  Future<void> _saveQueue() async {
    if (state.queue.isEmpty) return;

    await QueuePersistenceService.saveQueue(
      queue: state.queue,
      unshuffledQueue: state.unshuffledQueue,
      currentIndex: state.currentIndex,
      position: state.position,
      duration: state.duration,
      isShuffled: state.isShuffled,
      loopMode: _loopModeToString(state.loopMode),
      isCompleted: state.queueCompleted,
    );
  }

  /// Persist only playback cursor fields — avoids re-encoding the full queue
  /// on every 2s position tick (major main-isolate hitch with long queues).
  ///
  /// Pass [position] from the live position stream; UI state may lag due to
  /// publish throttling and would under-report progress on kill/resume.
  Future<void> _saveQueueProgress({Duration? position}) async {
    if (state.queue.isEmpty) return;

    await QueuePersistenceService.savePlaybackProgress(
      currentIndex: state.currentIndex,
      position: position ?? state.position,
      duration: state.duration,
      isCompleted: state.queueCompleted,
    );
  }

  Future<void> _finalizeListenAt(Duration position) async {
    try {
      await _listenTracker.finalizeAt(position: position);
    } catch (_) {}
  }

  Future<void> _finalizeListenAtTrackEnd(Duration position) async {
    try {
      await _listenTracker.finalizeAt(
        position: position,
        forceAccumulate: true,
      );
    } catch (_) {}
  }

  Future<void> _finalizeCurrentListen() =>
      _finalizeListenAt(_handler.audioPlayer.position);

  Future<void> _activateListenForTrack(
    Track track, {
    Duration position = Duration.zero,
    bool? isPlaying,
  }) async {
    try {
      final resume =
          _pendingRestoreListenSession?.trackId == track.id
              ? _pendingRestoreListenSession
              : null;
      _pendingRestoreListenSession = null;
      await _listenTracker.activate(
        track,
        position: position,
        isPlaying: isPlaying ?? _handler.audioPlayer.playing,
        resume: resume,
      );
    } catch (_) {}
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

  /// True when the app should not rely on network streaming.
  bool get _isOffline => ref.read(offlineStateProvider).isOffline;

  /// Whether [track] can be started without the network (local audio file).
  bool _isTrackCached(Track track) {
    return ref.read(offlineTrackIdsProvider).contains(track.id);
  }

  /// Find the next (or previous) playable index in [queue].
  ///
  /// Online: any index is considered playable (may stream).
  /// Offline: only tracks with local audio. Returns null if none found
  /// in the given direction before leaving the list bounds.
  int? _findPlayableIndex(List<Track> queue, int from, {int step = 1}) {
    if (queue.isEmpty) return null;
    if (!_isOffline) {
      return (from >= 0 && from < queue.length) ? from : null;
    }
    final offlineIds = ref.read(offlineTrackIdsProvider);
    if (offlineIds.isEmpty) return null;
    for (var i = from; i >= 0 && i < queue.length; i += step) {
      if (offlineIds.contains(queue[i].id)) return i;
    }
    return null;
  }

  void _showOfflineUnavailableSnack(String? title) {
    final ctx = shellNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final label = (title != null && title.isNotEmpty) ? '"$title"' : 'track';
    ScaffoldMessenger.of(
      ctx,
    ).showSnackBar(SnackBar(content: Text('$label is not available offline')));
  }

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

    if (_isOffline) {
      throw Exception('Track ${track.id} not available offline');
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
    _needsReload = false;

    // Offline: gapless would mix stream URLs for uncached tracks and stall.
    // Force the single-track path which skips uncached items.
    if (_isOffline) {
      _gaplessActive = false;
      return false;
    }

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

      // Explicitly seek so the positionStream reliably reports the correct
      // position before play() is called (see comment in _loadTrack).
      if (initialPosition != null) {
        await _handler.audioPlayer.seek(initialPosition);
      }

      // Sync the player's loop mode so it can handle looping natively.
      _handler.audioPlayer.setLoopMode(state.loopMode);

      _gaplessActive = true;
      return true;
    } catch (e) {
      debugPrint('Failed to build gapless source: $e');
      _gaplessActive = false;
      // Source failed to load; reload on next play() attempt.
      _needsReload = true;
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
      Analytics.track('radio_start_requested', {'radio_id': radioId});
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
      Analytics.track('radio_session_created', {
        'radio_id': radioId,
        'used_session': true,
      });

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
      _startRadioFetchTimer();
      Analytics.track('radio_started', {
        'radio_id': radioId,
        'source': 'session',
      });
    } catch (e) {
      // If session creation fails (500 on some servers) fall back to a
      // session-less strategy: repeatedly call the radio sample endpoint
      // GET /api/v1/radios/radios/{id}/tracks/ which many servers support.
      debugPrint('startRadio encountered error creating session: $e');

      try {
        // First attempt to get one track via the sample endpoint.
        final first = await _api.getRadioTrack(radioId);
        _radioSessionId = null;
        _radioId = radioId;

        await playTracks([first], source: 'radio-fallback');
        state = state.copyWith(clearLoadingRadioId: true);
        Analytics.track('radio_started', {
          'radio_id': radioId,
          'source': 'fallback',
        });

        // Start the periodic radio fetch timer (also prefetches one track).
        _startRadioFetchTimer();
        return;
      } catch (fallbackErr) {
        state = state.copyWith(clearLoadingRadioId: true);
        debugPrint('startRadio fallback also failed: $fallbackErr');
      }
    }
  }

  /// Start an "instance" (built-in) radio such as 'random', 'favorites',
  /// or 'actor-content'. These radios are client-side presets that ask the
  /// server to create a session for the given radio_type string. [loadingId]
  /// is used only for UI loading state (can be a sentinel negative id).
  Future<void> startInstanceRadio(
    String radioType,
    int loadingId, {
    String? relatedObjectId,
  }) async {
    state = state.copyWith(loadingRadioId: loadingId);
    try {
      RadioSession session;
      try {
        final body = <String, dynamic>{'radio_type': radioType};
        if (relatedObjectId != null) {
          body['related_object_id'] = relatedObjectId;
        }
        session = await _api.createRadioSession(body);
      } on DioException catch (_) {
        // Retry with related_object_id as string if present (some servers
        // are picky about typing).
        try {
          final body = <String, dynamic>{'radio_type': radioType};
          if (relatedObjectId != null) {
            body['related_object_id'] = relatedObjectId.toString();
          }
          session = await _api.createRadioSession(body);
        } on DioException catch (e2) {
          debugPrint(
            'createInstanceRadioSession failed: ${e2.response?.statusCode} ${e2.response?.data}',
          );
          rethrow;
        }
      }

      _radioSessionId = session.id;
      _radioId = null;

      // Fetch the first track from the session and start playback.
      final rawFirst = await _api.postNextRadioTrackRaw(_radioSessionId!);
      final first = await _parseTrackFromRaw(rawFirst);
      if (first == null) {
        throw Exception('No track returned for instance radio');
      }

      await playTracks([first], source: 'instance-radio');
      state = state.copyWith(clearLoadingRadioId: true);
      _startRadioFetchTimer();
    } catch (e) {
      debugPrint('startInstanceRadio failed: $e');
      // Clear loading state on failure
      state = state.copyWith(clearLoadingRadioId: true);
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
    Analytics.track('radio_stopped');
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
        addToQueue([t]);
      }
    } catch (_) {
    } finally {
      _isPrefetchingRadioTrack = false;
    }
  }

  /// Periodic timer that keeps the radio queue populated and handles
  /// resuming playback when the gapless source runs dry before a fetch
  /// completes.
  void _startRadioFetchTimer() {
    _radioFetchTimer?.cancel();
    _radioFetchTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_isPrefetchingRadioTrack) return;
      try {
        // Keep at least one track ahead of the currently playing track.
        final ahead = state.queue.length - state.currentIndex - 1;
        if (ahead < 1) {
          _isPrefetchingRadioTrack = true;
          try {
            if (_radioSessionId != null) {
              final raw = await _api.postNextRadioTrackRaw(_radioSessionId!);
              final t = await _parseTrackFromRaw(raw);
              if (t != null) addToQueue([t]);
            } else if (_radioId != null) {
              final t = await _api.getRadioTrack(_radioId!);
              addToQueue([t]);
            }
          } finally {
            _isPrefetchingRadioTrack = false;
          }
        }

        // If playback stalled (gapless source ran dry before we could
        // append the next track), rebuild and resume.  Don't auto-resume
        // when the user explicitly paused playback.
        //
        // We gate on processingState == completed rather than just
        // !state.isPlaying so that a pause, an audio interruption, or a
        // brief playingStream flicker from a playback-device change on
        // Android (which can transiently report isPlaying=false while the
        // source stays in the ready state) doesn't spuriously resume the
        // radio.  Only a genuinely-exhausted gapless source ends up in the
        // completed state.
        if (_handler.audioPlayer.processingState == ProcessingState.completed &&
            state.hasNext &&
            _gaplessActive &&
            !_userPaused) {
          final nextIndex = state.currentIndex + 1;
          state = state.copyWith(currentIndex: nextIndex, isLoading: true);
          final loaded = await _loadGaplessSource(nextIndex);
          if (loaded) {
            await _handler.audioPlayer.play();
            state = state.copyWith(
              isLoading: false,
              isPlaying: _handler.audioPlayer.playing,
            );
            final track = state.queue[nextIndex];
            await _activateListenForTrack(track);
            try {
              await _api.recordListening(track.id);
            } catch (_) {}
            _saveQueue();
          }
        }
      } catch (_) {}
    });
  }

  /// Play a list of tracks starting at the given index.
  ///
  /// When [shuffle] is true, [tracks] is treated as the canonical
  /// (unshuffled) order: it is stored as the base queue
  /// ([PlayerState.unshuffledQueue]) and a shuffled view is derived for
  /// active playback. This keeps a single source of truth (the unshuffled
  /// list) so that toggling shuffle off later restores the original order
  /// rather than some stale previous queue.
  Future<void> playTracks(
    List<Track> tracks, {
    int startIndex = 0,
    String? source,
    Duration? initialPosition,
    bool shuffle = false,
  }) async {
    _userPaused = false;
    await _finalizeCurrentListen();

    const radioSources = {'radio', 'radio-fallback', 'instance-radio'};
    if (source == null || !radioSources.contains(source)) {
      await stopRadio();
    }

    if (tracks.isEmpty) {
      _gaplessActive = false;
      state = const PlayerState();
      await _handler.audioPlayer.stop();
      await QueuePersistenceService.clearQueue();
      // Clearing the active queue means it's no longer the restored stash.
      _activeStashName = null;
      return;
    }

    final safeStartIndex = startIndex.clamp(0, tracks.length - 1);

    if (state.queueCompleted) {
      state = state.copyWith(queueCompleted: false);
    }

    _pendingRestorePosition = null;
    // If this play request is not a stash restore, the active stash name
    // should not be preserved (we only keep it when restoring a stash).
    if (source != 'stash_restore') {
      _activeStashName = null;
    }

    // Build the active queue and shuffle state. When shuffle is requested,
    // [tracks] is the base (unshuffled) order; we derive a shuffled view for
    // playback while keeping the base as the source of truth. When not
    // shuffling, reset the shuffle state entirely so stale state from a
    // previous session never leaks into a fresh queue.
    final Track startTrack;
    final int newCurrentIndex;
    final List<Track> newQueue;
    final List<Track> newUnshuffledQueue;
    final bool newIsShuffled;
    if (shuffle) {
      final base = List<Track>.from(tracks);
      newUnshuffledQueue = base;
      newIsShuffled = true;
      if (safeStartIndex > 0 && safeStartIndex < tracks.length) {
        // Keep the requested start track at the front of the shuffled view
        // so playback begins from it, then shuffle the remainder.
        startTrack = tracks[safeStartIndex];
        final rest = List<Track>.from(tracks)..removeAt(safeStartIndex);
        rest.shuffle();
        newQueue = [startTrack, ...rest];
      } else {
        // Fully random order (matches the previous "Shuffle All" behaviour
        // where the first track was also randomised).
        newQueue = List<Track>.from(tracks)..shuffle();
        startTrack = newQueue.first;
      }
      newCurrentIndex = 0;
    } else {
      newQueue = List<Track>.from(tracks);
      newUnshuffledQueue = const [];
      newIsShuffled = false;
      newCurrentIndex = safeStartIndex;
      startTrack = tracks[safeStartIndex];
    }

    // Offline: start on the first track that has local audio at or after
    // the requested index (then wrap-search from 0). Keep the full queue so
    // the UI still shows everything the user selected.
    var effectiveIndex = newCurrentIndex;
    var effectiveStart = startTrack;
    if (_isOffline) {
      final playable =
          _findPlayableIndex(newQueue, newCurrentIndex) ??
          _findPlayableIndex(newQueue, 0);
      if (playable == null) {
        state = state.copyWith(
          queue: newQueue,
          unshuffledQueue: newUnshuffledQueue,
          isShuffled: newIsShuffled,
          currentIndex: newCurrentIndex,
          isLoading: false,
          isPlaying: false,
        );
        _gaplessActive = false;
        _showOfflineUnavailableSnack(startTrack.title);
        _saveQueue();
        return;
      }
      if (playable != newCurrentIndex) {
        effectiveIndex = playable;
        effectiveStart = newQueue[playable];
        if (!_isTrackCached(startTrack)) {
          _showOfflineUnavailableSnack(startTrack.title);
        }
      }
    }

    state = state.copyWith(
      queue: newQueue,
      unshuffledQueue: newUnshuffledQueue,
      isShuffled: newIsShuffled,
      currentIndex: effectiveIndex,
      isLoading: true,
    );

    if (_isGaplessEnabled && !_isOffline) {
      final loaded = await _loadGaplessSource(
        effectiveIndex,
        initialPosition: initialPosition,
      );
      if (loaded) {
        await _handler.audioPlayer.play();
        // Sync isPlaying immediately from the player rather than waiting for
        // playingStream to fire asynchronously — avoids a race where the button
        // briefly shows the wrong icon between play() returning and the stream
        // event arriving.
        state = state.copyWith(
          isLoading: false,
          isPlaying: _handler.audioPlayer.playing,
        );
        await _activateListenForTrack(effectiveStart);
        try {
          await _api.recordListening(effectiveStart.id);
        } catch (_) {}
      } else {
        // Fall back to single-track loading.
        await _loadAndPlay(effectiveStart, initialPosition: initialPosition);
      }
    } else {
      _gaplessActive = false;
      await _loadAndPlay(effectiveStart, initialPosition: initialPosition);
    }

    _saveQueue();

    // Pre-cache cover art and audio for queued tracks in the background.
    _preCacheCoverArt(newQueue);
    _preCacheAudio(newQueue, newCurrentIndex);
    Analytics.track('play_tracks', {
      'count': newQueue.length,
      'start_index': newCurrentIndex,
      'source': source ?? 'unknown',
      'shuffled': shuffle,
    });
  }

  /// Add tracks to the end of the queue.
  void addToQueue(List<Track> tracks) {
    if (tracks.isEmpty) return;
    state = state.copyWith(queue: [...state.queue, ...tracks]);
    // When shuffled, keep the base (unshuffled) queue in sync by appending
    // the same tracks so the source of truth contains every active track.
    if (state.isShuffled) {
      state = state.copyWith(
        unshuffledQueue: [...state.unshuffledQueue, ...tracks],
      );
    }
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
    Analytics.track('add_to_queue', {'count': tracks.length});
  }

  /// Insert tracks immediately after the current track so they play next.
  /// If the queue is empty, this replaces the queue and starts playback.
  void insertTracksNext(List<Track> tracks) {
    if (tracks.isEmpty) return;

    // If nothing is playing, replace the queue and start playback.
    if (state.queue.isEmpty || state.currentIndex < 0) {
      // Play the given tracks immediately (start at 0).
      playTracks(tracks, source: 'insert_next');
      return;
    }

    final insertIndex = state.currentIndex + 1;
    final newQueue = List<Track>.from(state.queue);
    newQueue.insertAll(insertIndex, tracks);
    state = state.copyWith(queue: newQueue);

    // Sync gapless source by inserting audio sources at the correct indices.
    if (_gaplessActive) {
      var idx = insertIndex;
      for (final track in tracks) {
        final capturedIdx = idx++;
        _audioSourceForTrack(track).then(
          (source) =>
              _handler.audioPlayer.insertAudioSource(capturedIdx, source),
          onError: (_) {},
        );
      }
    }

    // When shuffled, also reflect the insertion in the base (unshuffled)
    // queue so the source of truth stays consistent. Insert after the
    // current track's position in the base order.
    if (state.isShuffled) {
      final base = List<Track>.from(state.unshuffledQueue);
      final currentId = state.queue[state.currentIndex].id;
      final basePos = base.indexWhere((t) => t.id == currentId);
      base.insertAll(basePos >= 0 ? basePos + 1 : base.length, tracks);
      state = state.copyWith(unshuffledQueue: base);
    }

    _saveQueue();
    Analytics.track('insert_next', {'count': tracks.length});
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
    // When shuffled, keep the base queue in sync by inserting after the
    // current track's position in the base order.
    if (state.isShuffled) {
      final base = List<Track>.from(state.unshuffledQueue);
      final currentId = state.queue[state.currentIndex].id;
      final basePos = base.indexWhere((t) => t.id == currentId);
      base.insert(basePos >= 0 ? basePos + 1 : base.length, track);
      state = state.copyWith(unshuffledQueue: base);
    }
    _saveQueue();
    Analytics.track('play_next');
  }

  /// Remove track at index from the queue.
  void removeFromQueue(int index) {
    if (index < 0 || index >= state.queue.length) return;
    final wasCurrentTrack = index == state.currentIndex;
    final removedTrack = state.queue[index];
    final newQueue = List<Track>.from(state.queue);
    newQueue.removeAt(index);

    var newIndex = state.currentIndex;
    if (index < state.currentIndex) {
      newIndex--;
    } else if (wasCurrentTrack) {
      if (newIndex >= newQueue.length) newIndex = newQueue.length - 1;
    }

    // When shuffled, remove one matching entry from the base queue so the
    // source of truth stays consistent. Prefer identity, then first id match
    // — never strip every duplicate of the same id.
    List<Track> newUnshuffled = state.unshuffledQueue;
    if (state.isShuffled && newUnshuffled.isNotEmpty) {
      newUnshuffled = List<Track>.from(newUnshuffled);
      final byIdentity = newUnshuffled.indexWhere(
        (t) => identical(t, removedTrack),
      );
      if (byIdentity >= 0) {
        newUnshuffled.removeAt(byIdentity);
      } else {
        final byId = newUnshuffled.indexWhere((t) => t.id == removedTrack.id);
        if (byId >= 0) newUnshuffled.removeAt(byId);
      }
    }

    state = state.copyWith(
      queue: newQueue,
      unshuffledQueue: newUnshuffled,
      currentIndex: newIndex,
    );
    // Sync gapless source.
    if (_gaplessActive) {
      _handler.audioPlayer.removeAudioSourceAt(index);
    }
    // If the removed track was the one currently playing, start playing the
    // new current track (or stop if the queue became empty).
    if (wasCurrentTrack) {
      if (newQueue.isEmpty) {
        _handler.audioPlayer.stop();
        state = state.copyWith(isPlaying: false, isLoading: false);
      } else if (_gaplessActive) {
        unawaited(
          _handler.audioPlayer.seek(Duration.zero, index: newIndex).then((_) {
            return _handler.audioPlayer.play();
          }),
        );
      } else {
        unawaited(_loadAndPlay(newQueue[newIndex]));
      }
    }
    _saveQueue();
    Analytics.track('remove_from_queue');
  }

  /// Reorder tracks in the queue.
  ///
  /// [newIndex] uses insert-before semantics on the list *before* removal
  /// (same as [ReorderableListView]): `0` = front, `queue.length` = end.
  /// Moving the currently playing track only reshuffles the playlist; playback
  /// continues without a seek/restart.
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.queue.length) return;
    if (newIndex < 0 || newIndex > state.queue.length) return;

    // Convert insert-before index to the post-removal insert index used by
    // both Dart list.insert and just_audio's moveAudioSource (which does
    // `children.insert(newIndex, children.removeAt(oldIndex))`).
    // Passing queue.length (end drop) without this adjustment throws / desyncs
    // the native playlist because the valid range after removal is 0..length-1.
    var insertIndex = newIndex;
    if (oldIndex < newIndex) {
      insertIndex -= 1;
    }
    if (insertIndex == oldIndex) return; // no-op (e.g. last item → end)

    final newQueue = List<Track>.from(state.queue);
    final track = newQueue.removeAt(oldIndex);
    newQueue.insert(insertIndex, track);

    var newCurrentIndex = state.currentIndex;
    if (oldIndex == state.currentIndex) {
      // Currently-playing track moved — follow it so playback identity is kept.
      newCurrentIndex = insertIndex;
    } else if (oldIndex < state.currentIndex &&
        insertIndex >= state.currentIndex) {
      newCurrentIndex--;
    } else if (oldIndex > state.currentIndex &&
        insertIndex <= state.currentIndex) {
      newCurrentIndex++;
    }

    // Suppress player index stream while the playlist reshuffles so a
    // transient native index can't be misread as "skipped to next track".
    _ignorePlayerIndexUpdates = true;
    state = state.copyWith(queue: newQueue, currentIndex: newCurrentIndex);

    if (_gaplessActive) {
      unawaited(() async {
        try {
          // Reshuffles the playlist only — does not seek or restart the
          // currently playing item when that item is the one being moved.
          await _handler.audioPlayer.moveAudioSource(oldIndex, insertIndex);
        } catch (e, st) {
          debugPrint('reorderQueue moveAudioSource failed: $e');
          debugPrintStack(stackTrace: st);
        } finally {
          _ignorePlayerIndexUpdates = false;
          // Reconcile if the player settled on a different index for the
          // same playing track (should match, but be defensive).
          final playerIndex = _handler.audioPlayer.currentIndex;
          final current = state.currentTrack;
          if (playerIndex != null &&
              playerIndex != state.currentIndex &&
              playerIndex >= 0 &&
              playerIndex < state.queue.length &&
              current != null &&
              state.queue[playerIndex].id == current.id) {
            state = state.copyWith(currentIndex: playerIndex);
          }
        }
      }());
    } else {
      _ignorePlayerIndexUpdates = false;
    }
    _saveQueue();
    Analytics.track('reorder_queue');
  }

  // ── Queue stash ─────────────────────────────────────────────────────────

  /// Snapshot the current queue + playback position, persist it as a stash,
  /// then clear the active queue so the user can play something else.
  Future<void> stashQueue() async {
    if (state.queue.isEmpty) return;

    // After a cold restore the audio source is not loaded yet, so the player
    // position is typically zero while UI / pending restore hold the real
    // resume point. Prefer those over a stale player position.
    final Duration stashPosition;
    if (_pendingRestorePosition != null) {
      stashPosition = state.position;
    } else {
      final playerPos = _handler.audioPlayer.position;
      stashPosition = playerPos > Duration.zero ? playerPos : state.position;
    }

    final stash = StashedQueue(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      // Preserve the active stash name (if any) so re-stashing keeps it.
      queue: List<Track>.from(state.queue),
      name: _activeStashName,
      unshuffledQueue: List<Track>.from(state.unshuffledQueue),
      currentIndex: state.currentIndex,
      position: stashPosition,
      isShuffled: state.isShuffled,
      loopMode: _loopModeToString(state.loopMode),
      savedAt: DateTime.now(),
    );

    await QueuePersistenceService.addStash(stash);
    ref.invalidate(stashedQueuesProvider);
    Analytics.track('queue_stashed', {'track_count': state.queue.length});

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

    // Remember the stash name on the active queue so re-stashing preserves it.
    _activeStashName = stash.name;

    await QueuePersistenceService.removeStash(id);
    ref.invalidate(stashedQueuesProvider);
    Analytics.track('stash_restored');

    final safeIndex = stash.currentIndex.clamp(0, stash.queue.length - 1);

    // Load the stashed tracks without re-shuffling — stash.queue is already
    // the playback order that was saved.
    await playTracks(
      stash.queue,
      startIndex: safeIndex,
      source: 'stash_restore',
      initialPosition:
          stash.position.inMilliseconds > 0 ? stash.position : null,
    );

    // playTracks resets shuffle/loop; re-apply the stashed metadata so
    // unshuffle and loop controls behave correctly.
    final restoredLoop = _parseLoopMode(stash.loopMode);
    if (stash.isShuffled && stash.unshuffledQueue.isNotEmpty) {
      state = state.copyWith(
        isShuffled: true,
        unshuffledQueue: List<Track>.from(stash.unshuffledQueue),
        loopMode: restoredLoop,
      );
    } else {
      state = state.copyWith(loopMode: restoredLoop);
    }
    _handler.audioPlayer.setLoopMode(
      _gaplessActive ? state.loopMode : LoopMode.off,
    );
    _saveQueue();
  }

  /// Delete a stash by [id] without restoring it.
  Future<void> deleteStash(String id) async {
    await QueuePersistenceService.removeStash(id);
    ref.invalidate(stashedQueuesProvider);
  }

  Future<void> _loadAndPlay(Track track, {Duration? initialPosition}) async {
    await _loadTrack(track, autoPlay: true, initialPosition: initialPosition);
  }

  Future<void> _loadTrack(
    Track track, {
    required bool autoPlay,
    Duration? initialPosition,
  }) async {
    _needsReload = false;
    try {
      final listenUrl = track.listenUrl;
      if (listenUrl == null) {
        debugPrint(
          'PlayerNotifier._loadTrack: track ${track.id} "${track.title}" has no listen URL '
          '(uploads: ${track.uploads.length})',
        );
        throw Exception('Track has no listen URL');
      }

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

      _handler.mediaItem.add(mediaItem);

      // Check audio cache first — play from local file if available.
      final cachedFile = await _audioCache.getCachedAudio(track);
      // Whether we ultimately streamed from server (so we know to kick off
      // background caching after playback starts).
      bool streamedFromServer = false;

      if (cachedFile != null) {
        // Try both URI forms for the cached file; fall back to streaming on
        // failure.  This handles edge cases where the URI scheme doesn't match
        // what the platform audio player accepts.
        bool loadedFromCache = false;
        try {
          debugPrint(
            'PlayerNotifier._loadTrack: track ${track.id} — trying cached URI ${cachedFile.uri}',
          );
          await _handler.audioPlayer.setAudioSource(
            AudioSource.uri(cachedFile.uri),
            initialPosition: initialPosition,
          );
          loadedFromCache = true;
        } catch (e1) {
          debugPrint(
            'PlayerNotifier._loadTrack: cached URI failed ($e1), trying file path ${cachedFile.path}',
          );
          try {
            await _handler.audioPlayer.setAudioSource(
              AudioSource.uri(Uri.file(cachedFile.path)),
              initialPosition: initialPosition,
            );
            loadedFromCache = true;
          } catch (e2) {
            debugPrint(
              'PlayerNotifier._loadTrack: cached file path also failed ($e2), '
              'falling back to server stream for track ${track.id}',
            );
          }
        }

        if (!loadedFromCache) {
          if (_isOffline) {
            throw Exception('Cached audio unreadable offline for ${track.id}');
          }
          // Both cached attempts failed — stream from server.
          debugPrint(
            'PlayerNotifier._loadTrack: streaming track ${track.id} from server: $streamUrl',
          );
          await _handler.audioPlayer.setAudioSource(
            AudioSource.uri(
              Uri.parse(streamUrl),
              headers: headers,
              tag: mediaItem.title,
            ),
            initialPosition: initialPosition,
          );
          streamedFromServer = true;
        } else {
          debugPrint(
            'PlayerNotifier._loadTrack: loaded track ${track.id} from cache',
          );
        }
      } else if (_isOffline) {
        // Not cached and offline — do not attempt a network stream.
        throw Exception('Track ${track.id} not available offline');
      } else {
        // Not cached — stream from server.
        debugPrint(
          'PlayerNotifier._loadTrack: streaming track ${track.id} from server: $streamUrl',
        );
        await _handler.audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(streamUrl),
            headers: headers,
            tag: mediaItem.title,
          ),
          initialPosition: initialPosition,
        );
        streamedFromServer = true;
      }

      if (autoPlay) {
        // Explicitly seek after the source is loaded so the positionStream
        // reliably reports the correct position.  setAudioSource's
        // initialPosition does not always synchronously update the reported
        // position before play() is called, which causes a brief jump to zero.
        if (initialPosition != null) {
          await _handler.audioPlayer.seek(initialPosition);
        }
        await _handler.audioPlayer.play();
      }

      // Background-cache the audio file if we streamed it (fire-and-forget).
      if (streamedFromServer) {
        unawaited(_cacheAudioAndNotify(track, streamUrl, headers));
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

      try {
        await _activateListenForTrack(
          track,
          position: initialPosition ?? Duration.zero,
        );
      } catch (_) {}

      // Single-source path: app handles loop modes; clear any stuck native
      // loop left over from a previous gapless session.
      if (!_gaplessActive) {
        unawaited(_handler.audioPlayer.setLoopMode(LoopMode.off));
      }

      // Successfully loaded.
      state = state.copyWith(isLoading: false);
    } catch (e, st) {
      debugPrint(
        'PlayerNotifier._loadTrack: failed to load track ${track.id}: $e\n$st',
      );
      state = state.copyWith(isLoading: false);

      // Offline: skip forward to the next locally available track instead of
      // stalling the queue on a stream-only item.
      if (_isOffline && autoPlay && state.queue.isNotEmpty) {
        final next = _findPlayableIndex(state.queue, state.currentIndex + 1);
        if (next != null) {
          _showOfflineUnavailableSnack(track.title);
          state = state.copyWith(currentIndex: next, isLoading: true);
          await _loadAndPlay(state.queue[next]);
          return;
        }
      }

      // Do NOT auto-skip online. Show a SnackBar and pause playback so the
      // user can manually intervene (remove track, retry, etc.).
      final ctx = shellNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        final title = track.title;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              _isOffline
                  ? '"$title" is not available offline'
                  : 'Unable to load "$title". Playback paused.',
            ),
          ),
        );
      } else {
        debugPrint(
          'PlayerNotifier._loadTrack: no navigation context to show SnackBar',
        );
      }

      // Stop playback and ensure UI reflects the paused state.
      try {
        await _handler.audioPlayer.stop();
      } catch (_) {}
      _gaplessActive = false;
      // Source failed to load (e.g. no network); reload on next play().
      _needsReload = true;
      state = state.copyWith(isPlaying: false);
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
    if (_isOffline) return;
    final headers = _api.authHeaders;
    // Cache the tracks *after* startIndex (the current track is already being
    // cached / played inside _loadTrack).
    final upcoming = tracks.skip(startIndex + 1);
    for (final track in upcoming) {
      final listenUrl = track.listenUrl;
      if (listenUrl != null) {
        final streamUrl = _api.getStreamUrl(listenUrl);
        unawaited(_cacheAudioAndNotify(track, streamUrl, headers));
      }
    }
  }

  /// Cache audio and update the bulk cached-ID set so list indicators refresh
  /// without a per-row disk scan.
  Future<void> _cacheAudioAndNotify(
    Track track,
    String streamUrl,
    Map<String, String> headers,
  ) async {
    final file = await _audioCache.cacheAudio(track, streamUrl, headers);
    if (file != null) {
      ref.read(cachedAudioTrackIdsProvider.notifier).add(track.id);
    }
  }

  void _onTrackCompleted() {
    if (_gaplessActive) {
      final completedTrack = state.currentTrack;
      if (completedTrack != null) {
        final endPosition =
            state.duration.inSeconds > 0
                ? state.duration
                : Duration(seconds: completedTrack.duration ?? 0);
        unawaited(_finalizeListenAtTrackEnd(endPosition));
      }

      // With gapless, the player's native loop mode handles LoopMode.one
      // and LoopMode.all.  ProcessingState.completed only fires for
      // LoopMode.off when the last track in the queue finishes.
      // just_audio's `playing` flag is an intent flag and stays true when
      // audio ends naturally on a ConcatenatingAudioSource, so playingStream
      // does not emit false automatically — we must set isPlaying ourselves.

      // In radio mode the gapless source may have run dry before the next
      // track was fetched and appended.  If the queue has already grown,
      // rebuild the source and resume; otherwise pause and let the periodic
      // radio timer fetch the next track.
      if (_radioSessionId != null || _radioId != null) {
        if (state.hasNext) {
          final nextIndex = state.currentIndex + 1;
          state = state.copyWith(currentIndex: nextIndex, isLoading: true);
          unawaited(
            _loadGaplessSource(nextIndex).then((loaded) {
              if (!loaded) {
                state = state.copyWith(isLoading: false, isPlaying: false);
                return;
              }
              _handler.audioPlayer.play();
              state = state.copyWith(
                isLoading: false,
                isPlaying: _handler.audioPlayer.playing,
              );
              final track = state.queue[nextIndex];
              _activateListenForTrack(track);
              _api.recordListening(track.id).catchError((_) {});
              _saveQueue();
            }),
          );
          return;
        }
        state = state.copyWith(isPlaying: false);
        return;
      }

      // Wrap back to track 0; the seek is deferred to play() so that we
      // don't accidentally resume playback (seeking while playing=true
      // on a ConcatenatingAudioSource restarts immediately).
      // Reset position to zero so it isn't persisted as the end-of-track
      // position, which would cause a seek to an arbitrary offset when
      // the queue is later restored from storage.
      state = state.copyWith(
        isPlaying: false,
        currentIndex: 0,
        position: Duration.zero,
        queueCompleted: true,
      );
      _saveQueue();
      return;
    }

    final completedTrack = state.currentTrack;
    if (completedTrack != null) {
      final endPosition =
          state.duration.inSeconds > 0
              ? state.duration
              : Duration(seconds: completedTrack.duration ?? 0);
      unawaited(_finalizeListenAtTrackEnd(endPosition));
    }

    switch (state.loopMode) {
      case LoopMode.one:
        _handler.audioPlayer.seek(Duration.zero);
        _handler.audioPlayer.play();
        if (completedTrack != null) {
          unawaited(_activateListenForTrack(completedTrack, isPlaying: false));
        }
        break;
      case LoopMode.all:
        if (state.hasNext) {
          skipNext();
        } else {
          state = state.copyWith(currentIndex: 0);
          _loadAndPlay(state.queue[0]);
          _saveQueue(); // Save state after looping back to start
        }
        break;
      case LoopMode.off:
        if (state.hasNext) {
          skipNext();
        } else if (_radioSessionId != null || _radioId != null) {
          // Radio mode with no next track yet — pause and let the timer
          // fetch more.  Don't reset currentIndex so the timer can resume
          // from the right position.
          state = state.copyWith(isPlaying: false, position: Duration.zero);
        } else {
          // Wrap back to track 0 so the play button resumes from the beginning.
          state = state.copyWith(
            isPlaying: false,
            currentIndex: 0,
            position: Duration.zero,
            queueCompleted: true,
          );
          // Don't touch the audio player here — play() already handles
          // ProcessingState.completed correctly (reloads or seeks as needed).
          // The completed player emits no new position events, so position: zero
          // in state above is stable and will hold until the user presses play.
          _saveQueue(); // Save final state when queue ends
        }
        break;
    }
  }

  Future<void> play() async {
    // User-initiated play always clears interruption / paused state.
    _interrupted = false;
    _userPaused = false;
    if (state.queueCompleted) {
      state = state.copyWith(queueCompleted: false);
    }

    // If the queue was just restored from storage, no audio source has been
    // loaded yet.  Load the current track, seek to where the user left off,
    // then play.
    if (_pendingRestorePosition != null) {
      final seekTo = _pendingRestorePosition!;
      final track = state.currentTrack;
      if (track != null) {
        state = state.copyWith(isLoading: true);
        if (_isGaplessEnabled) {
          final loaded = await _loadGaplessSource(
            state.currentIndex,
            initialPosition: seekTo,
          );
          if (loaded) {
            // Explicitly seek so the positionStream reports the right value.
            await _handler.audioPlayer.seek(seekTo);
            // Wait for the positionStream to confirm the seeked position
            // before dropping the guard, so no stale zero can overwrite it.
            await _handler.audioPlayer.positionStream
                .firstWhere((p) => p >= seekTo)
                .timeout(const Duration(seconds: 5), onTimeout: () => seekTo);
            _pendingRestorePosition = null;
            await _handler.audioPlayer.play();
            // Sync isPlaying immediately — same race fix as in playTracks().
            state = state.copyWith(
              isLoading: false,
              isPlaying: _handler.audioPlayer.playing,
              position: seekTo,
            );
            await _activateListenForTrack(track, position: seekTo);
            return;
          }
        }
        // Load without autoPlay so we can seek explicitly first.
        await _loadTrack(track, autoPlay: false, initialPosition: seekTo);
        // Source is loaded — explicitly seek to the restore position.
        await _handler.audioPlayer.seek(seekTo);
        // Wait for the positionStream to confirm the seeked position.
        await _handler.audioPlayer.positionStream
            .firstWhere((p) => p >= seekTo)
            .timeout(const Duration(seconds: 5), onTimeout: () => seekTo);
        // Guard is no longer needed — the positionStream just confirmed
        // the correct position.
        _pendingRestorePosition = null;
        // Start playback.
        await _handler.audioPlayer.play();
        state = state.copyWith(
          isLoading: false,
          isPlaying: _handler.audioPlayer.playing,
          position: seekTo,
        );
        unawaited(_activateListenForTrack(track, position: seekTo));
        try {
          await _api.recordListening(track.id);
        } catch (_) {}
        return;
      }
    }
    // If the audio source is in ProcessingState.completed (queue ended with
    // LoopMode.off), _handler.play() is a no-op. Resume from track 0 instead.
    if (_handler.audioPlayer.processingState == ProcessingState.completed) {
      final track = state.currentTrack;
      if (track != null) {
        if (_gaplessActive) {
          // For gapless, seeking on the ConcatenatingAudioSource to index 0
          // resets the completed state; since just_audio's playing intent is
          // still true the seek will resume playback automatically.
          await _handler.audioPlayer.seek(
            Duration.zero,
            index: state.currentIndex,
          );
          state = state.copyWith(isPlaying: _handler.audioPlayer.playing);
          _updateMediaItemForTrack(track);
          unawaited(_activateListenForTrack(track));
        } else {
          state = state.copyWith(isLoading: true);
          await _loadAndPlay(track);
        }
        return;
      }
    }

    // If the previously loaded source broke (e.g. a mid-stream network drop
    // or a failed load), resuming via _handler.play() would be a no-op on the
    // stale source. Reload the current track from its position so the user
    // can recover without restarting the app.
    if (_needsReload) {
      final track = state.currentTrack;
      if (track != null) {
        _needsReload = false;
        state = state.copyWith(isLoading: true);
        final position = _handler.audioPlayer.position;
        await _loadAndPlay(track, initialPosition: position);
        return;
      }
      _needsReload = false;
    }

    await _handler.play();
  }

  Future<void> pause() {
    _userPaused = true;
    return _handler.pause();
  }

  /// Called when the app enters the background (paused/inactive lifecycle).
  void onAppPaused() {
    _appPausedAt = DateTime.now();
  }

  /// Called when the app returns to the foreground (resumed lifecycle).
  ///
  /// If the audio player is stuck in loading/buffering after a meaningful
  /// background period (≥ 3 s), the underlying network connection is likely
  /// stale.  We cancel the watchdog and reload the current track so the user
  /// doesn't have to wait for the 30-second timeout or restart the app.
  Future<void> onAppResumed() async {
    // Clear any lingering interruption flag. Android's audio-focus system can
    // fire an interruptionEvent.begin while the app is backgrounded (treating
    // it as an audio interruption), which sets _interrupted = true. If that
    // "interruption" never resolves with an end event (e.g. the app sat in the
    // background long enough for the event to be missed), play() would silently
    // refuse every tap.  The user returning to the app is a reliable signal
    // that any previous interruption is over.
    _interrupted = false;

    final pausedAt = _appPausedAt;
    _appPausedAt = null;
    if (pausedAt == null) return;

    final backgroundDuration = DateTime.now().difference(pausedAt);
    final ps = _handler.audioPlayer.processingState;
    final stuckLoading =
        state.isLoading ||
        ps == ProcessingState.loading ||
        ps == ProcessingState.buffering;

    if (backgroundDuration.inSeconds >= 3 && stuckLoading) {
      debugPrint(
        'PlayerNotifier.onAppResumed: stuck loading after '
        '${backgroundDuration.inSeconds}s in background — reloading track',
      );
      final track = state.currentTrack;
      if (track != null) {
        _bufferingWatchdog?.cancel();
        _bufferingWatchdog = null;
        final position = _handler.audioPlayer.position;
        await _loadAndPlay(track, initialPosition: position);
      }
    }
  }

  Future<void> togglePlayPause() async {
    // Capture intent before the await so the analytics event reflects what the
    // user actually tapped rather than the (potentially stale) post-await state.
    final wasPlaying = state.isPlaying;
    if (wasPlaying) {
      await pause();
    } else {
      await play();
    }
    Analytics.track('toggle_play_pause', {
      'action': wasPlaying ? 'pause' : 'play',
    });
  }

  Future<void> skipNext() async {
    if (!state.hasNext && !(_isOffline && state.queue.isNotEmpty)) return;
    _userPaused = false;
    _pendingRestorePosition = null;
    if (state.queueCompleted) {
      state = state.copyWith(queueCompleted: false);
    }
    await _finalizeCurrentListen();

    // Offline: jump to the next track that has local audio.
    if (_isOffline) {
      final newIndex = _findPlayableIndex(state.queue, state.currentIndex + 1);
      if (newIndex == null) {
        state = state.copyWith(isPlaying: false, queueCompleted: true);
        _saveQueue();
        return;
      }
      _gaplessActive = false;
      state = state.copyWith(currentIndex: newIndex, isLoading: true);
      await _loadAndPlay(state.queue[newIndex]);
      _saveQueue();
      Analytics.track('skip_next');
      return;
    }

    if (_gaplessActive) {
      final newIndex = state.currentIndex + 1;
      if (newIndex >= state.queue.length) return;
      state = state.copyWith(currentIndex: newIndex);
      _updateMediaItemForTrack(state.queue[newIndex]);
      try {
        await _handler.audioPlayer.seekToNext();
      } catch (_) {
        // The gapless source may not yet have the next child (e.g. radio
        // tracks are added asynchronously).  Rebuild from the queue.
        state = state.copyWith(isLoading: true);
        final loaded = await _loadGaplessSource(newIndex);
        if (loaded) {
          await _handler.audioPlayer.play();
          state = state.copyWith(
            isLoading: false,
            isPlaying: _handler.audioPlayer.playing,
          );
        } else {
          state = state.copyWith(isLoading: false);
          return;
        }
      }
      await _activateListenForTrack(state.queue[newIndex]);
      try {
        await _api.recordListening(state.queue[newIndex].id);
      } catch (_) {}
    } else if (_isGaplessEnabled) {
      // Gapless was just turned on — build the full playlist from this track.
      final newIndex = state.currentIndex + 1;
      if (newIndex >= state.queue.length) return;
      state = state.copyWith(currentIndex: newIndex, isLoading: true);
      final loaded = await _loadGaplessSource(newIndex);
      if (loaded) {
        await _handler.audioPlayer.play();
        // Sync isPlaying immediately — same race fix as in playTracks().
        state = state.copyWith(
          isLoading: false,
          isPlaying: _handler.audioPlayer.playing,
        );
        await _activateListenForTrack(state.queue[newIndex]);
        try {
          await _api.recordListening(state.queue[newIndex].id);
        } catch (_) {}
      } else {
        await _loadAndPlay(state.queue[newIndex]);
      }
    } else {
      final newIndex = state.currentIndex + 1;
      if (newIndex >= state.queue.length) return;
      state = state.copyWith(currentIndex: newIndex, isLoading: true);
      await _loadAndPlay(state.queue[newIndex]);
    }

    _saveQueue();
    Analytics.track('skip_next');
  }

  Future<void> skipPrevious() async {
    if (state.position.inSeconds > 3) {
      await _handler.audioPlayer.seek(Duration.zero);
      return;
    }
    if (!state.hasPrevious && !(_isOffline && state.queue.isNotEmpty)) {
      await _handler.audioPlayer.seek(Duration.zero);
      return;
    }

    _userPaused = false;
    _pendingRestorePosition = null;
    if (state.queueCompleted) {
      state = state.copyWith(queueCompleted: false);
    }
    await _finalizeCurrentListen();

    // Offline: jump to the previous track that has local audio.
    if (_isOffline) {
      final newIndex = _findPlayableIndex(
        state.queue,
        state.currentIndex - 1,
        step: -1,
      );
      if (newIndex == null) {
        await _handler.audioPlayer.seek(Duration.zero);
        return;
      }
      _gaplessActive = false;
      state = state.copyWith(currentIndex: newIndex, isLoading: true);
      await _loadAndPlay(state.queue[newIndex]);
      _saveQueue();
      Analytics.track('skip_previous');
      return;
    }

    if (_gaplessActive) {
      final newIndex = state.currentIndex - 1;
      state = state.copyWith(currentIndex: newIndex);
      _updateMediaItemForTrack(state.queue[newIndex]);
      await _handler.audioPlayer.seekToPrevious();
      await _activateListenForTrack(state.queue[newIndex]);
      try {
        await _api.recordListening(state.queue[newIndex].id);
      } catch (_) {}
    } else {
      final newIndex = state.currentIndex - 1;
      state = state.copyWith(currentIndex: newIndex, isLoading: true);
      await _loadAndPlay(state.queue[newIndex]);
    }

    _saveQueue();
    Analytics.track('skip_previous');
  }

  Future<void> seekTo(Duration position) async {
    await _handler.seek(position);
    _saveQueue(); // Save position
    Analytics.track('seek', {'position_seconds': position.inSeconds});
  }

  void toggleShuffle() {
    if (state.queue.isEmpty) return;

    final oldQueue = List<Track>.from(state.queue);

    if (!state.isShuffled) {
      // Turning shuffle ON: save the original order, then shuffle
      final current = state.currentTrack;
      final newQueue = List<Track>.from(state.queue);
      if (current != null) newQueue.remove(current);
      newQueue.shuffle();
      if (current != null) newQueue.insert(0, current);
      state = state.copyWith(
        isShuffled: true,
        unshuffledQueue: List<Track>.from(oldQueue),
        queue: newQueue,
        currentIndex: 0,
      );
    } else {
      // Turning shuffle OFF: restore the original order, keeping current track.
      // Match by track id — after persistence restore, queue and unshuffled
      // lists are different instances so identity indexOf would fail.
      final current = state.currentTrack;
      final restored =
          state.unshuffledQueue.isNotEmpty
              ? List<Track>.from(state.unshuffledQueue)
              : List<Track>.from(state.queue);
      final newIndex =
          current != null
              ? restored.indexWhere((t) => t.id == current.id)
              : state.currentIndex;
      state = state.copyWith(
        isShuffled: false,
        unshuffledQueue: [],
        queue: restored,
        currentIndex: newIndex >= 0 ? newIndex : 0,
      );
    }

    // Reorder the gapless playlist in place via moveAudioSource so the
    // currently playing item is not reloaded (avoids stutter / seek-back).
    // Full setAudioSources rebuild was the previous approach and interrupted
    // playback even when initialPosition was preserved.
    if (_gaplessActive) {
      unawaited(_reorderGaplessPlaylist(oldQueue, state.queue));
    }

    _saveQueue();
    Analytics.track('toggle_shuffle', {'enabled': state.isShuffled});
  }

  /// Reorder the player's gapless sources from [oldQueue] order to
  /// [newQueue] order without reloading the currently playing item.
  ///
  /// Uses successive [AudioPlayer.moveAudioSource] calls (same primitive as
  /// [reorderQueue]). Falls back to a full [_loadGaplessSource] rebuild only
  /// if the queues cannot be matched (length mismatch or missing track).
  Future<void> _reorderGaplessPlaylist(
    List<Track> oldQueue,
    List<Track> newQueue,
  ) async {
    if (oldQueue.length != newQueue.length || oldQueue.isEmpty) {
      await _reloadGaplessPreservingPlayback();
      return;
    }

    // Map each new-queue slot to the index it currently occupies in the
    // player (oldQueue order). Prefer identity so duplicate track IDs keep
    // the correct source instance.
    final used = List<bool>.filled(oldQueue.length, false);
    final desiredOldIndices = <int>[];
    for (final track in newQueue) {
      var found = -1;
      for (var i = 0; i < oldQueue.length; i++) {
        if (!used[i] && identical(oldQueue[i], track)) {
          found = i;
          break;
        }
      }
      if (found < 0) {
        for (var i = 0; i < oldQueue.length; i++) {
          if (!used[i] && oldQueue[i].id == track.id) {
            found = i;
            break;
          }
        }
      }
      if (found < 0) {
        await _reloadGaplessPreservingPlayback();
        return;
      }
      used[found] = true;
      desiredOldIndices.add(found);
    }

    // Suppress index stream while the playlist reshuffles so intermediate
    // native indices are not treated as track changes.
    _ignorePlayerIndexUpdates = true;
    try {
      // arrangement[i] = original (oldQueue) index currently at player slot i
      final arrangement = List<int>.generate(oldQueue.length, (i) => i);
      for (var target = 0; target < desiredOldIndices.length; target++) {
        final want = desiredOldIndices[target];
        if (arrangement[target] == want) continue;
        final from = arrangement.indexOf(want);
        await _handler.audioPlayer.moveAudioSource(from, target);
        final item = arrangement.removeAt(from);
        arrangement.insert(target, item);
      }

      // Reconcile app currentIndex with the player if needed (should match
      // the playing track's new slot after the moves).
      final playerIndex = _handler.audioPlayer.currentIndex;
      final current = state.currentTrack;
      if (playerIndex != null &&
          playerIndex != state.currentIndex &&
          playerIndex >= 0 &&
          playerIndex < state.queue.length &&
          current != null &&
          state.queue[playerIndex].id == current.id) {
        state = state.copyWith(currentIndex: playerIndex);
      }
    } catch (e, st) {
      debugPrint('reorderGaplessPlaylist failed: $e');
      debugPrintStack(stackTrace: st);
      // Last resort: full rebuild so queue and player stay consistent.
      await _reloadGaplessPreservingPlayback();
    } finally {
      _ignorePlayerIndexUpdates = false;
    }
  }

  /// Full gapless reload that preserves position and play/pause state.
  /// Used only as a fallback when in-place reordering is not possible.
  Future<void> _reloadGaplessPreservingPlayback() async {
    final wasPlaying = state.isPlaying;
    final pos = _handler.audioPlayer.position;
    final ok = await _loadGaplessSource(
      state.currentIndex,
      initialPosition: pos,
    );
    if (!ok) return;
    if (wasPlaying) {
      await _handler.audioPlayer.play();
    }
    state = state.copyWith(isPlaying: _handler.audioPlayer.playing);
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
    // Gapless: just_audio handles looping natively in the concatenation.
    // Single-source: app handles loop in _onTrackCompleted — keep the native
    // player on LoopMode.off so a previous gapless mode cannot stick.
    _handler.audioPlayer.setLoopMode(
      _gaplessActive ? state.loopMode : LoopMode.off,
    );
    _saveQueue();
    Analytics.track('toggle_loop_mode', {'mode': state.loopMode.name});
  }

  static const _keyPlaybackSpeed = 'playback_speed';

  static const List<double> speedPresets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  Future<void> setPlaybackSpeed(double speed) async {
    await _handler.audioPlayer.setSpeed(speed);
    state = state.copyWith(playbackSpeed: speed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPlaybackSpeed, speed);
    Analytics.track('set_playback_speed', {'speed': speed});
  }

  Future<void> _loadPlaybackSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_keyPlaybackSpeed) ?? 1.0;
    if (saved != 1.0) {
      await _handler.audioPlayer.setSpeed(saved);
      state = state.copyWith(playbackSpeed: saved);
    }
  }

  /// Jump to a specific index in the queue.
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    _pendingRestorePosition = null;
    await _finalizeCurrentListen();

    if (_gaplessActive) {
      state = state.copyWith(currentIndex: index);
      _updateMediaItemForTrack(state.queue[index]);
      await _handler.audioPlayer.seek(Duration.zero, index: index);
      await _activateListenForTrack(state.queue[index]);
      try {
        await _api.recordListening(state.queue[index].id);
      } catch (_) {}
    } else {
      state = state.copyWith(currentIndex: index, isLoading: true);
      await _loadAndPlay(state.queue[index]);
    }

    _saveQueue();
    Analytics.track('jump_to_queue', {'index': index});
  }

  // ── Wear OS custom action handlers ──────────────────────────────────

  /// MethodChannel for pushing browse data to the native Android side,
  /// which forwards it to the watch via the Wearable Data Layer.
  static const _wearBrowseChannel = MethodChannel(
    'dev.lorendb.tayra/wear_browse',
  );

  /// Handle "startPlaylist" custom action from the watch.
  void _handleWearStartPlaylist(Map<String, dynamic> extras) {
    final playlistId = extras['playlistId'] as int?;
    if (playlistId == null) return;
    _wearStartPlaylist(playlistId);
  }

  /// Handle "startPlaylistShuffled" custom action from the watch.
  void _handleWearStartPlaylistShuffled(Map<String, dynamic> extras) {
    final playlistId = extras['playlistId'] as int?;
    if (playlistId == null) return;
    _wearStartPlaylist(playlistId, shuffled: true);
  }

  Future<void> _wearStartPlaylist(
    int playlistId, {
    bool shuffled = false,
  }) async {
    try {
      // Fetch all tracks for the playlist, paginating through all pages.
      final allTracks = <Track>[];
      int page = 1;
      while (true) {
        final response = await _api.getPlaylistTracks(
          playlistId,
          page: page,
          pageSize: 50,
        );
        allTracks.addAll(response.results.map((pt) => pt.track));
        if (response.next == null) break;
        page++;
      }
      if (allTracks.isEmpty) return;
      await playTracks(allTracks, source: 'wear-playlist', shuffle: shuffled);
      Analytics.track('wear_start_playlist', {
        'playlist_id': playlistId,
        'shuffled': shuffled,
      });
    } catch (e) {
      debugPrint('Wear startPlaylist failed: $e');
    }
  }

  /// Handle "startRadio" custom action from the watch.
  void _handleWearStartRadio(Map<String, dynamic> extras) {
    final radioId = extras['radioId'] as int?;
    if (radioId == null) return;
    startRadio(radioId);
    Analytics.track('wear_start_radio', {'radio_id': radioId});
  }

  /// Handle "startRadioShuffled" custom action from the watch.
  /// Radios are session-based and server-side, so shuffle has no additional
  /// effect; we simply start the radio normally.
  void _handleWearStartRadioShuffled(Map<String, dynamic> extras) {
    final radioId = extras['radioId'] as int?;
    if (radioId == null) return;
    startRadio(radioId);
    Analytics.track('wear_start_radio', {
      'radio_id': radioId,
      'shuffled': true,
    });
  }

  /// Handle "startInstanceRadio" custom action from the watch.
  void _handleWearStartInstanceRadio(Map<String, dynamic> extras) {
    final radioType = extras['radioType'] as String?;
    if (radioType == null) return;
    // Map radio type string back to the sentinel loading IDs used by
    // startInstanceRadio for UI loading state.
    const typeToLoadingId = {
      'actor-content': -100,
      'random': -101,
      'favorites': -102,
      'less-listened': -103,
    };
    final loadingId = typeToLoadingId[radioType] ?? -100;
    startInstanceRadio(radioType, loadingId);
    Analytics.track('wear_start_instance_radio', {'radio_type': radioType});
  }

  /// Handle "startInstanceRadioShuffled" custom action from the watch.
  /// Instance radios are server-generated streams; shuffle has no additional
  /// effect, so we start the radio normally.
  void _handleWearStartInstanceRadioShuffled(Map<String, dynamic> extras) {
    final radioType = extras['radioType'] as String?;
    if (radioType == null) return;
    const typeToLoadingId = {
      'actor-content': -100,
      'random': -101,
      'favorites': -102,
      'less-listened': -103,
    };
    final loadingId = typeToLoadingId[radioType] ?? -100;
    startInstanceRadio(radioType, loadingId);
    Analytics.track('wear_start_instance_radio', {
      'radio_type': radioType,
      'shuffled': true,
    });
  }

  /// Handle "requestBrowseData" custom action from the watch.
  /// Fetches playlists and radios from the API, serialises them to JSON,
  /// and pushes them to the native side via MethodChannel so the bridge
  /// can forward them to the watch over the Wearable Data Layer.
  void _handleWearRequestBrowseData() {
    if (!Platform.isAndroid) return;
    _pushBrowseDataToWatch();
  }

  Future<void> _pushBrowseDataToWatch() async {
    try {
      // Fetch user playlists
      final playlistResponse = await _api.getPlaylists(scope: 'me');
      final playlistsJson = jsonEncode(
        playlistResponse.results
            .map(
              (p) => {'id': p.id, 'name': p.name, 'tracksCount': p.tracksCount},
            )
            .toList(),
      );

      // Fetch user radios
      final radiosResponse = await _api.getRadios(scope: 'me');
      final radiosJson = jsonEncode(
        radiosResponse.results
            .map(
              (r) => {
                'id': r.id,
                'name': r.name,
                'description': r.description ?? '',
              },
            )
            .toList(),
      );

      await _wearBrowseChannel.invokeMethod('pushBrowseData', {
        'playlists': playlistsJson,
        'radios': radiosJson,
      });
    } catch (e) {
      debugPrint('Wear requestBrowseData failed: $e');
    }
  }

  /// Handle "toggleFavorite" custom action from the watch.
  /// Toggles the favorite state of the currently playing track.
  void _handleWearToggleFavorite() {
    final track = state.currentTrack;
    if (track == null) return;
    try {
      ref.read(favoriteTrackIdsProvider.notifier).toggle(track.id);
      Analytics.track('wear_toggle_favorite', {'track_id': track.id});
    } catch (e) {
      debugPrint('Wear toggleFavorite failed: $e');
    }
  }
}
