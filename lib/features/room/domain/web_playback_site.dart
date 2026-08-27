enum WebPlaybackProvider { iqiyi, tencentVideo }

final class WebPlaybackSitePolicy {
  const WebPlaybackSitePolicy._({
    required this.provider,
    required this.allowedHosts,
  });

  static const iqiyi = WebPlaybackSitePolicy._(
    provider: WebPlaybackProvider.iqiyi,
    allowedHosts: {'www.iqiyi.com'},
  );

  static const tencentVideo = WebPlaybackSitePolicy._(
    provider: WebPlaybackProvider.tencentVideo,
    allowedHosts: {'v.qq.com'},
  );

  static const values = <WebPlaybackSitePolicy>[iqiyi, tencentVideo];

  final WebPlaybackProvider provider;
  final Set<String> allowedHosts;

  bool allows(Uri uri) {
    if (uri.scheme.toLowerCase() != 'https') return false;
    if (!uri.hasAuthority || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    if (uri.hasPort && uri.port != 443) return false;
    return allowedHosts.contains(uri.host.toLowerCase());
  }

  static WebPlaybackSitePolicy? forUri(Uri uri) {
    for (final policy in values) {
      if (policy.allows(uri)) return policy;
    }
    return null;
  }
}
