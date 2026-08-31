import 'package:flutter_test/flutter_test.dart';
import 'package:synctv_app/features/providers/domain/provider_web_session_spec.dart';
import 'package:synctv_app/src/generated/proto/source_config.pbenum.dart'
    as source_enum;

void main() {
  group('providerWebSessionSpec', () {
    test('uses official iQiyi desktop and mobile login endpoints', () {
      final spec = providerWebSessionSpec(
        source_enum.SourceProvider.SOURCE_PROVIDER_IQIYI,
      );

      expect(spec.startUri, Uri.parse('https://www.iqiyi.com/'));
      expect(spec.mobileStartUri, Uri.parse('https://m.iqiyi.com/'));
      expect(spec.effectiveMobileStartUri, Uri.parse('https://m.iqiyi.com/'));
      expect(spec.allowedDomain, 'iqiyi.com');
      expect(spec.allowedDomains, <String>['iqiyi.com', 'qiyi.com']);
      expect(spec.effectiveCookieLookupUris, <Uri>[
        Uri.parse('https://m.iqiyi.com/'),
        Uri.parse('https://www.iqiyi.com/'),
        Uri.parse('https://www.qiyi.com/'),
      ]);
      expect(
        providerWebSessionUrlAllowed(
          Uri.parse('https://m.iqiyi.com/v_123.html'),
          spec,
        ),
        isTrue,
      );
      expect(
        providerWebSessionUrlAllowed(
          Uri.parse('https://www.iqiyi.com/v_123.html'),
          spec,
        ),
        isTrue,
      );
      expect(
        providerWebSessionUrlAllowed(
          Uri.parse('https://www.qiyi.com/v_123.html'),
          spec,
        ),
        isTrue,
      );
      expect(
        providerWebSessionDomainAllowedForSpec('.passport.iqiyi.com', spec),
        isTrue,
      );
      expect(
        providerWebSessionDomainAllowedForSpec('.passport.qiyi.com', spec),
        isTrue,
      );
    });

    test('normalizes URL-shaped Android cookie domains', () {
      expect(
        normalizeProviderCookieDomain('https://www.iqiyi.com/'),
        'www.iqiyi.com',
      );
      expect(
        normalizeProviderCookieDomain('HTTPS://V.QQ.COM/path'),
        'v.qq.com',
      );
      expect(
        normalizeProviderCookieDomain('.passport.iqiyi.com'),
        'passport.iqiyi.com',
      );
    });

    test('Tencent Video reuses its normal endpoint on mobile', () {
      final spec = providerWebSessionSpec(
        source_enum.SourceProvider.SOURCE_PROVIDER_TENCENT_VIDEO,
      );

      expect(spec.startUri, Uri.parse('https://v.qq.com/'));
      expect(spec.mobileStartUri, isNull);
      expect(spec.effectiveMobileStartUri, Uri.parse('https://v.qq.com/'));
      expect(spec.allowedDomain, 'qq.com');
      expect(spec.allowedDomains, <String>['qq.com']);
      expect(spec.effectiveCookieLookupUris, <Uri>[
        Uri.parse('https://v.qq.com/'),
      ]);
      expect(
        providerWebSessionUrlAllowed(
          Uri.parse('https://v.qq.com/x/cover/example.html'),
          spec,
        ),
        isTrue,
      );
      expect(
        providerWebSessionDomainAllowedForSpec('.video.qq.com', spec),
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
          Uri.parse('https://qiyi.com.evil.example/video'),
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
        providerWebSessionDomainAllowedForSpec('notqq.com', tencent),
        isFalse,
      );
    });
  });
}
