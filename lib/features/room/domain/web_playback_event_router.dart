import 'package:synctv_app/features/room/domain/web_playback_bridge_message.dart';
import 'package:synctv_app/features/room/domain/web_playback_command.dart';
import 'package:synctv_app/features/room/domain/web_playback_command_tracker.dart';

enum WebPlaybackLocalIntentType { play, pause, seek, rate }

final class WebPlaybackLocalIntent {
  const WebPlaybackLocalIntent({
    required this.type,
    this.positionSeconds,
    this.playbackRate,
  });

  final WebPlaybackLocalIntentType type;
  final double? positionSeconds;
  final double? playbackRate;
}

final class WebPlaybackEventRoute {
  const WebPlaybackEventRoute({
    required this.message,
    this.localIntent,
    this.commandAcknowledged = false,
  });

  final WebPlaybackBridgeMessage message;
  final WebPlaybackLocalIntent? localIntent;
  final bool commandAcknowledged;
}

final class WebPlaybackEventRouter {
  WebPlaybackEventRouter({WebPlaybackCommandTracker? commandTracker})
    : _commandTracker = commandTracker ?? WebPlaybackCommandTracker();

  final WebPlaybackCommandTracker _commandTracker;

  void rememberCommand(WebPlaybackCommand command, {DateTime? now}) {
    _commandTracker.remember(command, now: now);
  }

  WebPlaybackEventRoute? routeRaw(String raw, {DateTime? now}) {
    final message = WebPlaybackBridgeMessage.tryDecode(raw);
    if (message == null) return null;
    return route(message, now: now);
  }

  WebPlaybackEventRoute? route(
    WebPlaybackBridgeMessage message, {
    DateTime? now,
  }) {
    if (message.source == WebPlaybackBridgeEventSource.command) {
      if (!_commandTracker.acknowledge(message, now: now)) return null;
      return WebPlaybackEventRoute(message: message, commandAcknowledged: true);
    }

    if (message.source == WebPlaybackBridgeEventSource.user) {
      final intent = _localIntent(message);
      if (intent == null) return null;
      return WebPlaybackEventRoute(message: message, localIntent: intent);
    }

    return WebPlaybackEventRoute(message: message);
  }

  void clearCommands() => _commandTracker.clear();

  WebPlaybackLocalIntent? _localIntent(WebPlaybackBridgeMessage message) =>
      switch (message.type) {
        WebPlaybackBridgeEventType.play => const WebPlaybackLocalIntent(
          type: WebPlaybackLocalIntentType.play,
        ),
        WebPlaybackBridgeEventType.pause => const WebPlaybackLocalIntent(
          type: WebPlaybackLocalIntentType.pause,
        ),
        WebPlaybackBridgeEventType.seek => WebPlaybackLocalIntent(
          type: WebPlaybackLocalIntentType.seek,
          positionSeconds: message.positionSeconds,
        ),
        WebPlaybackBridgeEventType.rate => WebPlaybackLocalIntent(
          type: WebPlaybackLocalIntentType.rate,
          playbackRate: message.playbackRate,
        ),
        _ => null,
      };
}
