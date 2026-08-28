import 'package:synctv_app/features/room/domain/web_playback_site.dart';

enum WebPlaybackMediaKind { iqiyiVideo, iqiyiAlbum, tencentCover, tencentVideo }

final class WebPlaybackMediaIdentity {
  const WebPlaybackMediaIdentity({
    required this.provider,
    required this.kind,
    required this.canonicalUri,
    this.collectionId,
    this.mediaId,
  });

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]+$');

  final WebPlaybackProvider provider;
  final WebPlaybackMediaKind kind;
  final Uri canonicalUri;
  final String? collectionId;
  final String? mediaId;

  bool get isEpisode => mediaId != null;

  bool isSameEpisodeAs(WebPlaybackMediaIdentity other) =>
      isEpisode &&
      other.isEpisode &&
      provider == other.provider &&
      mediaId == other.mediaId;

  String get stableKey =>
      '${provider.name}:${kind.name}:${collectionId ?? ''}:${mediaId ?? ''}';

  static WebPlaybackMediaIdentity? tryParse(Uri uri) {
    final policy = WebPlaybackSitePolicy.forUri(uri);
    if (policy == null) return null;

    return switch (policy.provider) {
      WebPlaybackProvider.iqiyi => _parseIqiyi(uri),
      WebPlaybackProvider.tencentVideo => _parseTencentVideo(uri),
    };
  }

  static WebPlaybackMediaIdentity? _parseIqiyi(Uri uri) {
    final match = RegExp(
      r'^/(?:iex/)?(v|a)_([A-Za-z0-9_-]+)\.html/?$',
    ).firstMatch(uri.path);
    if (match == null) return null;

    final pageKind = match.group(1)!;
    final id = match.group(2)!;
    final canonicalUri = Uri(
      scheme: 'https',
      host: 'www.iqiyi.com',
      path: uri.path.endsWith('/')
          ? uri.path.substring(0, uri.path.length - 1)
          : uri.path,
    );
    if (pageKind == 'v') {
      return WebPlaybackMediaIdentity(
        provider: WebPlaybackProvider.iqiyi,
        kind: WebPlaybackMediaKind.iqiyiVideo,
        canonicalUri: canonicalUri,
        mediaId: id,
      );
    }
    return WebPlaybackMediaIdentity(
      provider: WebPlaybackProvider.iqiyi,
      kind: WebPlaybackMediaKind.iqiyiAlbum,
      canonicalUri: canonicalUri,
      collectionId: id,
    );
  }

  static WebPlaybackMediaIdentity? _parseTencentVideo(Uri uri) {
    final coverEpisode = RegExp(
      r'^/x/cover/([A-Za-z0-9_-]+)/([A-Za-z0-9_-]+)\.html/?$',
    ).firstMatch(uri.path);
    if (coverEpisode != null) {
      final collectionId = coverEpisode.group(1)!;
      final mediaId = coverEpisode.group(2)!;
      return _tencentEpisode(mediaId, collectionId: collectionId);
    }

    final page = RegExp(
      r'^/x/page/([A-Za-z0-9_-]+)\.html/?$',
    ).firstMatch(uri.path);
    if (page != null) {
      return _tencentEpisode(page.group(1)!);
    }

    final queryMediaId = uri.queryParameters['vid'];
    final queryCollectionId = uri.queryParameters['cid'];
    if (_isMediaId(queryMediaId) && _isTencentQueryPlaybackPath(uri.path)) {
      return _tencentEpisode(
        queryMediaId!,
        collectionId: _isMediaId(queryCollectionId) ? queryCollectionId : null,
      );
    }

    final cover = RegExp(
      r'^/x/cover/([A-Za-z0-9_-]+)\.html/?$',
    ).firstMatch(uri.path);
    if (cover != null) {
      final collectionId = cover.group(1)!;
      if (_isMediaId(queryMediaId)) {
        return _tencentEpisode(queryMediaId!, collectionId: collectionId);
      }
      return WebPlaybackMediaIdentity(
        provider: WebPlaybackProvider.tencentVideo,
        kind: WebPlaybackMediaKind.tencentCover,
        canonicalUri: Uri(
          scheme: 'https',
          host: 'v.qq.com',
          path: '/x/cover/$collectionId.html',
        ),
        collectionId: collectionId,
      );
    }

    final detail = RegExp(
      r'^/detail/[A-Za-z0-9_-]/([A-Za-z0-9_-]+)\.html/?$',
    ).firstMatch(uri.path);
    if (detail != null) {
      return WebPlaybackMediaIdentity(
        provider: WebPlaybackProvider.tencentVideo,
        kind: WebPlaybackMediaKind.tencentCover,
        canonicalUri: Uri(
          scheme: 'https',
          host: 'v.qq.com',
          path: '/detail/${uri.pathSegments[1]}/${detail.group(1)!}.html',
        ),
        collectionId: detail.group(1),
      );
    }

    return null;
  }

  static WebPlaybackMediaIdentity _tencentEpisode(
    String mediaId, {
    String? collectionId,
  }) {
    final path = collectionId == null
        ? '/x/page/$mediaId.html'
        : '/x/cover/$collectionId/$mediaId.html';
    return WebPlaybackMediaIdentity(
      provider: WebPlaybackProvider.tencentVideo,
      kind: WebPlaybackMediaKind.tencentVideo,
      canonicalUri: Uri(scheme: 'https', host: 'v.qq.com', path: path),
      collectionId: collectionId,
      mediaId: mediaId,
    );
  }

  static bool _isMediaId(String? value) =>
      value != null && value.isNotEmpty && _idPattern.hasMatch(value);

  static bool _isTencentQueryPlaybackPath(String path) {
    final normalized = path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;
    return normalized == '/x/m/play' ||
        normalized == '/play.html' ||
        normalized == '/play/play.html';
  }
}
