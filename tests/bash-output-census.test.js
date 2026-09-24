#!/usr/bin/env node
'use strict';

// Deterministic fixture-based test for scripts/bash-output-census.js. Never
// touches the operator's live transcript store — only the fixtures under
// tests/fixtures/bash-output-census/.

const assert = require('assert');
const path = require('path');
const { spawnSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');
const SCRIPT = path.join(REPO_ROOT, 'scripts', 'bash-output-census.js');
const FIXTURES = path.join(REPO_ROOT, 'tests', 'fixtures', 'bash-output-census');
const { percentile } = require(SCRIPT);
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

function runScript(argv, opts) {
  return spawnSync('node', [SCRIPT, ...argv], { encoding: 'utf8', ...opts });
}

function runCensus(dir) {
  const result = runScript(['--dir', dir, '--json']);
  assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stderr}`);
  return JSON.parse(result.stdout);
}

check('reports hand-computed percentiles for the mixed-shape fixture', () => {
  // Fixture Bash tool_result lengths: 10 ("AAAAAAAAAA"), 20 (two text
  // blocks, 12+8), 30 ("C"x30), 40 ("D"x40). The non-Bash Read pair is
  // excluded. Sorted: [10, 20, 30, 40].
  const out = runCensus(path.join(FIXTURES, '-home-fake-project'));
  assert.strictEqual(out.count, 4);
  assert.strictEqual(out.totalChars, 100);
  assert.strictEqual(out.p50, 20);
  assert.strictEqual(out.p75, 30);
  assert.strictEqual(out.p90, 40);
  assert.strictEqual(out.p95, 40);
  assert.strictEqual(out.p99, 40);
  assert.strictEqual(out.max, 40);
  assert.ok(Array.isArray(out.caps), 'expected a caps array');
});

check('non-vacuity: a fixture with only a non-Bash tool_result yields count 0', () => {
  const out = runCensus(path.join(FIXTURES, 'only-non-bash'));
  assert.strictEqual(out.count, 0);
  assert.strictEqual(out.totalChars, 0);
});

check('counts Bash pairs in nested subdirectories, not just the top level', () => {
  // The real transcript store keeps most transcripts under
  // <session-uuid>/subagents/*.jsonl, so a top-level-only scan undercounts.
  // Fixture: session-1.jsonl at the top (10 chars) plus sub/session-2.jsonl
  // one level down (25 chars).
  const out = runCensus(path.join(FIXTURES, 'nested-sessions'));
  assert.strictEqual(out.count, 2, 'expected the nested file to be censused too');
  assert.strictEqual(out.totalChars, 35);
  assert.strictEqual(out.max, 25, 'expected the nested pair to set the max');
});

check('malformed lines and orphan tool_results leave the count untouched', () => {
  // Fixture holds one real Bash pair (10 chars), one tool_result whose
  // tool_use_id has no matching tool_use (20 chars), and two unparseable
  // lines. Only the real pair may be counted.
  const out = runCensus(path.join(FIXTURES, 'malformed-and-orphan'));
  assert.strictEqual(out.count, 1);
  assert.strictEqual(out.totalChars, 10);
});

check('a missing --dir path exits non-zero and names the path on stderr', () => {
  const result = runScript(['--dir', '/nonexistent/path/xyz', '--json']);
  assert.notStrictEqual(result.status, 0, 'expected a non-zero exit for a missing directory');
  assert.ok(
    result.stderr.includes('/nonexistent/path/xyz'),
    `expected the offending path on stderr, got: ${result.stderr}`
  );
  assert.ok(!result.stdout.includes('"count":0'), 'expected no all-zero JSON report on stdout');
});

check('--dir with no following value is rejected, not silently ignored', () => {
  const result = runScript(['--dir']);
  assert.notStrictEqual(result.status, 0, 'expected a non-zero exit when --dir has no value');
  assert.ok(/--dir/.test(result.stderr), `expected --dir named on stderr, got: ${result.stderr}`);
});

check('percentile() uses the nearest-rank convention', () => {
  // Independent of any fixture: nearest-rank picks the value at
  // ceil(p/100 * n), 1-indexed. For n=5 that is index 3 at p50 -> 30.
  const sorted = [10, 20, 30, 40, 50];
  assert.strictEqual(percentile(sorted, 50), 30);
  assert.strictEqual(percentile(sorted, 20), 10);
  assert.strictEqual(percentile(sorted, 90), 50);
  assert.strictEqual(percentile(sorted, 100), 50);
  assert.strictEqual(percentile([], 50), 0);
});

check('the default transcript dir is resolved from the git toplevel, not raw cwd', () => {
  const print = `process.stdout.write(require(${JSON.stringify(SCRIPT)}).defaultTranscriptDir())`;
  const fromRoot = spawnSync('node', ['-e', print], { encoding: 'utf8', cwd: REPO_ROOT });
  const fromSubdir = spawnSync('node', ['-e', print], {
    encoding: 'utf8',
    cwd: path.join(REPO_ROOT, 'scripts'),
  });
  assert.strictEqual(fromRoot.status, 0, fromRoot.stderr);
  assert.strictEqual(fromSubdir.status, 0, fromSubdir.stderr);
  assert.strictEqual(
    fromSubdir.stdout,
    fromRoot.stdout,
    'expected the same store dir regardless of cwd inside the repo'
  );
});

if (failures > 0) {
  console.error(`\n${failures} test(s) failed.`);
  process.exit(1);
}
console.log('\nAll bash-output-census tests passed.');
