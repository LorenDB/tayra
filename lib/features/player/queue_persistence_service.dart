import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/api/models.dart';

// ── Stash ────────────────────────────────────────────────────────────────

/// A snapshot of the queue saved by the user for later restoration.
class StashedQueue {
  final String id;
  final List<Track> queue;
  final List<Track> unshuffledQueue;
  final int currentIndex;
  final Duration position;
  final bool isShuffled;
  final String loopMode;
  final DateTime savedAt;

  const StashedQueue({
    required this.id,
    required this.queue,
    this.unshuffledQueue = const [],
    required this.currentIndex,
    required this.position,
    required this.isShuffled,
    required this.loopMode,
    required this.savedAt,
  });

  Track? get currentTrack =>
      currentIndex >= 0 && currentIndex < queue.length
          ? queue[currentIndex]
          : null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'queue': queue.map((t) => t.toJson()).toList(),
    'unshuffledQueue': unshuffledQueue.map((t) => t.toJson()).toList(),
    'currentIndex': currentIndex,
    'positionMs': position.inMilliseconds,
    'isShuffled': isShuffled,
    'loopMode': loopMode,
    'savedAt': savedAt.toIso8601String(),
  };

  factory StashedQueue.fromJson(Map<String, dynamic> json) {
    List<Track> parseTracks(dynamic raw) {
      if (raw is! List) return [];
      return raw.whereType<Map<String, dynamic>>().map(Track.fromJson).toList();
    }

    return StashedQueue(
      id: json['id'] as String,
      queue: parseTracks(json['queue']),
      unshuffledQueue: parseTracks(json['unshuffledQueue']),
      currentIndex: (json['currentIndex'] as int? ?? 0),
      position: Duration(milliseconds: json['positionMs'] as int? ?? 0),
      isShuffled: json['isShuffled'] as bool? ?? false,
      loopMode: json['loopMode'] as String? ?? 'off',
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Service for persisting and restoring the player queue state between app
/// launches. Stores queue tracks, current index, position, and playback mode.
class QueuePersistenceService {
  static const _keyQueue = 'player_queue';
  static const _keyUnshuffledQueue = 'player_unshuffled_queue';
  static const _keyCurrentIndex = 'player_current_index';
  static const _keyPosition = 'player_position';
  static const _keyIsShuffled = 'player_is_shuffled';
  static const _keyLoopMode = 'player_loop_mode';

  /// Save the current queue state to SharedPreferences.
  static Future<void> saveQueue({
    required List<Track> queue,
    required List<Track> unshuffledQueue,
    required int currentIndex,
    required Duration position,
    required bool isShuffled,
    required String loopMode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Serialize tracks to JSON
      final queueJson = queue.map((track) => track.toJson()).toList();
      await prefs.setString(_keyQueue, jsonEncode(queueJson));

      if (unshuffledQueue.isNotEmpty) {
        final unshuffledJson =
            unshuffledQueue.map((track) => track.toJson()).toList();
        await prefs.setString(_keyUnshuffledQueue, jsonEncode(unshuffledJson));
      } else {
        await prefs.remove(_keyUnshuffledQueue);
      }

      // Save playback state
      await prefs.setInt(_keyCurrentIndex, currentIndex);
      await prefs.setInt(_keyPosition, position.inMilliseconds);
      await prefs.setBool(_keyIsShuffled, isShuffled);
      await prefs.setString(_keyLoopMode, loopMode);
    } catch (e) {
      // Silently fail - non-critical feature
    }
  }

  /// Restore the queue state from SharedPreferences.
  /// Returns null if no saved state exists or restoration fails.
  static Future<QueueState?> restoreQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if queue exists
      final queueJsonString = prefs.getString(_keyQueue);
      if (queueJsonString == null) return null;

      // Deserialize tracks
      final queueJson = jsonDecode(queueJsonString) as List<dynamic>;
      final queue =
          queueJson.map((json) {
            if (json is Map<String, dynamic>) return Track.fromJson(json);
            if (json is String) {
              try {
                final parsed = jsonDecode(json);
                if (parsed is Map<String, dynamic>)
                  return Track.fromJson(parsed);
              } catch (_) {}
            }
            return Track.fromJson({});
          }).toList();

      if (queue.isEmpty) return null;

      // Restore unshuffled queue if present
      List<Track> unshuffledQueue = const [];
      final unshuffledJsonString = prefs.getString(_keyUnshuffledQueue);
      if (unshuffledJsonString != null) {
        final unshuffledJson =
            jsonDecode(unshuffledJsonString) as List<dynamic>;
        unshuffledQueue =
            unshuffledJson.map((json) {
              if (json is Map<String, dynamic>) return Track.fromJson(json);
              if (json is String) {
                try {
                  final parsed = jsonDecode(json);
                  if (parsed is Map<String, dynamic>) {
                    return Track.fromJson(parsed);
                  }
                } catch (_) {}
              }
              return Track.fromJson({});
            }).toList();
      }

      // Restore playback state
      final currentIndex = prefs.getInt(_keyCurrentIndex) ?? 0;
      final positionMs = prefs.getInt(_keyPosition) ?? 0;
      final isShuffled = prefs.getBool(_keyIsShuffled) ?? false;
      final loopModeStr = prefs.getString(_keyLoopMode) ?? 'off';

      return QueueState(
        queue: queue,
        unshuffledQueue: unshuffledQueue,
        currentIndex: currentIndex.clamp(0, queue.length - 1),
        position: Duration(milliseconds: positionMs),
        isShuffled: isShuffled,
        loopMode: loopModeStr,
      );
    } catch (e) {
      // Silently fail - corrupted data or other issue
      return null;
    }
  }

  // ── Stash ──────────────────────────────────────────────────────────────

  static const _keyStashes = 'player_stashes';
  static const _maxStashes = 10;

  /// Load all stashed queues, most-recent first.
  static Future<List<StashedQueue>> loadStashes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyStashes);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(StashedQueue.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Persist [stashes] to SharedPreferences.
  static Future<void> _saveStashes(List<StashedQueue> stashes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyStashes,
      jsonEncode(stashes.map((s) => s.toJson()).toList()),
    );
  }

  /// Add a new stash, evicting the oldest entry when the limit is exceeded.
  static Future<List<StashedQueue>> addStash(StashedQueue stash) async {
    final stashes = await loadStashes();
    stashes.insert(0, stash);
    if (stashes.length > _maxStashes) stashes.removeLast();
    await _saveStashes(stashes);
    return stashes;
  }

  /// Remove a stash by [id].
  static Future<List<StashedQueue>> removeStash(String id) async {
    final stashes = await loadStashes();
    stashes.removeWhere((s) => s.id == id);
    await _saveStashes(stashes);
    return stashes;
  }

  /// Clear all stashes.
  static Future<void> clearStashes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyStashes);
    } catch (_) {}
  }

  // ── Queue ──────────────────────────────────────────────────────────────

  /// Clear the saved queue state.
  static Future<void> clearQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyQueue);
      await prefs.remove(_keyUnshuffledQueue);
      await prefs.remove(_keyCurrentIndex);
      await prefs.remove(_keyPosition);
      await prefs.remove(_keyIsShuffled);
      await prefs.remove(_keyLoopMode);
    } catch (e) {
      // Silently fail
    }
  }
}

/// Restored queue state.
class QueueState {
  final List<Track> queue;
  final List<Track> unshuffledQueue;
  final int currentIndex;
  final Duration position;
  final bool isShuffled;
  final String loopMode;

  const QueueState({
    required this.queue,
    this.unshuffledQueue = const [],
    required this.currentIndex,
    required this.position,
    required this.isShuffled,
    required this.loopMode,
  });
}
