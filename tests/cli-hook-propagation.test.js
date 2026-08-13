#!/usr/bin/env node
'use strict';

// `bin/cli.js --update` must deliver hook scripts and their hooks.json
// registrations to an ALREADY-installed standalone project — the upgrade path
// used to refresh persona files only, so a project installed before a gate
// existed never received it (docs/plans/2026-08-12-standalone-hook-propagation-gap.md).

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');
const CLI = path.join(REPO_ROOT, 'bin', 'cli.js');
const PKG_HOOKS = path.join(REPO_ROOT, 'hooks', 'scripts');
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

// Enumerated at runtime, never hardcoded: a hook added later is covered
// without editing this test (AC1.3).
function packagedHookRelPaths(dir, prefix) {
  const out = [];
  for (const entry of fs.readdirSync(dir || PKG_HOOKS, { withFileTypes: true })) {
    const rel = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (entry.isDirectory()) out.push(...packagedHookRelPaths(path.join(dir || PKG_HOOKS, entry.name), rel));
    else out.push(rel);
  }
  return out.sort();
}

// A real scaffold into a throwaway cwd with a throwaway HOME, so
// detectMarketplacePlugin can't pick up the dev box's own enabled plugin.
function makeProject() {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-hookprop-cwd-'));
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-hookprop-home-'));
  const scaffold = spawnSync('node', [CLI, '--yes'], {
    cwd,
    env: Object.assign({}, process.env, { HOME: home }),
    encoding: 'utf8',
  });
  assert.strictEqual(scaffold.status, 0, `scaffold failed: ${scaffold.stdout}${scaffold.stderr}`);
  return { cwd, home };
}

// The scaffold leaves explorer.md's graph-MCP placeholder unresolved, which
// aborts --update's render loop for a reason unrelated to hook propagation.
function resolveSubstitutions(project) {
  const cfgPath = path.join(project.cwd, '.claude', 'persona-config.json');
  const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
  cfg.substitutions = {
    graphMcpLaunch: { command: 'npx', args: ['code-review-graph-mcp'] },
    arxivMcpLaunch: null,
  };
  fs.writeFileSync(cfgPath, JSON.stringify(cfg, null, 2) + '\n');
}

function update(project, extraArgs) {
  return spawnSync('node', [CLI, '--update'].concat(extraArgs || []), {
    cwd: project.cwd,
    env: Object.assign({}, process.env, { HOME: project.home }),
    encoding: 'utf8',
  });
}

function cleanup(project) {
  fs.rmSync(project.cwd, { recursive: true, force: true });
  fs.rmSync(project.home, { recursive: true, force: true });
}

function mirrorPath(project, rel) {
  return path.join(project.cwd, '.claude', 'hooks', 'scripts', rel);
}

function readSettings(project) {
  return JSON.parse(fs.readFileSync(path.join(project.cwd, '.claude', 'settings.json'), 'utf8'));
}

check('AC1.2: --update restores hook scripts deleted from an adapted project', () => {
  const project = makeProject();
  try {
    resolveSubstitutions(project);
    const deleted = ['human-decision-gate.sh', 'lib/benign-command.sh'];
    for (const rel of deleted) fs.unlinkSync(mirrorPath(project, rel));

    const result = update(project);
    assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
    for (const rel of deleted) {
      assert.ok(fs.existsSync(mirrorPath(project, rel)), `${rel} was not restored`);
      assert.strictEqual(
        fs.readFileSync(mirrorPath(project, rel), 'utf8'),
        fs.readFileSync(path.join(PKG_HOOKS, rel), 'utf8'),
        `${rel} is not byte-identical to the packaged original`
      );
      // A restored gate that isn't executable is a gate that never fires.
      assert.strictEqual(
        fs.statSync(mirrorPath(project, rel)).mode & 0o777,
        fs.statSync(path.join(PKG_HOOKS, rel)).mode & 0o777,
        `${rel} did not keep the packaged file mode`
      );
    }
  } finally {
    cleanup(project);
  }
});

