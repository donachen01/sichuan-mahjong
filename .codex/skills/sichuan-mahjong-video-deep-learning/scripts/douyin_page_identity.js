'use strict';

function normalizeVideoTitle(value) {
  return String(value || '')
    .normalize('NFKC')
    .replace(/\s*-\s*抖音\s*$/, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function hasExactTargetId(pageUrl, expectedVideoId) {
  try {
    const parsed = new URL(pageUrl);
    if (parsed.hostname !== 'www.douyin.com' && parsed.hostname !== 'douyin.com') {
      return false;
    }
    if (parsed.pathname === `/video/${expectedVideoId}`) {
      return true;
    }
    return parsed.searchParams.get('modal_id') === expectedVideoId;
  } catch (_) {
    return false;
  }
}

function verifyPagePlayerIdentity({
  pageUrl,
  pageTitle,
  expectedVideoId,
  expectedTitle,
  htmlHasExpectedId,
  hasMediaCandidate,
}) {
  const normalizedExpectedTitle = normalizeVideoTitle(expectedTitle);
  const normalizedPageTitle = normalizeVideoTitle(pageTitle);
  return Boolean(
    expectedVideoId &&
    normalizedExpectedTitle &&
    hasExactTargetId(pageUrl, expectedVideoId) &&
    htmlHasExpectedId &&
    hasMediaCandidate &&
    normalizedPageTitle === normalizedExpectedTitle
  );
}

module.exports = {
  hasExactTargetId,
  normalizeVideoTitle,
  verifyPagePlayerIdentity,
};
