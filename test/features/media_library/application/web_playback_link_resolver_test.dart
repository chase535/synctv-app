import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:synctv_app/features/media_library/application/web_playback_link_resolver.dart';
import 'package:synctv_app/features/room/domain/web_playback_site.dart';

void main() {
  group('WebPlaybackLinkResolver', () {
    test('resolves iQIYI qy.net app share links to canonical episodes', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://qy.net/4aJQrYo-ef');
        expect(request.followRedirects, isFalse);
        return http.Response(
          '',
          302,
          headers: {
            'location':
                'https://www.iqiyi.com/iex/v_19rrlo7rno.html?vfrm=share',
          },
          request: request,
        );
      });
      final resolver = WebPlaybackLinkResolver(client: client);

      final uri = await resolver.resolve(
        'https://qy.net/4aJQrYo-ef',
        provider: WebPlaybackProvider.iqiyi,
      );

      expect(
        uri.toString(),
        'https://www.iqiyi.com/iex/v_19rrlo7rno.html',
      );
    });

    test('extracts an official link from copied share text', () async {
      final client = MockClient((request) async {
        return http.Response(
          '',
          302,
          headers: {'location': 'https://www.iqiyi.com/v_19rrn9o9n8.html'},
          request: request,
        );
      });
      final resolver = WebPlaybackLinkResolver(client: client);

      final uri = await resolver.resolve(
        '我正在爱奇艺看这个视频：https://qy.net/4aJQrYo-ef，复制链接一起看',
        provider: WebPlaybackProvider.iqiyi,
      );

      expect(uri.toString(), 'https://www.iqiyi.com/v_19rrn9o9n8.html');
    });

    test('resolves Tencent url.cn links through mobile share URLs', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'url.cn');
        return http.Response(
          '',
          302,
          headers: {
            'location':
                'https://m.v.qq.com/x/m/play?cid=mzc00200cf43gaf&vid=7uHwAjgHuPJ&url_from=share',
          },
          request: request,
        );
      });
      final resolver = WebPlaybackLinkResolver(client: client);

      final uri = await resolver.resolve(
        'https://url.cn/example',
        provider: WebPlaybackProvider.tencentVideo,
      );

      expect(
        uri.toString(),
        'https://v.qq.com/x/cover/mzc00200cf43gaf/7uHwAjgHuPJ.html',
      );
    });

    test('accepts legacy http Tencent mobile links by upgrading to https', () async {
      final client = MockClient((request) async {
        fail('direct recognizable links must not perform a network request');
      });
      final resolver = WebPlaybackLinkResolver(client: client);

      final uri = await resolver.resolve(
        'http://m.v.qq.com/play.html?cid=&vid=t060641781b&url_from=share',
        provider: WebPlaybackProvider.tencentVideo,
      );

      expect(uri.toString(), 'https://v.qq.com/x/page/t060641781b.html');
    });

    test('rejects redirects that leave the selected provider trust boundary', () async {
      final client = MockClient((request) async {
        return http.Response(
          '',
          302,
          headers: {'location': 'https://evil.example/video.html'},
          request: request,
        );
      });
      final resolver = WebPlaybackLinkResolver(client: client);

      await expectLater(
        resolver.resolve(
          'https://qy.net/4aJQrYo-ef',
          provider: WebPlaybackProvider.iqiyi,
        ),
        throwsA(
          isA<WebPlaybackLinkResolutionException>().having(
            (error) => error.message,
            'message',
            contains('非当前视频平台'),
          ),
        ),
      );
    });

    test('rejects a share host belonging to the other provider', () async {
      final resolver = WebPlaybackLinkResolver(
        client: MockClient((request) async => http.Response('', 500)),
      );

      await expectLater(
        resolver.resolve(
          'https://url.cn/example',
          provider: WebPlaybackProvider.iqiyi,
        ),
        throwsA(
          isA<WebPlaybackLinkResolutionException>().having(
            (error) => error.message,
            'message',
            contains('不属于当前选择的视频平台'),
          ),
        ),
      );
    });

    test('rejects collection-only links with an actionable reason', () async {
      final resolver = WebPlaybackLinkResolver(
        client: MockClient((request) async {
          fail('collection identity should fail before a network request');
        }),
      );

      await expectLater(
        resolver.resolve(
          'https://www.iqiyi.com/a_1cul7zi24jt.html',
          provider: WebPlaybackProvider.iqiyi,
        ),
        throwsA(
          isA<WebPlaybackLinkResolutionException>().having(
            (error) => error.message,
            'message',
            contains('专辑/合集'),
          ),
        ),
      );
    });
  });
}
