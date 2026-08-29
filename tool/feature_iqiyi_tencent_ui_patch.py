from pathlib import Path


def replace_once_in(path: Path, old: str, new: str, name: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"expected exactly one {name} anchor in {path}, found {count}")
    path.write_text(text.replace(old, new, 1))


path = Path("lib/features/media_library/presentation/add_media_dialog.dart")
text = path.read_text()


def replace_once(old: str, new: str, name: str) -> None:
    global text
    if text.count(old) != 1:
        raise SystemExit(f"expected exactly one {name} anchor, found {text.count(old)}")
    text = text.replace(old, new, 1)


replace_once(
    "import 'package:synctv_app/features/media_library/presentation/add_media/tiktok_add_media_form.dart';\n",
    "import 'package:synctv_app/features/media_library/presentation/add_media/tiktok_add_media_form.dart';\n"
    "import 'package:synctv_app/features/media_library/presentation/add_media/provider_web_session_add_media_form.dart';\n",
    "web-session form import",
)

replace_once(
    """  List<TikTokBindInfo> _tiktokBinds = [];
  bool _tiktokHasDraft = false;
  List<String> _huyaInstances = const [''];
""",
    """  List<TikTokBindInfo> _tiktokBinds = [];
  bool _tiktokHasDraft = false;
  bool _iqiyiHasDraft = false;
  bool _tencentVideoHasDraft = false;
  List<String> _huyaInstances = const [''];
""",
    "draft state",
)

replace_once(
    """      case 20:
        return 'TikTok';
      default:
""",
    """      case 20:
        return 'TikTok';
      case 21:
        return 'iQiyi';
      case 22:
        return 'Tencent Video';
      default:
""",
    "title switch",
)

replace_once(
    """            const _MediaSourceSpec(
              index: 20,
              title: 'TikTok',
              subtitle: 'Video / Live / User Posts',
              icon: Icons.music_video_rounded,
              color: Color(0xFFFE2C55),
            ),
          ]
""",
    """            const _MediaSourceSpec(
              index: 20,
              title: 'TikTok',
              subtitle: 'Video / Live / User Posts',
              icon: Icons.music_video_rounded,
              color: Color(0xFFFE2C55),
            ),
            const _MediaSourceSpec(
              index: 21,
              title: 'iQiyi',
              subtitle: 'Official iqiyi.com video',
              icon: Icons.ondemand_video_rounded,
              color: Color(0xFF00BE06),
            ),
            const _MediaSourceSpec(
              index: 22,
              title: 'Tencent Video',
              subtitle: 'Official v.qq.com video',
              icon: Icons.play_circle_outline_rounded,
              color: Color(0xFF00A4FF),
            ),
          ]
""",
    "source specs",
)

replace_once(
    """  String? _providerTypeForSourceIndex(int index) {
    return switch (index) {
      0 => 'directUrl',
      1 => 'rtmp',
      2 => 'liveProxy',
      3 => 'bilibili',
      4 => 'alist',
      5 => 'emby',
      6 => 'cloudreve',
      7 => 'twitch',
      8 => 'huya',
      9 => 'douyu',
      10 => 'acfun',
      11 => 'cctv',
      12 => 'fnos',
      13 => 'qnap',
      14 => 'synology',
      15 => 'nextcloud',
      16 => 'seafile',
      17 => 'truenas',
      18 => 'youtube',
      19 => 'douyin',
      20 => 'tiktok',
      _ => null,
    };
  }
""",
    """  String? _providerTypeForSourceIndex(int index) {
    return switch (index) {
      0 => 'directUrl',
      1 => 'rtmp',
      2 => 'liveProxy',
      3 => 'bilibili',
      4 => 'alist',
      5 => 'emby',
      6 => 'cloudreve',
      7 => 'twitch',
      8 => 'huya',
      9 => 'douyu',
      10 => 'acfun',
      11 => 'cctv',
      12 => 'fnos',
      13 => 'qnap',
      14 => 'synology',
      15 => 'nextcloud',
      16 => 'seafile',
      17 => 'truenas',
      18 => 'youtube',
      19 => 'douyin',
      20 => 'tiktok',
      21 => 'iqiyi',
      22 => 'tencentVideo',
      _ => null,
    };
  }
""",
    "provider type switch",
)

replace_once(
    """      case 20:
        return TikTokAddMediaForm(
          roomId: widget.roomId,
          playlistId: widget.parentId ?? '',
          binds: _tiktokBinds,
          onDraftChanged: (value) => _tiktokHasDraft = value,
        );
      default:
""",
    """      case 20:
        return TikTokAddMediaForm(
          roomId: widget.roomId,
          playlistId: widget.parentId ?? '',
          binds: _tiktokBinds,
          onDraftChanged: (value) => _tiktokHasDraft = value,
        );
      case 21:
        return ProviderWebSessionAddMediaForm(
          roomId: widget.roomId,
          playlistId: widget.parentId ?? '',
          provider: source_enum.SourceProvider.SOURCE_PROVIDER_IQIYI,
          onDraftChanged: (value) => _iqiyiHasDraft = value,
        );
      case 22:
        return ProviderWebSessionAddMediaForm(
          roomId: widget.roomId,
          playlistId: widget.parentId ?? '',
          provider: source_enum.SourceProvider.SOURCE_PROVIDER_TENCENT_VIDEO,
          onDraftChanged: (value) => _tencentVideoHasDraft = value,
        );
      default:
""",
    "content switch",
)

replace_once(
    """        _youtubeHasDraft ||
        _douyinHasDraft ||
        _tiktokHasDraft) {
""",
    """        _youtubeHasDraft ||
        _douyinHasDraft ||
        _tiktokHasDraft ||
        _iqiyiHasDraft ||
        _tencentVideoHasDraft) {
""",
    "unsaved draft",
)

path.write_text(text)

form_path = Path(
    "lib/features/media_library/presentation/add_media/provider_web_session_add_media_form.dart"
)
replace_once_in(
    form_path,
    "providerWebSessionUriAllowed(uri, _spec)",
    "providerWebSessionUrlAllowed(uri, _spec)",
    "WebSession URL validation call",
)

test_path = Path("test/features/providers/provider_web_session_spec_test.dart")
test_text = test_path.read_text()
count = test_text.count("providerWebSessionUriAllowed")
if count != 5:
    raise SystemExit(f"expected 5 WebSession URI test calls, found {count}")
test_path.write_text(
    test_text.replace("providerWebSessionUriAllowed", "providerWebSessionUrlAllowed")
)

capture_path = Path(
    "lib/features/providers/infrastructure/provider_web_session_capture_io.dart"
)
replace_once_in(
    capture_path,
    "final cookies = await webview!.getAllCookies();",
    "final cookies = await webview.getAllCookies();",
    "desktop WebView cookie snapshot",
)
