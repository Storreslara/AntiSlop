'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const net = require('node:net');
const path = require('node:path');
const { spawn, spawnSync } = require('node:child_process');
const { createServer } = require('../src/server');

const SRC = path.join(__dirname, '..', 'src');

test('prototype-key tokens are rejected on every route', { timeout: 20000 }, async () => {
  const server = createServer();
  await new Promise((resolve) => server.listen(0, resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    for (const token of ['toString', 'constructor', 'valueOf', 'hasOwnProperty', '__proto__']) {
      const headers = { authorization: `Bearer ${token}`, 'content-type': 'application/json' };
      assert.equal((await fetch(`${base}/notes`, { headers })).status, 401, token);
      const body = JSON.stringify({ title: 'x' });
      assert.equal((await fetch(`${base}/notes`, { method: 'POST', headers, body })).status, 401, token);
      assert.equal((await fetch(`${base}/notes/n1`, { method: 'DELETE', headers })).status, 401, token);
    }
    const good = await fetch(`${base}/notes`, { headers: { authorization: 'Bearer tok-alice' } });
    assert.equal(good.status, 200);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

// The server runs in a child process so a crash is a failed test, not a dead runner.
const SERVE = `const { createServer } = require(${JSON.stringify(path.join(SRC, 'server'))});
const server = createServer();
server.listen(0, () => { console.log('ready'); console.log(server.address().port); });`;

function rawRequest(port, text) {
  return new Promise((resolve) => {
    let buf = '';
    const socket = net.connect(port, '127.0.0.1', () => socket.write(text));
    // A server that never answers ends the request after 5 seconds with what it sent (nothing), so the assertion fails.
    socket.setTimeout(5000, () => socket.destroy());
    socket.on('data', (d) => { buf += d; });
    socket.on('close', () => resolve(buf));
    socket.on('error', () => resolve(buf));
  });
}

test('a malformed request URL is a 400 and the server keeps serving', { timeout: 30000 }, async () => {
  const child = spawn(process.execPath, ['-e', SERVE], { stdio: ['ignore', 'pipe', 'ignore'] });
  let exited = false;
  child.on('exit', () => { exited = true; });
  try {
    const port = await new Promise((resolve, reject) => {
      let out = '';
      child.stdout.on('data', (d) => {
        out += d;
        const line = /^(\d+)\r?\n/m.exec(out);
        if (line) resolve(Number(line[1]));
      });
      child.once('exit', () => reject(new Error('server exited before it listened')));
    });
    const head = 'GET http://[ HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer tok-alice\r\nConnection: close\r\n\r\n';
    assert.match(await rawRequest(port, head), /^HTTP\/1\.1 400 /);
    assert.equal(exited, false);
    const after = await fetch(`http://127.0.0.1:${port}/notes`, { headers: { authorization: 'Bearer tok-alice' } });
    assert.equal(after.status, 200);
  } finally {
    child.kill();
  }
});

test('requiring cli.js does not run main', () => {
  const code = `require(${JSON.stringify(path.join(SRC, 'cli.js'))}); console.log('exitCode=' + process.exitCode);`;
  const out = spawnSync(process.execPath, ['-e', code], { encoding: 'utf8' });
  assert.equal(out.stdout, 'exitCode=undefined\n');
  assert.equal(out.stderr, '');
  assert.equal(out.status, 0);
});
