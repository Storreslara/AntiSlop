#!/usr/bin/env node
'use strict';

// Verifies .claude/persona-config.json's fileHashes baselines agree with
// each managed mirror's actual on-disk, stamp-stripped content hash. See
// docs/plans/2026-08-26-debug-spec2-unite-stale-hash-baselines.md — a stale
// baseline (content correct, hash not) is a distinct defect from mirror
// content drift, which tests/validate.sh's content-parity check already
// guards separately.

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const { sha256Hex, stripStamp } = require(path.join(REPO_ROOT, 'bin', 'cli.js'));

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

// Core check: for each [relPath, recordedHash] in fileHashes, compares
// sha256Hex(stripStamp(<file contents>)) against recordedHash, resolving
// relPath against baseDir. Read-only; never touches baseDir's fileHashes.
function checkFileHashes(fileHashes, baseDir) {
  const mismatches = [];
  const missing = [];
  let examined = 0;
  for (const [relPath, recordedHash] of Object.entries(fileHashes)) {
    examined++;
    const abs = path.join(baseDir, relPath);
    if (!fs.existsSync(abs)) {
      missing.push(relPath);
      continue;
    }
    const actual = sha256Hex(stripStamp(fs.readFileSync(abs, 'utf8')));
    if (actual !== recordedHash) {
      mismatches.push({ relPath, recorded: recordedHash, actual });
    }
  }
  return { examined, mismatches, missing };
}

function withTempDir(fn) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'filehashes-currency-selftest-'));
  try {
    fn(dir);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

// --- AC-F3 part 2: both-kinds self-test, on a temp fixture, never on the
// real persona-config.json --------------------------------------------------

check('self-test: fires on a corrupted baseline for a raw artifact', () => {
  withTempDir((dir) => {
    const rel = 'raw.sh';
    fs.writeFileSync(path.join(dir, rel), '#!/bin/sh\necho hi\n');
    const result = checkFileHashes({ [rel]: 'deadbeef'.repeat(8) }, dir);
    assert.strictEqual(result.mismatches.length, 1, 'expected exactly one mismatch');
    assert.strictEqual(result.mismatches[0].relPath, rel);
  });
});

check('self-test: fires on a corrupted baseline for a stamped artifact, via the stripped hash', () => {
  withTempDir((dir) => {
    const rel = 'stamped.md';
    const body = '<!-- antislop v9.9.9 | source: agents/x.md | ADAPT-substituted -->\nHello.\n';
    fs.writeFileSync(path.join(dir, rel), body);
    const goodResult = checkFileHashes({ [rel]: sha256Hex(stripStamp(body)) }, dir);
    assert.strictEqual(goodResult.mismatches.length, 0, 'a correct stripped-hash baseline must not mismatch');
    const badResult = checkFileHashes({ [rel]: 'deadbeef'.repeat(8) }, dir);
    assert.strictEqual(badResult.mismatches.length, 1, 'expected exactly one mismatch');
  });
});

check('self-test: a missing file is reported as a failure, not silently skipped', () => {
  withTempDir((dir) => {
    const result = checkFileHashes({ 'does-not-exist.sh': 'deadbeef'.repeat(8) }, dir);
    assert.strictEqual(result.missing.length, 1);
    assert.strictEqual(result.mismatches.length, 0);
  });
});

// --- The real check, against this repo's actual persona-config.json -------

const configPath = path.join(REPO_ROOT, '.claude', 'persona-config.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const fileHashes = config.fileHashes || {};
const keyCount = Object.keys(fileHashes).length;

check(`covers all ${keyCount} fileHashes entries (no path-prefix filter)`, () => {
  const { examined } = checkFileHashes(fileHashes, REPO_ROOT);
  assert.strictEqual(examined, keyCount);
});

check("every fileHashes entry matches its file's stamp-stripped content hash", () => {
  const { mismatches, missing } = checkFileHashes(fileHashes, REPO_ROOT);
  for (const relPath of missing) {
    console.log(`MISSING ${relPath} (recorded in fileHashes but no file on disk)`);
  }
  for (const m of mismatches) {
    console.log(`MISMATCH ${m.relPath}  recorded=${m.recorded}  actual=${m.actual}`);
  }
  if (mismatches.length > 0 || missing.length > 0) {
    throw new Error(
      `${mismatches.length} mismatch(es), ${missing.length} missing file(s). ` +
      'Run `node bin/cli.js --update --force-render` and commit the resulting ' +
      '.claude/persona-config.json — never hand-edit fileHashes (constitution §2).'
    );
  }
});

console.log(`\n${keyCount} fileHashes entries examined.`);

if (failures > 0) {
  console.error(`\n${failures} test(s) failed.`);
  process.exit(1);
}
console.log('\nAll filehashes-currency tests passed.');
