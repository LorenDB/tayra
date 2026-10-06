import 'package:connectivity_plus/connectivity_plus.dart';

/// How long one play attempt may spend resolving a source and buffering.
///
/// The clock starts when the attempt starts (listen credential, cache probe,
/// source setup, and later buffering). Further loading or buffering signals
/// for that same attempt do not move it. A quality step-down or the single
/// connectivity retry is a new attempt with its own deadline.
const Duration playbackAttemptDeadline = Duration(seconds: 30);

/// How long playback may sit without making progress before a network-backed
/// source is treated as stale.
///
/// Measured from the last position advance, or from the moment playback was
/// paused — not from an app-lifecycle transition. Desktop idle never leaves
/// the resumed lifecycle and still uses this threshold.
const Duration playbackStaleIdleThreshold = Duration(minutes: 10);

/// Why a deadline was started. Each kind is a distinct attempt.
enum PlaybackAttemptKind { play, qualityStepDown, connectivityRetry }

/// One bounded play attempt. [startedAt] is fixed for the attempt's epoch.
class PlaybackAttempt {
  final int epoch;
  final DateTime startedAt;
  final PlaybackAttemptKind kind;

  const PlaybackAttempt({
    required this.epoch,
    required this.startedAt,
    required this.kind,
  });

  DateTime get deadlineAt => startedAt.add(playbackAttemptDeadline);

  bool isExpiredAt(DateTime now) => !now.isBefore(deadlineAt);
}

/// Keep [current] when [epoch] is unchanged so a later loading signal cannot
/// push the deadline out. A new epoch (play, quality step-down, connectivity
/// retry) starts a new deadline at [now].
PlaybackAttempt anchorAttemptDeadline({
  PlaybackAttempt? current,
  required int epoch,
  required DateTime now,
  PlaybackAttemptKind kind = PlaybackAttemptKind.play,
}) {
  if (current != null && current.epoch == epoch) {
    return current;
  }
  return PlaybackAttempt(epoch: epoch, startedAt: now, kind: kind);
}

/// What abandoning an attempt does to the player. Never skips to another track.
class PlaybackStallOutcome {
  final bool clearSpinner;
  final bool pause;
  final bool markStaleForReload;
  final bool skipToNext;
  final int abandonedEpoch;

  const PlaybackStallOutcome({
    required this.clearSpinner,
    required this.pause,
    required this.markStaleForReload,
    required this.skipToNext,
    required this.abandonedEpoch,
  });
}

/// User cancel, connectivity loss, or any other path that ends the wait
/// before the deadline. The source is left so the next play reloads it.
PlaybackStallOutcome abandonPlaybackAttempt({required int epoch}) {
  return PlaybackStallOutcome(
    clearSpinner: true,
    pause: true,
    markStaleForReload: true,
    skipToNext: false,
    abandonedEpoch: epoch,
  );
}

/// Deadline expiry while the attempt is still the one showing the spinner.
/// Returns null when the attempt is still inside its budget or the spinner
/// is already down.
PlaybackStallOutcome? stallOutcomeIfExpired({
  required PlaybackAttempt? attempt,
  required bool isLoading,
  required DateTime now,
}) {
  if (attempt == null || !isLoading) return null;
  if (!attempt.isExpiredAt(now)) return null;
  return abandonPlaybackAttempt(epoch: attempt.epoch);
}

/// A load result may update the player only while its epoch is still current.
/// Abandoned and superseded attempts fail this check.
bool mayApplyLoadResult({
  required int completionEpoch,
  required int currentEpoch,
}) {
  return completionEpoch == currentEpoch;
}

/// A stall outcome may change the player only if its attempt is still current.
/// An outcome that would skip tracks is rejected.
bool shouldApplyStallOutcome({
  required PlaybackStallOutcome outcome,
  required int currentEpoch,
}) {
  return outcome.abandonedEpoch == currentEpoch && !outcome.skipToNext;
}

