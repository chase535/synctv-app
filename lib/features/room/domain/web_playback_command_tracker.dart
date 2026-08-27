import 'package:synctv_app/features/room/domain/web_playback_bridge_message.dart';
import 'package:synctv_app/features/room/domain/web_playback_command.dart';

final class WebPlaybackCommandTracker {
  WebPlaybackCommandTracker({
    this.retention = const Duration(seconds: 10),
    this.maxPending = 32,
  }) {
    if (retention.isNegative) {
      throw ArgumentError.value(
        retention,
        'retention',
        'Retention must not be negative',
      );
    }
    if (maxPending <= 0) {
      throw ArgumentError.value(
        maxPending,
        'maxPending',
        'maxPending must be positive',
      );
    }
  }

  final Duration retention;
  final int maxPending;
  final Map<String, _PendingWebPlaybackCommand> _pending = {};

  int get pendingCount => _pending.length;

  void remember(WebPlaybackCommand command, {DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    _removeExpired(timestamp);
    _pending.remove(command.id);
    while (_pending.length >= maxPending) {
      _pending.remove(_pending.keys.first);
    }
    _pending[command.id] = _PendingWebPlaybackCommand(
      type: command.type,
      createdAt: timestamp,
    );
  }

  bool acknowledge(WebPlaybackBridgeMessage message, {DateTime? now}) {
    if (message.source != WebPlaybackBridgeEventSource.command ||
        message.commandId == null) {
      return false;
    }

    final timestamp = now ?? DateTime.now();
    _removeExpired(timestamp);
    final pending = _pending[message.commandId];
    if (pending == null) return false;

    final matches = message.type == WebPlaybackBridgeEventType.error ||
        _matches(pending.type, message.type);
    if (!matches) return false;

    _pending.remove(message.commandId);
    return true;
  }

  void clear() => _pending.clear();

  void _removeExpired(DateTime now) {
    final expired = _pending.entries
        .where((entry) => now.difference(entry.value.createdAt) > retention)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final id in expired) {
      _pending.remove(id);
    }
  }

  bool _matches(
    WebPlaybackCommandType commandType,
    WebPlaybackBridgeEventType eventType,
  ) =>
      switch (commandType) {
        WebPlaybackCommandType.play =>
          eventType == WebPlaybackBridgeEventType.play,
        WebPlaybackCommandType.pause =>
          eventType == WebPlaybackBridgeEventType.pause,
        WebPlaybackCommandType.seek =>
          eventType == WebPlaybackBridgeEventType.seek,
        WebPlaybackCommandType.rate =>
          eventType == WebPlaybackBridgeEventType.rate,
      };
}

final class _PendingWebPlaybackCommand {
  const _PendingWebPlaybackCommand({
    required this.type,
    required this.createdAt,
  });

  final WebPlaybackCommandType type;
  final DateTime createdAt;
}
