import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/features/player/playback_recovery.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 1, 12);

  PlaybackAttempt attemptAt(
    DateTime started, {
    int epoch = 1,
    PlaybackAttemptKind kind = PlaybackAttemptKind.play,
  }) {
    return anchorAttemptDeadline(
      current: null,
      epoch: epoch,
      now: started,
      kind: kind,
    );
  }

  group('attempt deadline', () {
    test('stays anchored when more loading signals arrive', () {
      final started = attemptAt(t0);
      final afterFirstSignal = anchorAttemptDeadline(
        current: started,
        epoch: started.epoch,
        now: t0.add(const Duration(seconds: 10)),
      );
      final afterSecondSignal = anchorAttemptDeadline(
        current: afterFirstSignal,
        epoch: started.epoch,
        now: t0.add(const Duration(seconds: 25)),
      );

      expect(afterFirstSignal.startedAt, t0);
      expect(afterSecondSignal.startedAt, t0);
      expect(afterSecondSignal.deadlineAt, t0.add(playbackAttemptDeadline));
      expect(
        stallOutcomeIfExpired(
          attempt: afterSecondSignal,
          isLoading: true,
          now: t0
              .add(playbackAttemptDeadline)
              .subtract(const Duration(milliseconds: 1)),
        ),
        isNull,
      );
    });

    test(
      'expiry clears the spinner, pauses, marks stale, and does not skip',
      () {
        final attempt = attemptAt(t0);
        final outcome = stallOutcomeIfExpired(
          attempt: attempt,
          isLoading: true,
          now: t0.add(playbackAttemptDeadline),
        );

        expect(outcome, isNotNull);
        expect(outcome!.clearSpinner, isTrue);
        expect(outcome.pause, isTrue);
        expect(outcome.markStaleForReload, isTrue);
        expect(outcome.skipToNext, isFalse);
        expect(outcome.abandonedEpoch, attempt.epoch);
        expect(
          shouldApplyStallOutcome(
            outcome: outcome,
            currentEpoch: attempt.epoch,
          ),
          isTrue,
        );
      },
    );

    test(
      'quality step-down and connectivity retry get their own deadlines',
      () {
        final play = attemptAt(t0);
        final stepAt = t0.add(const Duration(seconds: 8));
        final stepped = anchorAttemptDeadline(
          current: play,
          epoch: play.epoch + 1,
          now: stepAt,
          kind: PlaybackAttemptKind.qualityStepDown,
        );
        final steppedAgain = anchorAttemptDeadline(
          current: stepped,
          epoch: stepped.epoch,
          now: stepAt.add(const Duration(seconds: 20)),
          kind: PlaybackAttemptKind.qualityStepDown,
        );

        expect(stepped.kind, PlaybackAttemptKind.qualityStepDown);
        expect(stepped.startedAt, stepAt);
        expect(steppedAgain.startedAt, stepAt);
        expect(steppedAgain.deadlineAt, stepAt.add(playbackAttemptDeadline));
        expect(
          stallOutcomeIfExpired(
            attempt: steppedAgain,
            isLoading: true,
            now: t0.add(playbackAttemptDeadline),
          ),
          isNull,
          reason: 'the previous attempt budget must not expire the step-down',
        );

        final retryAt = stepAt.add(const Duration(seconds: 4));
        final retried = anchorAttemptDeadline(
          current: steppedAgain,
          epoch: stepped.epoch + 1,
          now: retryAt,
          kind: PlaybackAttemptKind.connectivityRetry,
        );
        final retriedNudge = anchorAttemptDeadline(
          current: retried,
          epoch: retried.epoch,
          now: retryAt.add(const Duration(seconds: 12)),
        );
        expect(retried.kind, PlaybackAttemptKind.connectivityRetry);
        expect(retriedNudge.startedAt, retryAt);
        expect(retriedNudge.deadlineAt, retryAt.add(playbackAttemptDeadline));
      },
    );

    test('a superseded attempt cannot overwrite a newer one', () {
      final older = attemptAt(t0, epoch: 4);
      final newer = attemptAt(t0.add(const Duration(seconds: 5)), epoch: 5);
      final staleOutcome = stallOutcomeIfExpired(
        attempt: older,
        isLoading: true,
        now: t0.add(playbackAttemptDeadline),
      );

      expect(
        mayApplyLoadResult(
          completionEpoch: older.epoch,
          currentEpoch: newer.epoch,
        ),
        isFalse,
      );
      expect(
        mayApplyLoadResult(
          completionEpoch: newer.epoch,
          currentEpoch: newer.epoch,
        ),
        isTrue,
      );
      expect(staleOutcome, isNotNull);
      expect(
        shouldApplyStallOutcome(
          outcome: staleOutcome!,
          currentEpoch: newer.epoch,
        ),
        isFalse,
      );
      expect(
        shouldApplyStallOutcome(
          outcome: abandonPlaybackAttempt(epoch: older.epoch),
          currentEpoch: newer.epoch,
        ),
        isFalse,
      );
    });

    test('expiry is a no-op once the spinner is already down', () {
      final attempt = attemptAt(t0);
      expect(
        stallOutcomeIfExpired(
          attempt: attempt,
          isLoading: false,
          now: t0.add(playbackAttemptDeadline),
        ),
        isNull,
      );
    });

    test('a ready gapless seek finishes so the deadline cannot pause it', () {
      final opened = attemptAt(t0);
      final settlement = settleRetainedSourceAttempt(
        seekSucceeded: true,
        sourceReady: true,
      );

      expect(settlement.acceptPlatformEvents, isTrue);
      expect(settlement.finishAttempt, isTrue);
      expect(settlement.clearSpinner, isTrue);
      expect(
        stallOutcomeIfExpired(
          attempt: settlement.finishAttempt ? null : opened,
          isLoading: false,
          now: t0.add(playbackAttemptDeadline),
        ),
        isNull,
      );
    });

    test('a buffering gapless seek keeps its deadline and accepts ready', () {
      final opened = attemptAt(t0);
      final at = t0.add(const Duration(seconds: 4));
      final settlement = settleRetainedSourceAttempt(
        seekSucceeded: true,
        sourceReady: false,
      );

      expect(settlement.acceptPlatformEvents, isTrue);
      expect(settlement.finishAttempt, isFalse);
      expect(settlement.clearSpinner, isFalse);
      expect(
        loadingSignalStartsNewAttempt(
          current: opened,
          epoch: opened.epoch,
          now: at,
          isLoading: false,
        ),
        isFalse,
      );
      final nudged = anchorAttemptDeadline(
        current: settlement.finishAttempt ? null : opened,
        epoch: opened.epoch,
        now: at,
      );
      expect(nudged.startedAt, opened.startedAt);
      expect(nudged.deadlineAt, opened.deadlineAt);
    });

    test('a failed seek closes the attempt and clears the spinner', () {
      final settlement = settleRetainedSourceAttempt(
        seekSucceeded: false,
        sourceReady: false,
      );

      expect(settlement.acceptPlatformEvents, isTrue);
      expect(settlement.finishAttempt, isTrue);
      expect(settlement.clearSpinner, isTrue);
    });

    test('an expired attempt is replaced only once the spinner is down', () {
      final expired = attemptAt(t0);
      final now = t0.add(playbackAttemptDeadline);

      expect(
        loadingSignalStartsNewAttempt(
          current: expired,
          epoch: expired.epoch,
          now: now,
          isLoading: true,
        ),
        isFalse,
      );
      expect(
        stallOutcomeIfExpired(attempt: expired, isLoading: true, now: now),
        isNotNull,
      );

      expect(
        loadingSignalStartsNewAttempt(
          current: expired,
          epoch: expired.epoch,
          now: now,
          isLoading: false,
        ),
        isTrue,
      );
      // Reusing the expired attempt would schedule no time at all.
      final reused = anchorAttemptDeadline(
        current: expired,
        epoch: expired.epoch,
        now: now,
      );
      expect(reused.startedAt, expired.startedAt);
      expect(reused.isExpiredAt(now), isTrue);

      // The player passes current: null when the predicate is true.
      final replaced = anchorAttemptDeadline(
        current: null,
        epoch: expired.epoch,
        now: now,
      );
      expect(replaced.startedAt, now);
      expect(replaced.isExpiredAt(now), isFalse);
      expect(replaced.deadlineAt, now.add(playbackAttemptDeadline));

      expect(
        loadingSignalStartsNewAttempt(
          current: null,
          epoch: expired.epoch,
          now: now,
          isLoading: false,
        ),
        isTrue,
      );
      expect(
        loadingSignalStartsNewAttempt(
          current: expired,
          epoch: expired.epoch + 1,
          now: t0,
          isLoading: true,
        ),
        isTrue,
      );
    });
  });

  group('stale idle', () {
    PlaybackProgressSnapshot snapshot({
      required Duration idle,
      bool positionAdvancing = false,
      bool playingFromLocalCache = false,
      bool networkBacked = true,
      bool attemptStuckLoading = false,
      bool lifecycleWasPaused = false,
    }) {
      return PlaybackProgressSnapshot(
        now: t0.add(idle),
        lastProgressAt: t0,
        positionAdvancing: positionAdvancing,
        playingFromLocalCache: playingFromLocalCache,
        networkBacked: networkBacked,
        attemptStuckLoading: attemptStuckLoading,
        lifecycleWasPaused: lifecycleWasPaused,
      );
    }

    test(
      'threshold reloads a stuck network load now, otherwise on next play',
      () {
        expect(
          decideStaleIdle(
            snapshot(
              idle: playbackStaleIdleThreshold,
              attemptStuckLoading: true,
              lifecycleWasPaused: false,
            ),
          ),
          PlaybackIdleAction.reloadNow,
        );
        expect(
          decideStaleIdle(
            snapshot(
              idle: playbackStaleIdleThreshold + const Duration(minutes: 30),
              lifecycleWasPaused: false,
            ),
          ),
          PlaybackIdleAction.reloadOnNextPlay,
        );
      },
    );

    test('shorter idle, advancing playback, and a local file stay put', () {
      expect(
        decideStaleIdle(
          snapshot(
            idle: playbackStaleIdleThreshold - const Duration(milliseconds: 1),
            attemptStuckLoading: true,
          ),
        ),
        PlaybackIdleAction.none,
      );
      expect(
        decideStaleIdle(
          snapshot(
            idle: playbackStaleIdleThreshold + const Duration(hours: 2),
            positionAdvancing: true,
            attemptStuckLoading: true,
          ),
        ),
        PlaybackIdleAction.none,
      );
      expect(
        decideStaleIdle(
          snapshot(
            idle: playbackStaleIdleThreshold + const Duration(hours: 2),
            playingFromLocalCache: true,
            networkBacked: false,
            attemptStuckLoading: true,
          ),
        ),
        PlaybackIdleAction.none,
      );
      expect(
        decideStaleIdle(
          snapshot(
            idle: playbackStaleIdleThreshold,
            networkBacked: false,
            attemptStuckLoading: true,
          ),
        ),
        PlaybackIdleAction.none,
      );
    });

    test('does not require a paused lifecycle event', () {
      final desktopIdle = decideStaleIdle(
        snapshot(
          idle: playbackStaleIdleThreshold,
          attemptStuckLoading: true,
          lifecycleWasPaused: false,
        ),
      );
      final backgroundIdle = decideStaleIdle(
        snapshot(
          idle: playbackStaleIdleThreshold,
          attemptStuckLoading: true,
          lifecycleWasPaused: true,
        ),
      );
      expect(desktopIdle, PlaybackIdleAction.reloadNow);
      expect(backgroundIdle, desktopIdle);
    });
  });

  group('connectivity', () {
    PlaybackNetworkSnapshot network(List<ConnectivityResult> results) {
      return PlaybackNetworkSnapshot.fromResults(results);
    }

    final wifi = network(const [ConnectivityResult.wifi]);
    final mobile = network(const [ConnectivityResult.mobile]);
    final offline = network(const [ConnectivityResult.none]);

    PlaybackConnectivityContext context({
      PlaybackNetworkSnapshot? previous,
      required PlaybackNetworkSnapshot current,
      PlaybackTransportPhase phase = PlaybackTransportPhase.attempting,
      bool userIntendedPlay = true,
      bool userPaused = false,
      bool positionAdvancing = false,
      bool playingFromLocalCache = false,
      bool connectivityRetryConsumed = false,
    }) {
      return PlaybackConnectivityContext(
        previous: previous,
        current: current,
        phase: phase,
        userIntendedPlay: userIntendedPlay,
        userPaused: userPaused,
        positionAdvancing: positionAdvancing,
        playingFromLocalCache: playingFromLocalCache,
        connectivityRetryConsumed: connectivityRetryConsumed,
      );
    }

    test('loss abandons a load and an interface change retries once', () {
      expect(
        decidePlaybackConnectivity(context(previous: wifi, current: offline)),
        PlaybackConnectivityAction.abandonAttempt,
      );
      expect(
        decidePlaybackConnectivity(context(previous: wifi, current: mobile)),
        PlaybackConnectivityAction.retryOnce,
      );
      expect(
        decidePlaybackConnectivity(
          context(
            previous: wifi,
            current: mobile,
            connectivityRetryConsumed: true,
          ),
        ),
        PlaybackConnectivityAction.abandonAttempt,
      );
    });

    test('restore retries a user-intended play at most once', () {
      expect(
        decidePlaybackConnectivity(
          context(
            previous: offline,
            current: wifi,
            phase: PlaybackTransportPhase.idle,
          ),
        ),
        PlaybackConnectivityAction.retryOnce,
      );
      expect(
        decidePlaybackConnectivity(
          context(
            previous: offline,
            current: wifi,
            phase: PlaybackTransportPhase.idle,
            connectivityRetryConsumed: true,
          ),
        ),
        PlaybackConnectivityAction.none,
      );
      expect(
        decidePlaybackConnectivity(
          context(
            previous: offline,
            current: wifi,
            phase: PlaybackTransportPhase.idle,
            userIntendedPlay: false,
          ),
        ),
        PlaybackConnectivityAction.none,
      );
    });

    test('duplicates, pause, progress, and a cached file do not reload', () {
      expect(
        decidePlaybackConnectivity(context(previous: wifi, current: wifi)),
        PlaybackConnectivityAction.none,
      );
      expect(
        decidePlaybackConnectivity(
          context(
            previous: wifi,
            current: network(const [
              ConnectivityResult.none,
              ConnectivityResult.wifi,
              ConnectivityResult.bluetooth,
            ]),
          ),
        ),
        PlaybackConnectivityAction.none,
      );
      expect(
        decidePlaybackConnectivity(context(previous: null, current: mobile)),
        PlaybackConnectivityAction.none,
      );
      expect(
        decidePlaybackConnectivity(
          context(previous: wifi, current: offline, userPaused: true),
        ),
        PlaybackConnectivityAction.none,
      );
      expect(
        decidePlaybackConnectivity(
          context(
            previous: wifi,
            current: mobile,
            phase: PlaybackTransportPhase.playing,
            positionAdvancing: true,
          ),
        ),
        PlaybackConnectivityAction.none,
      );
      expect(
        decidePlaybackConnectivity(
          context(
            previous: offline,
            current: wifi,
            phase: PlaybackTransportPhase.playing,
            positionAdvancing: true,
          ),
        ),
        PlaybackConnectivityAction.none,
      );
      expect(
        decidePlaybackConnectivity(
          context(
            previous: wifi,
            current: offline,
            playingFromLocalCache: true,
          ),
        ),
        PlaybackConnectivityAction.none,
      );
      expect(
        decidePlaybackConnectivity(
          context(previous: wifi, current: mobile, playingFromLocalCache: true),
        ),
        PlaybackConnectivityAction.none,
      );
    });
  });
}
