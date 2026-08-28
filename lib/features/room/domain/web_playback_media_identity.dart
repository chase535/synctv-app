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

    final canonicalUri = Uri(
      scheme: 'https',
      host: uri.host.toLowerCase(),
      path: uri.path,
    );

    return switch (policy.provider) {
      WebPlaybackProvider.iqiyi => _parseIqiyi(canonicalUri),
      WebPlaybackProvider.tencentVideo => _parseTencentVideo(canonicalUri),
    };
  }

  static WebPlaybackMediaIdentity? _parseIqiyi(Uri uri) {
    final match = RegExp(
      r'^/(?:iex/)?(v|a)_([A-Za-z0-9_-]+)\.html$',
    ).firstMatch(uri.path);
    if (match == null) return null;

    final pageKind = match.group(1)!;
    final id = match.group(2)!;
    if (pageKind == 'v') {
      return WebPlaybackMediaIdentity(
        provider: WebPlaybackProvider.iqiyi,
        kind: WebPlaybackMediaKind.iqiyiVideo,
        canonicalUri: uri,
        mediaId: id,
      );
    }
    return WebPlaybackMediaIdentity(
      provider: WebPlaybackProvider.iqiyi,
      kind: WebPlaybackMediaKind.iqiyiAlbum,
      canonicalUri: uri,
      collectionId: id,
    );
  }

  static WebPlaybackMediaIdentity? _parseTencentVideo(Uri uri) {
    final coverEpisode = RegExp(
      r'^/x/cover/([A-Za-z0-9]+)/([A-Za-z0-9]+)\.html$',
    ).firstMatch(uri.path);
    if (coverEpisode != null) {
      return WebPlaybackMediaIdentity(
        provider: WebPlaybackProvider.tencentVideo,
        kind: WebPlaybackMediaKind.tencentVideo,
        canonicalUri: uri,
        collectionId: coverEpisode.group(1),
        mediaId: coverEpisode.group(2),
      );
    }

    final cover = RegExp(
      r'^/x/cover/([A-Za-z0-9]+)\.html$',
    ).firstMatch(uri.path);
    if (cover != null) {
      return WebPlaybackMediaIdentity(
        provider: WebPlaybackProvider.tencentVideo,
        kind: WebPlaybackMediaKind.tencentCover,
        canonicalUri: uri,
        collectionId: cover.group(1),
      );
    }

    final page = RegExp(r'^/x/page/([A-Za-z0-9]+)\.html$').firstMatch(uri.path);
    if (page != null) {
      return WebPlaybackMediaIdentity(
        provider: WebPlaybackProvider.tencentVideo,
        kind: WebPlaybackMediaKind.tencentVideo,
        canonicalUri: uri,
        mediaId: page.group(1),
      );
    }

    final detail = RegExp(
      r'^/detail/[A-Za-z0-9]/([A-Za-z0-9]+)\.html$',
    ).firstMatch(uri.path);
    if (detail != null) {
      return WebPlaybackMediaIdentity(
        provider: WebPlaybackProvider.tencentVideo,
        kind: WebPlaybackMediaKind.tencentCover,
        canonicalUri: uri,
        collectionId: detail.group(1),
      );
    }

    return null;
  }
}
