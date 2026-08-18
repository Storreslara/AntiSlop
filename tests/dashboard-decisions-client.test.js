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

function makeFetchStub(bundlesData, decisionsData, sourceData, fetchCalls, contextData) {
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
    if (pathname === '/api/context') {
      if (contextData === undefined) {
        // Default: return sha and empty userName
        return { ok: true, status: 200, json: async () => ({ sha: 'deadbeef', userName: '' }) };
      } else if (contextData.ok === false) {
        // Failure mode
        return { ok: false, status: contextData.status || 500, json: async () => ({ error: contextData.error || 'error' }) };
      } else {
        // Custom contextData
        return { ok: true, status: 200, json: async () => contextData };
      }
    }
    return { ok: false, status: 404, json: async () => ({ error: 'not found' }) };
  };
}

const emptyDecisions = { escalations: [], briefings: [], findings: [], pendingReview: [] };

// Executes the client's inline module script against a minimal stub DOM,
// with stubbed /api/bundles, /api/decisions and /api/source responses.
// markdownStub: optional function (s) => string to replace renderMarkdown, for testing single-implementation (U2-C2).
// contextData: optional context data for /api/context stub; can be { sha, userName } or { ok: false, status, error }.
async function renderClient({ bundlesData = [], decisionsData = emptyDecisions, sourceData, markdownStub, contextData } = {}) {
  const html = fs.readFileSync(path.join(REPO_ROOT, 'bin/microworld-dashboard/index.html'), 'utf8');
  const match = html.match(/<script type="module">([\s\S]*?)<\/script>/);
  if (!match) throw new Error('could not find inline module script in index.html');

  const feedbackBlockSrc = fs.readFileSync(path.join(REPO_ROOT, 'bin/microworld-dashboard/feedback-block.js'), 'utf8');
  const decisionBlockSrc = fs.readFileSync(path.join(REPO_ROOT, 'bin/microworld-dashboard/decision-block.js'), 'utf8');
  const markdownLiteSrc = fs.readFileSync(path.join(REPO_ROOT, 'bin/microworld-dashboard/markdown-lite.js'), 'utf8');

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
    briefingExcerptPane: makeFakeElement(),
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
    fetch: makeFetchStub(bundlesData, decisionsData, sourceData, fetchCalls, contextData),
    alert: () => {},
    setInterval: () => {},
    clearInterval: () => {},
    navigator: {},
  };
  vm.createContext(sandbox);
  // Same injection pattern server.js uses for the real page: these files
  // become page globals (formatFeedbackBlock, composeDecisionBlock, renderMarkdown)
  // before the module script that calls them by name runs.
  vm.runInContext(feedbackBlockSrc, sandbox);
  vm.runInContext(decisionBlockSrc, sandbox);
  if (markdownStub) {
    // For U2-C2: inject a stub that returns a sentinel value instead of the real renderer.
    vm.runInContext(`const renderMarkdown = ${markdownStub.toString()};`, sandbox);
  } else {
    vm.runInContext(markdownLiteSrc, sandbox);
  }
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
    // gh375's harness comment claiming click simulation isn't supported was
    // wrong: selectDecisionView is a top-level declaration in the module
    // script, so it's reachable on the sandbox directly (dash-ux-4 D3 fix).
    sandbox,
  };
}

