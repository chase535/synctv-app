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
      expect(
        webPlaybackBridgeBootstrapScript,
        contains('setInterval(refresh, 500)'),
      );
      expect(webPlaybackBridgeBootstrapScript, contains('attributes: true'));
    });

    test('limits the privileged bridge to top-level official origins', () {
      expect(
        webPlaybackBridgeBootstrapScript,
        contains("'https://www.iqiyi.com'"),
      );
      expect(webPlaybackBridgeBootstrapScript, contains("'https://v.qq.com'"));
      expect(
        webPlaybackBridgeBootstrapScript,
        contains('window.top !== window.self'),
      );
      expect(
        webPlaybackBridgeBootstrapScript,
        contains('PRIVILEGED_ORIGINS.has(window.location.origin)'),
      );
      expect(webPlaybackBridgeBootstrapScript, contains('token: sessionToken'));
      expect(webPlaybackBridgeBootstrapScript, contains('setSessionToken'));
    });

    test('tracks blocking and non-blocking advertisements separately', () {
      expect(
        webPlaybackBridgeBootstrapScript,
        contains("'overlayAdvertisement'"),
      );
      expect(
        webPlaybackBridgeBootstrapScript,
        contains("phase === 'advertisement'"),
      );
      expect(
        webPlaybackBridgeBootstrapScript,
        contains(
          'Content timeline is unavailable during a blocking advertisement',
        ),
      );
    });

    test('command errors include the current playback phase', () {
      expect(
        webPlaybackBridgeBootstrapScript,
        contains("Object.assign(\n        {\n          type: 'error'"),
      );
      expect(webPlaybackBridgeBootstrapScript, contains('phasePayload()'));
    });

    test('publishes advertisement-kind changes within the same phase', () {
      expect(
        webPlaybackBridgeBootstrapScript,
        contains('normalizedAdvertisementKind === advertisementKind'),
      );
      expect(
        webPlaybackBridgeBootstrapScript,
        contains('advertisementKind = normalizedAdvertisementKind'),
      );
    });

    test(
      'does not publish ended when the active phase is a blocking advertisement',
      () {
        expect(
          webPlaybackBridgeBootstrapScript,
          contains("phase !== 'content'"),
        );
        expect(
          webPlaybackBridgeBootstrapScript,
          contains("phase !== 'buffering'"),
        );
        expect(
          webPlaybackBridgeBootstrapScript,
          contains("phase !== 'overlayAdvertisement'"),
        );
        expect(webPlaybackBridgeBootstrapScript, contains("phase !== 'ended'"));
      },
    );

    test(
      'serializes command arguments as JSON instead of string interpolation',
      () {
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
      },
    );

    test('builds authenticated startup before transport binding', () {
      const token = '0123456789abcdef0123456789abcdef';
      final script = buildWebPlaybackBridgeStartScript(
        bridgeToken: token,
        transportFunctionExpression: '(message) => Bridge.postMessage(message)',
        phaseDetectorFunctionExpression: '(video, document) => "content"',
      );

      expect(
        script,
        startsWith('window.__synctvPlaybackBridge?.setSessionToken("$token");'),
      );
      expect(script, contains('setTransport('));
      expect(script, contains('setPhaseDetector('));
      expect(script, endsWith('window.__synctvPlaybackBridge?.start();'));
    });

    test('rejects startup tokens that are too short', () {
      expect(
        () => buildWebPlaybackBridgeStartScript(
          bridgeToken: 'short',
          transportFunctionExpression:
              '(message) => Bridge.postMessage(message)',
        ),
        throwsArgumentError,
      );
    });
  });
}
