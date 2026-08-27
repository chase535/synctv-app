import 'package:synctv_app/features/room/domain/web_playback_bridge_message.dart';
import 'package:synctv_app/features/room/domain/web_playback_command.dart';
import 'package:synctv_app/features/room/domain/web_playback_event_router.dart';
import 'package:synctv_app/features/room/domain/web_playback_phase.dart';
import 'package:synctv_app/features/room/domain/web_playback_sync_gate.dart';

final class WebPlaybackSnapshot {
  const WebPlaybackSnapshot({
    this.ready = false,
    this.phase = WebPlaybackPhase.initializing,
    this.isPlaying = false,
    this.positionSeconds = 0,
    this.playbackRate = 1,
    this.errorMessage,
  });

  final bool ready;
  final WebPlaybackPhase phase;
  final bool isPlaying;
  final double positionSeconds;
  final double playbackRate;
  final String? errorMessage;
}

final class WebPlaybackRuntimeUpdate {
  const WebPlaybackRuntimeUpdate({
    required this.snapshot,
    this.localIntent,
    this.commandAcknowledged = false,
    this.releasedSyncTarget,
  });

  final WebPlaybackSnapshot snapshot;
  final WebPlaybackLocalIntent? localIntent;
  final bool commandAcknowledged;
  final WebPlaybackSyncTarget? releasedSyncTarget;
}

final class WebPlaybackRuntime {
  WebPlaybackRuntime({
    WebPlaybackEventRouter? eventRouter,
    WebPlaybackSyncGate? syncGate,
  }) : _eventRouter = eventRouter ?? WebPlaybackEventRouter(),
       _syncGate = syncGate ?? WebPlaybackSyncGate();

  final WebPlaybackEventRouter _eventRouter;
  final WebPlaybackSyncGate _syncGate;
  WebPlaybackSnapshot _snapshot = const WebPlaybackSnapshot();

  WebPlaybackSnapshot get snapshot => _snapshot;

  void rememberCommand(WebPlaybackCommand command, {DateTime? now}) {
    _eventRouter.rememberCommand(command, now: now);
  }

  WebPlaybackSyncTarget? submitSyncTarget(WebPlaybackSyncTarget target) =>
      _syncGate.submit(target);

  WebPlaybackRuntimeUpdate? handleRawMessage(String raw, {DateTime? now}) {
    final route = _eventRouter.routeRaw(raw, now: now);
    if (route == null) return null;
    return _applyRoute(route);
  }

  void resetForNavigation() {
    _eventRouter.clearCommands();
    _syncGate.clear();
    _syncGate.updatePhase(WebPlaybackPhase.initializing);
    _snapshot = const WebPlaybackSnapshot();
  }

  WebPlaybackRuntimeUpdate _applyRoute(WebPlaybackEventRoute route) {
    final message = route.message;
    var ready = _snapshot.ready;
    var phase = _snapshot.phase;
    var isPlaying = _snapshot.isPlaying;
    var positionSeconds = _snapshot.positionSeconds;
    var playbackRate = _snapshot.playbackRate;
    var errorMessage = _snapshot.errorMessage;
    WebPlaybackSyncTarget? releasedSyncTarget;

    void applyPhase(WebPlaybackPhase nextPhase) {
      if (phase == nextPhase) return;
      phase = nextPhase;
      releasedSyncTarget ??= _syncGate.updatePhase(nextPhase);
    }

    if (message.phase != null) applyPhase(message.phase!);
    if (message.positionSeconds != null) {
      positionSeconds = message.positionSeconds!;
    }
    if (message.playbackRate != null) {
      playbackRate = message.playbackRate!;
    }

    switch (message.type) {
      case WebPlaybackBridgeEventType.ready:
        ready = true;
        errorMessage = null;
        break;
      case WebPlaybackBridgeEventType.phase:
        break;
      case WebPlaybackBridgeEventType.play:
        isPlaying = true;
        break;
      case WebPlaybackBridgeEventType.pause:
        isPlaying = false;
        break;
      case WebPlaybackBridgeEventType.seek:
        break;
      case WebPlaybackBridgeEventType.rate:
        break;
      case WebPlaybackBridgeEventType.ended:
        isPlaying = false;
        if (phase.hasContentTimeline) {
          applyPhase(WebPlaybackPhase.ended);
        }
        break;
      case WebPlaybackBridgeEventType.error:
        errorMessage = message.errorMessage;
        break;
    }

    _snapshot = WebPlaybackSnapshot(
      ready: ready,
      phase: phase,
      isPlaying: isPlaying,
      positionSeconds: positionSeconds,
      playbackRate: playbackRate,
      errorMessage: errorMessage,
    );

    return WebPlaybackRuntimeUpdate(
      snapshot: _snapshot,
      localIntent: route.localIntent,
      commandAcknowledged: route.commandAcknowledged,
      releasedSyncTarget: releasedSyncTarget,
    );
  }
}
