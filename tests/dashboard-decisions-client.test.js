#!/usr/bin/env node
'use strict';

// Test suite for the Decisions section of the microworld dashboard client
// (index.html). Executes the client's inline module script under `vm`
// against a stub DOM, following tests/dashboard-client.test.js's technique --
// asserts rendered output, never source-text presence.
// Cases: (a) distinct section header + composed command, (b) absent when
// empty, (c) no answer-submitting control in the briefing view, (d) skip
// consequence text verbatim, (e) zero non-GET fetch calls across all views.

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const REPO_ROOT = path.resolve(__dirname, '..');

function makeFakeDiv() {
  return {
    _text: '',
    set textContent(v) { this._text = String(v); },
    get textContent() { return this._text; },
    get innerHTML() {
      return this._text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    },
  };
}

function makeFakeElement() {
  return {
    _html: '',
    set innerHTML(v) { this._html = v; },
    get innerHTML() { return this._html; },
    querySelectorAll() { return []; },
  };
}

function makeFetchStub(bundlesData, decisionsData, sourceData, fetchCalls) {
  return async (url, options) => {
    const method = (options && options.method) || 'GET';
    fetchCalls.push({ url: String(url), method });
    const pathname = String(url).split('?')[0];
    if (pathname === '/api/bundles') return { ok: true, status: 200, json: async () => bundlesData };
    if (pathname === '/api/decisions') return { ok: true, status: 200, json: async () => decisionsData };
    if (pathname === '/api/source') {
      if (!sourceData) return { ok: false, status: 404, json: async () => ({ error: 'not found' }) };
      return { ok: true, status: 200, json: async () => sourceData };
    }
    if (pathname === '/api/context') return { ok: true, status: 200, json: async () => ({ sha: 'deadbeef' }) };
    return { ok: false, status: 404, json: async () => ({ error: 'not found' }) };
  };
}

const emptyDecisions = { escalations: [], briefings: [], findings: [], pendingReview: [] };

// Executes the client's inline module script against a minimal stub DOM,
// with stubbed /api/bundles, /api/decisions and /api/source responses.
async function renderClient({ bundlesData = [], decisionsData = emptyDecisions, sourceData } = {}) {
  const html = fs.readFileSync(path.join(REPO_ROOT, 'bin/microworld-dashboard/index.html'), 'utf8');
  const match = html.match(/<script type="module">([\s\S]*?)<\/script>/);
  if (!match) throw new Error('could not find inline module script in index.html');

  const feedbackBlockSrc = fs.readFileSync(path.join(REPO_ROOT, 'bin/microworld-dashboard/feedback-block.js'), 'utf8');
  const decisionBlockSrc = fs.readFileSync(path.join(REPO_ROOT, 'bin/microworld-dashboard/decision-block.js'), 'utf8');

  const leftRail = makeFakeElement();
  const contentArea = makeFakeElement();
  const elementsById = { leftRail, contentArea };
  const fetchCalls = [];
  const sandbox = {
    document: {
      getElementById: (id) => elementsById[id] || null,
      createElement: () => makeFakeDiv(),
    },
    location: { search: '' },
    URLSearchParams,
    console,
    fetch: makeFetchStub(bundlesData, decisionsData, sourceData, fetchCalls),
    alert: () => {},
    setInterval: () => {},
    clearInterval: () => {},
    navigator: {},
  };
  vm.createContext(sandbox);
  // Same injection pattern server.js uses for the real page: these two files
  // become page globals (formatFeedbackBlock, composeDecisionBlock) before
  // the module script that calls them by name runs.
  vm.runInContext(feedbackBlockSrc, sandbox);
  vm.runInContext(decisionBlockSrc, sandbox);
  vm.runInContext(match[1], sandbox);
  await new Promise((r) => setTimeout(r, 50));
  return { leftRailHtml: leftRail.innerHTML, contentHtml: contentArea.innerHTML, fetchCalls };
}

