#!/usr/bin/env node
'use strict';

// Test suite for the microworld dashboard client (index.html).
// Tests: (a) auth, (b) content requirements, (c) no external scripts, (d) token requirement

const fs = require('fs');
const path = require('path');
const os = require('os');
const http = require('http');
const { startServer } = require('../bin/dashboard/server');

const REPO_ROOT = path.resolve(__dirname, '..');

function httpRequest(url, { token, method = 'GET' } = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      port: urlObj.port,
      path: urlObj.pathname + urlObj.search,
      method,
      headers: token ? { 'X-Antislop-Token': token } : {},
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk.toString();
      });
      res.on('end', () => {
        resolve({ status: res.statusCode, body: data, headers: res.headers });
      });
    });

    req.on('error', reject);
    req.end();
  });
}

async function runTests() {
  const failures = [];

  // Test (a): GET / with valid token returns 200 and Content-Type text/html
  console.log('Test (a): GET / with valid token...');
  try {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dashboard-client-test-a-'));
    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const result = await httpRequest(`http://127.0.0.1:${addr.port}/?t=${token}`);

    if (result.status !== 200) {
      failures.push(`Test (a) FAILED: expected 200, got ${result.status}`);
    }
    const contentType = result.headers['content-type'] || '';
    if (!contentType.includes('text/html')) {
      failures.push(`Test (a) FAILED: expected Content-Type text/html, got ${contentType}`);
    }
    if (result.body.length === 0) {
      failures.push(`Test (a) FAILED: response body is empty`);
    } else if (failures.filter((f) => f.includes('Test (a)')).length === 0) {
      console.log('  ✓ Test (a) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (a) ERROR: ${err.message}`);
  }

  // Test (b): served HTML contains /api/bundles and /api/invoke
  console.log('Test (b): HTML contains required API references...');
  try {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dashboard-client-test-b-'));
    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const result = await httpRequest(`http://127.0.0.1:${addr.port}/?t=${token}`);

    if (!result.body.includes('/api/bundles')) {
      failures.push(`Test (b) FAILED: HTML does not contain '/api/bundles'`);
    }
    if (!result.body.includes('/api/invoke')) {
      failures.push(`Test (b) FAILED: HTML does not contain '/api/invoke'`);
    }

    if (failures.filter((f) => f.includes('Test (b)')).length === 0) {
      console.log('  ✓ Test (b) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (b) ERROR: ${err.message}`);
  }

  // Test (c): no external script src (no http:// or https://)
  console.log('Test (c): no external script src...');
  try {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dashboard-client-test-c-'));
    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const result = await httpRequest(`http://127.0.0.1:${addr.port}/?t=${token}`);

    const externalScriptRegex = /<script[^>]+src=["'](?:https?:\/\/|\/\/)[^"']*["'][^>]*>/g;
    const matches = result.body.match(externalScriptRegex);
    if (matches && matches.length > 0) {
      failures.push(`Test (c) FAILED: found external script src: ${matches.join(', ')}`);
    } else if (failures.filter((f) => f.includes('Test (c)')).length === 0) {
      console.log('  ✓ Test (c) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (c) ERROR: ${err.message}`);
  }

  // Test (d): GET / with no token returns 401
  console.log('Test (d): GET / without token returns 401...');
  try {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dashboard-client-test-d-'));
    const { server } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const result = await httpRequest(`http://127.0.0.1:${addr.port}/`);

    if (result.status !== 401) {
      failures.push(`Test (d) FAILED: expected 401, got ${result.status}`);
    } else if (failures.filter((f) => f.includes('Test (d)')).length === 0) {
      console.log('  ✓ Test (d) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (d) ERROR: ${err.message}`);
  }

  console.log();
  if (failures.length > 0) {
    console.error('FAILURES:');
    failures.forEach((f) => console.error('  ' + f));
    process.exit(1);
  } else {
    console.log('All tests passed!');
    process.exit(0);
  }
}

runTests().catch((err) => {
  console.error('Test suite error:', err);
  process.exit(1);
});
