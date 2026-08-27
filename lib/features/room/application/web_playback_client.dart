import 'package:synctv_app/features/room/domain/web_playback_command.dart';
import 'package:synctv_app/features/room/domain/web_playback_runtime.dart';
import 'package:synctv_app/features/room/domain/web_playback_sync_gate.dart';

abstract interface class WebPlaybackSession {
  Stream<WebPlaybackRuntimeUpdate> get updates;

  Future<void> get closed;

  Uri? get currentUri;

  WebPlaybackSnapshot get snapshot;

  WebPlaybackSyncTarget? submitSyncTarget(WebPlaybackSyncTarget target);

  Future<bool> execute(WebPlaybackCommand command);

  Future<WebPlaybackSnapshot?> readSnapshot();

  Future<void> navigate(Uri uri);

  Future<void> bringToForeground();

  Future<void> close();
}

abstract interface class WebPlaybackClient {
  bool get supported;

  Future<WebPlaybackSession> open({required Uri uri, required String title});
}
