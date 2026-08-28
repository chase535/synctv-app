// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synctv_app/features/room/application/web_playback_client.dart';
import 'package:synctv_app/features/room/domain/web_playback_adapter.dart';
import 'package:synctv_app/features/room/domain/web_playback_adapter_registry.dart';
import 'package:synctv_app/features/room/domain/web_playback_bridge_message.dart';
import 'package:synctv_app/features/room/domain/web_playback_bridge_script.dart';
import 'package:synctv_app/features/room/domain/web_playback_command.dart';
import 'package:synctv_app/features/room/domain/web_playback_media_identity.dart';
import 'package:synctv_app/features/room/domain/web_playback_navigation.dart';
import 'package:synctv_app/features/room/domain/web_playback_phase.dart';
import 'package:synctv_app/features/room/domain/web_playback_runtime.dart';
import 'package:synctv_app/features/room/domain/web_playback_sync_gate.dart';

final class NativeDesktopWebPlaybackClient implements WebPlaybackClient {
  const NativeDesktopWebPlaybackClient();

  @override
  bool get supported => Platform.isWindows;

  @override
  Future<WebPlaybackSession> open({
    required Uri uri,
    required String title,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'Official-site web playback currently requires Windows WebView2',
      );
    }
    final adapter = WebPlaybackAdapterRegistry.standard.forMediaUri(uri);
    if (adapter == null) {
      throw ArgumentError.value(
        uri,
        'uri',
        'Unsupported official playback URL',
      );
    }
    if (!await WebviewWindow.isWebviewAvailable()) {
      throw UnsupportedError(
        'WebView2 Runtime is required for iQIYI and Tencent Video playback',
      );
    }

    final appDirectory = await getApplicationSupportDirectory();
    final profileDirectory = [
      appDirectory.path,
      'web_playback',
      adapter.provider.name,
    ].join(Platform.pathSeparator);
    final webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        title: title,
        windowWidth: 1280,
        windowHeight: 800,
        openMaximized: true,
        userDataFolderWindows: profileDirectory,
      ),
    );
    final session = _WindowsWebPlaybackSession(
      webview: webview,
      adapter: adapter,
      bridgeToken: _createBridgeToken(),
    );
    try {
      session.initialize(uri);
      return session;
    } on Object {
      webview.close();
      rethrow;
    }
  }

  static String _createBridgeToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }
}

final class _WindowsWebPlaybackSession implements WebPlaybackSession {
  _WindowsWebPlaybackSession({
    required Webview webview,
    required WebPlaybackAdapter adapter,
    required String bridgeToken,
  }) : _webview = webview,
       _adapter = adapter,
       _bridgeToken = bridgeToken,
       _runtime = WebPlaybackRuntime(bridgeToken: bridgeToken);

  final Webview _webview;
  final WebPlaybackAdapter _adapter;
  final String _bridgeToken;
  final WebPlaybackRuntime _runtime;
  final StreamController<WebPlaybackRuntimeUpdate> _updates =
      StreamController<WebPlaybackRuntimeUpdate>.broadcast(sync: true);
  final Completer<void> _closedCompleter = Completer<void>();

  Uri? _currentUri;
  WebPlaybackMediaIdentity? _expectedMediaIdentity;
  Future<void> _webMessageTail = Future<void>.value();
  int _navigationGeneration = 0;
  bool _closed = false;

  void initialize(Uri uri) {
    _expectedMediaIdentity = _requireRoomMediaIdentity(uri);
    _currentUri = uri;
    _webview.addScriptToExecuteOnDocumentCreated(
      webPlaybackBridgeBootstrapScript,
    );
    _webview.setOnUrlRequestCallback(_onUrlRequest);
    _webview.addOnWebMessageReceivedCallback(_onWebMessage);
    _webview.isNavigating.addListener(_onNavigationChanged);
    unawaited(_webview.onClose.then((_) => _finishClosed()));
    _runtime.resetForNavigation();
    _navigationGeneration += 1;
    _webview.launch(uri.toString());
  }

  @override
  Stream<WebPlaybackRuntimeUpdate> get updates => _updates.stream;

  @override
  Future<void> get closed => _closedCompleter.future;

  @override
  Uri? get currentUri => _currentUri;

  @override
  WebPlaybackSnapshot get snapshot => _runtime.snapshot;

