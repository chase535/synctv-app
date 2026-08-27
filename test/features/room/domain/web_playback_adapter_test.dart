import 'package:flutter_test/flutter_test.dart';
import 'package:synctv_app/features/room/domain/adapters/iqiyi_web_playback_adapter.dart';
import 'package:synctv_app/features/room/domain/adapters/tencent_video_web_playback_adapter.dart';
import 'package:synctv_app/features/room/domain/web_playback_adapter_registry.dart';
import 'package:synctv_app/features/room/domain/web_playback_navigation.dart';
import 'package:synctv_app/features/room/domain/web_playback_phase_detector.dart';
import 'package:synctv_app/features/room/domain/web_playback_site.dart';

void main() {
  group('WebPlaybackAdapterRegistry', () {
    test('resolves supported provider sites and media separately', () {
      final site = WebPlaybackAdapterRegistry.standard.forSiteUri(
        Uri.parse('https://www.iqiyi.com/iframe/loginreg'),
      );
      final media = WebPlaybackAdapterRegistry.standard.forMediaUri(
        Uri.parse('https://www.iqiyi.com/v_19rrn9o9n8.html'),
      );

      expect(site?.provider, WebPlaybackProvider.iqiyi);
      expect(media?.provider, WebPlaybackProvider.iqiyi);
      expect(
        WebPlaybackAdapterRegistry.standard.forMediaUri(
          Uri.parse('https://www.iqiyi.com/iframe/loginreg'),
        ),
        isNull,
      );
    });

    test('resolves Tencent Video media without accepting auth hosts as media', () {
      final adapter = WebPlaybackAdapterRegistry.standard.forMediaUri(
        Uri.parse('https://v.qq.com/x/cover/nhtfh14i9y1egge/d00249ld45q.html'),
      );

      expect(adapter?.provider, WebPlaybackProvider.tencentVideo);
      expect(
        WebPlaybackAdapterRegistry.standard.forSiteUri(
          Uri.parse('https://graph.qq.com/oauth2.0/authorize'),
        ),
        isNull,
      );
    });
  });

  group('web playback adapter navigation', () {
    const iqiyi = IqiyiWebPlaybackAdapter();
    const tencent = TencentVideoWebPlaybackAdapter();

    test('keeps playback origins privileged and auth origins unprivileged', () {
      expect(
        iqiyi.classifyNavigation(
          Uri.parse('https://www.iqiyi.com/v_19rrn9o9n8.html'),
          isMainFrame: true,
        ),
        WebPlaybackNavigationDisposition.allowPrivileged,
      );
      expect(
        iqiyi.classifyNavigation(
          Uri.parse('https://passport.iqiyi.com/pages/login.action'),
          isMainFrame: true,
        ),
        WebPlaybackNavigationDisposition.allowUnprivileged,
      );
      expect(
        tencent.classifyNavigation(
          Uri.parse('https://graph.qq.com/oauth2.0/authorize'),
          isMainFrame: true,
        ),
        WebPlaybackNavigationDisposition.allowUnprivileged,
      );
      expect(
        tencent.classifyNavigation(
          Uri.parse('https://www.iqiyi.com/v_19rrn9o9n8.html'),
          isMainFrame: true,
        ),
        WebPlaybackNavigationDisposition.block,
      );
      expect(
        tencent.classifyNavigation(
          Uri.parse('https://evil.qq.com/login'),
          isMainFrame: true,
        ),
        WebPlaybackNavigationDisposition.block,
      );
    });

    test('allows HTTPS subframes without granting bridge privilege', () {
      expect(
        tencent.classifyNavigation(
          Uri.parse('https://xui.ptlogin2.qq.com/cgi-bin/xlogin'),
          isMainFrame: false,
        ),
        WebPlaybackNavigationDisposition.allowUnprivileged,
      );
      expect(
        tencent.classifyNavigation(
          Uri.parse('http://unsafe.example/frame'),
          isMainFrame: false,
        ),
        WebPlaybackNavigationDisposition.block,
      );
    });

    test(
      'about blank is allowed only as unprivileged main-frame bootstrap',
      () {
        expect(
          iqiyi.classifyNavigation(Uri.parse('about:blank'), isMainFrame: true),
          WebPlaybackNavigationDisposition.allowUnprivileged,
        );
      },
    );
  });

  test('phase detector is geometry-aware and recognizes pause/overlay ads', () {
    expect(webPlaybackOverlayPhaseDetector, contains('getBoundingClientRect'));
    expect(webPlaybackOverlayPhaseDetector, contains('overlapWidth'));
    expect(webPlaybackOverlayPhaseDetector, contains('暂停广告'));
    expect(webPlaybackOverlayPhaseDetector, contains('overlayAdvertisement'));
    expect(
      const IqiyiWebPlaybackAdapter().phaseDetectorFunctionExpression,
      webPlaybackOverlayPhaseDetector,
    );
    expect(
      const TencentVideoWebPlaybackAdapter().phaseDetectorFunctionExpression,
      webPlaybackOverlayPhaseDetector,
    );
  });
}
