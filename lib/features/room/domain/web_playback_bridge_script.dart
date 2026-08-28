import 'dart:convert';

import 'package:synctv_app/features/room/domain/web_playback_bridge_message.dart';
import 'package:synctv_app/features/room/domain/web_playback_command.dart';

const String webPlaybackBridgeBootstrapScript = r'''(() => {
  const VERSION = 1;
  const PRIVILEGED_ORIGINS = new Set([
    'https://www.iqiyi.com',
    'https://v.qq.com',
  ]);
  if (
    window.top !== window.self ||
    !PRIVILEGED_ORIGINS.has(window.location.origin)
  ) {
    return;
  }

  const existing = window.__synctvPlaybackBridge;
  if (existing && existing.version === VERSION) return;

  const MAX_MESSAGE_LENGTH = 16 * 1024;
  const MIN_SESSION_TOKEN_LENGTH = 32;
  const MAX_SESSION_TOKEN_LENGTH = 128;
  const MAX_COMMAND_ID_LENGTH = 128;
  const MAX_ERROR_LENGTH = 1024;
  const MAX_POSITION = 604800;
  const MIN_RATE = 0.1;
  const MAX_RATE = 16;
  const USER_GESTURE_WINDOW_MS = 1200;
  const COMMAND_TTL_MS = 5000;
  const VALID_PHASES = new Set([
    'initializing',
    'advertisement',
    'overlayAdvertisement',
    'content',
    'buffering',
    'ended',
    'unsupported',
  ]);
  const VALID_AD_KINDS = new Set([
    'unknown',
    'preroll',
    'midroll',
    'pause',
    'overlay',
  ]);

  let sessionToken = null;
  let transport = null;
  const queuedMessages = [];
  let activeVideo = null;
  let phase = 'initializing';
  let advertisementKind = null;
  let phaseDetector = null;
  let refreshScheduled = false;
  let observer = null;
  let refreshTimer = null;
  let started = false;
  const pendingCommands = new Map();
  let lastUserGesture = {
    at: 0,
    target: null,
    x: null,
    y: null,
    key: '',
    type: '',
    consumed: true,
  };

  function now() {
    return Date.now();
  }

  function finiteNumber(value) {
    return typeof value === 'number' && Number.isFinite(value);
  }

  function clampText(value, maxLength) {
    const text = String(value == null ? '' : value);
    if (text.length <= maxLength) return text;
    return text.slice(0, maxLength);
  }

  function validSessionToken(value) {
    return (
      typeof value === 'string' &&
      value.length >= MIN_SESSION_TOKEN_LENGTH &&
      value.length <= MAX_SESSION_TOKEN_LENGTH
    );
  }

  function setSessionToken(nextToken) {
    if (!validSessionToken(nextToken)) return false;
    if (sessionToken !== null) return sessionToken === nextToken;
    sessionToken = nextToken;
    queuedMessages.length = 0;
    pendingCommands.clear();
    return true;
  }

  function post(payload) {
    if (!sessionToken) return;
    const envelope = Object.assign(
      { version: VERSION, source: 'page', token: sessionToken },
      payload,
    );
    let raw;
    try {
      raw = JSON.stringify(envelope);
    } catch (_) {
      return;
    }
    if (raw.length > MAX_MESSAGE_LENGTH) return;

    if (transport) {
      try {
        transport(raw);
        return;
      } catch (_) {
        transport = null;
      }
    }

    if (queuedMessages.length >= 32) queuedMessages.shift();
    queuedMessages.push(raw);
  }

  function setTransport(nextTransport) {
    if (typeof nextTransport !== 'function') return false;
    transport = nextTransport;
    while (queuedMessages.length > 0) {
      const raw = queuedMessages.shift();
      try {
        transport(raw);
      } catch (_) {
        queuedMessages.unshift(raw);
        transport = null;
        return false;
      }
    }
    return true;
  }

  function gestureCoordinates(event) {
    if (finiteNumber(event && event.clientX) && finiteNumber(event && event.clientY)) {
      return { x: event.clientX, y: event.clientY };
    }
    const touch =
      event && event.changedTouches && event.changedTouches.length > 0
        ? event.changedTouches[0]
        : event && event.touches && event.touches.length > 0
          ? event.touches[0]
          : null;
    if (touch && finiteNumber(touch.clientX) && finiteNumber(touch.clientY)) {
      return { x: touch.clientX, y: touch.clientY };
    }
    return { x: null, y: null };
  }

  function rememberUserGesture(event) {
    if (event && event.isTrusted === false) return;
    const coordinates = gestureCoordinates(event);
    lastUserGesture = {
      at: now(),
      target: event ? event.target : null,
      x: coordinates.x,
      y: coordinates.y,
      key: event && typeof event.key === 'string' ? event.key : '',
      type: event && typeof event.type === 'string' ? event.type : '',
      consumed: false,
    };
  }

  document.addEventListener('pointerdown', rememberUserGesture, true);
  document.addEventListener('touchstart', rememberUserGesture, true);
  document.addEventListener('keydown', rememberUserGesture, true);

  function gestureTargetsActivePlayer() {
    if (!activeVideo) return false;
    if (now() - lastUserGesture.at > USER_GESTURE_WINDOW_MS) return false;
    if (lastUserGesture.consumed) return false;

    if (lastUserGesture.type === 'keydown') {
      const key = lastUserGesture.key.toLowerCase();
      if (
        key === ' ' ||
        key === 'enter' ||
        key === 'arrowleft' ||
        key === 'arrowright' ||
        key === 'arrowup' ||
        key === 'arrowdown' ||
        key === 'j' ||
        key === 'k' ||
        key === 'l'
      ) {
        return activeVideo.ownerDocument === document;
      }
      return false;
    }

    try {
      const rect = activeVideo.getBoundingClientRect();
      if (finiteNumber(lastUserGesture.x) && finiteNumber(lastUserGesture.y)) {
        const margin = 80;
        if (
          lastUserGesture.x >= rect.left - margin &&
          lastUserGesture.x <= rect.right + margin &&
          lastUserGesture.y >= rect.top - margin &&
          lastUserGesture.y <= rect.bottom + margin
        ) {
          return true;
        }
      }
    } catch (_) {
      // Fall through to the DOM ancestry check.
    }

    let node = lastUserGesture.target;
    for (let depth = 0; node && depth < 5; depth += 1) {
      if (node === document.body || node === document.documentElement) break;
      try {
        if (node.contains && node.contains(activeVideo)) return true;
      } catch (_) {
        return false;
      }
      node = node.parentElement;
    }
    return false;
  }

  function removeExpiredCommands() {
    const timestamp = now();
    for (const [type, pending] of pendingCommands.entries()) {
      if (pending.expiresAt < timestamp) pendingCommands.delete(type);
    }
  }

  function rememberCommand(type, commandId) {
    removeExpiredCommands();
    pendingCommands.set(type, {
      id: commandId,
      expiresAt: now() + COMMAND_TTL_MS,
    });
  }

  function sourceForControl(type) {
    removeExpiredCommands();
    const pending = pendingCommands.get(type);
    if (pending) {
      pendingCommands.delete(type);
      return { source: 'command', commandId: pending.id };
    }
    if (gestureTargetsActivePlayer()) {
      lastUserGesture.consumed = true;
      return { source: 'user' };
    }
    return { source: 'page' };
  }

  function phasePayload() {
    if (phase === 'advertisement' || phase === 'overlayAdvertisement') {
      return { phase, adKind: advertisementKind || 'unknown' };
    }
    return { phase };
  }

  function emitControl(type, extra) {
    const payload = Object.assign(
      { type },
      sourceForControl(type),
      phasePayload(),
      extra || {},
    );
    post(payload);
  }

  function acknowledgeIfPending(type, commandId, extra) {
    const pending = pendingCommands.get(type);
    if (!pending || pending.id !== commandId) return;
    pendingCommands.delete(type);
    post(
      Object.assign(
        { type, source: 'command', commandId },
        phasePayload(),
        extra || {},
      ),
    );
  }

  function emitCommandError(commandId, error) {
    if (typeof commandId !== 'string' || commandId.length === 0) return;
    if (commandId.length > MAX_COMMAND_ID_LENGTH) return;
    post(
      Object.assign(
        {
          type: 'error',
          source: 'command',
          commandId,
          error: clampText(error, MAX_ERROR_LENGTH) || 'Playback command failed',
        },
        phasePayload(),
      ),
    );
  }

  function collectVideos(rootDocument, result, visitedDocuments) {
    if (!rootDocument || visitedDocuments.has(rootDocument)) return;
    visitedDocuments.add(rootDocument);

    try {
      for (const video of rootDocument.querySelectorAll('video')) {
        result.push(video);
      }
      for (const frame of rootDocument.querySelectorAll('iframe')) {
        try {
          if (frame.contentDocument) {
            collectVideos(frame.contentDocument, result, visitedDocuments);
          }
        } catch (_) {
          // Cross-origin frames are intentionally ignored.
        }
      }
    } catch (_) {
      // A detached document may become inaccessible during SPA navigation.
    }
  }

  function scoreVideo(video) {
    try {
      const rect = video.getBoundingClientRect();
      const style = video.ownerDocument.defaultView.getComputedStyle(video);
      if (
        style.display === 'none' ||
        style.visibility === 'hidden' ||
        Number(style.opacity) === 0
      ) {
        return Number.NEGATIVE_INFINITY;
      }
      const area = Math.max(0, rect.width) * Math.max(0, rect.height);
      if (area <= 0) return Number.NEGATIVE_INFINITY;
      let score = area;
      if (!video.paused && !video.ended) score += 1e9;
      if (video.readyState >= 2) score += 1e7;
      if (video.currentSrc) score += 1e6;
      return score;
    } catch (_) {
      return Number.NEGATIVE_INFINITY;
    }
  }

  function findBestVideo() {
    const videos = [];
    collectVideos(document, videos, new Set());
    let best = null;
    let bestScore = Number.NEGATIVE_INFINITY;
    for (const video of videos) {
      const score = scoreVideo(video);
      if (score > bestScore) {
        best = video;
        bestScore = score;
      }
    }
    return best;
  }

  function fallbackPhaseForVideo(video) {
    if (!video) return 'initializing';
    if (video.ended) return 'ended';
    if (video.readyState < 1) return 'initializing';
    if (video.readyState < 3 && !video.paused) return 'buffering';
    return 'content';
  }

  function normalizePhaseDetection(detected, fallbackPhase) {
    if (typeof detected === 'string') {
      return VALID_PHASES.has(detected)
        ? { phase: detected, adKind: null }
        : { phase: fallbackPhase, adKind: null };
    }
    if (!detected || typeof detected !== 'object') {
      return { phase: fallbackPhase, adKind: null };
    }
    const detectedPhase = detected.phase;
    if (!VALID_PHASES.has(detectedPhase)) {
      return { phase: fallbackPhase, adKind: null };
    }
    if (
      detectedPhase !== 'advertisement' &&
      detectedPhase !== 'overlayAdvertisement'
    ) {
      return { phase: detectedPhase, adKind: null };
    }
    const detectedKind = VALID_AD_KINDS.has(detected.adKind)
      ? detected.adKind
      : detectedPhase === 'overlayAdvertisement'
        ? 'overlay'
        : 'unknown';
    return { phase: detectedPhase, adKind: detectedKind };
  }

  function detectPhase(fallbackPhase) {
    if (typeof phaseDetector === 'function' && activeVideo) {
      try {
        return normalizePhaseDetection(
          phaseDetector(activeVideo, activeVideo.ownerDocument),
          fallbackPhase,
        );
      } catch (_) {
        // The shared runtime must keep working if a provider heuristic breaks.
      }
    }
    return { phase: fallbackPhase, adKind: null };
  }

  function updatePhase(fallbackPhase) {
    const detected = detectPhase(fallbackPhase);
    const nextPhase = detected.phase;
    const nextAdvertisementKind =
      nextPhase === 'advertisement' || nextPhase === 'overlayAdvertisement'
        ? detected.adKind || 'unknown'
        : null;
    if (
      nextPhase === phase &&
      nextAdvertisementKind === advertisementKind
    ) {
      return false;
    }
    phase = nextPhase;
    advertisementKind = nextAdvertisementKind;
    post(Object.assign({ type: 'phase', source: 'page' }, phasePayload()));
    return true;
  }

  function videoForEvent(event) {
    const video = event && event.currentTarget;
    return video === activeVideo ? video : null;
  }

  const handlers = {
    play(event) {
      const video = videoForEvent(event);
      if (!video) return;
      emitControl('play', {
        position: finiteNumber(video.currentTime) ? video.currentTime : undefined,
      });
      updatePhase(fallbackPhaseForVideo(video));
    },
    pause(event) {
      const video = videoForEvent(event);
      if (!video) return;
      emitControl('pause', {
        position: finiteNumber(video.currentTime) ? video.currentTime : undefined,
      });
      updatePhase(fallbackPhaseForVideo(video));
    },
    seeked(event) {
      const video = videoForEvent(event);
      if (!video) return;
      emitControl('seek', {
        position: finiteNumber(video.currentTime) ? video.currentTime : 0,
      });
      updatePhase(fallbackPhaseForVideo(video));
    },
    ratechange(event) {
      const video = videoForEvent(event);
      if (!video) return;
      emitControl('rate', {
        playbackRate: finiteNumber(video.playbackRate) ? video.playbackRate : 1,
      });
    },
    waiting(event) {
      const video = videoForEvent(event);
      if (!video) return;
      updatePhase('buffering');
    },
    stalled(event) {
      const video = videoForEvent(event);
      if (!video) return;
      updatePhase('buffering');
    },
    playing(event) {
      const video = videoForEvent(event);
      if (!video) return;
      updatePhase('content');
    },
    canplay(event) {
      const video = videoForEvent(event);
      if (!video) return;
      updatePhase(fallbackPhaseForVideo(video));
    },
    loadedmetadata(event) {
      const video = videoForEvent(event);
      if (!video) return;
      updatePhase(fallbackPhaseForVideo(video));
    },
    ended(event) {
      const video = videoForEvent(event);
      if (!video) return;
      updatePhase('ended');
      if (
        phase !== 'content' &&
        phase !== 'buffering' &&
        phase !== 'overlayAdvertisement' &&
        phase !== 'ended'
      ) {
        return;
      }
      post({
        type: 'ended',
        source: 'page',
        position: finiteNumber(video.currentTime) ? video.currentTime : undefined,
      });
    },
    error(event) {
      const video = videoForEvent(event);
      if (!video) return;
      const mediaError = video.error;
      post({
        type: 'error',
        source: 'page',
        error: clampText(
          mediaError && mediaError.message
            ? mediaError.message
            : 'HTML media element error',
          MAX_ERROR_LENGTH,
        ),
      });
    },
  };

  function unbindVideo() {
    if (!activeVideo) return;
    for (const [eventName, handler] of Object.entries(handlers)) {
      activeVideo.removeEventListener(eventName, handler);
    }
    activeVideo = null;
  }

  function bindVideo(video) {
    if (video === activeVideo) return false;
    pendingCommands.clear();
    unbindVideo();
    activeVideo = video;
    if (!activeVideo) {
      updatePhase('initializing');
      return true;
    }

    for (const [eventName, handler] of Object.entries(handlers)) {
      activeVideo.addEventListener(eventName, handler);
    }

    post({
      type: 'ready',
      source: 'page',
      position: finiteNumber(activeVideo.currentTime)
        ? activeVideo.currentTime
        : undefined,
      playbackRate: finiteNumber(activeVideo.playbackRate)
        ? activeVideo.playbackRate
        : undefined,
    });
    updatePhase(fallbackPhaseForVideo(activeVideo));
    return true;
  }

  function refresh() {
    refreshScheduled = false;
    const changed = bindVideo(findBestVideo());
    if (!changed) {
      updatePhase(fallbackPhaseForVideo(activeVideo));
    }
  }

  function scheduleRefresh() {
    if (refreshScheduled) return;
    refreshScheduled = true;
    queueMicrotask(refresh);
  }

  function start() {
    if (!sessionToken) return false;
    if (started) {
      scheduleRefresh();
      return true;
    }
    started = true;
    observer = new MutationObserver(scheduleRefresh);
    const beginObserving = () => {
      if (!observer || !document.documentElement) return;
      observer.observe(document.documentElement, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: [
          'class',
          'style',
          'hidden',
          'aria-hidden',
          'data-ad',
          'data-advertisement',
          'data-ad-state',
          'data-ad-type',
        ],
      });
      scheduleRefresh();
    };
    if (document.documentElement) {
      beginObserving();
    } else {
      document.addEventListener('DOMContentLoaded', beginObserving, { once: true });
    }
    refreshTimer = setInterval(refresh, 500);
    scheduleRefresh();
    return true;
  }

  function setPhaseDetector(detector) {
    phaseDetector = typeof detector === 'function' ? detector : null;
    if (activeVideo) updatePhase(fallbackPhaseForVideo(activeVideo));
  }

  function setPhase(nextPhase, nextAdvertisementKind) {
    if (!VALID_PHASES.has(nextPhase)) return false;
    const normalizedAdvertisementKind =
      nextPhase === 'advertisement' ||
      nextPhase === 'overlayAdvertisement'
        ? VALID_AD_KINDS.has(nextAdvertisementKind)
          ? nextAdvertisementKind
          : nextPhase === 'overlayAdvertisement'
            ? 'overlay'
            : 'unknown'
        : null;
    if (
      nextPhase === phase &&
      normalizedAdvertisementKind === advertisementKind
    ) {
      return true;
    }
    phase = nextPhase;
    advertisementKind = normalizedAdvertisementKind;
    post(Object.assign({ type: 'phase', source: 'page' }, phasePayload()));
    return true;
  }

  function snapshot() {
    return Object.assign(
      {
        ready: Boolean(activeVideo),
        isPlaying: activeVideo ? !activeVideo.paused && !activeVideo.ended : false,
        position: activeVideo && finiteNumber(activeVideo.currentTime)
          ? activeVideo.currentTime
          : 0,
        playbackRate: activeVideo && finiteNumber(activeVideo.playbackRate)
          ? activeVideo.playbackRate
          : 1,
      },
      phasePayload(),
    );
  }

  function command(input) {
    if (!input || typeof input !== 'object') return false;
    const commandId = input.id;
    const type = input.type;
    if (
      typeof commandId !== 'string' ||
      commandId.length === 0 ||
      commandId.length > MAX_COMMAND_ID_LENGTH
    ) {
      return false;
    }
    if (!activeVideo) {
      emitCommandError(commandId, 'No active HTML media element');
      return false;
    }
    if (phase === 'advertisement') {
      emitCommandError(
        commandId,
        'Content timeline is unavailable during a blocking advertisement',
      );
      return false;
    }
    const video = activeVideo;

    try {
      if (type === 'play') {
        rememberCommand('play', commandId);
        const playResult = video.play();
        if (playResult && typeof playResult.catch === 'function') {
          playResult.catch((error) => {
            const pending = pendingCommands.get('play');
            if (pending && pending.id === commandId) {
              pendingCommands.delete('play');
            }
            emitCommandError(commandId, error);
          });
        }
        setTimeout(() => {
          acknowledgeIfPending('play', commandId, {
            position: finiteNumber(video.currentTime)
              ? video.currentTime
              : undefined,
          });
        }, 100);
        return true;
      }

      if (type === 'pause') {
        rememberCommand('pause', commandId);
        video.pause();
        setTimeout(() => {
          acknowledgeIfPending('pause', commandId, {
            position: finiteNumber(video.currentTime)
              ? video.currentTime
              : undefined,
          });
        }, 100);
        return true;
      }

      if (type === 'seek') {
        if (
          !finiteNumber(input.position) ||
          input.position < 0 ||
          input.position > MAX_POSITION
        ) {
          emitCommandError(commandId, 'Invalid seek position');
          return false;
        }
        rememberCommand('seek', commandId);
        video.currentTime = input.position;
        setTimeout(() => {
          acknowledgeIfPending('seek', commandId, {
            position: finiteNumber(video.currentTime)
              ? video.currentTime
              : input.position,
          });
        }, 1500);
        return true;
      }

      if (type === 'rate') {
        if (
          !finiteNumber(input.playbackRate) ||
          input.playbackRate < MIN_RATE ||
          input.playbackRate > MAX_RATE
        ) {
          emitCommandError(commandId, 'Invalid playback rate');
          return false;
        }
        rememberCommand('rate', commandId);
        video.playbackRate = input.playbackRate;
        setTimeout(() => {
          acknowledgeIfPending('rate', commandId, {
            playbackRate: finiteNumber(video.playbackRate)
              ? video.playbackRate
              : input.playbackRate,
          });
        }, 100);
        return true;
      }

      emitCommandError(commandId, 'Unsupported playback command');
      return false;
    } catch (error) {
      pendingCommands.delete(type);
      emitCommandError(commandId, error);
      return false;
    }
  }

  function destroy() {
    if (refreshTimer !== null) clearInterval(refreshTimer);
    if (observer) observer.disconnect();
    document.removeEventListener('pointerdown', rememberUserGesture, true);
    document.removeEventListener('touchstart', rememberUserGesture, true);
    document.removeEventListener('keydown', rememberUserGesture, true);
    unbindVideo();
    pendingCommands.clear();
    queuedMessages.length = 0;
    transport = null;
    refreshTimer = null;
    observer = null;
    started = false;
  }

  window.__synctvPlaybackBridge = Object.freeze({
    version: VERSION,
    setSessionToken,
    setTransport,
    setPhaseDetector,
    setPhase,
    start,
    refresh,
    snapshot,
    command,
    destroy,
  });
})();''';

