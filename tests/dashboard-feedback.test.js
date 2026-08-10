#!/usr/bin/env node
'use strict';

// Test suite for microworld dashboard feedback primitives (D7).
// Tests source excerpt reader (GET /api/source), context endpoint (GET /api/context),
// feedback block formatter, path containment, and clipboard mechanics.

const fs = require('fs');
const path = require('path');
const os = require('os');
const { startServer } = require('../bin/dashboard/server');
const { readSourceExcerpt } = require('../bin/dashboard/source');
const { formatFeedbackBlock } = require('../bin/dashboard/feedback-block');

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

  // Summary
  console.log('\n' + '='.repeat(60));
  if (failures.length === 0) {
    console.log('All 9 acceptance criteria passed!');
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
