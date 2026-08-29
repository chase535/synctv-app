import 'package:flutter/material.dart';
import 'package:synctv_app/core/presentation/notifications/app_notifications.dart';
import 'package:synctv_app/core/presentation/widgets/app_form_controls.dart';
import 'package:synctv_app/features/media_library/presentation/add_media/playback_proxy_mode_control.dart';
import 'package:synctv_app/features/media_library/presentation/add_media/provider_workspace.dart';
import 'package:synctv_app/features/providers/domain/provider_web_session_spec.dart';
import 'package:synctv_app/features/providers/presentation/provider_gateway_scope.dart';
import 'package:synctv_app/features/providers/presentation/provider_web_session_capture.dart';
import 'package:synctv_app/l10n/l10n.dart';
import 'package:synctv_app/src/generated/proto/providers/common.pb.dart'
    as provider_common;
import 'package:synctv_app/src/generated/proto/providers/common_service.pb.dart'
    as provider_common_service;
import 'package:synctv_app/src/generated/proto/source_config.pb.dart'
    as source_config;
import 'package:synctv_app/src/generated/proto/source_config.pbenum.dart'
    as source_enum;

final _webSessionPlaybackProxyPolicy = provider_common.PlaybackProxyPolicy(
  supportedModes: [
    source_enum.PlaybackProxyMode.PLAYBACK_PROXY_MODE_AUTO,
    source_enum.PlaybackProxyMode.PLAYBACK_PROXY_MODE_DIRECT_PREFER,
    source_enum.PlaybackProxyMode.PLAYBACK_PROXY_MODE_DIRECT_ONLY,
  ],
);

class ProviderWebSessionAddMediaForm extends StatefulWidget {
  const ProviderWebSessionAddMediaForm({
    super.key,
    required this.roomId,
    required this.playlistId,
    required this.provider,
    required this.onDraftChanged,
  });

  final String roomId;
  final String playlistId;
  final source_enum.SourceProvider provider;
  final ValueChanged<bool> onDraftChanged;

  @override
  State<ProviderWebSessionAddMediaForm> createState() =>
      _ProviderWebSessionAddMediaFormState();
}

