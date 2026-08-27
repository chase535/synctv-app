#!/usr/bin/env python3
from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one anchor, found {count}: {old[:120]!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def insert_before(path: Path, anchor: str, addition: str) -> None:
    replace_once(path, anchor, addition + anchor)


root = Path(__file__).resolve().parents[2]
add_media = root / "lib/features/media_library/presentation/add_media_dialog.dart"
room = root / "lib/features/room/presentation/room_screen.dart"
bridge = root / "lib/features/room/domain/web_playback_bridge_script.dart"

# Add dedicated iQIYI/Tencent source entries while persisting through DirectUrl.
replace_once(
    add_media,
    "import 'package:synctv_app/features/media_library/presentation/add_media/tiktok_add_media_form.dart';\n",
    "import 'package:synctv_app/features/media_library/presentation/add_media/tiktok_add_media_form.dart';\n"
    "import 'package:synctv_app/features/media_library/presentation/add_media/official_web_playback_add_media_form.dart';\n"
    "import 'package:synctv_app/features/room/domain/web_playback_site.dart';\n",
)
replace_once(
    add_media,
    "      case 20:\n        return 'TikTok';\n      default:\n",
    "      case 20:\n        return 'TikTok';\n"
    "      case 21:\n        return '爱奇艺';\n"
    "      case 22:\n        return '腾讯视频';\n"
    "      default:\n",
)
replace_once(
    add_media,
    "            const _MediaSourceSpec(\n              index: 20,\n              title: 'TikTok',\n              subtitle: 'Video / Live / User Posts',\n              icon: Icons.music_video_rounded,\n              color: Color(0xFFFE2C55),\n            ),\n",
    "            const _MediaSourceSpec(\n              index: 20,\n              title: 'TikTok',\n              subtitle: 'Video / Live / User Posts',\n              icon: Icons.music_video_rounded,\n              color: Color(0xFFFE2C55),\n            ),\n"
    "            const _MediaSourceSpec(\n              index: 21,\n              title: '爱奇艺',\n              subtitle: 'Official webpage / synchronized playback',\n              icon: Icons.play_circle_outline_rounded,\n              color: Color(0xFF00BE06),\n            ),\n"
    "            const _MediaSourceSpec(\n              index: 22,\n              title: '腾讯视频',\n              subtitle: 'Official webpage / synchronized playback',\n              icon: Icons.play_circle_outline_rounded,\n              color: Color(0xFF1AAD19),\n            ),\n",
)
replace_once(
    add_media,
    "            if (providerType == null) return spec;\n",
    "            if (providerType == null || spec.index == 21 || spec.index == 22) {\n"
    "              return spec;\n"
    "            }\n",
)
replace_once(
    add_media,
    "      case 20:\n        return TikTokAddMediaForm(\n          roomId: widget.roomId,\n          playlistId: widget.parentId ?? '',\n          binds: _tiktokBinds,\n          onDraftChanged: (value) => _tiktokHasDraft = value,\n        );\n      default:\n",
    "      case 20:\n        return TikTokAddMediaForm(\n          roomId: widget.roomId,\n          playlistId: widget.parentId ?? '',\n          binds: _tiktokBinds,\n          onDraftChanged: (value) => _tiktokHasDraft = value,\n        );\n"
    "      case 21:\n        return OfficialWebPlaybackAddMediaForm(\n"
    "          roomId: widget.roomId,\n"
    "          playlistId: widget.parentId ?? '',\n"
    "          provider: WebPlaybackProvider.iqiyi,\n"
    "          onDraftChanged: (value) => _iqiyiHasDraft = value,\n"
    "        );\n"
    "      case 22:\n        return OfficialWebPlaybackAddMediaForm(\n"
    "          roomId: widget.roomId,\n"
    "          playlistId: widget.parentId ?? '',\n"
    "          provider: WebPlaybackProvider.tencentVideo,\n"
    "          onDraftChanged: (value) => _tencentVideoHasDraft = value,\n"
    "        );\n"
    "      default:\n",
)
replace_once(
    add_media,
    "  bool _tiktokHasDraft = false;\n",
    "  bool _tiktokHasDraft = false;\n"
    "  bool _iqiyiHasDraft = false;\n"
    "  bool _tencentVideoHasDraft = false;\n",
)
replace_once(
    add_media,
    "        _douyinHasDraft ||\n        _tiktokHasDraft) {\n",
    "        _douyinHasDraft ||\n"
    "        _tiktokHasDraft ||\n"
    "        _iqiyiHasDraft ||\n"
    "        _tencentVideoHasDraft) {\n",
)
replace_once(
    add_media,
    "      20 => 'tiktok',\n      _ => null,\n",
    "      20 => 'tiktok',\n"
    "      21 || 22 => 'directUrl',\n"
    "      _ => null,\n",
)

# WebView2 ExecuteScript does not await JS Promises. Keep command acceptance synchronous
# and report asynchronous play() rejection through the authenticated command error channel.
replace_once(bridge, "  async function command(input) {\n", "  function command(input) {\n")
replace_once(
    bridge,
    "      if (type === 'play') {\n"
    "        rememberCommand('play', commandId);\n"
    "        await video.play();\n"
    "        setTimeout(() => {\n"
    "          acknowledgeIfPending('play', commandId, {\n"
    "            position: finiteNumber(video.currentTime)\n"
    "              ? video.currentTime\n"
    "              : undefined,\n"
    "          });\n"
    "        }, 100);\n"
    "        return true;\n"
    "      }\n",
    "      if (type === 'play') {\n"
    "        rememberCommand('play', commandId);\n"
    "        const playResult = video.play();\n"
    "        if (playResult && typeof playResult.catch === 'function') {\n"
    "          playResult.catch((error) => {\n"
    "            const pending = pendingCommands.get('play');\n"
    "            if (pending && pending.id === commandId) {\n"
    "              pendingCommands.delete('play');\n"
    "            }\n"
    "            emitCommandError(commandId, error);\n"
    "          });\n"
    "        }\n"
    "        setTimeout(() => {\n"
    "          acknowledgeIfPending('play', commandId, {\n"
    "            position: finiteNumber(video.currentTime)\n"
    "              ? video.currentTime\n"
    "              : undefined,\n"
    "          });\n"
    "        }, 100);\n"
    "        return true;\n"
    "      }\n",
)

# Room integration: official web playback uses the same generic realtime protocol.
replace_once(
    room,
    "import 'package:synctv_app/features/room/application/room_playback_controller.dart';\n",
    "import 'package:synctv_app/features/room/application/room_playback_controller.dart';\n"
    "import 'package:synctv_app/features/room/application/web_playback_client.dart';\n"
    "import 'package:synctv_app/features/room/application/web_playback_coordinator.dart';\n"
    "import 'package:synctv_app/features/room/infrastructure/desktop_web_playback_client.dart';\n"
    "import 'package:synctv_app/features/room/domain/web_playback_adapter_registry.dart';\n"
    "import 'package:synctv_app/features/room/domain/web_playback_bridge_message.dart';\n"
    "import 'package:synctv_app/features/room/domain/web_playback_event_router.dart';\n"
    "import 'package:synctv_app/features/room/domain/web_playback_phase.dart';\n"
    "import 'package:synctv_app/features/room/domain/web_playback_runtime.dart';\n"
    "import 'package:synctv_app/features/room/domain/web_playback_site.dart';\n"
    "import 'package:synctv_app/features/room/domain/web_playback_sync_gate.dart';\n",
)
replace_once(
    room,
    "  String? _videoError;\n  String? _roomSessionError;\n",
    "  String? _videoError;\n"
    "  String? _roomSessionError;\n"
    "  final WebPlaybackClient _webPlaybackClient =\n"
    "      const NativeDesktopWebPlaybackClient();\n"
    "  WebPlaybackSession? _webPlaybackSession;\n"
    "  WebPlaybackCoordinator? _webPlaybackCoordinator;\n"
    "  StreamSubscription<WebPlaybackRuntimeUpdate>?\n"
    "  _webPlaybackUpdatesSubscription;\n"
    "  Uri? _webPlaybackUri;\n"
    "  WebPlaybackProvider? _webPlaybackProvider;\n"
    "  WebPlaybackSnapshot? _webPlaybackSnapshot;\n"
    "  String? _webPlaybackError;\n"
    "  bool _webPlaybackOpening = false;\n"
    "  bool _webPlaybackAutoOpenSuppressed = false;\n"
    "  int _webPlaybackGeneration = 0;\n",
)
replace_once(
    room,
    "  void dispose() {\n    _isDisposing = true;\n",
    "  void dispose() {\n"
    "    _isDisposing = true;\n"
    "    _webPlaybackGeneration += 1;\n"
    "    unawaited(_webPlaybackUpdatesSubscription?.cancel());\n"
    "    _webPlaybackUpdatesSubscription = null;\n"
    "    final webPlaybackCoordinator = _webPlaybackCoordinator;\n"
    "    final webPlaybackSession = _webPlaybackSession;\n"
    "    _webPlaybackCoordinator = null;\n"
    "    _webPlaybackSession = null;\n"
    "    if (webPlaybackCoordinator != null) {\n"
    "      unawaited(webPlaybackCoordinator.close());\n"
    "    } else if (webPlaybackSession != null) {\n"
    "      unawaited(webPlaybackSession.close());\n"
    "    }\n",
)
replace_once(
    room,
    "    _reconnectTimer?.cancel();\n    await _disposeVideoController();\n",
    "    _reconnectTimer?.cancel();\n"
    "    await _disposeVideoController();\n"
    "    await _disposeWebPlayback();\n",
)

web_helpers = r'''  Future<void> _applyWebPlaybackStatus(
    SyncTvPlaybackStatus status,
    Uri uri, {
    required bool applySync,
  }) async {
    final adapter = WebPlaybackAdapterRegistry.standard.forMediaUri(uri);
    final identity = adapter?.identify(uri);
    if (adapter == null || identity == null || !identity.isEpisode) return;
    final canonicalUri = identity.canonicalUri;
    final provider = adapter.provider;
    final sameProvider = _webPlaybackProvider == provider;
    final sameMedia = _webPlaybackUri == canonicalUri;

    if (!_webPlaybackClient.supported) {
      if (_webPlaybackCoordinator != null || _webPlaybackSession != null) {
        await _disposeWebPlayback(clearUri: false);
      }
      if (!mounted || _isDisposing) return;
      setState(() {
        _webPlaybackUri = canonicalUri;
        _webPlaybackProvider = provider;
        _webPlaybackSnapshot = null;
        _webPlaybackOpening = false;
        _webPlaybackError =
            '当前平台暂不支持官方网页同步播放器。Windows 客户端需要 WebView2 Runtime。';
      });
      return;
    }

    if (_webPlaybackSession == null &&
        _webPlaybackAutoOpenSuppressed &&
        sameProvider &&
        sameMedia) {
      return;
    }

    final existingSession = _webPlaybackSession;
    final existingCoordinator = _webPlaybackCoordinator;
    if (existingSession != null &&
        existingCoordinator != null &&
        sameProvider) {
      if (!sameMedia) {
        _webPlaybackAutoOpenSuppressed = false;
        await existingSession.navigate(canonicalUri);
      }
      _webPlaybackUri = canonicalUri;
      _webPlaybackProvider = provider;
      if (applySync) {
        existingCoordinator.updateAuthoritativeState(
          _webPlaybackTarget(status),
        );
      }
      if (mounted) {
        setState(() {
          _webPlaybackSnapshot = existingSession.snapshot;
          _webPlaybackError = null;
        });
      }
      return;
    }

    if (existingSession != null || existingCoordinator != null) {
      await _disposeWebPlayback(clearUri: false);
      if (!mounted || _isDisposing) return;
    }

    final generation = ++_webPlaybackGeneration;
    _webPlaybackAutoOpenSuppressed = false;
    setState(() {
      _webPlaybackUri = canonicalUri;
      _webPlaybackProvider = provider;
      _webPlaybackOpening = true;
      _webPlaybackSnapshot = null;
      _webPlaybackError = null;
    });

    try {
      final providerName = provider == WebPlaybackProvider.iqiyi
          ? '爱奇艺'
          : '腾讯视频';
      final session = await _webPlaybackClient.open(
        uri: canonicalUri,
        title: '$providerName · SyncTV',
      );
      if (!mounted ||
          _isDisposing ||
          generation != _webPlaybackGeneration) {
        await session.close();
        return;
      }

      _webPlaybackSession = session;
      _webPlaybackUpdatesSubscription = session.updates.listen(
        (update) {
          if (!mounted || !identical(session, _webPlaybackSession)) return;
          setState(() {
            _webPlaybackSnapshot = update.snapshot;
            _webPlaybackError = update.snapshot.errorMessage;
          });
        },
        onError: (Object error, StackTrace stackTrace) {
          _handleWebPlaybackError(error, stackTrace);
        },
      );
      final coordinator = WebPlaybackCoordinator(
        session: session,
        onLocalIntent: _handleWebPlaybackLocalIntent,
        onError: _handleWebPlaybackError,
      );
      _webPlaybackCoordinator = coordinator;
      unawaited(
        session.closed.then((_) => _handleWebPlaybackClosed(session)),
      );
      setState(() {
        _webPlaybackOpening = false;
        _webPlaybackSnapshot = session.snapshot;
      });
      if (applySync) {
        coordinator.updateAuthoritativeState(_webPlaybackTarget(status));
      }
    } on Object catch (error, stackTrace) {
      if (!mounted || generation != _webPlaybackGeneration) return;
      debugPrint('Open official web playback failed: $error\n$stackTrace');
      setState(() {
        _webPlaybackOpening = false;
        _webPlaybackError = error.toString();
      });
    }
  }

  Future<void> _disposeWebPlayback({bool clearUri = true}) async {
    _webPlaybackGeneration += 1;
    final subscription = _webPlaybackUpdatesSubscription;
    final coordinator = _webPlaybackCoordinator;
    final session = _webPlaybackSession;
    _webPlaybackUpdatesSubscription = null;
    _webPlaybackCoordinator = null;
    _webPlaybackSession = null;
    if (clearUri) {
      _webPlaybackUri = null;
      _webPlaybackProvider = null;
      _webPlaybackSnapshot = null;
      _webPlaybackError = null;
      _webPlaybackAutoOpenSuppressed = false;
    }
    await subscription?.cancel();
    if (coordinator != null) {
      await coordinator.close();
    } else {
      await session?.close();
    }
    if (mounted && !_isDisposing) setState(() {});
  }

  void _handleWebPlaybackClosed(WebPlaybackSession session) {
    if (!identical(session, _webPlaybackSession)) return;
    final coordinator = _webPlaybackCoordinator;
    _webPlaybackSession = null;
    _webPlaybackCoordinator = null;
    unawaited(_webPlaybackUpdatesSubscription?.cancel());
    _webPlaybackUpdatesSubscription = null;
    _webPlaybackAutoOpenSuppressed = true;
    if (coordinator != null) unawaited(coordinator.close());
    if (mounted && !_isDisposing) {
      setState(() {
        _webPlaybackOpening = false;
        _webPlaybackError = '官方网页播放器已关闭，可重新打开。';
      });
    }
  }

  void _handleWebPlaybackError(Object error, StackTrace stackTrace) {
    debugPrint('Official web playback error: $error\n$stackTrace');
    if (mounted && !_isDisposing) {
      setState(() => _webPlaybackError = error.toString());
    }
  }

  void _handleWebPlaybackLocalIntent(WebPlaybackLocalIntent intent) {
    if (!_canControlPlaybackState) return;
    switch (intent.type) {
      case WebPlaybackLocalIntentType.play:
        _handleUserPlaybackStateChanged(true);
      case WebPlaybackLocalIntentType.pause:
        _handleUserPlaybackStateChanged(false);
      case WebPlaybackLocalIntentType.seek:
        final seconds = intent.positionSeconds;
        if (seconds != null) {
          _handleUserSeek(
            Duration(milliseconds: (seconds * 1000).round()),
          );
        }
      case WebPlaybackLocalIntentType.rate:
        final rate = intent.playbackRate;
        if (rate != null) _handleUserPlaybackSpeedChanged(rate);
    }
  }

  WebPlaybackSyncTarget _webPlaybackTarget(SyncTvPlaybackStatus status) {
    var positionSeconds = status.derivedCurrentTime(now: SyncedClock.now());
    if (!positionSeconds.isFinite || positionSeconds < 0) positionSeconds = 0;
    positionSeconds = positionSeconds
        .clamp(0.0, WebPlaybackBridgeMessage.maxPositionSeconds)
        .toDouble();
    var playbackRate = status.playbackRate;
    if (!playbackRate.isFinite ||
        playbackRate < WebPlaybackBridgeMessage.minPlaybackRate ||
        playbackRate > WebPlaybackBridgeMessage.maxPlaybackRate) {
      playbackRate = 1;
    }
    return WebPlaybackSyncTarget(
      isPlaying: status.isPlaying,
      position: Duration(milliseconds: (positionSeconds * 1000).round()),
      playbackRate: playbackRate,
    );
  }

  List<int>? _buildWebPlaybackControlMessage(_PlaybackControlIntent intent) {
    final status = _currentStatus;
    if (status == null) return null;
    final snapshot = _webPlaybackSession?.snapshot ?? _webPlaybackSnapshot;
    final currentPosition = _boundedPlaybackTime(
      intent.position?.inMilliseconds.toDouble() == null
          ? snapshot?.positionSeconds ?? status.currentTime
          : intent.position!.inMilliseconds / 1000.0,
    );
    final isPlaying =
        intent.isPlaying ?? snapshot?.isPlaying ?? status.isPlaying;
    final playbackRate =
        intent.speed ?? snapshot?.playbackRate ?? status.playbackRate;
    final action = switch (intent.kind) {
      _PlaybackControlIntentKind.playbackState => isPlaying
          ? PlaybackControlAction.play
          : PlaybackControlAction.pause,
      _PlaybackControlIntentKind.seek => PlaybackControlAction.seek,
      _PlaybackControlIntentKind.speed => PlaybackControlAction.speed,
    };
    return _realtimeProtocol.encodeGuardedPlaybackStateUpdate(
      action,
      status,
      isPlaying: isPlaying,
      position: currentPosition,
      playbackRate: intent.kind == _PlaybackControlIntentKind.speed
          ? playbackRate
          : null,
      clientOperationId: intent.clientOperationId,
      clientTimeMillis: intent.clientTimeMillis,
    );
  }

  SyncTvPlaybackStatus? _optimisticWebPlaybackStatus(
    _PlaybackControlIntent intent,
  ) {
    final status = _currentStatus;
    if (status == null) return null;
    final snapshot = _webPlaybackSession?.snapshot ?? _webPlaybackSnapshot;
    final currentTime = intent.position == null
        ? snapshot?.positionSeconds ?? status.currentTime
        : intent.position!.inMilliseconds / 1000.0;
    return status.copyWith(
      isPlaying: intent.isPlaying ?? status.isPlaying,
      currentTime: _boundedPlaybackTime(currentTime),
      playbackRate:
          intent.speed ?? snapshot?.playbackRate ?? status.playbackRate,
      generatedAtMillis: intent.clientTimeMillis,
      clientOperationId: intent.clientOperationId,
    );
  }

  Future<void> _reopenWebPlayback() async {
    final status = _currentStatus;
    final rawUri = _webPlaybackUri ??
        Uri.tryParse(status?.entry?.url ?? '');
    if (status == null || rawUri == null) return;
    _webPlaybackAutoOpenSuppressed = false;
    await _applyWebPlaybackStatus(status, rawUri, applySync: true);
  }

  Widget _buildWebPlaybackState() {
    final providerName = _webPlaybackProvider == WebPlaybackProvider.iqiyi
        ? '爱奇艺'
        : '腾讯视频';
    final snapshot = _webPlaybackSnapshot;
    final phaseLabel = switch (snapshot?.phase) {
      WebPlaybackPhase.initializing || null => '正在初始化官方播放器',
      WebPlaybackPhase.advertisement => switch (snapshot?.advertisementKind) {
        WebPlaybackAdvertisementKind.preroll => '正在播放片头广告',
        WebPlaybackAdvertisementKind.midroll => '正在播放中插广告',
        WebPlaybackAdvertisementKind.pause => '暂停广告中',
        _ => '广告播放中',
      },
      WebPlaybackPhase.overlayAdvertisement => '内容播放中（覆盖广告）',
      WebPlaybackPhase.content => snapshot?.isPlaying == true ? '播放中' : '已暂停',
      WebPlaybackPhase.buffering => '缓冲中',
      WebPlaybackPhase.ended => '已播放结束',
      WebPlaybackPhase.unsupported => '当前页面播放器暂不可控制',
    };
    final session = _webPlaybackSession;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.open_in_new_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              '$providerName 官方网页同步播放',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(phaseLabel, textAlign: TextAlign.center),
            if (_webPlaybackError case final error?) ...[
              const SizedBox(height: 10),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            if (_webPlaybackOpening)
              const CircularProgressIndicator()
            else
              FilledButton.icon(
                onPressed: session != null
                    ? () => unawaited(session.bringToForeground())
                    : _webPlaybackClient.supported
                    ? () => unawaited(_reopenWebPlayback())
                    : null,
                icon: Icon(
                  session == null
                      ? Icons.refresh_rounded
                      : Icons.open_in_new_rounded,
                ),
                label: Text(session == null ? '重新打开官方播放器' : '切回官方播放器'),
              ),
            const SizedBox(height: 12),
            const Text(
              '登录和会员状态仅保存在本机官方网页环境中；SyncTV 不读取或同步 Cookie、凭证或 DRM 信息。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

'''
insert_before(room, "  double _boundedPlaybackTime(double currentTime) {\n", web_helpers)

replace_once(
    room,
    "  List<int>? _buildPlaybackControlMessage(_PlaybackControlIntent intent) {\n    final value = _videoPlayerController?.value;\n",
    "  List<int>? _buildPlaybackControlMessage(_PlaybackControlIntent intent) {\n"
    "    if (_webPlaybackSession != null) {\n"
    "      return _buildWebPlaybackControlMessage(intent);\n"
    "    }\n"
    "    final value = _videoPlayerController?.value;\n",
)
replace_once(
    room,
    "    final status = _currentStatus;\n    final value = _videoPlayerController?.value;\n    if (status == null || value == null) return null;\n",
    "    final status = _currentStatus;\n"
    "    if (_webPlaybackSession != null) {\n"
    "      return _optimisticWebPlaybackStatus(intent);\n"
    "    }\n"
    "    final value = _videoPlayerController?.value;\n"
    "    if (status == null || value == null) return null;\n",
)
replace_once(
    room,
    "    final previousEntry = previousStatus?.entry;\n    final nextEntry = status.entry;\n    final generationChanged = liveStreamGenerationChanged(\n",
    "    final previousEntry = previousStatus?.entry;\n"
    "    final nextEntry = status.entry;\n"
    "    final rawWebPlaybackUri = nextEntry?.url.isNotEmpty == true\n"
    "        ? Uri.tryParse(nextEntry!.url)\n"
    "        : null;\n"
    "    final webPlaybackAdapter = rawWebPlaybackUri == null\n"
    "        ? null\n"
    "        : WebPlaybackAdapterRegistry.standard.forMediaUri(\n"
    "            rawWebPlaybackUri,\n"
    "          );\n"
    "    final generationChanged = liveStreamGenerationChanged(\n",
)
replace_once(
    room,
    "    final canPlayEntry =\n        nextEntry != null &&\n",
    "    if (webPlaybackAdapter != null && rawWebPlaybackUri != null) {\n"
    "      setState(() {\n"
    "        _currentStatus = status;\n"
    "        _videoInitialization.invalidate();\n"
    "        _isVideoLoading = false;\n"
    "        _videoError = null;\n"
    "      });\n"
    "      _cancelEndedLiveStreamDrain();\n"
    "      _disposeVideoControllerImmediately();\n"
    "      await _deactivateP2pResources();\n"
    "      if (!mounted || _isDisposing) return;\n"
    "      await _applyWebPlaybackStatus(\n"
    "        status,\n"
    "        rawWebPlaybackUri,\n"
    "        applySync: !skipPlayerSync,\n"
    "      );\n"
    "      return;\n"
    "    }\n"
    "    if (_webPlaybackUri != null ||\n"
    "        _webPlaybackSession != null ||\n"
    "        _webPlaybackOpening) {\n"
    "      await _disposeWebPlayback();\n"
    "      if (!mounted || _isDisposing) return;\n"
    "    }\n\n"
    "    final canPlayEntry =\n"
    "        nextEntry != null &&\n",
)
replace_once(
    room,
    "  Widget _buildVideoEmptyState() {\n    final entry = _currentStatus?.entry;\n",
    "  Widget _buildVideoEmptyState() {\n"
    "    if (_webPlaybackUri != null) return _buildWebPlaybackState();\n"
    "    final entry = _currentStatus?.entry;\n",
)
replace_once(
    room,
    "  String _playlistProviderLabel(RoomMediaEntry entry) {\n    final sourceProvider = SourceConfigCodec.providerToString(\n",
    "  String _playlistProviderLabel(RoomMediaEntry entry) {\n"
    "    final webUri = Uri.tryParse(entry.url);\n"
    "    final webAdapter = webUri == null\n"
    "        ? null\n"
    "        : WebPlaybackAdapterRegistry.standard.forMediaUri(webUri);\n"
    "    if (webAdapter != null) {\n"
    "      return webAdapter.provider == WebPlaybackProvider.iqiyi\n"
    "          ? '爱奇艺'\n"
    "          : '腾讯视频';\n"
    "    }\n"
    "    final sourceProvider = SourceConfigCodec.providerToString(\n",
)

print('web playback integration patches applied')
