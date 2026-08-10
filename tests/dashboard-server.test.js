#!/usr/bin/env node
'use strict';

// Comprehensive test suite for the microworld dashboard server.
// Tests bundle discovery, authentication, error handling, and concurrency.

const fs = require('fs');
const path = require('path');
const os = require('os');
const { startServer } = require('../bin/dashboard/server');

const REPO_ROOT = path.resolve(__dirname, '..');

function makeTestProject(name) {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), `dashboard-test-${name}-`));
  const microworldsDir = path.join(tmpDir, 'microworlds');
  fs.mkdirSync(microworldsDir);
  return tmpDir;
}

function makeBundle(tmpDir, unitSlug, hasValidEntry = true, validManifest = true) {
  const bundleDir = path.join(tmpDir, 'microworlds', unitSlug);
  fs.mkdirSync(bundleDir, { recursive: true });

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
        location: { file: 'src/index.js', startLine: 10, endLine: 20 },
        inputs: [{ name: 'input1', type: 'string', description: 'An input' }],
      },
    ],
  };

  if (hasValidEntry) {
    // Create an executable entry
    const entryPath = path.join(bundleDir, 'test-entry.sh');
    fs.writeFileSync(entryPath, '#!/bin/bash\necho "test"');
    fs.chmodSync(entryPath, 0o755);
  }

  const manifestPath = path.join(bundleDir, 'manifest.json');
  if (validManifest) {
    fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
  } else {
    fs.writeFileSync(manifestPath, '{invalid json');
  }

  return bundleDir;
}

function httpRequest(url, { token, method = 'GET', header = null } = {}) {
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
      if (header === 'query') {
        options.path += (options.path.includes('?') ? '&' : '?') + 't=' + token;
      } else {
        options.headers['X-Antislop-Token'] = token;
      }
    }

    const req = require('http').request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        resolve({ status: res.statusCode, body: data });
      });
    });

    req.on('error', reject);
    req.end();
  });
}

