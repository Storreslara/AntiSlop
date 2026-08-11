#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const { startServer } = require('../bin/dashboard/server');

const REPO_ROOT = path.resolve(__dirname, '..');

function makeTestProject(name) {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), `dashboard-packets-test-${name}-`));
  const microworldsDir = path.join(tmpDir, 'microworlds');
  fs.mkdirSync(microworldsDir);
  return tmpDir;
}

function makeBundle(tmpDir, unitSlug, entries = {}) {
  const bundleDir = path.join(tmpDir, 'microworlds', unitSlug);
  fs.mkdirSync(bundleDir, { recursive: true });

  const functions = Object.entries(entries).map(([id, scriptContent]) => ({
    id,
    group: 'TestGroup',
    label: `Test ${id}`,
    entry: `${id}.sh`,
    description: `Test function ${id}`,
    inputs: [],
  }));

  const manifest = {
    unit: unitSlug,
    description: `Test bundle for ${unitSlug}`,
    functions,
  };

  // Create entry scripts
  for (const [id, scriptContent] of Object.entries(entries)) {
    const entryPath = path.join(bundleDir, `${id}.sh`);
    fs.writeFileSync(entryPath, scriptContent);
    fs.chmodSync(entryPath, 0o755);
  }

  const manifestPath = path.join(bundleDir, 'manifest.json');
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));

  return bundleDir;
}

function makePacket(tmpDir, taskId, entries = {}) {
  const packetDir = path.join(tmpDir, '.claude', 'human-review', taskId);
  fs.mkdirSync(packetDir, { recursive: true });

  const functions = Object.entries(entries).map(([id, scriptContent]) => ({
    id,
    group: 'TestGroup',
    label: `Test ${id}`,
    entry: `${id}.sh`,
    description: `Test function ${id}`,
    inputs: [],
    location: { file: `${id}.sh`, startLine: 1, endLine: 1 },
  }));

  const manifest = {
    unit: taskId,
    description: `Packet for ${taskId}`,
    functions,
  };

  // Create entry scripts
  for (const [id, scriptContent] of Object.entries(entries)) {
    const entryPath = path.join(packetDir, `${id}.sh`);
    fs.writeFileSync(entryPath, scriptContent);
    fs.chmodSync(entryPath, 0o755);
  }

  const manifestPath = path.join(packetDir, 'manifest.json');
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));

  return packetDir;
}

function httpRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const method = options.method || 'GET';
    const token = options.token;
    const body = options.body;

    const reqOptions = {
      hostname: urlObj.hostname,
      port: urlObj.port,
      path: urlObj.pathname + urlObj.search,
      method,
      headers: { 'Content-Type': 'application/json' },
    };

    if (token) {
      reqOptions.headers['X-Antislop-Token'] = token;
    }

    if (body && method === 'POST') {
      const bodyStr = JSON.stringify(body);
      reqOptions.headers['Content-Length'] = Buffer.byteLength(bodyStr);
    }

    const req = require('http').request(reqOptions, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        resolve({ status: res.statusCode, body: data });
      });
    });

    req.on('error', reject);

    if (body && method === 'POST') {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

function waitForServer(server, timeout = 5000) {
  return new Promise((resolve, reject) => {
    const start = Date.now();
    const checkReady = () => {
      if (server.listening) {
        resolve();
      } else if (Date.now() - start > timeout) {
        reject(new Error('Server did not start in time'));
      } else {
        setImmediate(checkReady);
      }
    };
    checkReady();
  });
}

async function runTests() {
  const failures = [];

  // Test (a): a fixture packet at .claude/human-review/<task-id>/ appears in
  //           GET /api/bundles with source:"packet" and id packet:<task-id>
  console.log('Test (a): packet discovery with source and id namespacing...');
  try {
    const tmpDir = makeTestProject('a');
    const packetDir = makePacket(tmpDir, 'gh321-test', {
      run: '#!/bin/bash\necho "packet test"',
    });

    const { server, token } = startServer(tmpDir);
    await waitForServer(server);
    const response = await httpRequest(
      `http://127.0.0.1:${server.address().port}/api/bundles?t=${token}`
    );

    const bundles = JSON.parse(response.body);
    const packetBundle = bundles.find((b) => b.id === 'packet:gh321-test');

    if (!packetBundle) {
      failures.push('Test (a): packet bundle not found in discovery');
    } else if (packetBundle.source !== 'packet') {
      failures.push(`Test (a): packet source is "${packetBundle.source}", expected "packet"`);
    }

    server.close();
  } catch (err) {
    failures.push(`Test (a): ${err.message}`);
  }

  // Test (b): a working bundle and a packet for the SAME unit slug both appear
  //           with distinct ids (the collision case)
  console.log('Test (b): collision case — working and packet coexist for the same slug...');
  try {
    const tmpDir = makeTestProject('b');
    const workingDir = makeBundle(tmpDir, 'same-unit', {
      run: '#!/bin/bash\necho "working"',
    });
    const packetDir = makePacket(tmpDir, 'same-unit', {
      run: '#!/bin/bash\necho "packet"',
    });

    const { server, token } = startServer(tmpDir);
    await waitForServer(server);
    const response = await httpRequest(
      `http://127.0.0.1:${server.address().port}/api/bundles?t=${token}`
    );

    const bundles = JSON.parse(response.body);
    const workingBundle = bundles.find((b) => b.id === 'working:same-unit');
    const packetBundle = bundles.find((b) => b.id === 'packet:same-unit');

    if (!workingBundle) {
      failures.push('Test (b): working bundle not found');
    }
    if (!packetBundle) {
      failures.push('Test (b): packet bundle not found');
    }
    if (workingBundle && packetBundle && workingBundle.id === packetBundle.id) {
      failures.push('Test (b): bundle ids are not distinct');
    }

    server.close();
  } catch (err) {
    failures.push(`Test (b): ${err.message}`);
  }

  // Test (c): every source:"packet" entry has status:null, even with a real
  //           audit log present that names that unit — and the co-located
  //           working bundle for the SAME unit DOES pick up that status,
  //           proving discoverPackets() never consults the audit log at all
  console.log('Test (c): packet status is always null, even with an audit log present...');
  try {
    const tmpDir = makeTestProject('c');
    const workingDir = makeBundle(tmpDir, 'same-unit-status', {
      run: '#!/bin/bash\necho "working"',
    });
    const packetDir = makePacket(tmpDir, 'same-unit-status', {
      run: '#!/bin/bash\necho "test"',
    });

    // Write a real audit-log fixture, in the format audit-log.js actually parses.
    const auditLogPath = path.join(tmpDir, '.claude', 'microworld-audit.log');
    fs.mkdirSync(path.dirname(auditLogPath), { recursive: true });
    fs.appendFileSync(
      auditLogPath,
      '2026-08-10T00:00:00Z unit=same-unit-status result=pass file=run.sh\n'
    );

    const { server, token } = startServer(tmpDir);
    await waitForServer(server);
    const response = await httpRequest(
      `http://127.0.0.1:${server.address().port}/api/bundles?t=${token}`
    );

    const bundles = JSON.parse(response.body);
    const workingBundle = bundles.find((b) => b.id === 'working:same-unit-status');
    const packetBundle = bundles.find((b) => b.id === 'packet:same-unit-status');

    if (!workingBundle) {
      failures.push('Test (c): working bundle not found');
    } else if (!workingBundle.status || workingBundle.status.result !== 'pass') {
      failures.push(`Test (c): working bundle status is ${JSON.stringify(workingBundle.status)}, expected result "pass"`);
    }

    if (!packetBundle) {
      failures.push('Test (c): packet bundle not found');
    } else if (packetBundle.status !== null) {
      failures.push(`Test (c): packet status is ${JSON.stringify(packetBundle.status)}, expected null`);
    }

    server.close();
  } catch (err) {
    failures.push(`Test (c): ${err.message}`);
  }

  // Test (d): a function entry inside a packet is invocable via POST /api/invoke
  //           and resolves its assets from the PACKET's directory, not from
  //           microworlds/
  console.log('Test (d): packet function invocation...');
  try {
    const tmpDir = makeTestProject('d');
    const packetDir = makePacket(tmpDir, 'gh321-invoke-test', {
      run: '#!/bin/bash\necho "invoked from packet"',
    });

    const { server, token } = startServer(tmpDir);
    await waitForServer(server);

    // Get bundles to find the packet
    let bundlesResponse = await httpRequest(
      `http://127.0.0.1:${server.address().port}/api/bundles?t=${token}`
    );
    let bundles = JSON.parse(bundlesResponse.body);
    const packetBundle = bundles.find((b) => b.id === 'packet:gh321-invoke-test');

    if (!packetBundle || !packetBundle.functions || packetBundle.functions.length === 0) {
      failures.push('Test (d): packet bundle or functions not found');
    } else {
      // Invoke the function
      const invokeResponse = await httpRequest(
        `http://127.0.0.1:${server.address().port}/api/invoke?t=${token}`,
        {
          method: 'POST',
          token,
          body: {
            id: 'packet:gh321-invoke-test',
            functionId: 'run',
            inputs: {},
          },
        }
      );

      const invokeResult = JSON.parse(invokeResponse.body);
      if (invokeResult.ok !== true) {
        failures.push(`Test (d): invocation failed: ${invokeResult.stderr}`);
      } else if (!invokeResult.stdout.includes('invoked from packet')) {
        failures.push(`Test (d): output does not indicate packet invocation: ${invokeResult.stdout}`);
      }
    }

    server.close();
  } catch (err) {
    failures.push(`Test (d): ${err.message}`);
  }

  // Test (e): with no escalation-packet directory at all, the response is 200
  //           and contains only working bundles
  console.log('Test (e): graceful handling of missing packet directory...');
  try {
    const tmpDir = makeTestProject('e');
    const workingDir = makeBundle(tmpDir, 'only-working', {
      run: '#!/bin/bash\necho "working only"',
    });
    // Explicitly DO NOT create .claude/human-review directory

    const { server, token } = startServer(tmpDir);
    await waitForServer(server);
    const response = await httpRequest(
      `http://127.0.0.1:${server.address().port}/api/bundles?t=${token}`
    );

    if (response.status !== 200) {
      failures.push(`Test (e): HTTP status is ${response.status}, expected 200`);
    }

    const bundles = JSON.parse(response.body);
    const workingBundle = bundles.find((b) => b.id === 'working:only-working');
    const packetBundles = bundles.filter((b) => b.source === 'packet');

    if (!workingBundle) {
      failures.push('Test (e): working bundle not found');
    }
    if (packetBundles.length > 0) {
      failures.push(`Test (e): found ${packetBundles.length} packet bundles, expected 0`);
    }

    server.close();
  } catch (err) {
    failures.push(`Test (e): ${err.message}`);
  }

  // Report results
  if (failures.length > 0) {
    console.error('\nTest failures:');
    failures.forEach((f) => console.error(`  - ${f}`));
    process.exit(1);
  } else {
    console.log('\nAll tests passed!');
    process.exit(0);
  }
}

runTests().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
