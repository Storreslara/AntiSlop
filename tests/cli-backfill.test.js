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

const cli = require(path.join(REPO_ROOT, 'bin', 'cli.js'));

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

  // Builds a fresh, fully-baselined project in `tmp`: every current spec
  // (personaSelection: [] -> CORE_PERSONAS + persona-protocol.md +
  // protocol-digest.md) rendered clean and written UNSTAMPED, with
  // fileHashes recorded against that same unstamped content — this makes
  // stripStamp() a no-op, so every file is trivially "no local edits,
  // already current" without reproducing the real stamp-insertion logic.
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
      fs.writeFileSync(destAbsPath, cleanBody);
      config.fileHashes[spec.projectRelPath] = cli.sha256Hex(cleanBody);
    }
    fs.mkdirSync(path.join(tmp, '.claude'), { recursive: true });
    fs.writeFileSync(path.join(tmp, '.claude', 'persona-config.json'), JSON.stringify(config, null, 2) + '\n');
    return config;
  }

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

if (failures > 0) {
  console.error(`\n${failures} test(s) failed.`);
  process.exit(1);
}
console.log('\nAll cli-backfill tests passed.');
