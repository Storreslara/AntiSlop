#!/usr/bin/env node
'use strict';

// Coverage for item18-1-add-config-field and item18-2-backfill-existing-
// configs (docs/plans/2026-09-25-item18-default-implementer-model-config.md,
// Steps 1 and 2): `defaultImplementerModel` as a persona-config.json field,
// with the precedence per-dispatch tag > config field > frontmatter default,
// and `--update` backfilling the key into already-adapted projects.

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');
const cliPath = path.join(REPO_ROOT, 'bin', 'cli.js');

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

const cli = require(cliPath);

function frontmatterModel(text) {
  const m = text.match(/^---\n[\s\S]*?\nmodel:\s*(\S+)\n[\s\S]*?\n---/);
  return m ? m[1] : null;
}

check('a fresh scaffold emits defaultImplementerModel agreeing with agents/lead-programmer.md frontmatter', () => {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dim-fresh-cwd-'));
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dim-fresh-home-'));
  try {
    const result = spawnSync('node', [cliPath, '--yes'], {
      cwd,
      env: Object.assign({}, process.env, { HOME: home }),
      encoding: 'utf8',
    });
    assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
    const written = JSON.parse(fs.readFileSync(path.join(cwd, '.claude', 'persona-config.json'), 'utf8'));
    const expected = frontmatterModel(fs.readFileSync(path.join(REPO_ROOT, 'agents', 'lead-programmer.md'), 'utf8'));
    assert.ok(expected, 'could not read agents/lead-programmer.md frontmatter model');
    assert.strictEqual(
      written.defaultImplementerModel, expected,
      `fresh-install skeleton must ship defaultImplementerModel: ${JSON.stringify(expected)}, got ${JSON.stringify(written.defaultImplementerModel)}`
    );
  } finally {
    fs.rmSync(cwd, { recursive: true, force: true });
    fs.rmSync(home, { recursive: true, force: true });
  }
});

check('resolveDefaultImplementerModel: absent key degrades to the frontmatter default', () => {
  const config = { testAndLintCommand: '' }; // key removed/never set
  assert.strictEqual(cli.resolveDefaultImplementerModel(config, 'sonnet'), 'sonnet');
});

check('resolveDefaultImplementerModel: a recognised value passes through', () => {
  assert.strictEqual(cli.resolveDefaultImplementerModel({ defaultImplementerModel: 'opus' }, 'sonnet'), 'opus');
});

check('resolveDefaultImplementerModel: haiku is a recognised tier and passes through', () => {
  assert.strictEqual(cli.resolveDefaultImplementerModel({ defaultImplementerModel: 'haiku' }, 'sonnet'), 'haiku');
});

check('resolveDefaultImplementerModel: an unrecognised value resolves to opus (more capability, never less)', () => {
  assert.strictEqual(cli.resolveDefaultImplementerModel({ defaultImplementerModel: 'bogus-junk' }, 'sonnet'), 'opus');
  assert.strictEqual(cli.resolveDefaultImplementerModel({ defaultImplementerModel: 'fable' }, 'haiku'), 'opus');
});

check('IMPLEMENTER_MODEL_TIERS equals the schema enum', () => {
  const schema = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'templates', 'persona-config.schema.json'), 'utf8'));
  assert.deepStrictEqual(cli.IMPLEMENTER_MODEL_TIERS, schema.properties.defaultImplementerModel.enum);
});

check('migrateDefaultImplementerModel: only an old-version "sonnet" moves, only to haiku, only when enabled', () => {
  const m = cli.migrateDefaultImplementerModel;
  assert.strictEqual(m('sonnet', '0.31.140', '0.31.143', 'haiku'), 'haiku');
  assert.strictEqual(m('sonnet', '0.31.143', '0.31.143', 'haiku'), null);
  assert.strictEqual(m('sonnet', undefined, '0.31.143', 'haiku'), 'haiku');
  assert.strictEqual(m('opus', '0.31.140', '0.31.143', 'haiku'), null);
  assert.strictEqual(m('haiku', '0.31.140', '0.31.143', 'haiku'), null);
  assert.strictEqual(m('sonnet', '0.31.140', null, 'haiku'), null);
  assert.strictEqual(m('sonnet', '0.31.140', '0.31.143', 'sonnet'), null);
});

// Pins the stated "absent means nullish" decision in bin/cli.js: an explicit
// null (and a missing config object) is "no opinion", not junk.
check('resolveDefaultImplementerModel: a null value and a missing config both count as absent', () => {
  assert.strictEqual(cli.resolveDefaultImplementerModel({ defaultImplementerModel: null }, 'sonnet'), 'sonnet');
  assert.strictEqual(cli.resolveDefaultImplementerModel(null, 'sonnet'), 'sonnet');
  assert.strictEqual(cli.resolveDefaultImplementerModel(undefined, 'sonnet'), 'sonnet');
});

