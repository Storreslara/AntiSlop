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
const { composeEscalationDecisionBody, assertNoNewline, ID_RE } = require('./decision-block');

// Alphabet for 6-char code generation, excluding visually ambiguous glyphs (0, O, 1, I, l)
const CODE_ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz';

function startServer(projectRoot, port = 0, { ttyWrite, armTtlMs = 120_000 } = {}) {
  const token = crypto.randomBytes(32).toString('hex');
  const microworldsPath = path.join(projectRoot, 'microworlds');

  // Attempt to open /dev/tty for decision write capability
  let ownsTtyFd = false;
  if (ttyWrite === undefined) {
    try {
      ttyWrite = fs.openSync('/dev/tty', 'w');
      ownsTtyFd = true;
    } catch (err) {
      // No controlling terminal (e.g., agent environment or output redirect)
      ttyWrite = null;
    }
  }

  // In-memory record of the most recent arm: { code, taskId, body, expiresAt, used }
  let currentArm = null;

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
          // Same injection pattern for the decision-block composer (gh351).
          const decisionBlockSrc = fs.readFileSync(path.join(__dirname, 'decision-block.js'), 'utf8');
          html = html.replace('/* __DECISION_BLOCK_SOURCE__ */', decisionBlockSrc);
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

    // POST /api/decision/arm
    if (req.method === 'POST' && new URL(req.url, 'http://127.0.0.1').pathname === '/api/decision/arm') {
      let body = '';
      req.on('data', (chunk) => {
        body += chunk.toString();
      });
      req.on('end', () => {
        try {
          // If no tty available, fail closed. Gate on truthiness, not
          // `=== null`: any other falsy value (0, false) must also fail
          // closed rather than silently skipping both the 403 and the tty
          // write -- fs.writeFileSync(0, ...) would otherwise target fd 0
          // (stdin) instead of failing safely (gh380 advisory).
          if (!ttyWrite) {
            res.writeHead(403, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'decision writes require a controlling terminal' }));
            return;
          }

          const data = JSON.parse(body);
          // The request body itself is a client-chosen type. Destructuring
          // a null/array/scalar `data` throws, and the outer catch would
          // hand the client that internal exception message -- same
          // fail-open-on-unexpected-type class as the fields below (gh380).
          if (data === null || typeof data !== 'object' || Array.isArray(data)) {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'invalid request' }));
            return;
          }

          // `by`/`reason` default to '' only when omitted (undefined) --
          // exactly as composeEscalationDecisionBody destructures them, so
          // an omitted field stays legal while an explicit null does not.
          const { taskId, route, escalationTimestamp, by = '', reason = '', quiz } = data;

          // gh380: validate the free-text fields here, at the JSON-parse
          // boundary, and store *these* values into currentArm below. The
          // audit-log sink reads currentArm.by, not the composer's copy, so
          // relying on the composer alone would close that sink only
          // transitively. Same exported guard the composer uses, so there is
          // one place to neuter and one place to fix.
          assertNoNewline(by, 'by');
          assertNoNewline(reason, 'reason');

          // Validate taskId
          try {
            if (typeof taskId !== 'string' || !ID_RE.test(taskId)) {
              throw new Error('invalid taskId format');
            }
          } catch (err) {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: `invalid taskId: ${err.message}` }));
            return;
          }

          // Verify .claude/human-review/<taskId>/ exists (R7: never mkdir -p)
          const packetDir = path.join(projectRoot, '.claude', 'human-review', taskId);
          if (!fs.existsSync(packetDir)) {
            res.writeHead(409, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'packet directory does not exist' }));
            return;
          }

          // Verify escalationTimestamp matches the first line of .claude/reviewed/<taskId>.escalated
          const escalatedPath = path.join(projectRoot, '.claude', 'reviewed', `${taskId}.escalated`);
          let escalatedContent;
          try {
            escalatedContent = fs.readFileSync(escalatedPath, 'utf8');
          } catch (err) {
            res.writeHead(409, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'escalation marker not found' }));
            return;
          }

          const firstLine = escalatedContent.split('\n')[0];
          // Extract timestamp from first line. Real format (matching
          // decisions.js:37's parse of the same marker):
          // "ESCALATE-TO-HUMAN <taskId> <ts> trigger: ... microworld: ...".
          // Field index 0 is always the literal "ESCALATE-TO-HUMAN"; the
          // timestamp is capture group 2 (gh380 D1 fix).
          const markerMatch = firstLine.match(/^ESCALATE-TO-HUMAN (\S+) (\S+) trigger: (.*) microworld: (\S+)$/);
          const markerTimestamp = markerMatch ? markerMatch[2] : null;
          if (markerTimestamp === null || markerTimestamp !== escalationTimestamp) {
            res.writeHead(409, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'escalation timestamp mismatch' }));
            return;
          }

          // Compose the body server-side via composeEscalationDecisionBody
          const bodyResult = composeEscalationDecisionBody({
            taskId,
            route,
            escalationTimestamp,
            by,
            reason,
            quiz,
            via: 'dashboard',
          });

          if (bodyResult.body === null) {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'failed to compose body', warnings: bodyResult.warnings }));
            return;
          }

          // Generate a 6-character code via crypto.randomInt over ambiguous-glyph-free alphabet
          let code = '';
          for (let i = 0; i < 6; i++) {
            code += CODE_ALPHABET[crypto.randomInt(0, CODE_ALPHABET.length)];
          }

          // Write to /dev/tty BEFORE recording the arm and responding. If
          // the human never receives the code, the arm attempt must fail
          // rather than report armed:true (gh380 advisory).
          const validSeconds = Math.round(armTtlMs / 1000);
          const message = `antislop: confirmation code for DECISION ${taskId} is ${code} (valid ${validSeconds}s)\n`;
          try {
            if (typeof ttyWrite === 'number') {
              fs.writeFileSync(ttyWrite, message);
            } else if (ttyWrite && typeof ttyWrite.write === 'function') {
              ttyWrite.write(message);
            } else {
              throw new Error('ttyWrite is neither a file descriptor nor a writable stub');
            }
          } catch (err) {
            res.writeHead(502, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'failed to deliver confirmation code to /dev/tty' }));
            return;
          }

          // Replace any prior arm with a single in-memory record
          currentArm = {
            code,
            taskId,
            body: bodyResult.body,
            route,
            by,
            expiresAt: Date.now() + armTtlMs,
            used: false,
          };

          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ armed: true, expiresInMs: armTtlMs }));
        } catch (err) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'invalid request', message: err.message }));
        }
      });
      return;
    }

    // POST /api/decision/run
    if (req.method === 'POST' && new URL(req.url, 'http://127.0.0.1').pathname === '/api/decision/run') {
      let body = '';
      req.on('data', (chunk) => {
        body += chunk.toString();
      });
      req.on('end', () => {
        try {
          // If no tty available, fail closed. Gate on truthiness, not
          // `=== null`: any other falsy value (0, false) must also fail
          // closed rather than silently skipping both the 403 and the tty
          // write -- fs.writeFileSync(0, ...) would otherwise target fd 0
          // (stdin) instead of failing safely (gh380 advisory).
          if (!ttyWrite) {
            res.writeHead(403, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'decision writes require a controlling terminal' }));
            return;
          }

          const data = JSON.parse(body);
          // See the arm handler: a non-object body must not reach the
          // destructure, whose TypeError the outer catch would echo back as
          // internal exception text (gh380).
          if (data === null || typeof data !== 'object' || Array.isArray(data)) {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'invalid request' }));
            return;
          }

          const { taskId, code } = data;

          // Verify arm exists and matches taskId
          if (!currentArm || currentArm.taskId !== taskId) {
            res.writeHead(409, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'no matching arm' }));
            return;
          }

          // Check expiry
          if (Date.now() > currentArm.expiresAt) {
            currentArm = null;
            res.writeHead(409, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'confirmation code expired' }));
            return;
          }

          // Check if already used
          if (currentArm.used) {
            res.writeHead(409, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'confirmation code already used' }));
            return;
          }

          // Compare code with timing-safe equality after a type + length
          // check. The type half is not decoration: `code: null` otherwise
          // throws a TypeError on `.length` that the outer catch renders
          // into the response as internal exception text (gh380, same
          // type-confusion class as by/reason).
          if (typeof code !== 'string' || code.length !== currentArm.code.length) {
            res.writeHead(409, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'invalid code' }));
            currentArm = null;
            return;
          }

          try {
            if (!crypto.timingSafeEqual(Buffer.from(code), Buffer.from(currentArm.code))) {
              res.writeHead(409, { 'Content-Type': 'application/json' });
              res.end(JSON.stringify({ error: 'invalid code' }));
              currentArm = null;
              return;
            }
          } catch (err) {
            res.writeHead(409, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'invalid code' }));
            currentArm = null;
            return;
          }

          // Mark used BEFORE writing
          currentArm.used = true;

          // Write the DECISION file with wx flag (never overwrite)
          const decisionPath = path.join(projectRoot, '.claude', 'human-review', taskId, 'DECISION');
          try {
            fs.writeFileSync(decisionPath, currentArm.body, { flag: 'wx', mode: 0o600 });
          } catch (err) {
            if (err.code === 'EEXIST') {
              res.writeHead(409, { 'Content-Type': 'application/json' });
              res.end(JSON.stringify({ error: 'DECISION file already exists' }));
              currentArm = null;
              return;
            }
            throw err;
          }

          // Append to .claude/review-audit.log. The three interpolated
          // values were each constrained before currentArm was built:
          // taskId by ID_RE (no whitespace), route by the composer's ROUTES
          // allowlist, and `by` by assertNoNewline at the arm parse
          // boundary (string type, no CR/LF) -- so this template renders
          // one line (gh380 D3).
          const auditPath = path.join(projectRoot, '.claude', 'review-audit.log');
          const auditLine = `${new Date().toISOString()} decision-write-via-dashboard task=${taskId} route=${currentArm.route} by=${currentArm.by}\n`;
          // A failed append must not be silently swallowed (gh380
          // advisory): the DECISION file write already succeeded and
          // cannot be un-written under R7's never-overwrite rule, so the
          // response still reports written:true, but auditLogged:false
          // tells the caller the write happened without an audit trail.
          let auditLogged = true;
          try {
            fs.appendFileSync(auditPath, auditLine);
          } catch (err) {
            auditLogged = false;
          }

          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ written: true, auditLogged }));

          // Clear arm after successful write
          currentArm = null;
        } catch (err) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'invalid request', message: err.message }));
          currentArm = null;
        }
      });
      return;
    }

    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not found\n');
  });

  // Close the self-opened /dev/tty fd when the server shuts down -- it is
  // never closed otherwise, leaking one fd per startServer call under a
  // real terminal (gh380 advisory). Only close a fd this function opened;
  // never an injected handle (test stub or a fd the caller still owns).
  if (ownsTtyFd) {
    server.on('close', () => {
      try {
        fs.closeSync(ttyWrite);
      } catch (err) {
        // already closed or invalid; nothing to do
      }
    });
  }

  server.listen(port, '127.0.0.1', () => {
    const addr = server.address();
    console.log(`http://127.0.0.1:${addr.port}/?t=${token}`);
  });

  return { server, token };
}

module.exports = { startServer };
