'use strict';

const assert = require('assert');
const {
  hasExactTargetId,
  normalizeVideoTitle,
  verifyPagePlayerIdentity,
} = require('../scripts/douyin_page_identity');

const videoId = '7035899654399135007';
const title = '【潜龙勿用】龙潜于渊 #四川麻将';

assert.strictEqual(
  normalizeVideoTitle(`${title} - 抖音`),
  title,
);
assert.strictEqual(
  hasExactTargetId(`https://www.douyin.com/video/${videoId}`, videoId),
  true,
);
assert.strictEqual(
  hasExactTargetId(`https://www.douyin.com/user/author?modal_id=${videoId}`, videoId),
  true,
);
assert.strictEqual(
  hasExactTargetId('https://example.com/video/7035899654399135007', videoId),
  false,
);

const valid = {
  pageUrl: `https://www.douyin.com/video/${videoId}`,
  pageTitle: `${title} - 抖音`,
  expectedVideoId: videoId,
  expectedTitle: title,
  htmlHasExpectedId: true,
  hasMediaCandidate: true,
};
assert.strictEqual(verifyPagePlayerIdentity(valid), true);
assert.strictEqual(verifyPagePlayerIdentity({ ...valid, pageTitle: '推荐视频 - 抖音' }), false);
assert.strictEqual(verifyPagePlayerIdentity({ ...valid, pageUrl: 'https://www.douyin.com/' }), false);
assert.strictEqual(verifyPagePlayerIdentity({ ...valid, htmlHasExpectedId: false }), false);
assert.strictEqual(verifyPagePlayerIdentity({ ...valid, hasMediaCandidate: false }), false);

console.log('douyin page identity tests: PASS');
