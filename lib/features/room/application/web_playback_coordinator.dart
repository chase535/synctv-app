// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math';

import 'package:synctv_app/features/room/application/web_playback_client.dart';
import 'package:synctv_app/features/room/domain/web_playback_bridge_message.dart';
import 'package:synctv_app/features/room/domain/web_playback_command.dart';
import 'package:synctv_app/features/room/domain/web_playback_event_router.dart';
import 'package:synctv_app/features/room/domain/web_playback_phase.dart';
import 'package:synctv_app/features/room/domain/web_playback_runtime.dart';
import 'package:synctv_app/features/room/domain/web_playback_sync_gate.dart';

typedef WebPlaybackLocalIntentCallback =
    FutureOr<void> Function(WebPlaybackLocalIntent intent);
typedef WebPlaybackErrorCallback =
    void Function(Object error, StackTrace stackTrace);

final class WebPlaybackCoordinator {
  WebPlaybackCoordinator({
    required WebPlaybackSession session,
    required WebPlaybackLocalIntentCallback onLocalIntent,
    WebPlaybackErrorCallback? onError,
    Duration correctionInterval = const Duration(seconds: 3),
    Duration localIntentGracePeriod = const Duration(milliseconds: 2500),
    double seekToleranceSeconds = 1.5,
    double rateTolerance = 0.01,
    DateTime Function()? clock,
    Random? random,
  }) : _session = session,
       _onLocalIntent = onLocalIntent,
       _onError = onError,
       _localIntentGracePeriod = localIntentGracePeriod,
       _seekToleranceSeconds = seekToleranceSeconds,
       _rateTolerance = rateTolerance,
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure() {
    if (correctionInterval <= Duration.zero) {
      throw ArgumentError.value(
        correctionInterval,
        'correctionInterval',
        'Correction interval must be positive',
      );
    }
    if (localIntentGracePeriod.isNegative) {
      throw ArgumentError.value(
        localIntentGracePeriod,
        'localIntentGracePeriod',
        'Local intent grace period must not be negative',
      );
    }
    if (!seekToleranceSeconds.isFinite || seekToleranceSeconds <= 0) {
      throw ArgumentError.value(
        seekToleranceSeconds,
        'seekToleranceSeconds',
        'Seek tolerance must be positive and finite',
      );
    }
    if (!rateTolerance.isFinite || rateTolerance <= 0) {
      throw ArgumentError.value(
        rateTolerance,
        'rateTolerance',
        'Rate tolerance must be positive and finite',
      );
    }

    _subscription = _session.updates.listen(
      _handleRuntimeUpdate,
      onError: (Object error, StackTrace stackTrace) {
        _onError?.call(error, stackTrace);
      },
    );
    _correctionTimer = Timer.periodic(
      correctionInterval,
      (_) => unawaited(_correctDrift()),
    );
  }

  final WebPlaybackSession _session;
  final WebPlaybackLocalIntentCallback _onLocalIntent;
  final WebPlaybackErrorCallback? _onError;
  final Duration _localIntentGracePeriod;
  final double _seekToleranceSeconds;
  final double _rateTolerance;
  final DateTime Function() _clock;
  final Random _random;

  late final StreamSubscription<WebPlaybackRuntimeUpdate> _subscription;
  late final Timer _correctionTimer;
  _StampedSyncTarget? _authoritativeTarget;
  WebPlaybackSyncTarget? _pendingApplyTarget;
  DateTime? _suppressCorrectionUntil;
  int _commandSequence = 0;
  bool _draining = false;
  bool _correctionInFlight = false;
  bool _closed = false;

  WebPlaybackSession get session => _session;

  void updateAuthoritativeState(WebPlaybackSyncTarget target) {
    if (_closed) return;
    _authoritativeTarget = _StampedSyncTarget(target, _clock());
    if (_correctionSuppressed()) return;
    final effective = _effectiveTarget(_authoritativeTarget!);
    final released = _session.submitSyncTarget(effective);
    if (released != null) _queueApply(released);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _correctionTimer.cancel();
    await _subscription.cancel();
    await _session.close();
  }

  void _handleRuntimeUpdate(WebPlaybackRuntimeUpdate update) {
    if (_closed) return;

    final localIntent = update.localIntent;
    if (localIntent != null) {
      _suppressCorrectionUntil = _clock().add(_localIntentGracePeriod);
      final result = _onLocalIntent(localIntent);
      if (result is Future<void>) {
        unawaited(
          result.catchError((Object error, StackTrace stackTrace) {
            _onError?.call(error, stackTrace);
          }),
        );
      }
    }

    final authoritative = _authoritativeTarget;
    if (update.snapshot.phase == WebPlaybackPhase.advertisement &&
        authoritative != null) {
      _session.submitSyncTarget(_effectiveTarget(authoritative));
    }

    final released = update.releasedSyncTarget;
    if (released != null && !_correctionSuppressed()) {
      _queueApply(
        authoritative == null ? released : _effectiveTarget(authoritative),
      );
    }
  }

  void _queueApply(WebPlaybackSyncTarget target) {
    if (_closed) return;
    _pendingApplyTarget = target;
    if (_draining) return;
    _draining = true;
    unawaited(_drainTargets());
  }