class _ProviderWebSessionAddMediaFormState
    extends State<ProviderWebSessionAddMediaForm> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  bool _shared = false;
  bool _loading = false;
  source_enum.PlaybackProxyMode _proxyMode =
      source_enum.PlaybackProxyMode.PLAYBACK_PROXY_MODE_AUTO;
  provider_common_service.WebSessionBinding? _binding;

  ProviderWebSessionSpec get _spec => providerWebSessionSpec(widget.provider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshBinding();
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _notifyDraft() {
    widget.onDraftChanged(
      _urlController.text.trim().isNotEmpty ||
          _nameController.text.trim().isNotEmpty ||
          _shared ||
          _proxyMode != source_enum.PlaybackProxyMode.PLAYBACK_PROXY_MODE_AUTO,
    );
  }

  Uri? get _validatedUri {
    final uri = Uri.tryParse(_urlController.text.trim());
    if (uri == null || !providerWebSessionUrlAllowed(uri, _spec)) return null;
    return uri;
  }

  Future<void> _refreshBinding() async {
    try {
      final bindings = await providerGateway.listWebSessions();
      if (!mounted) return;
      setState(() {
        _binding = bindings
            .where((binding) => binding.provider == widget.provider)
            .firstOrNull;
      });
    } catch (error) {
      if (mounted) AppNotifications.showError(context, '$error');
    }
  }

  Future<void> _captureAndBind() async {
    if (!providerWebSessionCaptureSupported) {
      AppNotifications.showWarning(
        context,
        '${_spec.label} session capture is available in native apps only.',
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final cookies = await captureProviderWebSession(context, widget.provider);
      if (cookies.isEmpty) return;
      final binding = await providerGateway.bindWebSession(
        provider: widget.provider,
        label: '${_spec.label} official session',
        cookies: cookies,
      );
      if (!mounted) return;
      setState(() => _binding = binding);
      AppNotifications.showSuccess(
        context,
        '${_spec.label} session connected.',
      );
    } catch (error) {
      if (mounted) AppNotifications.showError(context, '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unbind() async {
    setState(() => _loading = true);
    try {
      await providerGateway.unbindWebSession(widget.provider);
      if (!mounted) return;
      setState(() => _binding = null);
      AppNotifications.showSuccess(
        context,
        '${_spec.label} session disconnected.',
      );
    } catch (error) {
      if (mounted) AppNotifications.showError(context, '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMedia() async {
    final uri = _validatedUri;
    if (uri == null) {
      AppNotifications.showWarning(
        context,
        'Enter an official HTTPS ${_spec.label} URL.',
      );
      return;
    }

    final media = switch (widget.provider) {
      source_enum.SourceProvider.SOURCE_PROVIDER_IQIYI =>
        source_config.MediaSourceConfig(
          iqiyi: source_config.IqiyiMediaSourceConfig(
            url: uri.toString(),
            shared: _shared,
            proxyMode: _proxyMode,
          ),
        ),
      source_enum.SourceProvider.SOURCE_PROVIDER_TENCENT_VIDEO =>
        source_config.MediaSourceConfig(
          tencentVideo: source_config.TencentVideoMediaSourceConfig(
            url: uri.toString(),
            shared: _shared,
            proxyMode: _proxyMode,
          ),
        ),
      _ => throw StateError('Unsupported WebSession media provider.'),
    };

    setState(() => _loading = true);
    try {
      await providerGateway.addDiscoveredSource(
        widget.roomId,
        playlistId: widget.playlistId,
        source: provider_common.DiscoveredSource(media: media),
        name: _nameController.text.trim().isEmpty
            ? _spec.label
            : _nameController.text.trim(),
      );
      if (!mounted) return;
      _urlController.clear();
      _nameController.clear();
      _shared = false;
      _proxyMode = source_enum.PlaybackProxyMode.PLAYBACK_PROXY_MODE_AUTO;
      widget.onDraftChanged(false);
      AppNotifications.showSuccess(context, context.l10n.addedSuccessfully);
      setState(() {});
    } catch (error) {
      if (mounted) AppNotifications.showError(context, '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final binding = _binding;
    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          key: ValueKey('${_spec.label}-url'),
          controller: _urlController,
          enabled: !_loading,
          label: '${_spec.label} official video URL',
          prefixIcon: Icons.link_rounded,
          keyboardType: TextInputType.url,
          enableSuggestions: false,
          autocorrect: false,
          onChanged: (_) {
            _notifyDraft();
            setState(() {});
          },
        ),
        const SizedBox(height: 12),
        AppTextField(
          key: ValueKey('${_spec.label}-name'),
          controller: _nameController,
          enabled: !_loading,
          label: context.l10n.name,
          prefixIcon: Icons.title_rounded,
          onChanged: (_) {
            _notifyDraft();
            setState(() {});
          },
        ),
        const SizedBox(height: 12),
        AppSwitchTile(
          contentPadding: EdgeInsets.zero,
          prefix: const Icon(Icons.group_outlined),
          title: const Text("Use room owner's session"),
          subtitle: const Text(
            'Off uses the current viewer session. On uses the room owner session.',
          ),
          value: _shared,
          onChanged: _loading
              ? null
              : (value) => setState(() {
                  _shared = value;
                  _notifyDraft();
                }),
        ),
        const SizedBox(height: 8),
        PlaybackProxyModeControl(
          value: _proxyMode,
          enabled: !_loading,
          policy: _webSessionPlaybackProxyPolicy,
          onChanged: (value) {
            setState(() {
              _proxyMode = value;
              _notifyDraft();
            });
          },
        ),
        const SizedBox(height: 16),
        AppPanelSurface(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                binding == null
                    ? Icons.no_accounts_outlined
                    : Icons.verified_user_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      binding == null
                          ? 'No local ${_spec.label} session connected'
                          : (binding.label.isEmpty
                                ? '${_spec.label} session connected'
                                : binding.label),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (binding != null)
                      Text('${binding.cookieCount} cookies · values hidden'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (binding != null)
                AppActionButton(
                  onPressed: _loading ? null : _unbind,
                  label: 'Disconnect',
                  style: AppActionButtonStyle.text,
                  size: AppActionButtonSize.sm,
                ),
              const SizedBox(width: 4),
              AppActionButton(
                key: ValueKey('${_spec.label}-connect-session'),
                onPressed: _loading ? null : _captureAndBind,
                icon: Icons.login_rounded,
                label: binding == null ? 'Connect session' : 'Refresh',
                size: AppActionButtonSize.sm,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Login opens only the official ${_spec.allowedDomain} site. '
          'Cookie values are sent only in the bind request and are never shown in the binding list.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: AppActionButton(
            key: ValueKey('${_spec.label}-add-media'),
            onPressed: _loading || _validatedUri == null ? null : _addMedia,
            icon: Icons.add_rounded,
            label: context.l10n.addMedia,
            loading: _loading,
          ),
        ),
      ],
    );

    return ProviderWorkspace(
      controls: controls,
      results: const SizedBox.shrink(),
    );
  }
}
