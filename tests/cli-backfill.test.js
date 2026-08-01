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
  const specs = cli.buildFileSpecs(['spec-master', 'task-master', 'scribe', 'reviewer', 'milestone-auditor', 'researcher']);
  const config = { substitutions: { graphMcpLaunch: { command: 'npx', args: ['g'] }, arxivMcpLaunch: null } };
  const render = (rel) => cli.renderCleanBody(specs.find((s) => s.projectRelPath === rel), config);
  const FULL_ONLY = 'INSUFFICIENT-CONTEXT';
  const SLIM_SHARED = 'lead with the direct answer';
  for (const p of ['orchestrator', 'spec-master', 'task-master', 'lead-programmer', 'reviewer', 'milestone-auditor']) {
    const body = render(`.claude/agents/${p}.md`);
    assert.ok(body.includes(FULL_ONLY), `${p} (full-tier) should inline the full protocol`);
    assert.ok(body.includes(SLIM_SHARED), `${p} should include the shared answer-shape rule`);
  }
  for (const p of ['explorer', 'researcher', 'scribe']) {
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

check('selectProtocolSections returns every canonical section for a full-tier persona', () => {
  const all = canonicalProtocolHeaders();
  assert.ok(all.length > 0, 'the canonical template must define at least one ## section');
  assert.deepStrictEqual(cli.selectProtocolSections('lead-programmer', 'full'), all);
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
  function buildBaselineProject(tmp, extraFileHashes) {
    const specs = cli.buildFileSpecs([]);
    const config = {
      pluginVersion,
      personaSelection: [],
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
      const selection = ['reviewer', 'milestone-auditor', 'scribe', 'researcher'];
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
      for (const p of ['explorer', 'scribe', 'researcher']) {
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

if (failures > 0) {
  console.error(`\n${failures} test(s) failed.`);
  process.exit(1);
}
console.log('\nAll cli-backfill tests passed.');
