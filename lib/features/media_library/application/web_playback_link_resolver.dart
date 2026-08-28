import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:synctv_app/contracts/web_playback_media_identity.dart';
import 'package:synctv_app/contracts/web_playback_site.dart';

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
  static const int _maxHtmlBytes = 256 * 1024;
  static const String _browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Safari/537.36';

  static final RegExp _urlInText = RegExp(
    r'https?://[^\s]+',
    caseSensitive: false,
  );
  static final RegExp _metaTagPattern = RegExp(
    r'<meta\b[^>]*>',
    caseSensitive: false,
  );
  static final RegExp _linkTagPattern = RegExp(
    r'<link\b[^>]*>',
    caseSensitive: false,
  );
  static final RegExp _attributePattern = RegExp(
    r'''([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))''',
    caseSensitive: false,
  );
  static final RegExp _locationAssignmentPattern = RegExp(
    r'''(?:window\s*\.\s*)?location(?:\s*\.\s*href)?\s*=\s*(['"])(.*?)\1''',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _locationCallPattern = RegExp(
    r'''(?:window\s*\.\s*)?location\s*\.\s*(?:replace|assign)\s*\(\s*(['"])(.*?)\1\s*\)''',
    caseSensitive: false,
    dotAll: true,
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

        final next = await _requestRedirect(client, current, policy);
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

  Future<Uri?> _requestRedirect(
    http.Client client,
    Uri uri,
    WebPlaybackSitePolicy policy,
  ) async {
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers['accept'] =
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      ..headers['accept-language'] = 'zh-CN,zh;q=0.9,en;q=0.8'
      ..headers['user-agent'] = _browserUserAgent;

    final response = await client.send(request).timeout(timeout);
    final location = response.headers['location'];
    final refresh = response.headers['refresh'];

    if (_redirectStatusCodes.contains(response.statusCode) &&
        location != null &&
        location.trim().isNotEmpty) {
      await _cancelBody(response.stream);
      return uri.resolve(location.trim());
    }

    final refreshTarget = _parseRefreshTarget(refresh);
    if (refreshTarget != null) {
      await _cancelBody(response.stream);
      return uri.resolve(refreshTarget);
    }

    final contentType = response.headers['content-type']?.toLowerCase();
    if (contentType != null &&
        !contentType.contains('text/html') &&
        !contentType.contains('application/xhtml+xml')) {
      await _cancelBody(response.stream);
      return null;
    }

    final body = await _readBodyPreview(response.stream).timeout(timeout);
    if (body.isEmpty) return null;

    final htmlTarget = _extractExplicitHtmlTarget(body);
    if (htmlTarget != null) {
      return uri.resolve(_decodeEmbeddedTarget(htmlTarget));
    }

    return _findEmbeddedEpisodeUri(body, policy);
  }

  static Future<void> _cancelBody(Stream<List<int>> stream) async {
    final subscription = stream.listen((_) {});
    await subscription.cancel();
  }

  static Future<String> _readBodyPreview(Stream<List<int>> stream) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      final remaining = _maxHtmlBytes - bytes.length;
      if (remaining <= 0) break;
      if (chunk.length <= remaining) {
        bytes.addAll(chunk);
      } else {
        bytes.addAll(chunk.take(remaining));
        break;
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static String? _extractExplicitHtmlTarget(String body) {
    for (final tagMatch in _metaTagPattern.allMatches(body)) {
      final attributes = _parseAttributes(tagMatch.group(0)!);
      final httpEquiv = attributes['http-equiv']?.toLowerCase();
      if (httpEquiv == 'refresh') {
        final target = _parseRefreshTarget(attributes['content']);
        if (target != null) return target;
      }

      final property =
          (attributes['property'] ?? attributes['name'])?.toLowerCase();
      if (property == 'og:url' || property == 'twitter:url') {
        final target = attributes['content']?.trim();
        if (target != null && target.isNotEmpty) return target;
      }
    }

    for (final tagMatch in _linkTagPattern.allMatches(body)) {
      final attributes = _parseAttributes(tagMatch.group(0)!);
      final rel = attributes['rel']?.toLowerCase().split(RegExp(r'\s+'));
      if (rel?.contains('canonical') == true) {
        final target = attributes['href']?.trim();
        if (target != null && target.isNotEmpty) return target;
      }
    }

    for (final pattern in [
      _locationCallPattern,
      _locationAssignmentPattern,
    ]) {
      final match = pattern.firstMatch(body);
      final target = match?.group(2)?.trim();
      if (target != null && target.isNotEmpty) return target;
    }

    return null;
  }

  static Map<String, String> _parseAttributes(String tag) {
    final attributes = <String, String>{};
    for (final match in _attributePattern.allMatches(tag)) {
      final name = match.group(1)!.toLowerCase();
      final value = match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
      attributes[name] = _decodeHtmlEntities(value);
    }
    return attributes;
  }

  static Uri? _findEmbeddedEpisodeUri(
    String body,
    WebPlaybackSitePolicy policy,
  ) {
    final decodedBody = _decodeEmbeddedTarget(body);
    for (final match in _urlInText.allMatches(decodedBody)) {
      var candidate = match.group(0);
      if (candidate == null || candidate.isEmpty) continue;

      while (candidate.isNotEmpty &&
          '''"'<>),;]}'''.contains(candidate[candidate.length - 1])) {
        candidate = candidate.substring(0, candidate.length - 1);
      }

      final parsed = Uri.tryParse(candidate);
      if (parsed == null) continue;
      final normalized = _normalizeTrustedUri(parsed, policy);
      if (normalized == null) continue;

      final identity = WebPlaybackMediaIdentity.tryParse(normalized);
      if (identity?.provider == policy.provider && identity?.isEpisode == true) {
        return identity!.canonicalUri;
      }
    }
    return null;
  }

  static String _decodeEmbeddedTarget(String value) {
    var decoded = _decodeHtmlEntities(value.trim());
    decoded = decoded
        .replaceAll(r'\/', '/')
        .replaceAll(RegExp(r'\\u002[fF]'), '/')
        .replaceAll(RegExp(r'\\u003[aA]'), ':')
        .replaceAll(RegExp(r'\\u0026'), '&')
        .replaceAll(RegExp(r'\\x2[fF]'), '/')
        .replaceAll(RegExp(r'\\x3[aA]'), ':');
    return decoded;
  }

  static String _decodeHtmlEntities(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&#38;', '&')
      .replaceAll('&#x26;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#34;', '"')
      .replaceAll('&#39;', "'");

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
