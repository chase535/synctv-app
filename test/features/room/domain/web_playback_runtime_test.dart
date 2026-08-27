import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:synctv_app/features/room/domain/web_playback_command.dart';
import 'package:synctv_app/features/room/domain/web_playback_event_router.dart';
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

    test('blocking advertisements hold the latest authoritative target', () {
      final runtime = WebPlaybackRuntime();
      runtime.handleRawMessage(
        jsonEncode({
          'version': 1,
          'type': 'phase',
          'source': 'page',
          'phase': 'advertisement',
          'adKind': 'midroll',
        }),
      );
      final first = WebPlaybackSyncTarget(
        isPlaying: true,
        position: const Duration(seconds: 80),
        playbackRate: 1,
      );
      final latest = WebPlaybackSyncTarget(
        isPlaying: false,
        position: const Duration(seconds: 95),
        playbackRate: 1.25,
      );

      expect(runtime.submitSyncTarget(first), isNull);
      expect(runtime.submitSyncTarget(latest), isNull);

      final content = runtime.handleRawMessage(
        jsonEncode({
          'version': 1,
          'type': 'phase',
          'source': 'page',
          'phase': 'content',
        }),
      );
      expect(content?.releasedSyncTarget, same(latest));
    });

    test('overlay advertisements preserve the content timeline', () {
      final runtime = WebPlaybackRuntime();
      runtime.handleRawMessage(
        jsonEncode({
          'version': 1,
          'type': 'phase',
          'source': 'page',
          'phase': 'overlayAdvertisement',
          'adKind': 'overlay',
        }),
      );
      final target = WebPlaybackSyncTarget(
        isPlaying: true,
        position: const Duration(seconds: 33),
        playbackRate: 1,
      );

      expect(runtime.snapshot.phase, WebPlaybackPhase.overlayAdvertisement);
      expect(
        runtime.snapshot.advertisementKind,
        WebPlaybackAdvertisementKind.overlay,
      );
      expect(runtime.submitSyncTarget(target), same(target));
    });

    test('ad ended events do not release the content sync target', () {
      final runtime = WebPlaybackRuntime();
      final target = WebPlaybackSyncTarget(
        isPlaying: true,
        position: const Duration(seconds: 92),
        playbackRate: 1,
      );
      runtime.handleRawMessage(
        jsonEncode({
          'version': 1,
          'type': 'phase',
          'source': 'page',
          'phase': 'advertisement',
        }),
      );
      expect(runtime.submitSyncTarget(target), isNull);

      final ended = runtime.handleRawMessage(
        jsonEncode({
          'version': 1,
          'type': 'ended',
          'source': 'page',
          'position': 30,
        }),
      );

      expect(ended?.snapshot.phase, WebPlaybackPhase.advertisement);
      expect(ended?.releasedSyncTarget, isNull);

      final content = runtime.handleRawMessage(
        jsonEncode({
          'version': 1,
          'type': 'phase',
          'source': 'page',
          'phase': 'content',
        }),
      );
      expect(content?.releasedSyncTarget, same(target));
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

    test('suppresses ad mechanics but keeps pause-ad play/pause intent', () {
      final runtime = WebPlaybackRuntime();
      runtime.handleRawMessage(
        jsonEncode({
          'version': 1,
          'type': 'phase',
          'source': 'page',
          'phase': 'advertisement',
          'adKind': 'pause',
        }),
      );

      final pause = runtime.handleRawMessage(
        jsonEncode({
          'version': 1,
          'type': 'pause',
          'source': 'user',
          'phase': 'advertisement',
          'adKind': 'pause',
          'position': 40,
        }),
      );
      final seek = runtime.handleRawMessage(
        jsonEncode({
          'version': 1,
          'type': 'seek',
          'source': 'user',
          'phase': 'advertisement',
          'adKind': 'pause',
          'position': 42,
        }),
      );

      expect(pause?.localIntent?.type, WebPlaybackLocalIntentType.pause);
      expect(seek?.localIntent, isNull);
    });

    test(
      'suppresses user controls generated inside preroll and midroll ads',
      () {
        for (final adKind in ['preroll', 'midroll', 'unknown']) {
          final runtime = WebPlaybackRuntime();
          runtime.handleRawMessage(
            jsonEncode({
              'version': 1,
              'type': 'phase',
              'source': 'page',
              'phase': 'advertisement',
              'adKind': adKind,
            }),
          );
          final update = runtime.handleRawMessage(
            jsonEncode({
              'version': 1,
              'type': 'play',
              'source': 'user',
              'phase': 'advertisement',
              'adKind': adKind,
              'position': 5,
            }),
          );
          expect(update?.localIntent, isNull);
        }
      },
    );

    test(
      'recognizes command acknowledgements without creating local intents',
      () {
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
      },
    );

    test('rejects raw messages that do not authenticate the session', () {
      const token = '0123456789abcdef0123456789abcdef';
      final runtime = WebPlaybackRuntime(bridgeToken: token);

      expect(
        runtime.handleRawMessage(
          jsonEncode({'version': 1, 'type': 'ready', 'source': 'page'}),
        ),
        isNull,
      );
      expect(
        runtime.handleRawMessage(
          jsonEncode({
            'version': 1,
            'type': 'ready',
            'source': 'page',
            'token': token,
          }),
        ),
        isNotNull,
      );
    });

    test('navigation reset clears pending commands and playback state', () {
      final runtime = WebPlaybackRuntime();
      runtime.rememberCommand(WebPlaybackCommand.play('stale-play'));
      runtime.handleRawMessage(
        jsonEncode({'version': 1, 'type': 'ready', 'source': 'page'}),
      );

      runtime.resetForNavigation();

      expect(runtime.snapshot.ready, isFalse);
      expect(runtime.snapshot.phase, WebPlaybackPhase.initializing);
      expect(runtime.snapshot.advertisementKind, isNull);
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
