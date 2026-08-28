import 'package:flutter_test/flutter_test.dart';
import 'package:synctv_app/features/room/domain/web_playback_bridge_message.dart';
import 'package:synctv_app/features/room/domain/web_playback_command.dart';
import 'package:synctv_app/features/room/domain/web_playback_command_tracker.dart';

void main() {
  group('WebPlaybackCommandTracker', () {
    test('new command of the same type supersedes the old command', () {
      final tracker = WebPlaybackCommandTracker();
      final now = DateTime.utc(2026, 8, 27, 12);

      tracker.remember(
        WebPlaybackCommand.seek('seek-old', const Duration(seconds: 10)),
        now: now,
      );
      tracker.remember(
        WebPlaybackCommand.seek('seek-new', const Duration(seconds: 20)),
        now: now.add(const Duration(milliseconds: 10)),
      );

      expect(tracker.pendingCount, 1);
      expect(
        tracker.acknowledge(
          const WebPlaybackBridgeMessage(
            type: WebPlaybackBridgeEventType.seek,
            source: WebPlaybackBridgeEventSource.command,
            commandId: 'seek-old',
            positionSeconds: 10,
          ),
          now: now.add(const Duration(milliseconds: 20)),
        ),
        isFalse,
      );
      expect(
        tracker.acknowledge(
          const WebPlaybackBridgeMessage(
            type: WebPlaybackBridgeEventType.seek,
            source: WebPlaybackBridgeEventSource.command,
            commandId: 'seek-new',
            positionSeconds: 20,
          ),
          now: now.add(const Duration(milliseconds: 20)),
        ),
        isTrue,
      );
    });

    test('different command types can remain pending together', () {
      final tracker = WebPlaybackCommandTracker();
      tracker.remember(WebPlaybackCommand.play('play-1'));
      tracker.remember(
        WebPlaybackCommand.seek('seek-1', const Duration(seconds: 5)),
      );

      expect(tracker.pendingCount, 2);
    });

    test('forget removes a command after JavaScript invocation failure', () {
      final tracker = WebPlaybackCommandTracker();
      tracker.remember(WebPlaybackCommand.play('play-failed'));

      expect(tracker.forget('play-failed'), isTrue);
      expect(tracker.pendingCount, 0);
      expect(tracker.forget('play-failed'), isFalse);
    });

    test('constructor rejects invalid retention and capacity', () {
      expect(
        () => WebPlaybackCommandTracker(retention: const Duration(seconds: -1)),
        throwsArgumentError,
      );
      expect(
        () => WebPlaybackCommandTracker(maxPending: 0),
        throwsArgumentError,
      );
    });
  });
}
