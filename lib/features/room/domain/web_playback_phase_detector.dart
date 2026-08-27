const String webPlaybackOverlayPhaseDetector = r'''(video, document) => {
  if (!video || !document) return 'initializing';

  let videoRect;
  try {
    videoRect = video.getBoundingClientRect();
  } catch (_) {
    return 'initializing';
  }
  if (videoRect.width <= 0 || videoRect.height <= 0) return 'initializing';

  const view = document.defaultView;
  const tokenPattern = /(^|[\s_-])(ad|ads|advert|advertisement|commercial)([\s_-]|$)/i;
  const textPattern = /(广告|廣告|advertisement|commercial)/i;
  let candidates = [];
  try {
    candidates = document.querySelectorAll(
      '[class],[id],[data-ad],[data-advertisement],[aria-label]',
    );
  } catch (_) {
    candidates = [];
  }

  const maxCandidates = Math.min(candidates.length, 500);
  for (let index = 0; index < maxCandidates; index += 1) {
    const candidate = candidates[index];
    if (!candidate || candidate === video) continue;

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

    const marker = [
      candidate.id,
      typeof candidate.className === 'string' ? candidate.className : '',
      candidate.getAttribute && candidate.getAttribute('data-ad'),
      candidate.getAttribute && candidate.getAttribute('data-advertisement'),
      candidate.getAttribute && candidate.getAttribute('aria-label'),
    ]
      .filter(Boolean)
      .join(' ');
    const text = String(candidate.textContent || '').trim().slice(0, 120);
    if (tokenPattern.test(marker) || textPattern.test(text)) {
      return 'advertisement';
    }
  }

  if (video.ended) return 'ended';
  if (video.readyState < 1) return 'initializing';
  if (video.readyState < 3 && !video.paused) return 'buffering';
  return 'content';
}''';
