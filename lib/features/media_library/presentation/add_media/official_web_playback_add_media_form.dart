import 'package:flutter/material.dart';
import 'package:synctv_app/contracts/discovered_source.dart';
import 'package:synctv_app/core/presentation/notifications/app_notifications.dart';
import 'package:synctv_app/core/presentation/widgets/app_form_controls.dart';
import 'package:synctv_app/core/web/official_site_login_client.dart';
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
  final _loginClient = const OfficialSiteLoginClient();
  bool _loading = false;
  bool _openingLogin = false;

  String get _providerName => switch (widget.provider) {
    WebPlaybackProvider.iqiyi => '爱奇艺',
    WebPlaybackProvider.tencentVideo => '腾讯视频',
  };

  String get _urlHint => switch (widget.provider) {
    WebPlaybackProvider.iqiyi => '支持 iqiyi.com / qy.net 等爱奇艺官方网页、移动端及分享链接',
    WebPlaybackProvider.tencentVideo =>
      '支持 v.qq.com / m.v.qq.com 等腾讯视频官方网页、移动端及分享链接',
  };

  String get _loginButtonLabel => switch (widget.provider) {
    WebPlaybackProvider.iqiyi => '登录爱奇艺（优先手机号验证码）',
    WebPlaybackProvider.tencentVideo => '登录腾讯视频（QQ / 微信）',
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

  Future<void> _openLogin() async {
    if (_openingLogin || !_loginClient.supported) return;
    setState(() => _openingLogin = true);
    try {
      await _loginClient.open(widget.provider);
      if (!mounted) return;
      final message = switch (widget.provider) {
        WebPlaybackProvider.iqiyi =>
          '已打开爱奇艺官方登录页。可直接使用手机号短信验证码，也可使用页面提供的其他官方登录方式。',
        WebPlaybackProvider.tencentVideo =>
          '已打开腾讯视频官方登录页。可使用页面提供的 QQ、微信等官方登录方式。',
      };
      AppNotifications.showSuccess(context, message);
    } catch (error) {
      if (mounted) {
        AppNotifications.showError(context, '打开 $_providerName 登录页失败：$error');
      }
    } finally {
      if (mounted) setState(() => _openingLogin = false);
    }
  }

  Future<void> _submit() async {
    final input = _urlController.text.trim();
    if (input.isEmpty || _loading) return;

    setState(() => _loading = true);
    try {
      final uri = await _linkResolver.resolve(input, provider: widget.provider);
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
        AppNotifications.showWarning(
          context,
          '$_providerName：${error.message}',
        );
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
    final canOpenLogin =
        _loginClient.supported && !_openingLogin && !_loading;
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
                    '支持官网、移动端和官方分享/短链接；分享链接会先安全解析为具体单集或视频的官方播放页。登录窗口与播放器复用同一本机 WebView2 配置目录，登录状态由官方网站直接保存；SyncTV 不读取或同步 Cookie、验证码、账号凭证、会员凭证或 DRM 信息，也不会绕过网站广告。',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: ValueKey('${widget.provider.name}-official-login'),
            onPressed: canOpenLogin ? _openLogin : null,
            icon: _openingLogin
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login_rounded),
            label: Text(_loginButtonLabel),
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
