import 'package:flutter/material.dart';
import 'package:synctv_app/contracts/discovered_source.dart';
import 'package:synctv_app/core/presentation/notifications/app_notifications.dart';
import 'package:synctv_app/core/presentation/widgets/app_form_controls.dart';
import 'package:synctv_app/features/media_library/application/web_playback_link_resolver.dart';
import 'package:synctv_app/features/providers/presentation/provider_gateway_scope.dart';
import 'package:synctv_app/features/room/domain/web_playback_site.dart';
import 'package:synctv_app/src/generated/proto/providers/common.pb.dart'
    as provider_common;
import 'package:synctv_app/src/generated/proto/source_config.pbenum.dart'
    as source_enum;

class OfficialWebPlaybackAddMediaForm extends StatefulWidget {
  const OfficialWebPlaybackAddMediaForm({
    super.key,
    required this.roomId,
    required this.playlistId,
    required this.provider,
    required this.onDraftChanged,
  });

  final String roomId;
  final String playlistId;
  final WebPlaybackProvider provider;
  final ValueChanged<bool> onDraftChanged;

  @override
  State<OfficialWebPlaybackAddMediaForm> createState() =>
      _OfficialWebPlaybackAddMediaFormState();
}

class _OfficialWebPlaybackAddMediaFormState
    extends State<OfficialWebPlaybackAddMediaForm> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  final _linkResolver = WebPlaybackLinkResolver();
  bool _loading = false;

  String get _providerName => switch (widget.provider) {
    WebPlaybackProvider.iqiyi => '爱奇艺',
    WebPlaybackProvider.tencentVideo => '腾讯视频',
  };

  String get _urlHint => switch (widget.provider) {
    WebPlaybackProvider.iqiyi =>
      '官网/移动端/分享链接，例如 https://qy.net/4aJQrYo-ef',
    WebPlaybackProvider.tencentVideo =>
      '官网/移动端/分享链接，例如 https://v.qq.com/x/cover/...',
  };

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _changed() {
    widget.onDraftChanged(
      _urlController.text.trim().isNotEmpty ||
          _nameController.text.trim().isNotEmpty,
    );
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    final input = _urlController.text.trim();
    if (input.isEmpty || _loading) return;

    setState(() => _loading = true);
    try {
      final uri = await _linkResolver.resolve(
        input,
        provider: widget.provider,
      );
      final prepared = await providerGateway.prepareDirectUrl(
        provider_common.PrepareDirectUrlRequest(
          url: uri.toString(),
          playbackKind: source_enum.PlaybackKind.PLAYBACK_KIND_REGULAR,
          proxyMode:
              source_enum.PlaybackProxyMode.PLAYBACK_PROXY_MODE_DIRECT_ONLY,
        ),
      );
      if (!prepared.hasSource()) {
        throw StateError('Server returned no DirectUrl media source');
      }
      final customName = _nameController.text.trim();
      await providerGateway.addDiscoveredSource(
        widget.roomId,
        playlistId: widget.playlistId,
        source: prepared.source.withPlaybackProxyMode(
          source_enum.PlaybackProxyMode.PLAYBACK_PROXY_MODE_DIRECT_ONLY,
        ),
        name: customName.isEmpty
            ? '$_providerName · ${prepared.suggestedName}'
            : customName,
      );
      if (!mounted) return;
      widget.onDraftChanged(false);
      Navigator.of(context).pop();
      AppNotifications.showSuccess(context, '已添加 $_providerName 官方网页播放源');
    } on WebPlaybackLinkResolutionException catch (error) {
      if (mounted) {
        AppNotifications.showWarning(context, '$_providerName：${error.message}');
      }
    } catch (error) {
      if (mounted) {
        AppNotifications.showError(context, '添加 $_providerName 失败：$error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSubmit = _urlController.text.trim().isNotEmpty && !_loading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          key: ValueKey('${widget.provider.name}-official-url'),
          controller: _urlController,
          label: '$_providerName 官方播放页或分享链接',
          hintText: _urlHint,
          prefixIcon: Icons.language_rounded,
          enabled: !_loading,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          onChanged: (_) => _changed(),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _nameController,
          label: '名称（可选）',
          prefixIcon: Icons.title_rounded,
          enabled: !_loading,
          textInputAction: TextInputAction.done,
          onChanged: (_) => _changed(),
          onSubmitted: (_) {
            if (canSubmit) _submit();
          },
        ),
        const SizedBox(height: 18),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '支持官网、移动端和官方分享/短链接；分享链接会先安全解析为具体单集或视频的官方播放页。使用本机登录状态播放，SyncTV 只同步播放/暂停、进度、倍速和媒体身份；不会读取或同步 Cookie、会员凭证、DRM 密钥，也不会绕过网站广告。',
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        Align(
          alignment: Alignment.centerRight,
          child: AppActionButton(
            key: ValueKey('${widget.provider.name}-official-submit'),
            onPressed: canSubmit ? _submit : null,
            loading: _loading,
            icon: Icons.playlist_add_rounded,
            label: '添加 $_providerName',
          ),
        ),
      ],
    );
  }
}