async function runTests() {
  const failures = [];

  // Test (a): distinct section header + composed command present
  console.log('Test (a): Decisions header distinct from Working Bundles/Escalation Packets; composed command rendered...');
  try {
    const escalationEntry = {
      taskId: 'gh999',
      timestamp: '2026-08-01T00:00:00Z',
      trigger: 'unclear',
      microworld: 'none',
      packetMissing: false,
      packetBody: 'packet body text',
    };

    // Sub-check 1: with bundles present (so all three headers render),
    // the Decisions header is a distinct string from the other two.
    const withBundles = await renderClient({
      bundlesData: [
        { id: 'b1', unit: 'b1', description: 'd', status: null, source: 'working', functions: [] },
        { id: 'b2', unit: 'b2', description: 'd', status: null, source: 'packet', functions: [] },
      ],
      decisionsData: { ...emptyDecisions, escalations: [escalationEntry] },
    });
    if (!withBundles.leftRailHtml.includes('Working Bundles')) {
      failures.push('Test (a) FAILED: missing Working Bundles header');
    }
    if (!withBundles.leftRailHtml.includes('Escalation Packets')) {
      failures.push('Test (a) FAILED: missing Escalation Packets header');
    }
    if (!withBundles.leftRailHtml.includes('Decisions')) {
      failures.push('Test (a) FAILED: missing Decisions header');
    }

    // Sub-check 2: with no bundles, the escalation auto-selects and its
    // composed command appears in the rendered content.
    const decisionOnly = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, escalations: [escalationEntry] },
    });
    if (!decisionOnly.contentHtml.includes('.claude/human-review/gh999/DECISION')) {
      failures.push(`Test (a) FAILED: composed command not found in content: ${decisionOnly.contentHtml.slice(0, 400)}`);
    }
    if (!decisionOnly.contentHtml.includes('route: approve')) {
      failures.push(`Test (a) FAILED: composed command route not found in content`);
    }

    if (failures.filter((f) => f.includes('Test (a)')).length === 0) {
      console.log('  ✓ Test (a) passed');
    }
  } catch (err) {
    failures.push(`Test (a) ERROR: ${err.stack}`);
  }

  // Test (b): all four groups empty -> Decisions section absent
  console.log('Test (b): Decisions section absent when all four groups are empty...');
  try {
    const { leftRailHtml } = await renderClient({ bundlesData: [], decisionsData: emptyDecisions });
    if (leftRailHtml.includes('Decisions')) {
      failures.push(`Test (b) FAILED: Decisions header rendered with no data: ${leftRailHtml.slice(0, 400)}`);
    } else {
      console.log('  ✓ Test (b) passed');
    }
  } catch (err) {
    failures.push(`Test (b) ERROR: ${err.stack}`);
  }

  // Test (c): milestone-briefing view has no answer-submitting control
  console.log('Test (c): milestone-briefing view renders no answer control...');
  try {
    const sourceData = { lines: ['# Test Plan', 'Goal: do the thing'], startLine: 1, endLine: 2, totalLines: 2 };
    const { contentHtml, fetchCalls } = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, briefings: [{ path: 'docs/plans/x.md', heading: 'Test Plan' }] },
      sourceData,
    });
    if (contentHtml.includes('<form')) {
      failures.push('Test (c) FAILED: briefing view renders a <form');
    }
    if (contentHtml.includes('<button')) {
      failures.push('Test (c) FAILED: briefing view renders a <button');
    }
    const nonGet = fetchCalls.filter((c) => c.method !== 'GET');
    if (nonGet.length > 0) {
      failures.push(`Test (c) FAILED: non-GET fetch calls from briefing view: ${JSON.stringify(nonGet)}`);
    }
    if (failures.filter((f) => f.includes('Test (c)')).length === 0) {
      console.log('  ✓ Test (c) passed');
    }
  } catch (err) {
    failures.push(`Test (c) ERROR: ${err.stack}`);
  }

  // Test (d): pending-review view renders the skip: consequence text verbatim
  console.log('Test (d): pending-review view renders skip consequence verbatim...');
  try {
    const { contentHtml } = await renderClient({
      bundlesData: [],
      decisionsData: {
        ...emptyDecisions,
        pendingReview: [{ agentId: 'agent1', state: 'pending', reason: null, timestamp: '2026-08-01T00:00:00Z', unit: 'gh999' }],
      },
    });
    const expectedConsequence = 'This deletes the pending-review flag and abandons the review for this unit -- the reviewer will not run against it.';
    if (!contentHtml.includes(expectedConsequence)) {
      failures.push(`Test (d) FAILED: consequence text not found verbatim: ${contentHtml.slice(0, 600)}`);
    } else {
      console.log('  ✓ Test (d) passed');
    }
  } catch (err) {
    failures.push(`Test (d) ERROR: ${err.stack}`);
  }

  // Test (e): zero non-GET fetch calls across all four views
  console.log('Test (e): zero non-GET fetch calls across all four views...');
  try {
    const views = [
      {
        name: 'escalation',
        decisionsData: {
          ...emptyDecisions,
          escalations: [{ taskId: 'gh1', timestamp: '2026-08-01T00:00:00Z', trigger: 't', microworld: 'm', packetMissing: false, packetBody: 'body' }],
        },
      },
      {
        name: 'briefing',
        decisionsData: { ...emptyDecisions, briefings: [{ path: 'docs/plans/x.md', heading: 'X' }] },
        sourceData: { lines: ['# X'], startLine: 1, endLine: 1, totalLines: 1 },
      },
      {
        name: 'findings',
        decisionsData: {
          ...emptyDecisions,
          findings: [{ slug: 'plan-a', timestamp: '2026-08-01T00:00:00Z', count: 1, body: 'finding body', malformed: false }],
        },
      },
      {
        name: 'pending-review',
        decisionsData: {
          ...emptyDecisions,
          pendingReview: [{ agentId: 'agent1', state: 'pending', reason: null, timestamp: '2026-08-01T00:00:00Z', unit: 'gh1' }],
        },
      },
    ];

    for (const view of views) {
      const { fetchCalls } = await renderClient({ bundlesData: [], decisionsData: view.decisionsData, sourceData: view.sourceData });
      const nonGet = fetchCalls.filter((c) => c.method !== 'GET');
      if (nonGet.length > 0) {
        failures.push(`Test (e) FAILED: non-GET fetch calls in ${view.name} view: ${JSON.stringify(nonGet)}`);
      }
    }
    if (failures.filter((f) => f.includes('Test (e)')).length === 0) {
      console.log('  ✓ Test (e) passed');
    }
  } catch (err) {
    failures.push(`Test (e) ERROR: ${err.stack}`);
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