// Whitespace-stripped (not just collapsed) so a wrapped line break inside
// the phrase can't evade the check (see writer-tier-consistency.test.js's
// AC-D9 for the same pattern).
function stripWhitespace(text) {
  return text.replace(/\s+/g, '');
}

check('agents/orchestrator.md documents the per-dispatch tag > config field > frontmatter precedence', () => {
  const text = stripWhitespace(fs.readFileSync(path.join(REPO_ROOT, 'agents', 'orchestrator.md'), 'utf8'));
  assert.ok(
    text.includes(stripWhitespace('`Suggested model` tag > `defaultImplementerModel` config field > frontmatter default')),
    'orchestrator.md does not state the per-dispatch tag > config field > frontmatter precedence'
  );
});

// The orchestrator prose is the production resolution path (it tells the
// orchestrator to read the raw value itself), so the fallback rule it states
// must match resolveDefaultImplementerModel's, not just the precedence chain.
check('agents/orchestrator.md restricts the frontmatter fallback to an absent key and escalates any other unrecognised value to opus', () => {
  const text = stripWhitespace(fs.readFileSync(path.join(REPO_ROOT, 'agents', 'orchestrator.md'), 'utf8'));
  assert.ok(
    text.includes(stripWhitespace('Only an **absent** key resolves to that frontmatter default')),
    'orchestrator.md does not restrict the frontmatter-default fallback to an absent key'
  );
  assert.ok(
    text.includes(stripWhitespace("outside the recognised set (`templates/persona-config.schema.json`'s `defaultImplementerModel` enum) resolves to the **more** capable tier, `opus`")),
    'orchestrator.md does not state that a present-but-unrecognised value resolves to `opus`'
  );
  assert.ok(
    !text.includes(stripWhitespace('and so does any value that')),
    'orchestrator.md still sends an unrecognised value to the frontmatter default (the cheaper tier)'
  );
});

// --- item18-2: --update backfill. Builds a fixture the same way
// tests/cli-backfill.test.js's buildBaselineProject does: every current spec
// rendered clean and stamped at the plugin's OWN version, so the version-
// match fast-path is in play and the only drift the fixture introduces is
// the one each check is about. A `--yes` scaffold-then-`--update` fixture was
// tried first and rejected: it leaves explorer.md's MCP placeholder
// unresolved (no --wire-graph-mcp in scripted mode), which fails `--update`
// for a reason unrelated to this backfill.
const PLUGIN_VERSION = JSON.parse(
  fs.readFileSync(path.join(REPO_ROOT, '.claude-plugin', 'plugin.json'), 'utf8')
).version;
const GRAPH_MCP_LAUNCH = { command: 'npx', args: ['code-review-graph-mcp'] };

function stampBody(body, sourceRelPath) {
  const stamp = `<!-- antislop v${PLUGIN_VERSION} | source: ${sourceRelPath} | ADAPT-substituted -->\n`;
  const fmMatch = body.match(/^---\r?\n[\s\S]*?\r?\n---\r?\n/);
  if (!fmMatch) return stamp + body;
  const end = fmMatch[0].length;
  return body.slice(0, end) + stamp + body.slice(end);
}

