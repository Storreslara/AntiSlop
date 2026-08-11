#!/usr/bin/env node
'use strict';

// Test suite for microworld dashboard feedback primitives (D7).
// Tests source excerpt reader (GET /api/source), context endpoint (GET /api/context),
// feedback block formatter, path containment, and clipboard mechanics.

const fs = require('fs');
const path = require('path');
const os = require('os');
const vm = require('vm');
const { startServer } = require('../bin/microworld-dashboard/server');
const { readSourceExcerpt } = require('../bin/microworld-dashboard/source');
const { formatFeedbackBlock } = require('../bin/microworld-dashboard/feedback-block');

const REPO_ROOT = path.resolve(__dirname, '..');

function makeTestProject(name) {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), `dashboard-feedback-test-${name}-`));
  const microworldsDir = path.join(tmpDir, 'microworlds');
  fs.mkdirSync(microworldsDir);
  return tmpDir;
}

function makeBundle(tmpDir, unitSlug, withLocation = true) {
  const bundleDir = path.join(tmpDir, 'microworlds', unitSlug);
  fs.mkdirSync(bundleDir, { recursive: true });

  const location = withLocation ? { file: 'src/index.js', startLine: 10, endLine: 15 } : undefined;

  const manifest = {
    unit: unitSlug,
    description: `Test bundle for ${unitSlug}`,
    functions: [
      {
        id: 'test-fn',
        group: 'TestClass',
        label: 'Test Function',
        entry: 'test-entry.sh',
        description: 'A test function entry',
        ...(location && { location }),
        inputs: [{ name: 'input1', type: 'string', description: 'An input' }],
      },
    ],
  };

  // Create an executable entry
  const entryPath = path.join(bundleDir, 'test-entry.sh');
  fs.writeFileSync(entryPath, '#!/bin/bash\necho "test"');
  fs.chmodSync(entryPath, 0o755);

  const manifestPath = path.join(bundleDir, 'manifest.json');
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));

  return bundleDir;
}

function httpRequest(url, { token, method = 'GET', body = null } = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      port: urlObj.port,
      path: urlObj.pathname + urlObj.search,
      method,
      headers: {},
    };

    if (token) {
      options.headers['X-Antislop-Token'] = token;
    }

    if (body) {
      options.headers['Content-Type'] = 'application/json';
    }

    const req = require('http').request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        resolve({ status: res.statusCode, body: data, headers: res.headers });
      });
    });

    req.on('error', reject);
    if (body) {
      req.write(typeof body === 'string' ? body : JSON.stringify(body));
    }
    req.end();
  });
}

