import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:synctv_app/contracts/web_playback_site.dart';
import 'package:synctv_app/features/media_library/application/web_playback_link_resolver.dart';

void main() {
  test('resolves qy.net redirects to mobile iQIYI playShare pages', () async {
    var qyRequests = 0;
    var mixerRequests = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'qy.net') {
        qyRequests += 1;
        return http.Response(
          '',
          302,
          headers: {
            'location':
                'https://m.iqiyi.com/m/playShare?shareId=TestShare_123'
                '&positiveId=MTIzNDU2Nzg5MDEyMzQwMA%3D%3D'
                '&type=0&rpage=sharepage_new'
                '&v=MjM0NTY3ODkwMTIzNDUwMA%3D%3D'
                '&social_platform=link',
          },
          request: request,
        );
      }

      mixerRequests += 1;
      expect(request.url.host, 'mesh.if.iqiyi.com');
      expect(request.url.path, '/tvg/play/mixer');
      expect(request.url.queryParameters['id'], '1234567890123400');
      return http.Response(
        '{"retcode":200,"data":{"pageurl_iqiyi_pc":'
        '"https://www.iqiyi.com/v_test_mobile_share_landing_1.html"}}',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    final resolver = WebPlaybackLinkResolver(client: client);

    final uri = await resolver.resolve(
      'https://qy.net/TestMobileLanding_123',
      provider: WebPlaybackProvider.iqiyi,
    );

    expect(qyRequests, greaterThanOrEqualTo(1));
    expect(mixerRequests, 1);
    expect(
      uri.toString(),
      'https://www.iqiyi.com/v_test_mobile_share_landing_1.html',
    );
  });
}
