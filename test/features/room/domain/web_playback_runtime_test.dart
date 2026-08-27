import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:synctv_app/features/room/domain/web_playback_command.dart';
import 'package:synctv_app/features/room/domain/web_playback_phase.dart';
import 'package:synctv_app/features/room/domain/web_playback_runtime.dart';
import 'package:synctv_app/features/room/domain/web_playback_sync_gate.dart';

void main() {
  group('WebPlaybackRuntime', () {
    test('queues remote sync until the content timeline is available', () {
      final runtime = WebPlaybackRuntime();
      final target = WebPlaybackSyncTarget(
        isPlaying: true,
        position: const Duration(seconds: 92),
        playbackRate: 1,
      );

      expect(runtime.submitSyncTarget(target), isNull);

      final update = runtime.handleRawMessage(
        jsonEncode({
          'version': 1,
          'type': 'phase',
          'source': 'page',
          'phase': 'content',
        }),
      );

      expect(update?.snapshot.phase, WebPlaybackPhase.content);
      expect(update?.releasedSyncTarget, same(target));
    });

    test('updates state while reporting only explicit user controls', () {
      final runtime = WebPlaybackRuntime();

      final userPlay = runtime.handleRawMessage(
        jsonEncode({
          'version': 1,
          'type': 'play',
          'source': 'user',
          'position': 10,
        }),
      );
      expect(userPlay?.snapshot.isPlaying, isTrue);
      expect(userPlay?.snapshot.positionSeconds, 10);
      expect(userPlay?.localIntent, isNotNull);

      final automaticPause = runtime.handleRawMessage(
        jsonEncode({
          'version': 1,
          'type': 'pause',
          'source': 'page',
          'position': 11,
        }),
      );
      expect(automaticPause?.snapshot.isPlaying, isFalse);
      expect(automaticPause?.snapshot.positionSeconds, 11);
      expect(automaticPause?.localIntent, isNull);
    });

    test('recognizes command acknowledgements without creating local intents', () {
      final runtime = WebPlaybackRuntime();
      runtime.rememberCommand(WebPlaybackCommand.pause('remote-pause'));

      final update = runtime.handleRawMessage(
        jsonEncode({
          'version': 1,
          'type': 'pause',
          'source': 'command',
          'commandId': 'remote-pause',
          'position': 30,
        }),
      );

      expect(update?.commandAcknowledged, isTrue);
      expect(update?.localIntent, isNull);
      expect(update?.snapshot.isPlaying, isFalse);
      expect(update?.snapshot.positionSeconds, 30);
    });

    test('navigation reset clears pending commands and playback state', () {
      final runtime = WebPlaybackRuntime();
      runtime.rememberCommand(WebPlaybackCommand.play('stale-play'));
      runtime.handleRawMessage(
        jsonEncode({
          'version': 1,
          'type': 'ready',
          'source': 'page',
        }),
      );

      runtime.resetForNavigation();

      expect(runtime.snapshot.ready, isFalse);
      expect(runtime.snapshot.phase, WebPlaybackPhase.initializing);
      expect(
        runtime.handleRawMessage(
          jsonEncode({
            'version': 1,
            'type': 'play',
            'source': 'command',
            'commandId': 'stale-play',
          }),
        ),
        isNull,
      );
    });

    test('rejects malformed bridge input without mutating state', () {
      final runtime = WebPlaybackRuntime();

      expect(runtime.handleRawMessage('{bad-json'), isNull);
      expect(runtime.snapshot.ready, isFalse);
      expect(runtime.snapshot.positionSeconds, 0);
    });
  });
}
