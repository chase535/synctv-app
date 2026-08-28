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

    test('uses mobile browser semantics for iQIYI short share links', () async {
      final client = MockClient((request) async {
        expect(request.headers['user-agent'], contains('Mobile'));
        return http.Response(
          '',
          302,
          headers: {
            'location': 'https://www.iqiyi.com/v_test_mobile_share_1.html',
          },
          request: request,
        );
      });
      final resolver = WebPlaybackLinkResolver(client: client);

      final uri = await resolver.resolve(
        'https://qy.net/TestMobileShare_123',
        provider: WebPlaybackProvider.iqiyi,
      );

      expect(uri.toString(), 'https://www.iqiyi.com/v_test_mobile_share_1.html');
    });

    test(
      'uses mobile share semantics for iQIYI playShare landing pages',
      () async {
        final client = MockClient((request) async {
          expect(request.url.host, 'www.iqiyi.com');
          expect(request.url.path, '/playShare.html');
          expect(request.url.queryParameters['shareId'], 'TestShare');
          expect(request.url.queryParameters['positiveId'], 'TestPositive');
          expect(request.headers['user-agent'], contains('Mobile'));
          return http.Response(
            '',
            302,
            headers: {
              'location': 'https://www.iqiyi.com/v_test_play_share_1.html',
            },
            request: request,
          );
        });
        final resolver = WebPlaybackLinkResolver(client: client);

        final uri = await resolver.resolve(
          'https://www.iqiyi.com/playShare.html?shareId=TestShare'
          '&positiveId=TestPositive&type=0&is_short_id=1&social_platform=link',
          provider: WebPlaybackProvider.iqiyi,
        );

        expect(uri.toString(), 'https://www.iqiyi.com/v_test_play_share_1.html');
      },
    );

    test(
      'resolves qy.net links that land on iQIYI playShare tvid pages',
      () async {
        var requestCount = 0;
        final client = MockClient((request) async {
          requestCount += 1;
          if (request.url.host == 'qy.net') {
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
          expect(request.url.queryParameters['fid'], '');
          return http.Response(
            '{"retcode":200,"data":{"pageurl_iqiyi_pc":'
            '"https://www.iqiyi.com/v_test_mixer_share_1.html"}}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        });
        final resolver = WebPlaybackLinkResolver(client: client);

        final uri = await resolver.resolve(
          'https://qy.net/TestTvidShare_123',
          provider: WebPlaybackProvider.iqiyi,
        );

        expect(requestCount, 2);
        expect(uri.toString(), 'https://www.iqiyi.com/v_test_mixer_share_1.html');
      },
    );

    test(
      'decodes synthetic iQIYI playShare ids before metadata lookup',
      () async {
        final client = MockClient((request) async {
          expect(request.url.host, 'mesh.if.iqiyi.com');
          expect(request.url.path, '/tvg/play/mixer');
          expect(request.url.queryParameters['id'], '1234567890123400');
          return http.Response(
            '{"retcode":200,"data":{"pageurl_iqiyi_pc":'
            '"https://www.iqiyi.com/v_test_encoded_share_1.html"}}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        });
        final resolver = WebPlaybackLinkResolver(client: client);

        final uri = await resolver.resolve(
          'https://www.iqiyi.com/playShare.html?'
          'shareId=MzQ1Njc4OTAxMjM0NTYwMA%3D%3D'
          '&positiveId=MTIzNDU2Nzg5MDEyMzQwMA%3D%3D'
          '&type=0&is_short_id=1'
          '&v=MjM0NTY3ODkwMTIzNDUwMA%3D%3D'
          '&social_platform=link',
          provider: WebPlaybackProvider.iqiyi,
        );

        expect(uri.toString(), 'https://www.iqiyi.com/v_test_encoded_share_1.html');
      },
    );

    test(
      'falls back to desktop semantics when a mobile share redirect is generic',
      () async {
        var requestCount = 0;
        final client = MockClient((request) async {
          requestCount += 1;
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
              'location': 'https://www.iqiyi.com/v_test_desktop_share_1.html',
            },
            request: request,
          );
        });
        final resolver = WebPlaybackLinkResolver(client: client);

        final uri = await resolver.resolve(
          'https://qy.net/TestUaFallback_123',
          provider: WebPlaybackProvider.iqiyi,
        );

        expect(requestCount, 2);
        expect(
          uri.toString(),
          'https://www.iqiyi.com/v_test_desktop_share_1.html',
        );
      },
    );

    test('resolves iQIYI share pages that use HTML meta refresh', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://qy.net/TestMetaShare_123');
        return http.Response(
          '''
<html>
<head>
<meta http-equiv="refresh" content="0; url=https://www.iqiyi.com/v_test_meta_video_1.html?vfrm=share">
</head>
</html>
''',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
          request: request,
        );
      });
      final resolver = WebPlaybackLinkResolver(client: client);

      final uri = await resolver.resolve(
        'https://qy.net/TestMetaShare_123',
        provider: WebPlaybackProvider.iqiyi,
      );

      expect(uri.toString(), 'https://www.iqiyi.com/v_test_meta_video_1.html');
    });

    test('resolves iQIYI share pages that use JavaScript redirects', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://qy.net/TestJsShare_123');
        return http.Response(
          r'''
<html>
<body>
<script>
window.location.replace("https:\/\/www.iqiyi.com\/iex\/v_test_js_video_1.html?vfrm=share");
</script>
</body>
</html>
''',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
          request: request,
        );
      });
      final resolver = WebPlaybackLinkResolver(client: client);

      final uri = await resolver.resolve(
        'https://qy.net/TestJsShare_123',
        provider: WebPlaybackProvider.iqiyi,
      );

      expect(
        uri.toString(),
        'https://www.iqiyi.com/iex/v_test_js_video_1.html',
      );
    });

    test(
      'prefers embedded iQIYI episodes over generic share-page metadata',
      () async {
        var requestCount = 0;
        final client = MockClient((request) async {
          requestCount += 1;
          return http.Response(
            r'''
<html>
<head>
<meta property="og:url" content="https://www.iqiyi.com/">
<link rel="canonical" href="https://www.iqiyi.com/">
</head>
<body>
<script>
window.__SHARE_DATA__ = {
  "playUrl": "https:\/\/www.iqiyi.com\/v_test_embedded_video_1.html?vfrm=share"
};
</script>
</body>
</html>
''',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
            request: request,
          );
        });
        final resolver = WebPlaybackLinkResolver(client: client);

        final uri = await resolver.resolve(
          'https://qy.net/TestEmbeddedShare_123',
          provider: WebPlaybackProvider.iqiyi,
        );

        expect(requestCount, 1);
        expect(
          uri.toString(),
          'https://www.iqiyi.com/v_test_embedded_video_1.html',
        );
      },
    );

    test(
      'accepts iqiyi.cn official share links as resolution inputs',
      () async {
        final client = MockClient((request) async {
          expect(request.url.toString(), 'https://iqiyi.cn/TestShare_123');
          return http.Response(
            '',
            302,
            headers: {
              'location': 'https://www.iqiyi.com/v_test_cn_video_1.html',
            },
            request: request,
          );
        });
        final resolver = WebPlaybackLinkResolver(client: client);

        final uri = await resolver.resolve(
          'https://iqiyi.cn/TestShare_123',
          provider: WebPlaybackProvider.iqiyi,
        );

        expect(uri.toString(), 'https://www.iqiyi.com/v_test_cn_video_1.html');
      },
    );

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
