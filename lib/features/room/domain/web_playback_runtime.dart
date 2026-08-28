import 'package:synctv_app/features/room/domain/web_playback_bridge_message.dart';
import 'package:synctv_app/features/room/domain/web_playback_command.dart';
import 'package:synctv_app/features/room/domain/web_playback_event_router.dart';
import 'package:synctv_app/features/room/domain/web_playback_phase.dart';
import 'package:synctv_app/features/room/domain/web_playback_sync_gate.dart';

final class WebPlaybackSnapshot {
  const WebPlaybackSnapshot({
    this.ready = false,
    this.phase = WebPlaybackPhase.initializing,
    this.advertisementKind,
    this.isPlaying = false,
    this.positionSeconds = 0,
    this.playbackRate = 1,
    this.errorMessage,
  });

  final bool ready;
  final WebPlaybackPhase phase;
  final WebPlaybackAdvertisementKind? advertisementKind;
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
    String? bridgeToken,
    WebPlaybackEventRouter? eventRouter,
    WebPlaybackSyncGate? syncGate,
  }) : _eventRouter = _createEventRouter(eventRouter, bridgeToken),
       _syncGate = syncGate ?? WebPlaybackSyncGate();

  final WebPlaybackEventRouter _eventRouter;
  final WebPlaybackSyncGate _syncGate;
  WebPlaybackSnapshot _snapshot = const WebPlaybackSnapshot();

  WebPlaybackSnapshot get snapshot => _snapshot;

  void rememberCommand(WebPlaybackCommand command, {DateTime? now}) {
    _eventRouter.rememberCommand(command, now: now);
  }

  bool forgetCommand(String commandId) => _eventRouter.forgetCommand(commandId);

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
    final previousPhase = _snapshot.phase;
    final message = route.message;
    var ready = _snapshot.ready;
    var phase = _snapshot.phase;
    var advertisementKind = _snapshot.advertisementKind;
    var isPlaying = _snapshot.isPlaying;
    var positionSeconds = _snapshot.positionSeconds;
    var playbackRate = _snapshot.playbackRate;
    var errorMessage = _snapshot.errorMessage;
    WebPlaybackSyncTarget? releasedSyncTarget;

    void applyPhase(
      WebPlaybackPhase nextPhase, {
      WebPlaybackAdvertisementKind? nextAdvertisementKind,
    }) {
      if (nextPhase.isAdvertisement) {
        advertisementKind =
            nextAdvertisementKind ??
            (nextPhase == WebPlaybackPhase.overlayAdvertisement
                ? WebPlaybackAdvertisementKind.overlay
                : WebPlaybackAdvertisementKind.unknown);
      } else {
        advertisementKind = null;
      }
      if (phase == nextPhase) return;
      phase = nextPhase;
      releasedSyncTarget ??= _syncGate.updatePhase(nextPhase);
    }

    if (message.phase != null) {
      applyPhase(
        message.phase!,
        nextAdvertisementKind: message.advertisementKind,
      );
    }
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
      advertisementKind: advertisementKind,
      isPlaying: isPlaying,
      positionSeconds: positionSeconds,
      playbackRate: playbackRate,
      errorMessage: errorMessage,
    );

    var localIntent = route.localIntent;
    if (localIntent != null &&
        !_shouldForwardLocalIntent(
          phase: phase,
          previousPhase: previousPhase,
          advertisementKind: advertisementKind,
          intent: localIntent,
        )) {
      localIntent = null;
    }

    return WebPlaybackRuntimeUpdate(
      snapshot: _snapshot,
      localIntent: localIntent,
      commandAcknowledged: route.commandAcknowledged,
      releasedSyncTarget: releasedSyncTarget,
    );
  }

  static WebPlaybackEventRouter _createEventRouter(
    WebPlaybackEventRouter? eventRouter,
    String? bridgeToken,
  ) {
    if (eventRouter != null && bridgeToken != null) {
      throw ArgumentError(
        'bridgeToken cannot be combined with a custom eventRouter',
      );
    }
    return eventRouter ??
        WebPlaybackEventRouter(expectedBridgeToken: bridgeToken);
  }

  static bool _shouldForwardLocalIntent({
    required WebPlaybackPhase phase,
    required WebPlaybackPhase previousPhase,
    required WebPlaybackAdvertisementKind? advertisementKind,
    required WebPlaybackLocalIntent intent,
  }) {
    if (phase != WebPlaybackPhase.advertisement) return true;

    if (advertisementKind == WebPlaybackAdvertisementKind.pause) {
      return intent.type == WebPlaybackLocalIntentType.play ||
          intent.type == WebPlaybackLocalIntentType.pause;
    }

    return intent.type == WebPlaybackLocalIntentType.pause &&
        previousPhase.hasContentTimeline;
  }
}
