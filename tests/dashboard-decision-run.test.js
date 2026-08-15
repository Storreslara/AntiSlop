#!/usr/bin/env node
'use strict';

// Comprehensive test suite for Step 3 endpoints: POST /api/decision/arm and POST /api/decision/run
// Covers all acceptance criteria from docs/plans/2026-08-15-dashboard-decision-run-and-pill-controls.md, Step 3

const fs = require('fs');
const path = require('path');
const os = require('os');
const { startServer } = require('../bin/microworld-dashboard/server');

function makeTestProject(name) {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), `dashboard-decision-test-${name}-`));
  return tmpDir;
}

function setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp = '2026-08-15T10:00:00Z') {
  // Create .claude/human-review/<taskId>/
  const packetDir = path.join(tmpDir, '.claude', 'human-review', taskId);
  fs.mkdirSync(packetDir, { recursive: true });

  // Create .claude/reviewed/<taskId>.escalated
  const reviewedDir = path.join(tmpDir, '.claude', 'reviewed');
  fs.mkdirSync(reviewedDir, { recursive: true });
  const escalatedPath = path.join(reviewedDir, `${taskId}.escalated`);
  fs.writeFileSync(escalatedPath, `${escalationTimestamp} escalation marker\n`);

  // Create .claude/review-audit.log if it doesn't exist
  const auditDir = path.join(tmpDir, '.claude');
  const auditPath = path.join(auditDir, 'review-audit.log');
  if (!fs.existsSync(auditPath)) {
    fs.writeFileSync(auditPath, '');
  }
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

  // Test (1): POST /api/decision/arm with valid input returns 200 with armed:true and expiresInMs
  console.log('Test (1): POST /api/decision/arm success case...');
  try {
    const tmpDir = makeTestProject('1');
    const taskId = 'test-task-1';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    const ttyWrite = { write: () => {} };
    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const url = `http://127.0.0.1:${addr.port}/api/decision/arm`;

    const result = await httpRequest(url, {
      method: 'POST',
      token,
      body: {
        taskId,
        route: 'approve',
        escalationTimestamp,
        by: 'TestUser',
        reason: 'testing',
        quiz: 'skipped',
      },
    });

    if (result.status !== 200) {
      failures.push(`Test (1) FAILED: expected 200, got ${result.status}`);
    } else {
      const resp = JSON.parse(result.body);
      if (!resp.armed || resp.expiresInMs !== 120000) {
        failures.push(`Test (1) FAILED: expected armed:true and expiresInMs:120000, got ${JSON.stringify(resp)}`);
      } else {
        console.log('  ✓ Test (1) passed');
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (1) ERROR: ${err.message}`);
  }

  // Test (2): Code generation and non-visibility in response body
  console.log('Test (2): code not in response body, but guessed code fails...');
  try {
    const tmpDir = makeTestProject('2');
    const taskId = 'test-task-2';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    const ttyWrite = { write: () => {} };
    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();

    // Arm the decision
    const armUrl = `http://127.0.0.1:${addr.port}/api/decision/arm`;
    const armResult = await httpRequest(armUrl, {
      method: 'POST',
      token,
      body: {
        taskId,
        route: 'approve',
        escalationTimestamp,
        by: 'TestUser',
        reason: 'testing',
        quiz: 'skipped',
      },
    });

    if (armResult.status !== 200) {
      failures.push(`Test (2) FAILED: arm returned ${armResult.status}`);
    } else {
      // Verify the code is NOT in the response body
      if (armResult.body.includes('ABCDEF') || armResult.body.includes('234567') || armResult.body.includes('code:')) {
        failures.push(`Test (2) FAILED: response body appears to contain a code`);
      }

      // Try to run with a guessed code - should fail
      const runUrl = `http://127.0.0.1:${addr.port}/api/decision/run`;
      const runResult = await httpRequest(runUrl, {
        method: 'POST',
        token,
        body: {
          taskId,
          code: 'GUESS1', // Wrong code
        },
      });

      if (runResult.status === 200) {
        failures.push(`Test (2) FAILED: guessed code should fail`);
      } else {
        // Verify no DECISION file was written
        const decisionPath = path.join(tmpDir, '.claude', 'human-review', taskId, 'DECISION');
        if (fs.existsSync(decisionPath)) {
          failures.push(`Test (2) FAILED: DECISION file should not exist after failed code`);
        } else {
          console.log('  ✓ Test (2) passed');
        }
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (2) ERROR: ${err.message}`);
  }

  // Test (3): ttyWrite unavailable (null) returns 403 for both endpoints
  console.log('Test (3): no terminal available, both endpoints return 403...');
  try {
    const tmpDir = makeTestProject('3');
    const taskId = 'test-task-3';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    // Inject null ttyWrite to simulate no terminal
    const { server, token } = startServer(tmpDir, 0, { ttyWrite: null });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();

    // Test /api/decision/arm
    const armUrl = `http://127.0.0.1:${addr.port}/api/decision/arm`;
    const armResult = await httpRequest(armUrl, {
      method: 'POST',
      token,
      body: {
        taskId,
        route: 'approve',
        escalationTimestamp,
        by: 'TestUser',
        reason: 'testing',
        quiz: 'skipped',
      },
    });

    if (armResult.status !== 403) {
      failures.push(`Test (3) FAILED: arm should return 403, got ${armResult.status}`);
    }

    // Test /api/decision/run
    const runUrl = `http://127.0.0.1:${addr.port}/api/decision/run`;
    const runResult = await httpRequest(runUrl, {
      method: 'POST',
      token,
      body: {
        taskId,
        code: 'SOMECODE',
      },
    });

    if (runResult.status !== 403) {
      failures.push(`Test (3) FAILED: run should return 403, got ${runResult.status}`);
    }

    // Verify no DECISION file was written
    const decisionPath = path.join(tmpDir, '.claude', 'human-review', taskId, 'DECISION');
    if (fs.existsSync(decisionPath)) {
      failures.push(`Test (3) FAILED: no DECISION file should exist`);
    } else {
      console.log('  ✓ Test (3) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (3) ERROR: ${err.message}`);
  }

  // Test (4): Code reuse fails (used flag)
  console.log('Test (4): second use of same code fails...');
  try {
    const tmpDir = makeTestProject('4');
    const taskId = 'test-task-4';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    // Create a stub ttyWrite to capture output
    let capturedCode = null;
    const ttyWrite = {
      write: (data) => {
        // Extract code from output like "antislop: confirmation code for DECISION test-task-4 is ABCDEF (valid 120s)"
        const match = data.toString().match(/is (\S+) \(valid/);
        if (match) capturedCode = match[1];
      },
    };

    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();

    // Arm the decision
    const armUrl = `http://127.0.0.1:${addr.port}/api/decision/arm`;
    await httpRequest(armUrl, {
      method: 'POST',
      token,
      body: {
        taskId,
        route: 'approve',
        escalationTimestamp,
        by: 'TestUser',
        reason: 'testing',
        quiz: 'skipped',
      },
    });

    if (!capturedCode) {
      failures.push(`Test (4) FAILED: could not capture code from tty output`);
    } else {
      // First run should succeed
      const runUrl = `http://127.0.0.1:${addr.port}/api/decision/run`;
      const runResult1 = await httpRequest(runUrl, {
        method: 'POST',
        token,
        body: { taskId, code: capturedCode },
      });

      if (runResult1.status !== 200) {
        failures.push(`Test (4) FAILED: first run should succeed, got ${runResult1.status}`);
      } else {
        // Second run with same code should fail
        const runResult2 = await httpRequest(runUrl, {
          method: 'POST',
          token,
          body: { taskId, code: capturedCode },
        });

        if (runResult2.status === 200) {
          failures.push(`Test (4) FAILED: second use should fail`);
        } else {
          console.log('  ✓ Test (4) passed');
        }
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (4) ERROR: ${err.message}`);
  }

  // Test (5): Expired code fails
  console.log('Test (5): expired code fails...');
  try {
    const tmpDir = makeTestProject('5');
    const taskId = 'test-task-5';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    let capturedCode = null;
    const ttyWrite = {
      write: (data) => {
        const match = data.toString().match(/is (\S+) \(valid/);
        if (match) capturedCode = match[1];
      },
    };

    // Use short TTL of 100ms for testing
    const { server, token } = startServer(tmpDir, 0, { ttyWrite: ttyWrite, armTtlMs: 100 });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();

    // Arm the decision
    const armUrl = `http://127.0.0.1:${addr.port}/api/decision/arm`;
    await httpRequest(armUrl, {
      method: 'POST',
      token,
      body: {
        taskId,
        route: 'approve',
        escalationTimestamp,
        by: 'TestUser',
        reason: 'testing',
        quiz: 'skipped',
      },
    });

    if (!capturedCode) {
      failures.push(`Test (5) FAILED: could not capture code`);
    } else {
      // Wait for code to expire (TTL is 100ms, so wait 150ms to be safe)
      await new Promise((r) => setTimeout(r, 150));

      // Try to run with expired code
      const runUrl = `http://127.0.0.1:${addr.port}/api/decision/run`;
      const runResult = await httpRequest(runUrl, {
        method: 'POST',
        token,
        body: { taskId, code: capturedCode },
      });

      if (runResult.status === 200) {
        failures.push(`Test (5) FAILED: expired code should fail`);
      } else {
        console.log('  ✓ Test (5) passed');
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (5) ERROR: ${err.message}`);
  }

  // Test (6): Cross-task binding - code for task A cannot write task B
  console.log('Test (6): code from task A cannot write task B...');
  try {
    const tmpDir = makeTestProject('6');
    const taskIdA = 'test-task-6a';
    const taskIdB = 'test-task-6b';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskIdA, escalationTimestamp);
    setupDecisionEnvironment(tmpDir, taskIdB, escalationTimestamp);

    let capturedCodeA = null;
    const ttyWrite = {
      write: (data) => {
        const match = data.toString().match(/is (\S+) \(valid/);
        if (match && !capturedCodeA) capturedCodeA = match[1];
      },
    };

    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();

    // Arm decision for task A
    const armUrl = `http://127.0.0.1:${addr.port}/api/decision/arm`;
    await httpRequest(armUrl, {
      method: 'POST',
      token,
      body: {
        taskId: taskIdA,
        route: 'approve',
        escalationTimestamp,
        by: 'TestUser',
        reason: 'testing',
        quiz: 'skipped',
      },
    });

    if (!capturedCodeA) {
      failures.push(`Test (6) FAILED: could not capture code`);
    } else {
      // Try to run with task B using code from task A
      const runUrl = `http://127.0.0.1:${addr.port}/api/decision/run`;
      const runResult = await httpRequest(runUrl, {
        method: 'POST',
        token,
        body: {
          taskId: taskIdB,
          code: capturedCodeA,
        },
      });

      if (runResult.status === 200) {
        failures.push(`Test (6) FAILED: code from task A should not write task B`);
      } else {
        console.log('  ✓ Test (6) passed');
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (6) ERROR: ${err.message}`);
  }

  // Test (7): R7 - Packet directory absent returns 409, no directory created
  console.log('Test (7): packet directory absent returns 409, no mkdir...');
  try {
    const tmpDir = makeTestProject('7');
    const taskId = 'test-task-7';
    const escalationTimestamp = '2026-08-15T10:00:00Z';

    // Set up escalated marker but NOT the packet directory
    const reviewedDir = path.join(tmpDir, '.claude', 'reviewed');
    fs.mkdirSync(reviewedDir, { recursive: true });
    const escalatedPath = path.join(reviewedDir, `${taskId}.escalated`);
    fs.writeFileSync(escalatedPath, `${escalationTimestamp} escalation marker\n`);

    const ttyWrite = { write: () => {} };
    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();

    // Try to arm without packet directory
    const armUrl = `http://127.0.0.1:${addr.port}/api/decision/arm`;
    const armResult = await httpRequest(armUrl, {
      method: 'POST',
      token,
      body: {
        taskId,
        route: 'approve',
        escalationTimestamp,
        by: 'TestUser',
        reason: 'testing',
        quiz: 'skipped',
      },
    });

    if (armResult.status !== 409) {
      failures.push(`Test (7) FAILED: should return 409, got ${armResult.status}`);
    } else {
      // Verify directory was NOT created
      const packetDir = path.join(tmpDir, '.claude', 'human-review', taskId);
      if (fs.existsSync(packetDir)) {
        failures.push(`Test (7) FAILED: packet directory should not be created`);
      } else {
        console.log('  ✓ Test (7) passed');
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (7) ERROR: ${err.message}`);
  }

  // Test (8): Existing DECISION file not overwritten
  console.log('Test (8): existing DECISION file not overwritten...');
  try {
    const tmpDir = makeTestProject('8');
    const taskId = 'test-task-8';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    // Pre-create DECISION file with original content
    const decisionPath = path.join(tmpDir, '.claude', 'human-review', taskId, 'DECISION');
    const originalContent = 'ORIGINAL DECISION CONTENT\n';
    fs.writeFileSync(decisionPath, originalContent);

    let capturedCode = null;
    const ttyWrite = {
      write: (data) => {
        const match = data.toString().match(/is (\S+) \(valid/);
        if (match) capturedCode = match[1];
      },
    };

    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();

    // Arm and run
    const armUrl = `http://127.0.0.1:${addr.port}/api/decision/arm`;
    await httpRequest(armUrl, {
      method: 'POST',
      token,
      body: {
        taskId,
        route: 'approve',
        escalationTimestamp,
        by: 'TestUser',
        reason: 'testing',
        quiz: 'skipped',
      },
    });

    if (capturedCode) {
      const runUrl = `http://127.0.0.1:${addr.port}/api/decision/run`;
      const runResult = await httpRequest(runUrl, {
        method: 'POST',
        token,
        body: { taskId, code: capturedCode },
      });

      if (runResult.status === 200) {
        failures.push(`Test (8) FAILED: should return 409, got 200`);
      } else {
        // Verify original content is intact
        const actualContent = fs.readFileSync(decisionPath, 'utf8');
        if (actualContent !== originalContent) {
          failures.push(`Test (8) FAILED: original content was modified`);
        } else {
          console.log('  ✓ Test (8) passed');
        }
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (8) ERROR: ${err.message}`);
  }

  // Test (9): Staleness - mismatched escalationTimestamp is refused
  console.log('Test (9): mismatched escalationTimestamp refused...');
  try {
    const tmpDir = makeTestProject('9');
    const taskId = 'test-task-9';
    const correctTimestamp = '2026-08-15T10:00:00Z';
    const wrongTimestamp = '2026-08-15T10:00:01Z';
    setupDecisionEnvironment(tmpDir, taskId, correctTimestamp);

    const ttyWrite = { write: () => {} };
    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();

    // Try to arm with wrong timestamp
    const armUrl = `http://127.0.0.1:${addr.port}/api/decision/arm`;
    const armResult = await httpRequest(armUrl, {
      method: 'POST',
      token,
      body: {
        taskId,
        route: 'approve',
        escalationTimestamp: wrongTimestamp,
        by: 'TestUser',
        reason: 'testing',
        quiz: 'skipped',
      },
    });

    if (armResult.status !== 409) {
      failures.push(`Test (9) FAILED: should return 409, got ${armResult.status}`);
    } else {
      console.log('  ✓ Test (9) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (9) ERROR: ${err.message}`);
  }

  // Test (10): R6 - All three quiz tokens behave identically
  console.log('Test (10): all quiz tokens behave identically...');
  try {
    const tmpDir = makeTestProject('10');
    const taskId = 'test-task-10'; // Same taskId for all three runs
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    const quizTokens = ['passed-self-check', 'skipped', 'none-offered'];
    const writtenBodies = {};

    // Set up once for the shared taskId
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    let capturedCode = null;
    const ttyWrite = {
      write: (data) => {
        const match = data.toString().match(/is (\S+) \(valid/);
        if (match) capturedCode = match[1];
      },
    };

    const { server, token } = startServer(tmpDir, 0, { ttyWrite: ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();

    // Test each quiz token with the SAME taskId
    for (const quizToken of quizTokens) {
      // Before each test, remove the DECISION file from previous run so we can write fresh
      const decisionPath = path.join(tmpDir, '.claude', 'human-review', taskId, 'DECISION');
      if (fs.existsSync(decisionPath)) {
        fs.unlinkSync(decisionPath);
      }

      // Arm with this quiz token
      const armUrl = `http://127.0.0.1:${addr.port}/api/decision/arm`;
      await httpRequest(armUrl, {
        method: 'POST',
        token,
        body: {
          taskId,
          route: 'approve',
          escalationTimestamp,
          by: 'TestUser',
          reason: 'testing',
          quiz: quizToken,
        },
      });

      if (!capturedCode) {
        failures.push(`Test (10) FAILED: could not capture code for ${quizToken}`);
        continue;
      }

      // Run with the captured code
      const runUrl = `http://127.0.0.1:${addr.port}/api/decision/run`;
      const runResult = await httpRequest(runUrl, {
        method: 'POST',
        token,
        body: { taskId, code: capturedCode },
      });

      if (runResult.status !== 200) {
        failures.push(`Test (10) FAILED: run with ${quizToken} should succeed, got ${runResult.status}`);
        continue;
      }

      // Read the written body
      const body = fs.readFileSync(decisionPath, 'utf8');
      writtenBodies[quizToken] = body;

      // Reset capturedCode for next iteration
      capturedCode = null;
    }

    // Verify all three succeed and differ only in quiz: line
    if (Object.keys(writtenBodies).length === 3) {
      const baselines = quizTokens.map((qt) => {
        const lines = writtenBodies[qt].split('\n').filter((l) => l.trim() !== '');
        return {
          token: qt,
          body: writtenBodies[qt],
          quizLine: lines.find((line) => line.startsWith('quiz:')),
          // Get all lines except quiz: and strip timestamp from DECISION line for comparison
          otherLines: lines
            .filter((line) => !line.startsWith('quiz:'))
            .map((line) => {
              // DECISION line has format: DECISION taskId ISO-timestamp route: ... escalation: ...
              // Strip the timestamp to compare the rest
              if (line.startsWith('DECISION ')) {
                // Keep everything except the ISO timestamp
                const parts = line.split(' ');
                // parts[0] = 'DECISION', parts[1] = taskId, parts[2] = ISO-timestamp, rest = route: ...
                return `${parts[0]} ${parts[1]} TIMESTAMP ${parts.slice(3).join(' ')}`;
              }
              return line;
            }),
        };
      });

      // All should have the same non-quiz lines (DECISION, by, via, reason if present)
      const firstOtherLines = baselines[0].otherLines;
      let allOthersMatch = true;
      for (let i = 1; i < baselines.length; i++) {
        if (baselines[i].otherLines.length !== firstOtherLines.length) {
          allOthersMatch = false;
          break;
        }
        for (let j = 0; j < firstOtherLines.length; j++) {
          if (baselines[i].otherLines[j] !== firstOtherLines[j]) {
            allOthersMatch = false;
            break;
          }
        }
      }

      if (!allOthersMatch) {
        failures.push(`Test (10) FAILED: bodies differ in more than just quiz: line`);
      } else {
        const uniqueQuizLines = new Set(baselines.map((b) => b.quizLine));
        if (uniqueQuizLines.size !== 3) {
          failures.push(`Test (10) FAILED: not all three quiz tokens appear`);
        } else {
          console.log('  ✓ Test (10) passed');
        }
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (10) ERROR: ${err.message}`);
  }

  // Test (11): Audit log appended
  console.log('Test (11): audit log appended with correct format...');
  try {
    const tmpDir = makeTestProject('11');
    const taskId = 'test-task-11';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    let capturedCode = null;
    const ttyWrite = {
      write: (data) => {
        const match = data.toString().match(/is (\S+) \(valid/);
        if (match) capturedCode = match[1];
      },
    };

    const { server, token } = startServer(tmpDir, 0, { ttyWrite: ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();

    // Get initial audit log size
    const auditPath = path.join(tmpDir, '.claude', 'review-audit.log');
    const initialSize = fs.statSync(auditPath).size;

    // Arm and run
    const armUrl = `http://127.0.0.1:${addr.port}/api/decision/arm`;
    await httpRequest(armUrl, {
      method: 'POST',
      token,
      body: {
        taskId,
        route: 'approve',
        escalationTimestamp,
        by: 'TestUser',
        reason: 'testing',
        quiz: 'skipped',
      },
    });

    if (capturedCode) {
      const runUrl = `http://127.0.0.1:${addr.port}/api/decision/run`;
      const runResult = await httpRequest(runUrl, {
        method: 'POST',
        token,
        body: { taskId, code: capturedCode },
      });

      if (runResult.status === 200) {
        // Check audit log was appended
        const auditContent = fs.readFileSync(auditPath, 'utf8');
        const lines = auditContent.trim().split('\n');
        const lastLine = lines[lines.length - 1];

        if (
          lastLine.includes('decision-write-via-dashboard') &&
          lastLine.includes(`task=${taskId}`) &&
          lastLine.includes('route=approve') &&
          lastLine.includes('by=TestUser')
        ) {
          console.log('  ✓ Test (11) passed');
        } else {
          failures.push(`Test (11) FAILED: audit line format incorrect: ${lastLine}`);
        }
      } else {
        failures.push(`Test (11) FAILED: run failed with ${runResult.status}`);
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (11) ERROR: ${err.message}`);
  }

  // Print results
  console.log('\n' + '='.repeat(60));
  if (failures.length === 0) {
    console.log('All tests passed!');
    process.exit(0);
  } else {
    console.log(`${failures.length} test(s) failed:\n`);
    failures.forEach((f) => console.log(`  ${f}`));
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error('Test suite error:', err);
  process.exit(1);
});
