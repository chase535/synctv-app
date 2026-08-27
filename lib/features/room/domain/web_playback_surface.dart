import 'dart:async';

import 'package:synctv_app/features/room/domain/web_playback_adapter.dart';
import 'package:synctv_app/features/room/domain/web_playback_command.dart';

abstract interface class WebPlaybackSurface {
  WebPlaybackAdapter get adapter;

  Uri? get currentUri;

  Stream<String> get bridgeMessages;

  Stream<Uri> get mainFrameNavigations;

  Future<void> navigate(Uri uri);

  Future<void> execute(WebPlaybackCommand command);

  Future<void> reload();

  Future<void> bringToForeground();

  Future<void> close();
}
