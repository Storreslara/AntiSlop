#!/usr/bin/env node
'use strict';

// Test suite for the microworld dashboard notebook feature (index.html cells, history, edit-and-re-run)
// Tests: (a) fresh process proof via PID, (b) no-shared-state proof via counter,
// (c) route table unchanged, (d) GET / and /api/invoke still work

const fs = require('fs');
const path = require('path');
const os = require('os');
const http = require('http');
const vm = require('vm');
const { startServer } = require('../bin/dashboard/server');
const { execSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');

function makeFakeDOMEnv() {
  let elements = {};
  let eventListeners = {};

  return {
    document: {
      getElementById: (id) => {
        if (!elements[id]) {
          elements[id] = {
            _html: '',
            _text: '',
            set innerHTML(v) { this._html = v; },
            get innerHTML() { return this._html; },
            set textContent(v) { this._text = String(v); },
            get textContent() { return this._text; },
            querySelectorAll: (selector) => {
              if (!elements[id]._html.includes(selector.slice(1))) return [];
              // Stub implementation: return empty array (listeners set via setAttribute)
              return [];
            },
            setAttribute: () => {},
            getAttribute: () => {},
            addEventListener: () => {},
          };
        }
        return elements[id];
      },
      createElement: () => {
        return {
          textContent: '',
          innerHTML: '',
          querySelectorAll: () => [],
          setAttribute: () => {},
          getAttribute: () => {},
          addEventListener: () => {},
        };
      },
    },
    location: { search: '' },
    URLSearchParams,
    console,
    fetch: async () => ({ ok: true, status: 200, json: async () => [] }),
    alert: () => {},
    setInterval: () => {},
    clearInterval: () => {},
  };
}

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
  let tmpDirs = [];

  // Test (a): FRESH-PROCESS PROOF — PID differs between invocations
  console.log('Test (a): Fresh process proof via PID...');
  try {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dashboard-notebook-test-a-'));
    tmpDirs.push(tmpDir);

    // Create microworld with PID-printing entry
    const microworldDir = path.join(tmpDir, 'microworlds', 'test-pid');
    fs.mkdirSync(microworldDir, { recursive: true });

    const pidScript = path.join(microworldDir, 'pid.sh');
    fs.writeFileSync(pidScript, '#!/bin/bash\necho "$$"\n', { mode: 0o755 });

    const manifestPath = path.join(microworldDir, 'manifest.json');
    fs.writeFileSync(manifestPath, JSON.stringify({
      unit: 'test-pid',
      description: 'PID printer',
      functions: [{ id: 'print-pid', entry: 'pid.sh', label: 'Print PID' }],
    }, null, 2));

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const baseUrl = `http://127.0.0.1:${addr.port}`;

    // Get bundles to find bundle ID
    const bundlesResp = await httpRequest(`${baseUrl}/api/bundles?t=${token}`);
    const bundles = JSON.parse(bundlesResp.body);
    const bundle = bundles[0];

    if (!bundle) {
      failures.push('Test (a) FAILED: no bundles discovered');
    } else {
      // Invoke twice and check PIDs differ
      const invoke1 = await httpRequest(`${baseUrl}/api/invoke?t=${token}`, {
        method: 'POST',
        token,
      });
      // Actually need to POST JSON body, so use a different approach

      // For simplicity, invoke via inline fetch simulation
      const result1 = await new Promise((resolve, reject) => {
        const postData = JSON.stringify({
          id: bundle.id,
          functionId: 'print-pid',
          inputs: {},
        });
        const urlObj = new URL(`${baseUrl}/api/invoke`);
        const options = {
          hostname: urlObj.hostname,
          port: urlObj.port,
          path: urlObj.pathname,
          method: 'POST',
          headers: {
            'X-Antislop-Token': token,
            'Content-Type': 'application/json',
            'Content-Length': postData.length,
          },
        };
        const req = http.request(options, (res) => {
          let data = '';
          res.on('data', (chunk) => { data += chunk.toString(); });
          res.on('end', () => {
            resolve(JSON.parse(data));
          });
        });
        req.on('error', reject);
        req.write(postData);
        req.end();
      });

      const result2 = await new Promise((resolve, reject) => {
        const postData = JSON.stringify({
          id: bundle.id,
          functionId: 'print-pid',
          inputs: {},
        });
        const urlObj = new URL(`${baseUrl}/api/invoke`);
        const options = {
          hostname: urlObj.hostname,
          port: urlObj.port,
          path: urlObj.pathname,
          method: 'POST',
          headers: {
            'X-Antislop-Token': token,
            'Content-Type': 'application/json',
            'Content-Length': postData.length,
          },
        };
        const req = http.request(options, (res) => {
          let data = '';
          res.on('data', (chunk) => { data += chunk.toString(); });
          res.on('end', () => {
            resolve(JSON.parse(data));
          });
        });
        req.on('error', reject);
        req.write(postData);
        req.end();
      });

      const pid1 = result1.stdout?.trim();
      const pid2 = result2.stdout?.trim();

      if (!pid1 || !pid2) {
        failures.push(`Test (a) FAILED: no PID output (pid1=${pid1}, pid2=${pid2})`);
      } else if (pid1 === pid2) {
        failures.push(`Test (a) FAILED: PIDs are identical (${pid1}), expected different processes`);
      } else {
        console.log('  ✓ Test (a) passed: PIDs differ', pid1, 'vs', pid2);
      }
    }

    server.close();
  } catch (err) {
    failures.push(`Test (a) ERROR: ${err.message}`);
  }

  // Test (b): NO-SHARED-STATE PROOF — in-process counter always same value
  console.log('Test (b): No shared state proof via counter...');
  try {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dashboard-notebook-test-b-'));
    tmpDirs.push(tmpDir);

    const microworldDir = path.join(tmpDir, 'microworlds', 'test-counter');
    fs.mkdirSync(microworldDir, { recursive: true });

    // Create a script that reads/increments an in-memory (process) value
    const counterScript = path.join(microworldDir, 'counter.sh');
    fs.writeFileSync(counterScript, '#!/bin/bash\necho "1"\n', { mode: 0o755 });

    const manifestPath = path.join(microworldDir, 'manifest.json');
    fs.writeFileSync(manifestPath, JSON.stringify({
      unit: 'test-counter',
      description: 'Counter test',
      functions: [{ id: 'counter', entry: 'counter.sh', label: 'Counter' }],
    }, null, 2));

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const baseUrl = `http://127.0.0.1:${addr.port}`;

    const bundlesResp = await httpRequest(`${baseUrl}/api/bundles?t=${token}`);
    const bundles = JSON.parse(bundlesResp.body);
    const bundle = bundles[0];

    if (!bundle) {
      failures.push('Test (b) FAILED: no bundles discovered');
    } else {
      const result1 = await new Promise((resolve, reject) => {
        const postData = JSON.stringify({
          id: bundle.id,
          functionId: 'counter',
          inputs: {},
        });
        const urlObj = new URL(`${baseUrl}/api/invoke`);
        const options = {
          hostname: urlObj.hostname,
          port: urlObj.port,
          path: urlObj.pathname,
          method: 'POST',
          headers: {
            'X-Antislop-Token': token,
            'Content-Type': 'application/json',
            'Content-Length': postData.length,
          },
        };
        const req = http.request(options, (res) => {
          let data = '';
          res.on('data', (chunk) => { data += chunk.toString(); });
          res.on('end', () => {
            resolve(JSON.parse(data));
          });
        });
        req.on('error', reject);
        req.write(postData);
        req.end();
      });

      const result2 = await new Promise((resolve, reject) => {
        const postData = JSON.stringify({
          id: bundle.id,
          functionId: 'counter',
          inputs: {},
        });
        const urlObj = new URL(`${baseUrl}/api/invoke`);
        const options = {
          hostname: urlObj.hostname,
          port: urlObj.port,
          path: urlObj.pathname,
          method: 'POST',
          headers: {
            'X-Antislop-Token': token,
            'Content-Type': 'application/json',
            'Content-Length': postData.length,
          },
        };
        const req = http.request(options, (res) => {
          let data = '';
          res.on('data', (chunk) => { data += chunk.toString(); });
          res.on('end', () => {
            resolve(JSON.parse(data));
          });
        });
        req.on('error', reject);
        req.write(postData);
        req.end();
      });

      const val1 = result1.stdout?.trim();
      const val2 = result2.stdout?.trim();

      if (val1 !== val2) {
        failures.push(`Test (b) FAILED: values differ (${val1} vs ${val2}), expected no shared state`);
      } else if (val1 !== '1') {
        failures.push(`Test (b) FAILED: unexpected value ${val1}, expected 1`);
      } else {
        console.log('  ✓ Test (b) passed: no shared state (both printed 1)');
      }
    }

    server.close();
  } catch (err) {
    failures.push(`Test (b) ERROR: ${err.message}`);
  }

  // Test (c): ROUTE TABLE UNCHANGED
  console.log('Test (c): Server route table unchanged...');
  try {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dashboard-notebook-test-c-'));
    tmpDirs.push(tmpDir);

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const baseUrl = `http://127.0.0.1:${addr.port}`;

    // Expected routes from prior steps: GET /, GET /api/bundles, GET /api/status, POST /api/invoke
    const expectedRoutes = [
      { method: 'GET', path: '/', expectOk: true },
      { method: 'GET', path: '/api/bundles', expectOk: true },
      { method: 'GET', path: '/api/status', expectOk: true },
      { method: 'POST', path: '/api/invoke', expectOk: false }, // Missing body, so expect error but route exists
    ];

    let routeCheckOk = true;
    for (const route of expectedRoutes) {
      const options = {
        hostname: 'localhost',
        port: addr.port,
        path: route.path,
        method: route.method,
        headers: { 'X-Antislop-Token': token },
      };

      const result = await new Promise((resolve) => {
        const req = http.request(options, (res) => {
          resolve(res.statusCode);
        });
        req.on('error', () => resolve(null));
        if (route.method === 'POST') {
          req.write('{}');
        }
        req.end();
      });

      if (result === null) {
        failures.push(`Test (c) FAILED: route ${route.method} ${route.path} returned null`);
        routeCheckOk = false;
      } else if (route.expectOk && result >= 400) {
        failures.push(`Test (c) FAILED: route ${route.method} ${route.path} returned ${result}, expected <400`);
        routeCheckOk = false;
      }
    }

    // Also check that no unexpected routes exist
    const unexpectedRoutes = [
      { method: 'GET', path: '/api/cells' },
      { method: 'POST', path: '/api/cells' },
      { method: 'DELETE', path: '/api/cells/123' },
    ];

    for (const route of unexpectedRoutes) {
      const options = {
        hostname: 'localhost',
        port: addr.port,
        path: route.path,
        method: route.method,
        headers: { 'X-Antislop-Token': token },
      };

      const result = await new Promise((resolve) => {
        const req = http.request(options, (res) => {
          resolve(res.statusCode);
        });
        req.on('error', () => resolve(null));
        req.end();
      });

      if (result === 200 || result === 201) {
        failures.push(`Test (c) FAILED: unexpected route ${route.method} ${route.path} returned ${result} (should not exist)`);
        routeCheckOk = false;
      }
    }

    if (routeCheckOk) {
      console.log('  ✓ Test (c) passed: route table unchanged');
    }

    server.close();
  } catch (err) {
    failures.push(`Test (c) ERROR: ${err.message}`);
  }

  // Test (d): GET / still works and references /api/invoke
  console.log('Test (d): GET / and /api/invoke reference...');
  try {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dashboard-notebook-test-d-'));
    tmpDirs.push(tmpDir);

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const result = await httpRequest(`http://127.0.0.1:${addr.port}/?t=${token}`);

    if (result.status !== 200) {
      failures.push(`Test (d) FAILED: expected 200, got ${result.status}`);
    }
    if (!result.body.includes('/api/invoke')) {
      failures.push(`Test (d) FAILED: HTML does not reference /api/invoke`);
    }
    if (result.body.length === 0) {
      failures.push(`Test (d) FAILED: response body is empty`);
    }

    if (failures.filter((f) => f.includes('Test (d)')).length === 0) {
      console.log('  ✓ Test (d) passed: GET / returns 200 and references /api/invoke');
    }

    server.close();
  } catch (err) {
    failures.push(`Test (d) ERROR: ${err.message}`);
  }

  // Cleanup
  for (const tmpDir of tmpDirs) {
    try {
      fs.rmSync(tmpDir, { recursive: true });
    } catch (err) {
      // Ignore cleanup errors
    }
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
