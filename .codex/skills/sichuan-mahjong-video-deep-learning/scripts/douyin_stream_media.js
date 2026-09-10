'use strict';

const fs = require('fs');
const http = require('http');
const https = require('https');

function allowedUrl(rawUrl, allowedHostSuffixes, allowHttpForTest) {
  try {
    const parsed = new URL(rawUrl);
    const protocolAllowed = parsed.protocol === 'https:'
      || (allowHttpForTest && parsed.protocol === 'http:');
    return protocolAllowed && allowedHostSuffixes.some(
      suffix => parsed.hostname.toLowerCase().endsWith(suffix)
    );
  } catch (_) {
    return false;
  }
}

function streamMedia(rawUrl, options, redirectsLeft = 10) {
  const {
    destination,
    headers = {},
    allowedHostSuffixes,
    stallTimeoutMs,
    responseTimeoutMs = stallTimeoutMs,
    allowHttpForTest = false,
  } = options;
  if (!allowedUrl(rawUrl, allowedHostSuffixes, allowHttpForTest)) {
    return Promise.reject(new Error('media host is not allowlisted'));
  }

  return new Promise((resolve, reject) => {
    const parsed = new URL(rawUrl);
    const client = parsed.protocol === 'http:' ? http : https;
    let settled = false;
    let responseRef = null;
    let output = null;
    let stallTimer = null;
    let responseTimer = null;
    let bytes = 0;
    let lastByteAt = Date.now();

    const removePartial = () => {
      try { fs.rmSync(destination, { force: true }); } catch (_) { }
    };
    const cleanup = () => {
      if (stallTimer) clearInterval(stallTimer);
      if (responseTimer) clearTimeout(responseTimer);
    };
    const fail = error => {
      if (settled) return;
      settled = true;
      cleanup();
      if (responseRef) responseRef.destroy();
      if (output) output.destroy();
      removePartial();
      reject(error);
    };

    const request = client.get(rawUrl, { headers }, response => {
      responseRef = response;
      if (responseTimer) clearTimeout(responseTimer);
      const status = Number(response.statusCode || 0);
      if ([301, 302, 303, 307, 308].includes(status) && response.headers.location) {
        response.resume();
        if (redirectsLeft <= 0) {
          fail(new Error('too many media redirects'));
          return;
        }
        settled = true;
        cleanup();
        const redirected = new URL(response.headers.location, rawUrl).toString();
        streamMedia(redirected, options, redirectsLeft - 1).then(resolve, reject);
        return;
      }
      if (status !== 200 && status !== 206) {
        response.resume();
        fail(new Error(`media HTTP status ${status}`));
        return;
      }

      output = fs.createWriteStream(destination, { flags: 'w', mode: 0o600 });
      stallTimer = setInterval(() => {
        if (Date.now() - lastByteAt >= stallTimeoutMs) {
          request.destroy(new Error(`media stalled for ${stallTimeoutMs}ms`));
        }
      }, Math.min(5000, Math.max(100, Math.floor(stallTimeoutMs / 4))));
      response.on('data', chunk => {
        bytes += chunk.length;
        lastByteAt = Date.now();
      });
      response.on('error', fail);
      output.on('error', fail);
      output.on('finish', () => {
        if (settled) return;
        output.close(error => {
          if (error) {
            fail(error);
            return;
          }
          settled = true;
          cleanup();
          resolve({ status, bytes });
        });
      });
      response.pipe(output);
    });
    request.setTimeout(stallTimeoutMs, () => {
      request.destroy(new Error(`media request idle for ${stallTimeoutMs}ms`));
    });
    responseTimer = setTimeout(() => {
      request.destroy(new Error(`media response not received for ${responseTimeoutMs}ms`));
    }, responseTimeoutMs);
    request.on('error', fail);
  });
}

module.exports = { streamMedia };
