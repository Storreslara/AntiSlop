#!/usr/bin/env node
'use strict';

// Test suite for decisions.js and GET /api/decisions: read-only enumeration
// of the four human-decision touchpoints (escalations, briefings, findings,
// pending-review). Fixture-driven against a real temp project root, no
// mocking of fs.

const fs = require('fs');
const path = require('path');
const os = require('os');
const http = require('http');
const { startServer } = require('../bin/microworld-dashboard/server');

function makeTestProject(name) {
  return fs.mkdtempSync(path.join(os.tmpdir(), `dashboard-decisions-${name}-`));
}

function writeFixture(filePath, content, mtime) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content);
  if (mtime) {
    fs.utimesSync(filePath, mtime, mtime);
  }
}

function httpRequest(url, { token } = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      port: urlObj.port,
      path: urlObj.pathname + urlObj.search,
      headers: token ? { 'X-Antislop-Token': token } : {},
    };
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    });
    req.on('error', reject);
    req.end();
  });
}

async function startAndFetch(tmpDir) {
  const { server, token } = startServer(tmpDir, 0);
  await new Promise((r) => setTimeout(r, 100));
  const port = server.address().port;
  const fetchDecisions = async () => {
    const result = await httpRequest(`http://127.0.0.1:${port}/api/decisions`, { token });
    return { status: result.status, decisions: result.status === 200 ? JSON.parse(result.body) : null, raw: result };
  };
  return { server, token, port, fetchDecisions };
}

