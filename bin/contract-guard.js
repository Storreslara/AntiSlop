#!/usr/bin/env node
'use strict';

// Contract-score guard (csg-1). Before a unit is dispatched on `haiku`, the orchestrator runs this
// over the unit's contract of record. One stdout line; `contract-guard: haiku ` only when the one
// matching contract block scores every row true under --rubric=v2 (lead shape: and not sizeOver).
// Exit 0 with a decision, exit 2 on a usage or read error; the orchestrator treats any output
// other than a `contract-guard: haiku ` line, and any non-zero exit, as `sonnet`.
//
// Any argument other than one <path|-> and the --unit=<id> / --shape=<lead|scribe> flags is a usage
// error (exit 2, empty stdout), for example `--shape scribe` written with a space.
//
// A fenced block opens on a run of three or more backticks or tildes and closes only on a line that
// holds exactly the same run. A longer closing fence therefore leaves the block open, it is never
// returned, and the unit falls to `reason=no-contract`, which fails safe to sonnet.

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const FENCE = /^\s*(`{3,}|~{3,})/;
const SHAPE_HEADING = { lead: '## Ordered edits', scribe: '## Glossary edits' };
const UNIT_ID = /^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$/;

function usage(msg) {
  process.stderr.write(`${msg}\nusage: contract-guard.js <path|-> --unit=<id> [--shape=lead|scribe]\n`);
  process.exit(2);
}

// Top-level fenced blocks whose first interior line is exactly `Unit: <id>`; nested fences are
// interior lines. An unclosed block is never returned. A whole input whose line 1 is `Unit: <id>`
// is a block too.
function blocks(lines, id) {
  const out = [];
  let open = null;
  let start = -1;
  lines.forEach((l, i) => {
    if (open === null) {
      const m = FENCE.exec(l);
      if (m) { open = m[1]; start = i; }
    } else if (l.trim() === open) {
      if (lines[start + 1] === `Unit: ${id}`) out.push(lines.slice(start + 1, i));
      open = null;
    }
  });
  if (lines[0] === `Unit: ${id}`) out.push(lines);
  return out;
}

// `## ` headings outside the block's own nested fences.
function headings(block) {
  const hs = [];
  let open = null;
  for (const l of block) {
    if (open === null) {
      const m = FENCE.exec(l);
      if (m) open = m[1];
      else if (/^## /.test(l)) hs.push(l.trim());
    } else if (l.trim() === open) open = null;
  }
  return hs;
}

function main() {
  const args = process.argv.slice(2);
  const opt = (k) => {
    const a = args.find((x) => x.startsWith(`--${k}=`));
    return a ? a.slice(k.length + 3) : null;
  };
  const id = opt('unit');
  const shape = opt('shape') || 'lead';
  const rest = args.filter((a) => !/^--(unit|shape)=/.test(a));
  if (rest.length > 1) usage(`unexpected argument(s): ${rest.slice(1).join(' ')}`);
  const file = rest[0];
  if (!id || !UNIT_ID.test(id)) usage('bad or missing --unit');
  if (!Object.hasOwn(SHAPE_HEADING, shape)) usage('bad --shape');
  if (!file) usage('missing <path|->');
  let raw;
  try { raw = fs.readFileSync(file === '-' ? 0 : file, 'utf8'); } catch (e) { usage(`unreadable: ${e.message}`); }
  const lines = raw.replace(/\r\n/g, '\n').split('\n');
  const say = (tier, why) => process.stdout.write(`contract-guard: ${tier} unit=${id} shape=${shape} ${why}\n`);
  const found = blocks(lines, id).filter((b) => headings(b).includes(SHAPE_HEADING[shape]));
  if (found.length === 0) return say('sonnet', 'reason=no-contract');
  if (found.length > 1) return say('sonnet', `reason=ambiguous-contract(${found.length})`);
  const r = spawnSync(process.execPath,
    [path.join(__dirname, 'contract-score.js'), '-', `--shape=${shape}`, '--rubric=v2'],
    { input: `${found[0].join('\n')}\n`, encoding: 'utf8' });
  let j = null;
  try { j = JSON.parse(r.stdout); } catch (e) { j = null; }
  if (r.status !== 0 || !j || !j.rows) return say('sonnet', `reason=scorer-exit-${r.status}`);
  const rows = Object.keys(j.rows);
  const failed = rows.filter((k) => j.rows[k] !== true);
  const score = `score=${rows.length - failed.length}/${rows.length}`;
  if (failed.length > 0) return say('sonnet', `${score} failed=${failed.join(',')}`);
  if (shape === 'lead' && j.sizeOver !== false) return say('sonnet', `${score} reason=sizeOver`);
  return say('haiku', score);
}

main();
