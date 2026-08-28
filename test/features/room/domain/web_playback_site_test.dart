import 'package:flutter_test/flutter_test.dart';
import 'package:synctv_app/features/room/domain/web_playback_site.dart';

void main() {
  group('WebPlaybackSitePolicy', () {
    test('detects supported official playback hosts', () {
      expect(
        WebPlaybackSitePolicy.forUri(
          Uri.parse('https://www.iqiyi.com/iex/v_19rrlo7rno.html'),
        )?.provider,
        WebPlaybackProvider.iqiyi,
      );
      expect(
        WebPlaybackSitePolicy.forUri(
          Uri.parse('https://m.iqiyi.com/v_19rrlo7rno.html'),
        )?.provider,
        WebPlaybackProvider.iqiyi,
      );
      expect(
        WebPlaybackSitePolicy.forUri(
          Uri.parse('https://v.qq.com/x/cover/example/example.html'),
        )?.provider,
        WebPlaybackProvider.tencentVideo,
      );
      expect(
        WebPlaybackSitePolicy.forUri(
          Uri.parse('https://m.v.qq.com/x/m/play?vid=example'),
        )?.provider,
        WebPlaybackProvider.tencentVideo,
      );
    });

    test('recognizes official share and redirect entry hosts separately', () {
      expect(
        WebPlaybackSitePolicy.forInputUri(
          Uri.parse('https://qy.net/4aJQrYo-ef'),
        )?.provider,
        WebPlaybackProvider.iqiyi,
      );
      expect(
        WebPlaybackSitePolicy.forInputUri(
          Uri.parse('https://url.cn/example'),
        )?.provider,
        WebPlaybackProvider.tencentVideo,
      );
      expect(
        WebPlaybackSitePolicy.forInputUri(
          Uri.parse('https://m.q.qq.com/a/s/example'),
        )?.provider,
        WebPlaybackProvider.tencentVideo,
      );

      // Short/share hosts are accepted as input but are never privileged
      // playback WebView hosts.
      expect(
        WebPlaybackSitePolicy.forUri(Uri.parse('https://qy.net/4aJQrYo-ef')),
        isNull,
      );
      expect(
        WebPlaybackSitePolicy.forUri(Uri.parse('https://url.cn/example')),
        isNull,
      );
    });

    test('requires https and exact hosts', () {
      expect(
        WebPlaybackSitePolicy.forUri(
          Uri.parse('http://www.iqiyi.com/iex/v_example.html'),
        ),
        isNull,
      );
      expect(
        WebPlaybackSitePolicy.forInputUri(Uri.parse('http://qy.net/example')),
        isNull,
      );
      expect(
        WebPlaybackSitePolicy.forInputUri(
          Uri.parse('https://qy.net.evil.example/example'),
        ),
        isNull,
      );
      expect(
        WebPlaybackSitePolicy.forUri(
          Uri.parse('https://www.iqiyi.com.evil.example/iex/v_example.html'),
        ),
        isNull,
      );
      expect(
        WebPlaybackSitePolicy.forUri(
          Uri.parse('https://v.qq.com.evil.example/x/cover/a/b.html'),
        ),
        isNull,
      );
    });

    test('rejects credentials and non-standard ports', () {
      expect(
        WebPlaybackSitePolicy.forUri(
          Uri.parse('https://user:pass@www.iqiyi.com/iex/v_example.html'),
        ),
        isNull,
      );
      expect(
        WebPlaybackSitePolicy.forInputUri(
          Uri.parse('https://user:pass@qy.net/example'),
        ),
        isNull,
      );
      expect(
        WebPlaybackSitePolicy.forUri(
          Uri.parse('https://v.qq.com:8443/x/cover/a/b.html'),
        ),
        isNull,
      );
    });
  });
}
