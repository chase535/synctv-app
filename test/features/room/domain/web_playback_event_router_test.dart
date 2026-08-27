import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:synctv_app/features/room/domain/web_playback_command.dart';
import 'package:synctv_app/features/room/domain/web_playback_event_router.dart';

void main() {
  group('WebPlaybackEventRouter', () {
    test('routes explicit user controls as local intents', () {
      final router = WebPlaybackEventRouter();

      final route = router.routeRaw(
        jsonEncode({
          'version': 1,
          'type': 'seek',
          'source': 'user',
          'position': 42.25,
        }),
      );

      expect(route, isNotNull);
      expect(route!.commandAcknowledged, isFalse);
      expect(route.localIntent?.type, WebPlaybackLocalIntentType.seek);
      expect(route.localIntent?.positionSeconds, 42.25);
    });

    test('keeps passive page controls out of room reporting', () {
      final router = WebPlaybackEventRouter();

      final route = router.routeRaw(
        jsonEncode({'version': 1, 'type': 'pause', 'source': 'page'}),
      );

      expect(route, isNotNull);
      expect(route!.localIntent, isNull);
      expect(route.commandAcknowledged, isFalse);
    });

    test('acknowledges only a matching remembered command', () {
      final router = WebPlaybackEventRouter();
      final now = DateTime.utc(2026, 8, 27, 12);
      router.rememberCommand(
        WebPlaybackCommand.seek('sync-1', const Duration(seconds: 42)),
        now: now,
      );

      final route = router.routeRaw(
        jsonEncode({
          'version': 1,
          'type': 'seek',
          'source': 'command',
          'commandId': 'sync-1',
          'position': 42,
        }),
        now: now.add(const Duration(seconds: 1)),
      );

      expect(route, isNotNull);
      expect(route!.commandAcknowledged, isTrue);
      expect(route.localIntent, isNull);
    });

    test('rejects spoofed and mismatched command echoes', () {
      final router = WebPlaybackEventRouter();
      final now = DateTime.utc(2026, 8, 27, 12);
      router.rememberCommand(
        WebPlaybackCommand.seek('sync-2', const Duration(seconds: 12)),
        now: now,
      );

      expect(
        router.routeRaw(
          jsonEncode({
            'version': 1,
            'type': 'pause',
            'source': 'command',
            'commandId': 'missing',
          }),
          now: now,
        ),
        isNull,
      );
      expect(
        router.routeRaw(
          jsonEncode({
            'version': 1,
            'type': 'play',
            'source': 'command',
            'commandId': 'sync-2',
          }),
          now: now,
        ),
        isNull,
      );
      expect(
        router.routeRaw(
          jsonEncode({
            'version': 1,
            'type': 'seek',
            'source': 'command',
            'commandId': 'sync-2',
            'position': 12,
          }),
          now: now,
        ),
        isNotNull,
      );
    });

    test('rejects command echoes after retention expires', () {
      final router = WebPlaybackEventRouter();
      final now = DateTime.utc(2026, 8, 27, 12);
      router.rememberCommand(WebPlaybackCommand.pause('sync-3'), now: now);

      final route = router.routeRaw(
        jsonEncode({
          'version': 1,
          'type': 'pause',
          'source': 'command',
          'commandId': 'sync-3',
        }),
        now: now.add(const Duration(seconds: 11)),
      );

      expect(route, isNull);
    });

    test('command errors acknowledge the matching pending command', () {
      final router = WebPlaybackEventRouter();
      router.rememberCommand(WebPlaybackCommand.play('sync-4'));

      final route = router.routeRaw(
        jsonEncode({
          'version': 1,
          'type': 'error',
          'source': 'command',
          'commandId': 'sync-4',
          'error': 'play rejected',
        }),
      );

      expect(route?.commandAcknowledged, isTrue);
    });
  });

  group('WebPlaybackCommand', () {
    test('serializes bounded seek and rate arguments', () {
      expect(
        WebPlaybackCommand.seek(
          'seek-1',
          const Duration(milliseconds: 1250),
        ).toArguments(),
        {'id': 'seek-1', 'type': 'seek', 'position': 1.25},
      );
      expect(WebPlaybackCommand.rate('rate-1', 1.5).toArguments(), {
        'id': 'rate-1',
        'type': 'rate',
        'playbackRate': 1.5,
      });
    });

    test('rejects invalid command values', () {
      expect(() => WebPlaybackCommand.play(''), throwsArgumentError);
      expect(
        () => WebPlaybackCommand.seek('seek', const Duration(seconds: -1)),
        throwsRangeError,
      );
      expect(() => WebPlaybackCommand.rate('rate', 0), throwsRangeError);
    });
  });
}
