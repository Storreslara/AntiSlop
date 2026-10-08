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

function runWith(markers, repo, extra, env) {
  return cp.execFileSync('node', [SCRIPT, `--repo=${repo}`, `--markers=${markers}`,
    `--transcripts=${path.join(markers, 'no-transcripts')}`, ...extra],
  { cwd: REPO_ROOT, encoding: 'utf8', env: { ...process.env, GH_BIN: path.join(FIX, 'bin', 'gh'), ...env } });
}
function asofLine(markers, until) {
  return runWith(markers, scratch.dir, [`--until=${until}`]).split('\n').find((l) => l.startsWith('{"id":"fx-asof"'));
}
const AS_OF_10 = rows(scratch.dir, '2026-09-10').map['fx-asof'];
check('asof 09-10 row', () => {
  assert.ok(AS_OF_10, 'fx-asof absent');
  assert.strictEqual(AS_OF_10.pass_ts, null);
  assert.strictEqual(AS_OF_10.terminal_ts, '2026-09-03T10:00:00Z');
  assert.strictEqual(AS_OF_10.fail_blocks, 2);
  assert.strictEqual(AS_OF_10.attempts, 2);
  assert.strictEqual(AS_OF_10.cap_hit, true);
});
check('asof 09-30 row', () => {
  const r = rows(scratch.dir, '2026-09-30').map['fx-asof'];
  assert.strictEqual(r.pass_ts, '2026-09-20T10:00:00Z');
  assert.strictEqual(r.terminal_ts, '2026-09-03T10:00:00Z');
  assert.strictEqual(r.attempts, 3);
});
check('asof row stable without PASS file', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'uo-asof-'));
  fs.cpSync(path.join(FIX, 'markers'), dir, { recursive: true });
  fs.rmSync(path.join(dir, 'fx-asof.pass'));
  const without = asofLine(dir, '2026-09-10');
  const withPass = asofLine(path.join(FIX, 'markers'), '2026-09-10');
  fs.rmSync(dir, { recursive: true, force: true });
  assert.ok(withPass);
  assert.strictEqual(without, withPass);
});
check('source issue block wins', () => {
  assert.strictEqual(R['fx-src'].contract_source, 'issue#901');
  assert.strictEqual(R['fx-src'].contract_author, 'task-master');
  assert.strictEqual(R['fx-src'].contract_score, 7);
});
check('source pointer-only none', () => {
  assert.strictEqual(R['fx-ptr'].contract_source, 'none');
  assert.strictEqual(R['fx-ptr'].contract_score, null);
});
check('source contract_ts issue', () => {
  assert.strictEqual(R['fx-src'].contract_ts, '2026-09-01T09:00:00Z');
});
check('source contract_ts null', () => {
  assert.strictEqual(R['fx-ptr'].contract_ts, null);
});
check('fence five-tilde block, inner three-tilde line kept', () => {
  const body = JSON.parse(fs.readFileSync(path.join(FIX, 'issues', 'fx-tilde5.json'), 'utf8'))[0].body;
  const block = body.slice(body.indexOf('\n', body.indexOf('~~~~~')) + 1, body.lastIndexOf('~~~~~'));
  assert.ok(scoreText(block) === 7 && scoreText(block.slice(0, block.indexOf('~~~'))) !== 7, 'fixture must discriminate');
  assert.strictEqual(R['fx-tilde5'].contract_source, 'issue#902');
  assert.strictEqual(R['fx-tilde5'].contract_author, 'task-master');
  assert.strictEqual(R['fx-tilde5'].contract_ts, '2026-09-02T09:00:00Z');
  assert.strictEqual(R['fx-tilde5'].contract_score, 7);
});

