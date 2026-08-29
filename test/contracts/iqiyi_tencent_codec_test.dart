import 'package:flutter_test/flutter_test.dart';
import 'package:synctv_app/contracts/source_config_codec.dart';
import 'package:synctv_app/src/generated/proto/source_config.pbenum.dart'
    as source_enum;

void main() {
  group('iQiyi and Tencent Video source config', () {
    test('parses canonical and protobuf-style provider names', () {
      expect(
        SourceConfigCodec.providerFromString('iqiyi'),
        source_enum.SourceProvider.SOURCE_PROVIDER_IQIYI,
      );
      expect(
        SourceConfigCodec.providerFromString('tencentVideo'),
        source_enum.SourceProvider.SOURCE_PROVIDER_TENCENT_VIDEO,
      );
      expect(
        SourceConfigCodec.providerFromString('SOURCE_PROVIDER_TENCENT_VIDEO'),
        source_enum.SourceProvider.SOURCE_PROVIDER_TENCENT_VIDEO,
      );
      expect(
        SourceConfigCodec.providerToString(
          source_enum.SourceProvider.SOURCE_PROVIDER_IQIYI,
        ),
        'iqiyi',
      );
      expect(
        SourceConfigCodec.providerToString(
          source_enum.SourceProvider.SOURCE_PROVIDER_TENCENT_VIDEO,
        ),
        'tencentVideo',
      );
    });

    test('round trips iQiyi shared config and proxy mode', () {
      const source = {
        'url': 'https://www.iqiyi.com/v_example.html',
        'shared': true,
        'proxyMode': 'directPrefer',
      };
      final config = SourceConfigCodec.mediaSourceConfigFromMap(
        sourceProvider: source_enum.SourceProvider.SOURCE_PROVIDER_IQIYI,
        sourceConfig: source,
      )!;
      expect(
        SourceConfigCodec.providerForMediaSourceConfig(config),
        source_enum.SourceProvider.SOURCE_PROVIDER_IQIYI,
      );
      expect(SourceConfigCodec.mediaSourceConfigToMap(config), source);
    });

    test('round trips Tencent Video viewer config and proxy mode', () {
      const source = {
        'url': 'https://v.qq.com/x/cover/example.html',
        'proxyMode': 'only',
      };
      final config = SourceConfigCodec.mediaSourceConfigFromMap(
        sourceProvider:
            source_enum.SourceProvider.SOURCE_PROVIDER_TENCENT_VIDEO,
        sourceConfig: source,
      )!;
      expect(
        SourceConfigCodec.providerForMediaSourceConfig(config),
        source_enum.SourceProvider.SOURCE_PROVIDER_TENCENT_VIDEO,
      );
      expect(SourceConfigCodec.mediaSourceConfigToMap(config), source);
    });
  });
}
