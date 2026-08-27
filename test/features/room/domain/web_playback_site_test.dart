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
          Uri.parse('https://v.qq.com/x/cover/example/example.html'),
        )?.provider,
        WebPlaybackProvider.tencentVideo,
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
        WebPlaybackSitePolicy.forUri(
          Uri.parse('https://v.qq.com:8443/x/cover/a/b.html'),
        ),
        isNull,
      );
    });
  });
}
