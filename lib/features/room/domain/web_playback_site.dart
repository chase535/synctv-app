enum WebPlaybackProvider { iqiyi, tencentVideo }

final class WebPlaybackSitePolicy {
  const WebPlaybackSitePolicy._({
    required this.provider,
    required this.allowedHosts,
    required this.inputHosts,
    this.inputHostSuffixes = const {},
    this.authenticationHosts = const {},
  });

  static const iqiyi = WebPlaybackSitePolicy._(
    provider: WebPlaybackProvider.iqiyi,
    allowedHosts: {
      'www.iqiyi.com',
      'm.iqiyi.com',
      'iqiyi.com',
      'www.qiyi.com',
      'qiyi.com',
    },
    inputHosts: {
      'www.qy.com',
      'qy.com',
      'qy.net',
      'www.qy.net',
      's.iq.com',
      'iq.com',
      'www.iq.com',
    },
    inputHostSuffixes: {'iqiyi.com', 'qiyi.com', 'qy.net', 'qy.com', 'iq.com'},
    authenticationHosts: {'passport.iqiyi.com'},
  );

  static const tencentVideo = WebPlaybackSitePolicy._(
    provider: WebPlaybackProvider.tencentVideo,
    allowedHosts: {'v.qq.com', 'm.v.qq.com'},
    inputHosts: {
      'url.cn',
      'www.url.cn',
      'm.q.qq.com',
      'c.pc.qq.com',
      'c.url.cn',
      'film.qq.com',
    },
    // Tencent's published Tencent Video service scope includes the v.qq.com,
    // video.qq.com, and iwan.qq.com domain families. These are accepted only
    // as link-resolution inputs; playback WebView navigation remains limited
    // to [allowedHosts].
    inputHostSuffixes: {'v.qq.com', 'video.qq.com', 'iwan.qq.com'},
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

  /// Explicit hosts that may be pasted and resolved before playback.
  final Set<String> inputHosts;

  /// Provider-owned domain families accepted only during link resolution.
  final Set<String> inputHostSuffixes;
  final Set<String> authenticationHosts;

  bool allows(Uri uri) => _allowsHost(uri, allowedHosts);

  bool allowsInput(Uri uri) =>
      _isSecureStandardUri(uri) && recognizesInputHost(uri.host);

  bool recognizesInputHost(String host) {
    final normalized = host.toLowerCase();
    if (allowedHosts.contains(normalized) || inputHosts.contains(normalized)) {
      return true;
    }
    for (final suffix in inputHostSuffixes) {
      if (normalized == suffix || normalized.endsWith('.$suffix')) return true;
    }
    return false;
  }

  bool allowsAuthentication(Uri uri) => _allowsHost(uri, authenticationHosts);

  bool allowsMainFrameNavigation(Uri uri) =>
      allows(uri) || allowsAuthentication(uri);

  static bool _allowsHost(Uri uri, Set<String> hosts) =>
      _isSecureStandardUri(uri) && hosts.contains(uri.host.toLowerCase());

  static bool _isSecureStandardUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'https') return false;
    if (!uri.hasAuthority || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    if (uri.hasPort && uri.port != 443) return false;
    return true;
  }

  static WebPlaybackSitePolicy forProvider(WebPlaybackProvider provider) =>
      switch (provider) {
        WebPlaybackProvider.iqiyi => iqiyi,
        WebPlaybackProvider.tencentVideo => tencentVideo,
      };

  static WebPlaybackSitePolicy? forUri(Uri uri) {
    for (final policy in values) {
      if (policy.allows(uri)) return policy;
    }
    return null;
  }

  static WebPlaybackSitePolicy? forInputUri(Uri uri) {
    for (final policy in values) {
      if (policy.allowsInput(uri)) return policy;
    }
    return null;
  }
}
