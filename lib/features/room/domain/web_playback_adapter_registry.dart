import 'package:synctv_app/features/room/domain/adapters/iqiyi_web_playback_adapter.dart';
import 'package:synctv_app/features/room/domain/adapters/tencent_video_web_playback_adapter.dart';
import 'package:synctv_app/features/room/domain/web_playback_adapter.dart';

final class WebPlaybackAdapterRegistry {
  const WebPlaybackAdapterRegistry(this.adapters);

  static const standard = WebPlaybackAdapterRegistry([
    IqiyiWebPlaybackAdapter(),
    TencentVideoWebPlaybackAdapter(),
  ]);

  final List<WebPlaybackAdapter> adapters;

  WebPlaybackAdapter? forSiteUri(Uri uri) {
    for (final adapter in adapters) {
      if (adapter.sitePolicy.allows(uri)) return adapter;
    }
    return null;
  }

  WebPlaybackAdapter? forMediaUri(Uri uri) {
    for (final adapter in adapters) {
      if (adapter.identify(uri) != null) return adapter;
    }
    return null;
  }
}
