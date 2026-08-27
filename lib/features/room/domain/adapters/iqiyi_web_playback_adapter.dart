import 'package:synctv_app/features/room/domain/web_playback_adapter.dart';
import 'package:synctv_app/features/room/domain/web_playback_phase_detector.dart';
import 'package:synctv_app/features/room/domain/web_playback_site.dart';

final class IqiyiWebPlaybackAdapter extends BaseWebPlaybackAdapter {
  const IqiyiWebPlaybackAdapter();

  @override
  WebPlaybackProvider get provider => WebPlaybackProvider.iqiyi;

  @override
  WebPlaybackSitePolicy get sitePolicy => WebPlaybackSitePolicy.iqiyi;

  @override
  String get phaseDetectorFunctionExpression => webPlaybackOverlayPhaseDetector;
}
