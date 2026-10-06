#!/usr/bin/env node
'use strict';

const fs = require('fs');

const POINTER = /as specified|see the (plan|issue|spec)|to reflect|as appropriate|as needed|update accordingly/i;
const INLINE = /^`[^`]+`/;
const INT = /^\d+\b/;
const SEMVER = /\d+\.\d+\.\d+/;

function section(text, name) {
  const lines = text.split('\n');
  const start = lines.findIndex((l) => new RegExp(`^## ${name}\\b`).test(l));
  if (start < 0) return null;
  let end = lines.findIndex((l, i) => i > start && /^## /.test(l));
  if (end < 0) end = lines.length;
  return lines.slice(start + 1, end);
}

// Items start at `^\d+\. `; each maps field name -> {value, fenced}.
function items(lines) {
  const out = [];
  let cur = null;
  let inFence = false;
  lines.forEach((raw, i) => {
    if (/^\s*```/.test(raw)) { inFence = !inFence; return; }
    if (inFence) return;
    const start = /^\d+\. (.*)$/.exec(raw);
    if (start) { cur = {}; out.push(cur); }
    if (!cur) return;
    const m = /^(?:\d+\. )?\s*([a-z-]+):\s*(.*)$/.exec(raw);
    if (!m || m[1] in cur) return;
    const next = (lines[i + 1] || '').trim();
    cur[m[1]] = { value: m[2].trim(), fenced: m[2].trim() === '' && next.startsWith('```') };
  });
  return out;
}

const has = (it, k) => k in it;
const payload = (it, k) => has(it, k) && (it[k].fenced || INLINE.test(it[k].value));

function editItemOk(it) {
  if (has(it, 'command')) {
    return INLINE.test(it.command.value) && has(it, 'expect') && INT.test(it.expect.value);
  }
  if (!has(it, 'file') || !INLINE.test(it.file.value)) return false;
  if (!has(it, 'anchor') || it.anchor.value === '') return false;
  if (has(it, 'before') || has(it, 'after')) return payload(it, 'before') && payload(it, 'after');
  return payload(it, 'insert-after') || payload(it, 'delete');
}

function critItemOk(it) {
  return has(it, 'run') && INLINE.test(it.run.value)
    && has(it, 'exit') && INT.test(it.exit.value)
    && has(it, 'stdout') && it.stdout.value !== ''
    && has(it, 'mutation') && it.mutation.value !== '';
}

function r1(text) {
  const sec = section(text, 'Ordered edits');
  if (!sec || POINTER.test(sec.join('\n'))) return false;
  const its = items(sec);
  return its.length > 0 && its.every(editItemOk);
}

function r2(text) {
  const aff = section(text, 'Affected files') || [];
  if (!aff.some((l) => /`(agents\/[^/`]+\.md|templates\/[^`]*)`/.test(l))) return true;
  const lines = text.split('\n');
  const semverLine = (p) => lines.some((l) => l.includes(p) && SEMVER.test(l));
  const crit = items(section(text, 'Acceptance criteria') || []);
  const changelog = items(section(text, 'Ordered edits') || [])
    .some((it) => has(it, 'file') && it.file.value.includes('CHANGELOG.md')
      && (payload(it, 'insert-after') || payload(it, 'after')));
  return semverLine('.claude-plugin/plugin.json') && semverLine('package.json')
    && changelog && text.includes('node bin/cli.js --update')
    && crit.some((it) => has(it, 'run') && it.run.value.includes('version-stamp-check.sh'));
}

function r3(text) {
  const its = items(section(text, 'Acceptance criteria') || []);
  return its.length > 0 && its.every(critItemOk);
}

function r4(text) {
  const runs = [];
  let inFence = false;
  for (const l of text.split('\n')) {
    if (/^\s*```/.test(l)) { inFence = !inFence; continue; }
    const m = !inFence && /^(?:\d+\. )?\s*run:\s*(.*)$/.exec(l);
    if (m) runs.push(m[1]);
  }
  if (runs.some((r) => /\/home\/|\/tmp\/|~\/|\$HOME/.test(r))) return false;
  if (runs.some((r) => /command -v|which /.test(r))) return /^\s*(?:\d+\. )?precondition:/m.test(text);
  return true;
}

const ctxLine = (sec, key) => (sec || []).find((l) => l.startsWith(`${key}:`));

function r5(text) {
  const sec = section(text, 'Pre-resolved context');
  const tdd = ctxLine(sec, 'tdd');
  const blast = ctxLine(sec, 'blast-radius');
  return !!tdd && /^tdd:\s*(yes|no)\s+\S+/.test(tdd)
    && !!blast && (/[\w./-]+:\d+/.test(blast) || /^blast-radius:\s*none\s*$/.test(blast))
    && sec.some((l) => l.startsWith('commit-message:'));
}

function r6(text) {
  const sec = section(text, 'Do NOT touch') || [];
  return sec.filter((l) => /^\s*[-*] `[^`]+`/.test(l)).length >= 2;
}

function r7(text) {
  return (section(text, 'Pre-resolved context') || []).some((l) => /^diagnosis: none\s*$/.test(l));
}

function s1(text) {
  const sec = section(text, 'Glossary edits');
  if (!sec || sec.join('').trim() === '') return false;
  const its = items(sec);
  return its.length > 0 && its.every((it) => has(it, 'file') && has(it, 'heading') && has(it, 'text'));
}

function s2(text) {
  const body = (section(text, 'ADR') || []).join('\n');
  return /\b\d{4} \S/.test(body) || /^\s*`?none`?\s*$/m.test(body);
}

function s3(text) {
  const body = (section(text, 'Close conditions') || []).join('\n');
  return /#\d+/.test(body) && /\b[a-z][a-z0-9]*(-[a-z0-9]+)+\b/.test(body) && /"PASS [^"]+"/.test(body);
}

function s4(text) {
  return (section(text, 'Do NOT touch') || []).some((l) => l.trim() !== '');
}

function s5(text) {
  return r3(text);
}

// Mirrors the H2 fence counting in dispatch-hygiene.sh: lines opening with ``` toggle a block.
function maxBlockLines(text) {
  let inBlock = false;
  let interior = 0;
  let widest = 0;
  for (const line of text.split('\n')) {
    if (line.startsWith('```')) {
      if (inBlock) { inBlock = false; widest = Math.max(widest, interior); }
      else { inBlock = true; interior = 0; }
    } else if (inBlock) interior++;
  }
  return widest;
}

const SHAPES = {
  lead: { R1: r1, R2: r2, R3: r3, R4: r4, R5: r5, R6: r6, R7: r7 },
  scribe: { S1: s1, S2: s2, S3: s3, S4: s4, S5: s5 },
};

function main() {
  const args = process.argv.slice(2);
  const shapeArg = args.find((a) => a.startsWith('--shape='));
  const shape = shapeArg ? shapeArg.slice(8) : 'lead';
  const file = args.find((a) => !a.startsWith('--') || a === '-');
  if (!SHAPES[shape] || !file) { process.stderr.write('usage: contract-score.js <path|-> [--shape=lead|scribe]\n'); process.exit(2); }
  let buf;
  try { buf = fs.readFileSync(file === '-' ? 0 : file); } catch (e) { process.stderr.write(`unreadable: ${e.message}\n`); process.exit(2); }
  const text = buf.toString('utf8');
  const rows = {};
  for (const [k, fn] of Object.entries(SHAPES[shape])) rows[k] = fn(text);
  const lines = maxBlockLines(text);
  const out = {
    shape,
    score: Object.values(rows).filter(Boolean).length,
    rows,
    bytes: buf.length,
    maxBlockLines: lines,
    sizeOver: buf.length > 30000 || lines > 80,
  };
  process.stdout.write(`${JSON.stringify(out)}\n`);
}

main();
