import 'package:flutter_test/flutter_test.dart';
import 'package:synctv_app/features/providers/domain/provider_web_session_spec.dart';
import 'package:synctv_app/src/generated/proto/source_config.pbenum.dart'
    as source_enum;

void main() {
  group('providerWebSessionSpec', () {
    test('uses official iQiyi scope and desktop site on mobile', () {
      final spec = providerWebSessionSpec(
        source_enum.SourceProvider.SOURCE_PROVIDER_IQIYI,
      );

      expect(spec.startUri, Uri.parse('https://www.iqiyi.com/'));
      expect(spec.allowedDomain, 'iqiyi.com');
      expect(spec.requestDesktopSiteOnMobile, isTrue);
      expect(
        providerWebSessionUrlAllowed(
          Uri.parse('https://www.iqiyi.com/v_123.html'),
          spec,
        ),
        isTrue,
      );
      expect(
        providerWebSessionDomainAllowed(
          '.passport.iqiyi.com',
          spec.allowedDomain,
        ),
        isTrue,
      );
    });

    test('uses official Tencent Video scope without forcing desktop site', () {
      final spec = providerWebSessionSpec(
        source_enum.SourceProvider.SOURCE_PROVIDER_TENCENT_VIDEO,
      );

      expect(spec.startUri, Uri.parse('https://v.qq.com/'));
      expect(spec.allowedDomain, 'qq.com');
      expect(spec.requestDesktopSiteOnMobile, isFalse);
      expect(
        providerWebSessionUrlAllowed(
          Uri.parse('https://v.qq.com/x/cover/example.html'),
          spec,
        ),
        isTrue,
      );
      expect(
        providerWebSessionDomainAllowed('.video.qq.com', spec.allowedDomain),
        isTrue,
      );
    });

    test('rejects lookalike, non-HTTPS, and unrelated domains', () {
      final iqiyi = providerWebSessionSpec(
        source_enum.SourceProvider.SOURCE_PROVIDER_IQIYI,
      );
      final tencent = providerWebSessionSpec(
        source_enum.SourceProvider.SOURCE_PROVIDER_TENCENT_VIDEO,
      );

      expect(
        providerWebSessionUrlAllowed(Uri.parse('http://www.iqiyi.com/'), iqiyi),
        isFalse,
      );
      expect(
        providerWebSessionUrlAllowed(
          Uri.parse('https://iqiyi.com.evil.example/video'),
          iqiyi,
        ),
        isFalse,
      );
      expect(
        providerWebSessionUrlAllowed(
          Uri.parse('https://qq.com.evil.example/video'),
          tencent,
        ),
        isFalse,
      );
      expect(
        providerWebSessionDomainAllowed('notqq.com', tencent.allowedDomain),
        isFalse,
      );
    });
  });
}
