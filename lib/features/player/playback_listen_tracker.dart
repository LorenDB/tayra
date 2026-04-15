import 'dart:async';

import 'package:tayra/core/api/models.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';

typedef InsertListenRecord =
    Future<int> Function(
      Track track, {
      required int listenedSeconds,
      required DateTime listenedAt,
    });

typedef UpdateListenRecord = Future<void> Function(int id, int listenedSeconds);

/// Tracks one local listen row per actual track activation.
class PlaybackListenTracker {
  PlaybackListenTracker({
    this.persistIntervalSeconds = 2,
    InsertListenRecord? insertListenRecord,
    UpdateListenRecord? updateListenRecord,
  }) : _insertListenRecord =
           insertListenRecord ?? ListenHistoryService.insertListen,
       _updateListenRecord =
           updateListenRecord ?? ListenHistoryService.updateListenDuration;

  final int persistIntervalSeconds;
  final InsertListenRecord _insertListenRecord;
  final UpdateListenRecord _updateListenRecord;

  _TrackedListenSession? _session;
  Future<void> _tail = Future.value();

  Track? get currentTrack => _session?.track;

  Future<void> activate(
    Track track, {
    Duration position = Duration.zero,
    DateTime? listenedAt,
    bool isPlaying = false,
  }) {
    return _serialize(() async {
      final previousSession = _session;
      if (previousSession != null) {
        await _persist(previousSession, force: true);
      }

      _session = _TrackedListenSession(
        track: track,
        listenedAt: listenedAt ?? DateTime.now(),
        lastPosition: position,
        isPlaying: isPlaying,
      );
    });
  }

  Future<void> setPlaying(bool isPlaying, {Duration? position}) {
    return _serialize(() async {
      final session = _session;
      if (session == null) return;

      final resolvedPosition = position ?? session.lastPosition;
      if (!isPlaying && session.isPlaying) {
        _accumulateTo(session, resolvedPosition);
        session.isPlaying = false;
        await _persist(session, force: true);
        return;
      }

      session.lastPosition = resolvedPosition;
      session.isPlaying = isPlaying;
    });
  }

  Future<void> updatePosition(Duration position) {
    return _serialize(() async {
      final session = _session;
      if (session == null) return;
      if (!session.isPlaying) return;

      _accumulateTo(session, position);
      await _persist(session);
    });
  }

  Future<void> handleSeek({
    required Duration previousPosition,
    required Duration newPosition,
  }) {
    return _serialize(() async {
      final session = _session;
      if (session == null) return;

      _accumulateTo(session, previousPosition);
      await _persist(session, force: true);
      session.lastPosition = newPosition;
    });
  }

  Future<void> finalize({Duration? position}) {
    return finalizeAt(position: position);
  }

  Future<void> finalizeAt({Duration? position, bool forceAccumulate = false}) {
    return _serialize(() async {
      final session = _session;
      if (session == null) return;

      if (position != null) {
        _accumulateTo(session, position, force: forceAccumulate);
      }
      await _persist(session, force: true);
      _session = null;
    });
  }

  Future<void> dispose({Duration? position}) => finalizeAt(position: position);

  void _accumulateTo(
    _TrackedListenSession session,
    Duration position, {
    bool force = false,
  }) {
    final deltaMs =
        position.inMilliseconds - session.lastPosition.inMilliseconds;
    if (deltaMs <= 0) {
      session.lastPosition = position;
      return;
    }

    if (session.isPlaying || force) {
      session.listenedMilliseconds += deltaMs;
    }
    session.lastPosition = position;
  }

  Future<void> _persist(
    _TrackedListenSession session, {
    bool force = false,
  }) async {
    final listenedSeconds = session.listenedMilliseconds ~/ 1000;
    if (listenedSeconds <= 0) return;

    if (session.recordId == null) {
      session.recordId = await _insertListenRecord(
        session.track,
        listenedSeconds: listenedSeconds,
        listenedAt: session.listenedAt,
      );
      session.persistedSeconds = listenedSeconds;
      return;
    }

    final deltaSeconds = listenedSeconds - session.persistedSeconds;
    if (deltaSeconds <= 0) {
      return;
    }

    if (!force && deltaSeconds < persistIntervalSeconds) {
      return;
    }

    await _updateListenRecord(session.recordId!, listenedSeconds);
    session.persistedSeconds = listenedSeconds;
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _tail.then((_) => operation());
    _tail = next.catchError((_) {});
    return next;
  }
}

class _TrackedListenSession {
  _TrackedListenSession({
    required this.track,
    required this.listenedAt,
    required this.lastPosition,
    required this.isPlaying,
  });

  final Track track;
  final DateTime listenedAt;
  Duration lastPosition;
  bool isPlaying;
  int listenedMilliseconds = 0;
  int persistedSeconds = 0;
  int? recordId;
}
