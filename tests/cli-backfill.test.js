#!/usr/bin/env node
'use strict';

// Exercises bin/cli.js's legacy-backfill logic (deriveMcpLaunchFromDisk,
// backfillSubstitutionsFromDisk, backfillFileHashesFromDisk) against the
// plugin's REAL agents/*.md content, not synthetic fixtures — that's what
// makes this worth having: it's the highest-regex-risk code in the file (see
// CHANGELOG for the incident it fixes), so round-tripping against the actual
// shipped placeholder shapes is the point, not a toy example that happens to
// pass.

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');
let failures = 0;

function check(name, fn) {
  try {
    fn();
    console.log(`OK   ${name}`);
  } catch (err) {
    console.log(`FAIL ${name}: ${err.message}`);
    failures++;
  }
}

function captureThrow(fn) {
  try {
    fn();
    return null;
  } catch (err) {
    return err;
  }
}

const cli = require(path.join(REPO_ROOT, 'bin', 'cli.js'));

check('buildFileSpecs registers the slim protocol digest for .claude/persona-protocol-slim.md', () => {
  const specs = cli.buildFileSpecs([]);
  const spec = specs.find((s) => s.projectRelPath === '.claude/persona-protocol-slim.md');
  assert.ok(spec, `expected a spec for .claude/persona-protocol-slim.md, got: ${JSON.stringify(specs.map((s) => s.projectRelPath))}`);
  assert.strictEqual(spec.sourceRelPath, 'templates/persona-protocol-slim.md');
});

check('renderCleanBody inlines the full protocol into full-tier bodies and the slim digest into slim-tier bodies', () => {
  const specs = cli.buildFileSpecs(['spec-master', 'task-master', 'scribe', 'reviewer', 'milestone-auditor', 'researcher', 'agent-auditor']);
  const config = { substitutions: { graphMcpLaunch: { command: 'npx', args: ['g'] }, arxivMcpLaunch: null } };
  const render = (rel) => cli.renderCleanBody(specs.find((s) => s.projectRelPath === rel), config);
  const FULL_ONLY = 'INSUFFICIENT-CONTEXT';
  const SLIM_SHARED = 'lead with the direct answer';
  for (const p of ['orchestrator', 'spec-master', 'task-master', 'lead-programmer', 'reviewer', 'milestone-auditor']) {
    const body = render(`.claude/agents/${p}.md`);
    assert.ok(body.includes(FULL_ONLY), `${p} (full-tier) should inline the full protocol`);
    assert.ok(body.includes(SLIM_SHARED), `${p} should include the shared answer-shape rule`);
  }
  for (const p of ['explorer', 'researcher', 'scribe', 'agent-auditor']) {
    const body = render(`.claude/agents/${p}.md`);
    assert.ok(!body.includes(FULL_ONLY), `${p} (slim-tier) must NOT inline the full protocol`);
    assert.ok(body.includes(SLIM_SHARED), `${p} should include the slim answer-shape rule`);
  }
  // The standalone slim doc renders raw, not tier-wrapped. (The full protocol
  // doc is no longer generated as a standalone project file — OQ11=DROP, U12.)
  assert.ok(!render('.claude/persona-protocol-slim.md').includes(FULL_ONLY), 'the slim doc has no full-only phrase');
});

// Canonical section list is DERIVED from the template, never hard-coded, so a
// section legitimately added to templates/persona-protocol.md keeps being
// tested (same fail-closed style as tests/adapter-protocol-parity.test.js).
function canonicalProtocolHeaders() {
  return fs.readFileSync(path.join(REPO_ROOT, 'templates', 'persona-protocol.md'), 'utf8')
    .split('\n')
    .filter((l) => l.startsWith('## '))
    .map((l) => l.slice(3).trim());
}

// The A3 ruling ("orchestrator is deliberately untrimmed") was reversed for
// three sections by gh348 Step 4 (Third verdict, Fourth verdict, Microworld
// bundles — operator-approved 2026-08-13, see docs/plans/2026-08-13-persona-
// efficiency-audit-gh348.md finding 1.1). This now asserts the row's actual
// include list rather than the full canonical set.
check('selectProtocolSections returns the orchestrator row\'s include list', () => {
  const all = canonicalProtocolHeaders();
  assert.ok(all.length > 0, 'the canonical template must define at least one ## section');
  const row = cli.PROTOCOL_SECTIONS_BY_PERSONA['orchestrator'];
  const expected = all.filter((h) => !row.drop.includes(h));
  assert.deepStrictEqual(cli.selectProtocolSections('orchestrator', 'full'), expected);
});

check('selectProtocolSections throws when a matrix row names a section the template does not define', () => {
  const matrix = cli.PROTOCOL_SECTIONS_BY_PERSONA;
  const all = canonicalProtocolHeaders();
  // Runtime mutation, deliberately AFTER load: this asserts the per-call
  // existence check inside selectProtocolSections is still live, which the
  // load-time completeness guard cannot cover (S4-A3e).
  matrix['fixture-persona'] = { include: [all[0], 'No Such Section'], drop: all.slice(1) };
  try {
    assert.throws(() => cli.selectProtocolSections('fixture-persona', 'full'), /No Such Section/);
  } finally {
    delete matrix['fixture-persona'];
  }
});

// --- S4-A3a: the load-time completeness validator, exercised as a pure
// function on synthetic headers — no template mutation, no module state. The
// positive control is load-bearing: without it a validator that threw
// unconditionally would satisfy both negative cases. These three cases are the
// in-process form of the criterion's three `node -e` invocations.
check('assertProtocolMatrixComplete throws when a row leaves a canonical section unclassified, naming the row and the header', () => {
  const err = captureThrow(() => cli.assertProtocolMatrixComplete(['A', 'B', 'C'], { p: { include: ['A'], drop: ['B'] } }));
  assert.ok(err, 'an incomplete row must throw');
  assert.ok(/\bp\b/.test(err.message), `message must name the row key: ${err.message}`);
  assert.ok(err.message.includes('"C"'), `message must name the uncovered header verbatim: ${err.message}`);
});

check('assertProtocolMatrixComplete positive control: an exhaustive row does not throw', () => {
  assert.doesNotThrow(() => cli.assertProtocolMatrixComplete(['A', 'B', 'C'], { p: { include: ['A'], drop: ['B', 'C'] } }));
});

check('assertProtocolMatrixComplete throws when a header is in both include and drop, naming that header', () => {
  const err = captureThrow(() => cli.assertProtocolMatrixComplete(['A', 'B', 'C'], { p: { include: ['A', 'B'], drop: ['B', 'C'] } }));
  assert.ok(err, 'an overlapping row must throw');
  assert.ok(/\bp\b/.test(err.message), `message must name the row key: ${err.message}`);
  assert.ok(err.message.includes('"B"'), `message must name the doubly-listed header verbatim: ${err.message}`);
});

check('selectProtocolSections returns every canonical section for an unknown persona name', () => {
  assert.deepStrictEqual(cli.selectProtocolSections('no-such-persona', 'full'), canonicalProtocolHeaders());
});

// Proves the selector is actually wired into the inlining path: the Step-2
// matrix is an all-sections no-op, so nothing else here can tell a live
// selector from dead code.
check('renderCleanBody inlines only the sections the selector returns for the persona', () => {
  const matrix = cli.PROTOCOL_SECTIONS_BY_PERSONA;
  const all = canonicalProtocolHeaders();
  const original = matrix['lead-programmer'];
  matrix['lead-programmer'] = { include: [all[0]], drop: all.slice(1) };
  try {
    const spec = cli.buildFileSpecs([]).find((s) => s.projectRelPath === '.claude/agents/lead-programmer.md');
    const block = cli.renderCleanBody(spec, {}).split('<!-- ANTISLOP:BEGIN persona-protocol')[1];
    assert.ok(block.includes(`## ${all[0]}`), `expected the selected section "${all[0]}" to survive`);
    for (const header of all.slice(1)) {
      assert.ok(!block.includes(`## ${header}`), `expected "${header}" to be trimmed out`);
    }
  } finally {
    matrix['lead-programmer'] = original;
  }
});

// --- Step 4 trimming matrix. TRIMMED_PERSONAS is every full-tier row except
// the still-mostly-untrimmed orchestrator (see the A3 ruling). gh348 Step 4
// reversed A3 for three of orchestrator's sections (operator-approved
// 2026-08-13); orchestrator stays out of this list because a separate check
// below still relies on it being an iff-frontmatter EXCEPTION for the memory
// section, which the other rows here are not — orchestrator's new partial
// trim is covered by its own check instead.
const TRIMMED_PERSONAS = ['lead-programmer', 'reviewer', 'spec-master', 'task-master', 'milestone-auditor'];

// Criterion 1 (as corrected by A4.1): positive AND negative, per persona,
// rendered with the config this repo actually SHIPS — an empty config leaves
// `gatedAgents` undefined, so the force-include never runs and the render
// corresponds to no real project. Expectation = row.include plus the gate
// sections forced back in for a gated persona (`lead-programmer` here, per the
// A4.1 ruling that force-include wins over its drop of the pending-review
// flag). Asserted on the fresh render AND on the shipped mirror, so the two
// cannot drift apart silently.
check('each trimmed persona carries its row include list plus any force-included gate sections, and none of the rest of its drop list, under the shipped persona-config', () => {
  const config = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, '.claude', 'persona-config.json'), 'utf8'));
  assert.ok(
    (config.gatedAgents || []).includes('lead-programmer'),
    `this repo gates lead-programmer — without it the force-include half of this test is dead: ${JSON.stringify(config.gatedAgents)}`
  );
  const specs = cli.buildFileSpecs(TRIMMED_PERSONAS.filter((p) => p !== 'lead-programmer'));
  for (const persona of TRIMMED_PERSONAS) {
    const row = cli.PROTOCOL_SECTIONS_BY_PERSONA[persona];
    assert.ok(row && row.drop.length > 0, `${persona} must have a row that actually drops sections`);
    const forced = config.gatedAgents.includes(persona) ? cli.GATED_AGENT_SECTIONS : [];
    const spec = specs.find((s) => s.projectRelPath === `.claude/agents/${persona}.md`);
    const sources = {
      render: cli.renderCleanBody(spec, config),
      mirror: fs.readFileSync(path.join(REPO_ROOT, '.claude', 'agents', `${persona}.md`), 'utf8'),
    };
    for (const [label, body] of Object.entries(sources)) {
      const block = body.split('<!-- ANTISLOP:BEGIN persona-protocol')[1];
      assert.ok(block, `${persona} (${label}) must carry an inlined protocol block`);
      for (const header of row.include.concat(forced)) {
        assert.ok(block.includes(`## ${header}`), `${persona} (${label}) must carry "${header}"`);
      }
      for (const header of row.drop.filter((h) => !forced.includes(h))) {
        assert.ok(!block.includes(`## ${header}`), `${persona} (${label}) must NOT carry its dropped section "${header}"`);
      }
    }
  }
});

// A4.1's logic gap: a renamed canonical heading would leave GATED_AGENT_SECTIONS
// naming a section the template no longer defines, silently turning the
// force-include into a no-op. Pure, so it is exercised on synthetic headers.
check('assertGatedSectionsCanonical throws naming a gate section the canonical header list does not define', () => {
  const err = captureThrow(() => cli.assertGatedSectionsCanonical(['A', 'B'], ['A', 'Renamed section']));
  assert.ok(err, 'a gate section absent from the canonical headers must throw');
  assert.ok(err.message.includes('"Renamed section"'), `message must name the offending section verbatim: ${err.message}`);
  assert.doesNotThrow(() => cli.assertGatedSectionsCanonical(['A', 'B'], ['A', 'B']));
});

// --- Step 5. The slim template carries neither gate section, so a slim-tier
// persona in gatedAgents can never be honoured — it must throw, not silently
// render a gated persona without the sections describing its own gate. Read
// from the REAL .claude/persona-config.json rather than a synthetic `{}` (#191
// finding (c): an empty config leaves gatedAgents undefined, so the test could
// not see the defect it was written for).
function shippedPersonaConfig() {
  return JSON.parse(fs.readFileSync(path.join(REPO_ROOT, '.claude', 'persona-config.json'), 'utf8'));
}

check('renderCleanBody throws, naming the persona, when gatedAgents contains a slim-tier persona', () => {
  const config = shippedPersonaConfig();
  assert.ok(
    cli.protocolTierFor('scribe') === 'slim',
    'this case needs a genuinely slim-tier persona to be meaningful'
  );
  config.gatedAgents = (config.gatedAgents || []).concat('scribe');
  const spec = cli.buildFileSpecs([]).find((s) => s.projectRelPath === '.claude/agents/lead-programmer.md');
  const err = captureThrow(() => cli.renderCleanBody(spec, config));
  assert.ok(err, 'a slim-tier persona in gatedAgents must throw');
  assert.ok(err.message.includes('"scribe"'), `message must name the offending persona verbatim: ${err.message}`);
});

// The renderer never consults the selector for a slim persona (it inlines the
// slim template wholesale), so a selector that reported the full section list
// for one would contradict both the renderer and the throw above — the same
// disagreement, told two different ways.
check('selectProtocolSections refuses to report a section list for the slim tier', () => {
  const err = captureThrow(() => cli.selectProtocolSections('scribe', 'slim'));
  assert.ok(err, 'the selector must not answer for a slim-tier persona');
  assert.ok(/scribe/.test(err.message), `message must name the persona: ${err.message}`);
  assert.ok(/slim/.test(err.message), `message must name the tier: ${err.message}`);
});

