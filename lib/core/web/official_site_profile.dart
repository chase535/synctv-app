import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:synctv_app/contracts/web_playback_site.dart';

Future<String> officialSiteProfileDirectory(
  WebPlaybackProvider provider,
) async {
  final appDirectory = await getApplicationSupportDirectory();
  return <String>[
    appDirectory.path,
    'web_playback',
    provider.name,
  ].join(Platform.pathSeparator);
}
