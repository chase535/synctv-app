import 'package:synctv_app/features/room/domain/web_playback_adapter.dart';
import 'package:synctv_app/features/room/domain/web_playback_phase_detector.dart';
import 'package:synctv_app/features/room/domain/web_playback_site.dart';

final class TencentVideoWebPlaybackAdapter extends BaseWebPlaybackAdapter {
  const TencentVideoWebPlaybackAdapter();

  @override
  WebPlaybackProvider get provider => WebPlaybackProvider.tencentVideo;

  @override
  WebPlaybackSitePolicy get sitePolicy => WebPlaybackSitePolicy.tencentVideo;

  @override
  String get phaseDetectorFunctionExpression => webPlaybackOverlayPhaseDetector;
}
