#!/usr/bin/env node
'use strict';

// Coverage for scripts/unit-outcomes.js (rgh-u0-2): read-only unit-outcome export.

const assert = require('assert');
const crypto = require('crypto');
const cp = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const FIX = path.join(__dirname, 'fixtures', 'unit-outcomes');
const SCRIPT = path.join(REPO_ROOT, 'scripts', 'unit-outcomes.js');
const CUTOFF = '2026-09-15T00:00:00Z';

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

function git(cwd, args, env) {
  return cp.execFileSync('git', args, { cwd, encoding: 'utf8', env: { ...process.env, ...env } }).trim();
}

function buildScratchRepo() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'unit-outcomes-'));
  const env = { GIT_AUTHOR_DATE: '2026-08-30T00:00:00Z', GIT_COMMITTER_DATE: '2026-08-30T00:00:00Z' };
  git(dir, ['init', '-q'], env);
  git(dir, ['config', 'user.email', 't@example.com']);
  git(dir, ['config', 'user.name', 'T']);
  fs.mkdirSync(path.join(dir, 'agents'));
  fs.writeFileSync(path.join(dir, 'agents', 'lead-programmer.md'), '---\nname: lead-programmer\nmodel: sonnet\n---\nbody\n');
  git(dir, ['add', '-A']);
  git(dir, ['commit', '-q', '-m', 'chore: base'], env);
  const base = git(dir, ['rev-parse', 'HEAD']);
  git(dir, ['commit', '-q', '--allow-empty', '-m', 'test(fx-scope-1): red'], env);
  git(dir, ['commit', '-q', '--allow-empty', '-m', 'feat(fx-scope-1): green'], env);
  return { dir, base };
}

function run(repo, extra) {
  const out = cp.execFileSync('node', [
    SCRIPT,
    `--repo=${repo}`,
    `--markers=${path.join(FIX, 'markers')}`,
    `--transcripts=${path.join(FIX, 'transcripts')}`,
    ...extra,
  ], { cwd: REPO_ROOT, encoding: 'utf8', env: { ...process.env, GH_BIN: path.join(FIX, 'bin', 'gh') } });
  return out;
}

function rows(repo, until) {
  const out = run(repo, [`--until=${until}`]);
  const map = {};
  out.split('\n').filter(Boolean).forEach((l) => { const o = JSON.parse(l); map[o.id] = o; });
  return { map, out };
}

function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => (
    e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]));
}

function checksums() {
  return walk(FIX).sort().map((f) => `${f}:${crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex')}`).join('\n');
}

const scratch = buildScratchRepo();
const mtimeFile = path.join(FIX, 'markers', 'fx-mtime.pass');
const mtimeOrig = fs.statSync(mtimeFile).mtime;
const early = new Date('2026-09-01T00:00:00Z');
fs.utimesSync(mtimeFile, early, early);

const { map: R, out: OUT } = rows(scratch.dir, CUTOFF);