async function runTests() {
  const failures = [];

  // Test (a): GET /api/context returns git HEAD SHA
  console.log('Test (a): GET /api/context returns git HEAD SHA...');
  try {
    const tmpDir = makeTestProject('a');
    // Use REPO_ROOT as the projectRoot for server, since it needs to be a git repo
    const { server, token } = startServer(REPO_ROOT, 0);
    await new Promise((r) => setTimeout(r, 100));

    try {
      const response = await httpRequest(
        `http://127.0.0.1:${server.address().port}/api/context?t=${token}`,
        { token }
      );

      if (response.status !== 200) {
        throw new Error(`Expected 200, got ${response.status}`);
      }

      const data = JSON.parse(response.body);
      if (!data.sha || typeof data.sha !== 'string' || data.sha.length < 7) {
        throw new Error(`Invalid SHA format: ${JSON.stringify(data)}`);
      }

      // Verify it matches git rev-parse HEAD
      const { execSync } = require('child_process');
      const gitSha = execSync('git rev-parse HEAD', { cwd: REPO_ROOT, encoding: 'utf8' }).trim();
      if (data.sha !== gitSha) {
        throw new Error(`Returned SHA ${data.sha} does not match git HEAD ${gitSha}`);
      }

      console.log('  ✓ GET /api/context returns correct git HEAD SHA');
    } finally {
      server.close();
    }
  } catch (err) {
    console.log('  ✗ ' + err.message);
    failures.push('(a) GET /api/context');
  }

  // Test (b): GET /api/source with valid location returns exact line range
  console.log('Test (b): GET /api/source returns exact declared line range...');
  try {
    const tmpDir = makeTestProject('b');
    makeBundle(tmpDir, 'test-b');

    // Create source file with specific lines
    const srcDir = path.join(tmpDir, 'src');
    fs.mkdirSync(srcDir);
    const srcFile = path.join(srcDir, 'index.js');
    const lines = [];
    for (let i = 1; i <= 30; i++) {
      lines.push(`line ${i}`);
    }
    fs.writeFileSync(srcFile, lines.join('\n'));

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    try {
      const response = await httpRequest(
        `http://127.0.0.1:${server.address().port}/api/source?file=src/index.js&startLine=10&endLine=15&t=${token}`,
        { token }
      );

      if (response.status !== 200) {
        throw new Error(`Expected 200, got ${response.status}: ${response.body}`);
      }

      const data = JSON.parse(response.body);
      const returnedLines = data.lines || [];

      // Verify exact line range (10-15 inclusive)
      if (returnedLines.length !== 6) {
        throw new Error(`Expected 6 lines, got ${returnedLines.length}`);
      }

      if (returnedLines[0] !== 'line 10') {
        throw new Error(`First line incorrect: expected 'line 10', got '${returnedLines[0]}'`);
      }

      if (returnedLines[5] !== 'line 15') {
        throw new Error(`Last line incorrect: expected 'line 15', got '${returnedLines[5]}'`);
      }

      console.log('  ✓ GET /api/source returns exact declared line range');
    } finally {
      server.close();
    }
  } catch (err) {
    console.log('  ✗ ' + err.message);
    failures.push('(b) GET /api/source exact range');
  }

  // Test (c): PATH-TRAVERSAL PROOF: reject ../../etc/passwd and absolute paths
  console.log('Test (c): PATH-TRAVERSAL PROOF: reject ../../etc/passwd and absolute paths...');
  try {
    const tmpDir = makeTestProject('c');
    makeBundle(tmpDir, 'test-c');

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    try {
      // Test relative path traversal
      const response1 = await httpRequest(
        `http://127.0.0.1:${server.address().port}/api/source?file=../../etc/passwd&startLine=1&endLine=10&t=${token}`,
        { token }
      );

      if (response1.status !== 400) {
        throw new Error(`Relative traversal: Expected 400, got ${response1.status}`);
      }

      // Test absolute path
      const response2 = await httpRequest(
        `http://127.0.0.1:${server.address().port}/api/source?file=/etc/passwd&startLine=1&endLine=10&t=${token}`,
        { token }
      );

      if (response2.status !== 400) {
        throw new Error(`Absolute path: Expected 400, got ${response2.status}`);
      }

      console.log('  ✓ PATH-TRAVERSAL protection working: rejects traversal and absolute paths');
    } finally {
      server.close();
    }
  } catch (err) {
    console.log('  ✗ ' + err.message);
    failures.push('(c) PATH-TRAVERSAL proof');
  }

  // Test (d): Nonexistent file and out-of-range startLine return 404 with stated reason
  console.log('Test (d): Nonexistent file and out-of-range lines return 404 with stated reason...');
  try {
    const tmpDir = makeTestProject('d');
    makeBundle(tmpDir, 'test-d');

    const srcDir = path.join(tmpDir, 'src');
    fs.mkdirSync(srcDir);
    const srcFile = path.join(srcDir, 'index.js');
    fs.writeFileSync(srcFile, 'line 1\nline 2\nline 3\n');

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    try {
      // Test nonexistent file
      const response1 = await httpRequest(
        `http://127.0.0.1:${server.address().port}/api/source?file=nonexistent.js&startLine=1&endLine=10&t=${token}`,
        { token }
      );

      if (response1.status !== 404) {
        throw new Error(`Nonexistent file: Expected 404, got ${response1.status}`);
      }

      const data1 = JSON.parse(response1.body);
      if (!data1.error || typeof data1.error !== 'string') {
        throw new Error(`Nonexistent file: No stated reason in response: ${response1.body}`);
      }

      // Test startLine beyond EOF
      const response2 = await httpRequest(
        `http://127.0.0.1:${server.address().port}/api/source?file=src/index.js&startLine=100&endLine=110&t=${token}`,
        { token }
      );

      if (response2.status !== 404) {
        throw new Error(`StartLine beyond EOF: Expected 404, got ${response2.status}`);
      }

      const data2 = JSON.parse(response2.body);
      if (!data2.error || typeof data2.error !== 'string') {
        throw new Error(`StartLine beyond EOF: No stated reason in response: ${response2.body}`);
      }

      console.log('  ✓ 404 with stated reasons for nonexistent file and out-of-range lines');
    } finally {
      server.close();
    }
  } catch (err) {
    console.log('  ✗ ' + err.message);
    failures.push('(d) 404 with stated reason');
  }

  // Test (e): endLine far beyond cap returns at most capped number of lines
  console.log('Test (e): endLine far beyond cap returns at most capped lines...');
  try {
    const tmpDir = makeTestProject('e');
    makeBundle(tmpDir, 'test-e');

    const srcDir = path.join(tmpDir, 'src');
    fs.mkdirSync(srcDir);
    const srcFile = path.join(srcDir, 'index.js');
    const lines = [];
    for (let i = 1; i <= 500; i++) {
      lines.push(`line ${i}`);
    }
    fs.writeFileSync(srcFile, lines.join('\n'));

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    try {
      const response = await httpRequest(
        `http://127.0.0.1:${server.address().port}/api/source?file=src/index.js&startLine=1&endLine=9999&t=${token}`,
        { token }
      );

      if (response.status !== 200) {
        throw new Error(`Expected 200, got ${response.status}`);
      }

      const data = JSON.parse(response.body);
      const returnedLines = data.lines || [];

      // Should be capped (e.g., 400 lines)
      if (returnedLines.length > 400) {
        throw new Error(`Expected at most 400 lines, got ${returnedLines.length}`);
      }

      console.log(`  ✓ EndLine capping works: returned ${returnedLines.length} lines (max 400)`);
    } finally {
      server.close();
    }
  } catch (err) {
    console.log('  ✗ ' + err.message);
    failures.push('(e) EndLine capping');
  }

  // Test (f): GET /api/source and GET /api/context with no token return 401
  console.log('Test (f): GET /api/source and GET /api/context with no token return 401...');
  try {
    const tmpDir = makeTestProject('f');
    makeBundle(tmpDir, 'test-f');

    const { server } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    try {
      const response1 = await httpRequest(
        `http://127.0.0.1:${server.address().port}/api/source?file=src/index.js&startLine=1&endLine=10`
      );

      if (response1.status !== 401) {
        throw new Error(`/api/source no token: Expected 401, got ${response1.status}`);
      }

      const response2 = await httpRequest(
        `http://127.0.0.1:${server.address().port}/api/context`
      );

      if (response2.status !== 401) {
        throw new Error(`/api/context no token: Expected 401, got ${response2.status}`);
      }

      console.log('  ✓ Both endpoints return 401 with no token');
    } finally {
      server.close();
    }
  } catch (err) {
    console.log('  ✗ ' + err.message);
    failures.push('(f) 401 without token');
  }

  // Test (g): Formatter reproduces comment with backticks and fenced blocks byte-for-byte
  console.log('Test (g): Formatter reproduces comment byte-for-byte...');
  try {
    const comment = 'Test with `backticks` and code:\n```javascript\nconst x = 1;\n```\nEnd.';

    const context = {
      unitSlug: 'test-unit',
      functionId: 'test-fn',
      functionGroup: 'TestClass',
      functionLabel: 'Test Function',
      comment,
      sha: 'abc123def456',
      // No location means "location: not declared"
      // No cell means no "### Last run"
    };

    const block = formatFeedbackBlock(context);

    if (!block.includes(comment)) {
      throw new Error(`Comment not reproduced verbatim. Got:\n${block}`);
    }

    // Verify exact substring match
    if (block.indexOf(comment) === -1) {
      throw new Error(`Comment not byte-for-byte identical in formatted block`);
    }

    console.log('  ✓ Comment reproduced byte-for-byte');
  } catch (err) {
    console.log('  ✗ ' + err.message);
    failures.push('(g) Comment byte-for-byte reproduction');
  }

  // Test (h): Function with no location produces "location: not declared"
  console.log('Test (h): Function with no location produces "location: not declared"...');
  try {
    const context = {
      unitSlug: 'test-unit',
      functionId: 'test-fn-no-loc',
      functionGroup: 'TestClass',
      functionLabel: 'No Location Function',
      comment: 'Test comment',
      sha: 'abc123',
      // No location specified
    };

    const block = formatFeedbackBlock(context);

    if (!block.includes('location: not declared')) {
      throw new Error(`Expected "location: not declared" in block, got:\n${block}`);
    }

    console.log('  ✓ "location: not declared" present for function with no location');
  } catch (err) {
    console.log('  ✗ ' + err.message);
    failures.push('(h) "location: not declared"');
  }

  // Test (i): Function vs cell: no "### Last run" for function, present for cell
  console.log('Test (i): Function has no "### Last run"; cell has it...');
  try {
    // Test (i.a): Function with no run (no cell)
    const contextFn = {
      unitSlug: 'test-unit',
      functionId: 'test-fn',
      functionGroup: 'TestClass',
      functionLabel: 'Test Function',
      comment: 'Test',
      sha: 'abc123',
      location: { file: 'src/index.js', startLine: 10, endLine: 15 },
      // No cell information
    };

    const blockFn = formatFeedbackBlock(contextFn);

    if (blockFn.includes('### Last run')) {
      throw new Error(`Function should not have "### Last run" section`);
    }

    // Test (i.b): Cell with run information
    const contextCell = {
      unitSlug: 'test-unit',
      functionId: 'test-fn',
      functionGroup: 'TestClass',
      functionLabel: 'Test Function',
      comment: 'Test',
      sha: 'abc123',
      location: { file: 'src/index.js', startLine: 10, endLine: 15 },
      cell: {
        inputs: { input1: 'value1' },
        result: {
          exitCode: 0,
          durationMs: 100,
          stdout: 'output',
        },
      },
    };

    const blockCell = formatFeedbackBlock(contextCell);

    if (!blockCell.includes('### Last run')) {
      throw new Error(`Cell should have "### Last run" section: ${blockCell}`);
    }

    if (!blockCell.includes('inputs:')) {
      throw new Error(`Cell "### Last run" should include inputs`);
    }

    if (!blockCell.includes('exit:')) {
      throw new Error(`Cell "### Last run" should include exit code`);
    }

    if (!blockCell.includes('duration:')) {
      throw new Error(`Cell "### Last run" should include duration`);
    }

    console.log('  ✓ Function has no "### Last run"; cell has it with proper fields');
  } catch (err) {
    console.log('  ✗ ' + err.message);
    failures.push('(i) Function vs cell "### Last run"');
  }

  // ---- Fix-pass additions (gh320): one test per FAIL-verdict defect ----

  // Test (j) SYMLINK ESCAPE PROOF (D1): a symlink living inside the project
  // root but pointing outside it must be rejected with 400, not followed.
  // Mutation check: reverting D1 (comparing only lexical, non-realpath'd
  // paths) makes this go green with a 200 and leaked content -- i.e. this
  // test is red without the fix.
  console.log('Test (j): SYMLINK ESCAPE PROOF: symlink inside root pointing outside root returns 400...');
  try {
    const tmpDir = makeTestProject('j');
    makeBundle(tmpDir, 'test-j');

    const outsideDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dashboard-feedback-test-j-outside-'));
    fs.writeFileSync(path.join(outsideDir, 'secret.txt'), 'SENTINEL_SECRET_LINE_ONE\nSENTINEL_SECRET_LINE_TWO\n');
    fs.symlinkSync(path.join(outsideDir, 'secret.txt'), path.join(tmpDir, 'innocent.txt'));

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    try {
      const response = await httpRequest(
        `http://127.0.0.1:${server.address().port}/api/source?file=innocent.txt&startLine=1&endLine=2&t=${token}`,
        { token }
      );

      if (response.status !== 400) {
        throw new Error(`Symlink escape: Expected 400, got ${response.status}: ${response.body}`);
      }
      if (response.body.includes('SENTINEL_SECRET')) {
        throw new Error(`Symlink escape: secret content leaked into response: ${response.body}`);
      }

      console.log('  ✓ Symlink escaping project root rejected with 400, no content leaked');
    } finally {
      server.close();
    }
  } catch (err) {
    console.log('  ✗ ' + err.message);
    failures.push('(j) SYMLINK ESCAPE proof');
  }

  // Test (k) endLine < startLine (D2): must be a 404 with a stated reason,
  // never a silent 200 with an empty lines array.
  console.log('Test (k): endLine < startLine returns 404 with stated reason...');
  try {
    const tmpDir = makeTestProject('k');
    makeBundle(tmpDir, 'test-k');

    const srcDir = path.join(tmpDir, 'src');
    fs.mkdirSync(srcDir);
    fs.writeFileSync(path.join(srcDir, 'index.js'), 'line 1\nline 2\nline 3\nline 4\nline 5\n');

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    try {
      const response = await httpRequest(
        `http://127.0.0.1:${server.address().port}/api/source?file=src/index.js&startLine=4&endLine=2&t=${token}`,
        { token }
      );

      if (response.status !== 404) {
        throw new Error(`endLine<startLine: Expected 404, got ${response.status}: ${response.body}`);
      }

      const data = JSON.parse(response.body);
      if (!data.error || typeof data.error !== 'string') {
        throw new Error(`endLine<startLine: no stated reason in response: ${response.body}`);
      }
      if (data.success === true) {
        throw new Error(`endLine<startLine: response reports success:true: ${response.body}`);
      }

      console.log('  ✓ endLine < startLine returns 404 with a stated reason (never a silent empty 200)');
    } finally {
      server.close();
    }
  } catch (err) {
    console.log('  ✗ ' + err.message);
    failures.push('(k) endLine < startLine 404');
  }

  // Test (l) TRUNCATION MARKER (D5): the fixed block shape requires an
  // explicit marker in the fenced output when cell.result.truncated is true.
  console.log('Test (l): explicit truncation marker present only when cell.result.truncated is true...');
  try {
    const truncatedContext = {
      unitSlug: 'test-unit',
      functionId: 'test-fn',
      functionGroup: 'TestClass',
      functionLabel: 'Test Function',
      comment: 'Test',
      sha: 'abc123',
      cell: {
        inputs: { input1: 'value1' },
        result: { exitCode: 0, durationMs: 100, stdout: 'partial output', truncated: true },
      },
    };
    const notTruncatedContext = JSON.parse(JSON.stringify(truncatedContext));
    notTruncatedContext.cell.result.truncated = false;

    const blockTruncated = formatFeedbackBlock(truncatedContext);
    const blockNotTruncated = formatFeedbackBlock(notTruncatedContext);

    if (!blockTruncated.includes('output truncated')) {
      throw new Error(`Expected an explicit truncation marker, got:\n${blockTruncated}`);
    }
    if (blockNotTruncated.includes('output truncated')) {
      throw new Error(`Non-truncated block should not contain a truncation marker: ${blockNotTruncated}`);
    }

    console.log('  ✓ Explicit truncation marker present only when cell.result.truncated is true');
  } catch (err) {
    console.log('  ✗ ' + err.message);
    failures.push('(l) Truncation marker');
  }

  // Test (m) SHIPPED CLIENT ACTUALLY USES THE REAL FORMATTER, THE PER-CELL
  // BOX EXISTS, AND "### Last run" IS SCOPED CORRECTLY (D3 + D4, and the
  // claim D6 rests on). Loads the ACTUAL served HTML via a real HTTP
  // request -- so server.js's injection genuinely runs -- and evaluates
  // BOTH the injected classic <script> (defines formatFeedbackBlock as a
  // page global) and the <script type="module"> app code in the SAME vm
  // context, exactly as a browser shares globals between two <script> tags.
  // Then drives a real invoke plus two distinct "Copy Feedback" clicks
  // (function-scoped, then cell-scoped) through the actual client code path.
  console.log('Test (m): shipped client renders per-cell comment box, uses the real formatter, and scopes "### Last run" correctly...');
  try {
    const tmpDir = makeTestProject('m');
    makeBundle(tmpDir, 'test-m');
    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    try {
      const pageResponse = await httpRequest(
        `http://127.0.0.1:${server.address().port}/?t=${token}`,
        { token }
      );
      if (pageResponse.status !== 200) {
        throw new Error(`GET / expected 200, got ${pageResponse.status}`);
      }
      const html = pageResponse.body;

      const classicMatch = html.match(/<script>([\s\S]*?)<\/script>/);
      const moduleMatch = html.match(/<script type="module">([\s\S]*?)<\/script>/);
      if (!classicMatch) throw new Error('could not find injected classic <script> in served HTML');
      if (!moduleMatch) throw new Error('could not find inline module <script> in served HTML');
      if (!classicMatch[1].includes('function formatFeedbackBlock')) {
        throw new Error('served HTML classic script does not contain the real formatFeedbackBlock source -- injection missing');
      }

      const fn = {
        id: 'test-fn',
        group: 'TestClass',
        label: 'Test Function',
        entry: 'test-entry.sh',
        description: 'A test function entry',
        location: { file: 'src/index.js', startLine: 10, endLine: 15 },
        inputs: [{ name: 'input1', type: 'string' }],
      };
      const bundlesData = [{
        id: 'test-m',
        unit: 'test-m',
        description: 'Test bundle for test-m',
        status: null,
        functions: [fn],
      }];
      const invokeResult = { exitCode: 0, stdout: 'invoked output', stderr: '', durationMs: 42, truncated: true };

      function makeFakeDiv() {
        return {
          _text: '',
          style: {},
          set textContent(v) { this._text = String(v); },
          get textContent() { return this._text; },
          get innerHTML() { return this._text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); },
        };
      }
      function makeFakeElement() {
        return {
          _html: '',
          style: {},
          set innerHTML(v) { this._html = v; },
          get innerHTML() { return this._html; },
          querySelectorAll: () => [],
          addEventListener: () => {},
        };
      }
      function makeFakeButton(attrs) {
        const listeners = [];
        return {
          _listeners: listeners,
          addEventListener: (type, cb) => { listeners.push({ type, cb }); },
          getAttribute: (name) => (attrs && attrs[name] !== undefined ? attrs[name] : null),
        };
      }
      function makeFakeForm(inputs) {
        const elements = {};
        for (const input of inputs) {
          elements[input.name] = { value: input.default !== undefined ? String(input.default) : 'x' };
        }
        const submitBtn = { textContent: 'Invoke', disabled: false };
        const listeners = [];
        return {
          elements,
          _listeners: listeners,
          querySelector: (sel) => (sel === 'button[type="submit"]' ? submitBtn : null),
          addEventListener: (type, cb) => { listeners.push({ type, cb }); },
        };
      }

      const leftRail = makeFakeElement();
      const contentArea = makeFakeElement();
      const outputPane = makeFakeElement();
      const inputForm = makeFakeForm(fn.inputs);
      const commentBox = { value: 'function-level comment' };
      const copyFeedbackBtn = makeFakeButton();
      const copyFeedbackDiv = makeFakeDiv();
      const clipboardFallback = { value: '' };
      const cellCommentBox = { value: 'cell-level comment' };
      const cellCopyFeedbackDiv = makeFakeDiv();
      const cellClipboardFallback = { value: '' };

      const elementsById = {
        leftRail, contentArea, outputPane, inputForm,
        commentBox, copyFeedbackBtn, copyFeedback: copyFeedbackDiv, clipboardFallback,
        'cell-comment-0': cellCommentBox,
        'cell-copy-feedback-0': cellCopyFeedbackDiv,
        'cell-clipboard-fallback-0': cellClipboardFallback,
      };

      let lastCellCopyBtn = null;
      const clipboardWrites = [];

      const sandbox = {
        document: {
          getElementById: (id) => elementsById[id] || null,
          createElement: () => makeFakeDiv(),
          querySelectorAll: (selector) => {
            if (selector === '.cell-copy-btn') {
              const b = makeFakeButton({ 'data-fn-id': fn.id, 'data-cell-id': '0' });
              lastCellCopyBtn = b;
              return [b];
            }
            if (['.cell-edit-btn', '.cell-toggle-btn', '.cell-remove-btn'].includes(selector)) {
              return [makeFakeButton({ 'data-fn-id': fn.id, 'data-cell-id': '0' })];
            }
            return [];
          },
        },
        location: { search: '' },
        URLSearchParams,
        console,
        navigator: {
          clipboard: {
            writeText: async (text) => { clipboardWrites.push(text); },
          },
        },
        fetch: async (url) => {
          if (url === '/api/bundles') return { ok: true, status: 200, json: async () => bundlesData };
          if (url === '/api/invoke') return { ok: true, status: 200, json: async () => invokeResult };
          if (url === '/api/context') return { ok: true, status: 200, json: async () => ({ sha: 'deadbeefcafe' }) };
          return { ok: false, status: 404, json: async () => ({ error: 'not found' }) };
        },
        alert: () => {},
        setInterval: () => {},
        clearInterval: () => {},
        setTimeout: () => {},
      };
      vm.createContext(sandbox);
      // Classic script first (defines formatFeedbackBlock as a page global),
      // then the module script -- same order and same shared global object a
      // browser gives two <script> tags on one page.
      vm.runInContext(classicMatch[1], sandbox);
      vm.runInContext(moduleMatch[1], sandbox);
      await new Promise((r) => setTimeout(r, 50));

      const submitListener = inputForm._listeners.find((l) => l.type === 'submit');
      if (!submitListener) throw new Error('submit listener never attached to inputForm');
      await submitListener.cb({ preventDefault: () => {} });

      // STRUCTURAL PROOF (D3): the actually-rendered cell HTML must contain
      // a per-cell comment textarea and copy button with per-instance ids --
      // not just "attachCellEventListeners queried a selector that returned
      // something", which the stubbed querySelectorAll above would satisfy
      // even if renderCell emitted no such markup at all.
      const renderedCellHtml = outputPane.innerHTML;
      if (!renderedCellHtml.includes('id="cell-comment-0"')) {
        throw new Error(`renderCell did not emit a per-cell comment textarea (id="cell-comment-0"): ${renderedCellHtml.slice(0, 500)}`);
      }
      if (!renderedCellHtml.includes('class="cell-copy-btn"')) {
        throw new Error(`renderCell did not emit a per-cell "Copy Feedback" button (class="cell-copy-btn"): ${renderedCellHtml.slice(0, 500)}`);
      }

      // Function-scoped copy: click id="copyFeedbackBtn"'s listener.
      const fnCopyListener = copyFeedbackBtn._listeners.find((l) => l.type === 'click');
      if (!fnCopyListener) throw new Error('function-level copy button never wired a click listener');
      await fnCopyListener.cb({ preventDefault: () => {} });

      if (clipboardWrites.length !== 1) {
        throw new Error(`expected 1 clipboard write after function-level copy, got ${clipboardWrites.length}`);
      }
      const fnBlock = clipboardWrites[0];
      if (fnBlock.includes('### Last run')) {
        throw new Error(`function-level copy must NOT include "### Last run" (D3 inversion): ${fnBlock}`);
      }
      if (!fnBlock.includes('function-level comment')) {
        throw new Error(`function-level copy did not include the function comment box's text: ${fnBlock}`);
      }

      // Cell-scoped copy: click the wired .cell-copy-btn.
      if (!lastCellCopyBtn) throw new Error('no .cell-copy-btn was ever queried/wired');
      const cellCopyListener = lastCellCopyBtn._listeners.find((l) => l.type === 'click');
      if (!cellCopyListener) throw new Error('.cell-copy-btn has no click listener wired');
      await cellCopyListener.cb({ preventDefault: () => {} });

      if (clipboardWrites.length !== 2) {
        throw new Error(`expected 2 clipboard writes after cell-level copy, got ${clipboardWrites.length}`);
      }
      const cellBlock = clipboardWrites[1];
      if (!cellBlock.includes('### Last run')) {
        throw new Error(`cell-level copy must include "### Last run": ${cellBlock}`);
      }
      if (!cellBlock.includes('cell-level comment')) {
        throw new Error(`cell-level copy did not include the per-cell comment box's own text: ${cellBlock}`);
      }
      if (!cellBlock.includes('output truncated')) {
        throw new Error(`cell-level copy did not carry the D5 truncation marker through to the shipped path: ${cellBlock}`);
      }

      // No-duplicate-implementation proof: the cell-level block the shipped
      // client actually produced must be byte-identical to calling
      // formatFeedbackBlock() (the same function required via CommonJS by
      // this test file) with the equivalent context -- proving the client
      // calls the real formatter rather than a hand-reimplemented copy.
      const expectedCellBlock = formatFeedbackBlock({
        unitSlug: 'test-m',
        functionId: 'test-fn',
        functionGroup: 'TestClass',
        functionLabel: 'Test Function',
        comment: 'cell-level comment',
        sha: 'deadbeefcafe',
        location: fn.location,
        cell: { inputs: { input1: 'x' }, result: invokeResult },
      });
      if (cellBlock !== expectedCellBlock) {
        throw new Error(`shipped client's cell-level copy diverges from formatFeedbackBlock()'s own output -- duplicate implementation suspected.\nGot:\n${cellBlock}\nExpected:\n${expectedCellBlock}`);
      }

      console.log('  ✓ per-cell comment box + copy button wired, function-vs-cell "### Last run" scoping correct, shipped client uses the real formatter (no duplicate)');
    } finally {
      server.close();
    }
  } catch (err) {
    console.log('  ✗ ' + err.message);
    failures.push('(m) shipped client integration (D3/D4/D5 wiring)');
  }

  // Summary
  console.log('\n' + '='.repeat(60));
  if (failures.length === 0) {
    console.log('All 9 original acceptance criteria (a)-(i) plus 4 gh320 fix-pass tests (j)-(m) passed!');
    process.exit(0);
  } else {
    console.log(`${failures.length} test(s) failed:`);
    failures.forEach((f) => console.log(`  - ${f}`));
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error('Unexpected error:', err);
  process.exit(1);
});
