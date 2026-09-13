'use strict';

const assert = require('assert');
const fs = require('fs');
const http = require('http');
const os = require('os');
const path = require('path');
const { streamMedia } = require('../scripts/douyin_stream_media');

async function main() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'douyin-stream-test-'));
  const successPath = path.join(root, 'success.mp4');
  const stalledPath = path.join(root, 'stalled.mp4');
  const chunk = Buffer.alloc(32 * 1024, 7);
  const server = http.createServer((request, response) => {
    if (request.url === '/redirect') {
      response.writeHead(302, { Location: '/stream' });
      response.end();
      return;
    }
    if (request.url === '/stream') {
      response.writeHead(200, { 'Content-Type': 'video/mp4' });
      let sent = 0;
      const timer = setInterval(() => {
        response.write(chunk);
        sent += 1;
        if (sent === 6) {
          clearInterval(timer);
          response.end();
        }
      }, 100);
      return;
    }
    response.writeHead(200, { 'Content-Type': 'video/mp4' });
    response.write(chunk);
  });

  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  assert(address && typeof address === 'object');
  const base = `http://127.0.0.1:${address.port}`;
  const common = {
    allowedHostSuffixes: ['127.0.0.1'],
    stallTimeoutMs: 350,
    responseTimeoutMs: 200,
    allowHttpForTest: true,
  };

  try {
    const result = await streamMedia(`${base}/redirect`, {
      ...common,
      destination: successPath,
    });
    assert.strictEqual(result.status, 200);
    assert.strictEqual(result.bytes, chunk.length * 6);
    assert.strictEqual(fs.statSync(successPath).size, chunk.length * 6);

    let stalled = false;
    try {
      await streamMedia(`${base}/stall`, {
        ...common,
        destination: stalledPath,
      });
    } catch (error) {
      stalled = /idle|stalled/.test(String(error));
    }
    assert.strictEqual(stalled, true);
    assert.strictEqual(fs.existsSync(stalledPath), false);
    console.log('douyin stream media tests: PASS');
  } finally {
    await new Promise(resolve => server.close(resolve));
    fs.rmSync(root, { recursive: true, force: true });
  }
}

main().catch(error => {
  console.error(error);
  process.exit(1);
});
