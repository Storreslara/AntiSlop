'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../src/server');
const { createStore } = require('../src/store');

// The payload grid. A route is only proven safe by a payload that runs without
// throwing, because the handler answers 400 to a throw. So every delimiter is
// crossed with a backslash prefix (none, one) and a copy count (1, 2, 3). The
// closing forms are: a "|| ... ||" form for an equality filter; a reopen form
// that closes k parens, ORs in a code-running or a keyword-free data-leaking
// tail, then reopens k parens and the delimiter, so the filter's own closing
// text balances it at any wrapping depth without a comment; a comma form and a
// plus form that run code inside an argument list with no ; or | and, for the
// forms using __pwned, no this; and a "+ 1//" form. Every payload is
// lowercase-stable. The grid is a regression net, not a proof of security: it
// samples breakout shapes and does not enumerate every way out of an argument
// list, so a route family it misses needs a new axis and a new proof line in
// variants-proof.sh.
const RUN = '(this.__pwned=1)';
const RUN2 = '(__pwned=1)';
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
        const o = '('.repeat(k);
        PAYLOADS.push(`${p}${d.repeat(n)}${c} || ${RUN}//`, `${p}${d.repeat(n)}${c} || true//`);
        PAYLOADS.push(`${p}${d.repeat(n)}${c} || ${RUN} || ${o}${d}`, `${p}${d.repeat(n)}${c} || true || ${o}${d}`);
        if (n === 1) PAYLOADS.push(`${p}${d}${c} || ${RUN2} || ${o}${d}`);
      }
    }
    PAYLOADS.push(`${p}${d}, this.__pwned=1, ${d}`, `${p}${d}, __pwned=1, ${d}`);
    PAYLOADS.push(`${p}${d}+[__pwned=1]+${d}`, `${p}${d}+[global.__pwned=1]+${d}`);
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
