#!/usr/bin/env node
'use strict';

// Section-level drift guard for the Codex/Cursor protocol ports. Those ports
// are DELIBERATELY hand-adapted condensed variants of
// templates/persona-protocol.md (reworded headers, platform-specific "loud
// degradation" notes, no memory primitive on Codex) — bin/cli.js copies them
// VERBATIM at scaffold time and does not generate them from the canonical
// template, so parity cannot be verified-by-construction. This is why the
// remediation is a drift test rather than construction-time marker injection:
// injecting the canonical text would clobber those intentional adaptations
// (see plan OQ12 / U15). The test fails CLOSED — every canonical top-level
// section must be either matched by a probe in each port OR listed as an
// explicit, documented deferred gap; a NEW canonical section with no table
// entry throws, forcing a present-or-deferred decision instead of silent
// divergence.

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const CANONICAL = path.join(REPO_ROOT, 'templates/persona-protocol.md');
const SLIM = path.join(REPO_ROOT, 'templates/persona-protocol-slim.md');
const CODEX_PORT = path.join(REPO_ROOT, 'adapters/codex/agents-md-fragment.md');
const CURSOR_PORT = path.join(REPO_ROOT, 'adapters/cursor/rules/persona-protocol.mdc');

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

// Canonical section list is DERIVED from the template, never hard-coded, so a
// section added to templates/persona-protocol.md is picked up automatically.
function canonicalHeaders() {
  return fs.readFileSync(CANONICAL, 'utf8')
    .split('\n')
    .filter((l) => l.startsWith('## '))
    .map((l) => l.slice(3).trim());
}

// Per-port parity map keyed by the EXACT canonical header. Each value is
// either { probe } (content that must appear in the port — a string, or an
// array when one section carries several load-bearing sub-artifacts) or
// { deferred } (an explicit, documented gap this port is allowed to omit). The
// deferred entries are the pre-existing broader drift spec-master surfaced —
// recorded here visibly, not silently fixed and not silently ignored.
//
// The escalate-to-human row probes the packet's human-facing artifacts by
// name, not just the header: gh299 (CHANGES.md) and examples-1 (EXAMPLES.md)
// both landed in these hand-adapted ports, and a header-only probe would pass
// on a port that had silently dropped either one.
const ESCALATION_PROBES = [
  'Fourth verdict: escalate-to-human',
  'Comprehension material only',   // CHANGES.md's byte-exact authority line (gh299)
  'EXAMPLES.md',                   // worked examples, examples-1
  'examples: reviewed',
  'examples: skipped',             // the non-gate token — omitting it builds a gate
  'examples: none-offered',
  'never graded by the reviewer',  // the R6 authority constraint, gh300
];

const codexMap = {
  'Structural questions go to the explorer': { probe: 'Structural questions go to the explorer' },
  'Answer shape': { probe: 'Answer shape' },
  'Scope Bash output before it enters context': { probe: 'Scope Bash output before it enters context' },
  'Agent-teams mode (only relevant if you were spawned as a teammate)': { deferred: 'agent-teams mode dropped for Codex v1 (no SendMessage/TaskCompleted) — see platform notes' },
  'Teammate Write/Edit fallback and gate rephrasing doctrine': { deferred: 'agent-teams mode dropped for Codex v1 (no SendMessage/TaskCompleted) — see platform notes' },
  'WIP sentinel (mid-task handoff, not a bypass)': { probe: 'WIP sentinel' },
  'Blocked by a gate you do not own (never self-authorize a bypass)': { probe: 'Blocked by a gate you do not own' },
  'Terminal status line (every dispatched turn)': { probe: 'STATUS: complete' },
  'Running acceptance-criteria commands (there is no self-wake)': { deferred: 'pre-existing broader drift, out of scope for U15 (roast backfill only) — candidate future port sweep' },
  'Retrieval contract': { probe: 'Retrieval contract' },
  'Machine-checkable criteria': { probe: 'Machine-checkable criteria' },
  'Review ownership — one unit, one review, single owner': { probe: 'Review ownership' },
  'Pending-review flag (default-mode review backstop)': { probe: 'Pending-review flag' },
  'FAIL record (durable warning for future spawns)': { probe: 'FAIL record' },
  'Third verdict: insufficient-context': { deferred: 'pre-existing broader drift, out of scope for U15 — candidate future port sweep' },
  'Fourth verdict: escalate-to-human': { probe: ESCALATION_PROBES },
  'Continuing after a FAIL verdict': { probe: 'Continuing after a FAIL verdict' },
  'A note on `memory`': { deferred: 'Codex has no per-agent memory primitive (file convention only) — see platform notes' },
  'Microworld bundles (format and the check contract)': { probe: 'Microworld bundles' },
};