const ALL_PASS = fs.readFileSync(path.join(REPO_ROOT, 'tests', 'fixtures', 'contract-score', 'all-pass.md'), 'utf8');
const MINUS_R1 = fs.readFileSync(path.join(REPO_ROOT, 'tests', 'fixtures', 'contract-score', 'minus-R1.md'), 'utf8');
const U34_PASS = '2026-09-01T00:00:00Z';
// units: {id, pass, fails: [[ts, text]], issue: [createdAt, bodyText] | null}
function g3Set(units) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'uo-g3-'));
  const stub = {};
  const all = [{ id: 'rgh-u3-4', pass: U34_PASS, fails: [], issue: null }, ...units];
  all.forEach((u) => {
    fs.writeFileSync(path.join(dir, `${u.id}.pass`), `PASS ${u.id} ${u.pass} commit: none criteria: fixture\n`);
    if (u.fails.length) {
      fs.writeFileSync(path.join(dir, `${u.id}.fail`), u.fails.map(([ts, t]) => `FAIL ${u.id} ${ts}\n${t}\n`).join('\n'));
    }
    if (u.issue) stub[u.id] = { createdAt: u.issue[0], body: `## Dispatch contract\n\n~~~markdown\n${u.issue[1]}\n~~~\n` };
  });
  const stubFile = path.join(dir, 'stub.json');
  fs.writeFileSync(stubFile, JSON.stringify(stub));
  const out = runWith(dir, dir, ['--until=2026-09-15T00:00:00Z', '--gate=G3'], { UO_GH_STUB: stubFile });
  fs.rmSync(dir, { recursive: true, force: true });
  return out;
}
function boundary(total, sevens) {
  const units = [];
  for (let i = 0; i < total; i++) {
    units.push({ id: `g3-${i}`, pass: '2026-09-05T10:00:00Z', fails: [], issue: ['2026-09-02T09:00:00Z', i < sevens ? ALL_PASS : MINUS_R1] });
  }
  return g3Set(units);
}
check('g3 open at 60/20', () => { assert.ok(/^G3 open\n/.test(boundary(60, 20))); });
check('g3 closed at 59/20', () => { assert.ok(/^G3 closed: /.test(boundary(59, 20))); });
check('g3 closed at 60/19', () => { assert.ok(/^G3 closed: /.test(boundary(60, 19))); });
const MIX = g3Set([
  { id: 'g3-rub', pass: '2026-09-04T10:00:00Z', fails: [['2026-09-03T10:00:00Z', 'The assertion was vacuous.']], issue: ['2026-09-02T09:00:00Z', ALL_PASS] },
  { id: 'g3-ver', pass: '2026-09-04T10:00:00Z', fails: [['2026-09-03T10:00:00Z', 'The changelog entry is missing.']], issue: null },
  { id: 'g3-scp', pass: '2026-09-04T10:00:00Z', fails: [['2026-09-03T10:00:00Z', 'The edit was out of scope.']], issue: ['2026-08-30T09:00:00Z', ALL_PASS] },
  { id: 'g3-host', pass: '2026-08-10T10:00:00Z', fails: [['2026-08-09T10:00:00Z', 'A precondition was not met.']], issue: null },
]);
check('g3 rubric classes only vacuous', () => {
  assert.ok(MIX.split('\n').includes('rubric_classes=vacuous=1'), MIX);
});
check('g3 pre-rubric classes version+scope', () => {
  assert.ok(MIX.split('\n').includes('pre_rubric_classes=version=1,scope=1'), MIX);
});
check('g3 cutoffs unmeasured', () => {
  assert.ok(MIX.includes('task_master_cutoffs=unmeasured'), MIX);
});
check('era before 08-02 sonnet', () => {
  assert.deepStrictEqual(R['fx-era-1'].implementer_tiers, [{ tier: 'sonnet', source: 'era-inferred' }]);
});
check('era 08-02 to 08-25 haiku', () => {
  assert.deepStrictEqual(R['fx-era-2'].implementer_tiers, [{ tier: 'haiku', source: 'era-inferred' }]);
});
check('era from 08-25 sonnet', () => {
  assert.deepStrictEqual(R['fx-era-3'].implementer_tiers, [{ tier: 'sonnet', source: 'era-inferred' }]);
});
check('era from the haiku-default cutover haiku', () => {
  const later = rows(scratch.dir, '2027-01-01T00:00:00Z').map;
  assert.deepStrictEqual(later['fx-era-4'].implementer_tiers, [{ tier: 'haiku', source: 'era-inferred' }]);
  assert.deepStrictEqual(later['fx-era-3'].implementer_tiers, [{ tier: 'sonnet', source: 'era-inferred' }]);
});

