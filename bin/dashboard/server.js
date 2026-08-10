#!/usr/bin/env node
'use strict';

// HTTP server for the microworld dashboard. Binds 127.0.0.1 only, ephemeral
// port by default. Generates a per-launch token via node:crypto. Routes:
// GET / (placeholder HTML), GET /api/bundles (bundle list with auth).
// Auth: every request requires ?t=<token> or X-Antislop-Token header.

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { discover } = require('./discover');

function startServer(projectRoot, port = 0) {
  const token = crypto.randomBytes(32).toString('hex');

  const server = http.createServer(async (req, res) => {
    // Auth check: token must be present in ?t= query param or X-Antislop-Token header
    const urlObj = new URL(req.url, 'http://127.0.0.1');
    const tokenParam = urlObj.searchParams.get('t');
    const tokenHeader = req.headers['x-antislop-token'];
    const providedToken = tokenParam || tokenHeader;

    if (!providedToken || providedToken !== token) {
      res.writeHead(401, { 'Content-Type': 'text/plain' });
      res.end();
      return;
    }

    // GET /
    if (req.method === 'GET' && req.url.startsWith('/')) {
      const pathname = new URL(req.url, 'http://127.0.0.1').pathname;
      if (pathname === '/') {
        const htmlPath = path.join(__dirname, 'index.html');
        try {
          const html = fs.readFileSync(htmlPath, 'utf8');
          res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
          res.end(html);
        } catch (err) {
          res.writeHead(500, { 'Content-Type': 'text/plain' });
          res.end('Could not read index.html\n');
        }
        return;
      }

      // GET /api/bundles
      if (pathname === '/api/bundles') {
        try {
          const bundles = discover(projectRoot);
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify(bundles, null, 2));
        } catch (err) {
          res.writeHead(500, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Failed to discover bundles' }));
        }
        return;
      }

      // 404
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Not found\n');
      return;
    }

    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not found\n');
  });

  server.listen(port, '127.0.0.1', () => {
    const addr = server.address();
    console.log(`http://127.0.0.1:${addr.port}/?t=${token}`);
  });

  return { server, token };
}

module.exports = { startServer };