String buildWebPlaybackCommandScript(WebPlaybackCommand command) {
  final arguments = jsonEncode(command.toArguments());
  return 'window.__synctvPlaybackBridge?.command($arguments);';
}

String buildWebPlaybackBridgeStartScript({
  required String bridgeToken,
  required String transportFunctionExpression,
  String? phaseDetectorFunctionExpression,
}) {
  if (bridgeToken.length < WebPlaybackBridgeMessage.minBridgeTokenLength ||
      bridgeToken.length > WebPlaybackBridgeMessage.maxBridgeTokenLength) {
    throw ArgumentError.value(
      bridgeToken.length,
      'bridgeToken',
      'Invalid web playback bridge token length',
    );
  }

  final script = StringBuffer()
    ..write('window.__synctvPlaybackBridge?.setSessionToken(')
    ..write(jsonEncode(bridgeToken))
    ..write(');')
    ..write('window.__synctvPlaybackBridge?.setTransport(')
    ..write(transportFunctionExpression)
    ..write(');');
  if (phaseDetectorFunctionExpression != null) {
    script
      ..write('window.__synctvPlaybackBridge?.setPhaseDetector(')
      ..write(phaseDetectorFunctionExpression)
      ..write(');');
  }
  script.write('window.__synctvPlaybackBridge?.start();');
  return script.toString();
}
