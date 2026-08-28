import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:synctv_app/features/room/domain/web_playback_media_identity.dart';
import 'package:synctv_app/features/room/domain/web_playback_site.dart';

final class WebPlaybackLinkResolutionException implements Exception {
  const WebPlaybackLinkResolutionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resolves official desktop/mobile/share links to a canonical episode URL.
///
/// Only provider-owned or explicitly trusted share/redirect hosts are ever
/// requested. Redirects are followed manually so every hop can be checked
/// before the next network request is made.
final class WebPlaybackLinkResolver {
  factory WebPlaybackLinkResolver({
    http.Client? client,
    Duration timeout = const Duration(seconds: 8),
    int maxRedirects = 6,
  }) => WebPlaybackLinkResolver._(client, timeout, maxRedirects);

  WebPlaybackLinkResolver._(this._client, this.timeout, this.maxRedirects);

  static const Set<int> _redirectStatusCodes = {301, 302, 303, 307, 308};
  static final RegExp _urlInText = RegExp(
    r'https?://[^\s]+',
    caseSensitive: false,
  );

  final http.Client? _client;
  final Duration timeout;
  final int maxRedirects;

  Future<Uri> resolve(
    String rawInput, {
    required WebPlaybackProvider provider,
  }) async {
    final parsed = _parseInput(rawInput);
    if (parsed == null) {
      throw const WebPlaybackLinkResolutionException('链接格式无效');
    }

    final policy = WebPlaybackSitePolicy.forProvider(provider);
    final initialUri = _normalizeTrustedUri(parsed, policy);
    if (initialUri == null) {
      throw const WebPlaybackLinkResolutionException(
        '链接不属于当前选择的视频平台，或不是受支持的官方/分享链接',
      );
    }
    var current = initialUri;

    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    final visited = <String>{};
    try {
      for (var hop = 0; hop <= maxRedirects; hop++) {
        if (!visited.add(current.toString())) {
          throw const WebPlaybackLinkResolutionException('分享链接发生循环跳转');
        }

        final identity = WebPlaybackMediaIdentity.tryParse(current);
        if (identity != null && identity.provider == provider) {
          if (!identity.isEpisode) {
            throw const WebPlaybackLinkResolutionException(
              '该链接指向专辑/合集，请分享具体单集或视频的播放链接',
            );
          }
          return identity.canonicalUri;
        }

        if (hop == maxRedirects) {
          throw const WebPlaybackLinkResolutionException('分享链接跳转次数过多');
        }

        final next = await _requestRedirect(client, current);
        if (next == null) {
          throw const WebPlaybackLinkResolutionException(
            '这是官方链接，但暂时无法从中识别出具体单集/视频，请复制视频正在播放时的分享链接',
          );
        }

        final normalized = _normalizeTrustedUri(next, policy);
        if (normalized == null) {
          throw const WebPlaybackLinkResolutionException(
            '分享链接跳转到了非当前视频平台页面，已停止解析',
          );
        }
        current = normalized;
      }
    } on TimeoutException {
      throw const WebPlaybackLinkResolutionException('解析分享链接超时，请检查网络后重试');
    } on http.ClientException catch (error) {
      throw WebPlaybackLinkResolutionException('无法解析分享链接：${error.message}');
    } finally {
      if (ownsClient) client.close();
    }

    throw const WebPlaybackLinkResolutionException('无法识别该视频链接');
  }

  static Uri? _parseInput(String rawInput) {
    var value = rawInput.trim();
    if (value.isEmpty) return null;

    final embedded = _urlInText.firstMatch(value);
    if (embedded != null) {
      value = embedded.group(0)!;
    } else {
      if (value.contains(RegExp(r'\s'))) return null;
      if (!value.contains('://')) value = 'https://$value';
    }

    const trailingPunctuation = '.,;:!?)]}>，。；：！？）】》」』';
    while (value.isNotEmpty &&
        trailingPunctuation.contains(value[value.length - 1])) {
      value = value.substring(0, value.length - 1);
    }
    return Uri.tryParse(value);
  }

  static Uri? _normalizeTrustedUri(Uri uri, WebPlaybackSitePolicy policy) {
    final scheme = uri.scheme.toLowerCase();
    if ((scheme != 'https' && scheme != 'http') ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    if (!policy.recognizesInputHost(uri.host)) return null;

    if (uri.hasPort) {
      final expectedPort = scheme == 'https' ? 443 : 80;
      if (uri.port != expectedPort) return null;
      // Explicit :80 would survive Uri.replace(scheme: 'https') as :80, so
      // reject that unusual form rather than accidentally requesting HTTPS:80.
      if (scheme == 'http') return null;
    }

    return uri.replace(scheme: 'https', host: uri.host.toLowerCase());
  }

  Future<Uri?> _requestRedirect(http.Client client, Uri uri) async {
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers['accept'] =
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      ..headers['user-agent'] =
          'Mozilla/5.0 (SyncTV; official playback link resolver)';

    final response = await client.send(request).timeout(timeout);
    final location = response.headers['location'];
    final refresh = response.headers['refresh'];
    final subscription = response.stream.listen((_) {});
    await subscription.cancel();

    if (_redirectStatusCodes.contains(response.statusCode) &&
        location != null &&
        location.trim().isNotEmpty) {
      return uri.resolve(location.trim());
    }

    final refreshTarget = _parseRefreshTarget(refresh);
    if (refreshTarget != null) return uri.resolve(refreshTarget);
    return null;
  }

  static String? _parseRefreshTarget(String? refresh) {
    if (refresh == null || refresh.isEmpty) return null;
    final match = RegExp(
      r'^\s*\d+(?:\.\d+)?\s*;\s*url\s*=\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(refresh);
    var target = match?.group(1)?.trim();
    if (target == null || target.isEmpty) return null;
    if (target.length >= 2 &&
        ((target.startsWith('"') && target.endsWith('"')) ||
            (target.startsWith("'") && target.endsWith("'")))) {
      target = target.substring(1, target.length - 1).trim();
    }
    return target.isEmpty ? null : target;
  }
}
