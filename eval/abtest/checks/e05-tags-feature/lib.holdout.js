'use strict';
// Shared helper for the E5 holdout tests: start the server on a port, call it.
const { createServer } = require('../src/server');
const { createStore } = require('../src/store');

async function withServer(fn) {
  const store = createStore();
  const server = createServer(store);
  await new Promise((resolve) => server.listen(0, resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await fn(base, store);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

const H = (user) => ({ authorization: `Bearer tok-${user}`, 'content-type': 'application/json' });

function post(base, user, body) {
  return fetch(`${base}/notes`, { method: 'POST', headers: H(user), body: JSON.stringify(body) });
}

module.exports = { withServer, H, post };
