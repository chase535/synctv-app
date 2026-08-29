from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file_path = Path(path)
    text = file_path.read_text()
    if old not in text:
        raise SystemExit(f"{path}: expected {label} anchor not found")
    file_path.write_text(text.replace(old, new, 1))


codec = "lib/contracts/source_config_codec.dart"
replace_once(
    codec,
    """      'youtube' => source_enum.SourceProvider.SOURCE_PROVIDER_YOUTUBE,
      'tiktok' => source_enum.SourceProvider.SOURCE_PROVIDER_TIKTOK,
      _ => source_enum.SourceProvider.SOURCE_PROVIDER_UNSPECIFIED,
""",
    """      'youtube' => source_enum.SourceProvider.SOURCE_PROVIDER_YOUTUBE,
      'tiktok' => source_enum.SourceProvider.SOURCE_PROVIDER_TIKTOK,
      'iqiyi' => source_enum.SourceProvider.SOURCE_PROVIDER_IQIYI,
      'tencent_video' ||
      'tencentvideo' => source_enum.SourceProvider.SOURCE_PROVIDER_TENCENT_VIDEO,
      _ => source_enum.SourceProvider.SOURCE_PROVIDER_UNSPECIFIED,
""",
    "providerFromString",
)
replace_once(
    codec,
    """      source_enum.SourceProvider.SOURCE_PROVIDER_YOUTUBE => 'youtube',
      source_enum.SourceProvider.SOURCE_PROVIDER_TIKTOK => 'tiktok',
      _ => '',
""",
    """      source_enum.SourceProvider.SOURCE_PROVIDER_YOUTUBE => 'youtube',
      source_enum.SourceProvider.SOURCE_PROVIDER_TIKTOK => 'tiktok',
      source_enum.SourceProvider.SOURCE_PROVIDER_IQIYI => 'iqiyi',
      source_enum.SourceProvider.SOURCE_PROVIDER_TENCENT_VIDEO => 'tencentVideo',
      _ => '',
""",
    "providerToString",
)
replace_once(
    codec,
    """      source_config.MediaSourceConfig_Provider.tiktok =>
        source_enum.SourceProvider.SOURCE_PROVIDER_TIKTOK,
      source_config.MediaSourceConfig_Provider.notSet =>
""",
    """      source_config.MediaSourceConfig_Provider.tiktok =>
        source_enum.SourceProvider.SOURCE_PROVIDER_TIKTOK,
      source_config.MediaSourceConfig_Provider.iqiyi =>
        source_enum.SourceProvider.SOURCE_PROVIDER_IQIYI,
      source_config.MediaSourceConfig_Provider.tencentVideo =>
        source_enum.SourceProvider.SOURCE_PROVIDER_TENCENT_VIDEO,
      source_config.MediaSourceConfig_Provider.notSet =>
""",
    "providerForMediaSourceConfig",
)
replace_once(
    codec,
    """      source_enum.SourceProvider.SOURCE_PROVIDER_YOUTUBE =>
        source_config.MediaSourceConfig(
          youtube: source_config.YoutubeMediaSourceConfig(
            videoId: _string(config['videoId']),
            shared: config['shared'] == true,
          ),
        ),
      _ => null,
""",
    """      source_enum.SourceProvider.SOURCE_PROVIDER_YOUTUBE =>
        source_config.MediaSourceConfig(
          youtube: source_config.YoutubeMediaSourceConfig(
            videoId: _string(config['videoId']),
            shared: config['shared'] == true,
          ),
        ),
      source_enum.SourceProvider.SOURCE_PROVIDER_IQIYI =>
        source_config.MediaSourceConfig(
          iqiyi: source_config.IqiyiMediaSourceConfig(
            url: _string(config['url']),
            shared: config['shared'] == true,
            proxyMode: _playbackProxyModeFromValue(config['proxyMode']),
          ),
        ),
      source_enum.SourceProvider.SOURCE_PROVIDER_TENCENT_VIDEO =>
        source_config.MediaSourceConfig(
          tencentVideo: source_config.TencentVideoMediaSourceConfig(
            url: _string(config['url']),
            shared: config['shared'] == true,
            proxyMode: _playbackProxyModeFromValue(config['proxyMode']),
          ),
        ),
      _ => null,
""",
    "mediaSourceConfigForProvider",
)
replace_once(
    codec,
    """      source_config.MediaSourceConfig_Provider.youtube => {
        'videoId': config.youtube.videoId,
        if (config.youtube.shared) 'shared': true,
      },
      source_config.MediaSourceConfig_Provider.notSet => <String, dynamic>{},
""",
    """      source_config.MediaSourceConfig_Provider.youtube => {
        'videoId': config.youtube.videoId,
        if (config.youtube.shared) 'shared': true,
      },
      source_config.MediaSourceConfig_Provider.iqiyi => {
        'url': config.iqiyi.url,
        if (config.iqiyi.shared) 'shared': true,
        ..._playbackProxyModeMap(config.iqiyi.proxyMode),
      },
      source_config.MediaSourceConfig_Provider.tencentVideo => {
        'url': config.tencentVideo.url,
        if (config.tencentVideo.shared) 'shared': true,
        ..._playbackProxyModeMap(config.tencentVideo.proxyMode),
      },
      source_config.MediaSourceConfig_Provider.notSet => <String, dynamic>{},
""",
    "mediaSourceConfigToMap",
)

