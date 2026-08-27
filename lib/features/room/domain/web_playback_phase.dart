enum WebPlaybackPhase {
  initializing,
  advertisement,
  content,
  buffering,
  ended,
  unsupported,
}

extension WebPlaybackPhaseTimeline on WebPlaybackPhase {
  bool get hasContentTimeline =>
      this == WebPlaybackPhase.content ||
      this == WebPlaybackPhase.buffering ||
      this == WebPlaybackPhase.ended;
}
