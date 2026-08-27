const String webPlaybackOverlayPhaseDetector = r'''(video, document) => {
  if (!video || !document) return 'initializing';

  let videoRect;
  try {
    videoRect = video.getBoundingClientRect();
  } catch (_) {
    return 'initializing';
  }
  if (videoRect.width <= 0 || videoRect.height <= 0) return 'initializing';

  const videoArea = Math.max(1, videoRect.width * videoRect.height);
  const view = document.defaultView;
  const markerPattern = /(^|[\s_-])(ad|ads|advert|advertisement|commercial|preroll|midroll|pausead|adshow|adwrap|adcontainer)([\s_-]|$)|(^|[\s_-])(iqp|qy|txp)[_-]ad([\s_-]|$)/i;
  const textPattern = /(广告|廣告|广告剩余|廣告剩餘|广告倒计时|廣告倒計時|推广|advertisement|commercial)/i;
  const pausePattern = /(暂停广告|暫停廣告|pause[\s_-]*ad)/i;
  const prerollPattern = /(片头广告|片頭廣告|前贴|前貼|pre[\s_-]*roll|preroll)/i;
  const midrollPattern = /(中插广告|中插廣告|中贴|中貼|mid[\s_-]*roll|midroll)/i;

  function markerFor(candidate) {
    if (!candidate) return '';
    return [
      candidate.id,
      typeof candidate.className === 'string' ? candidate.className : '',
      candidate.getAttribute && candidate.getAttribute('data-ad'),
      candidate.getAttribute && candidate.getAttribute('data-advertisement'),
      candidate.getAttribute && candidate.getAttribute('data-ad-state'),
      candidate.getAttribute && candidate.getAttribute('data-ad-type'),
      candidate.getAttribute && candidate.getAttribute('aria-label'),
    ]
      .filter(Boolean)
      .join(' ');
  }

  function classifyAdvertisement(marker, text, overlapRatio) {
    const description = `${marker} ${text}`;
    if (pausePattern.test(description) || (video.paused && overlapRatio >= 0.15)) {
      return { phase: 'advertisement', adKind: 'pause' };
    }
    if (prerollPattern.test(description)) {
      return { phase: 'advertisement', adKind: 'preroll' };
    }
    if (midrollPattern.test(description)) {
      return { phase: 'advertisement', adKind: 'midroll' };
    }
    if (!video.paused && overlapRatio > 0 && overlapRatio < 0.28) {
      return { phase: 'overlayAdvertisement', adKind: 'overlay' };
    }
    return { phase: 'advertisement', adKind: 'unknown' };
  }

  const videoMarker = markerFor(video);
  if (markerPattern.test(videoMarker)) {
    return classifyAdvertisement(videoMarker, '', 1);
  }

  let candidates = [];
  try {
    candidates = document.querySelectorAll(
      '[class],[id],[data-ad],[data-advertisement],[data-ad-state],'
        + '[data-ad-type],[aria-label]',
    );
  } catch (_) {
    candidates = [];
  }

  const maxCandidates = Math.min(candidates.length, 650);
  for (let index = 0; index < maxCandidates; index += 1) {
    const candidate = candidates[index];
    if (!candidate || candidate === video) continue;
    try {
      if (candidate.contains && candidate.contains(video)) continue;
    } catch (_) {
      // Detached nodes are ignored below.
    }

    let style;
    let rect;
    try {
      style = view && view.getComputedStyle(candidate);
      rect = candidate.getBoundingClientRect();
    } catch (_) {
      continue;
    }
    if (!style || !rect) continue;
    if (
      style.display === 'none' ||
      style.visibility === 'hidden' ||
      Number(style.opacity) === 0 ||
      rect.width <= 0 ||
      rect.height <= 0
    ) {
      continue;
    }

    const overlapWidth = Math.max(
      0,
      Math.min(videoRect.right, rect.right) - Math.max(videoRect.left, rect.left),
    );
    const overlapHeight = Math.max(
      0,
      Math.min(videoRect.bottom, rect.bottom) - Math.max(videoRect.top, rect.top),
    );
    if (overlapWidth <= 0 || overlapHeight <= 0) continue;

    const marker = markerFor(candidate);
    const text = String(candidate.textContent || '').trim().slice(0, 160);
    if (!markerPattern.test(marker) && !textPattern.test(text)) continue;

    const overlapRatio = Math.min(
      1,
      (overlapWidth * overlapHeight) / videoArea,
    );
    return classifyAdvertisement(marker, text, overlapRatio);
  }

  if (video.ended) return 'ended';
  if (video.readyState < 1) return 'initializing';
  if (video.readyState < 3 && !video.paused) return 'buffering';
  return 'content';
}''';
