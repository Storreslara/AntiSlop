'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { withServer, post } = require('./lib.holdout');

test('[holdout] valid tags are stored on the note', async () => {
  await withServer(async (base) => {
    const res = await post(base, 'alice', { title: 't', tags: ['a', 'b-1', 'x'.repeat(20)] });
    assert.equal(res.status, 201);
    assert.deepEqual((await res.json()).tags, ['a', 'b-1', 'x'.repeat(20)]);
  });
});

test('[holdout] omitted or empty tags give an empty list', async () => {
  await withServer(async (base) => {
    assert.deepEqual((await (await post(base, 'alice', { title: 't' })).json()).tags, []);
    assert.deepEqual((await (await post(base, 'alice', { title: 't', tags: [] })).json()).tags, []);
  });
});

test('[holdout] five tags are accepted and six are rejected', async () => {
  await withServer(async (base) => {
    assert.equal((await post(base, 'alice', { title: 't', tags: ['a', 'b', 'c', 'd', 'e'] })).status, 201);
    assert.equal((await post(base, 'alice', { title: 't', tags: ['a', 'b', 'c', 'd', 'e', 'f'] })).status, 400);
  });
});

test('[holdout] bad slugs and bad shapes are rejected with 400', async () => {
  await withServer(async (base) => {
    for (const tags of [['Bad'], ['has space'], ['under_score'], [''], ['x'.repeat(21)], 'solo', [1], [null], { a: 1 }]) {
      const res = await post(base, 'alice', { title: 't', tags });
      assert.equal(res.status, 400, JSON.stringify(tags));
    }
  });
});
