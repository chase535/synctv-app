import 'dart:async';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:synctv_app/features/providers/domain/provider_web_session_spec.dart';
import 'package:synctv_app/src/generated/proto/providers/common_service.pb.dart'
    as provider_common_service;
import 'package:synctv_app/src/generated/proto/source_config.pbenum.dart'
    as source_enum;
import 'package:webview_flutter/webview_flutter.dart';

const _desktopChromeUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
const _desktopSafariUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Safari/605.1.15';

bool get providerWebSessionCaptureSupported =>
    Platform.isWindows ||
    Platform.isLinux ||
    Platform.isMacOS ||
    Platform.isAndroid ||
    Platform.isIOS;

String? _embeddedUserAgent(ProviderWebSessionSpec spec) {
  if (!spec.requestDesktopSiteOnMobile) {
    return null;
  }
  if (Platform.isAndroid) {
    return _desktopChromeUserAgent;
  }
  if (Platform.isIOS) {
    return _desktopSafariUserAgent;
  }
  return null;
}

Future<List<provider_common_service.WebSessionCookie>>
captureProviderWebSession(
  BuildContext context,
  source_enum.SourceProvider provider,
) async {
  final spec = providerWebSessionSpec(provider);
  if (Platform.isWindows || Platform.isLinux) {
    return _captureDesktop(spec);
  }
  if (Platform.isMacOS || Platform.isAndroid || Platform.isIOS) {
    return _captureEmbedded(context, spec);
  }
  throw UnsupportedError('Provider WebSession capture is unavailable here.');
}

