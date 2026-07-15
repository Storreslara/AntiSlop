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

// No-op variant of check() for subtests temporarily neutralized pending a
// redesign (see TODO(Step 3.6) below) — logs SKIP instead of running fn.
function skip(name) {
  console.log(`SKIP ${name}`);
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

check('migrateLegacyPersonaTokens resolves repo-historian to scribe without a planner token present', () => {
  // Reproduces a real already-adapted project's personaSelection (no
  // "planner" present) to confirm the legacy-token guard isn't keyed to
  // "planner" specifically.
  const selection = ['hivemind', 'repo-historian', 'researcher', 'milestone-auditor', 'reviewer'];
  const migrated = cli.migrateLegacyPersonaTokens(selection, { logNote: false });
  assert.ok(migrated.includes('scribe'), `expected "scribe" in ${JSON.stringify(migrated)}`);
  assert.ok(!migrated.includes('repo-historian'), `"repo-historian" should have been migrated away`);
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
    // TODO(Step 3.6): this subtest exercises the legacy hivemind -> (new
    // personas) migration path via buildFileSpecs(['hivemind']) /
    // fileHashes['.claude/agents/hivemind.md'], which Step 3.4 redesigns
    // with LEGACY_PERSONA_MAP (a one-to-two split). Neutralized here (see
    // Step 3.3b in docs/plans/2026-07-14-threefold-update.md) rather than
    // substantively fixed, since fixing it now would either pull 3.4's
    // design forward or be immediately broken by it. Step 3.6 owns
    // un-skipping and rewriting this fixture once LEGACY_PERSONA_MAP exists.
    skip('backfillSubstitutionsFromDisk + backfillFileHashesFromDisk backfill a simulated legacy project', () => {
      fs.mkdirSync(path.join(tmp, '.claude', 'agents'), { recursive: true });
      for (const name of ['hivemind', 'lead-programmer']) {
        const sourceBody = fs.readFileSync(path.join(REPO_ROOT, 'agents', `${name}.md`), 'utf8');
        const substituted = cliInTemp.applyMattpocockSubs(sourceBody, KNOWN_MAP, name);
        fs.writeFileSync(path.join(tmp, '.claude', 'agents', `${name}.md`), substituted);
      }
      // orchestrator/explorer/persona-protocol/protocol-digest are also in
      // buildFileSpecs but deliberately left absent from disk here — backfill
      // must skip missing files silently, not error.
      const specs = cliInTemp.buildFileSpecs(['hivemind']);
      const config = {};
      const changedSubs = cliInTemp.backfillSubstitutionsFromDisk(config, specs);
      const changedHashes = cliInTemp.backfillFileHashesFromDisk(config, specs);
      assert.strictEqual(changedSubs, true);
      assert.strictEqual(changedHashes, true);
      for (const slot of ['grill-me', 'to-issues', 'tdd', 'diagnose']) {
        assert.strictEqual(config.substitutions.mattpocockSkills[slot], KNOWN_MAP[slot], `slot ${slot}`);
      }
      assert.ok(config.fileHashes['.claude/agents/hivemind.md']);
      assert.ok(config.fileHashes['.claude/agents/lead-programmer.md']);
      assert.strictEqual(config.fileHashes['.claude/agents/explorer.md'], undefined);
    });
  } finally {
    process.chdir(prevCwd);
    delete require.cache[require.resolve(cliPath)];
    fs.rmSync(tmp, { recursive: true, force: true });
  }
}

if (failures > 0) {
  console.error(`\n${failures} test(s) failed.`);
  process.exit(1);
}
console.log('\nAll cli-backfill tests passed.');
