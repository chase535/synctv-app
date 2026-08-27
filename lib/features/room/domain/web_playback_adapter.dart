import 'package:synctv_app/features/room/domain/web_playback_media_identity.dart';
import 'package:synctv_app/features/room/domain/web_playback_navigation.dart';
import 'package:synctv_app/features/room/domain/web_playback_site.dart';

abstract interface class WebPlaybackAdapter {
  WebPlaybackProvider get provider;

  WebPlaybackSitePolicy get sitePolicy;

  String get phaseDetectorFunctionExpression;

  WebPlaybackMediaIdentity? identify(Uri uri);

  WebPlaybackNavigationDisposition classifyNavigation(
    Uri uri, {
    required bool isMainFrame,
  });
}

abstract base class BaseWebPlaybackAdapter implements WebPlaybackAdapter {
  const BaseWebPlaybackAdapter();

  @override
  WebPlaybackMediaIdentity? identify(Uri uri) {
    final identity = WebPlaybackMediaIdentity.tryParse(uri);
    if (identity?.provider != provider) return null;
    return identity;
  }

  @override
  WebPlaybackNavigationDisposition classifyNavigation(
    Uri uri, {
    required bool isMainFrame,
  }) => classifyWebPlaybackNavigation(
    uri: uri,
    isMainFrame: isMainFrame,
    isPrivilegedUri: sitePolicy.allows,
    isAuthenticationUri: sitePolicy.allowsAuthentication,
  );
}