api_client = "lib/data/synctv_api/synctv_api_client.dart"
replace_once(
    api_client,
    """import 'package:synctv_app/src/generated/proto/providers/common.pb.dart'
    as provider_common;
""",
    """import 'package:synctv_app/src/generated/proto/providers/common.pb.dart'
    as provider_common;
import 'package:synctv_app/src/generated/proto/providers/common_service.pb.dart'
    as provider_common_service;
""",
    "provider common service import",
)

facades = "lib/data/synctv_api/synctv_api_facades.dart"
replace_once(
    facades,
    """  Future<provider_common.DisableProviderInstanceResponse>
  disableProviderInstance(
    provider_common.DisableProviderInstanceRequest request,
  ) {
    return _api._send(
      'POST',
      '/api/providers/instances/${request.name}/disable',
      provider_common.DisableProviderInstanceResponse.create,
    );
  }
}

class SyncTvAlistProviderApi {
""",
    """  Future<provider_common.DisableProviderInstanceResponse>
  disableProviderInstance(
    provider_common.DisableProviderInstanceRequest request,
  ) {
    return _api._send(
      'POST',
      '/api/providers/instances/${request.name}/disable',
      provider_common.DisableProviderInstanceResponse.create,
    );
  }

  Future<provider_common_service.BindWebSessionResponse> bindWebSession(
    provider_common_service.BindWebSessionRequest request,
  ) {
    return _api._send(
      'POST',
      '/api/providers/web-sessions',
      provider_common_service.BindWebSessionResponse.create,
      body: request,
    );
  }

  Future<provider_common_service.ListWebSessionsResponse> listWebSessions() {
    return _api._send(
      'GET',
      '/api/providers/web-sessions',
      provider_common_service.ListWebSessionsResponse.create,
    );
  }

  Future<provider_common_service.UnbindWebSessionResponse> unbindWebSession(
    provider_common_service.UnbindWebSessionRequest request,
  ) {
    return _api._send(
      'POST',
      '/api/providers/web-sessions/unbind',
      provider_common_service.UnbindWebSessionResponse.create,
      body: request,
    );
  }
}

class SyncTvAlistProviderApi {
""",
    "provider common web-session methods",
)

provider_service = "lib/data/synctv_api/synctv_provider_service.dart"
replace_once(
    provider_service,
    """import 'package:synctv_app/src/generated/proto/providers/common.pb.dart'
    as provider_common;
""",
    """import 'package:synctv_app/src/generated/proto/providers/common.pb.dart'
    as provider_common;
import 'package:synctv_app/src/generated/proto/providers/common_service.pb.dart'
    as provider_common_service;
""",
    "provider service common-service import",
)
replace_once(
    provider_service,
    """  Future<provider_common.PlaybackProxyPolicy> resolvePlaybackProxyPolicy(
    provider_common.DiscoveredSource source,
  ) => _api.providerCommon.resolvePlaybackProxyPolicy(source);

  Future<AlistLoginInfo> loginAList(
""",
    """  Future<provider_common.PlaybackProxyPolicy> resolvePlaybackProxyPolicy(
    provider_common.DiscoveredSource source,
  ) => _api.providerCommon.resolvePlaybackProxyPolicy(source);

  Future<provider_common_service.WebSessionBinding> bindWebSession({
    required source_enum.SourceProvider provider,
    required String label,
    required List<provider_common_service.WebSessionCookie> cookies,
  }) async {
    _requireWebSessionProvider(provider);
    final normalizedLabel = label.trim();
    if (normalizedLabel.isEmpty) {
      throw ArgumentError.value(label, 'label', '不能为空');
    }
    if (cookies.isEmpty) {
      throw ArgumentError.value(cookies, 'cookies', '不能为空');
    }
    final response = await _api.providerCommon.bindWebSession(
      provider_common_service.BindWebSessionRequest(
        provider: provider,
        label: normalizedLabel,
        cookies: cookies,
      ),
    );
    if (!response.hasBinding()) {
      throw StateError('WebSession bind response is missing binding metadata');
    }
    return response.binding;
  }

  Future<List<provider_common_service.WebSessionBinding>> listWebSessions() async {
    final response = await _api.providerCommon.listWebSessions();
    return response.bindings.toList(growable: false);
  }

  Future<bool> unbindWebSession(source_enum.SourceProvider provider) async {
    _requireWebSessionProvider(provider);
    final response = await _api.providerCommon.unbindWebSession(
      provider_common_service.UnbindWebSessionRequest(provider: provider),
    );
    return response.removed;
  }

  static void _requireWebSessionProvider(source_enum.SourceProvider provider) {
    if (provider != source_enum.SourceProvider.SOURCE_PROVIDER_IQIYI &&
        provider !=
            source_enum.SourceProvider.SOURCE_PROVIDER_TENCENT_VIDEO) {
      throw ArgumentError.value(
        provider,
        'provider',
        'WebSession only supports iQiyi and Tencent Video',
      );
    }
  }

  Future<AlistLoginInfo> loginAList(
""",
    "provider domain web-session methods",
)

Path("test/contracts/iqiyi_tencent_codec_test.dart").write_text(r'''import 'package:flutter_test/flutter_test.dart';
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
''')
