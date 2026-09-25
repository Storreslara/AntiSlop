#!/usr/bin/env node
'use strict';

// Coverage for item18-1-add-config-field
// (docs/plans/2026-09-25-item18-default-implementer-model-config.md, Step 1):
// `defaultImplementerModel` as a persona-config.json field, with the
// precedence per-dispatch tag > config field > frontmatter default.

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

check('resolveDefaultImplementerModel: an unrecognised value resolves to opus (more capability, never less)', () => {
  assert.strictEqual(cli.resolveDefaultImplementerModel({ defaultImplementerModel: 'haiku' }, 'sonnet'), 'opus');
  assert.strictEqual(cli.resolveDefaultImplementerModel({ defaultImplementerModel: 'bogus-junk' }, 'sonnet'), 'opus');
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

console.log(failures === 0 ? '\nAll default-implementer-model checks passed.' : `\n${failures} check(s) failed.`);
process.exit(failures === 0 ? 0 : 1);
