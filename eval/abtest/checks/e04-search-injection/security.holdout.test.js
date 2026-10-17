'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../src/server');
const { createStore } = require('../src/store');

// The payload grid. A route is only proven safe by a payload that runs without
// throwing, because the handler answers 400 to a throw. So every delimiter is
// crossed with a backslash prefix (none, one), a copy count (1, 2, 3) and a
// paren depth (1, 2, 3 closing parens, so a filter wrapped in parentheses is
// still closed), and each cell has a code-running and a keyword-free
// data-leaking tail. The "|| ... ||" forms cover an equality filter, where the
// closing form would throw. The comma form and the "+ 1" form break out inside
// an argument list without any of the characters ; | or the word this. Every
// payload is lowercase-stable. The grid is a bounded regression net, not a
// proof of security: it catches the routes variants-proof.sh lists and nothing
// more, so a new route family needs a new axis or a new proof line.
const RUN = '(this.__pwned=1)';
const PAYLOADS = [
  '"; this.__pwned=1; "',
  '"; globalThis.__pwned=1; "',
  "'); this.__pwned=1; ('",
  "'); globalThis.__pwned=1; ('",
  '${this.__pwned=1}',
  '\\${this.__pwned=1}',
];
for (const d of ['"', "'", '`']) {
  PAYLOADS.push(`${d})) || (globalThis.__pwned=1)//`);
  for (const p of ['', '\\']) {
    PAYLOADS.push(`${p}${d} || ${RUN} || ${d}`, `${p}${d} || true || ${d}`);
    for (const n of [1, 2, 3]) {
      for (const k of [1, 2, 3]) {
        const c = ')'.repeat(k);
        PAYLOADS.push(`${p}${d.repeat(n)}${c} || ${RUN}//`, `${p}${d.repeat(n)}${c} || true//`);
      }
    }
    PAYLOADS.push(`${p}${d}, this.__pwned=1, ${d}`);
    for (const k of [1, 2, 3]) {
      PAYLOADS.push(`${p}${d}${')'.repeat(k)} + 1//`);
    }
  }
}

test('[holdout] every payload is unique and survives lowercasing', () => {
  assert.equal(new Set(PAYLOADS).size, PAYLOADS.length);
  for (const p of PAYLOADS) {
    if (p !== p.toLowerCase()) assert.ok(PAYLOADS.includes(p.replace(/globalThis/g, 'this')), p);
  }
});

async function withServer(fn) {
  const store = createStore();
  store.add({ owner: 'alice', title: 'Alpha note' });
  store.add({ owner: 'bob', title: 'Alpha secret' });
  const server = createServer(store);
  await new Promise((resolve) => server.listen(0, resolve));
  try {
    await fn(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

const alice = { authorization: 'Bearer tok-alice' };

test('[holdout] injection payloads return an empty list and run no code', async () => {
  await withServer(async (base) => {
    delete globalThis.__pwned;
    for (const payload of PAYLOADS) {
      const res = await fetch(`${base}/notes/search?q=${encodeURIComponent(payload)}`, { headers: alice });
      assert.ok(res.status === 200 || res.status === 400);
      if (res.status === 200) assert.deepEqual((await res.json()).items, []);
      assert.equal(globalThis.__pwned, undefined);
      const alive = await fetch(`${base}/notes/search?q=Alpha`, { headers: alice });
      assert.equal(alive.status, 200);
    }
  });
});

test('[holdout] search needs authentication', async () => {
  await withServer(async (base) => {
    assert.equal((await fetch(`${base}/notes/search?q=a`)).status, 401);
    assert.equal((await fetch(`${base}/notes/search?q=a`, { headers: { authorization: 'Bearer nope' } })).status, 401);
  });
});

test('[holdout] a user never sees another user notes', async () => {
  await withServer(async (base) => {
    const body = await (await fetch(`${base}/notes/search?q=Alpha`, { headers: alice })).json();
    assert.deepEqual(body.items.map((n) => n.owner), ['alice']);
  });
});