function buildBaselineProject(tmp) {
  const specs = cli.buildFileSpecs([]);
  const config = {
    pluginVersion: PLUGIN_VERSION,
    personaSelection: [],
    substitutions: { graphMcpLaunch: GRAPH_MCP_LAUNCH },
    fileHashes: {},
    humanReviewMode: 'critical',
    defaultImplementerModel: frontmatterModel(fs.readFileSync(path.join(REPO_ROOT, 'agents', 'lead-programmer.md'), 'utf8')),
  };
  for (const spec of specs) {
    const cleanBody = cli.renderCleanBody(spec, config);
    const destAbsPath = path.join(tmp, spec.projectRelPath);
    fs.mkdirSync(path.dirname(destAbsPath), { recursive: true });
    fs.writeFileSync(destAbsPath, stampBody(cleanBody, spec.sourceRelPath));
    config.fileHashes[spec.projectRelPath] = cli.sha256Hex(cleanBody);
  }
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

function readConfig(tmp) {
  return JSON.parse(fs.readFileSync(path.join(tmp, '.claude', 'persona-config.json'), 'utf8'));
}

function writeConfig(tmp, config) {
  fs.writeFileSync(path.join(tmp, '.claude', 'persona-config.json'), JSON.stringify(config, null, 2) + '\n');
}

check('--update backfills defaultImplementerModel for a config lacking it, without disturbing an unrelated field', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dim-backfill-missing-'));
  try {
    const before = buildBaselineProject(tmp);
    delete before.defaultImplementerModel;
    const humanReviewModeBefore = before.humanReviewMode;
    writeConfig(tmp, before);

    const result = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
    assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);

    const after = readConfig(tmp);
    const expected = frontmatterModel(fs.readFileSync(path.join(REPO_ROOT, 'agents', 'lead-programmer.md'), 'utf8'));
    assert.strictEqual(
      after.defaultImplementerModel, expected,
      `--update must backfill defaultImplementerModel: ${JSON.stringify(expected)}, got ${JSON.stringify(after.defaultImplementerModel)}`
    );
    // Non-vacuity: the backfill must not have touched an unrelated field.
    assert.strictEqual(after.humanReviewMode, humanReviewModeBefore, 'humanReviewMode must be byte-identical before/after the backfill');
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

check('--update is idempotent: a second run leaves the config unchanged after the first backfill', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dim-backfill-idempotent-'));
  try {
    const before = buildBaselineProject(tmp);
    delete before.defaultImplementerModel;
    writeConfig(tmp, before);

    const first = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
    assert.strictEqual(first.status, 0, `first --update expected exit 0, got ${first.status}: ${first.stdout}${first.stderr}`);
    const afterFirst = fs.readFileSync(path.join(tmp, '.claude', 'persona-config.json'), 'utf8');

    const second = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
    assert.strictEqual(second.status, 0, `second --update expected exit 0, got ${second.status}: ${second.stdout}${second.stderr}`);
    const afterSecond = fs.readFileSync(path.join(tmp, '.claude', 'persona-config.json'), 'utf8');

    assert.strictEqual(afterSecond, afterFirst, 'a second --update must leave persona-config.json byte-identical to the first backfill');
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

check('--update preserves a deliberately-set non-default defaultImplementerModel value', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dim-backfill-preserve-'));
  try {
    const before = buildBaselineProject(tmp);
    before.defaultImplementerModel = 'opus';
    writeConfig(tmp, before);

    const result = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
    assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);

    const after = readConfig(tmp);
    assert.strictEqual(after.defaultImplementerModel, 'opus', 'a deliberately-set non-default value must survive --update untouched');
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

check('--update applies migrateDefaultImplementerModel to an old-version "sonnet" config', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dim-migrate-'));
  try {
    const before = buildBaselineProject(tmp);
    before.defaultImplementerModel = 'sonnet';
    before.pluginVersion = '0.31.0';
    writeConfig(tmp, before);

    const result = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
    assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);

    const frontmatter = frontmatterModel(fs.readFileSync(path.join(REPO_ROOT, 'agents', 'lead-programmer.md'), 'utf8'));
    const expected = cli.migrateDefaultImplementerModel('sonnet', '0.31.0', cli.IMPLEMENTER_HAIKU_DEFAULT_SINCE, frontmatter) || 'sonnet';
    assert.strictEqual(readConfig(tmp).defaultImplementerModel, expected);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

check('--update --dry-run against a config missing defaultImplementerModel reports the pending change without writing it', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dim-backfill-dryrun-'));
  try {
    const before = buildBaselineProject(tmp);
    delete before.defaultImplementerModel;
    writeConfig(tmp, before);
    const configPath = path.join(tmp, '.claude', 'persona-config.json');
    const bytesBefore = fs.readFileSync(configPath, 'utf8');

    const result = spawnSync('node', [cliPath, '--update', '--dry-run'], { cwd: tmp, encoding: 'utf8' });
    assert.strictEqual(result.status, 3, `expected exit 3 (would mutate), got ${result.status}: ${result.stdout}${result.stderr}`);
    assert.ok(
      result.stdout.includes('would backfill to'),
      `dry-run output must report the pending backfill in future tense, got: ${result.stdout}`
    );
    assert.ok(
      !result.stdout.includes('— backfilled to'),
      `dry-run output must not claim the backfill already happened, got: ${result.stdout}`
    );

    const bytesAfter = fs.readFileSync(configPath, 'utf8');
    assert.strictEqual(bytesAfter, bytesBefore, '--dry-run must not write defaultImplementerModel to disk');
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

console.log(failures === 0 ? '\nAll default-implementer-model checks passed.' : `\n${failures} check(s) failed.`);
process.exit(failures === 0 ? 0 : 1);