check('era null cutover falls back to the pre-haiku eras', () => {
  for (const withOrchestrator of [true, false]) {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'unit-outcomes-nocutover-'));
    try {
      fs.mkdirSync(path.join(tmp, 'scripts'));
      fs.copyFileSync(SCRIPT, path.join(tmp, 'scripts', 'unit-outcomes.js'));
      if (withOrchestrator) {
        fs.mkdirSync(path.join(tmp, 'agents'));
        fs.writeFileSync(path.join(tmp, 'agents', 'orchestrator.md'), '# orchestrator\nno cutover line here\n');
      }
      const out = cp.execFileSync('node', [
        path.join(tmp, 'scripts', 'unit-outcomes.js'),
        `--repo=${scratch.dir}`,
        `--markers=${path.join(FIX, 'markers')}`,
        `--transcripts=${path.join(FIX, 'transcripts')}`,
        '--until=2027-01-01T00:00:00Z',
      ], { cwd: REPO_ROOT, encoding: 'utf8', env: { ...process.env, GH_BIN: path.join(FIX, 'bin', 'gh') } });
      const map = {};
      out.split('\n').filter(Boolean).forEach((l) => { const o = JSON.parse(l); map[o.id] = o; });
      assert.deepStrictEqual(map['fx-era-4'].implementer_tiers, [{ tier: 'sonnet', source: 'era-inferred' }]);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  }
});

check('era reviewer empty', () => {
  assert.deepStrictEqual(R['fx-era-1'].reviewer_tiers, []);
});

