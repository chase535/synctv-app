import 'dart:async';
import 'dart:convert';
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

bool get providerWebSessionCaptureSupported =>
    Platform.isWindows ||
    Platform.isLinux ||
    Platform.isMacOS ||
    Platform.isAndroid ||
    Platform.isIOS;

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

Future<List<provider_common_service.WebSessionCookie>>
_captureVisibleDesktopCookies(
  Webview webview,
  ProviderWebSessionSpec spec,
) async {
  final raw = await webview.evaluateJavaScript(
    'JSON.stringify({href: window.location.href, cookie: document.cookie})',
  );
  if (raw == null || raw.trim().isEmpty) {
    return const [];
  }

  dynamic decoded = jsonDecode(raw);
  if (decoded is String) {
    decoded = jsonDecode(decoded);
  }
  if (decoded is! Map) {
    return const [];
  }

  final href = decoded['href'];
  final cookieHeader = decoded['cookie'];
  if (href is! String ||
      cookieHeader is! String ||
      cookieHeader.trim().isEmpty) {
    return const [];
  }

  final uri = Uri.tryParse(href);
  if (uri == null || !providerWebSessionUrlAllowed(uri, spec)) {
    return const [];
  }

  final domain = uri.host.toLowerCase();
  final result = <provider_common_service.WebSessionCookie>[];
  final seen = <String>{};
  for (final segment in cookieHeader.split(';')) {
    final cookie = segment.trim();
    final separator = cookie.indexOf('=');
    if (separator <= 0) {
      continue;
    }
    final name = cookie.substring(0, separator).trim();
    final value = cookie.substring(separator + 1);
    if (name.isEmpty || !seen.add(name)) {
      continue;
    }
    result.add(
      provider_common_service.WebSessionCookie(
        name: name,
        value: value,
        domain: domain,
        path: '/',
        secure: uri.scheme.toLowerCase() == 'https',
        httpOnly: false,
        sessionOnly: true,
      ),
    );
  }
  return result;
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
  var lastVisibleCookieCount = 0;
  var lastMatchedCookieCount = 0;
  String? lastNativeCookieErrorType;
  String? lastVisibleCookieErrorType;

  Future<void> snapshot() async {
    if (reading || webview == null) return;
    reading = true;
    try {
      var matched = <provider_common_service.WebSessionCookie>[];
      var observedDomains = <String>[];

      try {
        final cookies = await webview.getAllCookies();
        lastNativeCookieErrorType = null;
        lastObservedCookieCount = cookies.length;
        observedDomains =
            cookies
                .map((cookie) => normalizeProviderCookieDomain(cookie.domain))
                .where((domain) => domain.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        matched = [
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
      } on Object catch (error) {
        lastNativeCookieErrorType = error.runtimeType.toString();
      }

      var captured = matched;
      if (captured.isEmpty && Platform.isWindows) {
        try {
          final visible = await _captureVisibleDesktopCookies(webview, spec);
          lastVisibleCookieErrorType = null;
          lastVisibleCookieCount = visible.length;
          if (visible.isNotEmpty) {
            captured = visible;
          }
        } on Object catch (error) {
          lastVisibleCookieErrorType = error.runtimeType.toString();
        }
      }

      lastMatchedCookieCount = captured.length;

      // WebView2 can transiently return an empty cookie list while a page is
      // navigating or while the native window is beginning to close. Never let
      // that empty read erase a session snapshot captured after successful
      // sign-in. A later non-empty snapshot still replaces the previous one so
      // refreshed cookie values are retained.
      if (captured.isNotEmpty) {
        latest = captured;
      }

      assert(() {
        final names = captured.map((cookie) => cookie.name).toSet().toList()
          ..sort();
        debugPrint(
          '${spec.label} WebSession cookie snapshot: '
          'native=$lastObservedCookieCount, '
          'visible=$lastVisibleCookieCount, matched=${captured.length}, '
          'domains=$observedDomains, matchedNames=$names, '
          'nativeError=${lastNativeCookieErrorType ?? 'none'}, '
          'visibleError=${lastVisibleCookieErrorType ?? 'none'}',
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
      final nativeRead = lastNativeCookieErrorType == null
          ? ''
          : ', nativeRead=$lastNativeCookieErrorType';
      final visibleRead = lastVisibleCookieErrorType == null
          ? ''
          : ', documentRead=$lastVisibleCookieErrorType';
      throw StateError(
        'No ${spec.label} session cookies were captured '
        '(WebView cookies: $lastObservedCookieCount, '
        'document cookies: $lastVisibleCookieCount, '
        'matching ${spec.allowedDomains.join(', ')}: '
        '$lastMatchedCookieCount$nativeRead$visibleRead). '
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

  // Keep the native Android/iOS WebView identity and enter the provider's
  // explicit mobile site. macOS keeps the ordinary desktop start URL.
  final startUri = Platform.isAndroid || Platform.isIOS
      ? spec.effectiveMobileStartUri
      : spec.startUri;
  await controller.loadRequest(startUri);
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
