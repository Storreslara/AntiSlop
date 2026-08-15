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

// gh375 Step 14: interactive controls (selects, buttons) that new tests
// drive directly -- set .value then fire('change'), or fire('click') --
// standing in for a real element's addEventListener/dispatchEvent pair.
function makeFakeControl(initialValue = '') {
  return {
    value: initialValue,
    _listeners: {},
    addEventListener(type, cb) { this._listeners[type] = cb; },
    async fire(type) {
      const cb = this._listeners[type];
      if (cb) await cb({ preventDefault() {} });
    },
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
  const elementsById = {
    leftRail,
    contentArea,
    // gh375 Step 14: escalation-form controls the new tests drive directly.
    // Step 1: route and quiz are now radiogroup buttons
    'routeOption-approve': makeFakeControl(''),
    'routeOption-reject': makeFakeControl(''),
    'routeOption-direct': makeFakeControl(''),
    'quizOption-skipped': makeFakeControl(''),
    'quizOption-passed-self-check': makeFakeControl(''),
    'quizOption-none-offered': makeFakeControl(''),
    escalationReason: makeFakeControl(''),
    escalationBy: makeFakeControl(''),
    decisionCopyBtn: makeFakeControl(),
    quizRevealBtn: makeFakeControl(),
    quizAnswerContainer: makeFakeElement(),
  };
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
  return {
    leftRailHtml: leftRail.innerHTML,
    contentHtml: contentArea.innerHTML,
    fetchCalls,
    // Live references (gh375 Step 14 tests): contentArea.innerHTML re-reads
    // the latest render after firing a control; elementsById lets a test
    // grab a specific control (e.g. quizRevealBtn) to fire an event on.
    contentArea,
    leftRail,
    elementsById,
  };
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

  // Test (f): pill-styled radiogroup controls — quiz rendered on approve,
  // absent on reject, defaults to skipped; composed command reflects selections
  // (Step 1).
  console.log('Test (f): pill-styled radiogroup controls — composed command assertions...');
  try {
    const escalationEntry = {
      taskId: 'gh910', timestamp: '2026-08-15T00:00:00Z', trigger: 't', microworld: 'm',
      packetMissing: false, packetBody: 'packet body', changesBody: null, quizBody: null,
    };
    const { contentArea, elementsById } = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, escalations: [escalationEntry] },
    });

    // Sub-check 1: quiz radiogroup rendered on default (approve) route
    if (!contentArea.innerHTML.includes('id="quizOption-skipped"')) {
      failures.push('Test (f) FAILED: quiz radiogroup not rendered on default (approve) route');
    } else {
      console.log('OK   quiz radiogroup rendered on approve');
    }

    // Sub-check 2: default composed command contains quiz: skipped (no interaction)
    if (!contentArea.innerHTML.includes('quiz: skipped')) {
      failures.push(`Test (f) FAILED: composed command does not contain "quiz: skipped" by default: ${contentArea.innerHTML.slice(0, 800)}`);
    } else {
      console.log('OK   composed command defaults to quiz: skipped');
    }

    // Sub-check 3: clicking quizOption-passed-self-check updates composed command
    await elementsById['quizOption-passed-self-check'].fire('click');
    if (!contentArea.innerHTML.includes('quiz: passed-self-check')) {
      failures.push(`Test (f) FAILED: composed command does not contain "quiz: passed-self-check" after click: ${contentArea.innerHTML.slice(0, 800)}`);
    } else {
      console.log('OK   composed command reflects quiz: passed-self-check after click');
    }

    // Sub-check 4: clicking routeOption-reject removes quiz radiogroup
    await elementsById['routeOption-reject'].fire('click');
    if (contentArea.innerHTML.includes('id="quizOption-skipped"')) {
      failures.push('Test (f) FAILED: quiz radiogroup still rendered after switching to reject');
    } else {
      console.log('OK   quiz radiogroup absent on reject route');
    }

    if (failures.filter((f) => f.includes('Test (f)')).length === 0) {
      console.log('  ✓ Test (f) passed');
    }
  } catch (err) {
    failures.push(`Test (f) ERROR: ${err.stack}`);
  }

  // Test (g): CHANGES.md / QUIZ.md pane rendering — presence, reading order,
  // and clean omission when absent (gh375 Step 14).
  console.log('Test (g): CHANGES.md / QUIZ.md pane rendering — presence, ordering, absence...');
  try {
    const withBoth = {
      taskId: 'gh911', timestamp: '2026-08-15T00:00:00Z', trigger: 't', microworld: 'm',
      packetMissing: false, packetBody: 'PACKET BODY TEXT',
      changesBody: 'CHANGES BODY TEXT', quizBody: 'QUIZ BODY TEXT',
    };
    const { contentArea } = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, escalations: [withBoth] },
    });
    const html = contentArea.innerHTML;

    if (!html.includes('CHANGES BODY TEXT')) {
      failures.push('Test (g) FAILED: CHANGES.md body not rendered');
    } else {
      console.log('OK   escalation view renders CHANGES.md');
    }
    if (!html.includes('QUIZ BODY TEXT')) {
      failures.push('Test (g) FAILED: QUIZ.md body not rendered');
    } else {
      console.log('OK   escalation view renders QUIZ.md');
    }

    const changesIdx = html.indexOf('CHANGES BODY TEXT');
    const packetIdx = html.indexOf('PACKET BODY TEXT');
    const quizIdx = html.indexOf('QUIZ BODY TEXT');
    if (!(changesIdx !== -1 && packetIdx !== -1 && changesIdx < packetIdx)) {
      failures.push('Test (g) FAILED: CHANGES.md not rendered before PACKET.md');
    } else {
      console.log('OK   CHANGES.md rendered before PACKET.md');
    }
    if (!(packetIdx !== -1 && quizIdx !== -1 && quizIdx > packetIdx)) {
      failures.push('Test (g) FAILED: QUIZ.md not rendered after PACKET.md');
    } else {
      console.log('OK   QUIZ.md rendered after PACKET.md');
    }

    const withNeither = {
      taskId: 'gh912', timestamp: '2026-08-15T00:00:00Z', trigger: 't', microworld: 'm',
      packetMissing: false, packetBody: 'ONLY PACKET TEXT',
      changesBody: null, quizBody: null,
    };
    const { contentArea: contentArea2 } = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, escalations: [withNeither] },
    });
    const html2 = contentArea2.innerHTML;
    if (html2.includes('CHANGES.md')) {
      failures.push('Test (g) FAILED: CHANGES.md label rendered though CHANGES.md is absent');
    } else {
      console.log('OK   absent CHANGES.md renders no empty pane');
    }
    if (html2.includes('QUIZ.md')) {
      failures.push('Test (g) FAILED: QUIZ.md label rendered though QUIZ.md is absent');
    } else {
      console.log('OK   absent QUIZ.md renders no quiz pane');
    }
    if (html2.includes('quizRevealBtn') || html2.includes('Reveal answer key')) {
      failures.push('Test (g) FAILED: reveal control rendered though QUIZ.md is absent');
    } else {
      console.log('OK   reveal control absent when no QUIZ.md');
    }

    if (failures.filter((f) => f.includes('Test (g)')).length === 0) {
      console.log('  ✓ Test (g) passed');
    }
  } catch (err) {
    failures.push(`Test (g) ERROR: ${err.stack}`);
  }

  // Test (h): answer-key reveal — absent before click, on-demand fetch
  // through /api/source on click, inline error on a failed/404 fetch
  // (gh375 Step 14, R6 structural exclusion).
  console.log('Test (h): reveal control — on-demand answer-key fetch behavior...');
  try {
    const entryWithQuiz = {
      taskId: 'gh913', timestamp: '2026-08-15T00:00:00Z', trigger: 't', microworld: 'm',
      packetMissing: false, packetBody: 'packet body',
      changesBody: null, quizBody: 'QUIZ BODY TEXT',
    };

    // Sub-case: successful reveal.
    const sourceData = { lines: ['ANSWER: 42'], startLine: 1, endLine: 1, totalLines: 1 };
    const { elementsById, fetchCalls } = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, escalations: [entryWithQuiz] },
      sourceData,
    });

    if (elementsById.quizAnswerContainer.innerHTML.includes('ANSWER: 42')) {
      failures.push('Test (h) FAILED: answer key text present before reveal click');
    } else {
      console.log('OK   answer key absent before reveal click');
    }

    await elementsById.quizRevealBtn.fire('click');

    if (!elementsById.quizAnswerContainer.innerHTML.includes('ANSWER: 42')) {
      failures.push(`Test (h) FAILED: answer key not rendered after reveal click: ${elementsById.quizAnswerContainer.innerHTML.slice(0, 800)}`);
    } else {
      console.log('OK   answer key rendered after reveal click');
    }

    const sourceCall = fetchCalls.find((c) => c.url.includes('QUIZ-ANSWERS.md'));
    if (!sourceCall || !sourceCall.url.startsWith('/api/source?file=')) {
      failures.push(`Test (h) FAILED: reveal did not fetch QUIZ-ANSWERS.md through /api/source, got ${JSON.stringify(fetchCalls)}`);
    }

    // Sub-case: failed/404 fetch renders the inline-error treatment, never
    // throws (no sourceData -> makeFetchStub 404s /api/source).
    const { elementsById: elementsById2 } = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, escalations: [entryWithQuiz] },
    });
    await elementsById2.quizRevealBtn.fire('click');
    if (!/error/i.test(elementsById2.quizAnswerContainer.innerHTML)) {
      failures.push(`Test (h) FAILED: failed reveal fetch did not render inline error: ${elementsById2.quizAnswerContainer.innerHTML.slice(0, 800)}`);
    } else {
      console.log('OK   reveal fetch failure renders inline error');
    }

    if (failures.filter((f) => f.includes('Test (h)')).length === 0) {
      console.log('  ✓ Test (h) passed');
    }
  } catch (err) {
    failures.push(`Test (h) ERROR: ${err.stack}`);
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