// Positive control for the case above: without it, an assertion that threw for
// every gatedAgents list would satisfy it. Pins A4.1's force-include ruling as
// the thing that must survive — lead-programmer's row drops the pending-review
// flag, so both sections being present is the force-include still working.
check('positive control: the shipped gatedAgents renders lead-programmer without throwing, gate sections intact', () => {
  const config = shippedPersonaConfig();
  assert.deepStrictEqual(config.gatedAgents, ['lead-programmer'], 'this repo ships exactly this gatedAgents list');
  const spec = cli.buildFileSpecs([]).find((s) => s.projectRelPath === '.claude/agents/lead-programmer.md');
  let body;
  assert.doesNotThrow(() => { body = cli.renderCleanBody(spec, config); });
  assert.ok(body.includes('## WIP sentinel'), 'the force-include must still deliver the WIP sentinel section');
  assert.ok(body.includes('## Pending-review flag'), 'the force-include must still deliver the pending-review flag section');
});

// Criterion 2 (revised for gh348 Step 4): the orchestrator mirror on disk
// carries every header in its row's include list and none of its (now
// non-empty) drop list — the same shape as the generic TRIMMED_PERSONAS
// check above, kept separate because orchestrator is not a member of that
// list (see the iff-frontmatter exception noted there).
check('the .claude/agents/orchestrator.md mirror carries its row include list and none of its drop list', () => {
  const row = cli.PROTOCOL_SECTIONS_BY_PERSONA['orchestrator'];
  assert.ok(row.drop.length > 0, 'gh348 Step 4 expects orchestrator to drop at least one section now');
  const body = fs.readFileSync(path.join(REPO_ROOT, '.claude', 'agents', 'orchestrator.md'), 'utf8');
  const block = body.split('<!-- ANTISLOP:BEGIN persona-protocol')[1];
  assert.ok(block, 'the orchestrator mirror must carry an inlined protocol block');
  for (const header of row.include) {
    assert.ok(block.includes(`## ${header}`), `the orchestrator mirror must carry "${header}"`);
  }
  for (const header of row.drop) {
    assert.ok(!block.includes(`## ${header}`), `the orchestrator mirror must NOT carry its dropped section "${header}"`);
  }
});

// --- S4-A3c: the guard is per-ROW. Deleting a header from one row's include
// AND drop must throw naming that row and that header, even while every other
// row still covers it — which is exactly the case a union-over-rows check
// cannot see. unionBlindCases counts the mutations that leave the union
// complete; asserting it is non-zero is what proves the shape difference
// rather than merely assuming it.
check('assertProtocolMatrixComplete rejects a header deleted from any single real row, including ones other rows still cover', () => {
  const all = canonicalProtocolHeaders();
  const rows = Object.keys(cli.PROTOCOL_SECTIONS_BY_PERSONA);
  assert.ok(rows.length >= 5, `expected the full-tier rows, got: ${JSON.stringify(rows)}`);
  let unionBlindCases = 0;
  for (const persona of rows) {
    for (const header of all) {
      const clone = {};
      for (const name of rows) {
        const row = cli.PROTOCOL_SECTIONS_BY_PERSONA[name];
        clone[name] = { include: row.include.slice(), drop: row.drop.slice() };
      }
      clone[persona].include = clone[persona].include.filter((h) => h !== header);
      clone[persona].drop = clone[persona].drop.filter((h) => h !== header);

      const err = captureThrow(() => cli.assertProtocolMatrixComplete(all, clone));
      assert.ok(err, `deleting "${header}" from ${persona} must throw`);
      assert.ok(err.message.includes(`'${persona}'`), `message must name the row ${persona}: ${err.message}`);
      assert.ok(err.message.includes(`"${header}"`), `message must name the header verbatim: ${err.message}`);

      const union = new Set();
      for (const name of rows) clone[name].include.concat(clone[name].drop).forEach((h) => union.add(h));
      if (all.every((h) => union.has(h))) unionBlindCases++;
    }
  }
  assert.ok(unionBlindCases > 0, 'at least one mutation must leave the union over rows complete — otherwise this proves nothing a union check could not do');
});

// --- S4-A3d: the memory section is carried iff the persona's SOURCE file has
// `memory:` frontmatter. Swept over all five trimmed rows, both directions, so
// adding `memory:` to a persona without editing the matrix fails loudly.
check('the memory section is included exactly for the trimmed personas whose agents/*.md carries memory: frontmatter', () => {
  const memoryHeader = canonicalProtocolHeaders().find((h) => h.startsWith('A note on'));
  assert.ok(memoryHeader, 'the canonical template must still define the memory section');
  for (const persona of TRIMMED_PERSONAS) {
    const source = fs.readFileSync(path.join(REPO_ROOT, 'agents', `${persona}.md`), 'utf8');
    const hasMemory = /^memory:/m.test(source);
    const row = cli.PROTOCOL_SECTIONS_BY_PERSONA[persona];
    assert.strictEqual(
      row.include.includes(memoryHeader), hasMemory,
      `agents/${persona}.md ${hasMemory ? 'has' : 'has no'} memory: frontmatter, so "${memoryHeader}" must ${hasMemory ? 'be in' : 'be out of'} its include list`
    );
    assert.strictEqual(
      row.drop.includes(memoryHeader), !hasMemory,
      `agents/${persona}.md ${hasMemory ? 'has' : 'has no'} memory: frontmatter, so "${memoryHeader}" must ${hasMemory ? 'be out of' : 'be in'} its drop list`
    );
  }
});

check('deriveMcpLaunchFromDisk round-trips a full command+args+env block', () => {
  const sourceBody = fs.readFileSync(path.join(REPO_ROOT, 'agents', 'explorer.md'), 'utf8');
  const launch = { command: 'node', args: ['/path/to/server.js', '--flag'], env: { API_KEY: 'xyz' } };
  const rendered = cli.applyMcpPlaceholder(
    sourceBody,
    '<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_4>',
    launch,
    'explorer.md'
  );
  assert.deepStrictEqual(cli.deriveMcpLaunchFromDisk(rendered), launch);
});

check('deriveMcpLaunchFromDisk round-trips a block with no env', () => {
  const sourceBody = fs.readFileSync(path.join(REPO_ROOT, 'agents', 'explorer.md'), 'utf8');
  const launch = { command: 'npx', args: ['code-review-graph-mcp'] };
  const rendered = cli.applyMcpPlaceholder(
    sourceBody,
    '<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_4>',
    launch,
    'explorer.md'
  );
  assert.deepStrictEqual(cli.deriveMcpLaunchFromDisk(rendered), launch);
});

check('deriveMcpLaunchFromDisk does not swallow a frontmatter key that follows mcpServers:', () => {
  // explorer.md has `maxTurns: 10` immediately after the mcpServers: block,
  // still inside frontmatter — the block-capture regex must stop there.
  const sourceBody = fs.readFileSync(path.join(REPO_ROOT, 'agents', 'explorer.md'), 'utf8');
  assert.ok(/\nmaxTurns: 10\n/.test(sourceBody), 'fixture assumption changed — explorer.md no longer has maxTurns right after mcpServers');
  const rendered = cli.applyMcpPlaceholder(
    sourceBody,
    '<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_4>',
    { command: 'node', args: [] },
    'explorer.md'
  );
  assert.ok(rendered.includes('\nmaxTurns: 10\n'), 'maxTurns: 10 got swallowed into the parsed/replaced block');
});

check('PLACEHOLDER_RE still matches real unresolved-placeholder shapes', () => {
  assert.ok(cli.PLACEHOLDER_RE.test('<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_4>'));
  assert.ok(cli.PLACEHOLDER_RE.test('<MATTPOCOCK:slot>'));
  assert.ok(cli.PLACEHOLDER_RE.test('<MATTPOCOCK>'));
});

check('PLACEHOLDER_RE does not false-positive on a bare single-letter prose token like "Open Question <N>"', () => {
  assert.ok(!cli.PLACEHOLDER_RE.test('converted to Open Question <N> (citing the actual Open Questions list number)'));
});

check('migrateLegacyPersonaTokens resolves repo-historian to scribe without a planner token present', () => {
  // Reproduces a real already-adapted project's personaSelection (no
  // "planner" present) to confirm the legacy-token guard isn't keyed to
  // "planner" specifically.
  const selection = ['hivemind', 'repo-historian', 'researcher', 'milestone-auditor', 'reviewer'];
  const migrated = cli.migrateLegacyPersonaTokens(selection, { logNote: false });
  assert.ok(migrated.includes('scribe'), `expected "scribe" in ${JSON.stringify(migrated)}`);
  assert.ok(!migrated.includes('repo-historian'), `"repo-historian" should have been migrated away`);
});

check('migrateLegacyPersonaTokens expands legacy hivemind into both spec-master and task-master', () => {
  const selection = ['hivemind', 'researcher'];
  const migrated = cli.migrateLegacyPersonaTokens(selection, { logNote: false });
  assert.ok(migrated.includes('spec-master'), `expected "spec-master" in ${JSON.stringify(migrated)}`);
  assert.ok(migrated.includes('task-master'), `expected "task-master" in ${JSON.stringify(migrated)}`);
  assert.ok(!migrated.includes('hivemind'), `"hivemind" should have been migrated away`);
});

check('migrateLegacyPersonaTokens chains the even-older planner token through hivemind to both new personas', () => {
  const selection = ['planner'];
  const migrated = cli.migrateLegacyPersonaTokens(selection, { logNote: false });
  assert.ok(migrated.includes('spec-master'), `expected "spec-master" in ${JSON.stringify(migrated)}`);
  assert.ok(migrated.includes('task-master'), `expected "task-master" in ${JSON.stringify(migrated)}`);
  assert.ok(!migrated.includes('planner') && !migrated.includes('hivemind'), `legacy tokens should be gone from ${JSON.stringify(migrated)}`);
});

