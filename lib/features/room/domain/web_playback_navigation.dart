enum WebPlaybackNavigationDisposition {
  allowPrivileged,
  allowUnprivileged,
  block,
}

extension WebPlaybackNavigationDispositionAccess
    on WebPlaybackNavigationDisposition {
  bool get isAllowed => this != WebPlaybackNavigationDisposition.block;

  bool get canUseBridge =>
      this == WebPlaybackNavigationDisposition.allowPrivileged;
}

WebPlaybackNavigationDisposition classifyWebPlaybackNavigation({
  required Uri uri,
  required bool isMainFrame,
  required bool Function(Uri uri) isPrivilegedUri,
  bool Function(Uri uri)? isAuthenticationUri,
}) {
  if (isPrivilegedUri(uri)) {
    return isMainFrame
        ? WebPlaybackNavigationDisposition.allowPrivileged
        : WebPlaybackNavigationDisposition.allowUnprivileged;
  }

  if (isMainFrame) {
    if (uri.scheme == 'about' && uri.path == 'blank') {
      return WebPlaybackNavigationDisposition.allowUnprivileged;
    }
    if (isAuthenticationUri?.call(uri) == true) {
      return WebPlaybackNavigationDisposition.allowUnprivileged;
    }
    return WebPlaybackNavigationDisposition.block;
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'https' ||
      scheme == 'about' ||
      scheme == 'blob' ||
      scheme == 'data') {
    return WebPlaybackNavigationDisposition.allowUnprivileged;
  }
  return WebPlaybackNavigationDisposition.block;
}
