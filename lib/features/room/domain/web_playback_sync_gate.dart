import 'package:synctv_app/features/room/domain/web_playback_phase.dart';

final class WebPlaybackSyncTarget {
  const WebPlaybackSyncTarget({
    required this.isPlaying,
    required this.position,
    required this.playbackRate,
  });

  final bool isPlaying;
  final Duration position;
  final double playbackRate;
}

final class WebPlaybackSyncGate {
  WebPlaybackSyncGate({
    WebPlaybackPhase initialPhase = WebPlaybackPhase.initializing,
  }) : _phase = initialPhase;

  WebPlaybackPhase _phase;
  WebPlaybackSyncTarget? _pendingTarget;

  WebPlaybackPhase get phase => _phase;
  WebPlaybackSyncTarget? get pendingTarget => _pendingTarget;

  WebPlaybackSyncTarget? submit(WebPlaybackSyncTarget target) {
    if (_phase.hasContentTimeline) return target;
    _pendingTarget = target;
    return null;
  }

  WebPlaybackSyncTarget? updatePhase(WebPlaybackPhase phase) {
    _phase = phase;
    if (!phase.hasContentTimeline) return null;
    final pending = _pendingTarget;
    _pendingTarget = null;
    return pending;
  }

  void clear() => _pendingTarget = null;
}
