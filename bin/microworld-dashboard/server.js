#!/usr/bin/env node
'use strict';

// HTTP server for the microworld dashboard. Binds 127.0.0.1 only, ephemeral
// port by default. Generates a per-launch token via node:crypto. Routes:
// GET / (placeholder HTML), GET /api/bundles (bundle list with auth),
// GET /api/status (same as /api/bundles for now, same auth).
// Auth: every request requires ?t=<token> or X-Antislop-Token header.
// Watches microworlds/ directory for bundle changes without server restart.

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');
const { discover } = require('./discover');
const { invoke } = require('./invoke');
const { readSourceExcerpt } = require('./source');
const { enumerateDecisions } = require('./decisions');

function startServer(projectRoot, port = 0) {
  const token = crypto.randomBytes(32).toString('hex');
  const microworldsPath = path.join(projectRoot, 'microworlds');

  // Watch for bundle directory changes (new/deleted bundles)
  if (fs.existsSync(microworldsPath)) {
    try {
      fs.watch(microworldsPath, { recursive: true }, () => {
        // Bundle structure changed; next GET request will pick up the change
      });
    } catch (err) {
      // Watch failed; graceful degradation — discover will still work, just no live update
    }
  }

  const server = http.createServer(async (req, res) => {
    // Auth check: token must be present in ?t= query param or X-Antislop-Token header
    let urlObj;
    try {
      urlObj = new URL(req.url, 'http://127.0.0.1');
    } catch (err) {
      res.writeHead(400, { 'Content-Type': 'text/plain' });
      res.end('Bad request\n');
      return;
    }
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
          let html = fs.readFileSync(htmlPath, 'utf8');
          // Inject the feedback-block formatter's actual source verbatim so
          // the shipped client uses the same single implementation the test
          // suite requires via CommonJS -- no separate hand-maintained copy.
          const feedbackBlockSrc = fs.readFileSync(path.join(__dirname, 'feedback-block.js'), 'utf8');
          html = html.replace('/* __FEEDBACK_BLOCK_SOURCE__ */', feedbackBlockSrc);
          res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
          res.end(html);
        } catch (err) {
          res.writeHead(500, { 'Content-Type': 'text/plain' });
          res.end('Could not read index.html\n');
        }
        return;
      }

      // GET /api/bundles and GET /api/status (both return same data)
      if (pathname === '/api/bundles' || pathname === '/api/status') {
        try {
          const bundles = await discover(projectRoot);
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify(bundles, null, 2));
        } catch (err) {
          res.writeHead(500, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Failed to discover bundles' }));
        }
        return;
      }

      // GET /api/decisions (the four human-decision touchpoints, D-7)
      if (pathname === '/api/decisions') {
        try {
          const decisions = enumerateDecisions(projectRoot);
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify(decisions, null, 2));
        } catch (err) {
          res.writeHead(500, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Failed to enumerate decisions' }));
        }
        return;
      }

      // GET /api/context (git HEAD sha)
      if (pathname === '/api/context') {
        try {
          const sha = execSync('git rev-parse HEAD', { cwd: projectRoot, encoding: 'utf8' }).trim();
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ sha }));
        } catch (err) {
          res.writeHead(500, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Failed to get git HEAD' }));
        }
        return;
      }

      // GET /api/source (bounded excerpt reader)
      if (pathname === '/api/source') {
        const file = urlObj.searchParams.get('file');
        const startLineStr = urlObj.searchParams.get('startLine');
        const endLineStr = urlObj.searchParams.get('endLine');

        if (!file || !startLineStr || !endLineStr) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Missing file, startLine, or endLine parameter' }));
          return;
        }

        const startLine = parseInt(startLineStr, 10);
        const endLine = parseInt(endLineStr, 10);

        if (isNaN(startLine) || isNaN(endLine)) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Invalid line numbers' }));
          return;
        }

        const result = readSourceExcerpt(projectRoot, file, startLine, endLine);

        if (!result.success) {
          const statusCode = result.statusCode || 400;
          res.writeHead(statusCode, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: result.reason }));
          return;
        }

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(result));
        return;
      }

      // 404
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Not found\n');
      return;
    }

    // POST /api/invoke
    if (req.method === 'POST' && new URL(req.url, 'http://127.0.0.1').pathname === '/api/invoke') {
      let body = '';
      req.on('data', (chunk) => {
        body += chunk.toString();
      });
      req.on('end', async () => {
        try {
          const data = JSON.parse(body);
          const { id, functionId, inputs } = data;

          if (!id || !functionId || !inputs) {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'missing id, functionId, or inputs' }));
            return;
          }

          // Look up bundle by id
          const bundles = await discover(projectRoot);
          const bundle = bundles.find((b) => b.id === id);
          if (!bundle) {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'unknown id' }));
            return;
          }

          if (bundle.disabled) {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'bundle is disabled', reason: bundle.disabledReason }));
            return;
          }

          // Look up function by functionId
          const fn = bundle.functions.find((f) => f.id === functionId);
          if (!fn) {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'unknown functionId' }));
            return;
          }

          if (fn.disabled) {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'function is disabled', reason: fn.disabledReason }));
            return;
          }

          // Resolve entry path using the directory slug (canonical), not the
          // manifest's self-declared `unit` field, which can diverge from it.
          // For packets, resolve from .claude/human-review/, not microworlds/.
          let bundlePath;
          if (bundle.source === 'packet') {
            bundlePath = path.join(projectRoot, '.claude', 'human-review', bundle.dirSlug);
          } else {
            bundlePath = path.join(projectRoot, 'microworlds', bundle.dirSlug);
          }
          const entryPath = path.join(bundlePath, fn.entry);

          // Get timeout from manifest (default 60)
          const timeoutSeconds = bundle.timeoutSeconds || 60;

          // Invoke
          const result = await invoke(entryPath, bundlePath, timeoutSeconds, inputs, projectRoot);

          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify(result));
        } catch (err) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'invalid request', message: err.message }));
        }
      });
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