Future<List<provider_common_service.WebSessionCookie>> _captureDesktop(
  ProviderWebSessionSpec spec,
) async {
  Directory? windowsProfile;
  if (Platform.isWindows) {
    if (!await WebviewWindow.isWebviewAvailable()) {
      throw StateError('Microsoft Edge WebView2 Runtime is required.');
    }
    windowsProfile = await Directory.systemTemp.createTemp(
      'synctv_provider_session_',
    );
  }

  final configuration = Platform.isWindows
      ? CreateConfiguration(
          windowWidth: 1180,
          windowHeight: 780,
          title: 'SyncTV · ${spec.label} session',
          userDataFolderWindows: windowsProfile!.path,
        )
      : CreateConfiguration(
          windowWidth: 1180,
          windowHeight: 780,
          title: 'SyncTV · ${spec.label} session',
        );
  Webview? webview;
  Timer? timer;
  var latest = <provider_common_service.WebSessionCookie>[];
  var reading = false;
  var lastObservedCookieCount = 0;
  var lastMatchedCookieCount = 0;

  Future<void> snapshot() async {
    if (reading || webview == null) return;
    reading = true;
    try {
      final cookies = await webview.getAllCookies();
      final matched = [
        for (final cookie in cookies)
          if (providerWebSessionDomainAllowedForSpec(cookie.domain, spec))
            provider_common_service.WebSessionCookie(
              name: cookie.name,
              value: cookie.value,
              domain: normalizeProviderCookieDomain(cookie.domain),
              path: cookie.path,
              secure: cookie.secure,
              httpOnly: cookie.httpOnly,
              sessionOnly: cookie.sessionOnly,
              expiresAt: cookie.expires == null
                  ? null
                  : Int64(cookie.expires!.millisecondsSinceEpoch ~/ 1000),
            ),
      ];
      lastObservedCookieCount = cookies.length;
      lastMatchedCookieCount = matched.length;

      // WebView2 can transiently return an empty cookie list while a page is
      // navigating or while the native window is beginning to close. Never let
      // that empty read erase a session snapshot captured after successful
      // sign-in. A later non-empty snapshot still replaces the previous one so
      // refreshed cookie values are retained.
      if (matched.isNotEmpty) {
        latest = matched;
      }

      assert(() {
        final domains =
            cookies
                .map((cookie) => normalizeProviderCookieDomain(cookie.domain))
                .where((domain) => domain.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        final names = matched.map((cookie) => cookie.name).toSet().toList()
          ..sort();
        debugPrint(
          '${spec.label} WebSession cookie snapshot: '
          'total=${cookies.length}, matched=${matched.length}, '
          'domains=$domains, matchedNames=$names',
        );
        return true;
      }());
    } on Object catch (error) {
      // The window can close while a cookie read is in flight. Keep the last
      // successful snapshot. Log only the error type in debug builds because
      // exception text from a platform channel must not be assumed cookie-free.
      assert(() {
        debugPrint(
          '${spec.label} WebSession cookie snapshot failed: '
          '${error.runtimeType}',
        );
        return true;
      }());
    } finally {
      reading = false;
    }
  }

  try {
    webview = await WebviewWindow.create(configuration: configuration);
    webview.launch(spec.startUri.toString());
    timer = Timer.periodic(
      const Duration(milliseconds: 750),
      (_) => unawaited(snapshot()),
    );
    await webview.onClose;
    timer.cancel();

    // Give an already-started cookie read a short opportunity to finish. A
    // final read cannot safely be started after onClose because the native
    // WebView may already have been destroyed.
    final readDeadline = DateTime.now().add(const Duration(seconds: 1));
    while (reading && DateTime.now().isBefore(readDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }

    if (latest.isEmpty) {
      throw StateError(
        'No ${spec.label} session cookies were captured '
        '(WebView cookies: $lastObservedCookieCount, '
        'matching ${spec.allowedDomains.join(', ')}: '
        '$lastMatchedCookieCount). '
        'Sign in on the official page, then close the login window.',
      );
    }
    return latest;
  } finally {
    timer?.cancel();
    if (Platform.isWindows && windowsProfile != null) {
      try {
        await WebviewWindow.clearAll(
          userDataFolderWindows: windowsProfile.path,
        );
      } on Object {
        // Best-effort cleanup; the temporary directory is removed below.
      }
      try {
        if (await windowsProfile.exists()) {
          await windowsProfile.delete(recursive: true);
        }
      } on Object {
        // The OS may keep WebView2 files open briefly after window shutdown.
      }
    }
    // Linux uses the plugin's shared WebView profile. Do not call clearAll()
    // here because it would remove unrelated WebView cookies owned by SyncTV.
  }
}

Future<List<provider_common_service.WebSessionCookie>> _captureEmbedded(
  BuildContext context,
  ProviderWebSessionSpec spec,
) async {
  final cookieManager = WebViewCookieManager();
  final controller = WebViewController();
  await controller.setJavaScriptMode(JavaScriptMode.unrestricted);

  // iQiyi serves a restricted mobile-web experience when Android/iOS WebView
  // identifies itself as a phone. Request the normal desktop website before
  // the very first navigation so the server never sees the mobile user agent.
  final userAgent = _embeddedUserAgent(spec);
  if (userAgent != null) {
    await controller.setUserAgent(userAgent);
  }
  await controller.loadRequest(spec.startUri);
  if (!context.mounted) {
    return const [];
  }

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text('${spec.label} official login'),
      content: SizedBox(
        width: 960,
        height: 680,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: WebViewWidget(controller: controller),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Use this session'),
        ),
      ],
    ),
  );

  if (accepted != true) return const [];

  // Android's webview_flutter CookieManager returns cookie.domain as the full
  // lookup URL rather than as a cookie Domain attribute. Query each explicitly
  // allowed provider URL and normalize the reported value back to a hostname
  // before it crosses the client/server boundary.
  final result = <provider_common_service.WebSessionCookie>[];
  final seen = <String>{};
  final observedCounts = <String, int>{};
  for (final lookupUri in spec.effectiveCookieLookupUris) {
    final cookies = await cookieManager.getCookies(domain: lookupUri);
    observedCounts[lookupUri.host] = cookies.length;
    for (final cookie in cookies) {
      final reportedDomain = normalizeProviderCookieDomain(cookie.domain);
      final domain = reportedDomain.isEmpty
          ? lookupUri.host.toLowerCase()
          : reportedDomain;
      if (!providerWebSessionDomainAllowedForSpec(domain, spec)) {
        continue;
      }
      final path = cookie.path.isEmpty ? '/' : cookie.path;
      final identity = '$domain\n$path\n${cookie.name}';
      if (!seen.add(identity)) {
        continue;
      }
      result.add(
        provider_common_service.WebSessionCookie(
          name: cookie.name,
          value: cookie.value,
          domain: domain,
          path: path,
          secure: lookupUri.scheme.toLowerCase() == 'https',
          httpOnly: false,
          sessionOnly: true,
        ),
      );
    }
  }

  if (result.isEmpty) {
    final observations = observedCounts.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    throw StateError(
      'No ${spec.label} session cookies were captured '
      '(CookieManager: ${observations.isEmpty ? 'no lookups' : observations}). '
      'Complete sign-in before choosing “Use this session”.',
    );
  }
  // webview_flutter exposes only a global clearCookies() operation. Keep the
  // platform WebView cookie jar intact rather than signing the user out of
  // unrelated embedded sites; only this filtered snapshot crosses the bind
  // boundary into SyncTV's provider credential service.
  return result;
}
