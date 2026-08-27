import 'package:synctv_app/features/room/domain/web_playback_bridge_message.dart';

enum WebPlaybackCommandType { play, pause, seek, rate }

final class WebPlaybackCommand {
  WebPlaybackCommand._(
    this.id,
    this.type, {
    this.positionSeconds,
    this.playbackRate,
  }) {
    if (id.isEmpty || id.length > WebPlaybackBridgeMessage.maxCommandIdLength) {
      throw ArgumentError.value(id, 'id', 'Invalid web playback command id');
    }
  }

  factory WebPlaybackCommand.play(String id) =>
      WebPlaybackCommand._(id, WebPlaybackCommandType.play);

  factory WebPlaybackCommand.pause(String id) =>
      WebPlaybackCommand._(id, WebPlaybackCommandType.pause);

  factory WebPlaybackCommand.seek(String id, Duration position) {
    final seconds = position.inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds < 0 ||
        !seconds.isFinite ||
        seconds > WebPlaybackBridgeMessage.maxPositionSeconds) {
      throw RangeError.value(
        seconds,
        'position',
        'Position must be between 0 and '
            '${WebPlaybackBridgeMessage.maxPositionSeconds} seconds',
      );
    }
    return WebPlaybackCommand._(
      id,
      WebPlaybackCommandType.seek,
      positionSeconds: seconds,
    );
  }

  factory WebPlaybackCommand.rate(String id, double playbackRate) {
    if (!playbackRate.isFinite ||
        playbackRate < WebPlaybackBridgeMessage.minPlaybackRate ||
        playbackRate > WebPlaybackBridgeMessage.maxPlaybackRate) {
      throw RangeError.value(
        playbackRate,
        'playbackRate',
        'Playback rate must be between '
            '${WebPlaybackBridgeMessage.minPlaybackRate} and '
            '${WebPlaybackBridgeMessage.maxPlaybackRate}',
      );
    }
    return WebPlaybackCommand._(
      id,
      WebPlaybackCommandType.rate,
      playbackRate: playbackRate,
    );
  }

  final String id;
  final WebPlaybackCommandType type;
  final double? positionSeconds;
  final double? playbackRate;

  Map<String, Object> toArguments() => {
    'id': id,
    'type': type.name,
    'position': ?positionSeconds,
    'playbackRate': ?playbackRate,
  };
}
