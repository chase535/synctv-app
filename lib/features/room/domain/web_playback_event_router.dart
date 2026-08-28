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
  WebPlaybackEventRouter({
    WebPlaybackCommandTracker? commandTracker,
    String? expectedBridgeToken,
  }) : _commandTracker = commandTracker ?? WebPlaybackCommandTracker(),
       _expectedBridgeToken = expectedBridgeToken {
    if (expectedBridgeToken != null &&
        (expectedBridgeToken.length <
                WebPlaybackBridgeMessage.minBridgeTokenLength ||
            expectedBridgeToken.length >
                WebPlaybackBridgeMessage.maxBridgeTokenLength)) {
      throw ArgumentError.value(
        expectedBridgeToken.length,
        'expectedBridgeToken',
        'Invalid web playback bridge token length',
      );
    }
  }

  final WebPlaybackCommandTracker _commandTracker;
  final String? _expectedBridgeToken;

  void rememberCommand(WebPlaybackCommand command, {DateTime? now}) {
    _commandTracker.remember(command, now: now);
  }

  bool forgetCommand(String commandId) => _commandTracker.forget(commandId);

  WebPlaybackEventRoute? routeRaw(String raw, {DateTime? now}) {
    final message = WebPlaybackBridgeMessage.tryDecode(
      raw,
      expectedBridgeToken: _expectedBridgeToken,
    );
    if (message == null) return null;
    return route(message, now: now);
  }

  WebPlaybackEventRoute? route(
    WebPlaybackBridgeMessage message, {
    DateTime? now,
  }) {
    if (_expectedBridgeToken != null &&
        message.bridgeToken != _expectedBridgeToken) {
      return null;
    }

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
