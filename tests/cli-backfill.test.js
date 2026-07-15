#!/usr/bin/env node
'use strict';

// Exercises bin/cli.js's legacy-backfill logic (deriveMattpocockSubsForFile,
// deriveMcpLaunchFromDisk, backfillSubstitutionsFromDisk,
// backfillFileHashesFromDisk) against the plugin's REAL agents/*.md content,
// not synthetic fixtures — that's what makes this worth having: it's the
// highest-regex-risk code in the file (see CHANGELOG for the incident it
// fixes), so round-tripping against the actual shipped placeholder shapes is
// the point, not a toy example that happens to pass.

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

const KNOWN_MAP = {
  'grill-me': 'mattpocock-skills:grill-me',
  'to-issues': 'mattpocock-skills:to-tickets',
  'to-spec': 'mattpocock-skills:to-spec',
  'improve-codebase-architecture': 'mattpocock-skills:improve-codebase-architecture',
  tdd: 'mattpocock-skills:tdd',
  diagnose: 'mattpocock-skills:diagnosing-bugs',
};

for (const name of ['scribe', 'milestone-auditor', 'lead-programmer', 'spec-master', 'task-master']) {
  check(`deriveMattpocockSubsForFile round-trips agents/${name}.md`, () => {
    const sourcePath = path.join(REPO_ROOT, 'agents', `${name}.md`);
    const sourceBody = fs.readFileSync(sourcePath, 'utf8');
    if (!sourceBody.includes('<MATTPOCOCK:')) return; // nothing to test for this file
    const currentBody = cli.applyMattpocockSubs(sourceBody, KNOWN_MAP, sourcePath);
    const { resolved, unresolvedSlots } = cli.deriveMattpocockSubsForFile(sourceBody, currentBody);
    assert.deepStrictEqual(unresolvedSlots, [], `unresolved slots: ${unresolvedSlots.join(', ')}`);
    for (const slot of Object.keys(resolved)) {
      assert.strictEqual(resolved[slot], KNOWN_MAP[slot], `slot ${slot} mismatch`);
    }
  });
}

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

check('deriveMattpocockSubsForFile leaves a genuinely reworded line unresolved rather than guessing', () => {
  const sourceBody = 'skills: <MATTPOCOCK:grill-me>\n';
  const currentBody = 'this line no longer resembles the original template at all\n';
  const { resolved, unresolvedSlots } = cli.deriveMattpocockSubsForFile(sourceBody, currentBody);
  assert.deepStrictEqual(resolved, {});
  assert.deepStrictEqual(unresolvedSlots, ['grill-me']);
});

check('deriveMattpocockSubsForFile flags ambiguous (multi-match) lines instead of taking the first', () => {
  const sourceBody = 'skills: <MATTPOCOCK:grill-me>\n';
  const currentBody = 'skills: option-a\nskills: option-b\n';
  const { resolved, unresolvedSlots } = cli.deriveMattpocockSubsForFile(sourceBody, currentBody);
  assert.deepStrictEqual(resolved, {});
  assert.deepStrictEqual(unresolvedSlots, ['grill-me']);
});

check('deriveMattpocockSubsForFile flags a same-slot conflict across files instead of picking one silently', () => {
  const sourceBody = 'skills: <MATTPOCOCK:grill-me>, <MATTPOCOCK:grill-me>\n';
  const currentBody = 'skills: option-a, option-b\n';
  const { resolved, unresolvedSlots } = cli.deriveMattpocockSubsForFile(sourceBody, currentBody);
  assert.deepStrictEqual(resolved, {});
  assert.deepStrictEqual(unresolvedSlots, ['grill-me']);
});

