// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:synctv_app/features/room/application/web_playback_client.dart';
import 'package:synctv_app/features/room/application/web_playback_coordinator.dart';
import 'package:synctv_app/features/room/domain/web_playback_command.dart';
import 'package:synctv_app/features/room/domain/web_playback_event_router.dart';
import 'package:synctv_app/features/room/domain/web_playback_phase.dart';
import 'package:synctv_app/features/room/domain/web_playback_runtime.dart';
import 'package:synctv_app/features/room/domain/web_playback_sync_gate.dart';

void main() {
  test('applies remote state in pause seek rate play order', () async {
    final session = _FakeWebPlaybackSession(
      snapshot: const WebPlaybackSnapshot(
        ready: true,
        phase: WebPlaybackPhase.content,
        isPlaying: true,
        positionSeconds: 2,
        playbackRate: 1,
      ),
    );
    final coordinator = WebPlaybackCoordinator(
      session: session,
      onLocalIntent: (_) {},
      correctionInterval: const Duration(hours: 1),
      random: Random(1),
    );

    coordinator.updateAuthoritativeState(
      const WebPlaybackSyncTarget(
        isPlaying: true,
        position: Duration(seconds: 20),
        playbackRate: 1.5,
      ),
    );
    await _settle();

    expect(session.commands.map((command) => command.type), [
      WebPlaybackCommandType.pause,
      WebPlaybackCommandType.seek,
      WebPlaybackCommandType.rate,
      WebPlaybackCommandType.play,
    ]);
    expect(session.commands[1].positionSeconds, closeTo(20, 0.05));
    expect(session.commands[2].playbackRate, 1.5);
    await coordinator.close();
  });

  test('blocking advertisement releases latest time-adjusted target', () async {
    var now = DateTime.utc(2026, 8, 28, 12);
    final session = _FakeWebPlaybackSession(
      snapshot: const WebPlaybackSnapshot(
        ready: true,
        phase: WebPlaybackPhase.advertisement,
        advertisementKind: WebPlaybackAdvertisementKind.preroll,
        isPlaying: false,
      ),
    );
    final coordinator = WebPlaybackCoordinator(
      session: session,
      onLocalIntent: (_) {},
      correctionInterval: const Duration(hours: 1),
      clock: () => now,
      random: Random(2),
    );

    coordinator.updateAuthoritativeState(
      const WebPlaybackSyncTarget(
        isPlaying: true,
        position: Duration(seconds: 30),
        playbackRate: 1,
      ),
    );
    expect(session.commands, isEmpty);
    final pending = session.pendingTarget;
    expect(pending, isNotNull);

    now = now.add(const Duration(seconds: 7));
    const contentSnapshot = WebPlaybackSnapshot(
      ready: true,
      phase: WebPlaybackPhase.content,
      isPlaying: false,
      positionSeconds: 0,
      playbackRate: 1,
    );
    session.emit(
      WebPlaybackRuntimeUpdate(
        snapshot: contentSnapshot,
        releasedSyncTarget: pending,
      ),
    );
    await _settle();

    final seek = session.commands.firstWhere(
      (command) => command.type == WebPlaybackCommandType.seek,
    );
    expect(seek.positionSeconds, closeTo(37, 0.05));
    expect(session.commands.last.type, WebPlaybackCommandType.play);
    await coordinator.close();
  });

  test('overlay advertisement keeps content timeline available', () async {
    final session = _FakeWebPlaybackSession(
      snapshot: const WebPlaybackSnapshot(
        ready: true,
        phase: WebPlaybackPhase.overlayAdvertisement,
        advertisementKind: WebPlaybackAdvertisementKind.overlay,
        isPlaying: false,
        positionSeconds: 4,
      ),
    );
    final coordinator = WebPlaybackCoordinator(
      session: session,
      onLocalIntent: (_) {},
      correctionInterval: const Duration(hours: 1),
      random: Random(3),
    );

    coordinator.updateAuthoritativeState(
      const WebPlaybackSyncTarget(
        isPlaying: true,
        position: Duration(seconds: 9),
        playbackRate: 1,
      ),
    );
    await _settle();

    expect(
      session.commands.any((c) => c.type == WebPlaybackCommandType.seek),
      isTrue,
    );
    expect(session.commands.last.type, WebPlaybackCommandType.play);
    await coordinator.close();
  });

  test('local intent grace prevents stale authoritative snap-back', () async {
    var now = DateTime.utc(2026, 8, 28, 12);
    final session = _FakeWebPlaybackSession(
      snapshot: const WebPlaybackSnapshot(
        ready: true,
        phase: WebPlaybackPhase.content,
        isPlaying: false,
        positionSeconds: 12,
        playbackRate: 1,
      ),
    );
    final localIntents = <WebPlaybackLocalIntent>[];
    final coordinator = WebPlaybackCoordinator(
      session: session,
      onLocalIntent: localIntents.add,
      correctionInterval: const Duration(milliseconds: 15),
      localIntentGracePeriod: const Duration(seconds: 2),
      clock: () => now,
      random: Random(4),
    );

    session.emit(
      const WebPlaybackRuntimeUpdate(
        snapshot: WebPlaybackSnapshot(
          ready: true,
          phase: WebPlaybackPhase.content,
          isPlaying: false,
          positionSeconds: 12,
          playbackRate: 1,
        ),
        localIntent: WebPlaybackLocalIntent(
          type: WebPlaybackLocalIntentType.pause,
        ),
      ),
    );
    coordinator.updateAuthoritativeState(
      const WebPlaybackSyncTarget(
        isPlaying: true,
        position: Duration(seconds: 12),
        playbackRate: 1,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(localIntents, hasLength(1));
    expect(session.commands, isEmpty);

    now = now.add(const Duration(seconds: 3));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(session.commands.last.type, WebPlaybackCommandType.play);
    await coordinator.close();
  });
  test('close suppresses failures from in-flight correction', () async {
    final session = _FakeWebPlaybackSession(
      snapshot: const WebPlaybackSnapshot(
        ready: true,
        phase: WebPlaybackPhase.content,
        isPlaying: false,
        positionSeconds: 3,
        playbackRate: 1,
      ),
    );
    final readStarted = Completer<void>();
    final pendingRead = Completer<WebPlaybackSnapshot?>();
    session
      ..readSnapshotStarted = readStarted
      ..readSnapshotCompleter = pendingRead;
    final errors = <Object>[];
    final coordinator = WebPlaybackCoordinator(
      session: session,
      onLocalIntent: (_) {},
      onError: (error, _) => errors.add(error),
      correctionInterval: const Duration(hours: 1),
      random: Random(5),
    );

    coordinator.updateAuthoritativeState(
      const WebPlaybackSyncTarget(
        isPlaying: true,
        position: Duration(seconds: 20),
        playbackRate: 1,
      ),
    );
    await readStarted.future;
    final closeFuture = coordinator.close();
    pendingRead.completeError(StateError('session closed'));
    await closeFuture;
    await _settle();

    expect(errors, isEmpty);
    expect(session.commands, isEmpty);
  });
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 30));

final class _FakeWebPlaybackSession implements WebPlaybackSession {
  _FakeWebPlaybackSession({required WebPlaybackSnapshot snapshot})
    : _snapshot = snapshot;

  final StreamController<WebPlaybackRuntimeUpdate> _updates =
      StreamController<WebPlaybackRuntimeUpdate>.broadcast(sync: true);
  final Completer<void> _closed = Completer<void>();
  final List<WebPlaybackCommand> commands = [];

  Completer<void>? readSnapshotStarted;
  Completer<WebPlaybackSnapshot?>? readSnapshotCompleter;
  WebPlaybackSnapshot _snapshot;
  WebPlaybackSyncTarget? pendingTarget;
  Uri? _currentUri = Uri.parse('https://www.iqiyi.com/v_test.html');

  void emit(WebPlaybackRuntimeUpdate update) {
    _snapshot = update.snapshot;
    if (update.releasedSyncTarget != null) pendingTarget = null;
    _updates.add(update);
  }

  @override
  Stream<WebPlaybackRuntimeUpdate> get updates => _updates.stream;

  @override
  Future<void> get closed => _closed.future;

  @override
  Uri? get currentUri => _currentUri;

  @override
  WebPlaybackSnapshot get snapshot => _snapshot;

  @override
  WebPlaybackSyncTarget? submitSyncTarget(WebPlaybackSyncTarget target) {
    if (!_snapshot.phase.hasContentTimeline) {
      pendingTarget = target;
      return null;
    }
    return target;
  }

  @override
  Future<bool> execute(WebPlaybackCommand command) async {
    commands.add(command);
    switch (command.type) {
      case WebPlaybackCommandType.play:
        _snapshot = _copySnapshot(isPlaying: true);
      case WebPlaybackCommandType.pause:
        _snapshot = _copySnapshot(isPlaying: false);
      case WebPlaybackCommandType.seek:
        _snapshot = _copySnapshot(positionSeconds: command.positionSeconds);
      case WebPlaybackCommandType.rate:
        _snapshot = _copySnapshot(playbackRate: command.playbackRate);
    }
    return true;
  }

  @override
  Future<WebPlaybackSnapshot?> readSnapshot() async {
    final started = readSnapshotStarted;
    if (started != null && !started.isCompleted) started.complete();
    final pending = readSnapshotCompleter;
    if (pending != null) return pending.future;
    return _snapshot;
  }

  @override
  Future<void> navigate(Uri uri) async {
    _currentUri = uri;
  }

  @override
  Future<void> bringToForeground() async {}

  @override
  Future<void> close() async {
    if (!_closed.isCompleted) _closed.complete();
    await _updates.close();
  }

  WebPlaybackSnapshot _copySnapshot({
    bool? isPlaying,
    double? positionSeconds,
    double? playbackRate,
  }) => WebPlaybackSnapshot(
    ready: _snapshot.ready,
    phase: _snapshot.phase,
    advertisementKind: _snapshot.advertisementKind,
    isPlaying: isPlaying ?? _snapshot.isPlaying,
    positionSeconds: positionSeconds ?? _snapshot.positionSeconds,
    playbackRate: playbackRate ?? _snapshot.playbackRate,
    errorMessage: _snapshot.errorMessage,
  );
}
