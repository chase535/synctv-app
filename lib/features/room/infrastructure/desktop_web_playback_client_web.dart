import 'package:synctv_app/features/room/application/web_playback_client.dart';

final class NativeDesktopWebPlaybackClient implements WebPlaybackClient {
  const NativeDesktopWebPlaybackClient();

  @override
  bool get supported => false;

  @override
  Future<WebPlaybackSession> open({
    required Uri uri,
    required String title,
  }) => throw UnsupportedError(
    'Official-site web playback is not available on this platform',
  );
}
