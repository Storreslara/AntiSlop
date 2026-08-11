#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawn } = require('child_process');
const { startServer } = require('../bin/microworld-dashboard/server');

const REPO_ROOT = path.resolve(__dirname, '..');

function makeTestProject(name) {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), `dashboard-invoke-test-${name}-`));
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

async function runTests() {
  const failures = [];

  // Test (a): stdin echo — inputs recovered intact
  console.log('Test (a): stdin echo — inputs recovered intact...');
  try {
    const tmpDir = makeTestProject('a');
    const echoScript = `#!/bin/bash
exec cat`;
    makeBundle(tmpDir, 'echo-unit', { echo: echoScript });

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const url = `http://127.0.0.1:${addr.port}/api/invoke`;

    const result = await httpRequest(url, {
      method: 'POST',
      token,
      body: {
        id: 'working:echo-unit',
        functionId: 'echo',
        inputs: { key: 'value', num: 42 },
      },
    });

    if (result.status !== 200) {
      failures.push(`Test (a) FAILED: expected 200, got ${result.status}`);
    } else {
      const resp = JSON.parse(result.body);
      const expected = JSON.stringify({ key: 'value', num: 42 });
      if (resp.stdout !== expected) {
        failures.push(`Test (a) FAILED: expected stdout ${expected}, got ${resp.stdout}`);
      } else {
        console.log('  ✓ Test (a) passed');
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (a) ERROR: ${err.message}`);
  }

  // Test (b): INJECTION PROOF — shell metacharacters delivered verbatim
  console.log('Test (b): injection proof — shell metacharacters in JSON...');
  try {
    const tmpDir = makeTestProject('b');
    const echoScript = `#!/bin/bash
exec cat`;
    makeBundle(tmpDir, 'inject-test', { echo: echoScript });

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const url = `http://127.0.0.1:${addr.port}/api/invoke`;

    // Clean up any prior test file
    try {
      fs.unlinkSync('/tmp/antislop-microworld-pwned');
    } catch (e) {
      // OK if doesn't exist
    }

    const injectionPayload = '; touch /tmp/antislop-microworld-pwned #';
    const result = await httpRequest(url, {
      method: 'POST',
      token,
      body: {
        id: 'working:inject-test',
        functionId: 'echo',
        inputs: { payload: injectionPayload },
      },
    });

    if (result.status !== 200) {
      failures.push(`Test (b) FAILED: expected 200, got ${result.status}`);
    } else {
      const resp = JSON.parse(result.body);
      const expected = JSON.stringify({ payload: injectionPayload });
      if (resp.stdout !== expected) {
        failures.push(`Test (b) FAILED: payload not delivered verbatim, got ${resp.stdout}`);
      }

      // Verify the file was NOT created (proof the shell did not execute)
      await new Promise((r) => setTimeout(r, 100));
      try {
        fs.statSync('/tmp/antislop-microworld-pwned');
        failures.push(`Test (b) FAILED: injection was executed (file exists)`);
      } catch (e) {
        // Good, file should not exist
        console.log('  ✓ Test (b) passed');
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (b) ERROR: ${err.message}`);
  }

  // Test (c): timeout with process kill
  console.log('Test (c): timeout with process kill...');
  try {
    const tmpDir = makeTestProject('c');
    const bundleDir = path.join(tmpDir, 'microworlds', 'sleep-unit');
    fs.mkdirSync(bundleDir, { recursive: true });
    const pidFile = path.join(bundleDir, 'child.pid');
    const sleepScript = `#!/bin/bash
sleep 10 &
echo $! > ${pidFile}
wait`;
    const entryPath = path.join(bundleDir, 'sleep.sh');
    fs.writeFileSync(entryPath, sleepScript);
    fs.chmodSync(entryPath, 0o755);

    const manifest = {
      unit: 'sleep-unit',
      description: 'Sleep test bundle',
      timeoutSeconds: 1,
      functions: [
        {
          id: 'sleep',
          group: 'TestGroup',
          label: 'Sleep',
          entry: 'sleep.sh',
          description: 'Sleep function',
          inputs: [],
        },
      ],
    };
    fs.writeFileSync(path.join(bundleDir, 'manifest.json'), JSON.stringify(manifest, null, 2));

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const url = `http://127.0.0.1:${addr.port}/api/invoke`;

    const result = await httpRequest(url, {
      method: 'POST',
      token,
      body: {
        id: 'working:sleep-unit',
        functionId: 'sleep',
        inputs: {},
      },
    });

    if (result.status !== 200) {
      failures.push(`Test (c) FAILED: expected 200, got ${result.status}`);
    } else {
      const resp = JSON.parse(result.body);
      if (!resp.timedOut) {
        failures.push(`Test (c) FAILED: expected timedOut:true, got ${resp.timedOut}`);
      } else if (resp.durationMs >= 3000) {
        failures.push(`Test (c) FAILED: expected prompt response well under 10s, got durationMs ${resp.durationMs}`);
      } else {
        const sleepPid = Number(fs.readFileSync(pidFile, 'utf8').trim());
        let stillAlive = true;
        for (let i = 0; i < 20 && stillAlive; i++) {
          try {
            process.kill(sleepPid, 0);
            await new Promise((r) => setTimeout(r, 50));
          } catch (err) {
            stillAlive = false;
          }
        }
        if (stillAlive) {
          failures.push(`Test (c) FAILED: descendant sleep process (pid ${sleepPid}) still running after response`);
        } else {
          console.log('  ✓ Test (c) passed');
        }
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (c) ERROR: ${err.message}`);
  }

  // Test (d): 1 MiB truncation
  console.log('Test (d): 1 MiB output cap with truncation...');
  try {
    const tmpDir = makeTestProject('d');
    const largeScript = `#!/bin/bash
python3 -c "print('x' * (2 * 1024 * 1024))"`;
    makeBundle(tmpDir, 'large-unit', { large: largeScript });

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const url = `http://127.0.0.1:${addr.port}/api/invoke`;

    const result = await httpRequest(url, {
      method: 'POST',
      token,
      body: {
        id: 'working:large-unit',
        functionId: 'large',
        inputs: {},
      },
    });

    if (result.status !== 200) {
      failures.push(`Test (d) FAILED: expected 200, got ${result.status}`);
    } else {
      const resp = JSON.parse(result.body);
      if (!resp.truncated) {
        failures.push(`Test (d) FAILED: expected truncated:true, got ${resp.truncated}`);
      } else if (resp.stdout.length > 1024 * 1024) {
        failures.push(`Test (d) FAILED: stdout exceeds 1 MiB: ${resp.stdout.length}`);
      } else {
        console.log('  ✓ Test (d) passed');
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (d) ERROR: ${err.message}`);
  }

  // Test (e): non-zero exit code
  console.log('Test (e): non-zero exit code...');
  try {
    const tmpDir = makeTestProject('e');
    const failScript = `#!/bin/bash
exit 42`;
    makeBundle(tmpDir, 'fail-unit', { fail: failScript });

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const url = `http://127.0.0.1:${addr.port}/api/invoke`;

    const result = await httpRequest(url, {
      method: 'POST',
      token,
      body: {
        id: 'working:fail-unit',
        functionId: 'fail',
        inputs: {},
      },
    });

    if (result.status !== 200) {
      failures.push(`Test (e) FAILED: expected 200 even on non-zero exit, got ${result.status}`);
    } else {
      const resp = JSON.parse(result.body);
      if (resp.exitCode !== 42) {
        failures.push(`Test (e) FAILED: expected exitCode 42, got ${resp.exitCode}`);
      } else {
        console.log('  ✓ Test (e) passed');
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (e) ERROR: ${err.message}`);
  }

  // Test (f): unknown functionId → 400
  console.log('Test (f): unknown functionId returns 400...');
  try {
    const tmpDir = makeTestProject('f');
    const dummyScript = `#!/bin/bash
echo ok`;
    makeBundle(tmpDir, 'dummy-unit', { dummy: dummyScript });

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const url = `http://127.0.0.1:${addr.port}/api/invoke`;

    const result = await httpRequest(url, {
      method: 'POST',
      token,
      body: {
        id: 'working:dummy-unit',
        functionId: 'nonexistent',
        inputs: {},
      },
    });

    if (result.status !== 400) {
      failures.push(`Test (f) FAILED: expected 400 for unknown functionId, got ${result.status}`);
    } else {
      console.log('  ✓ Test (f) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (f) ERROR: ${err.message}`);
  }

  // Test (g): auth check — 401 on missing/wrong token
  console.log('Test (g): auth check — 401 on missing/wrong token...');
  try {
    const tmpDir = makeTestProject('g');
    const dummyScript = `#!/bin/bash
echo ok`;
    makeBundle(tmpDir, 'dummy-unit', { dummy: dummyScript });

    const { server, token: validToken } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const url = `http://127.0.0.1:${addr.port}/api/invoke`;

    // No token
    const result1 = await httpRequest(url, {
      method: 'POST',
      body: {
        id: 'working:dummy-unit',
        functionId: 'dummy',
        inputs: {},
      },
    });

    if (result1.status !== 401) {
      failures.push(`Test (g) FAILED: no token should return 401, got ${result1.status}`);
    }

    // Wrong token
    const result2 = await httpRequest(url, {
      method: 'POST',
      token: 'wrongtoken',
      body: {
        id: 'working:dummy-unit',
        functionId: 'dummy',
        inputs: {},
      },
    });

    if (result2.status !== 401) {
      failures.push(`Test (g) FAILED: wrong token should return 401, got ${result2.status}`);
    }

    if (failures.filter((f) => f.includes('Test (g)')).length === 0) {
      console.log('  ✓ Test (g) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (g) ERROR: ${err.message}`);
  }

  // Test (h): concurrent invocations
  console.log('Test (h): concurrent invocations...');
  try {
    const tmpDir = makeTestProject('h');
    const slowScript = `#!/bin/bash
exec cat`;
    makeBundle(tmpDir, 'slow-unit', { slow: slowScript });

    const { server, token } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const url = `http://127.0.0.1:${addr.port}/api/invoke`;

    // Launch two concurrent requests
    const prom1 = httpRequest(url, {
      method: 'POST',
      token,
      body: {
        id: 'working:slow-unit',
        functionId: 'slow',
        inputs: { id: 1 },
      },
    });

    const prom2 = httpRequest(url, {
      method: 'POST',
      token,
      body: {
        id: 'working:slow-unit',
        functionId: 'slow',
        inputs: { id: 2 },
      },
    });

    const [result1, result2] = await Promise.all([prom1, prom2]);

    if (result1.status !== 200 || result2.status !== 200) {
      failures.push(`Test (h) FAILED: both requests should return 200`);
    } else {
      const resp1 = JSON.parse(result1.body);
      const resp2 = JSON.parse(result2.body);
      const expected1 = JSON.stringify({ id: 1 });
      const expected2 = JSON.stringify({ id: 2 });

      // Each response must contain only its own input, never the other's
      if (resp1.stdout !== expected1) {
        failures.push(`Test (h) FAILED: invocation 1 expected stdout ${expected1}, got ${resp1.stdout}`);
      } else if (resp2.stdout !== expected2) {
        failures.push(`Test (h) FAILED: invocation 2 expected stdout ${expected2}, got ${resp2.stdout}`);
      } else {
        console.log('  ✓ Test (h) passed');
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (h) ERROR: ${err.message}`);
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