/// How to close an attempt that did not install a new audio source.
///
/// Gapless skip seeks inside the playlist already loaded. The attempt must
/// still accept the platform ready event that ends the wait, and must not
/// keep a deadline that can later pause a track that already became ready.
class RetainedSourceSettlement {
  /// Set the source-commit epoch so ready and error events apply.
  final bool acceptPlatformEvents;

  /// Drop the deadline. False only when a successful seek is still buffering.
  final bool finishAttempt;

  final bool clearSpinner;

  const RetainedSourceSettlement({
    required this.acceptPlatformEvents,
    required this.finishAttempt,
    required this.clearSpinner,
  });
}

/// [seekSucceeded] means the platform seek on the retained playlist returned.
/// [sourceReady] means that playlist is already ready or completed.
RetainedSourceSettlement settleRetainedSourceAttempt({
  required bool seekSucceeded,
  required bool sourceReady,
}) {
  if (!seekSucceeded || sourceReady) {
    return const RetainedSourceSettlement(
      acceptPlatformEvents: true,
      finishAttempt: true,
      clearSpinner: true,
    );
  }
  // Still buffering on the playlist already loaded. Keep this attempt's
  // deadline, but accept the ready event that ends it.
  return const RetainedSourceSettlement(
    acceptPlatformEvents: true,
    finishAttempt: false,
    clearSpinner: false,
  );
}

/// A loading or buffering signal starts a new attempt when there is none,
/// the epoch changed, or the current attempt is already expired and the
/// spinner is down.
///
/// An expired attempt that is still showing the spinner must not be
/// refreshed — its deadline is already used.
bool loadingSignalStartsNewAttempt({
  required PlaybackAttempt? current,
  required int epoch,
  required DateTime now,
  required bool isLoading,
}) {
  if (current == null || current.epoch != epoch) return true;
  if (current.isExpiredAt(now) && !isLoading) return true;
  return false;
}

/// What to do with a network-backed source that has not made progress.
enum PlaybackIdleAction {
  /// Keep the current pipeline.
  none,

  /// A load is already stuck: reload from the last position now.
  reloadNow,

  /// The next play reloads from the last position. Do not start audio now.
  reloadOnNextPlay,
}

/// Progress and source facts for [decideStaleIdle]. Times are injected.
class PlaybackProgressSnapshot {
  final DateTime now;
  final DateTime? lastProgressAt;
  final bool positionAdvancing;
  final bool playingFromLocalCache;
  final bool networkBacked;

  /// True when a play attempt is still showing the loading spinner.
  final bool attemptStuckLoading;

  /// Whether a paused lifecycle event was observed.
  ///
  /// [decideStaleIdle] does not require this. Foreground idle (desktop, or
  /// any process that never leaves resumed) is decided from [lastProgressAt].
  final bool lifecycleWasPaused;

  const PlaybackProgressSnapshot({
    required this.now,
    required this.lastProgressAt,
    required this.positionAdvancing,
    required this.playingFromLocalCache,
    required this.networkBacked,
    required this.attemptStuckLoading,
    this.lifecycleWasPaused = false,
  });

  Duration? get idleFor {
    final at = lastProgressAt;
    if (at == null) return null;
    return now.difference(at);
  }
}

/// Stale-pipeline decision. Local files, advancing playback, and idles
/// shorter than [playbackStaleIdleThreshold] stay on the current source.
PlaybackIdleAction decideStaleIdle(PlaybackProgressSnapshot snapshot) {
  if (snapshot.playingFromLocalCache) return PlaybackIdleAction.none;
  if (snapshot.positionAdvancing) return PlaybackIdleAction.none;
  if (!snapshot.networkBacked) return PlaybackIdleAction.none;
  final idle = snapshot.idleFor;
  if (idle == null || idle < playbackStaleIdleThreshold) {
    return PlaybackIdleAction.none;
  }
  if (snapshot.attemptStuckLoading) return PlaybackIdleAction.reloadNow;
  return PlaybackIdleAction.reloadOnNextPlay;
}

