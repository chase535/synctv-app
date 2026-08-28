import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:synctv_app/contracts/web_playback_site.dart';
import 'package:synctv_app/core/web/official_site_login_target.dart';
import 'package:synctv_app/core/web/official_site_profile.dart';

final class OfficialSiteLoginClient {
  const OfficialSiteLoginClient();

  bool get supported => Platform.isWindows;

  Future<void> open(WebPlaybackProvider provider) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'Official-site account login currently requires Windows WebView2',
      );
    }
    if (!await WebviewWindow.isWebviewAvailable()) {
      throw UnsupportedError(
        'WebView2 Runtime is required for official-site account login',
      );
    }

    final profileDirectory = await officialSiteProfileDirectory(provider);
    final webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        title: '登录 ${officialSiteLoginProviderName(provider)}',
        windowWidth: 1100,
        windowHeight: 780,
        openMaximized: true,
        userDataFolderWindows: profileDirectory,
      ),
    );

    // Login pages must keep the browser's original navigation request intact.
    // In particular, SMS verification and OAuth flows may depend on POST
    // bodies, referrers, user activation, popup/window.opener, and redirects.
    await webview.setUrlRequestInterceptionEnabled(false);
    await webview.launch(
      officialSiteLoginEntryUri(provider).toString(),
      triggerOnUrlRequestEvent: false,
    );
    await webview.bringToForeground(maximized: true);
  }
}