// --- detectMarketplacePlugin: pure function, no module-level CWD
// dependency, so it's exercised directly against mkdtempSync fixture dirs
// without the chdir/require-cache dance the --update tests below need.
{
  function writeSettings(dir, relPath, json) {
    const abs = path.join(dir, relPath);
    fs.mkdirSync(path.dirname(abs), { recursive: true });
    fs.writeFileSync(abs, JSON.stringify(json));
  }

  function makeDirs() {
    const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-detect-cwd-'));
    const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-detect-home-'));
    return { cwd, home };
  }

  const enabledJson = { enabledPlugins: { 'antislop@antislop-marketplace': true } };

  [
    ['.claude/settings.json', 'project settings.json'],
    ['.claude/settings.local.json', 'project settings.local.json'],
  ].forEach(([relPath, label]) => {
    check(`detectMarketplacePlugin('claude', ...) detects the key set true in ${label}`, () => {
      const { cwd, home } = makeDirs();
      try {
        writeSettings(cwd, relPath, enabledJson);
        const result = cli.detectMarketplacePlugin('claude', cwd, home);
        assert.strictEqual(result.enabled, true);
        assert.strictEqual(result.source, path.join(cwd, relPath));
      } finally {
        fs.rmSync(cwd, { recursive: true, force: true });
        fs.rmSync(home, { recursive: true, force: true });
      }
    });
  });

  check("detectMarketplacePlugin('claude', ...) detects the key set true in the home settings.json", () => {
    const { cwd, home } = makeDirs();
    try {
      writeSettings(home, '.claude/settings.json', enabledJson);
      const result = cli.detectMarketplacePlugin('claude', cwd, home);
      assert.strictEqual(result.enabled, true);
      assert.strictEqual(result.source, path.join(home, '.claude', 'settings.json'));
    } finally {
      fs.rmSync(cwd, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check("detectMarketplacePlugin('claude', ...) returns enabled:false when the key is false", () => {
    const { cwd, home } = makeDirs();
    try {
      writeSettings(cwd, '.claude/settings.json', { enabledPlugins: { 'antislop@antislop-marketplace': false } });
      const result = cli.detectMarketplacePlugin('claude', cwd, home);
      assert.strictEqual(result.enabled, false);
    } finally {
      fs.rmSync(cwd, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check("detectMarketplacePlugin('claude', ...) returns enabled:false when the key is absent", () => {
    const { cwd, home } = makeDirs();
    try {
      writeSettings(cwd, '.claude/settings.json', { enabledPlugins: { 'some-other-plugin': true } });
      const result = cli.detectMarketplacePlugin('claude', cwd, home);
      assert.strictEqual(result.enabled, false);
    } finally {
      fs.rmSync(cwd, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check("detectMarketplacePlugin('claude', ...) returns enabled:false when enabledPlugins is absent entirely", () => {
    const { cwd, home } = makeDirs();
    try {
      writeSettings(cwd, '.claude/settings.json', {});
      const result = cli.detectMarketplacePlugin('claude', cwd, home);
      assert.strictEqual(result.enabled, false);
    } finally {
      fs.rmSync(cwd, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check("detectMarketplacePlugin('claude', ...) returns enabled:false and does not throw on malformed JSON", () => {
    const { cwd, home } = makeDirs();
    try {
      const abs = path.join(cwd, '.claude', 'settings.json');
      fs.mkdirSync(path.dirname(abs), { recursive: true });
      fs.writeFileSync(abs, '{ not valid json');
      assert.doesNotThrow(() => cli.detectMarketplacePlugin('claude', cwd, home));
      const result = cli.detectMarketplacePlugin('claude', cwd, home);
      assert.strictEqual(result.enabled, false);
    } finally {
      fs.rmSync(cwd, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check("detectMarketplacePlugin('claude', ...) reported-bug regression: home=true + project=false -> enabled:false (higher-precedence false wins)", () => {
    const { cwd, home } = makeDirs();
    try {
      writeSettings(home, '.claude/settings.json', enabledJson);
      writeSettings(cwd, '.claude/settings.json', { enabledPlugins: { 'antislop@antislop-marketplace': false } });
      const result = cli.detectMarketplacePlugin('claude', cwd, home);
      assert.strictEqual(result.enabled, false);
    } finally {
      fs.rmSync(cwd, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check("detectMarketplacePlugin('claude', ...) Local overrides Project: settings.local.json=false, settings.json=true -> enabled:false", () => {
    const { cwd, home } = makeDirs();
    try {
      writeSettings(cwd, '.claude/settings.local.json', { enabledPlugins: { 'antislop@antislop-marketplace': false } });
      writeSettings(cwd, '.claude/settings.json', enabledJson);
      const result = cli.detectMarketplacePlugin('claude', cwd, home);
      assert.strictEqual(result.enabled, false);
    } finally {
      fs.rmSync(cwd, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check("detectMarketplacePlugin('claude', ...) a higher explicit true still wins over a lower false: project=true, home=false -> enabled:true, source=project settings.json", () => {
    const { cwd, home } = makeDirs();
    try {
      writeSettings(cwd, '.claude/settings.json', enabledJson);
      writeSettings(home, '.claude/settings.json', { enabledPlugins: { 'antislop@antislop-marketplace': false } });
      const result = cli.detectMarketplacePlugin('claude', cwd, home);
      assert.strictEqual(result.enabled, true);
      assert.strictEqual(result.source, path.join(cwd, '.claude', 'settings.json'));
    } finally {
      fs.rmSync(cwd, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  ['cursor', 'codex'].forEach((target) => {
    check(`detectMarketplacePlugin('${target}', ...) always returns enabled:false, even with the key true everywhere (no-op, never scans)`, () => {
      const { cwd, home } = makeDirs();
      try {
        writeSettings(cwd, '.claude/settings.json', enabledJson);
        writeSettings(cwd, '.claude/settings.local.json', enabledJson);
        writeSettings(home, '.claude/settings.json', enabledJson);
        const result = cli.detectMarketplacePlugin(target, cwd, home);
        assert.strictEqual(result.enabled, false);
        assert.ok(result.reason, 'expected an explanatory reason for the no-op target');
      } finally {
        fs.rmSync(cwd, { recursive: true, force: true });
        fs.rmSync(home, { recursive: true, force: true });
      }
    });
  });
}

// --- Integration: fileHashes pruning + --check, exercised via the real
// `node bin/cli.js --update` CLI process (runUpdate() calls process.exit()
// on several paths, so it must run out-of-process rather than in the same
// test runner). PKG_ROOT is derived from cli.js's own __dirname, not CWD, so
// buildFileSpecs/renderCleanBody/sha256Hex can be used directly from the
// top-level `cli` require without the chdir/require-cache dance above.
{
  const cliPath = path.join(REPO_ROOT, 'bin', 'cli.js');
  const pluginVersion = JSON.parse(
    fs.readFileSync(path.join(REPO_ROOT, '.claude-plugin', 'plugin.json'), 'utf8')
  ).version;
  const graphMcpLaunch = { command: 'npx', args: ['code-review-graph-mcp'] };

  // Mirrors bin/cli.js's insertStampAfterFrontmatter/versionStamp shape
  // (stamp right after frontmatter when present, else at the top) without
  // reaching into cli.js internals — those two helpers aren't exported.
  function stampBody(body, sourceRelPath) {
    const stamp = `<!-- antislop v${pluginVersion} | source: ${sourceRelPath} | ADAPT-substituted -->\n`;
    const fmMatch = body.match(/^---\r?\n[\s\S]*?\r?\n---\r?\n/);
    if (!fmMatch) return stamp + body;
    const end = fmMatch[0].length;
    return body.slice(0, end) + stamp + body.slice(end);
  }

  // Builds a fresh, fully-baselined project in `tmp`: every current spec
  // (personaSelection: [] -> CORE_PERSONAS + persona-protocol-slim.md +
  // protocol-digest.md) rendered clean and written STAMPED at the fixture's
  // own pluginVersion — a genuinely current, correctly-stamped project, not
  // the impossible unstamped state a real project can never be in.
  // fileHashes are still recorded against the UNSTAMPED cleanBody (what
  // stripStamp() recovers), matching the real render loop's hash basis.
  function buildBaselineProject(tmp, extraFileHashes, selection) {
    const specs = cli.buildFileSpecs(selection || []);
    const config = {
      pluginVersion,
      personaSelection: selection || [],
      substitutions: { graphMcpLaunch },
      fileHashes: Object.assign({}, extraFileHashes),
    };
    for (const spec of specs) {
      const cleanBody = cli.renderCleanBody(spec, config);
      const destAbsPath = path.join(tmp, spec.projectRelPath);
      fs.mkdirSync(path.dirname(destAbsPath), { recursive: true });
      fs.writeFileSync(destAbsPath, stampBody(cleanBody, spec.sourceRelPath));
      config.fileHashes[spec.projectRelPath] = cli.sha256Hex(cleanBody);
    }
    // Hook scripts are part of a current project too, but carry no stamp —
    // they're copied verbatim and tracked by content hash (see
    // buildHookScriptSpecs). Without them the fixture looks like a project
    // whose entire .claude/hooks/scripts/ was deleted, and every --update
    // below would be busy recreating it.
    for (const spec of cli.buildHookScriptSpecs()) {
      const body = fs.readFileSync(spec.sourceAbsPath, 'utf8');
      const destAbsPath = path.join(tmp, spec.projectRelPath);
      fs.mkdirSync(path.dirname(destAbsPath), { recursive: true });
      fs.writeFileSync(destAbsPath, body);
      config.fileHashes[spec.projectRelPath] = cli.sha256Hex(body);
    }
    fs.mkdirSync(path.join(tmp, '.claude'), { recursive: true });
    fs.writeFileSync(path.join(tmp, '.claude', 'persona-config.json'), JSON.stringify(config, null, 2) + '\n');
    return config;
  }

  check("buildBaselineProject stamps each mirror at the fixture's own pluginVersion (after frontmatter when present, else at the top), while fileHashes stay pinned to the unstamped body", () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-baseline-stamp-test-'));
    try {
      const config = buildBaselineProject(tmp, {});
      for (const spec of cli.buildFileSpecs([])) {
        const onDisk = fs.readFileSync(path.join(tmp, spec.projectRelPath), 'utf8');
        assert.strictEqual(
          cli.stampVersionOf(onDisk), pluginVersion,
          `${spec.projectRelPath} should be stamped at ${pluginVersion}, got: ${cli.stampVersionOf(onDisk)}`
        );
        assert.strictEqual(
          cli.sha256Hex(cli.stripStamp(onDisk)), config.fileHashes[spec.projectRelPath],
          `${spec.projectRelPath}'s fileHashes entry must match its unstamped body`
        );
        const fmMatch = onDisk.match(/^---\r?\n[\s\S]*?\r?\n---\r?\n/);
        if (fmMatch) {
          assert.ok(
            onDisk.slice(fmMatch[0].length).startsWith('<!-- antislop v'),
            `${spec.projectRelPath} has frontmatter, so the stamp must sit immediately after it`
          );
        } else {
          assert.ok(
            onDisk.startsWith('<!-- antislop v'),
            `${spec.projectRelPath} has no frontmatter, so the stamp must sit at the top of the file`
          );
        }
      }
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  // --- Integration (S4-A3b): a canonical section that no matrix row
  // classifies must make bin/cli.js unloadable, so `--update` dies at its own
  // require with ZERO mirrors rewritten — an error raised after a partial
  // rewrite would be a worse outcome than no guard at all. Runs against a
  // `cp -r` copy of the WORKING TREE (not a git worktree: the copy has to
  // carry uncommitted changes), and never touches the tracked template.
  check('--update fails at load and rewrites no mirror when the template gains a section no matrix row classifies', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-unclassified-section-'));
    try {
      for (const entry of fs.readdirSync(REPO_ROOT)) {
        if (entry === '.git' || entry === 'node_modules') continue;
        const copied = spawnSync('cp', ['-r', path.join(REPO_ROOT, entry), path.join(tmp, entry)], { encoding: 'utf8' });
        assert.strictEqual(copied.status, 0, `cp -r ${entry} failed: ${copied.stderr}`);
      }
      const tmpCli = path.join(tmp, 'bin', 'cli.js');
      const agentsDir = path.join(tmp, '.claude', 'agents');
      const mirrorHashes = () => {
        const out = {};
        for (const f of fs.readdirSync(agentsDir)) out[f] = cli.sha256Hex(fs.readFileSync(path.join(agentsDir, f), 'utf8'));
        return out;
      };

      // Force a real render in both halves: without this the version-match
      // fast-path could make the negative control exit 0 without rendering.
      const configPath = path.join(tmp, '.claude', 'persona-config.json');
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      config.pluginVersion = '0.0.1';
      fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');

      // Negative control (mandatory): the identical sequence WITHOUT the
      // fabricated section exits 0, so the failure below is the section's
      // doing and not the copy's.
      const clean = spawnSync('node', [tmpCli, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(clean.status, 0, `the unmutated copy must update cleanly, got ${clean.status}: ${clean.stdout}${clean.stderr}`);

      const before = mirrorHashes();
      fs.appendFileSync(
        path.join(tmp, 'templates', 'persona-protocol.md'),
        '\n## Fabricated canonical section\n\nA rule that must reach gated personas.\n'
      );

      const mutated = spawnSync('node', [tmpCli, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.notStrictEqual(mutated.status, 0, `an unclassified canonical section must exit non-zero, got: ${mutated.stdout}${mutated.stderr}`);
      assert.ok(
        mutated.stderr.includes('Fabricated canonical section'),
        `stderr must name the unclassified header verbatim, got: ${mutated.stderr}`
      );
      assert.deepStrictEqual(mirrorHashes(), before, 'no mirror may be rewritten by a run that fails the matrix guard');
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  // --- Integration (Step 4, criterion 3): .claude/persona-config.json's
  // gatedAgents beats the matrix, so the trimming can never leave a gated
  // persona without the two sections that describe its own gate. Asserted on
  // `reviewer` precisely because its matrix row DROPS both — the ungated
  // baseline read first is the control that makes the second half meaningful.
  check('--update force-includes the WIP sentinel and Pending-review flag sections for a persona listed in gatedAgents', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-gated-force-include-'));
    try {
      buildBaselineProject(tmp, {}, ['reviewer']);
      const reviewerPath = path.join(tmp, '.claude', 'agents', 'reviewer.md');
      // Control: of the two forced sections, only the WIP sentinel is absent
      // from reviewer's row (the pending-review flag is in its include list
      // already), so the WIP sentinel is what carries the proof here.
      const ungated = fs.readFileSync(reviewerPath, 'utf8');
      assert.ok(!ungated.includes('## WIP sentinel'), 'control: an ungated reviewer must not carry the WIP sentinel section');

      const configPath = path.join(tmp, '.claude', 'persona-config.json');
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      config.gatedAgents = ['lead-programmer', 'reviewer'];
      config.pluginVersion = '0.0.1'; // force the render loop past the version-match fast path
      fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');

      const result = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);

      const gated = fs.readFileSync(reviewerPath, 'utf8');
      assert.ok(gated.includes('## WIP sentinel'), `gatedAgents must win over the matrix row, got: ${result.stdout}`);
      assert.ok(gated.includes('## Pending-review flag'), `gatedAgents must win over the matrix row, got: ${result.stdout}`);
      assert.ok(
        !gated.includes('## Continuing after a FAIL verdict'),
        'force-include covers exactly the two gate sections — the rest of the row\'s drop list must still be dropped'
      );
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  // --- The fresh-scaffold path renders persona bodies too, and it renders them
  // from the same matrix — so it must pass the same gatedAgents it is about to
  // write into persona-config.json, or a brand-new project ships bodies that
  // differ from what its very first `--update` would produce.
  check('a fresh scaffold renders each persona body identically to --update, force-include included', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-scaffold-render-'));
    try {
      const scaffold = spawnSync('node', [cliPath, '--yes'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(scaffold.status, 0, `scaffold must exit 0, got ${scaffold.status}: ${scaffold.stdout}${scaffold.stderr}`);
      const config = JSON.parse(fs.readFileSync(path.join(tmp, '.claude', 'persona-config.json'), 'utf8'));
      assert.ok(
        (config.gatedAgents || []).includes('lead-programmer'),
        `a fresh scaffold must record gatedAgents, got: ${JSON.stringify(config.gatedAgents)}`
      );

      const specs = cli.buildFileSpecs(TRIMMED_PERSONAS.filter((p) => p !== 'lead-programmer'));
      for (const persona of TRIMMED_PERSONAS.concat('orchestrator')) {
        const spec = specs.find((s) => s.projectRelPath === `.claude/agents/${persona}.md`);
        const onDisk = cli.stripStamp(fs.readFileSync(path.join(tmp, '.claude', 'agents', `${persona}.md`), 'utf8'));
        assert.strictEqual(
          onDisk, cli.renderCleanBody(spec, config),
          `the scaffolded ${persona}.md must be byte-identical to what --update renders from the config the scaffold just wrote`
        );
      }
      // Control: the equality above would also hold if BOTH paths stopped
      // trimming, so pin the two ends of the force-include directly — the
      // gated persona keeps a section its own row drops, the ungated one does
      // not get its dropped section back.
      const scaffolded = (p) => fs.readFileSync(path.join(tmp, '.claude', 'agents', `${p}.md`), 'utf8');
      assert.ok(
        scaffolded('lead-programmer').includes('## Pending-review flag'),
        'lead-programmer is in gatedAgents, so the scaffold must force-include the pending-review flag its row drops'
      );
      assert.ok(
        !scaffolded('reviewer').includes('## WIP sentinel'),
        'control: reviewer is not gated, so its dropped WIP sentinel must stay dropped on scaffold'
      );
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  check('--update prunes a stale fileHashes entry for a persona no longer in the current selection', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-prune-test-'));
    try {
      buildBaselineProject(tmp, { '.claude/agents/hivemind.md': 'a'.repeat(64) });
      // Force the render loop to actually run (a plain version-match
      // fast-path would otherwise skip it entirely) the same way a real
      // version bump would — mirrors the real hivemind-retirement incident,
      // which shipped alongside a plugin version bump.
      const configPath = path.join(tmp, '.claude', 'persona-config.json');
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      config.pluginVersion = '0.0.1';
      fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');

      const result = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);

      const after = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      assert.strictEqual(
        after.fileHashes['.claude/agents/hivemind.md'],
        undefined,
        'stale hivemind.md fileHashes entry should have been pruned'
      );
      assert.ok(after.fileHashes['.claude/agents/orchestrator.md'], 'current specs should still have fileHashes entries');
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  // --- Regression: stale fileHashes for raw specs (issue gh360-1).
  // Hand-edits to both source and mirror can bypass writeSpecBody (which
  // recomputes fileHashes), leaving the stored hash stale. The fix ensures
  // that if the current on-disk content already matches a fresh clean
  // regeneration, the hash is silently healed without surfacing a
  // "diverged, needs decision" prompt.
  check('--update silently heals stale fileHashes for a raw spec when current content matches clean content', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-stale-hash-test-'));
    try {
      const config = buildBaselineProject(tmp, {});

      // Use a real hook script from the plugin: human-decision-gate.sh
      const relKey = '.claude/hooks/scripts/human-decision-gate.sh';
      const hookMirror = path.join(tmp, relKey);
      const realHookSource = path.join(REPO_ROOT, 'hooks', 'scripts', 'human-decision-gate.sh');

      // Ensure the mirror directory exists and write the current hook content
      fs.mkdirSync(path.dirname(hookMirror), { recursive: true });
      const currentHookBody = fs.readFileSync(realHookSource, 'utf8');
      fs.writeFileSync(hookMirror, currentHookBody);

      // Set up config with a stale fileHashes entry (simulate prior
      // hand-edit that didn't run writeSpecBody's hash recording)
      const staleHash = 'e2657478207ffe90a05af6dde932621197dcb0c0aa2a1d9c0b5add49442063c0';
      config.fileHashes[relKey] = staleHash;

      const configPath = path.join(tmp, '.claude', 'persona-config.json');
      fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');

      // Run --update --check: should report hash healed, not diverged
      const check = spawnSync('node', [cliPath, '--update', '--check'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(check.status, 0, `--update --check expected exit 0, got ${check.status}: ${check.stdout}${check.stderr}`);
      assert.ok(
        check.stdout.includes('hash healed'),
        `expected "hash healed" in output, got: ${check.stdout}`
      );
      assert.ok(
        !check.stdout.includes('have diverged'),
        `should not report divergence, got: ${check.stdout}`
      );

      // Verify the hash was actually healed in config
      const healedConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      const actualHash = cli.sha256Hex(currentHookBody);
      assert.strictEqual(
        healedConfig.fileHashes[relKey],
        actualHash,
        `fileHashes[${relKey}] should match actual content hash, got ${healedConfig.fileHashes[relKey]} (expected ${actualHash})`
      );

      // Also test plain --update (without --check) still heals the hash
      // First restore the stale hash
      config.fileHashes[relKey] = staleHash;
      fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');

      const plain = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(plain.status, 0, `--update expected exit 0, got ${plain.status}: ${plain.stdout}${plain.stderr}`);
      // Plain --update with stale hash should now heal it (thanks to the pre-scan fix)
      const plainConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      assert.strictEqual(
        plainConfig.fileHashes[relKey],
        actualHash,
        `plain --update should also heal the hash`
      );
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  // --- Integration (S3-A2a): the version-match fast-path must not skip past a
  // managed destination that is MISSING. Asserted on protocol-digest.md
  // rather than persona-protocol.md deliberately: the defeater has to be
  // general over `specs`, not a per-path special case.
  check('--update restores a deleted managed file instead of reporting "Nothing to update"', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-absent-dest-test-'));
    try {
      buildBaselineProject(tmp, {});

      const control = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(control.status, 0, `expected exit 0, got ${control.status}: ${control.stdout}${control.stderr}`);
      assert.ok(control.stdout.includes('Nothing to update'), `an untouched baseline must still take the fast path, got: ${control.stdout}`);

      const digestPath = path.join(tmp, '.claude', 'protocol-digest.md');
      fs.unlinkSync(digestPath);

      const healed = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(healed.status, 0, `expected exit 0, got ${healed.status}: ${healed.stdout}${healed.stderr}`);
      assert.ok(fs.existsSync(digestPath), 'the deleted managed file should have been recreated');
      assert.ok(
        healed.stdout.includes('.claude/protocol-digest.md: created'),
        `expected the deleted file to be reported as created, got: ${healed.stdout}`
      );
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  // --- Integration (S3-A2b): `.claude/persona-protocol.md` is a managed spec
  // again (reverses OQ11=DROP/U12, which deleted it) — see the buildFileSpecs
  // registration for why. Replaces the old "--update deletes a stale
  // pre-existing copy" test, which asserted the behaviour now reversed.
  check('--update creates .claude/persona-protocol.md, stamped at line 1 and byte-identical to the template past the stamp', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-full-protocol-test-'));
    try {
      buildBaselineProject(tmp, {});
      const destPath = path.join(tmp, '.claude', 'persona-protocol.md');
      fs.rmSync(destPath, { force: true });

      const result = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
      assert.ok(
        result.stdout.includes('.claude/persona-protocol.md: created'),
        `expected the full protocol doc to be created, got: ${result.stdout}`
      );

      const onDisk = fs.readFileSync(destPath, 'utf8');
      const lines = onDisk.split('\n');
      assert.strictEqual(
        lines[0],
        `<!-- antislop v${pluginVersion} | source: templates/persona-protocol.md | ADAPT-substituted -->`,
        'the template has no frontmatter, so the stamp must be line 1 exactly'
      );
      assert.strictEqual(
        lines.slice(1).join('\n'),
        fs.readFileSync(path.join(REPO_ROOT, 'templates', 'persona-protocol.md'), 'utf8'),
        'past the stamp line the copy must be byte-identical to templates/persona-protocol.md'
      );
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  // --- Integration (S3-A2c): idempotence measured against a FORCED render.
  // A plain second --update takes the version-match fast-path and never
  // renders anything, so "run it twice and diff the file" passes on *never
  // re-rendered* as readily as on *rendered and identical*. `--update --check`
  // defeats that fast-path, and the per-file "already current" line is emitted
  // only after renderCleanBody ran and its hash was compared — that line, not
  // the sha, is the render-invocation evidence. mtime is useless here: the
  // correct branch performs no write.
  check('a forced --update --check re-renders .claude/persona-protocol.md, reports it already current, and leaves it byte-identical', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-protocol-idempotence-test-'));
    try {
      buildBaselineProject(tmp, {});
      const destPath = path.join(tmp, '.claude', 'persona-protocol.md');
      fs.rmSync(destPath, { force: true });

      const created = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(created.status, 0, `expected exit 0, got ${created.status}: ${created.stdout}${created.stderr}`);
      const shaAfterCreate = cli.sha256Hex(fs.readFileSync(destPath, 'utf8'));

      const forced = spawnSync('node', [cliPath, '--update', '--check'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(forced.status, 0, `expected exit 0, got ${forced.status}: ${forced.stdout}${forced.stderr}`);
      assert.ok(
        forced.stdout.split('\n').includes('  .claude/persona-protocol.md: already current'),
        `expected the exact render-invocation line, got: ${forced.stdout}`
      );
      assert.strictEqual(
        cli.sha256Hex(fs.readFileSync(destPath, 'utf8')), shaAfterCreate,
        'the forced render must leave the file byte-identical to the creating run'
      );

      // Negative control: the same second run WITHOUT --check fast-paths out
      // and never names the file — this is what proves the assertions above
      // measure something a plain double --update structurally cannot.
      const plain = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(plain.status, 0, `expected exit 0, got ${plain.status}: ${plain.stdout}${plain.stderr}`);
      assert.ok(plain.stdout.includes('Nothing to update'), `a plain second --update must take the fast path, got: ${plain.stdout}`);
      assert.ok(
        !plain.stdout.includes('persona-protocol.md'),
        `a fast-pathed --update must not mention the file at all, got: ${plain.stdout}`
      );

      // Mutation control: the forced render must really compare content, not
      // just announce the spec. Exit code is asserted non-zero only — no code
      // path documents 2 as a contract.
      fs.appendFileSync(destPath, 'x\n');
      const mutated = spawnSync('node', [cliPath, '--update', '--check'], { cwd: tmp, encoding: 'utf8' });
      assert.notStrictEqual(mutated.status, 0, `a diverged file must exit non-zero, got: ${mutated.stdout}${mutated.stderr}`);
      assert.ok(
        mutated.stdout.includes('diverged from a fresh copy'),
        `expected the divergence report, got: ${mutated.stdout}`
      );
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  // --- Integration (S3-A2d): a project adapted before the file became a
  // managed spec may still carry an unmanaged, stale copy with no fileHashes
  // entry (removeStaleProtocolCopy, which used to delete it, is gone). That
  // orphan must migrate silently — landing in `pending` would turn a routine
  // --update into an interactive `diverged` prompt on every such project.
  check('--update adopts a legacy unmanaged .claude/persona-protocol.md without prompting about divergence', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-legacy-protocol-test-'));
    try {
      const config = buildBaselineProject(tmp, {});
      delete config.fileHashes['.claude/persona-protocol.md'];
      const configPath = path.join(tmp, '.claude', 'persona-config.json');
      fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');

      const destPath = path.join(tmp, '.claude', 'persona-protocol.md');
      fs.writeFileSync(
        destPath,
        '<!-- antislop v0.0.1 | source: templates/persona-protocol.md | ADAPT-substituted -->\nstale content predating the managed spec\n'
      );

      const result = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
      assert.ok(
        result.stdout.includes('.claude/persona-protocol.md: updated (no local edits detected)'),
        `expected the orphan to be adopted and updated, got: ${result.stdout}`
      );
      assert.ok(
        !result.stdout.includes('diverged from a fresh copy'),
        `a legacy orphan must not be reported as diverged, got: ${result.stdout}`
      );
      assert.strictEqual(
        fs.readFileSync(destPath, 'utf8').split('\n').slice(1).join('\n'),
        fs.readFileSync(path.join(REPO_ROOT, 'templates', 'persona-protocol.md'), 'utf8'),
        'the adopted file must be refreshed to the template past the stamp line'
      );
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  // --- Integration: Step 5 (token-hygiene-dispatch-gate) .gitignore backfill.
  // `runUpdate` must reach already-adapted projects too, not just the
  // scaffold-time lists — this is the specific gap Step 5 exists to close.
  check('--update backfills .claude/dispatch-audit.log and .claude/.dispatch-override into .gitignore without touching other lines, idempotently', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-gitignore-backfill-'));
    try {
      buildBaselineProject(tmp, {});
      const gitignorePath = path.join(tmp, '.gitignore');
      const original = '*.log\nnode_modules/\n.claude/reviewed/\n.claude/wip-audit.log\n.claude/review-audit.log\n';
      fs.writeFileSync(gitignorePath, original);

      const first = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(first.status, 0, `expected exit 0, got ${first.status}: ${first.stdout}${first.stderr}`);

      const afterFirst = fs.readFileSync(gitignorePath, 'utf8');
      assert.ok(afterFirst.includes('.claude/dispatch-audit.log'), 'expected .claude/dispatch-audit.log to be backfilled');
      assert.ok(afterFirst.includes('.claude/.dispatch-override'), 'expected .claude/.dispatch-override to be backfilled');
      assert.ok(afterFirst.startsWith(original), 'pre-existing .gitignore lines must survive unmodified and unreordered, as an exact prefix');

      const second = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(second.status, 0, `second --update expected exit 0, got ${second.status}: ${second.stdout}${second.stderr}`);
      const afterSecond = fs.readFileSync(gitignorePath, 'utf8');
      assert.strictEqual(afterSecond, afterFirst, 'a second --update must leave .gitignore byte-identical (idempotence)');
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  // --- Integration: Step 3a (microworlds/human-review) .gitignore backfill.
  // R9 — a rule added only to the scaffold lists never reaches an
  // already-adapted project, which would then see bundles and escalation
  // packets as untracked noise and plausibly commit them.
  check('--update backfills microworlds/ and .claude/human-review/ into .gitignore without touching other lines, idempotently', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-microworlds-gitignore-'));
    try {
      buildBaselineProject(tmp, {});
      const gitignorePath = path.join(tmp, '.gitignore');
      const original = '*.log\nnode_modules/\n.claude/reviewed/\n.claude/wip-audit.log\n.claude/review-audit.log\n';
      fs.writeFileSync(gitignorePath, original);

      const first = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(first.status, 0, `expected exit 0, got ${first.status}: ${first.stdout}${first.stderr}`);

      const afterFirst = fs.readFileSync(gitignorePath, 'utf8');
      for (const line of ['microworlds/', '.claude/human-review/', '.claude/microworld-audit.log']) {
        assert.ok(
          afterFirst.split('\n').includes(line),
          `expected ${line} to be backfilled as its own line, got: ${afterFirst}`
        );
      }
      assert.ok(afterFirst.startsWith(original), 'pre-existing .gitignore lines must survive unmodified and unreordered, as an exact prefix');

      const second = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(second.status, 0, `second --update expected exit 0, got ${second.status}: ${second.stdout}${second.stderr}`);
      const afterSecond = fs.readFileSync(gitignorePath, 'utf8');
      assert.strictEqual(afterSecond, afterFirst, 'a second --update must leave .gitignore byte-identical (idempotence)');
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  check('--update --check catches drift past the version-match fast-path that a plain --update misses', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-check-test-'));
    try {
      buildBaselineProject(tmp, {});
      const digestPath = path.join(tmp, '.claude', 'protocol-digest.md');
      fs.appendFileSync(digestPath, '\nhand-corrupted content\n');

      const plain = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(plain.status, 0, `expected exit 0, got ${plain.status}: ${plain.stdout}${plain.stderr}`);
      assert.ok(
        /already current/.test(plain.stdout),
        `plain --update should hit the version-match fast-path and not detect drift, got: ${plain.stdout}`
      );

      const checked = spawnSync('node', [cliPath, '--update', '--check'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(checked.status, 2, `expected exit 2 (pending), got ${checked.status}: ${checked.stdout}${checked.stderr}`);
      assert.ok(
        checked.stdout.includes('.claude/protocol-digest.md'),
        `--check should have flagged the corrupted file as pending, got: ${checked.stdout}`
      );
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  // --- Regression (F2, docs/plans/2026-08-09-agent-auditor-persona.md,
  // "Convergence follow-ups, round 2"): the acceptance-criterion form
  // `! node bin/cli.js --update --check 2>&1 | grep -qE ': (updated|created|pending)$'`
  // is vacuous -- it discards the exit code and can only ever match
  // `: created`, so drift that surfaces as "updated (no local edits
  // detected)" reports GREEN even though the file changed. The corrected
  // form -- exit code AND post-run `git status --porcelain -uno` emptiness
  // -- fixes this, but only if BOTH halves are load-bearing: this test
  // builds two drift shapes from a clean, committed starting state (the
  // fixture must be clean going in, or the pre-run precondition the
  // criterion itself asserts is never actually represented) and proves
  // neither half alone would discriminate both shapes.
  //
  // Runs against a real git-tracked copy of the repo, not
  // `buildBaselineProject`'s synthetic fixture, since the corrected form's
  // post-run assertion needs real git state to read.
  function buildF2GitFixture(label) {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), `antislop-f2-${label}-`));
    for (const entry of fs.readdirSync(REPO_ROOT)) {
      if (entry === '.git' || entry === 'node_modules') continue;
      const copied = spawnSync('cp', ['-r', path.join(REPO_ROOT, entry), path.join(tmp, entry)], { encoding: 'utf8' });
      assert.strictEqual(copied.status, 0, `cp -r ${entry} failed: ${copied.stderr}`);
    }
    const git = (gitArgs) => spawnSync('git', gitArgs, { cwd: tmp, encoding: 'utf8' });
    const porcelain = () => git(['status', '--porcelain', '-uno']).stdout;
    assert.strictEqual(git(['init', '-q']).status, 0, 'git init failed');
    git(['config', 'user.email', 'f2-regression@example.com']);
    git(['config', 'user.name', 'F2 Regression']);
    assert.strictEqual(git(['add', '-A']).status, 0, 'git add failed');
    const commit = git(['commit', '-q', '-m', 'baseline']);
    assert.strictEqual(commit.status, 0, `git commit failed: ${commit.stderr}`);
    assert.strictEqual(porcelain(), '', 'precondition: the baseline commit must leave the tree clean');
    return { tmp, git, porcelain, cli: path.join(tmp, 'bin', 'cli.js') };
  }

  function oldFormFooled(stdout) {
    // Reproduced here (not left live in the codebase) to prove it stays
    // GREEN on both fixtures below.
    return !/: (updated|created|pending)$/m.test(stdout);
  }

  check('F2 regression: shape A (source committed-edited, mirror stale) is caught ONLY by the post-run git-clean assertion — the exit code alone (0) reports fine', () => {
    const { tmp, git, porcelain, cli: tmpCli } = buildF2GitFixture('shape-a');
    try {
      // Mutation must be COMMITTED, not left uncommitted — an uncommitted
      // mutation would make the tree dirty before the CLI ever runs, which
      // both defeats the criterion's own pre-run precondition and makes the
      // post-run dirtiness assertion pass even if the CLI does nothing at all.
      fs.appendFileSync(path.join(tmp, 'agents', 'orchestrator.md'), '\nhand-edited source line\n');
      assert.strictEqual(git(['add', '-A']).status, 0, 'git add failed');
      assert.strictEqual(git(['commit', '-q', '-m', 'shape A: commit the source edit']).status, 0, 'git commit failed');
      assert.strictEqual(porcelain(), '', 'precondition: shape A must start from a clean tree, same as the criterion\'s own pre-run assertion');

      const checked = spawnSync('node', [tmpCli, '--update', '--check'], { cwd: tmp, encoding: 'utf8' });
      assert.ok(oldFormFooled(checked.stdout), `expected the old broken grep form to be fooled (GREEN) on shape A, got stdout: ${checked.stdout}`);

      // The dangerous part of shape A: --check self-heals and exits 0, so a
      // bare exit-code check reports "fine" even though drift occurred.
      assert.strictEqual(checked.status, 0, 'shape A must exit 0 — the self-heal write succeeds, which is what an exit-code-only remedy misses');

      // Only the post-run porcelain check catches it, and it must name the
      // mirror the CLI silently rewrote — not just "something changed".
      const dirtyAfter = porcelain();
      assert.notStrictEqual(dirtyAfter, '', 'shape A must leave the working tree dirty (the silent self-heal write)');
      assert.ok(
        dirtyAfter.includes('.claude/agents/orchestrator.md'),
        `expected the post-run diff to name the stale mirror the CLI rewrote, got: ${dirtyAfter}`
      );
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  check('F2 regression: shape B (mirror locally edited+committed) is caught ONLY by the exit-code assertion — the post-run tree comes back clean', () => {
    const { tmp, git, porcelain, cli: tmpCli } = buildF2GitFixture('shape-b');
    try {
      // Committed hand-edit to the MIRROR (not the source), so it diverges
      // from what a fresh render would produce.
      fs.appendFileSync(path.join(tmp, '.claude', 'agents', 'orchestrator.md'), '\nhand-edited mirror line\n');
      assert.strictEqual(git(['add', '-A']).status, 0, 'git add failed');
      assert.strictEqual(git(['commit', '-q', '-m', 'shape B: commit the mirror edit']).status, 0, 'git commit failed');
      assert.strictEqual(porcelain(), '', 'precondition: shape B must start from a clean tree, same as the criterion\'s own pre-run assertion');

      const checked = spawnSync('node', [tmpCli, '--update', '--check'], { cwd: tmp, encoding: 'utf8' });
      assert.ok(oldFormFooled(checked.stdout), `expected the old broken grep form to be fooled (GREEN) on shape B, got stdout: ${checked.stdout}`);

      // The CLI refuses to silently overwrite a locally-edited mirror — it
      // reports the file pending and exits 2, writing nothing else back that
      // changes tree content.
      assert.strictEqual(checked.status, 2, 'shape B must exit 2 (pending decision) — this is what the post-run-porcelain-only remedy misses');

      const dirtyAfter = porcelain();
      assert.strictEqual(
        dirtyAfter, '',
        `shape B must leave the working tree clean post-run (no self-heal write for a pending file), got: ${dirtyAfter}`
      );
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  // --- Regression (issue #172, Steps 2+3): a mirror whose STAMP is stale but
  // whose BODY and fileHashes are untouched, with pluginVersion already equal
  // to the resolved version — the exact live drift this repo was in. Both
  // layers must be fixed for this to pass: the top-level fast-path (Step 3)
  // must not skip the loop, and the per-file "already current" branch
  // (Step 2) must actually call copyStampedBody.
  check('a plain --update re-stamps every mirror whose stamp alone is stale, leaving bodies and fileHashes untouched, then no-ops on a second run', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-stale-stamp-test-'));
    try {
      buildBaselineProject(tmp, {});
      const configPath = path.join(tmp, '.claude', 'persona-config.json');
      const specs = cli.buildFileSpecs([]);
      const staleVersion = '0.13.18';

      // Rewrite every mirror's stamp (only) to an older version, leaving the
      // rest of the body untouched.
      const beforeStripped = {};
      for (const spec of specs) {
        const destAbsPath = path.join(tmp, spec.projectRelPath);
        const onDisk = fs.readFileSync(destAbsPath, 'utf8');
        beforeStripped[spec.projectRelPath] = cli.stripStamp(onDisk);
        const restamped = onDisk.replace(
          /<!-- antislop v[^\n]*ADAPT-substituted -->/,
          `<!-- antislop v${staleVersion} | source: ${spec.sourceRelPath} | ADAPT-substituted -->`
        );
        assert.notStrictEqual(restamped, onDisk, `${spec.projectRelPath} should have had a stamp line to rewrite`);
        fs.writeFileSync(destAbsPath, restamped);
      }
      const beforeFileHashes = JSON.parse(fs.readFileSync(configPath, 'utf8')).fileHashes;

      const first = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(first.status, 0, `expected exit 0, got ${first.status}: ${first.stdout}${first.stderr}`);

      for (const spec of specs) {
        assert.ok(
          first.stdout.includes(`${spec.projectRelPath}: stamp refreshed`),
          `expected a distinct "stamp refreshed" line for ${spec.projectRelPath}, got: ${first.stdout}`
        );
        const onDisk = fs.readFileSync(path.join(tmp, spec.projectRelPath), 'utf8');
        assert.strictEqual(
          cli.stampVersionOf(onDisk), pluginVersion,
          `${spec.projectRelPath} should be re-stamped to ${pluginVersion}`
        );
        assert.strictEqual(
          cli.stripStamp(onDisk), beforeStripped[spec.projectRelPath],
          `${spec.projectRelPath}'s stripped body must be byte-identical to before the refresh`
        );
      }

      const afterFileHashes = JSON.parse(fs.readFileSync(configPath, 'utf8')).fileHashes;
      assert.deepStrictEqual(afterFileHashes, beforeFileHashes, 'fileHashes must be unchanged by a stamp-only refresh');

      const afterFirstBytes = {};
      for (const spec of specs) {
        afterFirstBytes[spec.projectRelPath] = fs.readFileSync(path.join(tmp, spec.projectRelPath), 'utf8');
      }

      const second = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(second.status, 0, `second --update expected exit 0, got ${second.status}: ${second.stdout}${second.stderr}`);
      assert.ok(
        /already current/.test(second.stdout),
        `second --update should hit the version-match fast-path (no stamps stale, no content drift), got: ${second.stdout}`
      );
      for (const spec of specs) {
        const onDisk = fs.readFileSync(path.join(tmp, spec.projectRelPath), 'utf8');
        assert.strictEqual(
          onDisk, afterFirstBytes[spec.projectRelPath],
          `${spec.projectRelPath} must be byte-identical after a no-op second run`
        );
      }
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  // --- Integration: OQ9=A auto-migration from the old global-import scheme to
  // per-persona body-inlined protocol delivery (issue #121 Step 6). One
  // --update deterministically strips CLAUDE.md's global import, inlines the
  // full/slim protocol into every persona body, creates the slim doc, and
  // backfills fileHashes — even at a matching pluginVersion. A second run is a
  // no-op (git diff --quiet).
  check('--update migrates an old global-import project to per-persona protocol delivery, idempotently', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-migrate-test-'));
    const git = (...a) => spawnSync('git', ['-c', 'user.email=t@t', '-c', 'user.name=t', ...a], { cwd: tmp, encoding: 'utf8' });
    try {
      const selection = ['reviewer', 'milestone-auditor', 'scribe', 'researcher', 'agent-auditor'];
      const specs = cli.buildFileSpecs(selection);
      const config = { pluginVersion, personaSelection: selection, substitutions: { graphMcpLaunch, arxivMcpLaunch: null }, fileHashes: {} };
      // Write OLD-scheme bodies: persona files with NO inlined protocol (tier
      // stripped), no slim doc, and record their hashes as the clean baseline.
      for (const spec of specs) {
        if (spec.projectRelPath === '.claude/persona-protocol-slim.md') continue; // did not exist under the old scheme
        const oldSpec = Object.assign({}, spec, { protocolTier: undefined });
        const body = cli.renderCleanBody(oldSpec, config);
        const dest = path.join(tmp, spec.projectRelPath);
        fs.mkdirSync(path.dirname(dest), { recursive: true });
        fs.writeFileSync(dest, body);
        config.fileHashes[spec.projectRelPath] = cli.sha256Hex(body);
      }
      fs.mkdirSync(path.join(tmp, '.claude'), { recursive: true });
      fs.writeFileSync(path.join(tmp, '.claude', 'persona-config.json'), JSON.stringify(config, null, 2) + '\n');
      fs.writeFileSync(path.join(tmp, 'CLAUDE.md'), '# Project\n\nSome note.\n\n@.claude/persona-protocol.md\n');

      const first = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(first.status, 0, `expected exit 0, got ${first.status}: ${first.stdout}${first.stderr}`);

      const claudeMd = fs.readFileSync(path.join(tmp, 'CLAUDE.md'), 'utf8');
      assert.ok(!/^@\.claude\/persona-protocol\.md/m.test(claudeMd), 'global import should be stripped from CLAUDE.md');
      assert.ok(/Some note\./.test(claudeMd), 'the rest of CLAUDE.md should be preserved');

      const FULL_ONLY = 'INSUFFICIENT-CONTEXT';
      const SLIM_SHARED = 'lead with the direct answer';
      const read = (rel) => fs.readFileSync(path.join(tmp, rel), 'utf8');
      for (const p of ['orchestrator', 'lead-programmer', 'reviewer', 'milestone-auditor']) {
        const body = read(`.claude/agents/${p}.md`);
        assert.ok(body.includes(FULL_ONLY) && body.includes(SLIM_SHARED), `${p} should now carry the full protocol`);
      }
      for (const p of ['explorer', 'scribe', 'researcher', 'agent-auditor']) {
        const body = read(`.claude/agents/${p}.md`);
        assert.ok(!body.includes(FULL_ONLY) && body.includes(SLIM_SHARED), `${p} should now carry the slim digest`);
      }
      assert.ok(fs.existsSync(path.join(tmp, '.claude', 'persona-protocol-slim.md')), 'slim doc should be created');
      const after = JSON.parse(read('.claude/persona-config.json'));
      assert.ok(after.fileHashes['.claude/persona-protocol-slim.md'], 'slim doc fileHash should be backfilled');

      // Idempotency: commit, run once more, assert a clean tree.
      git('init', '-q');
      git('add', '-A');
      git('commit', '-qm', 'baseline');
      const second = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(second.status, 0, `second --update exit 0, got ${second.status}: ${second.stdout}${second.stderr}`);
      const status = git('status', '--porcelain').stdout;
      assert.strictEqual(status, '', `second --update should be a no-op, git status shows:\n${status}`);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  check('compareSemver strips dotted pre-release/build suffixes before numeric comparison (issue #109 A1)', () => {
    // A dotted suffix like -beta.3 must not leak an extra non-numeric segment
    // into the numeric comparison. All of these are equal to their release.
    assert.strictEqual(cli.compareSemver('1.2.0-beta.3', '1.2.0'), 0, '1.2.0-beta.3 == 1.2.0');
    assert.strictEqual(cli.compareSemver('1.2.0', '1.2.0-beta.3'), 0, '1.2.0 == 1.2.0-beta.3');
    assert.strictEqual(cli.compareSemver('1.0.0-rc.1', '1.0.0'), 0, '1.0.0-rc.1 == 1.0.0');
    assert.strictEqual(cli.compareSemver('1.0.0', '1.0.0-rc.1'), 0, '1.0.0 == 1.0.0-rc.1');
    // Single-segment suffix must not regress.
    assert.strictEqual(cli.compareSemver('1.2.0-beta', '1.2.0'), 0, '1.2.0-beta == 1.2.0');
    // Real ordering intact.
    assert.ok(cli.compareSemver('1.0.0', '2.0.0') < 0, '1.0.0 < 2.0.0');
    assert.ok(cli.compareSemver('2.0.0-rc.1', '1.0.0') > 0, '2.0.0-rc.1 > 1.0.0');
  });

  // --- Integration: semver-ordering downgrade guard in runUpdate() (B1/M5,
  // issue #102). A stale scope registration must not silently resolve an
  // OLDER plugin version than the project's recorded pluginVersion and stamp
  // it backward. Baseline pluginVersion is forced HIGHER than the real
  // plugin (inverse of the '0.0.1' trick above) so the guard fires.
  // Sets pluginVersion HIGHER than the real plugin so the guard fires, then
  // captures the on-disk state of persona-config.json + a persona .md under
  // .claude/agents/ so the caller can assert nothing was written before the
  // refused exit-1 (issue #109 A4 / #102's never-actually-asserted claim). A
  // clean HOME is passed per spawn so detectMarketplacePlugin can't pick up
  // the dev box's real ~/.claude/settings.json (mirrors the dedupe tests).
  function runDowngradeRefusal(tmp, home) {
    const configPath = path.join(tmp, '.claude', 'persona-config.json');
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    config.pluginVersion = '99.0.0';
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');

    const personaPath = path.join(tmp, '.claude', 'agents', 'orchestrator.md');
    const beforeConfig = cli.sha256Hex(fs.readFileSync(configPath, 'utf8'));
    const beforePersona = cli.sha256Hex(fs.readFileSync(personaPath, 'utf8'));

    const result = spawnSync('node', [cliPath, '--update'], {
      cwd: tmp,
      env: Object.assign({}, process.env, { HOME: home }),
      encoding: 'utf8',
    });
    const combined = result.stdout + result.stderr;

    // A4: prove no file writes happened before the refusal.
    assert.strictEqual(cli.sha256Hex(fs.readFileSync(configPath, 'utf8')), beforeConfig,
      `persona-config.json must be byte-identical after the refusal, got mutation: ${combined}`);
    assert.strictEqual(cli.sha256Hex(fs.readFileSync(personaPath, 'utf8')), beforePersona,
      `.claude/agents/orchestrator.md must be byte-identical after the refusal, got mutation: ${combined}`);
    return { result, combined };
  }

  function assertCommonRefusal(result, combined) {
    assert.strictEqual(result.status, 1, `expected exit 1 (downgrade refusal), got ${result.status}: ${combined}`);
    assert.ok(combined.includes(pluginVersion), `refusal should name the real plugin version ${pluginVersion}, got: ${combined}`);
    assert.ok(combined.includes('99.0.0'), `refusal should name the recorded version 99.0.0, got: ${combined}`);
  }

  check('--update downgrade refusal (marketplace-enabled) points at the claude plugin update command', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-downgrade-refuse-mkt-'));
    const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-downgrade-home-'));
    try {
      buildBaselineProject(tmp, {});
      writeProjectSettings(tmp, { enabledPlugins: { 'antislop@antislop-marketplace': true } });

      const { result, combined } = runDowngradeRefusal(tmp, home);
      assertCommonRefusal(result, combined);
      assert.ok(
        combined.includes('claude plugin update antislop@antislop-marketplace'),
        `marketplace refusal should point at the marketplace recovery command, got: ${combined}`
      );
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check('--update downgrade refusal (non-marketplace) gives local-install guidance, not the marketplace command', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-downgrade-refuse-local-'));
    const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-downgrade-home-'));
    try {
      buildBaselineProject(tmp, {}); // no .claude/settings.json -> plugin not enabled

      const { result, combined } = runDowngradeRefusal(tmp, home);
      assertCommonRefusal(result, combined);
      assert.ok(
        !combined.includes('claude plugin update antislop@antislop-marketplace'),
        `non-marketplace refusal must NOT suggest the marketplace command, got: ${combined}`
      );
      assert.ok(
        /--plugin-dir|bin\/cli\.js/.test(combined),
        `non-marketplace refusal should point at the local clone/scaffold update path, got: ${combined}`
      );
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check('--update --allow-downgrade overrides the guard and proceeds', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-downgrade-allow-'));
    try {
      buildBaselineProject(tmp, {});
      const configPath = path.join(tmp, '.claude', 'persona-config.json');
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      config.pluginVersion = '99.0.0';
      fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');

      const result = spawnSync('node', [cliPath, '--update', '--allow-downgrade'], { cwd: tmp, encoding: 'utf8' });
      const combined = result.stdout + result.stderr;
      assert.notStrictEqual(result.status, 1, `--allow-downgrade should not exit 1 on the guard, got ${result.status}: ${combined}`);
      assert.ok(
        !combined.includes('claude plugin update antislop@antislop-marketplace'),
        `override run should not print the refusal recovery command, got: ${combined}`
      );
      assert.ok(combined.includes(pluginVersion) && combined.includes('99.0.0'),
        `override warning should name both versions ${pluginVersion} and 99.0.0, got: ${combined}`);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  // --- Integration: detect/warn/dedupe pass for stale standalone hook
  // registrations (issue #76, Step 2 of the update-dedupe-standalone-hooks
  // plan). Reuses buildBaselineProject above; seeds the plugin-enabled key
  // directly in the project's own .claude/settings.json. HOME is still
  // overridden to an empty tmp dir per spawn (mirroring the --force-hooks
  // block below) so detectMarketplacePlugin's home-settings fallback can't
  // pick up whatever the machine actually running these tests has at
  // ~/.claude/settings.json (this repo dogfoods the plugin on itself, so a
  // real dev box's real HOME may well have it enabled).
  const HOOK_MARKER = '${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts';
  const standaloneCommand = `${HOOK_MARKER}/stop-gate.sh`;
  const enabledJson = { enabledPlugins: { 'antislop@antislop-marketplace': true } };

  function writeProjectSettings(tmp, json) {
    const abs = path.join(tmp, '.claude', 'settings.json');
    fs.mkdirSync(path.dirname(abs), { recursive: true });
    fs.writeFileSync(abs, JSON.stringify(json));
  }

  function readProjectSettings(tmp) {
    return JSON.parse(fs.readFileSync(path.join(tmp, '.claude', 'settings.json'), 'utf8'));
  }

  function runUpdateCmd(tmp, home, extraArgs) {
    return spawnSync('node', [cliPath, '--update'].concat(extraArgs || []), {
      cwd: tmp,
      env: Object.assign({}, process.env, { HOME: home }),
      encoding: 'utf8',
    });
  }

  check('--update --dedupe-hooks resolves the collision: standalone entry removed, enabledPlugins preserved', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dedupe-test-'));
    const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dedupe-home-'));
    try {
      buildBaselineProject(tmp, {});
      writeProjectSettings(tmp, Object.assign({}, enabledJson, {
        hooks: { Stop: [{ matcher: '', hooks: [{ type: 'command', command: standaloneCommand }] }] },
      }));

      const result = runUpdateCmd(tmp, home, ['--dedupe-hooks']);
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);

      const settings = readProjectSettings(tmp);
      assert.ok(!JSON.stringify(settings.hooks || {}).includes(HOOK_MARKER), 'expected the standalone entry to be removed');
      assert.strictEqual(settings.enabledPlugins['antislop@antislop-marketplace'], true, 'expected enabledPlugins to be preserved');
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check('--update (no flag) leaves the collision alone by default and warns', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dedupe-test-'));
    const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dedupe-home-'));
    try {
      buildBaselineProject(tmp, {});
      writeProjectSettings(tmp, Object.assign({}, enabledJson, {
        hooks: { Stop: [{ matcher: '', hooks: [{ type: 'command', command: standaloneCommand }] }] },
      }));

      const result = runUpdateCmd(tmp, home);
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
      assert.ok(result.stdout.includes('--dedupe-hooks'), `expected the NOTE to mention --dedupe-hooks, got: ${result.stdout}`);

      const settings = readProjectSettings(tmp);
      assert.ok(JSON.stringify(settings.hooks).includes(HOOK_MARKER), 'expected the standalone entry to survive a plain --update');
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check('--update --dedupe-hooks is a no-op when the plugin is NOT enabled (never leaves zero hooks)', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dedupe-test-'));
    const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dedupe-home-'));
    try {
      buildBaselineProject(tmp, {});
      writeProjectSettings(tmp, {
        hooks: { Stop: [{ matcher: '', hooks: [{ type: 'command', command: standaloneCommand }] }] },
      });

      const result = runUpdateCmd(tmp, home, ['--dedupe-hooks']);
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);

      const settings = readProjectSettings(tmp);
      assert.ok(JSON.stringify(settings.hooks).includes(HOOK_MARKER), 'expected the only hooks present to survive when the plugin is not enabled');
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check('--update --dedupe-hooks surgically preserves a user-authored hook entry', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dedupe-test-'));
    const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dedupe-home-'));
    try {
      buildBaselineProject(tmp, {});
      writeProjectSettings(tmp, Object.assign({}, enabledJson, {
        hooks: {
          Stop: [
            { matcher: '', hooks: [{ type: 'command', command: standaloneCommand }] },
            { matcher: 'Bash', hooks: [{ type: 'command', command: 'echo user-authored' }] },
          ],
        },
      }));

      const result = runUpdateCmd(tmp, home, ['--dedupe-hooks']);
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);

      const settings = readProjectSettings(tmp);
      assert.ok(!JSON.stringify(settings.hooks).includes(HOOK_MARKER), 'expected the standalone entry to be removed');
      assert.strictEqual(settings.hooks.Stop.length, 1, 'expected only the user-authored group to remain');
      assert.strictEqual(settings.hooks.Stop[0].hooks[0].command, 'echo user-authored', 'expected the user-authored hook to survive untouched');
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check('--update runs the dedupe pass before the version-match fast-path', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dedupe-test-'));
    const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dedupe-home-'));
    try {
      buildBaselineProject(tmp, {}); // already at the current pluginVersion
      writeProjectSettings(tmp, Object.assign({}, enabledJson, {
        hooks: { Stop: [{ matcher: '', hooks: [{ type: 'command', command: standaloneCommand }] }] },
      }));

      const result = runUpdateCmd(tmp, home);
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
      assert.ok(
        result.stdout.includes('--dedupe-hooks'),
        `expected the collision NOTE even though the project is already current, got: ${result.stdout}`
      );
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  // --- Integration: humanReviewMode (issue #135, Step 6). The pair below is
  // the point: a FRESH install gets the field at `critical`, and an
  // ALREADY-ADAPTED project WITHOUT the field keeps it absent across
  // --update. The second is not an oversight being pinned — it is the
  // preserve-fields contract of the existingPersonaConfig branch, which is
  // exactly why the shipped default has to live in the CONSUMER's absent-key
  // fallback (agents/reviewer.md) rather than in a backfill here. Backfilling
  // it would make this case fail.
  check('a fresh install writes humanReviewMode: "critical" into the skeleton persona-config.json', () => {
    const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-hrm-fresh-cwd-'));
    const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-hrm-fresh-home-'));
    try {
      const result = spawnSync('node', [cliPath, '--yes'], {
        cwd,
        env: Object.assign({}, process.env, { HOME: home }),
        encoding: 'utf8',
      });
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
      const written = JSON.parse(fs.readFileSync(path.join(cwd, '.claude', 'persona-config.json'), 'utf8'));
      assert.strictEqual(
        written.humanReviewMode, 'critical',
        `the fresh-install skeleton must ship humanReviewMode: "critical", got ${JSON.stringify(written.humanReviewMode)}`
      );
    } finally {
      fs.rmSync(cwd, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check('--update leaves an existing config WITHOUT humanReviewMode still without it (preserve-fields contract)', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-hrm-preserve-'));
    try {
      const config = buildBaselineProject(tmp, {});
      assert.ok(!('humanReviewMode' in config), 'the baseline fixture must start without the field');
      const configPath = path.join(tmp, '.claude', 'persona-config.json');
      // Stale the stamp so --update does real work and genuinely rewrites the
      // config — without this the version-match fast-path would let the
      // assertion below pass on "nothing ran".
      config.pluginVersion = '0.13.18';
      fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');

      const result = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);

      const written = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      assert.strictEqual(
        written.pluginVersion, pluginVersion,
        `--update must have actually rewritten the config (anti-vacuity control), got pluginVersion ${written.pluginVersion}`
      );
      assert.ok(
        !('humanReviewMode' in written),
        `--update must not backfill humanReviewMode; the consumer's absent-key fallback carries the default instead, got ${JSON.stringify(written.humanReviewMode)}`
      );
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });
}

// --- Integration: --force-hooks guard on the claude-target hooks merge
// (issue #68). Runs the real scaffold via spawnSync into a fresh tmp cwd
// (no pre-existing persona-config.json, so the fresh-install path runs, not
// --update). HOME is overridden per-spawn so os.homedir() in the child
// process resolves to a throwaway dir instead of the real one.
{
  const cliPath = path.join(REPO_ROOT, 'bin', 'cli.js');
  const HOOK_MARKER = '${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts';
  const enabledJson = { enabledPlugins: { 'antislop@antislop-marketplace': true } };

  function makeTmpCwdAndHome() {
    const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-forcehooks-cwd-'));
    const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-forcehooks-home-'));
    return { cwd, home };
  }

  function writeSettings(dir, relPath, json) {
    const abs = path.join(dir, relPath);
    fs.mkdirSync(path.dirname(abs), { recursive: true });
    fs.writeFileSync(abs, JSON.stringify(json));
  }

  function runScaffold(cwd, home, extraArgs) {
    return spawnSync('node', [cliPath, '--yes'].concat(extraArgs || []), {
      cwd,
      env: Object.assign({}, process.env, { HOME: home }),
      encoding: 'utf8',
    });
  }

  check('negative/regression: no plugin enabled anywhere -> hooks merge happens as today', () => {
    const { cwd, home } = makeTmpCwdAndHome();
    try {
      const result = runScaffold(cwd, home);
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
      const settings = JSON.parse(fs.readFileSync(path.join(cwd, '.claude', 'settings.json'), 'utf8'));
      assert.ok(JSON.stringify(settings.hooks).includes(HOOK_MARKER), 'expected hooks merged in by default');
    } finally {
      fs.rmSync(cwd, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check('guard fires when the plugin is enabled via project .claude/settings.json', () => {
    const { cwd, home } = makeTmpCwdAndHome();
    try {
      writeSettings(cwd, '.claude/settings.json', enabledJson);
      const result = runScaffold(cwd, home);
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
      const settings = JSON.parse(fs.readFileSync(path.join(cwd, '.claude', 'settings.json'), 'utf8'));
      assert.ok(!JSON.stringify(settings.hooks || {}).includes(HOOK_MARKER), 'expected hooks merge to be skipped');
      assert.strictEqual(settings.agent, 'orchestrator', 'settingsFragment merge should still have happened');
    } finally {
      fs.rmSync(cwd, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check('guard fires when the plugin is enabled via project .claude/settings.local.json', () => {
    const { cwd, home } = makeTmpCwdAndHome();
    try {
      writeSettings(cwd, '.claude/settings.local.json', enabledJson);
      const result = runScaffold(cwd, home);
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
      const settings = JSON.parse(fs.readFileSync(path.join(cwd, '.claude', 'settings.json'), 'utf8'));
      assert.ok(!JSON.stringify(settings.hooks || {}).includes(HOOK_MARKER), 'expected hooks merge to be skipped');
      assert.strictEqual(settings.agent, 'orchestrator', 'settingsFragment merge should still have happened');
    } finally {
      fs.rmSync(cwd, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check('guard fires when the plugin is enabled via ~/.claude/settings.json (tmp HOME)', () => {
    const { cwd, home } = makeTmpCwdAndHome();
    try {
      writeSettings(home, '.claude/settings.json', enabledJson);
      const result = runScaffold(cwd, home);
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
      const settings = JSON.parse(fs.readFileSync(path.join(cwd, '.claude', 'settings.json'), 'utf8'));
      assert.ok(!JSON.stringify(settings.hooks || {}).includes(HOOK_MARKER), 'expected hooks merge to be skipped');
      assert.strictEqual(settings.agent, 'orchestrator', 'settingsFragment merge should still have happened');
    } finally {
      fs.rmSync(cwd, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check('project-level opt-out overrides a global plugin enable: hooks merge fires, false key survives (issue #72 regression)', () => {
    const { cwd, home } = makeTmpCwdAndHome();
    try {
      writeSettings(home, '.claude/settings.json', enabledJson);
      writeSettings(cwd, '.claude/settings.json', { enabledPlugins: { 'antislop@antislop-marketplace': false } });
      const result = runScaffold(cwd, home);
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
      const settings = JSON.parse(fs.readFileSync(path.join(cwd, '.claude', 'settings.json'), 'utf8'));
      assert.ok(JSON.stringify(settings.hooks).includes(HOOK_MARKER), 'expected hooks merge to fire (guard must not suppress on a project-level opt-out)');
      assert.strictEqual(
        settings.enabledPlugins['antislop@antislop-marketplace'],
        false,
        'expected the pre-seeded project-level false to survive the merge unclobbered'
      );
    } finally {
      fs.rmSync(cwd, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check('--force-hooks overrides the guard even when the plugin is detected', () => {
    const { cwd, home } = makeTmpCwdAndHome();
    try {
      writeSettings(cwd, '.claude/settings.json', enabledJson);
      const result = runScaffold(cwd, home, ['--force-hooks']);
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
      const settings = JSON.parse(fs.readFileSync(path.join(cwd, '.claude', 'settings.json'), 'utf8'));
      assert.ok(JSON.stringify(settings.hooks).includes(HOOK_MARKER), 'expected --force-hooks to restore the hooks merge');
    } finally {
      fs.rmSync(cwd, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });
}

// --- Unit: findStandaloneHookRegistrations / stripStandaloneHookRegistrations
// (issue #75, Step 1 of the update-dedupe-standalone-hooks plan). Pure
// functions operating on an in-memory settings object, no file I/O — unit
// tested directly like detectMarketplacePlugin, colocated near the other
// HOOK_MARKER-using tests above for convention consistency.
{
  const standaloneCommand = '${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts/stop-gate.sh';
  const pluginCommand = '${CLAUDE_PLUGIN_ROOT}/hooks/scripts/stop-gate.sh';

  function settingsWith(hooks) {
    return { agent: 'orchestrator', env: { FOO: 'bar' }, permissions: { allow: [] }, hooks };
  }

  check('findStandaloneHookRegistrations returns a non-empty list for a marker-matched command', () => {
    const settings = settingsWith({
      Stop: [{ matcher: '', hooks: [{ type: 'command', command: standaloneCommand }] }],
    });
    const found = cli.findStandaloneHookRegistrations(settings);
    assert.strictEqual(found.length, 1);
    assert.strictEqual(found[0].event, 'Stop');
    assert.strictEqual(found[0].script, 'stop-gate.sh');
  });

  check('findStandaloneHookRegistrations returns [] for only CLAUDE_PLUGIN_ROOT-rooted commands', () => {
    const settings = settingsWith({
      Stop: [{ matcher: '', hooks: [{ type: 'command', command: pluginCommand }] }],
    });
    assert.deepStrictEqual(cli.findStandaloneHookRegistrations(settings), []);
  });

  check('findStandaloneHookRegistrations returns [] when settings has no hooks key', () => {
    assert.deepStrictEqual(cli.findStandaloneHookRegistrations({ agent: 'orchestrator' }), []);
  });

  check('findStandaloneHookRegistrations returns [] when hooks is a non-object value', () => {
    assert.deepStrictEqual(cli.findStandaloneHookRegistrations({ hooks: 'nope' }), []);
  });

  check('stripStandaloneHookRegistrations removes exactly the marker-matched entries and prunes empties', () => {
    const settings = settingsWith({
      Stop: [
        { matcher: '', hooks: [{ type: 'command', command: standaloneCommand }] },
        { matcher: 'Bash', hooks: [{ type: 'command', command: 'echo user-authored' }] },
      ],
    });
    const result = cli.stripStandaloneHookRegistrations(settings);
    assert.strictEqual(result.hooks.Stop.length, 1, 'expected the marker-matched group to be pruned');
    assert.strictEqual(result.hooks.Stop[0].matcher, 'Bash');
    assert.strictEqual(result.hooks.Stop[0].hooks[0].command, 'echo user-authored');
  });

  check('stripStandaloneHookRegistrations does not mutate its input', () => {
    const settings = settingsWith({
      Stop: [{ matcher: '', hooks: [{ type: 'command', command: standaloneCommand }] }],
    });
    const before = JSON.stringify(settings);
    cli.stripStandaloneHookRegistrations(settings);
    assert.strictEqual(JSON.stringify(settings), before);
  });

  check('stripStandaloneHookRegistrations deletes the hooks key entirely when every entry was standalone', () => {
    const settings = settingsWith({
      Stop: [{ matcher: '', hooks: [{ type: 'command', command: standaloneCommand }] }],
    });
    const result = cli.stripStandaloneHookRegistrations(settings);
    assert.ok(!Object.prototype.hasOwnProperty.call(result, 'hooks'), 'expected hooks key to be deleted');
  });

  check('stripStandaloneHookRegistrations preserves non-hooks settings keys byte-for-byte', () => {
    const settings = settingsWith({
      Stop: [{ matcher: '', hooks: [{ type: 'command', command: standaloneCommand }] }],
    });
    const result = cli.stripStandaloneHookRegistrations(settings);
    assert.strictEqual(result.agent, 'orchestrator');
    assert.deepStrictEqual(result.env, { FOO: 'bar' });
    assert.deepStrictEqual(result.permissions, { allow: [] });
  });
}

// --- Integration: the same guard, wired into the cursor/codex scaffolds for
// uniformity (issue #69). detectMarketplacePlugin('cursor'/'codex', ...)
// always returns enabled:false (see its own no-op comment, issue #67), so
// the guard structurally can never suppress these targets' hooks today —
// these tests prove exactly that (the marketplace key does NOT suppress
// cursor/codex hooks) while also exercising the guard's call site, so a
// future change to detectMarketplacePlugin's cursor/codex branch would flip
// one of these from green to red instead of silently doing nothing.
{
  const cliPath = path.join(REPO_ROOT, 'bin', 'cli.js');
  const enabledJson = { enabledPlugins: { 'antislop@antislop-marketplace': true } };

  function makeTmpCwdAndHome() {
    const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-cursorcodex-cwd-'));
    const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-cursorcodex-home-'));
    return { cwd, home };
  }

  function writeSettings(dir, relPath, json) {
    const abs = path.join(dir, relPath);
    fs.mkdirSync(path.dirname(abs), { recursive: true });
    fs.writeFileSync(abs, JSON.stringify(json));
  }

  function runScaffold(cwd, home, target) {
    return spawnSync('node', [cliPath, `--target=${target}`], {
      cwd,
      env: Object.assign({}, process.env, { HOME: home }),
      encoding: 'utf8',
    });
  }

  check('cursor not over-guarded: marketplace key set does not suppress .cursor/hooks.json registrations', () => {
    const { cwd, home } = makeTmpCwdAndHome();
    try {
      writeSettings(cwd, '.claude/settings.json', enabledJson);
      const result = runScaffold(cwd, home, 'cursor');
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
      const hooks = JSON.parse(fs.readFileSync(path.join(cwd, '.cursor', 'hooks.json'), 'utf8'));
      assert.ok(JSON.stringify(hooks).includes('.cursor/hooks/scripts'), 'expected .cursor/hooks/scripts registrations to be present');
    } finally {
      fs.rmSync(cwd, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  check('codex not over-guarded: marketplace key set does not suppress .codex/hooks.json registrations', () => {
    const { cwd, home } = makeTmpCwdAndHome();
    try {
      writeSettings(cwd, '.claude/settings.json', enabledJson);
      const result = runScaffold(cwd, home, 'codex');
      assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
      const hooks = JSON.parse(fs.readFileSync(path.join(cwd, '.codex', 'hooks.json'), 'utf8'));
      assert.ok(JSON.stringify(hooks).includes('.codex/hooks/scripts'), 'expected .codex/hooks/scripts registrations to be present');
    } finally {
      fs.rmSync(cwd, { recursive: true, force: true });
      fs.rmSync(home, { recursive: true, force: true });
    }
  });
}

// --- Integration: the full/slim protocol-tier split mirrored to the Codex and
// Cursor adapters (issue #121 Step 10 / U10). explorer is the only slim-tier
// MVP persona on either adapter; the other three carry the full inlined-backstop
// protocol. Asserted by scaffolding each target and grepping a full-tier-only
// phrase (INSUFFICIENT-CONTEXT, the third verdict) — present in the three full
// personas' inlined protocol, absent from explorer's slim body.
{
  const cliPath = path.join(REPO_ROOT, 'bin', 'cli.js');
  const FULL_ONLY = 'INSUFFICIENT-CONTEXT';

  function makeTmp() {
    const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-adapter-tier-cwd-'));
    const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-adapter-tier-home-'));
    return { cwd, home };
  }

  function runScaffold(cwd, home, target) {
    return spawnSync('node', [cliPath, `--target=${target}`], {
      cwd,
      env: Object.assign({}, process.env, { HOME: home }),
      encoding: 'utf8',
    });
  }

  [
    { target: 'codex', dir: '.codex', ext: 'toml' },
    { target: 'cursor', dir: '.cursor', ext: 'md' },
  ].forEach(({ target, dir, ext }) => {
    check(`${target}: explorer carries the slim protocol tier, the other three carry the full tier`, () => {
      const { cwd, home } = makeTmp();
      try {
        const result = runScaffold(cwd, home, target);
        assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
        const read = (name) => fs.readFileSync(path.join(cwd, dir, 'agents', `${name}.${ext}`), 'utf8');
        assert.ok(!read('explorer').includes(FULL_ONLY),
          `${target} explorer (slim) must NOT carry the full-tier-only phrase ${FULL_ONLY}`);
        for (const name of ['orchestrator', 'lead-programmer', 'reviewer']) {
          assert.ok(read(name).includes(FULL_ONLY),
            `${target} ${name} (full) must carry the full-tier-only phrase ${FULL_ONLY}`);
        }
      } finally {
        fs.rmSync(cwd, { recursive: true, force: true });
        fs.rmSync(home, { recursive: true, force: true });
      }
    });
  });
}

// --- Integration: downgrade-stamping warning on the three --overwrite scaffold
// paths (issue #110). scaffoldCursor, scaffoldCodex, and the claude-target
// --overwrite branch each unconditionally stamp pluginVersion = version; when
// the recorded pluginVersion is strictly NEWER than the resolving plugin, that
// silently stamps backward. This proves each path now warns (naming both
// versions) yet still completes, and stays quiet when there's no downgrade.
// Reuses the hardened compareSemver from #109 in bin/cli.js — no second
// comparison implementation here.
{
  const cliPath = path.join(REPO_ROOT, 'bin', 'cli.js');
  const pluginVersion = JSON.parse(
    fs.readFileSync(path.join(REPO_ROOT, '.claude-plugin', 'plugin.json'), 'utf8')
  ).version;

  const scaffoldPaths = [
    { name: 'cursor', configRel: '.cursor/persona-config.json', args: ['--target=cursor', '--overwrite'] },
    { name: 'codex', configRel: '.codex/persona-config.json', args: ['--target=codex', '--overwrite'] },
    { name: 'claude-target', configRel: '.claude/persona-config.json', args: ['--yes', '--overwrite'] },
  ];

  function makeTmpCwdAndHome() {
    const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-ow-stampguard-cwd-'));
    const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-ow-stampguard-home-'));
    return { cwd, home };
  }

  function seedConfig(cwd, configRel, recordedVersion) {
    const abs = path.join(cwd, configRel);
    fs.mkdirSync(path.dirname(abs), { recursive: true });
    fs.writeFileSync(abs, JSON.stringify({ pluginVersion: recordedVersion, personaSelection: [] }, null, 2) + '\n');
    return abs;
  }

  function runScaffold(cwd, home, extraArgs) {
    return spawnSync('node', [cliPath].concat(extraArgs), {
      cwd,
      env: Object.assign({}, process.env, { HOME: home }),
      encoding: 'utf8',
    });
  }

  for (const sp of scaffoldPaths) {
    check(`${sp.name} --overwrite over a NEWER recorded pluginVersion warns (naming both versions) and still refreshes the stamp`, () => {
      const { cwd, home } = makeTmpCwdAndHome();
      try {
        const configAbs = seedConfig(cwd, sp.configRel, '99.0.0');
        const result = runScaffold(cwd, home, sp.args);
        const combined = result.stdout + result.stderr;
        assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${combined}`);
        assert.ok(/downgrade/i.test(combined), `expected a downgrade warning, got: ${combined}`);
        assert.ok(
          combined.includes('99.0.0') && combined.includes(pluginVersion),
          `warning should name both the recorded 99.0.0 and the plugin ${pluginVersion}, got: ${combined}`
        );
        const written = JSON.parse(fs.readFileSync(configAbs, 'utf8'));
        assert.strictEqual(written.pluginVersion, pluginVersion, `expected pluginVersion refreshed to ${pluginVersion}, got ${written.pluginVersion}`);
      } finally {
        fs.rmSync(cwd, { recursive: true, force: true });
        fs.rmSync(home, { recursive: true, force: true });
      }
    });

    check(`${sp.name} --overwrite over an equal-or-lower recorded pluginVersion emits NO downgrade warning`, () => {
      const { cwd, home } = makeTmpCwdAndHome();
      try {
        const configAbs = seedConfig(cwd, sp.configRel, '0.0.1');
        const result = runScaffold(cwd, home, sp.args);
        const combined = result.stdout + result.stderr;
        assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${combined}`);
        assert.ok(!/downgrade/i.test(combined), `expected NO downgrade warning, got: ${combined}`);
        const written = JSON.parse(fs.readFileSync(configAbs, 'utf8'));
        assert.strictEqual(written.pluginVersion, pluginVersion, `expected pluginVersion refreshed to ${pluginVersion}, got ${written.pluginVersion}`);
      } finally {
        fs.rmSync(cwd, { recursive: true, force: true });
        fs.rmSync(home, { recursive: true, force: true });
      }
    });

    check(`${sp.name} --overwrite over a recorded pluginVersion EQUAL to the current plugin version emits NO downgrade warning and still refreshes the stamp`, () => {
      const { cwd, home } = makeTmpCwdAndHome();
      try {
        const configAbs = seedConfig(cwd, sp.configRel, pluginVersion);
        const result = runScaffold(cwd, home, sp.args);
        const combined = result.stdout + result.stderr;
        assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${combined}`);
        assert.ok(!/downgrade/i.test(combined), `expected NO downgrade warning at the equal boundary, got: ${combined}`);
        const written = JSON.parse(fs.readFileSync(configAbs, 'utf8'));
        assert.strictEqual(written.pluginVersion, pluginVersion, `expected pluginVersion refreshed to ${pluginVersion}, got ${written.pluginVersion}`);
      } finally {
        fs.rmSync(cwd, { recursive: true, force: true });
        fs.rmSync(home, { recursive: true, force: true });
      }
    });
  }
}

// --- Step 5, criterion 4: BOTH render paths. #191's first finding was that
// gatedAgents reached renderCleanBody but not the fresh-scaffold path, so
// asserting the throw in-process alone would leave the same half-covered shape
// this unit is a sequel to. Each path gets the offending config AND the shipped
// one, so neither half can pass by throwing (or not throwing) unconditionally.
{
  const cliPath = path.join(REPO_ROOT, 'bin', 'cli.js');
  const pluginVersion = JSON.parse(
    fs.readFileSync(path.join(REPO_ROOT, '.claude-plugin', 'plugin.json'), 'utf8')
  ).version;

  // Seeds an install the scaffold's --overwrite branch will reuse the gatedAgents
  // of, and that --update will render from. pluginVersion 0.0.1 defeats the
  // version-match fast path so --update really re-renders.
  function seedProject(cwd, gatedAgents) {
    fs.mkdirSync(path.join(cwd, '.claude'), { recursive: true });
    fs.writeFileSync(
      path.join(cwd, '.claude', 'persona-config.json'),
      JSON.stringify(
        {
          pluginVersion: '0.0.1',
          // scribe so the slim-tier persona the cases below gate is actually
          // among the bodies being rendered, not merely named in the config.
          personaSelection: ['scribe'],
          gatedAgents,
          // explorer.md's MCP placeholder is unrenderable without this, and
          // --update exits 1 on any unrendered file — which would make the
          // positive controls below fail for a reason unrelated to gating.
          substitutions: { graphMcpLaunch: { command: 'npx', args: ['code-review-graph-mcp'] } },
        },
        null,
        2
      ) + '\n'
    );
  }

  function runIn(cwd, args) {
    const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-gated-tier-home-'));
    try {
      return spawnSync('node', [cliPath].concat(args), {
        cwd,
        env: Object.assign({}, process.env, { HOME: home }),
        encoding: 'utf8',
      });
    } finally {
      fs.rmSync(home, { recursive: true, force: true });
    }
  }

  for (const p of [
    { name: '--update', args: ['--update'] },
    { name: 'fresh-scaffold', args: ['--yes', '--overwrite'] },
  ]) {
    check(`the ${p.name} path exits non-zero, naming the persona, when gatedAgents contains a slim-tier one`, () => {
      const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-gated-slim-tier-'));
      try {
        seedProject(cwd, ['lead-programmer', 'scribe']);
        const result = runIn(cwd, p.args);
        const combined = result.stdout + result.stderr;
        assert.notStrictEqual(result.status, 0, `expected a non-zero exit, got ${result.status}: ${combined}`);
        assert.ok(combined.includes('"scribe"'), `output must name the offending persona verbatim: ${combined}`);
        assert.ok(
          !fs.existsSync(path.join(cwd, '.claude', 'agents', 'lead-programmer.md')),
          'the run must die before rewriting any persona body, not half-render one'
        );
      } finally {
        fs.rmSync(cwd, { recursive: true, force: true });
      }
    });

    check(`positive control: the ${p.name} path renders the shipped gatedAgents cleanly, gate sections intact`, () => {
      const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-gated-full-tier-'));
      try {
        seedProject(cwd, ['lead-programmer']);
        const result = runIn(cwd, p.args);
        const combined = result.stdout + result.stderr;
        assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${combined}`);
        const body = fs.readFileSync(path.join(cwd, '.claude', 'agents', 'lead-programmer.md'), 'utf8');
        assert.ok(body.includes('## WIP sentinel'), `the force-include must still deliver the WIP sentinel section: ${combined}`);
        assert.ok(body.includes('## Pending-review flag'), `the force-include must still deliver the pending-review flag section: ${combined}`);
        const written = JSON.parse(fs.readFileSync(path.join(cwd, '.claude', 'persona-config.json'), 'utf8'));
        assert.strictEqual(written.pluginVersion, pluginVersion, `the run must have really re-rendered at ${pluginVersion}, got ${written.pluginVersion}`);
      } finally {
        fs.rmSync(cwd, { recursive: true, force: true });
      }
    });
  }

  // Criterion 5, the step's one mutation control, committed rather than run
  // once by hand: with the per-render assertion deleted from a throwaway copy
  // of the WORKING TREE, the criterion-1 case must go back to succeeding
  // silently. Without this, every case above would also pass against a CLI
  // that threw for some unrelated reason.
  check('mutation control: with the per-render assertion removed, the slim-tier gatedAgents case silently succeeds again', () => {
    const pkg = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-gated-mutant-pkg-'));
    const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-gated-mutant-cwd-'));
    try {
      for (const entry of fs.readdirSync(REPO_ROOT)) {
        if (entry === '.git' || entry === 'node_modules') continue;
        const copied = spawnSync('cp', ['-r', path.join(REPO_ROOT, entry), path.join(pkg, entry)], { encoding: 'utf8' });
        assert.strictEqual(copied.status, 0, `cp -r ${entry} failed: ${copied.stderr}`);
      }
      const mutantCli = path.join(pkg, 'bin', 'cli.js');
      const source = fs.readFileSync(mutantCli, 'utf8');
      const call = '  assertGatedAgentsFullTier(gatedAgents);\n';
      assert.strictEqual(
        source.split(call).length - 1, 1,
        'the mutation must match exactly one per-render call site — otherwise this control removes something else, or nothing'
      );
      fs.writeFileSync(mutantCli, source.replace(call, ''));

      seedProject(cwd, ['lead-programmer', 'scribe']);
      const result = spawnSync('node', [mutantCli, '--update'], { cwd, encoding: 'utf8' });
      const combined = result.stdout + result.stderr;
      assert.strictEqual(result.status, 0, `the mutant is expected to swallow the misconfiguration, got ${result.status}: ${combined}`);
      assert.ok(!combined.includes('"scribe"'), `the mutant must not name the persona at all: ${combined}`);
      const scribe = fs.readFileSync(path.join(cwd, '.claude', 'agents', 'scribe.md'), 'utf8');
      assert.ok(
        !scribe.includes('## WIP sentinel') && !scribe.includes('## Pending-review flag'),
        'and the force-include really was a no-op: the gated scribe body carries neither gate section'
      );
    } finally {
      fs.rmSync(pkg, { recursive: true, force: true });
      fs.rmSync(cwd, { recursive: true, force: true });
    }
  });
}

// --- deepMerge structural equality tests (issue #228)
check('deepMerge dedupes structurally-identical array items (different instances, same content)', () => {
  const target = { items: [{ a: 1, b: 2 }, { x: 10 }] };
  const source = { items: [{ b: 2, a: 1 }] }; // Same content as target[0], different key order
  cli.deepMerge(target, source);
  assert.strictEqual(target.items.length, 2, `expected 2 items (no duplicate), got ${target.items.length}`);
  assert.deepStrictEqual(target.items[0], { a: 1, b: 2 });
  assert.deepStrictEqual(target.items[1], { x: 10 });
});

check('deepMerge still appends genuinely distinct array items', () => {
  const target = { items: [{ a: 1 }, { b: 2 }] };
  const source = { items: [{ c: 3 }] };
  cli.deepMerge(target, source);
  assert.strictEqual(target.items.length, 3, `expected 3 items, got ${target.items.length}`);
  assert.deepStrictEqual(target.items[2], { c: 3 });
});

check('deepMerge handles nested object key ordering in structural comparison', () => {
  const target = { config: [{ name: 'test', version: '1.0' }] };
  const source = { config: [{ version: '1.0', name: 'test' }] }; // Same content, different key order
  cli.deepMerge(target, source);
  assert.strictEqual(target.config.length, 1, `expected 1 item (deduplicated), got ${target.config.length}`);
});

check('deepMerge dedupes with primitives in arrays (SameValueZero equality applies to primitives)', () => {
  const target = { nums: [1, 2, 3] };
  const source = { nums: [2, 4] }; // 2 is duplicate, 4 is new
  cli.deepMerge(target, source);
  assert.strictEqual(target.nums.length, 4, `expected 4 items (1,2,3,4), got ${target.nums.length}`);
  assert.deepStrictEqual(target.nums, [1, 2, 3, 4]);
});

if (failures > 0) {
  console.error(`\n${failures} test(s) failed.`);
  process.exit(1);
}
console.log('\nAll cli-backfill tests passed.');