async function runTests() {
  const failures = [];

  // Test (a): no-manifest escalation packet — the common case
  console.log('Test (a): escalation with PACKET.md, no manifest.json...');
  try {
    const tmpDir = makeTestProject('a');
    writeFixture(
      path.join(tmpDir, '.claude', 'reviewed', 'gh999.escalated'),
      'ESCALATE-TO-HUMAN gh999 2026-08-01T00:00:00Z trigger: heavy-unit escalation microworld: none\nbody...\n'
    );
    writeFixture(path.join(tmpDir, '.claude', 'human-review', 'gh999', 'PACKET.md'), 'Packet body text\n');

    const { server, fetchDecisions } = await startAndFetch(tmpDir);
    const { decisions } = await fetchDecisions();
    const entry = decisions.escalations.find((e) => e.taskId === 'gh999');

    if (!entry) {
      failures.push('Test (a) FAILED: no escalation entry for gh999');
    } else if (entry.packetBody !== 'Packet body text\n') {
      failures.push(`Test (a) FAILED: packetBody mismatch, got ${JSON.stringify(entry.packetBody)}`);
    } else if (entry.timestamp !== '2026-08-01T00:00:00Z') {
      failures.push(`Test (a) FAILED: timestamp mismatch, got ${entry.timestamp}`);
    } else if (entry.packetMissing !== false) {
      failures.push('Test (a) FAILED: packetMissing should be false');
    } else {
      console.log('  ✓ Test (a) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (a) ERROR: ${err.message}`);
  }

  // Test (b): escalated marker with no packet directory at all
  console.log('Test (b): escalated marker, packet directory absent...');
  try {
    const tmpDir = makeTestProject('b');
    writeFixture(
      path.join(tmpDir, '.claude', 'reviewed', 'gh998.escalated'),
      'ESCALATE-TO-HUMAN gh998 2026-08-01T00:00:00Z trigger: heavy-unit microworld: none\n'
    );

    const { server, fetchDecisions } = await startAndFetch(tmpDir);
    const { status, decisions } = await fetchDecisions();
    if (status !== 200) {
      failures.push(`Test (b) FAILED: expected 200, got ${status}`);
    }
    const entry = decisions.escalations.find((e) => e.taskId === 'gh998');
    if (!entry || entry.packetMissing !== true) {
      failures.push(`Test (b) FAILED: expected packetMissing:true, got ${JSON.stringify(entry)}`);
    } else {
      console.log('  ✓ Test (b) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (b) ERROR: ${err.message}`);
  }

  // Test (c): pending-review auto-created form + defer form
  console.log('Test (c): pending-review flags — auto-created and defer forms...');
  try {
    const tmpDir = makeTestProject('c');
    writeFixture(path.join(tmpDir, '.claude', '.pending-review.agent123'), '2026-08-01T00:00:00Z agent=agent123\n');
    writeFixture(path.join(tmpDir, '.claude', '.pending-review.agent456'), 'defer: waiting on tests\n');

    const { server, fetchDecisions } = await startAndFetch(tmpDir);
    const { decisions } = await fetchDecisions();
    const auto = decisions.pendingReview.find((e) => e.agentId === 'agent123');
    const deferred = decisions.pendingReview.find((e) => e.agentId === 'agent456');

    if (!auto || auto.state !== 'pending' || auto.timestamp !== '2026-08-01T00:00:00Z') {
      failures.push(`Test (c) FAILED: auto-created entry wrong, got ${JSON.stringify(auto)}`);
    } else if (!deferred || deferred.state !== 'deferred' || deferred.reason !== 'waiting on tests') {
      failures.push(`Test (c) FAILED: deferred entry wrong, got ${JSON.stringify(deferred)}`);
    } else {
      console.log('  ✓ Test (c) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (c) ERROR: ${err.message}`);
  }

  // Test (d): review-join linkage, including the unit:null path
  console.log('Test (d): pending-review to unit linkage, incl. unit:null...');
  try {
    const tmpDir = makeTestProject('d');
    const stampTime = new Date('2026-08-01T00:00:00Z');
    writeFixture(path.join(tmpDir, '.claude', '.pending-review.agentD'), '2026-08-01T00:00:00Z agent=agentD\n');
    writeFixture(
      path.join(tmpDir, '.claude', '.review-join.gh500'),
      '2026-08-01T00:00:00Z unit=gh500 prior=none prior_mtime=-\n',
      stampTime
    );

    const { server, fetchDecisions } = await startAndFetch(tmpDir);
    const { decisions: decisions1 } = await fetchDecisions();
    const entry1 = decisions1.pendingReview.find((e) => e.agentId === 'agentD');
    if (!entry1 || entry1.unit !== 'gh500') {
      failures.push(`Test (d) FAILED: expected unit gh500 before PASS, got ${JSON.stringify(entry1)}`);
    }

    // A PASS marker written after the stamp makes the join stale — unit:null.
    writeFixture(
      path.join(tmpDir, '.claude', 'reviewed', 'gh500.pass'),
      'PASS gh500 2026-08-01T00:05:00Z commit: abc123 criteria: bash tests/validate.sh\n',
      new Date(stampTime.getTime() + 60000)
    );
    const { decisions: decisions2 } = await fetchDecisions();
    const entry2 = decisions2.pendingReview.find((e) => e.agentId === 'agentD');
    if (!entry2 || entry2.unit !== null) {
      failures.push(`Test (d) FAILED: expected unit:null after PASS written after stamp, got ${JSON.stringify(entry2)}`);
    }

    // Invariant broken: two live review-join stamps, neither superseded by a
    // .pass. Every pending-review entry must be unit:null, not a guess.
    const tmpDir2 = makeTestProject('d-multi');
    writeFixture(path.join(tmpDir2, '.claude', '.pending-review.agentD1'), '2026-08-01T00:00:00Z agent=agentD1\n');
    writeFixture(path.join(tmpDir2, '.claude', '.pending-review.agentD2'), '2026-08-01T00:00:00Z agent=agentD2\n');
    writeFixture(
      path.join(tmpDir2, '.claude', '.review-join.gh501'),
      '2026-08-01T00:00:00Z unit=gh501 prior=none prior_mtime=-\n',
      stampTime
    );
    writeFixture(
      path.join(tmpDir2, '.claude', '.review-join.gh502'),
      '2026-08-01T00:00:10Z unit=gh502 prior=none prior_mtime=-\n',
      new Date(stampTime.getTime() + 10000)
    );

    const { server: server2, fetchDecisions: fetchDecisions2 } = await startAndFetch(tmpDir2);
    const { decisions: decisions3 } = await fetchDecisions2();
    const entry3a = decisions3.pendingReview.find((e) => e.agentId === 'agentD1');
    const entry3b = decisions3.pendingReview.find((e) => e.agentId === 'agentD2');
    if (!entry3a || entry3a.unit !== null || !entry3b || entry3b.unit !== null) {
      failures.push(`Test (d) FAILED: expected unit:null for both entries under multi-stamp ambiguity, got ${JSON.stringify([entry3a, entry3b])}`);
    }

    server2.close();
    fs.rmSync(tmpDir2, { recursive: true });

    if (failures.filter((f) => f.includes('Test (d)')).length === 0) {
      console.log('  ✓ Test (d) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (d) ERROR: ${err.message}`);
  }

  // Test (e): findings record, happy path + malformed first line
  console.log('Test (e): milestone findings record, incl. malformed...');
  try {
    const tmpDir = makeTestProject('e');
    writeFixture(
      path.join(tmpDir, '.claude', 'milestone-audit', 'plan-x', 'FINDINGS.md'),
      'FINDINGS plan-x 2026-08-01T00:00:00Z count: 2\n- finding one\n- finding two\n'
    );
    writeFixture(path.join(tmpDir, '.claude', 'milestone-audit', 'plan-y', 'FINDINGS.md'), 'not a valid first line\nmore text\n');

    const { server, fetchDecisions } = await startAndFetch(tmpDir);
    const { decisions } = await fetchDecisions();
    const good = decisions.findings.find((f) => f.slug === 'plan-x');
    const bad = decisions.findings.find((f) => !f.slug || f.malformed);

    if (!good || good.timestamp !== '2026-08-01T00:00:00Z' || good.count !== 2 || !good.body.includes('finding one')) {
      failures.push(`Test (e) FAILED: happy-path findings entry wrong, got ${JSON.stringify(good)}`);
    } else if (!bad || bad.malformed !== true) {
      failures.push(`Test (e) FAILED: malformed findings entry not flagged, got ${JSON.stringify(bad)}`);
    } else {
      console.log('  ✓ Test (e) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (e) ERROR: ${err.message}`);
  }

  // Test (f): docs/plans/*.md enumeration — path + first "# " heading
  console.log('Test (f): plan-doc briefing candidates...');
  try {
    const tmpDir = makeTestProject('f');
    writeFixture(path.join(tmpDir, 'docs', 'plans', '2026-01-01-test-plan.md'), '# Test Plan Title\n\nSome body text.\n');

    const { server, fetchDecisions } = await startAndFetch(tmpDir);
    const { decisions } = await fetchDecisions();
    const entry = decisions.briefings.find((b) => b.path.endsWith('2026-01-01-test-plan.md'));

    if (!entry || entry.heading !== 'Test Plan Title') {
      failures.push(`Test (f) FAILED: briefing entry wrong, got ${JSON.stringify(entry)}`);
    } else {
      console.log('  ✓ Test (f) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (f) ERROR: ${err.message}`);
  }

  // Test (g): all four sources absent — 200, each group an empty array
  console.log('Test (g): all sources absent — 200 with empty arrays...');
  try {
    const tmpDir = makeTestProject('g');

    const { server, fetchDecisions } = await startAndFetch(tmpDir);
    const { status, decisions } = await fetchDecisions();

    if (status !== 200) {
      failures.push(`Test (g) FAILED: expected 200, got ${status}`);
    } else if (
      !Array.isArray(decisions.escalations) || decisions.escalations.length !== 0 ||
      !Array.isArray(decisions.briefings) || decisions.briefings.length !== 0 ||
      !Array.isArray(decisions.findings) || decisions.findings.length !== 0 ||
      !Array.isArray(decisions.pendingReview) || decisions.pendingReview.length !== 0
    ) {
      failures.push(`Test (g) FAILED: expected all-empty groups, got ${JSON.stringify(decisions)}`);
    } else {
      console.log('  ✓ Test (g) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (g) ERROR: ${err.message}`);
  }

  // Test (h): no token, no header — 401
  console.log('Test (h): no token — 401...');
  try {
    const tmpDir = makeTestProject('h');
    const { server } = startServer(tmpDir, 0);
    await new Promise((r) => setTimeout(r, 100));
    const port = server.address().port;

    const result = await httpRequest(`http://127.0.0.1:${port}/api/decisions`);
    if (result.status !== 401) {
      failures.push(`Test (h) FAILED: expected 401, got ${result.status}`);
    } else {
      console.log('  ✓ Test (h) passed');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (h) ERROR: ${err.message}`);
  }

  // Test (i): changesBody / quizBody read from packet, fail-soft when absent
  // (gh375 Step 14, C14.1-C14.4).
  console.log('Test (i): changesBody/quizBody read from packet + fail-soft absence...');
  try {
    const tmpDir = makeTestProject('i');
    writeFixture(
      path.join(tmpDir, '.claude', 'reviewed', 'gh900.escalated'),
      'ESCALATE-TO-HUMAN gh900 2026-08-01T00:00:00Z trigger: heavy-unit microworld: none\n'
    );
    writeFixture(path.join(tmpDir, '.claude', 'human-review', 'gh900', 'PACKET.md'), 'Packet body\n');
    writeFixture(path.join(tmpDir, '.claude', 'human-review', 'gh900', 'CHANGES.md'), 'Changes body\n');
    writeFixture(path.join(tmpDir, '.claude', 'human-review', 'gh900', 'QUIZ.md'), 'Quiz body\n');

    writeFixture(
      path.join(tmpDir, '.claude', 'reviewed', 'gh901.escalated'),
      'ESCALATE-TO-HUMAN gh901 2026-08-01T00:00:00Z trigger: heavy-unit microworld: none\n'
    );
    writeFixture(path.join(tmpDir, '.claude', 'human-review', 'gh901', 'PACKET.md'), 'Packet body only\n');

    const { server, fetchDecisions } = await startAndFetch(tmpDir);
    const { decisions } = await fetchDecisions();
    const withBoth = decisions.escalations.find((e) => e.taskId === 'gh900');
    const withNeither = decisions.escalations.find((e) => e.taskId === 'gh901');

    if (!withBoth || withBoth.changesBody !== 'Changes body\n') {
      failures.push(`Test (i) FAILED: changesBody not read, got ${JSON.stringify(withBoth && withBoth.changesBody)}`);
    } else {
      console.log('OK   changesBody read from packet');
    }
    if (!withBoth || withBoth.quizBody !== 'Quiz body\n') {
      failures.push(`Test (i) FAILED: quizBody not read, got ${JSON.stringify(withBoth && withBoth.quizBody)}`);
    } else {
      console.log('OK   quizBody read from packet');
    }
    if (!withNeither || withNeither.changesBody !== null) {
      failures.push(`Test (i) FAILED: expected changesBody null when CHANGES.md absent, got ${JSON.stringify(withNeither && withNeither.changesBody)}`);
    } else {
      console.log('OK   changesBody null when CHANGES.md absent');
    }
    if (!withNeither || withNeither.quizBody !== null) {
      failures.push(`Test (i) FAILED: expected quizBody null when QUIZ.md absent, got ${JSON.stringify(withNeither && withNeither.quizBody)}`);
    } else {
      console.log('OK   quizBody null when QUIZ.md absent');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (i) ERROR: ${err.message}`);
  }

  // Test (j): QUIZ-ANSWERS.md must never enter the /api/decisions payload
  // (R6 structural pin, C14.14).
  console.log('Test (j): answer key never enters the decisions payload...');
  try {
    const tmpDir = makeTestProject('j');
    writeFixture(
      path.join(tmpDir, '.claude', 'reviewed', 'gh902.escalated'),
      'ESCALATE-TO-HUMAN gh902 2026-08-01T00:00:00Z trigger: heavy-unit microworld: none\n'
    );
    writeFixture(path.join(tmpDir, '.claude', 'human-review', 'gh902', 'PACKET.md'), 'Packet body\n');
    writeFixture(path.join(tmpDir, '.claude', 'human-review', 'gh902', 'QUIZ.md'), 'Quiz body\n');
    writeFixture(path.join(tmpDir, '.claude', 'human-review', 'gh902', 'QUIZ-ANSWERS.md'), 'SECRET-ANSWER-TEXT\n');

    const { server, fetchDecisions } = await startAndFetch(tmpDir);
    const { decisions } = await fetchDecisions();
    const payload = JSON.stringify(decisions);

    if (payload.includes('SECRET-ANSWER-TEXT')) {
      failures.push('Test (j) FAILED: answer key text leaked into /api/decisions payload');
    } else {
      console.log('OK   answer key never enters the decisions payload');
    }

    server.close();
    fs.rmSync(tmpDir, { recursive: true });
  } catch (err) {
    failures.push(`Test (j) ERROR: ${err.message}`);
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
