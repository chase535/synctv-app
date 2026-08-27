enum WebPlaybackProvider { iqiyi, tencentVideo }

final class WebPlaybackSitePolicy {
  const WebPlaybackSitePolicy._({
    required this.provider,
    required this.allowedHosts,
    this.authenticationHosts = const {},
  });

  static const iqiyi = WebPlaybackSitePolicy._(
    provider: WebPlaybackProvider.iqiyi,
    allowedHosts: {'www.iqiyi.com'},
    authenticationHosts: {'passport.iqiyi.com'},
  );

  static const tencentVideo = WebPlaybackSitePolicy._(
    provider: WebPlaybackProvider.tencentVideo,
    allowedHosts: {'v.qq.com'},
    authenticationHosts: {
      'xui.ptlogin2.qq.com',
      'ui.ptlogin2.qq.com',
      'ptlogin2.qq.com',
      'ssl.ptlogin2.qq.com',
      'graph.qq.com',
      'open.weixin.qq.com',
      'login.weixin.qq.com',
    },
  );

  static const values = <WebPlaybackSitePolicy>[iqiyi, tencentVideo];

  final WebPlaybackProvider provider;
  final Set<String> allowedHosts;
  final Set<String> authenticationHosts;

  bool allows(Uri uri) => _allowsHost(uri, allowedHosts);

  bool allowsAuthentication(Uri uri) => _allowsHost(uri, authenticationHosts);

  bool allowsMainFrameNavigation(Uri uri) =>
      allows(uri) || allowsAuthentication(uri);

  static bool _allowsHost(Uri uri, Set<String> hosts) {
    if (uri.scheme.toLowerCase() != 'https') return false;
    if (!uri.hasAuthority || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    if (uri.hasPort && uri.port != 443) return false;
    return hosts.contains(uri.host.toLowerCase());
  }

  static WebPlaybackSitePolicy? forUri(Uri uri) {
    for (final policy in values) {
      if (policy.allows(uri)) return policy;
    }
    return null;
  }
}
