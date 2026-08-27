enum WebPlaybackPhase {
  initializing,
  advertisement,
  overlayAdvertisement,
  content,
  buffering,
  ended,
  unsupported,
}

enum WebPlaybackAdvertisementKind { unknown, preroll, midroll, pause, overlay }

extension WebPlaybackPhaseTimeline on WebPlaybackPhase {
  bool get isAdvertisement =>
      this == WebPlaybackPhase.advertisement ||
      this == WebPlaybackPhase.overlayAdvertisement;

  bool get hasContentTimeline =>
      this == WebPlaybackPhase.overlayAdvertisement ||
      this == WebPlaybackPhase.content ||
      this == WebPlaybackPhase.buffering ||
      this == WebPlaybackPhase.ended;
}
