import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:synctv_app/contracts/web_playback_site.dart';
import 'package:synctv_app/features/media_library/application/web_playback_link_resolver.dart';

void main() {
  test(
    'prefers desktop iQIYI tvid redirect over generic mobile redirect',
    () async {
      var qyRequests = 0;
      final client = MockClient((request) async {
        if (request.url.host == 'qy.net') {
          qyRequests += 1;
          final userAgent = request.headers['user-agent'] ?? '';
          if (userAgent.contains('Mobile')) {
            return http.Response(
              '',
              302,
              headers: {'location': 'https://www.iqiyi.com/'},
              request: request,
            );
          }
          return http.Response(
            '',
            302,
            headers: {
              'location':
                  'https://www.iqiyi.com/playShare.html?tvid=1234567890123400'
                  '&social_platform=link',
            },
            request: request,
          );
        }

        expect(request.url.host, 'mesh.if.iqiyi.com');
        expect(request.url.path, '/tvg/play/mixer');
        expect(request.url.queryParameters['id'], '1234567890123400');
        return http.Response(
          '{"retcode":200,"data":{"pageurl_iqiyi_pc":'
          '"https://www.iqiyi.com/v_test_redirect_priority_1.html"}}',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      final resolver = WebPlaybackLinkResolver(client: client);

      final uri = await resolver.resolve(
        'https://qy.net/TestPriority_123',
        provider: WebPlaybackProvider.iqiyi,
      );

      expect(qyRequests, 2);
      expect(
        uri.toString(),
        'https://www.iqiyi.com/v_test_redirect_priority_1.html',
      );
    },
  );

  test('resolves tvid metadata from a trusted non-playShare iQIYI URL', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'mesh.if.iqiyi.com');
      expect(request.url.queryParameters['id'], '2234567890123400');
      return http.Response(
        '{"retcode":200,"data":{"pageurl_iqiyi_pc":'
        '"https://www.iqiyi.com/v_test_query_tvid_1.html"}}',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    final resolver = WebPlaybackLinkResolver(client: client);

    final uri = await resolver.resolve(
      'https://www.iqiyi.com/?tvid=2234567890123400',
      provider: WebPlaybackProvider.iqiyi,
    );

    expect(uri.toString(), 'https://www.iqiyi.com/v_test_query_tvid_1.html');
  });
}
