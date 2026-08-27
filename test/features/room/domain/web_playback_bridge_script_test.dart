import 'package:flutter_test/flutter_test.dart';
import 'package:synctv_app/features/room/domain/web_playback_bridge_script.dart';
import 'package:synctv_app/features/room/domain/web_playback_command.dart';

void main() {
  group('web playback bridge script', () {
    test('contains the shared video discovery and rebinding runtime', () {
      expect(webPlaybackBridgeBootstrapScript, contains('MutationObserver'));
      expect(
        webPlaybackBridgeBootstrapScript,
        contains("querySelectorAll('video')"),
      );
      expect(
        webPlaybackBridgeBootstrapScript,
        contains("querySelectorAll('iframe')"),
      );
      expect(webPlaybackBridgeBootstrapScript, contains('setPhaseDetector'));
      expect(
        webPlaybackBridgeBootstrapScript,
        contains('pendingCommands.clear()'),
      );
      expect(webPlaybackBridgeBootstrapScript, contains('existing.start()'));
    });

    test('limits the privileged bridge to top-level official origins', () {
      expect(
        webPlaybackBridgeBootstrapScript,
        contains("'https://www.iqiyi.com'"),
      );
      expect(
        webPlaybackBridgeBootstrapScript,
        contains("'https://v.qq.com'"),
      );
      expect(
        webPlaybackBridgeBootstrapScript,
        contains('window.top !== window.self'),
      );
      expect(
        webPlaybackBridgeBootstrapScript,
        contains('PRIVILEGED_ORIGINS.has(window.location.origin)'),
      );
    });

    test('does not publish ended when the active phase is an advertisement', () {
      expect(
        webPlaybackBridgeBootstrapScript,
        contains("phase !== 'content'"),
      );
      expect(
        webPlaybackBridgeBootstrapScript,
        contains("phase !== 'buffering'"),
      );
      expect(webPlaybackBridgeBootstrapScript, contains("phase !== 'ended'"));
    });

    test('serializes command arguments as JSON instead of string interpolation', () {
      final script = buildWebPlaybackCommandScript(
        WebPlaybackCommand.seek(
          'remote-1',
          const Duration(milliseconds: 92500),
        ),
      );

      expect(
        script,
        'window.__synctvPlaybackBridge?.command('
        '{"id":"remote-1","type":"seek","position":92.5});',
      );
    });

    test('builds startup after transport and phase detector binding', () {
      final script = buildWebPlaybackBridgeStartScript(
        transportFunctionExpression: '(message) => Bridge.postMessage(message)',
        phaseDetectorFunctionExpression: '(video, document) => "content"',
      );

      expect(
        script,
        startsWith('window.__synctvPlaybackBridge?.setTransport('),
      );
      expect(script, contains('setPhaseDetector('));
      expect(script, endsWith('window.__synctvPlaybackBridge?.start();'));
    });
  });
}
