#!/usr/bin/env node
'use strict';

// Regression coverage for 2.2/2.6 of the 2026-08-13 persona-efficiency-audit
// spec (#348): selectProtocolSections() drops protocol sections per-persona
// without checking whether the surviving rendered text still references them
// by name. Three checks: (C2.1) a rendered mirror mentioning "WIP sentinel"
// always also carries the sentinel's file path; (C2.2) a rendered mirror
// never carries a bare "Third verdict"/"Fourth verdict" backward reference
// without the matching header; (C2.3) the build-time guard
// (assertNoDanglingCrossReferences) rejects a synthetic matrix row
// reproducing that dangle shape.

const assert = require('assert');
const fs = require('fs');
const path = require('path');

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

const MIRROR_DIR = path.join(REPO_ROOT, '.claude/agents');
const mirrors = fs.readdirSync(MIRROR_DIR).filter((f) => f.endsWith('.md'));

// C2.1 names exactly these five full-tier personas (all rendered from
// templates/persona-protocol.md via PROTOCOL_SECTIONS_BY_PERSONA). Slim-tier
// personas (agent-auditor, explorer, scribe, researcher) render from the
// SEPARATE templates/persona-protocol-slim.md, which is out of scope for
// this spec step — not in its "Affected files" list — and is left for a
// separate pass even though it carries a same-shaped WIP-sentinel dangle.
const C2_1_MIRRORS = ['reviewer.md', 'spec-master.md', 'task-master.md', 'milestone-auditor.md', 'lead-programmer.md'];

check('C2.1: every named mirror mentioning "WIP sentinel" also mentions "wip-handoff"', () => {
  for (const f of C2_1_MIRRORS) {
    const text = fs.readFileSync(path.join(MIRROR_DIR, f), 'utf8');
    if (text.includes('WIP sentinel')) {
      assert.ok(text.includes('wip-handoff'), `${f} mentions "WIP sentinel" but never "wip-handoff" — a dangling reference to a dropped section`);
    }
  }
});

check('C2.2: no mirror carries a bare "Third verdict"/"Fourth verdict" backward reference', () => {
  for (const f of mirrors) {
    const text = fs.readFileSync(path.join(MIRROR_DIR, f), 'utf8');
    for (const label of ['Third verdict', 'Fourth verdict']) {
      if (text.includes(`"${label}" below`)) {
        assert.ok(
          new RegExp(`^## ${label}`, 'm').test(text),
          `${f} contains "${label}" below" but has no "## ${label}" header — dangling reference`,
        );
      }
    }
  }
});

check('C2.3: the guard rejects a synthetic row reproducing the WIP-sentinel dangle shape', () => {
  const sections = [
    { header: 'WIP sentinel (mid-task handoff, not a bypass)', text: 'write your reason into the sentinel file.' },
    { header: 'Blocked by a gate you do not own', text: 'report and wait, or use the WIP sentinel described above.' },
  ];
  const matrix = {
    synthetic: {
      include: ['Blocked by a gate you do not own'],
      drop: ['WIP sentinel (mid-task handoff, not a bypass)'],
    },
  };
  assert.throws(
    () => cli.assertNoDanglingCrossReferences(sections, matrix),
    /keeps "Blocked by a gate you do not own".*references "WIP sentinel/,
    'a kept section referencing a dropped section by name must throw',
  );
});

check('C2.3: the guard PASSES once the reference is made self-contained', () => {
  const sections = [
    { header: 'WIP sentinel (mid-task handoff, not a bypass)', text: 'write your reason into the sentinel file.' },
    { header: 'Blocked by a gate you do not own', text: 'report and wait, or write a non-empty reason to `.claude/wip-handoff.<agent-id>`.' },
  ];
  const matrix = {
    synthetic: {
      include: ['Blocked by a gate you do not own'],
      drop: ['WIP sentinel (mid-task handoff, not a bypass)'],
    },
  };
  assert.doesNotThrow(() => cli.assertNoDanglingCrossReferences(sections, matrix));
});

check('C2.3: the guard does not flag a row that keeps BOTH the referencing and referenced sections', () => {
  const sections = [
    { header: 'WIP sentinel (mid-task handoff, not a bypass)', text: 'write your reason into the sentinel file.' },
    { header: 'Blocked by a gate you do not own', text: 'report and wait, or use the WIP sentinel described above.' },
  ];
  const matrix = {
    synthetic: {
      include: ['WIP sentinel (mid-task handoff, not a bypass)', 'Blocked by a gate you do not own'],
      drop: [],
    },
  };
  assert.doesNotThrow(() => cli.assertNoDanglingCrossReferences(sections, matrix));
});

check('C2.3 non-vacuity: PROTOCOL_SECTIONS_BY_PERSONA itself passes the guard (bin/cli.js loaded without throwing above)', () => {
  // require() at the top of this file already ran assertNoDanglingCrossReferences
  // against the real template + matrix at module load — if that had thrown,
  // this whole test file would never have reached this point.
  assert.ok(cli.PROTOCOL_SECTIONS_BY_PERSONA['lead-programmer'], 'sanity: the real matrix is reachable from the loaded module');
});

if (failures) {
  console.log(`\n${failures} protocol-cross-references check(s) FAILED.`);
  process.exit(1);
}
console.log('\nAll protocol-cross-references checks passed.');