check('cap-plus-pass attempts 3', () => {
  assert.strictEqual(R['fx-cap3'].attempts, 3);
  assert.strictEqual(R['fx-cap3'].cap_hit, true);
});
check('observed tier', () => {
  assert.deepStrictEqual(R['fx-1'].implementer_tiers, [{ tier: 'sonnet', source: 'observed' }]);
  assert.deepStrictEqual(R['fx-1'].reviewer_tiers, [{ tier: 'opus', source: 'observed' }]);
});
check('frontmatter-inferred tier', () => {
  assert.deepStrictEqual(R['fx-cap3'].implementer_tiers, [{ tier: 'sonnet', source: 'frontmatter-inferred' }]);
});
check('commit-scope baseline', () => {
  assert.strictEqual(R['fx-scope-1'].range_source, 'commit-scope');
  assert.strictEqual(R['fx-scope-1'].baseline, scratch.base);
});
check('no-range none', () => {
  assert.strictEqual(R['fx-1'].range_source, 'none');
  assert.strictEqual(R['fx-1'].baseline, null);
});
check('fail_classes vacuous+version', () => {
  assert.deepStrictEqual(R['fx-class'].fail_classes, ['version', 'vacuous']);
});
check('fail_classes empty', () => {
  assert.deepStrictEqual(R['fx-plain'].fail_classes, []);
});
check('contract source gh stub', () => {
  assert.strictEqual(R['fx-cap'].contract_source, 'issue#7');
  assert.strictEqual(R['fx-cap'].contract_author, 'task-master');
  assert.strictEqual(R['fx-cap'].plan, 'fx-plan');
  assert.strictEqual(R['fx-1'].contract_source, 'transcript');
});
function scoreText(text) {
  const out = cp.execFileSync('node', [path.join(REPO_ROOT, 'bin', 'contract-score.js'), '-'], { input: text, encoding: 'utf8' });
  return JSON.parse(out).score;
}
check('issue attribution rejects mention-only title', () => {
  assert.strictEqual(R['fx-class'].contract_source, 'none');
  assert.strictEqual(R['fx-class'].contract_author, 'unknown');
  assert.strictEqual(R['fx-class'].plan, null);
  assert.strictEqual(R['fx-class'].contract_score, null);
});
check('issue attribution accepts verified hit', () => {
  assert.strictEqual(R['fx-cap'].contract_source, 'issue#7');
  assert.strictEqual(R['fx-scope-1'].contract_source, 'issue#12');
});
check('issue score uses dispatch-contract block', () => {
  const block = fs.readFileSync(path.join(FIX, 'issues', 'fx-plain.block.md'), 'utf8');
  const body = JSON.parse(fs.readFileSync(path.join(FIX, 'issues', 'fx-plain.json'), 'utf8'))[0].body;
  assert.ok(body.includes(block) && scoreText(body) !== scoreText(block), 'fixture must discriminate');
  assert.strictEqual(R['fx-plain'].contract_source, 'issue#11');
  assert.strictEqual(R['fx-plain'].contract_score, scoreText(block));
});
check('privacy 40-char', () => {
  const texts = walk(FIX).filter((f) => /\.(fail|jsonl)$/.test(f)).map((f) => fs.readFileSync(f, 'utf8'));
  const prose = texts.flatMap((t) => t.split('\n'));
  let windows = 0;
  prose.forEach((line) => {
    for (let i = 0; i + 40 <= line.length; i++) {
      windows++;
      assert.ok(!OUT.includes(line.slice(i, i + 40)), `leaked: ${line.slice(i, i + 40)}`);
    }
  });
  assert.ok(windows > 100);
});
check('until excludes later PASS', () => {
  assert.strictEqual(R['fx-late'], undefined);
});
check('until keeps cap unit', () => {
  assert.strictEqual(R['fx-cap'].cap_hit, true);
  assert.strictEqual(R['fx-cap'].attempts, 2);
  assert.strictEqual(R['fx-cap'].final_commit, null);
});
check('until uses content not mtime', () => {
  assert.ok(fs.statSync(mtimeFile).mtime < new Date(CUTOFF));
  assert.strictEqual(R['fx-mtime'], undefined);
});
check('timestamps pass unit', () => {
  assert.strictEqual(R['fx-1'].pass_ts, '2026-09-01T10:00:00Z');
  assert.strictEqual(R['fx-1'].terminal_ts, '2026-09-01T10:00:00Z');
  assert.strictEqual(R['fx-1'].fail_blocks, 0);
});
check('timestamps cap unit', () => {
  assert.strictEqual(R['fx-cap'].pass_ts, null);
  assert.strictEqual(R['fx-cap'].terminal_ts, '2026-09-04T12:00:00Z');
  assert.strictEqual(R['fx-cap'].fail_blocks, 2);
});
check('gate G3 closed without rubric era', () => {
  const out = run(scratch.dir, [`--until=${CUTOFF}`, '--gate=G3']);
  assert.ok(/^G3 closed: /.test(out), out);
});
check('read-only porcelain', () => {
  const before = [git(REPO_ROOT, ['status', '--porcelain']), git(scratch.dir, ['status', '--porcelain'])];
  run(scratch.dir, [`--until=${CUTOFF}`]);
  const after = [git(REPO_ROOT, ['status', '--porcelain']), git(scratch.dir, ['status', '--porcelain'])];
  assert.deepStrictEqual(after, before);
});
check('read-only checksums', () => {
  const before = checksums();
  run(scratch.dir, [`--until=${CUTOFF}`]);
  assert.strictEqual(checksums(), before);
});

fs.utimesSync(mtimeFile, mtimeOrig, mtimeOrig);
fs.rmSync(scratch.dir, { recursive: true, force: true });

console.log(failures === 0 ? '\nAll unit-outcomes checks passed.' : `\n${failures} check(s) failed.`);
process.exit(failures === 0 ? 0 : 1);