/// Online interfaces that distinguish a real network change.
///
/// Bluetooth, "none", and "other" are ignored so a partial
/// `connectivity_plus` snapshot is not treated as a new network.
const Set<ConnectivityResult> playbackMeaningfulInterfaces = {
  ConnectivityResult.wifi,
  ConnectivityResult.mobile,
  ConnectivityResult.ethernet,
  ConnectivityResult.vpn,
};

/// Normalized connectivity fact. Two snapshots with the same online
/// interfaces are the same network, regardless of list order or extras.
class PlaybackNetworkSnapshot {
  final bool online;
  final Set<String> interfaces;

  const PlaybackNetworkSnapshot({
    required this.online,
    required this.interfaces,
  });

  factory PlaybackNetworkSnapshot.fromResults(
    List<ConnectivityResult> results,
  ) {
    final names = <String>{
      for (final result in results)
        if (playbackMeaningfulInterfaces.contains(result)) result.name,
    };
    return PlaybackNetworkSnapshot(online: names.isNotEmpty, interfaces: names);
  }

  bool sameAs(PlaybackNetworkSnapshot other) {
    if (online != other.online ||
        interfaces.length != other.interfaces.length) {
      return false;
    }
    return interfaces.containsAll(other.interfaces);
  }
}

/// Coarse state of the transport when a connectivity snapshot arrives.
enum PlaybackTransportPhase {
  /// Resolving a source or stalled in loading / buffering.
  attempting,

  /// Audio is playing and the position is moving.
  playing,

  /// Paused, stopped, or otherwise not in a load.
  idle,
}

enum PlaybackConnectivityAction { none, abandonAttempt, retryOnce }

/// Facts for [decidePlaybackConnectivity]. Snapshots are compared by value.
class PlaybackConnectivityContext {
  final PlaybackNetworkSnapshot? previous;
  final PlaybackNetworkSnapshot current;
  final PlaybackTransportPhase phase;
  final bool userIntendedPlay;
  final bool userPaused;
  final bool positionAdvancing;
  final bool playingFromLocalCache;

  /// The one automatic connectivity retry for this user-intended play
  /// has already been used. Further changes must not chain another retry.
  final bool connectivityRetryConsumed;

  const PlaybackConnectivityContext({
    required this.previous,
    required this.current,
    required this.phase,
    required this.userIntendedPlay,
    required this.userPaused,
    required this.positionAdvancing,
    required this.playingFromLocalCache,
    required this.connectivityRetryConsumed,
  });
}

/// Connectivity policy for an in-flight or stalled play.
///
/// Loss or an interface change during a load ends that wait: one bounded
/// retry when the new snapshot is still online and the single retry has not
/// been used, otherwise abandon. Coming back online retries a user-intended
/// play that was not paused, at most once. Duplicates, a user pause, healthy
/// progressing playback, and a local cached file do nothing.
PlaybackConnectivityAction decidePlaybackConnectivity(
  PlaybackConnectivityContext context,
) {
  if (context.playingFromLocalCache) {
    return PlaybackConnectivityAction.none;
  }
  final previous = context.previous;
  if (previous == null || previous.sameAs(context.current)) {
    return PlaybackConnectivityAction.none;
  }
  if (context.userPaused || context.positionAdvancing) {
    return PlaybackConnectivityAction.none;
  }

  final lost = previous.online && !context.current.online;
  final restored = !previous.online && context.current.online;
  final interfaceChanged =
      previous.online &&
      context.current.online &&
      !previous.sameAs(context.current);
  final attempting = context.phase == PlaybackTransportPhase.attempting;

  if (attempting && (lost || interfaceChanged)) {
    if (interfaceChanged && !context.connectivityRetryConsumed) {
      return PlaybackConnectivityAction.retryOnce;
    }
    return PlaybackConnectivityAction.abandonAttempt;
  }

  if (restored &&
      context.userIntendedPlay &&
      !context.connectivityRetryConsumed) {
    return PlaybackConnectivityAction.retryOnce;
  }

  return PlaybackConnectivityAction.none;
}
