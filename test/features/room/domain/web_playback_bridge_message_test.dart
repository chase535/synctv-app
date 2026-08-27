import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:synctv_app/features/room/domain/web_playback_bridge_message.dart';
import 'package:synctv_app/features/room/domain/web_playback_phase.dart';

void main() {
  group('WebPlaybackBridgeMessage', () {
    test('decodes a programmatic seek event', () {
      final message = WebPlaybackBridgeMessage.tryDecode(
        jsonEncode({
          'version': 1,
          'type': 'seek',
          'source': 'command',
          'commandId': 'remote-42',
          'position': 92.5,
        }),
      );

      expect(message, isNotNull);
      expect(message!.type, WebPlaybackBridgeEventType.seek);
      expect(message.source, WebPlaybackBridgeEventSource.command);
      expect(message.commandId, 'remote-42');
      expect(message.positionSeconds, 92.5);
    });

    test('decodes explicit user control events', () {
      final message = WebPlaybackBridgeMessage.tryDecode(
        jsonEncode({'version': 1, 'type': 'pause', 'source': 'user'}),
      );

      expect(message?.source, WebPlaybackBridgeEventSource.user);
      expect(message?.type, WebPlaybackBridgeEventType.pause);
    });

    test('decodes blocking and overlay advertisement metadata', () {
      final pauseAd = WebPlaybackBridgeMessage.tryDecode(
        jsonEncode({
          'version': 1,
          'type': 'phase',
          'source': 'page',
          'phase': 'advertisement',
          'adKind': 'pause',
        }),
      );
      final overlay = WebPlaybackBridgeMessage.tryDecode(
        jsonEncode({
          'version': 1,
          'type': 'phase',
          'source': 'page',
          'phase': 'overlayAdvertisement',
          'adKind': 'overlay',
        }),
      );

      expect(pauseAd?.phase, WebPlaybackPhase.advertisement);
      expect(pauseAd?.advertisementKind, WebPlaybackAdvertisementKind.pause);
      expect(overlay?.phase, WebPlaybackPhase.overlayAdvertisement);
      expect(overlay?.advertisementKind, WebPlaybackAdvertisementKind.overlay);
    });

    test('requires the expected per-session bridge token when configured', () {
      const token = '0123456789abcdef0123456789abcdef';
      final valid = jsonEncode({
        'version': 1,
        'type': 'ready',
        'source': 'page',
        'token': token,
      });
      final forged = jsonEncode({
        'version': 1,
        'type': 'ready',
        'source': 'page',
        'token': 'fedcba9876543210fedcba9876543210',
      });

      expect(
        WebPlaybackBridgeMessage.tryDecode(valid, expectedBridgeToken: token),
        isNotNull,
      );
      expect(
        WebPlaybackBridgeMessage.tryDecode(forged, expectedBridgeToken: token),
        isNull,
      );
      expect(
        WebPlaybackBridgeMessage.tryDecode(
          jsonEncode({'version': 1, 'type': 'ready', 'source': 'page'}),
          expectedBridgeToken: token,
        ),
        isNull,
      );
    });

    test('rejects unsupported versions and malformed messages', () {
      expect(
        WebPlaybackBridgeMessage.tryDecode(
          jsonEncode({'version': 2, 'type': 'ready'}),
        ),
        isNull,
      );
      expect(
        WebPlaybackBridgeMessage.tryDecode(
          jsonEncode({'version': 1, 'type': 'seek', 'position': -1}),
        ),
        isNull,
      );
      expect(
        WebPlaybackBridgeMessage.tryDecode(
          jsonEncode({'version': 1, 'type': 'unknown'}),
        ),
        isNull,
      );
      expect(
        WebPlaybackBridgeMessage.tryDecode(
          jsonEncode({
            'version': 1,
            'type': 'phase',
            'phase': 'content',
            'adKind': 'pause',
          }),
        ),
        isNull,
      );
      expect(WebPlaybackBridgeMessage.tryDecode('{not-json'), isNull);
    });

    test('requires command ids for command-sourced events', () {
      expect(
        WebPlaybackBridgeMessage.tryDecode(
          jsonEncode({'version': 1, 'type': 'pause', 'source': 'command'}),
        ),
        isNull,
      );
    });

    test('rejects command ids on page and user events', () {
      for (final source in ['page', 'user']) {
        expect(
          WebPlaybackBridgeMessage.tryDecode(
            jsonEncode({
              'version': 1,
              'type': 'pause',
              'source': source,
              'commandId': 'spoofed',
            }),
          ),
          isNull,
        );
      }
    });

    test('restricts user source to playback controls', () {
      expect(
        WebPlaybackBridgeMessage.tryDecode(
          jsonEncode({'version': 1, 'type': 'ready', 'source': 'user'}),
        ),
        isNull,
      );
    });

    test('requires a bounded error message for errors', () {
      expect(
        WebPlaybackBridgeMessage.tryDecode(
          jsonEncode({'version': 1, 'type': 'error'}),
        ),
        isNull,
      );
      expect(
        WebPlaybackBridgeMessage.tryDecode(
          jsonEncode({
            'version': 1,
            'type': 'error',
            'error': 'player unavailable',
          }),
        ),
        isNotNull,
      );
    });

    test('rejects oversized bridge payloads', () {
      final oversized = jsonEncode({
        'version': 1,
        'type': 'error',
        'error': List.filled(
          WebPlaybackBridgeMessage.maxEncodedBytes,
          'x',
        ).join(),
      });

      expect(WebPlaybackBridgeMessage.tryDecode(oversized), isNull);
    });
  });
}
