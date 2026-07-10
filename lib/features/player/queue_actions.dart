import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/features/player/player_provider.dart';

/// Tracks that have a stream URL and can be queued for playback.
List<Track> filterPlayableTracks(Iterable<Track> tracks) =>
    tracks.where((t) => t.listenUrl != null).toList();

/// Adds playable tracks to the end of the queue.
///
/// Returns a user-facing status message (including the empty case).
String addTracksToQueue(WidgetRef ref, Iterable<Track> tracks) {
  final playable = filterPlayableTracks(tracks);
  if (playable.isEmpty) return 'No playable tracks to add';
  ref.read(playerProvider.notifier).addToQueue(playable);
  return 'Added ${playable.length} tracks to queue';
}

/// Inserts playable tracks to play next in the queue.
///
/// Returns a user-facing status message (including the empty case).
String insertTracksToPlayNext(WidgetRef ref, Iterable<Track> tracks) {
  final playable = filterPlayableTracks(tracks);
  if (playable.isEmpty) return 'No playable tracks to add';
  ref.read(playerProvider.notifier).insertTracksNext(playable);
  return 'Inserted ${playable.length} tracks to play next';
}