check('AC1.3: after --update every packaged hook script (including lib/) is present and byte-identical', () => {
  const project = makeProject();
  try {
    resolveSubstitutions(project);
    const rels = packagedHookRelPaths();
    assert.ok(rels.includes('lib/benign-command.sh'), 'fixture sanity: lib/ must be enumerated');
    // Mutate a representative spread: a deleted gate, a deleted lib file, and
    // an outright stale one, so "already identical" can't carry the assertion.
    fs.unlinkSync(mirrorPath(project, 'human-decision-gate.sh'));
    fs.unlinkSync(mirrorPath(project, 'lib/benign-command.sh'));
    fs.writeFileSync(mirrorPath(project, 'stop-gate.sh'), 'STALE\n');

    const result = update(project);
    assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
    for (const rel of rels) {
      const dest = mirrorPath(project, rel);
      assert.ok(fs.existsSync(dest), `${rel} missing from the adapted project after --update`);
      assert.strictEqual(
        fs.readFileSync(dest, 'utf8'),
        fs.readFileSync(path.join(PKG_HOOKS, rel), 'utf8'),
        `${rel} is not byte-identical to the packaged original`
      );
    }
  } finally {
    cleanup(project);
  }
});

// Every (event, matcher, command) the packaged hooks.json expects a
// standalone project to carry, in the CLI's own rewritten form.
function expectedRegistrations() {
  const raw = fs.readFileSync(path.join(REPO_ROOT, 'hooks', 'hooks.json'), 'utf8');
  const config = JSON.parse(
    raw.replace(/\$\{CLAUDE_PLUGIN_ROOT\}\/hooks\/scripts/g, '${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts')
  );
  const out = [];
  for (const [event, groups] of Object.entries(config.hooks)) {
    for (const group of groups) {
      for (const entry of group.hooks) out.push({ event, matcher: group.matcher || null, command: entry.command });
    }
  }
  return out;
}

function stripRegistrations(project, scriptNames) {
  const settingsPath = path.join(project.cwd, '.claude', 'settings.json');
  const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
  for (const groups of Object.values(settings.hooks || {})) {
    for (const group of groups) {
      group.hooks = (group.hooks || []).filter(
        (h) => !scriptNames.some((n) => h.command.endsWith('/' + n))
      );
    }
  }
  fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
}

function registrationsIn(settings) {
  const out = [];
  for (const [event, groups] of Object.entries(settings.hooks || {})) {
    for (const group of groups) {
      for (const entry of group.hooks || []) out.push({ event, matcher: group.matcher || null, command: entry.command });
    }
  }
  return out;
}

check('AC1.4: --update backfills hook registrations stripped from .claude/settings.json', () => {
  const project = makeProject();
  try {
    resolveSubstitutions(project);
    stripRegistrations(project, ['human-decision-gate.sh', 'microworld-rerun.sh']);
    const before = registrationsIn(readSettings(project));
    assert.ok(
      !before.some((r) => r.command.endsWith('human-decision-gate.sh')),
      'fixture sanity: the gate registration must be gone before --update'
    );

    const result = update(project);
    assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);

    const after = registrationsIn(readSettings(project));
    const key = (r) => `${r.event}|${r.matcher}|${r.command}`;
    const got = after.map(key);
    for (const want of expectedRegistrations()) {
      assert.ok(got.includes(key(want)), `missing registration after --update: ${key(want)}`);
    }
    assert.strictEqual(new Set(got).size, got.length, `--update duplicated a registration: ${got.join(', ')}`);
  } finally {
    cleanup(project);
  }
});

check('AC1.5 (guard): with the marketplace plugin enabled, --update adds zero hook registrations', () => {
  const project = makeProject();
  try {
    resolveSubstitutions(project);
    stripRegistrations(project, ['human-decision-gate.sh', 'microworld-rerun.sh']);
    fs.writeFileSync(
      path.join(project.cwd, '.claude', 'settings.local.json'),
      JSON.stringify({ enabledPlugins: { 'antislop@antislop-marketplace': true } })
    );
    const settingsPath = path.join(project.cwd, '.claude', 'settings.json');
    const before = JSON.stringify(JSON.parse(fs.readFileSync(settingsPath, 'utf8')).hooks);

    const result = update(project);
    assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);

    const after = JSON.stringify(JSON.parse(fs.readFileSync(settingsPath, 'utf8')).hooks);
    assert.strictEqual(after, before, 'the hooks key must be untouched when the marketplace plugin is enabled');
  } finally {
    cleanup(project);
  }
});