// --- H7 (rgh-h7): exporter strictness and rubric_version ---
function cli(args) {
  return cp.spawnSync('node', [SCRIPT, ...args], { cwd: REPO_ROOT, encoding: 'utf8', timeout: 5000 });
}
check('strict help exits 0 with usage', () => {
  const r = cli(['--help']);
  assert.strictEqual(r.status, 0);
  assert.ok(r.stdout.startsWith('usage:'), r.stdout);
});
check('strict unknown flag exits 2', () => {
  const r = cli(['--bogus']);
  assert.strictEqual(r.status, 2);
  assert.ok(r.stderr.includes('unknown flag: --bogus'), r.stderr);
});
// A private copy of the gh stub, so its issues/ dir can hold synthetic answers without touching FIX.
function stubDir(issues) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'uo-h7-'));
  fs.mkdirSync(path.join(dir, 'bin'));
  fs.mkdirSync(path.join(dir, 'issues'));
  fs.copyFileSync(path.join(FIX, 'bin', 'gh'), path.join(dir, 'bin', 'gh'));
  fs.chmodSync(path.join(dir, 'bin', 'gh'), 0o755);
  for (const [id, list] of Object.entries(issues)) fs.writeFileSync(path.join(dir, 'issues', `${id}.json`), JSON.stringify(list));
  return dir;
}
check('strict gh stub limit', () => {
  const dir = stubDir({ 'h7-lim': [{ number: 1, title: 'a' }, { number: 2, title: 'b' }] });
  try {
    const out = cp.execFileSync(path.join(dir, 'bin', 'gh'), ['issue', 'list', '--search', 'h7-lim in:title', '--limit', '1'], { encoding: 'utf8' });
    assert.strictEqual(JSON.parse(out).length, 1);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
check('strict unit first line', () => {
  const dir = stubDir({ 'h7-unit': [{ number: 7, title: 'other title', labels: [], createdAt: '2026-09-02T09:00:00Z',
    body: '## Dispatch contract\n\n~~~markdown\nnote line\nUnit: h7-unit\n~~~\n' }] });
  try {
    fs.writeFileSync(path.join(dir, 'h7-unit.pass'), 'PASS h7-unit 2026-09-05T10:00:00Z commit: none criteria: fixture\n');
    const out = cp.execFileSync('node', [SCRIPT, `--repo=${dir}`, `--markers=${dir}`, `--transcripts=${path.join(dir, 'none')}`, '--until=2026-09-15T00:00:00Z'],
      { cwd: REPO_ROOT, encoding: 'utf8', env: { ...process.env, GH_BIN: path.join(dir, 'bin', 'gh') } });
    assert.strictEqual(JSON.parse(out.trim()).contract_source, 'none');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
// units: {id, pass, issue: createdAt | null}; returns id -> row.
function rvSet(units) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'uo-rv-'));
  const stub = {};
  units.forEach((u) => {
    fs.writeFileSync(path.join(dir, `${u.id}.pass`), `PASS ${u.id} ${u.pass} commit: none criteria: fixture\n`);
    if (u.issue) stub[u.id] = { createdAt: u.issue, body: `## Dispatch contract\n\n~~~markdown\n${ALL_PASS}\n~~~\n` };
  });
  const stubFile = path.join(dir, 'stub.json');
  fs.writeFileSync(stubFile, JSON.stringify(stub));
  let out;
  try {
    out = runWith(dir, dir, ['--until=2026-09-15T00:00:00Z'], { UO_GH_STUB: stubFile });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
  const map = {};
  out.split('\n').filter(Boolean).forEach((l) => { const o = JSON.parse(l); map[o.id] = o; });
  return map;
}
const RV_NO_H2 = rvSet([{ id: 'rv-null', pass: '2026-09-04T10:00:00Z', issue: null },
  { id: 'rv-early', pass: '2026-09-04T10:00:00Z', issue: '2026-09-08T09:00:00Z' }]);
const RV_H2 = rvSet([{ id: 'rgh-h2', pass: '2026-09-05T10:00:00Z', issue: null },
  { id: 'rv-before', pass: '2026-09-06T10:00:00Z', issue: '2026-09-03T09:00:00Z' },
  { id: 'rv-after', pass: '2026-09-09T10:00:00Z', issue: '2026-09-07T09:00:00Z' }]);
check('rubric_version null without contract_ts', () => { assert.strictEqual(RV_NO_H2['rv-null'].rubric_version, null); });
check('rubric_version v1 without rgh-h2 PASS', () => { assert.strictEqual(RV_NO_H2['rv-early'].rubric_version, 'v1'); });
check('rubric_version v1 before rgh-h2 PASS', () => { assert.strictEqual(RV_H2['rv-before'].rubric_version, 'v1'); });
check('rubric_version v2 after rgh-h2 PASS', () => { assert.strictEqual(RV_H2['rv-after'].rubric_version, 'v2'); });


// --- H11 (rgh-h11): G3 scores each rubric-era unit under its own rubric_version ---
const V2_ALL_PASS = fs.readFileSync(path.join(REPO_ROOT, 'tests', 'fixtures', 'contract-score', 'v2-all-pass.md'), 'utf8');
const H2_PASS = { id: 'rgh-h2', pass: '2026-09-03T00:00:00Z', issue: null };
// v2-format contracts hold `~~~` payload fences, so the issue body wraps them in a five-tilde fence.
const wrap5 = (text) => `## Dispatch contract\n\n~~~~~markdown\n${text}\n~~~~~\n`;
// units: {id, issue: [createdAt, text] | null}; every unit PASSes at 2026-09-05 unless `pass` is given.
function g3v2Run(units, extra) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'uo-g3v2-'));
  const stub = {};
  [{ id: 'rgh-u3-4', pass: U34_PASS, issue: null }, ...units].forEach((u) => {
    fs.writeFileSync(path.join(dir, `${u.id}.pass`), `PASS ${u.id} ${u.pass || '2026-09-05T10:00:00Z'} commit: none criteria: fixture\n`);
    if (u.issue) stub[u.id] = { createdAt: u.issue[0], body: wrap5(u.issue[1]) };
  });
  const stubFile = path.join(dir, 'stub.json');
  fs.writeFileSync(stubFile, JSON.stringify(stub));
  const out = runWith(dir, dir, ['--until=2026-09-15T00:00:00Z', ...extra], { UO_GH_STUB: stubFile });
  fs.rmSync(dir, { recursive: true, force: true });
  return out;
}
// 60 rubric-era units: 10 "a" (contract before rgh-h2's PASS), 10 "b" (after it, v2-format), 40 "c" below 7.
function g3v2Set(withH2, aText) {
  const units = withH2 ? [H2_PASS] : [];
  for (let i = 0; i < 10; i++) units.push({ id: `g3v2-a${i}`, issue: ['2026-09-02T09:00:00Z', aText] });
  for (let i = 0; i < 10; i++) units.push({ id: `g3v2-b${i}`, issue: ['2026-09-04T09:00:00Z', V2_ALL_PASS] });
  for (let i = 0; i < 40; i++) units.push({ id: `g3v2-c${i}`, issue: ['2026-09-02T09:00:00Z', MINUS_R1] });
  return g3v2Run(units, ['--gate=G3']);
}
check('g3v2 field', () => {
  const out = g3v2Run([{ id: 'g3v2-f1', issue: ['2026-09-02T09:00:00Z', V2_ALL_PASS] }, { id: 'g3v2-f2', issue: null }], []);
  const byId = {};
  out.split('\n').filter(Boolean).forEach((l) => { const o = JSON.parse(l); byId[o.id] = o; });
  assert.strictEqual(byId['g3v2-f1'].contract_score, 6);
  assert.strictEqual(byId['g3v2-f1'].contract_score_v2, 7);
  assert.strictEqual(byId['g3v2-f2'].contract_score, null);
  assert.strictEqual(byId['g3v2-f2'].contract_score_v2, null);
});
check('g3v2 v2-counts', () => {
  const out = g3v2Set(true, ALL_PASS);
  assert.ok(/^G3 open\n/.test(out), out);
  assert.ok(out.includes(' scored7=20 '), out);
});
check('g3v2 v1-not-v2', () => {
  const out = g3v2Set(true, V2_ALL_PASS);
  assert.ok(/^G3 closed: /.test(out), out);
  assert.ok(out.includes(' scored7=10 '), out);
});
check('g3v2 v2-not-v1', () => {
  const out = g3v2Set(false, ALL_PASS);
  assert.ok(out.includes(' scored7=10 '), out);
});

// --- fc-1: rubric_version boundaries, the cutoff on rgh-h2's PASS, and an unparseable contract_ts ---
const RV_CUT = rvSet([{ id: 'rgh-h2', pass: '2026-09-20T10:00:00Z', issue: null },
  { id: 'rv-h2-after-cutoff', pass: '2026-09-12T10:00:00Z', issue: '2026-09-22T09:00:00Z' }]);
check('rv-h2-after-cutoff', () => { assert.strictEqual(RV_CUT['rv-h2-after-cutoff'].rubric_version, 'v1'); });
const RV_EQ = rvSet([{ id: 'rgh-h2', pass: '2026-09-05T10:00:00Z', issue: null },
  { id: 'rv-equal-boundary', pass: '2026-09-06T10:00:00Z', issue: '2026-09-05T10:00:00Z' }]);
check('rv-equal-boundary', () => { assert.strictEqual(RV_EQ['rv-equal-boundary'].rubric_version, 'v1'); });
check('rv-nan', () => {
  const units = [{ id: 'rgh-h2', pass: '2026-08-30T10:00:00Z', issue: null }, { id: 'rv-nan', issue: ['not-a-date', ALL_PASS] }];
  const row = JSON.parse(g3v2Run(units, []).split('\n').find((l) => l.startsWith('{"id":"rv-nan"')));
  assert.strictEqual(row.rubric_version, null);
  assert.ok(g3v2Run(units, ['--gate=G3']).includes(' rubric_era=0 '), 'rv-nan counted in rubric_era');
});

fs.utimesSync(mtimeFile, mtimeOrig, mtimeOrig);
fs.rmSync(scratch.dir, { recursive: true, force: true });

console.log(failures === 0 ? '\nAll unit-outcomes checks passed.' : `\n${failures} check(s) failed.`);
process.exit(failures === 0 ? 0 : 1);