  @override
  WebPlaybackSyncTarget? submitSyncTarget(WebPlaybackSyncTarget target) =>
      _runtime.submitSyncTarget(target);

  @override
  Future<bool> execute(WebPlaybackCommand command) async {
    _throwIfClosed();
    final uri = _currentUri;
    if (uri == null || !_adapter.sitePolicy.allows(uri)) return false;
    if (!await _pageMatchesExpectedMedia()) return false;
    _runtime.rememberCommand(command);
    final result = await _webview.evaluateJavaScript(
      buildWebPlaybackCommandScript(command),
    );
    return _parseJavaScriptBoolean(result);
  }

  @override
  Future<WebPlaybackSnapshot?> readSnapshot() async {
    _throwIfClosed();
    final uri = _currentUri;
    if (uri == null || !_adapter.sitePolicy.allows(uri)) return null;
    if (!await _pageMatchesExpectedMedia()) return null;

    final result = await _webview.evaluateJavaScript(
      'JSON.stringify(window.__synctvPlaybackBridge?.snapshot() ?? null);',
    );
    return _decodeSnapshot(result);
  }

  @override
  Future<void> navigate(Uri uri) async {
    _throwIfClosed();
    final identity = _requireRoomMediaIdentity(uri);
    if (_currentUri == uri &&
        _expectedMediaIdentity?.isSameEpisodeAs(identity) == true) {
      await bringToForeground();
      return;
    }
    _expectedMediaIdentity = identity;
    _currentUri = uri;
    _runtime.resetForNavigation();
    _navigationGeneration += 1;
    _webview.launch(uri.toString());
  }

  @override
  Future<void> bringToForeground() async {
    _throwIfClosed();
    await _webview.bringToForeground(maximized: true);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _webview.close();
    await _webview.onClose;
  }

  bool _onUrlRequest(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return false;
    final disposition = _adapter.classifyNavigation(uri, isMainFrame: true);
    if (!disposition.isAllowed) return false;
    if (disposition.canUseBridge && !_matchesExpectedMedia(uri)) return false;

    if (_currentUri != uri) {
      _currentUri = uri;
      _runtime.resetForNavigation();
      _navigationGeneration += 1;
    }
    return true;
  }

  void _onNavigationChanged() {
    if (_closed || _webview.isNavigating.value) return;
    unawaited(_configureBridgeForCurrentPage());
  }

