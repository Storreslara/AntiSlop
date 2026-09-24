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

function runCensus(dir) {
  const result = spawnSync('node', [SCRIPT, '--dir', dir, '--json'], { encoding: 'utf8' });
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

if (failures > 0) {
  console.error(`\n${failures} test(s) failed.`);
  process.exit(1);
}
console.log('\nAll bash-output-census tests passed.');