async function runTests() {
  const failures = [];

  // Test (a): no microworlds/ directory
  console.log('Test (a): no microworlds/ directory...');
  try {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dashboard-test-a-'));
    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const url = `http://127.0.0.1:${addr.port}/api/bundles?t=${token}`;
    const result = await httpRequest(url);

    if (result.status !== 200) {
      failures.push(`Test (a) FAILED: expected 200, got ${result.status}`);
    }
    const bundles = JSON.parse(result.body);
    if (!Array.isArray(bundles) || bundles.length !== 0) {
      failures.push(`Test (a) FAILED: expected empty array, got ${JSON.stringify(bundles)}`);
    } else {
      console.log('  ✓ Test (a) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (a) ERROR: ${err.message}`);
  }

  // Test (b): two fixture bundles with functions and location
  console.log('Test (b): two fixture bundles with functions[]...');
  try {
    const tmpDir = makeTestProject('b');
    makeBundle(tmpDir, 'bundle1', true, true);
    makeBundle(tmpDir, 'bundle2', true, true);

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const url = `http://127.0.0.1:${addr.port}/api/bundles?t=${token}`;
    const result = await httpRequest(url);

    const bundles = JSON.parse(result.body);
    if (bundles.length !== 2) {
      failures.push(`Test (b) FAILED: expected 2 bundles, got ${bundles.length}`);
    }

    const bundle1 = bundles.find((b) => b.unit === 'bundle1');
    if (!bundle1 || !bundle1.functions || bundle1.functions.length === 0) {
      failures.push(`Test (b) FAILED: bundle1 missing functions[]`);
    }
    if (bundle1 && bundle1.functions[0].location.file !== 'src/index.js') {
      failures.push(`Test (b) FAILED: location.file mismatch`);
    }
    if (bundle1 && bundle1.functions[0].group !== 'TestClass') {
      failures.push(`Test (b) FAILED: group mismatch`);
    }
    if (failures.filter((f) => f.includes('Test (b)')).length === 0) {
      console.log('  ✓ Test (b) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (b) ERROR: ${err.message}`);
  }

  // Test (c): no token and wrong token
  console.log('Test (c): authentication (no token, wrong token)...');
  try {
    const tmpDir = makeTestProject('c');
    makeBundle(tmpDir, 'test', true, true);

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();

    // No token
    const result1 = await httpRequest(`http://127.0.0.1:${addr.port}/api/bundles`);
    if (result1.status !== 401) {
      failures.push(`Test (c) FAILED: no token should return 401, got ${result1.status}`);
    }

    // Wrong token
    const result2 = await httpRequest(`http://127.0.0.1:${addr.port}/api/bundles?t=wrongtoken`);
    if (result2.status !== 401) {
      failures.push(`Test (c) FAILED: wrong token should return 401, got ${result2.status}`);
    }

    if (failures.filter((f) => f.includes('Test (c)')).length === 0) {
      console.log('  ✓ Test (c) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (c) ERROR: ${err.message}`);
  }

  // Test (d): listening address is exactly 127.0.0.1
  console.log('Test (d): listening address...');
  try {
    const tmpDir = makeTestProject('d');
    const { server } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    if (addr.address !== '127.0.0.1') {
      failures.push(`Test (d) FAILED: expected address 127.0.0.1, got ${addr.address}`);
    } else {
      console.log('  ✓ Test (d) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (d) ERROR: ${err.message}`);
  }

  // Test (e): malformed manifest and missing entry
  console.log('Test (e): graceful error handling...');
  try {
    const tmpDir = makeTestProject('e');
    makeBundle(tmpDir, 'malformed', false, false); // malformed JSON
    makeBundle(tmpDir, 'missing-entry', false, true); // missing entry file

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const url = `http://127.0.0.1:${addr.port}/api/bundles?t=${token}`;
    const result = await httpRequest(url);

    if (result.status !== 200) {
      failures.push(`Test (e) FAILED: should return 200 even with errors, got ${result.status}`);
    }

    const bundles = JSON.parse(result.body);
    const malformed = bundles.find((b) => b.unit === 'malformed');
    const missingEntry = bundles.find((b) => b.unit === 'missing-entry');

    if (!malformed || !malformed.disabled || !malformed.disabledReason) {
      failures.push(`Test (e) FAILED: malformed bundle should have disabled:true and disabledReason`);
    }
    if (!missingEntry || !missingEntry.disabled || !missingEntry.disabledReason) {
      failures.push(`Test (e) FAILED: missing-entry bundle should have disabled:true and disabledReason`);
    }

    if (failures.filter((f) => f.includes('Test (e)')).length === 0) {
      console.log('  ✓ Test (e) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (e) ERROR: ${err.message}`);
  }

  // Test (f): two servers on same project with independent ports/tokens
  console.log('Test (f): concurrent servers...');
  try {
    const tmpDir = makeTestProject('f');
    makeBundle(tmpDir, 'test', true, true);

    const { server: server1, token: token1 } = startServer(tmpDir, 0);
    const { server: server2, token: token2 } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr1 = server1.address();
    const addr2 = server2.address();

    if (addr1.port === addr2.port) {
      failures.push(`Test (f) FAILED: servers should have different ports`);
    }
    if (token1 === token2) {
      failures.push(`Test (f) FAILED: servers should have different tokens`);
    }

    // Server 1 should accept token1 but not token2
    const result1 = await httpRequest(`http://127.0.0.1:${addr1.port}/api/bundles?t=${token1}`);
    if (result1.status !== 200) {
      failures.push(`Test (f) FAILED: server1 should accept its own token`);
    }

    const result2 = await httpRequest(`http://127.0.0.1:${addr1.port}/api/bundles?t=${token2}`);
    if (result2.status !== 401) {
      failures.push(`Test (f) FAILED: server1 should reject other server's token`);
    }

    // Server 2 should accept token2 but not token1
    const result3 = await httpRequest(`http://127.0.0.1:${addr2.port}/api/bundles?t=${token2}`);
    if (result3.status !== 200) {
      failures.push(`Test (f) FAILED: server2 should accept its own token`);
    }

    const result4 = await httpRequest(`http://127.0.0.1:${addr2.port}/api/bundles?t=${token1}`);
    if (result4.status !== 401) {
      failures.push(`Test (f) FAILED: server2 should reject other server's token`);
    }

    if (failures.filter((f) => f.includes('Test (f)')).length === 0) {
      console.log('  ✓ Test (f) passed');
    }

    server1.close();
    server2.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (f) ERROR: ${err.message}`);
  }

  // Test (g): malformed request-target must not crash the server
  console.log('Test (g): malformed request-target survives...');
  try {
    const tmpDir = makeTestProject('g');
    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const net = require('net');
    await new Promise((resolve, reject) => {
      const socket = net.connect(addr.port, '127.0.0.1', () => {
        socket.write('GET //[ HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n');
      });
      socket.on('data', () => {});
      socket.on('end', resolve);
      socket.on('error', resolve);
    });
    await new Promise((r) => setTimeout(r, 100));

    // Server must still be listening and serve subsequent requests
    const url = `http://127.0.0.1:${addr.port}/api/bundles?t=${token}`;
    const result = await httpRequest(url);
    if (result.status !== 200) {
      failures.push(`Test (g) FAILED: server did not survive malformed request-target, got ${result.status}`);
    } else {
      console.log('  ✓ Test (g) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (g) ERROR: ${err.message}`);
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
