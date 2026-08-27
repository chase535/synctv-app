import 'package:flutter_test/flutter_test.dart';
import 'package:synctv_app/features/room/domain/web_playback_phase.dart';
import 'package:synctv_app/features/room/domain/web_playback_sync_gate.dart';

void main() {
  group('WebPlaybackSyncGate', () {
    const first = WebPlaybackSyncTarget(
      isPlaying: true,
      position: Duration(seconds: 42),
      playbackRate: 1,
    );
    const latest = WebPlaybackSyncTarget(
      isPlaying: false,
      position: Duration(seconds: 92),
      playbackRate: 1.25,
    );

    test('holds the latest remote target while an advertisement is active', () {
      final gate = WebPlaybackSyncGate(
        initialPhase: WebPlaybackPhase.advertisement,
      );

      expect(gate.submit(first), isNull);
      expect(gate.submit(latest), isNull);
      expect(gate.pendingTarget, same(latest));

      expect(gate.updatePhase(WebPlaybackPhase.content), same(latest));
      expect(gate.pendingTarget, isNull);
    });

    test('applies targets immediately when the content timeline exists', () {
      final contentGate = WebPlaybackSyncGate(
        initialPhase: WebPlaybackPhase.content,
      );
      final bufferingGate = WebPlaybackSyncGate(
        initialPhase: WebPlaybackPhase.buffering,
      );

      expect(contentGate.submit(first), same(first));
      expect(bufferingGate.submit(first), same(first));
      expect(contentGate.pendingTarget, isNull);
      expect(bufferingGate.pendingTarget, isNull);
    });

    test('does not release pending targets before content is available', () {
      final gate = WebPlaybackSyncGate();
      gate.submit(first);

      expect(gate.updatePhase(WebPlaybackPhase.advertisement), isNull);
      expect(gate.pendingTarget, same(first));
    });
  });
}
