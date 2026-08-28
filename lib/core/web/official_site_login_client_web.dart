import 'package:synctv_app/contracts/web_playback_site.dart';

final class OfficialSiteLoginClient {
  const OfficialSiteLoginClient();

  bool get supported => false;

  Future<void> open(WebPlaybackProvider provider) => throw UnsupportedError(
    'Official-site account login is not available on this platform',
  );
}