  Future<void> _drainTargets() async {
    try {
      while (!_closed && _pendingApplyTarget != null) {
        var target = _pendingApplyTarget!;
        _pendingApplyTarget = null;
        final authoritative = _authoritativeTarget;
        if (authoritative != null) target = _effectiveTarget(authoritative);
        await _applyTarget(target);
      }
    } on Object catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    } finally {
      _draining = false;
      if (!_closed && _pendingApplyTarget != null) {
        _queueApply(_pendingApplyTarget!);
      }
    }
  }

  Future<void> _applyTarget(WebPlaybackSyncTarget target) async {
    var snapshot = await _session.readSnapshot() ?? _session.snapshot;
    if (snapshot.phase == WebPlaybackPhase.advertisement) {
      final authoritative = _authoritativeTarget;
      _session.submitSyncTarget(
        authoritative == null ? target : _effectiveTarget(authoritative),
      );
      return;
    }
    if (!snapshot.phase.hasContentTimeline || !snapshot.ready) return;

    final targetSeconds = target.position.inMilliseconds / 1000;
    final needsSeek =
        (snapshot.positionSeconds - targetSeconds).abs() >
        _seekToleranceSeconds;
    final needsRate =
        (snapshot.playbackRate - target.playbackRate).abs() > _rateTolerance;
    final temporarilyPause =
        target.isPlaying && snapshot.isPlaying && (needsSeek || needsRate);

    if ((!target.isPlaying && snapshot.isPlaying) || temporarilyPause) {
      await _execute(WebPlaybackCommand.pause(_nextCommandId('pause')));
      snapshot = WebPlaybackSnapshot(
        ready: snapshot.ready,
        phase: snapshot.phase,
        advertisementKind: snapshot.advertisementKind,
        isPlaying: false,
        positionSeconds: snapshot.positionSeconds,
        playbackRate: snapshot.playbackRate,
        errorMessage: snapshot.errorMessage,
      );
    }

    if (needsSeek) {
      await _execute(
        WebPlaybackCommand.seek(_nextCommandId('seek'), target.position),
      );
    }

    if (needsRate) {
      await _execute(
        WebPlaybackCommand.rate(_nextCommandId('rate'), target.playbackRate),
      );
    }

    if (target.isPlaying && !snapshot.isPlaying) {
      await _execute(WebPlaybackCommand.play(_nextCommandId('play')));
    }
  }

  Future<void> _execute(WebPlaybackCommand command) async {
    if (!await _session.execute(command)) {
      throw StateError(
        'Web playback command was rejected: ${command.type.name}',
      );
    }
  }

  Future<void> _correctDrift() async {
    if (_closed || _correctionInFlight) return;
    final authoritative = _authoritativeTarget;
    if (authoritative == null || _correctionSuppressed()) return;

    _correctionInFlight = true;
    try {
      final snapshot = await _session.readSnapshot();
      if (snapshot == null || !snapshot.ready) return;
      if (snapshot.phase == WebPlaybackPhase.advertisement) {
        _session.submitSyncTarget(_effectiveTarget(authoritative));
        return;
      }
      if (snapshot.phase == WebPlaybackPhase.buffering ||
          !snapshot.phase.hasContentTimeline) {
        return;
      }

      final target = _effectiveTarget(authoritative);
      final targetSeconds = target.position.inMilliseconds / 1000;
      final needsCorrection =
          snapshot.isPlaying != target.isPlaying ||
          (snapshot.playbackRate - target.playbackRate).abs() >
              _rateTolerance ||
          (snapshot.positionSeconds - targetSeconds).abs() >
              _seekToleranceSeconds;
      if (needsCorrection) _queueApply(target);
    } on Object catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    } finally {
      _correctionInFlight = false;
    }
  }

  bool _correctionSuppressed() {
    final suppressUntil = _suppressCorrectionUntil;
    return suppressUntil != null && _clock().isBefore(suppressUntil);
  }

  WebPlaybackSyncTarget _effectiveTarget(_StampedSyncTarget stamped) {
    var milliseconds = stamped.target.position.inMilliseconds;
    if (stamped.target.isPlaying) {
      final elapsedMilliseconds = _clock()
          .difference(stamped.receivedAt)
          .inMilliseconds;
      if (elapsedMilliseconds > 0) {
        milliseconds += (elapsedMilliseconds * stamped.target.playbackRate)
            .round();
      }
    }
    final maxMilliseconds = (WebPlaybackBridgeMessage.maxPositionSeconds * 1000)
        .round();
    milliseconds = milliseconds.clamp(0, maxMilliseconds);
    return WebPlaybackSyncTarget(
      isPlaying: stamped.target.isPlaying,
      position: Duration(milliseconds: milliseconds),
      playbackRate: stamped.target.playbackRate,
    );
  }

  String _nextCommandId(String type) {
    _commandSequence = (_commandSequence + 1) & 0x7fffffff;
    final nonce = _random.nextInt(0x7fffffff).toRadixString(16);
    return 'web-$type-${_commandSequence.toRadixString(16)}-$nonce';
  }
}

final class _StampedSyncTarget {
  const _StampedSyncTarget(this.target, this.receivedAt);

  final WebPlaybackSyncTarget target;
  final DateTime receivedAt;
}