async function runTests() {
  const failures = [];

  // Test (a): new section headers and auto-select behavior
  console.log('Test (a): new Review/Plans & Specs/Microworlds headers; auto-select of escalations...');
  try {
    const escalationEntry = {
      taskId: 'gh999',
      timestamp: '2026-08-01T00:00:00Z',
      trigger: 'unclear',
      microworld: 'none',
      packetMissing: false,
      packetBody: 'packet body text',
    };

    // Sub-check 1: with bundles and decisions present, all three headers render.
    const withBundles = await renderClient({
      bundlesData: [
        { id: 'b1', unit: 'b1', description: 'd', status: null, source: 'working', functions: [] },
        { id: 'b2', unit: 'b2', description: 'd', status: null, source: 'packet', functions: [] },
      ],
      decisionsData: {
        ...emptyDecisions,
        escalations: [escalationEntry],
        briefings: [{ path: 'docs/plans/x.md', heading: 'Test' }],
      },
    });
    if (!withBundles.leftRailHtml.includes('Microworlds')) {
      failures.push('Test (a) FAILED: missing Microworlds header');
    }
    if (!withBundles.leftRailHtml.includes('Plans & Specs')) {
      failures.push('Test (a) FAILED: missing Plans & Specs header');
    }
    if (!withBundles.leftRailHtml.includes('Review')) {
      failures.push('Test (a) FAILED: missing Review header');
    }
    if (withBundles.leftRailHtml.includes('Decisions')) {
      failures.push('Test (a) FAILED: old Decisions header still present');
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

  // Test (b): Review section absent when all four groups are empty
  console.log('Test (b): Review section absent when all four groups are empty...');
  try {
    const { leftRailHtml } = await renderClient({ bundlesData: [], decisionsData: emptyDecisions });
    if (leftRailHtml.includes('Review')) {
      failures.push(`Test (b) FAILED: Review header rendered with no data: ${leftRailHtml.slice(0, 400)}`);
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

  // Test (i): U2-C2 single-implementation proof — stub renderMarkdown sentinel
  // must appear in D1-D3 and D6 (synchronous renders) and none of the
  // composed-text verbatim sites (V1, V2, V3, V4).
  console.log('Test (i): U2-C2 single-implementation proof — sentinel injection test...');
  try {
    const stubRenderMarkdown = (s) => 'MDSENTINEL:' + String(s);
    const escalationEntry = {
      taskId: 'gu99', timestamp: '2026-08-01T00:00:00Z', trigger: 't', microworld: 'm',
      packetMissing: false, packetBody: 'packet-text', changesBody: 'changes-text', quizBody: 'quiz-text',
    };
    const findingEntry = { slug: 'finding-slug', timestamp: '2026-08-01T00:00:00Z', count: 1, body: 'finding-body', malformed: false };

    // Sub-case 1: Test D1, D2, D3 (escalation view)
    const { contentHtml: escalationHtml } = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, escalations: [escalationEntry] },
      markdownStub: stubRenderMarkdown,
    });

    const d1 = escalationHtml.includes('MDSENTINEL:changes-text');
    const d2 = escalationHtml.includes('MDSENTINEL:packet-text');
    const d3 = escalationHtml.includes('MDSENTINEL:quiz-text');

    if (!d1) failures.push('Test (i) FAILED: D1 (CHANGES.md) does not contain sentinel');
    if (!d2) failures.push('Test (i) FAILED: D2 (PACKET.md) does not contain sentinel');
    if (!d3) failures.push('Test (i) FAILED: D3 (QUIZ.md) does not contain sentinel');

    // V1 (composed escalation-decision command) must NOT contain sentinel
    if (escalationHtml.match(/MDSENTINEL:.*route:/)) {
      failures.push('Test (i) FAILED: V1 (composed command) contains sentinel (should be escaped, not rendered)');
    }

    // Sub-case 2: Test D6 (findings view)
    const { contentHtml: findingsHtml } = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, findings: [findingEntry] },
      markdownStub: stubRenderMarkdown,
    });

    const d6 = findingsHtml.includes('MDSENTINEL:finding-body');
    if (!d6) failures.push('Test (i) FAILED: D6 (findings body) does not contain sentinel');

    if (failures.filter((f) => f.includes('Test (i)')).length === 0) {
      console.log('  ✓ Test (i) passed');
    }
  } catch (err) {
    failures.push(`Test (i) ERROR: ${err.stack}`);
  }

  // Test (i2): D4 (quiz answer reveal) also uses renderMarkdown
  console.log('Test (i2): U2-C2 D4 quiz reveal sentinel check...');
  try {
    const stubRenderMarkdown = (s) => 'MDSENTINEL:' + String(s);
    const escalationEntry = {
      taskId: 'gu88', timestamp: '2026-08-01T00:00:00Z', trigger: 't', microworld: 'm',
      packetMissing: false, packetBody: 'packet', changesBody: null, quizBody: 'has-quiz',
    };
    const sourceData = { lines: ['answer-line'], startLine: 1, endLine: 1, totalLines: 1 };

    const { elementsById } = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, escalations: [escalationEntry] },
      sourceData,
      markdownStub: stubRenderMarkdown,
    });

    // Before click, no answer visible
    if (elementsById.quizAnswerContainer?.innerHTML?.includes('MDSENTINEL')) {
      failures.push('Test (i2) FAILED: answer visible before reveal click');
    }

    // After click, answer should contain sentinel
    await elementsById.quizRevealBtn.fire('click');
    const html = elementsById.quizAnswerContainer?.innerHTML || '';
    if (!html.includes('MDSENTINEL:answer-line')) {
      failures.push(`Test (i2) FAILED: D4 (quiz answer) does not contain sentinel after reveal: ${html.slice(0, 300)}`);
    } else {
      console.log('OK   D4 quiz answer contains sentinel');
    }

    if (failures.filter((f) => f.includes('Test (i2)')).length === 0) {
      console.log('  ✓ Test (i2) passed');
    }
  } catch (err) {
    failures.push(`Test (i2) ERROR: ${err.stack}`);
  }

  // Test (i3): D5 (briefing excerpt) also uses renderMarkdown
  console.log('Test (i3): U2-C2 D5 briefing excerpt sentinel check...');
  try {
    const stubRenderMarkdown = (s) => 'MDSENTINEL:' + String(s);
    const sourceData = { lines: ['briefing-excerpt-line'], startLine: 1, endLine: 1, totalLines: 1 };

    const { elementsById } = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, briefings: [{ path: 'docs/plans/x.md', heading: 'X' }] },
      sourceData,
      markdownStub: stubRenderMarkdown,
    });

    const html = elementsById.briefingExcerptPane?.innerHTML || '';
    if (!html.includes('MDSENTINEL:briefing-excerpt-line')) {
      failures.push(`Test (i3) FAILED: D5 (briefing excerpt) does not contain sentinel: ${html.slice(0, 300)}`);
    } else {
      console.log('OK   D5 briefing excerpt contains sentinel');
    }

    if (failures.filter((f) => f.includes('Test (i3)')).length === 0) {
      console.log('  ✓ Test (i3) passed');
    }
  } catch (err) {
    failures.push(`Test (i3) ERROR: ${err.stack}`);
  }

  // Test (j): U2-C4 real renderer proves shipped code uses the module
  console.log('Test (j): U2-C4 real renderer at D6 with bold text...');
  try {
    const findingEntry = { slug: 'test-finding', timestamp: '2026-08-01T00:00:00Z', count: 1, body: '**bold text**', malformed: false };
    const { contentHtml } = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, findings: [findingEntry] },
    });

    // D6 should render **bold text** as <strong>bold text</strong>
    if (!contentHtml.includes('<strong>bold text</strong>')) {
      failures.push(`Test (j) FAILED: D6 did not render markdown bold: ${contentHtml.slice(0, 1000)}`);
    } else {
      console.log('OK   D6 renders markdown bold');
    }

    // V2 (findings paste-back block, same render, same finding.body) must stay
    // verbatim: the literal source text, no markdown applied.
    if (!contentHtml.includes('**bold text**')) {
      failures.push(`Test (j) FAILED: V2 (paste-back pane) does not contain the literal '**bold text**': ${contentHtml.slice(0, 1000)}`);
    } else {
      console.log('OK   V2 paste-back pane keeps literal **bold text**');
    }
    if (contentHtml.includes('<strong>bold text</strong>', contentHtml.indexOf('Paste-back block'))) {
      failures.push('Test (j) FAILED: V2 (paste-back pane) contains <strong> -- markdown over-applied to a verbatim pane');
    } else {
      console.log('OK   V2 paste-back pane contains no <strong>');
    }

    if (failures.filter((f) => f.includes('Test (j)')).length === 0) {
      console.log('  ✓ Test (j) passed');
    }
  } catch (err) {
    failures.push(`Test (j) ERROR: ${err.stack}`);
  }

  // Test (k): U2-C5 truncation marker is truthful in quiz answer reveal (D4)
  console.log('Test (k): U2-C5 truncation marker truthful...');
  try {
    const escalationEntry = { taskId: 'gu77', timestamp: '2026-08-01T00:00:00Z', trigger: 't', microworld: 'm', packetMissing: false, packetBody: 'packet', changesBody: null, quizBody: 'has-quiz' };

    // Sub-case 1: totalLines > endLine, marker MUST appear
    const sourceDataTruncated = { lines: ['a', 'b'], startLine: 1, endLine: 2, totalLines: 100 };
    const { elementsById: elementsById1 } = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, escalations: [escalationEntry] },
      sourceData: sourceDataTruncated,
    });
    await elementsById1.quizRevealBtn.fire('click');
    if (!elementsById1.quizAnswerContainer?.innerHTML?.includes('Truncated at line 2 of 100')) {
      failures.push(`Test (k) FAILED: truncation marker missing when totalLines > endLine: ${elementsById1.quizAnswerContainer?.innerHTML?.slice(0, 400)}`);
    } else {
      console.log('OK   truncation marker present when totalLines > endLine');
    }

    // Sub-case 2: totalLines <= endLine, marker MUST NOT appear
    const sourceDataNotTruncated = { lines: ['x'], startLine: 1, endLine: 1, totalLines: 1 };
    const escalationEntry2 = { taskId: 'gu66', timestamp: '2026-08-01T00:00:00Z', trigger: 't', microworld: 'm', packetMissing: false, packetBody: 'packet', changesBody: null, quizBody: 'has-quiz-2' };
    const { elementsById: elementsById2 } = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, escalations: [escalationEntry2] },
      sourceData: sourceDataNotTruncated,
    });
    await elementsById2.quizRevealBtn.fire('click');
    if (elementsById2.quizAnswerContainer?.innerHTML?.includes('Truncated at line')) {
      failures.push('Test (k) FAILED: truncation marker present when totalLines <= endLine');
    } else {
      console.log('OK   truncation marker absent when totalLines <= endLine');
    }

    if (failures.filter((f) => f.includes('Test (k)')).length === 0) {
      console.log('  ✓ Test (k) passed');
    }
  } catch (err) {
    failures.push(`Test (k) ERROR: ${err.stack}`);
  }

  // Test (l): U2-C6 document-not-per-line rendering in quiz answer reveal (D4)
  console.log('Test (l): U2-C6 document rendering, not per-line...');
  try {
    const escalationEntry = { taskId: 'gu55', timestamp: '2026-08-01T00:00:00Z', trigger: 't', microworld: 'm', packetMissing: false, packetBody: 'packet', changesBody: null, quizBody: 'has-quiz' };
    const sourceData = { lines: ['- a', '- b'], startLine: 1, endLine: 2, totalLines: 2 };
    const { elementsById } = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, escalations: [escalationEntry] },
      sourceData,
    });

    await elementsById.quizRevealBtn.fire('click');
    const quizAnswerHtml = elementsById.quizAnswerContainer?.innerHTML || '';
    // Should render as ONE <ul> with TWO <li>, not per-line divs
    const ulCount = (quizAnswerHtml.match(/<ul>/g) || []).length;
    const liCount = (quizAnswerHtml.match(/<li>/g) || []).length;
    const excerptLineCount = (quizAnswerHtml.match(/excerpt-line/g) || []).length;

    if (ulCount !== 1) {
      failures.push(`Test (l) FAILED: expected exactly one <ul>, got ${ulCount}: ${quizAnswerHtml.slice(0, 400)}`);
    } else {
      console.log('OK   exactly one <ul> rendered');
    }
    if (liCount !== 2) {
      failures.push(`Test (l) FAILED: expected exactly two <li>, got ${liCount}: ${quizAnswerHtml.slice(0, 400)}`);
    } else {
      console.log('OK   exactly two <li> rendered');
    }
    if (excerptLineCount !== 0) {
      failures.push(`Test (l) FAILED: should not use .excerpt-line class, found ${excerptLineCount} occurrences`);
    } else {
      console.log('OK   no .excerpt-line divs in document rendering');
    }

    if (failures.filter((f) => f.includes('Test (l)')).length === 0) {
      console.log('  ✓ Test (l) passed');
    }
  } catch (err) {
    failures.push(`Test (l) ERROR: ${err.stack}`);
  }

  // Test (k2): U2-C5 truncation marker is truthful in the D5 briefing excerpt pane
  console.log('Test (k2): U2-C5 truncation marker truthful (D5 briefing excerpt)...');
  try {
    // Sub-case 1: totalLines > endLine, marker MUST appear
    const sourceDataTruncated = { lines: ['a', 'b'], startLine: 1, endLine: 400, totalLines: 1200 };
    const { elementsById: elementsById1 } = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, briefings: [{ path: 'docs/plans/x.md', heading: 'X' }] },
      sourceData: sourceDataTruncated,
    });
    if (!elementsById1.briefingExcerptPane?.innerHTML?.includes('Truncated at line 400 of 1200')) {
      failures.push(`Test (k2) FAILED: truncation marker missing when totalLines > endLine: ${elementsById1.briefingExcerptPane?.innerHTML?.slice(0, 400)}`);
    } else {
      console.log('OK   D5 truncation marker present when totalLines > endLine');
    }

    // Sub-case 2: totalLines <= endLine, marker MUST NOT appear
    const sourceDataNotTruncated = { lines: ['x'], startLine: 1, endLine: 120, totalLines: 120 };
    const { elementsById: elementsById2 } = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, briefings: [{ path: 'docs/plans/y.md', heading: 'Y' }] },
      sourceData: sourceDataNotTruncated,
    });
    if (elementsById2.briefingExcerptPane?.innerHTML?.includes('Truncated at line')) {
      failures.push('Test (k2) FAILED: truncation marker present when totalLines <= endLine');
    } else {
      console.log('OK   D5 truncation marker absent when totalLines <= endLine');
    }

    if (failures.filter((f) => f.includes('Test (k2)')).length === 0) {
      console.log('  ✓ Test (k2) passed');
    }
  } catch (err) {
    failures.push(`Test (k2) ERROR: ${err.stack}`);
  }

  // Test (l2): U2-C6 document-not-per-line rendering in the D5 briefing excerpt pane
  console.log('Test (l2): U2-C6 document rendering, not per-line (D5 briefing excerpt)...');
  try {
    const sourceData = { lines: ['- a', '- b'], startLine: 1, endLine: 2, totalLines: 2 };
    const { elementsById } = await renderClient({
      bundlesData: [],
      decisionsData: { ...emptyDecisions, briefings: [{ path: 'docs/plans/z.md', heading: 'Z' }] },
      sourceData,
    });

    const briefingHtml = elementsById.briefingExcerptPane?.innerHTML || '';
    // Should render as ONE <ul> with TWO <li>, not per-line divs
    const ulCount = (briefingHtml.match(/<ul>/g) || []).length;
    const liCount = (briefingHtml.match(/<li>/g) || []).length;
    const excerptLineCount = (briefingHtml.match(/excerpt-line/g) || []).length;

    if (ulCount !== 1) {
      failures.push(`Test (l2) FAILED: expected exactly one <ul>, got ${ulCount}: ${briefingHtml.slice(0, 400)}`);
    } else {
      console.log('OK   exactly one <ul> rendered in D5');
    }
    if (liCount !== 2) {
      failures.push(`Test (l2) FAILED: expected exactly two <li>, got ${liCount}: ${briefingHtml.slice(0, 400)}`);
    } else {
      console.log('OK   exactly two <li> rendered in D5');
    }
    if (excerptLineCount !== 0) {
      failures.push(`Test (l2) FAILED: should not use .excerpt-line class in D5, found ${excerptLineCount} occurrences`);
    } else {
      console.log('OK   no .excerpt-line divs in D5 document rendering');
    }

    if (failures.filter((f) => f.includes('Test (l2)')).length === 0) {
      console.log('  ✓ Test (l2) passed');
    }
  } catch (err) {
    failures.push(`Test (l2) ERROR: ${err.stack}`);
  }

  // Test (m): U3-C2 header set with exact counts and ordering
  console.log('Test (m): U3-C2 header set exact with counts, in order...');
  try {
    const escalationEntry = { taskId: 'gh1', timestamp: '2026-08-01T00:00:00Z', trigger: 't', microworld: 'm', packetMissing: false, packetBody: 'body' };
    const { leftRailHtml } = await renderClient({
      bundlesData: [
        { id: 'b1', unit: 'b1', description: 'd', status: null, source: 'working', functions: [] },
        { id: 'b2', unit: 'b2', description: 'd', status: null, source: 'packet', functions: [] },
      ],
      decisionsData: {
        escalations: [escalationEntry],
        briefings: [{ path: 'docs/plans/x.md', heading: 'Test Plan' }],
        findings: [{ slug: 'f1', timestamp: '2026-08-01T00:00:00Z', count: 1, body: 'body', malformed: false }],
        pendingReview: [{ agentId: 'a1', state: 'pending', reason: null, timestamp: '2026-08-01T00:00:00Z', unit: 'gh1' }],
      },
    });
    const headers = (leftRailHtml.match(/<div class="bundle-section-header">([^<]*)<\/div>/g) || []).map(h => h.match(/>([^<]*)</)[1]);
    const expected = ['Review (4)', 'Plans & Specs (1)', 'Microworlds (1)'];
    if (JSON.stringify(headers) !== JSON.stringify(expected)) {
      failures.push(`Test (m) FAILED: expected headers ${JSON.stringify(expected)}, got ${JSON.stringify(headers)}`);
    } else {
      console.log('  ✓ Test (m) passed');
    }
  } catch (err) {
    failures.push(`Test (m) ERROR: ${err.stack}`);
  }

  // Test (n): U3-C3 row containment by offset (sections properly ordered)
  console.log('Test (n): U3-C3 row containment by offset...');
  try {
    const escalationEntry = { taskId: 'gh1', timestamp: '2026-08-01T00:00:00Z', trigger: 't', microworld: 'm', packetMissing: false, packetBody: 'body' };
    const { leftRailHtml } = await renderClient({
      bundlesData: [
        { id: 'b1', unit: 'working1', description: 'd', status: null, source: 'working', functions: [] },
        { id: 'b2', unit: 'packet1', description: 'd', status: null, source: 'packet', functions: [] },
      ],
      decisionsData: {
        escalations: [escalationEntry],
        briefings: [{ path: 'docs/plans/brief.md', heading: 'Brief' }],
        findings: [{ slug: 'findings1', timestamp: '2026-08-01T00:00:00Z', count: 1, body: 'body', malformed: false }],
        pendingReview: [{ agentId: 'pr1', state: 'pending', reason: null, timestamp: '2026-08-01T00:00:00Z', unit: 'pr1' }],
      },
    });
    const reviewIdx = leftRailHtml.indexOf('Review (4)');
    const plansIdx = leftRailHtml.indexOf('Plans & Specs (1)');
    const microIdx = leftRailHtml.indexOf('Microworlds (1)');
    const escalationIdx = leftRailHtml.indexOf('Escalation: gh1');
    const packetIdx = leftRailHtml.indexOf('Packet: packet1');
    const findingsIdx = leftRailHtml.indexOf('Findings: findings1');
    const pendingIdx = leftRailHtml.indexOf('Pending review: pr1');
    const briefIdx = leftRailHtml.indexOf('Brief');
    const workingIdx = leftRailHtml.indexOf('working1');

    if (!(reviewIdx < escalationIdx && escalationIdx < plansIdx)) {
      failures.push(`Test (n) FAILED: escalation not between Review and Plans & Specs headers`);
    }
    if (!(reviewIdx < packetIdx && packetIdx < plansIdx)) {
      failures.push(`Test (n) FAILED: packet not between Review and Plans & Specs headers`);
    }
    if (!(reviewIdx < findingsIdx && findingsIdx < plansIdx)) {
      failures.push(`Test (n) FAILED: findings not between Review and Plans & Specs headers`);
    }
    if (!(reviewIdx < pendingIdx && pendingIdx < plansIdx)) {
      failures.push(`Test (n) FAILED: pending-review not between Review and Plans & Specs headers`);
    }
    if (!(plansIdx < briefIdx && briefIdx < microIdx)) {
      failures.push(`Test (n) FAILED: briefing not between Plans & Specs and Microworlds headers`);
    }
    if (!(microIdx < workingIdx)) {
      failures.push(`Test (n) FAILED: working bundle not after Microworlds header`);
    }
    if (failures.filter((f) => f.includes('Test (n)')).length === 0) {
      console.log('  ✓ Test (n) passed');
    }
  } catch (err) {
    failures.push(`Test (n) ERROR: ${err.stack}`);
  }

  // Test (o): U3-C4 type prefixes on rows
  console.log('Test (o): U3-C4 type prefixes on rows...');
  try {
    const escalationEntry = { taskId: 'esc1', timestamp: '2026-08-01T00:00:00Z', trigger: 't', microworld: 'm', packetMissing: false, packetBody: 'body' };
    const { leftRailHtml } = await renderClient({
      bundlesData: [
        { id: 'b2', unit: 'packet1', description: 'd', status: null, source: 'packet', functions: [] },
      ],
      decisionsData: {
        escalations: [escalationEntry],
        briefings: [],
        findings: [{ slug: 'find1', timestamp: '2026-08-01T00:00:00Z', count: 1, body: 'body', malformed: false }],
        pendingReview: [{ agentId: 'pr1', state: 'pending', reason: null, timestamp: '2026-08-01T00:00:00Z', unit: 'pr1' }],
      },
    });
    if (!leftRailHtml.includes('Escalation: esc1')) {
      failures.push('Test (o) FAILED: escalation row missing "Escalation: " prefix');
    } else {
      console.log('OK   escalation row has Escalation: prefix');
    }
    if (!leftRailHtml.includes('Packet: packet1')) {
      failures.push('Test (o) FAILED: packet row missing "Packet: " prefix');
    } else {
      console.log('OK   packet row has Packet: prefix');
    }
    if (!leftRailHtml.includes('Findings: find1')) {
      failures.push('Test (o) FAILED: findings row missing "Findings: " prefix');
    } else {
      console.log('OK   findings row has Findings: prefix');
    }
    if (!leftRailHtml.includes('Pending review: pr1')) {
      failures.push('Test (o) FAILED: pending-review row missing "Pending review: " prefix');
    } else {
      console.log('OK   pending-review row has Pending review: prefix');
    }
    if (failures.filter((f) => f.includes('Test (o)')).length === 0) {
      console.log('  ✓ Test (o) passed');
    }
  } catch (err) {
    failures.push(`Test (o) ERROR: ${err.stack}`);
  }

  // Test (p): U3-C6 empty sections don't render
  console.log('Test (p): U3-C6 empty sections dont render...');
  try {
    // Only working bundle, nothing else
    const { leftRailHtml } = await renderClient({
      bundlesData: [
        { id: 'b1', unit: 'working1', description: 'd', status: null, source: 'working', functions: [] },
      ],
      decisionsData: { escalations: [], briefings: [], findings: [], pendingReview: [] },
    });
    const headers = (leftRailHtml.match(/<div class="bundle-section-header">([^<]*)<\/div>/g) || []).map(h => h.match(/>([^<]*)</)[1]);
    const expected = ['Microworlds (1)'];
    if (JSON.stringify(headers) !== JSON.stringify(expected)) {
      failures.push(`Test (p) FAILED: with only working bundle, expected ${JSON.stringify(expected)}, got ${JSON.stringify(headers)}`);
    } else {
      console.log('  ✓ Test (p) passed');
    }
  } catch (err) {
    failures.push(`Test (p) ERROR: ${err.stack}`);
  }

  // Test (q): U3-C7 inverted urgency fixed - escalation auto-selects before working bundle
  console.log('Test (q): U3-C7 inverted urgency fixed...');
  try {
    const escalationEntry = { taskId: 'esc-urgent', timestamp: '2026-08-01T00:00:00Z', trigger: 't', microworld: 'm', packetMissing: false, packetBody: 'body' };
    const workingBundle = { id: 'b1', unit: 'work-unit', description: 'd', status: null, source: 'working', functions: [] };

    // With both escalation and working bundle, escalation should auto-select
    const { contentHtml } = await renderClient({
      bundlesData: [workingBundle],
      decisionsData: {
        escalations: [escalationEntry],
        briefings: [],
        findings: [],
        pendingReview: [],
      },
    });
    if (!contentHtml.includes('Escalation: esc-urgent')) {
      failures.push('Test (q) FAILED: escalation not auto-selected when both escalation and working bundle present');
    } else {
      console.log('OK   escalation auto-selected over working bundle');
    }

    // With only working bundle (no escalation), working bundle should auto-select
    const { contentHtml: contentHtml2 } = await renderClient({
      bundlesData: [workingBundle],
      decisionsData: {
        escalations: [],
        briefings: [],
        findings: [],
        pendingReview: [],
      },
    });
    if (!contentHtml2.includes('work-unit')) {
      failures.push('Test (q) FAILED: working bundle not auto-selected when no escalation present');
    } else {
      console.log('OK   working bundle auto-selected when no escalation');
    }

    if (failures.filter((f) => f.includes('Test (q)')).length === 0) {
      console.log('  ✓ Test (q) passed');
    }
  } catch (err) {
    failures.push(`Test (q) ERROR: ${err.stack}`);
  }

  // U4-C2: Cold start — escalation by field shows the defaulted username
  console.log('Test (r): U4-C2 Cold start with userName default...');
  try {
    const { contentHtml, elementsById } = await renderClient({
      bundlesData: [],
      decisionsData: { escalations: [{ taskId: 'task1', title: 'Escalation 1' }], briefings: [], findings: [], pendingReview: [] },
      contextData: { sha: 'deadbeef', userName: 'Seb' },
    });
    if (!contentHtml.includes('id="escalationBy" value="Seb"')) {
      throw new Error(`escalationBy field should have value="Seb", but got: ${contentHtml.substring(contentHtml.indexOf('id="escalationBy"'), contentHtml.indexOf('id="escalationBy"') + 50)}`);
    }
    console.log('  ✓ Cold start with userName default works');
  } catch (err) {
    failures.push(`Test (r) U4-C2: ${err.message}`);
  }

  // U4-C3: View switch — escalation by field survives switching views
  console.log('Test (s): U4-C3 userName survives view switch...');
  try {
    const { contentHtml: html1, contentArea, sandbox } = await renderClient({
      bundlesData: [],
      decisionsData: {
        escalations: [
          { taskId: 'task1', timestamp: '2026-08-01T00:00:00Z', trigger: 't', microworld: 'm', packetMissing: false, packetBody: 'body1' },
          { taskId: 'task2', timestamp: '2026-08-01T00:00:00Z', trigger: 't', microworld: 'm', packetMissing: false, packetBody: 'body2' },
        ],
        briefings: [],
        findings: [],
        pendingReview: [],
      },
      contextData: { sha: 'deadbeef', userName: 'Seb' },
    });
    if (!html1.includes('id="escalationBy" value="Seb"')) {
      throw new Error('Initial render should have userName=Seb');
    }
    if (typeof sandbox.selectDecisionView !== 'function') {
      throw new Error('selectDecisionView is not reachable on the sandbox');
    }
    // Actually switch views: selectDecisionView calls resetDecisionForms(),
    // which is the per-view-switch-wipe this unit exists to fix.
    await sandbox.selectDecisionView('escalation', 'task2');
    const html2 = contentArea.innerHTML;
    if (!html2.includes('id="escalationBy" value="Seb"')) {
      throw new Error(`After switching views, escalationBy should still be "Seb": ${html2.slice(html2.indexOf('id="escalationBy"'), html2.indexOf('id="escalationBy"') + 50)}`);
    }
    if (html2.includes('id="escalationBy" value=""')) {
      throw new Error('After switching views, escalationBy was wiped back to empty');
    }
    console.log('  ✓ userName survives view switch');
  } catch (err) {
    failures.push(`Test (s) U4-C3: ${err.message}`);
  }

  // U4-C4: User edit wins — user's edited by value appears in composed command
  console.log('Test (t): U4-C4 User edit wins...');
  try {
    const escalationForT4 = {
      taskId: 'task-u4c4',
      timestamp: '2026-08-18T10:00:00Z',
      trigger: 'unclear',
      microworld: 'none',
      packetMissing: false,
      packetBody: 'packet body',
    };
    const { contentHtml: initialHtml, elementsById } = await renderClient({
      bundlesData: [],
      decisionsData: { escalations: [escalationForT4], briefings: [], findings: [], pendingReview: [] },
      contextData: { sha: 'deadbeef', userName: 'Seb' },
    });
    // Verify initial state has Seb
    if (!initialHtml.includes('id="escalationBy" value="Seb"')) {
      throw new Error('Initial value should be "Seb"');
    }
    // Check that initial composed command contains "by: Seb"
    if (!initialHtml.includes('by: Seb')) {
      throw new Error('Initial composed command should contain "by: Seb"');
    }
    // Simulate user editing the escalationBy field
    elementsById.escalationBy.value = 'Alice';
    // Fire the change event to trigger renderContent()
    await elementsById.escalationBy.fire('change');
    // Wait for async operations to settle
    await new Promise((r) => setTimeout(r, 50));
    // Re-read the content from the mock DOM
    const updatedHtml = elementsById.contentArea.innerHTML;
    // Check that composed command uses the edited value
    if (!updatedHtml.includes('by: Alice')) {
      throw new Error(`Composed command should contain "by: Alice" after edit`);
    }
    if (updatedHtml.includes('by: Seb')) {
      throw new Error('Composed command should NOT contain "by: Seb" after user edit');
    }
    console.log('  ✓ User edit wins');
  } catch (err) {
    failures.push(`Test (t) U4-C4: ${err.message}`);
  }

  // U4-C6: Context failure is non-fatal
  console.log('Test (u): U4-C6 Context fetch failure is non-fatal...');
  try {
    const { contentHtml, leftRailHtml } = await renderClient({
      bundlesData: [],
      decisionsData: { escalations: [{ taskId: 'task1', title: 'Escalation 1' }], briefings: [], findings: [], pendingReview: [] },
      contextData: { ok: false, status: 500, error: 'Failed to get context' },
    });
    // Check that the rail still renders
    if (!leftRailHtml || leftRailHtml.length === 0) {
      throw new Error('Left rail should still render even when context fetch fails');
    }
    // Check that escalationBy field defaults to empty string
    if (!contentHtml.includes('id="escalationBy" value=""')) {
      throw new Error('escalationBy field should default to empty string when fetch fails');
    }
    console.log('  ✓ Context fetch failure is non-fatal');
  } catch (err) {
    failures.push(`Test (u) U4-C6: ${err.message}`);
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
