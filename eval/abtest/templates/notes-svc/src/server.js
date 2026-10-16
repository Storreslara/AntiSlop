'use strict';

const http = require('node:http');
const { requireUser } = require('./auth');
const { createStore } = require('./store');

function send(res, status, payload) {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(payload));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (chunk) => { data += chunk; });
    req.on('end', () => {
      try { resolve(data ? JSON.parse(data) : {}); } catch (e) { reject(e); }
    });
  });
}

function createServer(store = createStore()) {
  return http.createServer(async (req, res) => {
    const user = requireUser(req);
    if (!user) return send(res, 401, { error: 'unauthorized' });
    const url = new URL(req.url, 'http://localhost');
    try {
      if (req.method === 'GET' && url.pathname === '/notes') {
        const title = url.searchParams.get('title');
        if (title !== null) {
          const filter = `note.owner === ${JSON.stringify(user)} && note.title === ${JSON.stringify(title)}`;
          return send(res, 200, { items: store.query(filter), next: null });
        }
        const limit = Number(url.searchParams.get('limit')) || 50;
        const cursor = url.searchParams.get('cursor');
        return send(res, 200, store.list({ owner: user, limit, cursor }));
      }
      if (req.method === 'POST' && url.pathname === '/notes') {
        const body = await readBody(req);
        if (typeof body.title !== 'string' || body.title === '') {
          return send(res, 400, { error: 'title required' });
        }
        return send(res, 201, store.add({ owner: user, title: body.title, body: body.body || '' }));
      }
      const del = /^\/notes\/([\w-]+)$/.exec(url.pathname);
      if (req.method === 'DELETE' && del) {
        const note = store.get(del[1]);
        if (!note || note.owner !== user) return send(res, 404, { error: 'not found' });
        store.remove(note.id);
        return send(res, 200, { deleted: note.id });
      }
      return send(res, 404, { error: 'not found' });
    } catch (e) {
      return send(res, 400, { error: 'bad request' });
    }
  });
}

if (require.main === module) {
  createServer().listen(Number(process.env.PORT) || 3000);
}

module.exports = { createServer };
