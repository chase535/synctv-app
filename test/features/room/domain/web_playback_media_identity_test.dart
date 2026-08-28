import 'package:flutter_test/flutter_test.dart';
import 'package:synctv_app/features/room/domain/web_playback_media_identity.dart';
import 'package:synctv_app/features/room/domain/web_playback_site.dart';

void main() {
  group('WebPlaybackMediaIdentity', () {
    test('normalizes iQIYI video URLs without leaking query state', () {
      final identity = WebPlaybackMediaIdentity.tryParse(
        Uri.parse(
          'https://www.iqiyi.com/v_19rrn9o9n8.html?vfrm=pcw_home&token=local',
        ),
      );

      expect(identity, isNotNull);
      expect(identity!.provider, WebPlaybackProvider.iqiyi);
      expect(identity.kind, WebPlaybackMediaKind.iqiyiVideo);
      expect(identity.mediaId, '19rrn9o9n8');
      expect(identity.collectionId, isNull);
      expect(
        identity.canonicalUri.toString(),
        'https://www.iqiyi.com/v_19rrn9o9n8.html',
      );
    });

    test('accepts the iQIYI iex playback route variant', () {
      final identity = WebPlaybackMediaIdentity.tryParse(
        Uri.parse('https://www.iqiyi.com/iex/v_19rrlo7rno.html?foo=bar'),
      );

      expect(identity?.kind, WebPlaybackMediaKind.iqiyiVideo);
      expect(identity?.mediaId, '19rrlo7rno');
      expect(
        identity?.canonicalUri.toString(),
        'https://www.iqiyi.com/iex/v_19rrlo7rno.html',
      );
    });

    test('normalizes iQIYI mobile and legacy hosts to www.iqiyi.com', () {
      final mobile = WebPlaybackMediaIdentity.tryParse(
        Uri.parse('https://m.iqiyi.com/v_19rrlo7rno.html?from=app'),
      );
      final legacy = WebPlaybackMediaIdentity.tryParse(
        Uri.parse('https://www.qiyi.com/v_19rrlo7rno.html'),
      );

      expect(
        mobile?.canonicalUri.toString(),
        'https://www.iqiyi.com/v_19rrlo7rno.html',
      );
      expect(mobile?.stableKey, legacy?.stableKey);
    });

    test('parses iQIYI album identities', () {
      final identity = WebPlaybackMediaIdentity.tryParse(
        Uri.parse('https://www.iqiyi.com/a_1cul7zi24jt.html'),
      );

      expect(identity?.kind, WebPlaybackMediaKind.iqiyiAlbum);
      expect(identity?.collectionId, '1cul7zi24jt');
      expect(identity?.mediaId, isNull);
    });

    test('parses Tencent cover episode identities', () {
      final identity = WebPlaybackMediaIdentity.tryParse(
        Uri.parse(
          'https://v.qq.com/x/cover/nhtfh14i9y1egge/d00249ld45q.html?ptag=test',
        ),
      );

      expect(identity, isNotNull);
      expect(identity!.provider, WebPlaybackProvider.tencentVideo);
      expect(identity.kind, WebPlaybackMediaKind.tencentVideo);
      expect(identity.collectionId, 'nhtfh14i9y1egge');
      expect(identity.mediaId, 'd00249ld45q');
      expect(
        identity.canonicalUri.toString(),
        'https://v.qq.com/x/cover/nhtfh14i9y1egge/d00249ld45q.html',
      );
    });

    test('parses Tencent standalone page identities', () {
      final identity = WebPlaybackMediaIdentity.tryParse(
        Uri.parse('https://v.qq.com/x/page/d00249ld45q.html'),
      );

      expect(identity?.kind, WebPlaybackMediaKind.tencentVideo);
      expect(identity?.mediaId, 'd00249ld45q');
      expect(identity?.collectionId, isNull);
    });

    test('normalizes Tencent mobile app share playback URLs', () {
      final identity = WebPlaybackMediaIdentity.tryParse(
        Uri.parse(
          'https://m.v.qq.com/x/m/play?lid=402&cid=mzc00200cf43gaf&vid=7uHwAjgHuPJ&url_from=share&share_from=copy',
        ),
      );

      expect(identity?.kind, WebPlaybackMediaKind.tencentVideo);
      expect(identity?.collectionId, 'mzc00200cf43gaf');
      expect(identity?.mediaId, '7uHwAjgHuPJ');
      expect(
        identity?.canonicalUri.toString(),
        'https://v.qq.com/x/cover/mzc00200cf43gaf/7uHwAjgHuPJ.html',
      );
    });

    test('normalizes legacy Tencent mobile play.html URLs', () {
      final identity = WebPlaybackMediaIdentity.tryParse(
        Uri.parse(
          'https://m.v.qq.com/play.html?cid=&vid=t060641781b&url_from=share',
        ),
      );

      expect(identity?.mediaId, 't060641781b');
      expect(
        identity?.canonicalUri.toString(),
        'https://v.qq.com/x/page/t060641781b.html',
      );
    });

    test('uses vid query parameter on Tencent cover links when present', () {
      final identity = WebPlaybackMediaIdentity.tryParse(
        Uri.parse(
          'https://m.v.qq.com/x/cover/nhtfh14i9y1egge.html?vid=d00249ld45q',
        ),
      );

      expect(identity?.collectionId, 'nhtfh14i9y1egge');
      expect(identity?.mediaId, 'd00249ld45q');
      expect(
        identity?.canonicalUri.toString(),
        'https://v.qq.com/x/cover/nhtfh14i9y1egge/d00249ld45q.html',
      );
    });

    test('normalizes equivalent page variants to the same stable key', () {
      final first = WebPlaybackMediaIdentity.tryParse(
        Uri.parse('https://v.qq.com/x/page/d00249ld45q.html?a=1'),
      );
      final second = WebPlaybackMediaIdentity.tryParse(
        Uri.parse('https://v.qq.com/x/page/d00249ld45q.html#player'),
      );

      expect(first?.stableKey, second?.stableKey);
      expect(first?.canonicalUri, second?.canonicalUri);
    });

    test('matches the same episode across Tencent route variants', () {
      final cover = WebPlaybackMediaIdentity.tryParse(
        Uri.parse('https://v.qq.com/x/cover/nhtfh14i9y1egge/d00249ld45q.html'),
      );
      final page = WebPlaybackMediaIdentity.tryParse(
        Uri.parse('https://v.qq.com/x/page/d00249ld45q.html'),
      );

      expect(cover, isNotNull);
      expect(page, isNotNull);
      expect(cover!.isSameEpisodeAs(page!), isTrue);
      expect(page.isSameEpisodeAs(cover), isTrue);
    });

    test('does not match different, collection-only, or cross-site media', () {
      final first = WebPlaybackMediaIdentity.tryParse(
        Uri.parse('https://v.qq.com/x/page/d00249ld45q.html'),
      )!;
      final different = WebPlaybackMediaIdentity.tryParse(
        Uri.parse('https://v.qq.com/x/page/z0044abcd12.html'),
      )!;
      final collection = WebPlaybackMediaIdentity.tryParse(
        Uri.parse('https://v.qq.com/x/cover/nhtfh14i9y1egge.html'),
      )!;
      final iqiyi = WebPlaybackMediaIdentity.tryParse(
        Uri.parse('https://www.iqiyi.com/v_d00249ld45q.html'),
      )!;

      expect(first.isSameEpisodeAs(different), isFalse);
      expect(first.isSameEpisodeAs(collection), isFalse);
      expect(first.isSameEpisodeAs(iqiyi), isFalse);
    });

    test('keeps share short links unresolved until redirect resolution', () {
      expect(
        WebPlaybackMediaIdentity.tryParse(
          Uri.parse('https://qy.net/4aJQrYo-ef'),
        ),
        isNull,
      );
      expect(
        WebPlaybackMediaIdentity.tryParse(Uri.parse('https://url.cn/example')),
        isNull,
      );
    });

    test('rejects insecure, off-site, and unsupported paths', () {
      expect(
        WebPlaybackMediaIdentity.tryParse(
          Uri.parse('http://www.iqiyi.com/v_19rrn9o9n8.html'),
        ),
        isNull,
      );
      expect(
        WebPlaybackMediaIdentity.tryParse(
          Uri.parse('https://evil.example/v_19rrn9o9n8.html'),
        ),
        isNull,
      );
      expect(
        WebPlaybackMediaIdentity.tryParse(
          Uri.parse('https://v.qq.com/channel/tv'),
        ),
        isNull,
      );
    });
  });
}
