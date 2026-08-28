import 'package:flutter_test/flutter_test.dart';
import 'package:synctv_app/contracts/web_playback_site.dart';
import 'package:synctv_app/core/web/official_site_login_target.dart';

void main() {
  group('official-site login targets', () {
    test('iQIYI opens its dedicated official login surface', () {
      expect(
        officialSiteLoginEntryUri(WebPlaybackProvider.iqiyi),
        Uri.https('www.iqiyi.com', '/iframe/loginreg'),
      );
      expect(
        officialSiteLoginProviderName(WebPlaybackProvider.iqiyi),
        '爱奇艺',
      );
    });

    test('Tencent opens its official video site for current account login UI', () {
      expect(
        officialSiteLoginEntryUri(WebPlaybackProvider.tencentVideo),
        Uri.https('v.qq.com', '/'),
      );
      expect(
        officialSiteLoginProviderName(WebPlaybackProvider.tencentVideo),
        '腾讯视频',
      );
    });
  });
}
