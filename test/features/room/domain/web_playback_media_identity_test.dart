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
