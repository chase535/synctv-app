import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:synctv_app/contracts/web_playback_site.dart';
import 'package:synctv_app/features/media_library/application/web_playback_link_resolver.dart';

void main() {
  group('WebPlaybackLinkResolver', () {
    test('resolves iQIYI qy.net app share links to canonical episodes', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://qy.net/TestShare_123');
        expect(request.followRedirects, isFalse);
        return http.Response(
          '',
          302,
          headers: {
            'location':
                'https://www.iqiyi.com/iex/v_test_share_video_1.html?vfrm=share',
          },
          request: request,
        );
      });
      final resolver = WebPlaybackLinkResolver(client: client);

      final uri = await resolver.resolve(
        'https://qy.net/TestShare_123',
        provider: WebPlaybackProvider.iqiyi,
      );

      expect(
        uri.toString(),
        'https://www.iqiyi.com/iex/v_test_share_video_1.html',
      );
    });

    test('extracts an official link from copied share text', () async {
      final client = MockClient((request) async {
        return http.Response(
          '',
          302,
          headers: {
            'location': 'https://www.iqiyi.com/v_test_share_video_2.html',
          },
          request: request,
        );
      });
      final resolver = WebPlaybackLinkResolver(client: client);

      final uri = await resolver.resolve(
        '我正在爱奇艺看这个视频：https://qy.net/TestShare_456，复制链接一起看',
        provider: WebPlaybackProvider.iqiyi,
      );

      expect(uri.toString(), 'https://www.iqiyi.com/v_test_share_video_2.html');
    });

    test('resolves Tencent url.cn links through mobile share URLs', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'url.cn');
        return http.Response(
          '',
          302,
          headers: {
            'location':
                'https://m.v.qq.com/x/m/play?cid=test_collection_1&vid=test_video_1&url_from=share',
          },
          request: request,
        );
      });
      final resolver = WebPlaybackLinkResolver(client: client);

      final uri = await resolver.resolve(
        'https://url.cn/TestShare_123',
        provider: WebPlaybackProvider.tencentVideo,
      );

      expect(
        uri.toString(),
        'https://v.qq.com/x/cover/test_collection_1/test_video_1.html',
      );
    });

    test(
      'accepts legacy http Tencent mobile links by upgrading to https',
      () async {
        final client = MockClient((request) async {
          fail('direct recognizable links must not perform a network request');
        });
        final resolver = WebPlaybackLinkResolver(client: client);

        final uri = await resolver.resolve(
          'http://m.v.qq.com/play.html?cid=&vid=test_video_2&url_from=share',
          provider: WebPlaybackProvider.tencentVideo,
        );

        expect(uri.toString(), 'https://v.qq.com/x/page/test_video_2.html');
      },
    );

    test(
      'rejects redirects that leave the selected provider trust boundary',
      () async {
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
            'https://qy.net/TestShare_789',
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
      },
    );

    test('rejects a share host belonging to the other provider', () async {
      final resolver = WebPlaybackLinkResolver(
        client: MockClient((request) async => http.Response('', 500)),
      );

      await expectLater(
        resolver.resolve(
          'https://url.cn/TestShare_456',
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
          'https://www.iqiyi.com/a_test_album_1.html',
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
