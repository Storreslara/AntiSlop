'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { withServer, H, post } = require('./lib.holdout');

test('[holdout] GET /tags counts tags over the caller notes only', async () => {
  await withServer(async (base) => {
    await post(base, 'alice', { title: 'one', tags: ['a', 'b'] });
    await post(base, 'alice', { title: 'two', tags: ['a'] });
    await post(base, 'bob', { title: 'three', tags: ['a', 'c'] });
    const res = await fetch(`${base}/tags`, { headers: H('alice') });
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { a: 2, b: 1 });
  });
});

test('[holdout] GET /tags is an empty object without tags and needs a token', async () => {
  await withServer(async (base) => {
    await post(base, 'alice', { title: 'plain' });
    assert.deepEqual(await (await fetch(`${base}/tags`, { headers: H('alice') })).json(), {});
    assert.equal((await fetch(`${base}/tags`)).status, 401);
  });
});
