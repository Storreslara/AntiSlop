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

// Real .escalated marker first-line format (gh380 D1/D2 fix), matching
// .claude/reviewed/373.escalated and 375.escalated verbatim:
// "ESCALATE-TO-HUMAN <taskId> <ts> trigger: ... microworld: ...". The
// timestamp is field index 2, not field index 0 -- a fixture using any
// other shape exercises a code path the real dashboard client never
// produces (see decisions.js:37, which parses this exact grammar).
function realEscalatedMarker(taskId, escalationTimestamp) {
  return `ESCALATE-TO-HUMAN ${taskId} ${escalationTimestamp} trigger: heavy-unit surface microworld: none\n`;
}

function setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp = '2026-08-15T10:00:00Z') {
  // Create .claude/human-review/<taskId>/
  const packetDir = path.join(tmpDir, '.claude', 'human-review', taskId);
  fs.mkdirSync(packetDir, { recursive: true });

  // Create .claude/reviewed/<taskId>.escalated
  const reviewedDir = path.join(tmpDir, '.claude', 'reviewed');
  fs.mkdirSync(reviewedDir, { recursive: true });
  const escalatedPath = path.join(reviewedDir, `${taskId}.escalated`);
  fs.writeFileSync(escalatedPath, realEscalatedMarker(taskId, escalationTimestamp));

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
    // rawBody sends the payload verbatim, so a test can drive a non-object
    // top-level JSON body that `body` (JSON.stringify'd) could express but
    // not distinguish from a normal object.
    const rawBody = options.rawBody;

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

    if (rawBody !== undefined && method === 'POST') {
      reqOptions.headers['Content-Length'] = Buffer.byteLength(rawBody);
    } else if (body && method === 'POST') {
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

    if (rawBody !== undefined && method === 'POST') {
      req.write(rawBody);
    } else if (body && method === 'POST') {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

// gh380 debug spec C7: the shape list and the field list are each defined
// exactly once and iterated as a cross-product, so a future free-text field
// inherits full shape coverage from one name added to FREE_TEXT_FIELDS
// rather than from a new hand-written test. The prior two attempts both
// failed because their tests pinned the one payload shape the attacker
// stops using the moment it is blocked.
const NON_STRING_SHAPES = [
  // The reviewer's exact FAIL-record payload, verbatim.
  { label: 'array-wrapped', value: ['agent\nquiz: passed-self-check\nnote: forged'] },
  { label: 'nested-array', value: [['agent\nquiz: passed-self-check']] },
  { label: 'plain-object', value: { forged: 'agent\nquiz: passed-self-check' } },
  { label: 'number', value: 42 },
  { label: 'boolean', value: true },
  { label: 'null', value: null },
];
const FREE_TEXT_FIELDS = ['by', 'reason'];

// gh380 debug spec C10: every field each handler destructures from the
// parsed JSON, so the property under test is a whole-endpoint one rather
// than a by/reason one.
const ARM_JSON_FIELDS = ['taskId', 'route', 'escalationTimestamp', 'by', 'reason', 'quiz'];
const RUN_JSON_FIELDS = ['taskId', 'code'];

function countNewlines(text) {
  return text.split('\n').length - 1;
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
    fs.writeFileSync(escalatedPath, realEscalatedMarker(taskId, escalationTimestamp));

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

  // Test (12): gh380 D1 exact repro -- arming against a REAL-format marker
  // with its true timestamp succeeds; arming with the literal constant
  // "ESCALATE-TO-HUMAN" (what the old split(' ')[0] bug would have
  // accepted) is correctly refused.
  console.log('Test (12): D1 repro -- real timestamp succeeds, literal constant refused...');
  try {
    const tmpDir = makeTestProject('12');
    const taskId = 'test-task-12';
    const trueTimestamp = '2026-08-15T19:54:54Z';
    setupDecisionEnvironment(tmpDir, taskId, trueTimestamp);

    const ttyWrite = { write: () => {} };
    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const armUrl = `http://127.0.0.1:${addr.port}/api/decision/arm`;

    // The literal constant that the pre-fix split(' ')[0] bug always
    // extracted from the real marker format, regardless of the actual
    // timestamp -- must now be refused.
    const bogusResult = await httpRequest(armUrl, {
      method: 'POST',
      token,
      body: {
        taskId,
        route: 'approve',
        escalationTimestamp: 'ESCALATE-TO-HUMAN',
        by: 'TestUser',
        reason: 'testing',
        quiz: 'skipped',
      },
    });

    if (bogusResult.status !== 409) {
      failures.push(`Test (12) FAILED: literal "ESCALATE-TO-HUMAN" timestamp should be refused with 409, got ${bogusResult.status}`);
    } else {
      // The true timestamp (real field-index-2 value) must succeed.
      const trueResult = await httpRequest(armUrl, {
        method: 'POST',
        token,
        body: {
          taskId,
          route: 'approve',
          escalationTimestamp: trueTimestamp,
          by: 'TestUser',
          reason: 'testing',
          quiz: 'skipped',
        },
      });

      if (trueResult.status !== 200) {
        failures.push(`Test (12) FAILED: true marker timestamp should arm successfully, got ${trueResult.status}: ${trueResult.body}`);
      } else {
        console.log('  ✓ Test (12) passed');
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (12) ERROR: ${err.message}`);
  }

  // Test (13): gh380 D2 exact repro -- a `by` value forging a newline +
  // "quiz: passed-self-check" line is refused end-to-end (arm returns 4xx,
  // no arm is recorded, no code is delivered).
  console.log('Test (13): D2 repro -- newline-injecting by field refused by /api/decision/arm...');
  try {
    const tmpDir = makeTestProject('13');
    const taskId = 'test-task-13';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    let ttyMessages = [];
    const ttyWrite = { write: (data) => ttyMessages.push(data.toString()) };
    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const armUrl = `http://127.0.0.1:${addr.port}/api/decision/arm`;

    const armResult = await httpRequest(armUrl, {
      method: 'POST',
      token,
      body: {
        taskId,
        route: 'approve',
        escalationTimestamp,
        by: 'agent\nquiz: passed-self-check\nnote: forged',
        reason: 'testing',
        quiz: 'skipped',
      },
    });

    if (armResult.status < 400 || armResult.status >= 500) {
      failures.push(`Test (13) FAILED: newline-injecting by should be refused with a 4xx, got ${armResult.status}: ${armResult.body}`);
    } else if (ttyMessages.length !== 0) {
      failures.push(`Test (13) FAILED: no confirmation code should have been delivered to tty, got ${JSON.stringify(ttyMessages)}`);
    } else {
      // A legitimate follow-up arm for the same task must still work --
      // the injection attempt must not have wedged server state.
      const cleanResult = await httpRequest(armUrl, {
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
      if (cleanResult.status !== 200) {
        failures.push(`Test (13) FAILED: a clean arm after a rejected injection attempt should still succeed, got ${cleanResult.status}`);
      } else {
        console.log('  ✓ Test (13) passed');
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (13) ERROR: ${err.message}`);
  }

  // Test (14): a `reason` value forging a newline + extra field line is
  // also refused (same injection class as Test (13), different field).
  console.log('Test (14): reason newline injection refused by /api/decision/arm...');
  try {
    const tmpDir = makeTestProject('14');
    const taskId = 'test-task-14';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    const ttyWrite = { write: () => {} };
    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const armUrl = `http://127.0.0.1:${addr.port}/api/decision/arm`;

    const armResult = await httpRequest(armUrl, {
      method: 'POST',
      token,
      body: {
        taskId,
        route: 'approve',
        escalationTimestamp,
        by: 'TestUser',
        reason: 'looks fine\nquiz: passed-self-check',
        quiz: 'skipped',
      },
    });

    if (armResult.status < 400 || armResult.status >= 500) {
      failures.push(`Test (14) FAILED: newline-injecting reason should be refused with a 4xx, got ${armResult.status}: ${armResult.body}`);
    } else {
      console.log('  ✓ Test (14) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (14) ERROR: ${err.message}`);
  }

  // Test (15): gh380 D3 -- the audit log cannot receive injected lines via
  // `by`, verified end-to-end (not just "the composer throws"): attempt a
  // full arm+run cycle with a newline-bearing `by`, then assert the audit
  // log file was never touched by the attempt (the arm itself is refused
  // before any in-memory arm record -- and therefore any audit line -- can
  // be produced).
  console.log('Test (15): D3 repro -- audit log receives no injected content via by...');
  try {
    const tmpDir = makeTestProject('15');
    const taskId = 'test-task-15';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    const auditPath = path.join(tmpDir, '.claude', 'review-audit.log');
    const beforeContent = fs.readFileSync(auditPath, 'utf8');

    const ttyWrite = { write: () => {} };
    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const armUrl = `http://127.0.0.1:${addr.port}/api/decision/arm`;

    const armResult = await httpRequest(armUrl, {
      method: 'POST',
      token,
      body: {
        taskId,
        route: 'approve',
        escalationTimestamp,
        by: 'agent\n2026-01-01T00:00:00Z decision-gate-denied identity=forged',
        reason: 'testing',
        quiz: 'skipped',
      },
    });

    const afterContent = fs.readFileSync(auditPath, 'utf8');

    if (armResult.status < 400 || armResult.status >= 500) {
      failures.push(`Test (15) FAILED: newline-injecting by should be refused with a 4xx, got ${armResult.status}`);
    } else if (afterContent !== beforeContent) {
      failures.push(`Test (15) FAILED: audit log was modified by a refused arm attempt: ${JSON.stringify(afterContent)}`);
    } else if (afterContent.includes('decision-gate-denied identity=forged')) {
      failures.push(`Test (15) FAILED: forged audit line reached the log`);
    } else {
      console.log('  ✓ Test (15) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (15) ERROR: ${err.message}`);
  }

  // Test (16): gh380 debug spec C2 + C6(a) -- the type-confusion matrix.
  // The defect was never "arrays": `typeof value === 'string' &&` as a
  // precondition skipped the guard for the entire complement of string, and
  // template interpolation coerced the value back. For every
  // {by, reason} x {6 non-string shapes} pair: arm must 400, must not report
  // armed:true, must deliver nothing to the tty, must leave the audit log
  // byte-identical, and must leave no arm record behind (a follow-up run
  // returns 409). One server for the whole matrix, so "no arm record" is
  // asserted against accumulated state, not a fresh process each time.
  console.log('Test (16): C2/C6(a) type-confusion matrix -- 12 shape x field cases refused...');
  try {
    const tmpDir = makeTestProject('16');
    const taskId = 'test-task-16';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    const auditPath = path.join(tmpDir, '.claude', 'review-audit.log');
    const auditBefore = fs.readFileSync(auditPath, 'utf8');

    const ttyMessages = [];
    const ttyWrite = { write: (data) => ttyMessages.push(data.toString()) };
    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const armUrl = `http://127.0.0.1:${addr.port}/api/decision/arm`;
    const runUrl = `http://127.0.0.1:${addr.port}/api/decision/run`;

    let cases = 0;
    for (const field of FREE_TEXT_FIELDS) {
      for (const shape of NON_STRING_SHAPES) {
        cases += 1;
        const label = `${field}=${shape.label}`;
        const payload = {
          taskId,
          route: 'approve',
          escalationTimestamp,
          by: 'TestUser',
          reason: 'testing',
          quiz: 'skipped',
        };
        payload[field] = shape.value;

        const ttyBefore = ttyMessages.length;
        const armResult = await httpRequest(armUrl, { method: 'POST', token, body: payload });

        if (armResult.status !== 400) {
          failures.push(`Test (16) FAILED [${label}]: expected 400, got ${armResult.status}: ${armResult.body}`);
        }
        if (armResult.body.includes('"armed":true')) {
          failures.push(`Test (16) FAILED [${label}]: response body reported armed:true: ${armResult.body}`);
        }
        if (ttyMessages.length !== ttyBefore) {
          failures.push(`Test (16) FAILED [${label}]: ${ttyMessages.length - ttyBefore} tty message(s) delivered for a refused arm: ${JSON.stringify(ttyMessages.slice(ttyBefore))}`);
        }
        if (fs.readFileSync(auditPath, 'utf8') !== auditBefore) {
          failures.push(`Test (16) FAILED [${label}]: .claude/review-audit.log was modified by a refused arm`);
        }
        // C6(a): no arm record was created holding an unvalidated value.
        const runResult = await httpRequest(runUrl, {
          method: 'POST',
          token,
          body: { taskId, code: 'AAAAAA' },
        });
        if (runResult.status !== 409) {
          failures.push(`Test (16) FAILED [${label}]: a run after a refused arm should be 409 (no arm), got ${runResult.status}: ${runResult.body}`);
        }
      }
    }

    if (cases !== 12) {
      failures.push(`Test (16) FAILED: expected 12 cross-product cases, ran ${cases}`);
    }
    if (fs.existsSync(path.join(tmpDir, '.claude', 'human-review', taskId, 'DECISION'))) {
      failures.push('Test (16) FAILED: a DECISION file was written during the refusal matrix');
    }
    if (failures.filter((f) => f.startsWith('Test (16)')).length === 0) {
      console.log(`  ✓ Test (16) passed (${cases} cases)`);
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (16) ERROR: ${err.message}`);
  }

  // Test (17): gh380 debug spec C3 -- the string content check covers
  // /[\r\n]/, but every prior test only ever sent \n, so the \r half was
  // unproven. Both fields, both characters.
  console.log('Test (17): C3 -- string \\n and \\r payloads refused for both fields...');
  try {
    const tmpDir = makeTestProject('17');
    const taskId = 'test-task-17';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    const ttyWrite = { write: () => {} };
    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const armUrl = `http://127.0.0.1:${server.address().port}/api/decision/arm`;

    for (const field of FREE_TEXT_FIELDS) {
      for (const [charLabel, char] of [['LF', '\n'], ['CR', '\r']]) {
        const payload = {
          taskId,
          route: 'approve',
          escalationTimestamp,
          by: 'TestUser',
          reason: 'testing',
          quiz: 'skipped',
        };
        payload[field] = `agent${char}quiz: passed-self-check`;
        const armResult = await httpRequest(armUrl, { method: 'POST', token, body: payload });
        if (armResult.status !== 400) {
          failures.push(`Test (17) FAILED [${field}/${charLabel}]: expected 400, got ${armResult.status}: ${armResult.body}`);
        }
      }
    }

    if (failures.filter((f) => f.startsWith('Test (17)')).length === 0) {
      console.log('  ✓ Test (17) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (17) ERROR: ${err.message}`);
  }

  // Test (18): gh380 debug spec C4 -- the undefined/null split, the
  // distinction most likely to be botched. Omitted hits the destructuring
  // default `= ''` and is depended upon; '' is legal; an explicit null is
  // not. A fix treating null and undefined alike fails this in one
  // direction or the other.
  console.log('Test (18): C4 -- omitted/empty/plain strings arm; explicit null is refused...');
  try {
    const tmpDir = makeTestProject('18');
    const taskId = 'test-task-18';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    const ttyWrite = { write: () => {} };
    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const armUrl = `http://127.0.0.1:${server.address().port}/api/decision/arm`;
    const base = { taskId, route: 'approve', escalationTimestamp, quiz: 'skipped' };

    const accepted = [
      ['both omitted', { ...base }],
      ['by omitted only', { ...base, reason: 'testing' }],
      ['reason omitted only', { ...base, by: 'TestUser' }],
      ['both empty strings', { ...base, by: '', reason: '' }],
      ['ordinary single-line strings', { ...base, by: 'TestUser', reason: 'testing' }],
    ];
    for (const [label, body] of accepted) {
      const result = await httpRequest(armUrl, { method: 'POST', token, body });
      if (result.status !== 200) {
        failures.push(`Test (18) FAILED [${label}]: expected 200, got ${result.status}: ${result.body}`);
      }
    }

    for (const field of FREE_TEXT_FIELDS) {
      const body = { ...base, by: 'TestUser', reason: 'testing' };
      body[field] = null;
      const result = await httpRequest(armUrl, { method: 'POST', token, body });
      if (result.status !== 400) {
        failures.push(`Test (18) FAILED [${field}: null]: expected 400, got ${result.status}: ${result.body}`);
      }
    }

    if (failures.filter((f) => f.startsWith('Test (18)')).length === 0) {
      console.log('  ✓ Test (18) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (18) ERROR: ${err.message}`);
  }

  // Test (19): gh380 debug spec C6(b) -- the positive/structural half of D3.
  // A legal arm->run cycle appends EXACTLY ONE line, asserted as a
  // newline-count delta of exactly 1 (a substring match would pass even if
  // an extra line were injected alongside the real one).
  console.log('Test (19): C6(b) -- a legal arm+run appends exactly one audit line...');
  try {
    const tmpDir = makeTestProject('19');
    const taskId = 'test-task-19';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    const auditPath = path.join(tmpDir, '.claude', 'review-audit.log');
    const before = fs.readFileSync(auditPath, 'utf8');

    let deliveredCode = null;
    const ttyWrite = {
      write: (data) => {
        const m = data.toString().match(/is (\S+) \(valid/);
        if (m) deliveredCode = m[1];
      },
    };
    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const armResult = await httpRequest(`http://127.0.0.1:${addr.port}/api/decision/arm`, {
      method: 'POST',
      token,
      body: { taskId, route: 'approve', escalationTimestamp, by: 'TestUser', reason: 'testing', quiz: 'skipped' },
    });

    if (armResult.status !== 200 || !deliveredCode) {
      failures.push(`Test (19) FAILED: arm should succeed and deliver a code, got ${armResult.status}: ${armResult.body}`);
    } else {
      const runResult = await httpRequest(`http://127.0.0.1:${addr.port}/api/decision/run`, {
        method: 'POST',
        token,
        body: { taskId, code: deliveredCode },
      });
      const after = fs.readFileSync(auditPath, 'utf8');
      const delta = countNewlines(after) - countNewlines(before);

      if (runResult.status !== 200) {
        failures.push(`Test (19) FAILED: run should succeed, got ${runResult.status}: ${runResult.body}`);
      } else if (delta !== 1) {
        failures.push(`Test (19) FAILED: expected a newline-count delta of exactly 1 on the audit log, got ${delta}: ${JSON.stringify(after)}`);
      } else {
        const appended = after.slice(before.length).replace(/\n$/, '');
        if (!/^\S+ decision-write-via-dashboard task=\S+ route=\S+ by=.*$/.test(appended)) {
          failures.push(`Test (19) FAILED: appended audit line does not match the expected shape: ${JSON.stringify(appended)}`);
        } else {
          console.log('  ✓ Test (19) passed');
        }
      }
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (19) ERROR: ${err.message}`);
  }

  // Test (20): gh380 debug spec C9 -- the sibling field `code` on
  // /api/decision/run is the same defect class. It was only incidentally
  // safe (via a length compare), and `code: null` threw a TypeError that
  // the outer catch surfaced to the client as internal exception text on a
  // security endpoint.
  console.log('Test (20): C9 -- non-string code is 4xx with no internal exception text...');
  try {
    const tmpDir = makeTestProject('20');
    const taskId = 'test-task-20';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    const ttyWrite = { write: () => {} };
    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const armUrl = `http://127.0.0.1:${addr.port}/api/decision/arm`;
    const runUrl = `http://127.0.0.1:${addr.port}/api/decision/run`;
    const armBody = { taskId, route: 'approve', escalationTimestamp, by: 'TestUser', reason: 'testing', quiz: 'skipped' };

    for (const shape of NON_STRING_SHAPES) {
      // Re-arm each time: a rejected code discards the outstanding arm, and
      // the point of this test is the code check, not the no-arm path.
      const armResult = await httpRequest(armUrl, { method: 'POST', token, body: armBody });
      if (armResult.status !== 200) {
        failures.push(`Test (20) FAILED [${shape.label}]: setup arm failed with ${armResult.status}`);
        continue;
      }
      const runResult = await httpRequest(runUrl, { method: 'POST', token, body: { taskId, code: shape.value } });
      if (runResult.status < 400 || runResult.status >= 500) {
        failures.push(`Test (20) FAILED [code=${shape.label}]: expected 4xx, got ${runResult.status}: ${runResult.body}`);
      }
      if (runResult.body.includes('Cannot read properties of')) {
        failures.push(`Test (20) FAILED [code=${shape.label}]: response leaked internal exception text: ${runResult.body}`);
      }
      if (fs.existsSync(path.join(tmpDir, '.claude', 'human-review', taskId, 'DECISION'))) {
        failures.push(`Test (20) FAILED [code=${shape.label}]: a DECISION file was written`);
      }
    }

    if (failures.filter((f) => f.startsWith('Test (20)')).length === 0) {
      console.log('  ✓ Test (20) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (20) ERROR: ${err.message}`);
  }

  // Test (21): gh380 debug spec C10 -- the asymmetry, stated as a
  // whole-endpoint property. Every field either handler destructures from
  // the parsed JSON must reject a non-string with a 4xx, so the fix
  // generalizes from "the by/reason bug" to "the field-discipline gap".
  console.log('Test (21): C10 -- every destructured field on both handlers rejects a non-string...');
  try {
    const tmpDir = makeTestProject('21');
    const taskId = 'test-task-21';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    const ttyWrite = { write: () => {} };
    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));

    const addr = server.address();
    const armUrl = `http://127.0.0.1:${addr.port}/api/decision/arm`;
    const runUrl = `http://127.0.0.1:${addr.port}/api/decision/run`;
    const armBody = { taskId, route: 'approve', escalationTimestamp, by: 'TestUser', reason: 'testing', quiz: 'skipped' };
    const nonString = ['forged\nquiz: passed-self-check'];

    for (const field of ARM_JSON_FIELDS) {
      const body = { ...armBody };
      body[field] = nonString;
      const result = await httpRequest(armUrl, { method: 'POST', token, body });
      if (result.status < 400 || result.status >= 500) {
        failures.push(`Test (21) FAILED [arm.${field}]: expected 4xx for a non-string, got ${result.status}: ${result.body}`);
      }
      if (result.body.includes('"armed":true')) {
        failures.push(`Test (21) FAILED [arm.${field}]: armed on a non-string field`);
      }
    }

    for (const field of RUN_JSON_FIELDS) {
      const armResult = await httpRequest(armUrl, { method: 'POST', token, body: armBody });
      if (armResult.status !== 200) {
        failures.push(`Test (21) FAILED [run.${field}]: setup arm failed with ${armResult.status}`);
        continue;
      }
      const body = { taskId, code: 'AAAAAA' };
      body[field] = nonString;
      const result = await httpRequest(runUrl, { method: 'POST', token, body });
      if (result.status < 400 || result.status >= 500) {
        failures.push(`Test (21) FAILED [run.${field}]: expected 4xx for a non-string, got ${result.status}: ${result.body}`);
      }
      if (result.body.includes('"written":true')) {
        failures.push(`Test (21) FAILED [run.${field}]: wrote a DECISION on a non-string field`);
      }
    }

    if (fs.existsSync(path.join(tmpDir, '.claude', 'human-review', taskId, 'DECISION'))) {
      failures.push('Test (21) FAILED: a DECISION file was written during the field sweep');
    }
    if (failures.filter((f) => f.startsWith('Test (21)')).length === 0) {
      console.log('  ✓ Test (21) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (21) ERROR: ${err.message}`);
  }

  // Test (22): same defect class one level up -- the request body itself is
  // a client-chosen type. A null/array/scalar body reached the destructure
  // and the resulting TypeError was echoed back to the client as internal
  // exception text on a security endpoint (the shape C9 forbids for `code`).
  console.log('Test (22): non-object request bodies are 4xx with no internal exception text...');
  try {
    const tmpDir = makeTestProject('22');
    const taskId = 'test-task-22';
    const escalationTimestamp = '2026-08-15T10:00:00Z';
    setupDecisionEnvironment(tmpDir, taskId, escalationTimestamp);

    const ttyWrite = { write: () => {} };
    const { server, token } = startServer(tmpDir, 0, { ttyWrite });
    await new Promise((r) => setTimeout(r, 100));
    const addr = server.address();

    for (const raw of ['null', '[1,2]', '"hello"', '42']) {
      for (const endpoint of ['arm', 'run']) {
        const result = await httpRequest(`http://127.0.0.1:${addr.port}/api/decision/${endpoint}`, {
          method: 'POST',
          token,
          rawBody: raw,
        });
        if (result.status < 400 || result.status >= 500) {
          failures.push(`Test (22) FAILED [${endpoint} ${raw}]: expected 4xx, got ${result.status}: ${result.body}`);
        }
        if (/Cannot destructure|Cannot read properties of/.test(result.body)) {
          failures.push(`Test (22) FAILED [${endpoint} ${raw}]: response leaked internal exception text: ${result.body}`);
        }
      }
    }

    if (failures.filter((f) => f.startsWith('Test (22)')).length === 0) {
      console.log('  ✓ Test (22) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (22) ERROR: ${err.message}`);
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
