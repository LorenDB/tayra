import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/api/models.dart';

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
