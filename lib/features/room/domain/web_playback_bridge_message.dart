import 'dart:convert';

import 'package:synctv_app/features/room/domain/web_playback_phase.dart';

enum WebPlaybackBridgeEventType {
  ready,
  phase,
  play,
  pause,
  seek,
  rate,
  ended,
  error,
}

enum WebPlaybackBridgeEventSource { page, user, command }

final class WebPlaybackBridgeMessage {
  const WebPlaybackBridgeMessage({
    required this.type,
    required this.source,
    this.phase,
    this.positionSeconds,
    this.playbackRate,
    this.commandId,
    this.errorMessage,
  });

  static const int protocolVersion = 1;
  static const int maxEncodedBytes = 16 * 1024;
  static const double maxPositionSeconds = 604800;
  static const double minPlaybackRate = 0.1;
  static const double maxPlaybackRate = 16;
  static const int maxCommandIdLength = 128;
  static const int maxErrorMessageLength = 1024;

  final WebPlaybackBridgeEventType type;
  final WebPlaybackBridgeEventSource source;
  final WebPlaybackPhase? phase;
  final double? positionSeconds;
  final double? playbackRate;
  final String? commandId;
  final String? errorMessage;

  static WebPlaybackBridgeMessage? tryDecode(String raw) {
    if (raw.length > maxEncodedBytes || utf8.encode(raw).length > maxEncodedBytes) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['version'] != protocolVersion) return null;

      final type = _parseType(decoded['type']);
      if (type == null) return null;
      final source = _parseSource(decoded['source']);
      if (source == null) return null;

      final commandId = _parseOptionalString(
        decoded['commandId'],
        maxLength: maxCommandIdLength,
      );
      if (decoded.containsKey('commandId') && commandId == null) return null;
      if (source == WebPlaybackBridgeEventSource.command && commandId == null) {
        return null;
      }
      if (source != WebPlaybackBridgeEventSource.command && commandId != null) {
        return null;
      }
      if (source == WebPlaybackBridgeEventSource.user && !_isControlType(type)) {
        return null;
      }
      if (source == WebPlaybackBridgeEventSource.command &&
          !_isCommandEventType(type)) {
        return null;
      }

      final positionSeconds = _parseOptionalFiniteDouble(
        decoded['position'],
        min: 0,
        max: maxPositionSeconds,
      );
      if (decoded.containsKey('position') && positionSeconds == null) {
        return null;
      }

      final playbackRate = _parseOptionalFiniteDouble(
        decoded['playbackRate'],
        min: minPlaybackRate,
        max: maxPlaybackRate,
      );
      if (decoded.containsKey('playbackRate') && playbackRate == null) {
        return null;
      }

      final phase = _parsePhase(decoded['phase']);
      if (decoded.containsKey('phase') && phase == null) return null;

      final errorMessage = _parseOptionalString(
        decoded['error'],
        maxLength: maxErrorMessageLength,
      );
      if (decoded.containsKey('error') && errorMessage == null) return null;

      if (type == WebPlaybackBridgeEventType.phase && phase == null) return null;
      if (type == WebPlaybackBridgeEventType.seek && positionSeconds == null) {
        return null;
      }
      if (type == WebPlaybackBridgeEventType.rate && playbackRate == null) {
        return null;
      }
      if (type == WebPlaybackBridgeEventType.error && errorMessage == null) {
        return null;
      }

      return WebPlaybackBridgeMessage(
        type: type,
        source: source,
        phase: phase,
        positionSeconds: positionSeconds,
        playbackRate: playbackRate,
        commandId: commandId,
        errorMessage: errorMessage,
      );
    } on FormatException {
      return null;
    }
  }

  static bool _isControlType(WebPlaybackBridgeEventType type) => switch (type) {
    WebPlaybackBridgeEventType.play ||
    WebPlaybackBridgeEventType.pause ||
    WebPlaybackBridgeEventType.seek ||
    WebPlaybackBridgeEventType.rate => true,
    _ => false,
  };

  static bool _isCommandEventType(WebPlaybackBridgeEventType type) =>
      _isControlType(type) || type == WebPlaybackBridgeEventType.error;

  static WebPlaybackBridgeEventType? _parseType(Object? value) => switch (value) {
    'ready' => WebPlaybackBridgeEventType.ready,
    'phase' => WebPlaybackBridgeEventType.phase,
    'play' => WebPlaybackBridgeEventType.play,
    'pause' => WebPlaybackBridgeEventType.pause,
    'seek' => WebPlaybackBridgeEventType.seek,
    'rate' => WebPlaybackBridgeEventType.rate,
    'ended' => WebPlaybackBridgeEventType.ended,
    'error' => WebPlaybackBridgeEventType.error,
    _ => null,
  };

  static WebPlaybackBridgeEventSource? _parseSource(Object? value) =>
      switch (value) {
        null || 'page' => WebPlaybackBridgeEventSource.page,
        'user' => WebPlaybackBridgeEventSource.user,
        'command' => WebPlaybackBridgeEventSource.command,
        _ => null,
      };

  static WebPlaybackPhase? _parsePhase(Object? value) => switch (value) {
    'initializing' => WebPlaybackPhase.initializing,
    'advertisement' => WebPlaybackPhase.advertisement,
    'content' => WebPlaybackPhase.content,
    'buffering' => WebPlaybackPhase.buffering,
    'ended' => WebPlaybackPhase.ended,
    'unsupported' => WebPlaybackPhase.unsupported,
    _ => null,
  };

  static double? _parseOptionalFiniteDouble(
    Object? value, {
    required double min,
    required double max,
  }) {
    if (value == null) return null;
    if (value is! num) return null;
    final parsed = value.toDouble();
    if (!parsed.isFinite || parsed < min || parsed > max) return null;
    return parsed;
  }

  static String? _parseOptionalString(Object? value, {required int maxLength}) {
    if (value == null) return null;
    if (value is! String || value.isEmpty || value.length > maxLength) {
      return null;
    }
    return value;
  }
}