  Future<void> _configureBridgeForCurrentPage() async {
    final generation = _navigationGeneration;
    final uri = _currentUri;
    if (uri == null || !_adapter.sitePolicy.allows(uri) || _closed) return;

    try {
      if (!await _pageMatchesExpectedMedia()) return;
      if (_closed || generation != _navigationGeneration) return;
      await _webview.evaluateJavaScript(webPlaybackBridgeBootstrapScript);
      if (_closed || generation != _navigationGeneration) return;
      if (!await _pageMatchesExpectedMedia()) return;
      await _webview.evaluateJavaScript(
        buildWebPlaybackBridgeStartScript(
          bridgeToken: _bridgeToken,
          transportFunctionExpression:
              '(message) => window.chrome.webview.postMessage(message)',
          phaseDetectorFunctionExpression:
              _adapter.phaseDetectorFunctionExpression,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (!_closed) _updates.addError(error, stackTrace);
    }
  }

  void _onWebMessage(String raw) {
    if (_closed) return;
    _webMessageTail = _webMessageTail.then((_) => _handleWebMessage(raw));
  }

  Future<void> _handleWebMessage(String raw) async {
    if (_closed) return;
    try {
      if (!await _pageMatchesExpectedMedia()) return;
      if (_closed) return;
      final update = _runtime.handleRawMessage(raw);
      if (update != null) _updates.add(update);
    } on Object catch (error, stackTrace) {
      if (!_closed) _updates.addError(error, stackTrace);
    }
  }

  WebPlaybackMediaIdentity _requireRoomMediaIdentity(Uri uri) {
    final disposition = _adapter.classifyNavigation(uri, isMainFrame: true);
    final identity = WebPlaybackMediaIdentity.tryParse(uri);
    if (!disposition.canUseBridge ||
        identity == null ||
        !identity.isEpisode ||
        identity.provider != _adapter.provider) {
      throw ArgumentError.value(
        uri,
        'uri',
        'Web playback navigation must target a supported room media episode',
      );
    }
    return identity;
  }

  bool _matchesExpectedMedia(Uri uri) {
    final expected = _expectedMediaIdentity;
    final candidate = WebPlaybackMediaIdentity.tryParse(uri);
    return expected != null &&
        candidate != null &&
        candidate.isSameEpisodeAs(expected);
  }

  Future<bool> _pageMatchesExpectedMedia() async {
    if (_closed) return false;
    final result = await _webview.evaluateJavaScript('window.location.href');
    final rawUrl = _parseJavaScriptString(result);
    final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (uri == null || !_matchesExpectedMedia(uri)) return false;
    _currentUri = uri;
    return true;
  }

  void _throwIfClosed() {
    if (_closed) throw StateError('Web playback session is already closed');
  }

  void _finishClosed() {
    if (_closed) return;
    _closed = true;
    _webview.isNavigating.removeListener(_onNavigationChanged);
    _webview.setOnUrlRequestCallback(null);
    _webview.removeAllWebMessageReceivedCallback();
    if (!_closedCompleter.isCompleted) _closedCompleter.complete();
    unawaited(_updates.close());
  }

  static bool _parseJavaScriptBoolean(String? result) {
    if (result == null) return false;
    if (result == 'true') return true;
    try {
      final decoded = jsonDecode(result);
      if (decoded is bool) return decoded;
      if (decoded is String) return decoded == 'true';
    } on FormatException {
      return false;
    }
    return false;
  }

  static String? _parseJavaScriptString(String? result) {
    if (result == null || result.isEmpty || result == 'null') return null;
    try {
      final decoded = jsonDecode(result);
      if (decoded is String) return decoded;
    } on FormatException {
      if (Uri.tryParse(result)?.hasScheme == true) return result;
    }
    return null;
  }

  WebPlaybackSnapshot? _decodeSnapshot(String? result) {
    if (result == null || result.isEmpty || result == 'null') return null;
    dynamic decoded;
    try {
      decoded = jsonDecode(result);
      if (decoded is String) decoded = jsonDecode(decoded);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;

    final phase = _parsePhase(decoded['phase']);
    if (phase == null) return null;
    final position = decoded['position'];
    final playbackRate = decoded['playbackRate'];
    if (position is! num || playbackRate is! num) return null;
    final positionSeconds = position.toDouble();
    final rate = playbackRate.toDouble();
    if (!positionSeconds.isFinite ||
        positionSeconds < 0 ||
        positionSeconds > WebPlaybackBridgeMessage.maxPositionSeconds ||
        !rate.isFinite ||
        rate < WebPlaybackBridgeMessage.minPlaybackRate ||
        rate > WebPlaybackBridgeMessage.maxPlaybackRate) {
      return null;
    }

    return WebPlaybackSnapshot(
      ready: decoded['ready'] == true,
      phase: phase,
      advertisementKind: _parseAdvertisementKind(decoded['adKind'], phase),
      isPlaying: decoded['isPlaying'] == true,
      positionSeconds: positionSeconds,
      playbackRate: rate,
      errorMessage: _runtime.snapshot.errorMessage,
    );
  }

  static WebPlaybackPhase? _parsePhase(Object? value) => switch (value) {
    'initializing' => WebPlaybackPhase.initializing,
    'advertisement' => WebPlaybackPhase.advertisement,
    'overlayAdvertisement' => WebPlaybackPhase.overlayAdvertisement,
    'content' => WebPlaybackPhase.content,
    'buffering' => WebPlaybackPhase.buffering,
    'ended' => WebPlaybackPhase.ended,
    'unsupported' => WebPlaybackPhase.unsupported,
    _ => null,
  };

  static WebPlaybackAdvertisementKind? _parseAdvertisementKind(
    Object? value,
    WebPlaybackPhase phase,
  ) {
    if (!phase.isAdvertisement) return null;
    return switch (value) {
      'preroll' => WebPlaybackAdvertisementKind.preroll,
      'midroll' => WebPlaybackAdvertisementKind.midroll,
      'pause' => WebPlaybackAdvertisementKind.pause,
      'overlay' => WebPlaybackAdvertisementKind.overlay,
      _ =>
        phase == WebPlaybackPhase.overlayAdvertisement
            ? WebPlaybackAdvertisementKind.overlay
            : WebPlaybackAdvertisementKind.unknown,
    };
  }
}