// A project whose hook scripts already have a recorded fileHashes baseline,
// then hand-edited: the one case where the local edit is provably the user's
// and not just a pre-baseline unknown.
function projectWithLocallyEditedHook(rel, body) {
  const project = makeProject();
  resolveSubstitutions(project);
  const first = update(project);
  assert.strictEqual(first.status, 0, `baseline --update failed: ${first.stdout}${first.stderr}`);
  fs.writeFileSync(mirrorPath(project, rel), body);
  return project;
}

const EDITED_REL = 'session-start.sh';
const EDITED_BODY = '#!/usr/bin/env bash\n# local edit\nexit 0\n';
const EDITED_KEY = '.claude/hooks/scripts/' + EDITED_REL;

check('AC1.6: a locally-edited hook script is reported as diverged and --update exits non-zero', () => {
  const project = projectWithLocallyEditedHook(EDITED_REL, EDITED_BODY);
  try {
    const result = update(project);
    assert.notStrictEqual(result.status, 0, `expected a non-zero exit, got 0: ${result.stdout}`);
    assert.ok(result.stdout.includes(EDITED_KEY), `expected ${EDITED_KEY} named in the divergence report: ${result.stdout}`);
    assert.strictEqual(
      fs.readFileSync(mirrorPath(project, EDITED_REL), 'utf8'), EDITED_BODY,
      'the local edit must survive an unresolved --update'
    );
  } finally {
    cleanup(project);
  }
});

check('AC1.6: --accept overwrites the locally-edited hook script', () => {
  const project = projectWithLocallyEditedHook(EDITED_REL, EDITED_BODY);
  try {
    const result = update(project, [`--accept=${EDITED_KEY}`]);
    assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
    assert.strictEqual(
      fs.readFileSync(mirrorPath(project, EDITED_REL), 'utf8'),
      fs.readFileSync(path.join(PKG_HOOKS, EDITED_REL), 'utf8'),
      '--accept must restore the packaged version'
    );
  } finally {
    cleanup(project);
  }
});

check('AC1.6: --keep preserves the locally-edited hook script', () => {
  const project = projectWithLocallyEditedHook(EDITED_REL, EDITED_BODY);
  try {
    const result = update(project, [`--keep=${EDITED_KEY}`]);
    assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
    assert.strictEqual(
      fs.readFileSync(mirrorPath(project, EDITED_REL), 'utf8'), EDITED_BODY,
      '--keep must preserve the local edit'
    );
  } finally {
    cleanup(project);
  }
});

check('AC1.7: the first --update prints a one-time bootstrap note naming hook-script paths', () => {
  const project = makeProject();
  try {
    resolveSubstitutions(project);
    const cfgPath = path.join(project.cwd, '.claude', 'persona-config.json');
    assert.ok(
      !JSON.parse(fs.readFileSync(cfgPath, 'utf8')).fileHashes,
      'fixture sanity: a freshly scaffolded project has no recorded fileHashes'
    );

    const first = update(project);
    assert.strictEqual(first.status, 0, `expected exit 0, got ${first.status}: ${first.stdout}${first.stderr}`);
    assert.ok(
      /hook script\(s\) had no recorded fileHashes baseline/.test(first.stdout),
      `expected the hook-script bootstrap note, got: ${first.stdout}`
    );
    assert.ok(
      first.stdout.includes('.claude/hooks/scripts/stop-gate.sh'),
      `the note must name hook-script paths specifically, got: ${first.stdout}`
    );

    // One-time: the baseline is recorded, so a second run says nothing.
    const second = update(project);
    assert.strictEqual(second.status, 0, `expected exit 0, got ${second.status}: ${second.stdout}${second.stderr}`);
    assert.ok(
      !/had no recorded fileHashes baseline/.test(second.stdout),
      `the note must not repeat once baselines exist, got: ${second.stdout}`
    );
  } finally {
    cleanup(project);
  }
});

if (failures > 0) {
  console.error(`\n${failures} test(s) failed.`);
  process.exit(1);
}
console.log('\nAll cli-hook-propagation tests passed.');
