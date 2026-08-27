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

    test('decodes playback phase events', () {
      final message = WebPlaybackBridgeMessage.tryDecode(
        jsonEncode({
          'version': 1,
          'type': 'phase',
          'source': 'page',
          'phase': 'advertisement',
        }),
      );

      expect(message?.phase, WebPlaybackPhase.advertisement);
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
      expect(WebPlaybackBridgeMessage.tryDecode('{not-json'), isNull);
    });

    test('requires command ids for command-sourced events', () {
      expect(
        WebPlaybackBridgeMessage.tryDecode(
          jsonEncode({
            'version': 1,
            'type': 'pause',
            'source': 'command',
          }),
        ),
        isNull,
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
