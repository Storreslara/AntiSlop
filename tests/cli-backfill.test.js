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
  }
}

if (failures > 0) {
  console.error(`\n${failures} test(s) failed.`);
  process.exit(1);
}
console.log('\nAll cli-backfill tests passed.');
