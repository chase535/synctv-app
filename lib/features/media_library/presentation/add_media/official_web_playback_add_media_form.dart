import 'package:flutter/material.dart';
import 'package:synctv_app/contracts/discovered_source.dart';
import 'package:synctv_app/core/presentation/notifications/app_notifications.dart';
import 'package:synctv_app/core/presentation/widgets/app_form_controls.dart';
import 'package:synctv_app/features/providers/presentation/provider_gateway_scope.dart';
import 'package:synctv_app/features/room/domain/web_playback_adapter_registry.dart';
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
  bool _loading = false;

  String get _providerName => switch (widget.provider) {
    WebPlaybackProvider.iqiyi => '爱奇艺',
    WebPlaybackProvider.tencentVideo => '腾讯视频',
  };

  String get _urlHint => switch (widget.provider) {
    WebPlaybackProvider.iqiyi => 'https://www.iqiyi.com/iex/v_19rrlo7rno.html',
    WebPlaybackProvider.tencentVideo =>
      'https://v.qq.com/x/cover/<coverId>/<videoId>.html',
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

  Uri? _validatedUri() {
    var input = _urlController.text.trim();
    if (input.isEmpty) return null;
    if (!input.contains('://')) input = 'https://$input';
    final uri = Uri.tryParse(input);
    if (uri == null) return null;
    final adapter = WebPlaybackAdapterRegistry.standard.forMediaUri(uri);
    if (adapter == null || adapter.provider != widget.provider) return null;
    final identity = adapter.identify(uri);
    if (identity == null || !identity.isEpisode) return null;
    return identity.canonicalUri;
  }

  Future<void> _submit() async {
    final uri = _validatedUri();
    if (uri == null) {
      AppNotifications.showWarning(
        context,
        '请输入 $_providerName 的具体单集/视频官方播放页链接',
      );
      return;
    }

    setState(() => _loading = true);
    try {
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
    final valid = _validatedUri() != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          key: ValueKey('${widget.provider.name}-official-url'),
          controller: _urlController,
          label: '$_providerName 官方播放页',
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
            if (valid && !_loading) _submit();
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
                    '使用官方网页和本机登录状态播放。SyncTV 只同步播放/暂停、进度、倍速和媒体身份；不会读取或同步 Cookie、会员凭证、DRM 密钥，也不会绕过网站广告。广告期间会暂停内容时间轴校正，广告结束后自动追上房间进度。',
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
            onPressed: valid ? _submit : null,
            loading: _loading,
            icon: Icons.playlist_add_rounded,
            label: '添加 $_providerName',
          ),
        ),
      ],
    );
  }
}
