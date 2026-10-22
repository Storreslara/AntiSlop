#!/usr/bin/env node
'use strict';

// qw-u6: the orchestrator ships `model: sonnet`; persona-config `orchestratorModel` overrides the
// rendered mirror's frontmatter line, and `inherit` keeps the user's session model.

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');
const cli = require(path.join(REPO_ROOT, 'bin/cli.js'));

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

function frontmatterModels(text) {
  const fm = text.match(/^---\n[\s\S]*?\n---\n/);
  return fm ? (fm[0].match(/^model: .*$/gm) || []) : [];
}

const SRC = fs.readFileSync(path.join(REPO_ROOT, 'agents/orchestrator.md'), 'utf8');

check('(a) agents/orchestrator.md ships exactly one frontmatter line `model: sonnet`', () => {
  assert.deepStrictEqual(frontmatterModels(SRC), ['model: sonnet']);
});

check('(b) an absent key leaves the body unchanged', () => {
  assert.strictEqual(cli.applyOrchestratorModel(SRC, 'orchestrator', {}), SRC);
  assert.strictEqual(cli.applyOrchestratorModel(SRC, 'orchestrator', null), SRC);
});

check('(c) inherit and opus replace only the frontmatter model line', () => {
  for (const v of ['inherit', 'opus', 'haiku']) {
    const out = cli.applyOrchestratorModel(SRC, 'orchestrator', { orchestratorModel: v });
    assert.deepStrictEqual(frontmatterModels(out), [`model: ${v}`]);
    assert.strictEqual(out.replace(`model: ${v}`, 'model: sonnet'), SRC);
  }
});

check('(d) an unrecognised value keeps the shipped model', () => {
  assert.strictEqual(cli.applyOrchestratorModel(SRC, 'orchestrator', { orchestratorModel: 'gpt-x' }), SRC);
});

check('(e) another persona is never touched', () => {
  const rev = fs.readFileSync(path.join(REPO_ROOT, 'agents/reviewer.md'), 'utf8');
  assert.strictEqual(cli.applyOrchestratorModel(rev, 'reviewer', { orchestratorModel: 'inherit' }), rev);
});

check('(f) a source with no model line (A/B uniform strip) gains none', () => {
  const stripped = SRC.replace(/^model: sonnet\n/m, '') + '\nmodel: example prose\n';
  assert.deepStrictEqual(frontmatterModels(stripped), []);
  assert.strictEqual(cli.applyOrchestratorModel(stripped, 'orchestrator', { orchestratorModel: 'opus' }), stripped);
});

check('(g) a body line after the frontmatter that starts with model: is left alone', () => {
  const body = SRC + '\nmodel: example prose\n';
  const out = cli.applyOrchestratorModel(body, 'orchestrator', { orchestratorModel: 'inherit' });
  assert.ok(out.endsWith('\nmodel: example prose\n'));
});

check('(h) the schema declares orchestratorModel with the four values and default sonnet', () => {
  const schema = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'templates/persona-config.schema.json'), 'utf8'));
  const p = schema.properties.orchestratorModel;
  assert.ok(p, 'no orchestratorModel property');
  assert.deepStrictEqual(p.enum, ['sonnet', 'opus', 'haiku', 'inherit']);
  assert.strictEqual(p.default, 'sonnet');
});

check('(i) scaffold renders sonnet; the opt-out renders inherit after --update --force-render', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'orch-model-'));
  try {
    const run = (args) => execFileSync('node', [path.join(REPO_ROOT, 'bin/cli.js'), ...args], { cwd: tmp, stdio: 'pipe' });
    execFileSync('git', ['init', '-q', '.'], { cwd: tmp });
    run(['--personas=spec-master,task-master,reviewer,scribe']);
    const mirror = path.join(tmp, '.claude', 'agents', 'orchestrator.md');
    assert.deepStrictEqual(frontmatterModels(fs.readFileSync(mirror, 'utf8')), ['model: sonnet']);
    const cfgPath = path.join(tmp, '.claude', 'persona' + '-config.json');
    const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
    cfg.orchestratorModel = 'inherit';
    fs.writeFileSync(cfgPath, JSON.stringify(cfg, null, 2) + '\n');
    // A fresh scaffold has no graph launch command recorded, so --update exits 1 over explorer.md
    // after rendering every other file; only the orchestrator mirror matters here.
    let out = '';
    try { out = run(['--update', '--force-render']).toString(); } catch (e) { out = String(e.stdout); }
    assert.ok(out.includes('.claude/agents/orchestrator.md: updated'), `orchestrator mirror not re-rendered: ${out.slice(0, 300)}`);
    assert.deepStrictEqual(frontmatterModels(fs.readFileSync(mirror, 'utf8')), ['model: inherit']);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

check('(j) a non-string value warns without throwing and keeps the shipped model (rp-u10)', () => {
  const warn = console.warn;
  const seen = [];
  console.warn = (m) => seen.push(String(m));
  try {
    assert.strictEqual(cli.applyOrchestratorModel(SRC, 'orchestrator', { orchestratorModel: { toString: 'x' } }), SRC);
    assert.strictEqual(cli.applyOrchestratorModel(SRC, 'orchestrator', { orchestratorModel: 7 }), SRC);
    assert.strictEqual(cli.applyOrchestratorModel(SRC, 'orchestrator', { orchestratorModel: 'gpt-x' }), SRC);
  } finally {
    console.warn = warn;
  }
  assert.deepStrictEqual(seen.map((m) => m.split(' is not one of')[0]), [
    'Note: persona-config.json orchestratorModel {"toString":"x"}',
    'Note: persona-config.json orchestratorModel 7',
    'Note: persona-config.json orchestratorModel "gpt-x"',
  ]);
});

if (failures > 0) {
  console.log(`${failures} orchestrator-model check(s) FAILED.`);
  process.exit(1);
}
console.log('All orchestrator-model checks passed.');
