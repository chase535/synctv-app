from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file_path = Path(path)
    text = file_path.read_text()
    if old not in text:
        raise SystemExit(f'{path}: expected {label} anchor not found')
    file_path.write_text(text.replace(old, new, 1))


service = 'lib/data/synctv_api/synctv_service.dart'
replace_once(
    service,
    """import 'package:synctv_app/src/generated/proto/providers/common.pb.dart'
    as provider_common;
""",
    """import 'package:synctv_app/src/generated/proto/providers/common.pb.dart'
    as provider_common;
import 'package:synctv_app/src/generated/proto/providers/common_service.pb.dart'
    as provider_common_service;
""",
    'common service import',
)
replace_once(
    service,
    """  static Future<AlistLoginInfo> loginAList(
""",
    """  static Future<provider_common_service.WebSessionBinding> bindWebSession({
    required source_enum.SourceProvider provider,
    required String label,
    required List<provider_common_service.WebSessionCookie> cookies,
  }) => _domains.providers.bindWebSession(
    provider: provider,
    label: label,
    cookies: cookies,
  );

  static Future<List<provider_common_service.WebSessionBinding>>
  listWebSessions() => _domains.providers.listWebSessions();

  static Future<bool> unbindWebSession(source_enum.SourceProvider provider) =>
      _domains.providers.unbindWebSession(provider);

  static Future<AlistLoginInfo> loginAList(
""",
    'web session wrappers',
)

generator = 'tool/generate_feature_gateways.dart'
replace_once(
    generator,
    """  'bindTikTok',
  'bindTwitch',
  'bindYoutube',
""",
    """  'bindTikTok',
  'bindTwitch',
  'bindWebSession',
  'bindYoutube',
""",
    'bind whitelist',
)
replace_once(
    generator,
    """  'listTrueNasFiles',
  'listTwitchCategoryStreams',
""",
    """  'listTrueNasFiles',
  'listTwitchCategoryStreams',
""",
    'stable list anchor',
)
replace_once(
    generator,
    """  'listTikTokUserPosts',
  'listTrueNasFiles',
""",
    """  'listTikTokUserPosts',
  'listTrueNasFiles',
  'listWebSessions',
""",
    'list whitelist',
)
replace_once(
    generator,
    """  'unbindTikTok',
  'unbindTwitch',
  'unbindYoutube',
""",
    """  'unbindTikTok',
  'unbindTwitch',
  'unbindWebSession',
  'unbindYoutube',
""",
    'unbind whitelist',
)