check('hasMattpocockResidue detects a leftover placeholder in an already-adapted file', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-residue-test-'));
  try {
    const relPath = '.claude/agents/spec-master.md';
    fs.mkdirSync(path.join(tmp, '.claude', 'agents'), { recursive: true });
    fs.writeFileSync(path.join(tmp, relPath), 'skills: grill-me, <MATTPOCOCK:to-spec>\n');
    assert.strictEqual(cli.hasMattpocockResidue([{ projectRelPath: relPath }], tmp), true);

    fs.writeFileSync(path.join(tmp, relPath), 'skills: grill-me, to-spec\n');
    assert.strictEqual(cli.hasMattpocockResidue([{ projectRelPath: relPath }], tmp), false);

    assert.strictEqual(
      cli.hasMattpocockResidue([{ projectRelPath: '.claude/agents/missing.md' }], tmp),
      false,
      'a spec whose file does not exist on disk should not be treated as residue'
    );
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
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

// --- Integration: backfillSubstitutionsFromDisk / backfillFileHashesFromDisk
// against a simulated legacy project on a real temp CWD (these two functions
// read CWD-relative paths, so they need an actual directory, not just strings).
{
  const cliPath = path.join(REPO_ROOT, 'bin', 'cli.js');
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-backfill-test-'));
  const prevCwd = process.cwd();
  process.chdir(tmp);
  // cli.js captures `const CWD = process.cwd()` at module-load time, so it
  // must be required AFTER chdir — the already-loaded `cli` reference above
  // would silently resolve every backfill path against the ORIGINAL cwd.
  delete require.cache[require.resolve(cliPath)];
  const cliInTemp = require(cliPath);
  try {
    // Exercises the legacy `hivemind` -> spec-master+task-master one-to-two
    // migration (LEGACY_PERSONA_MAP, Step 3.4): a simulated legacy project
    // already has the SPLIT files on disk (an early manual upgrade, or a
    // project predating fileHashes/substitutions tracking) but its
    // personaSelection still carries the deprecated "hivemind" token. Real
    // runUpdate() deletes the legacy `.claude/agents/hivemind.md` before
    // backfill ever runs (bin/cli.js's `hadLegacyToken` branch), so it's
    // never present on disk by the time buildFileSpecs/backfill see it —
    // only spec-master.md/task-master.md are.
    check('backfillSubstitutionsFromDisk + backfillFileHashesFromDisk backfill a simulated legacy project through the hivemind one-to-two migration', () => {
      fs.mkdirSync(path.join(tmp, '.claude', 'agents'), { recursive: true });
      for (const name of ['spec-master', 'task-master', 'lead-programmer']) {
        const sourceBody = fs.readFileSync(path.join(REPO_ROOT, 'agents', `${name}.md`), 'utf8');
        const substituted = cliInTemp.applyMattpocockSubs(sourceBody, KNOWN_MAP, name);
        fs.writeFileSync(path.join(tmp, '.claude', 'agents', `${name}.md`), substituted);
      }
      // orchestrator/explorer/persona-protocol/protocol-digest are also in
      // buildFileSpecs but deliberately left absent from disk here — backfill
      // must skip missing files silently, not error.
      const migrated = cliInTemp.migrateLegacyPersonaTokens(['hivemind'], { logNote: false });
      assert.ok(
        migrated.includes('spec-master') && migrated.includes('task-master') && !migrated.includes('hivemind'),
        `expected the legacy "hivemind" token to expand to both new personas, got ${JSON.stringify(migrated)}`
      );
      const specs = cliInTemp.buildFileSpecs(migrated);
      const config = {};
      const changedSubs = cliInTemp.backfillSubstitutionsFromDisk(config, specs);
      const changedHashes = cliInTemp.backfillFileHashesFromDisk(config, specs);
      assert.strictEqual(changedSubs, true);
      assert.strictEqual(changedHashes, true);
      for (const slot of ['grill-me', 'to-spec', 'to-issues', 'tdd', 'diagnose']) {
        assert.strictEqual(config.substitutions.mattpocockSkills[slot], KNOWN_MAP[slot], `slot ${slot}`);
      }
      assert.ok(config.fileHashes['.claude/agents/spec-master.md']);
      assert.ok(config.fileHashes['.claude/agents/task-master.md']);
      assert.ok(config.fileHashes['.claude/agents/lead-programmer.md']);
      assert.strictEqual(config.fileHashes['.claude/agents/hivemind.md'], undefined);
      assert.strictEqual(config.fileHashes['.claude/agents/explorer.md'], undefined);
    });
  } finally {
    process.chdir(prevCwd);
    delete require.cache[require.resolve(cliPath)];
    fs.rmSync(tmp, { recursive: true, force: true });
  }
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
      substitutions: { mattpocockSkills: KNOWN_MAP, graphMcpLaunch },
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

if (failures > 0) {
  console.error(`\n${failures} test(s) failed.`);
  process.exit(1);
}
console.log('\nAll cli-backfill tests passed.');