const cursorMap = {
  'Structural questions go to the explorer': { probe: 'Structural questions go to the explorer' },
  'Answer shape': { probe: 'Answer shape' },
  'Scope Bash output before it enters context': { probe: 'Scope Bash output before it enters context' },
  'Agent-teams mode (only relevant if you were spawned as a teammate)': { deferred: 'agent-teams mode dropped for Cursor v1 — see platform notes' },
  'Teammate Write/Edit fallback and gate rephrasing doctrine': { deferred: 'agent-teams mode dropped for Cursor v1 — see platform notes' },
  'WIP sentinel (mid-task handoff, not a bypass)': { probe: 'WIP sentinel' },
  'Blocked by a gate you do not own (never self-authorize a bypass)': { probe: 'Blocked by a gate you do not own' },
  'Terminal status line (every dispatched turn)': { probe: 'STATUS: complete' },
  'Running acceptance-criteria commands (there is no self-wake)': { deferred: 'pre-existing broader drift, out of scope for U15 (roast backfill only) — candidate future port sweep' },
  'Retrieval contract': { probe: 'Retrieval contract' },
  'Machine-checkable criteria': { probe: 'Machine-checkable criteria' },
  'Review ownership — one unit, one review, single owner': { probe: 'Review ownership' },
  'Pending-review flag (default-mode review backstop)': { probe: 'Pending-review flag' },
  'FAIL record (durable warning for future spawns)': { probe: 'FAIL record' },
  'Third verdict: insufficient-context': { deferred: 'pre-existing broader drift, out of scope for U15 — candidate future port sweep' },
  'Fourth verdict: escalate-to-human': { probe: ESCALATION_PROBES },
  'Continuing after a FAIL verdict': { probe: 'Continuing after a FAIL verdict' },
  'A note on `memory`': { deferred: 'Cursor has no per-agent memory primitive (file convention only) — see platform notes' },
  'Microworld bundles (format and the check contract)': { probe: 'Microworld bundles' },
};

// Throws on any drift: an unmapped canonical section, a stale map key, or a
// present-probe whose content is absent from the port. This is the fail-closed
// core the negative cases below exercise directly.
function checkPort(headers, portText, portMap, portName) {
  const canonSet = new Set(headers);
  const mapKeys = new Set(Object.keys(portMap));
  for (const h of canonSet) {
    assert.ok(mapKeys.has(h), `${portName}: canonical section "${h}" has no parity-map entry — drift, decide present or deferred`);
  }
  for (const k of mapKeys) {
    assert.ok(canonSet.has(k), `${portName}: parity-map key "${k}" is not a current canonical section — stale entry`);
  }
  for (const [header, rule] of Object.entries(portMap)) {
    if (rule.probe) {
      for (const probe of [].concat(rule.probe)) {
        assert.ok(portText.includes(probe), `${portName}: section "${header}" expected present (probe ${JSON.stringify(probe)}) but missing`);
      }
    } else if (!rule.deferred) {
      throw new Error(`${portName}: map entry for "${header}" must set probe or deferred`);
    }
  }
}

check('Codex port: every canonical section is present or explicitly deferred', () => {
  checkPort(canonicalHeaders(), fs.readFileSync(CODEX_PORT, 'utf8'), codexMap, 'codex');
});

check('Cursor port: every canonical section is present or explicitly deferred', () => {
  checkPort(canonicalHeaders(), fs.readFileSync(CURSOR_PORT, 'utf8'), cursorMap, 'cursor');
});

// The slim tier is not a port, but it IS the other half of the fan-out: four
// personas receive persona-protocol-slim.md instead of the canonical file, so a
// section that lands only in the canonical one silently exempts them. Nothing
// else in the repo reads the slim file's section list.
check('slim tier carries the terminal status line section', () => {
  const slim = fs.readFileSync(SLIM, 'utf8');
  assert.ok(slim.includes('\n## Terminal status line (every dispatched turn)\n'),
    'templates/persona-protocol-slim.md is missing the exact terminal status line heading');
  assert.ok(slim.includes('STATUS: complete'),
    'templates/persona-protocol-slim.md is missing the STATUS: complete grammar');
});

check('negative case: an UNMAPPED new canonical section is REJECTED (fail-closed on drift)', () => {
  const withExtra = canonicalHeaders().concat('Some brand-new canonical section');
  assert.throws(
    () => checkPort(withExtra, 'irrelevant port text', codexMap, 'codex'),
    /no parity-map entry/,
    'an unmapped canonical section must throw, not silently pass');
});

check('negative case: a present-probe absent from the port is REJECTED (not a silent pass)', () => {
  assert.throws(
    () => checkPort(canonicalHeaders(), '', codexMap, 'codex'),
    /expected present.*but missing/,
    'a probe whose content is missing from the port must throw');
});

if (failures) {
  console.log(`\n${failures} adapter-protocol-parity check(s) FAILED.`);
  process.exit(1);
}
console.log('\nAll adapter-protocol-parity checks passed.');
