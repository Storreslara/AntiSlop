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
  const bullets = sec.filter((l) => /^\s*[-*] /.test(l));
  return bullets.length >= 2 && bullets.every((l) => /^\s*[-*] `[^`]+`/.test(l));
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

// --- Rubric v2 (rgh-h1). v1 above is unchanged; v2 is selected with --rubric=v2. ---

// Fences: ``` or ~~~ runs of length >= 3, closed by a line holding exactly the same run.
function fenceFlags(lines) {
  const flags = [];
  let open = null;
  for (const l of lines) {
    const m = /^\s*(`{3,}|~{3,})/.exec(l);
    if (open === null) {
      if (m) { open = m[1]; flags.push('open'); } else flags.push(null);
    } else if (l.trim() === open) {
      open = null; flags.push('close');
    } else flags.push('in');
  }
  return flags;
}

const opensFence = (l) => /^\s*(`{3,}|~{3,})/.test(l);

function sectionV2(text, name) {
  const lines = text.split('\n');
  const flags = fenceFlags(lines);
  const head = (i, re) => flags[i] === null && re.test(lines[i]);
  const start = lines.findIndex((l, i) => head(i, new RegExp(`^## ${name}\\b`)));
  if (start < 0) return null;
  let end = lines.findIndex((l, i) => i > start && head(i, /^## /));
  if (end < 0) end = lines.length;
  return lines.slice(start + 1, end);
}

// Like items(), but fence-aware for both fence chars; a fenced field keeps its body lines.
function itemsV2(lines) {
  const flags = fenceFlags(lines);
  const out = [];
  let cur = null;
  let pending = null;
  lines.forEach((raw, i) => {
    if (flags[i] !== null) {
      if (pending && flags[i] === 'in') pending.body.push(raw);
      if (flags[i] === 'close') pending = null;
      return;
    }
    if (/^\d+\. /.test(raw)) { cur = {}; out.push(cur); }
    if (!cur) return;
    const m = /^(?:\d+\. )?\s*([a-z-]+):\s*(.*)$/.exec(raw);
    if (!m || m[1] in cur) return;
    const fenced = m[2].trim() === '' && opensFence(lines[i + 1] || '');
    cur[m[1]] = { value: m[2].trim(), fenced, body: [] };
    if (fenced) pending = cur[m[1]];
  });
  return out;
}

// H-C: blank or whitespace-only payload lines are exempt; every other line needs >= N spaces.
function indentOk(it) {
  const keys = ['before', 'after', 'insert-after', 'delete'].filter((k) => has(it, k) && it[k].fenced);
  if (keys.length === 0) return true;
  if (!has(it, 'indent') || !/^\d+$/.test(it.indent.value)) return false;
  const n = Number(it.indent.value);
  return keys.every((k) => it[k].body.every((l) => l.trim() === '' || /^ */.exec(l)[0].length >= n));
}

function editItemOkV2(it) {
  if (has(it, 'command')) {
    return INLINE.test(it.command.value) && has(it, 'expect') && INT.test(it.expect.value);
  }
  if (!has(it, 'file') || !INLINE.test(it.file.value)) return false;
  if (!has(it, 'anchor') || it.anchor.value === '') return false;
  const ok = (has(it, 'before') || has(it, 'after'))
    ? payload(it, 'before') && payload(it, 'after')
    : payload(it, 'insert-after') || payload(it, 'delete');
  return ok && indentOk(it);
}

// H-F: under v2 the pointer test reads instruction text only. Removed first: fenced lines (fences
// included), the backticked value of before:/after:/insert-after:/delete:, and the backticked
// literal of `anchor: line matching`. Text after a payload's closing backtick is still tested.
function instructionText(sec) {
  const flags = fenceFlags(sec);
  return sec.map((l, k) => (flags[k] !== null ? '' : l
    .replace(/^(\s*(?:\d+\. )?(?:before|after|insert-after|delete):\s*)`[^`]*`/, '$1')
    .replace(/^(\s*(?:\d+\. )?anchor:\s*line matching\s*)`[^`]*`/, '$1'))).join('\n');
}

function r1v2(text) {
  const sec = sectionV2(text, 'Ordered edits');
  if (!sec || POINTER.test(instructionText(sec))) return false;
  const its = itemsV2(sec);
  return its.length > 0 && its.every(editItemOkV2);
}

function r2v2(text) {
  const aff = sectionV2(text, 'Affected files') || [];
  if (!aff.some((l) => /`(agents\/[^/`]+\.md|templates\/[^`]*)`/.test(l))) return true;
  const lines = text.split('\n');
  const semverLine = (p) => lines.some((l) => l.includes(p) && SEMVER.test(l));
  const crit = itemsV2(sectionV2(text, 'Acceptance criteria') || []);
  const changelog = itemsV2(sectionV2(text, 'Ordered edits') || [])
    .some((it) => has(it, 'file') && it.file.value.includes('CHANGELOG.md')
      && (payload(it, 'insert-after') || payload(it, 'after')));
  return semverLine('.claude-plugin/plugin.json') && semverLine('package.json')
    && changelog && text.includes('node bin/cli.js --update')
    && crit.some((it) => has(it, 'run') && it.run.value.includes('version-stamp-check.sh'));
}

function r3v2(text) {
  const its = itemsV2(sectionV2(text, 'Acceptance criteria') || []);
  return its.length > 0 && its.every(critItemOk);
}

function r4v2(text) {
  const lines = text.split('\n');
  const flags = fenceFlags(lines);
  const runs = [];
  lines.forEach((l, i) => {
    const m = flags[i] === null && /^(?:\d+\. )?\s*run:\s*(.*)$/.exec(l);
    if (m) runs.push(m[1]);
  });
  if (runs.some((r) => /\/home\/|\/tmp\/|~\/|\$HOME/.test(r))) return false;
  if (runs.some((r) => /command -v|which /.test(r))) return /^\s*(?:\d+\. )?precondition:/m.test(text);
  return true;
}

// H-A: blanks and forbidden placeholders inside the review-packet block.
const BLANK = /<FILL:[^<>\n]*[^<>\s][^<>\n]*>/g;
const FORBIDDEN = /<FILL:\s*>|<(?!FILL:)[A-Za-z][^<>\n]*>|\b(?:TODO|TBD|FIXME|XXX)\b/;

function packetOk(sec) {
  const flags = fenceFlags(sec);
  const i = sec.findIndex((l, k) => flags[k] === null && /^\s*review-packet:\s*$/.test(l));
  if (i < 0 || flags[i + 1] !== 'open') return false;
  const body = [];
  let k = i + 2;
  for (; k < sec.length && flags[k] === 'in'; k++) body.push(sec[k]);
  if (flags[k] !== 'close') return false;
  const text = body.join('\n');
  const blanks = text.match(BLANK) || [];
  return blanks.length >= 1 && !FORBIDDEN.test(text.replace(BLANK, ''));
}

function r5v2(text) {
  const sec = sectionV2(text, 'Pre-resolved context');
  if (!sec) return false;
  const flags = fenceFlags(sec);
  const outside = sec.filter((l, k) => flags[k] === null).map((l) => l.trim());
  const key = (k) => outside.find((l) => l.startsWith(`${k}:`));
  const tdd = key('tdd');
  const blast = key('blast-radius');
  return !!tdd && /^tdd:\s*(yes|no)\s+\S+/.test(tdd)
    && !!blast && (/[\w./-]+:\d+/.test(blast) || /^blast-radius:\s*none\s*$/.test(blast))
    && outside.some((l) => l.startsWith('commit-message:'))
    && packetOk(sec);
}

function r6v2(text) {
  const sec = sectionV2(text, 'Do NOT touch') || [];
  const flags = fenceFlags(sec);
  const bullets = sec.filter((l, k) => flags[k] === null && /^ ?[-*+] /.test(l));
  return bullets.length >= 2 && bullets.every((l) => /^ ?[-*+] `[^`]*[/.][^`]*`/.test(l));
}

function r7v2(text) {
  return (sectionV2(text, 'Pre-resolved context') || []).some((l) => /^\s*diagnosis: none\s*$/.test(l));
}

// H-B: the v2 scribe skeleton, in this exact order.
const SCRIBE_HEADINGS = ['Objective', 'Retrieval', 'Glossary edits', 'Doc edits', 'ADR',
  'Close conditions', 'Do NOT touch', 'Acceptance criteria', 'Escalation'];
const nonEmpty = (sec) => (sec || []).filter((l) => l.trim() !== '');
const triple = (it) => has(it, 'file') && has(it, 'heading') && has(it, 'text');

function s1v2(text) {
  const sec = sectionV2(text, 'Glossary edits');
  const body = nonEmpty(sec);
  if (body.length === 1 && body[0].trim() === 'none') return true;
  const its = itemsV2(sec || []);
  return its.length > 0 && its.every(triple);
}

function s2v2(text) {
  const sec = sectionV2(text, 'ADR') || [];
  const body = nonEmpty(sec);
  if (body.length === 1 && body[0].trim() === 'none') return true;
  const flags = fenceFlags(sec);
  const outside = sec.map((l, k) => (flags[k] === null ? l.trim() : null)).filter((l) => l);
  const m = /^(\d{4}) \S/.exec(outside[0] || '');
  if (!m || !new RegExp(`^file: docs/adr/${m[1]}-\\S+\\.md$`).test(outside[1] || '')) return false;
  if (outside[2] !== 'body:' || !/^indent: \d+$/.test(outside[3] || '')) return false;
  const ind = sec.findIndex((l, k) => flags[k] === null && l.trim() === outside[3]);
  return flags[ind + 1] === 'open';
}

function s3v2(text) {
  const body = (sectionV2(text, 'Close conditions') || []).join('\n');
  const id = (/^Unit: (\S+)$/.exec(text.split('\n')[0]) || [])[1];
  return /#\d+/.test(body) && !!id && body.includes(id)
    && (body.includes(`"PASS ${id} "`) || body.includes('<PASS-VERDICT-LINE>'));
}

function s4v2(text) {
  return nonEmpty(sectionV2(text, 'Do NOT touch')).length > 0;
}

function s6v2(text) {
  const sec = sectionV2(text, 'Doc edits');
  const body = nonEmpty(sec);
  if (body.length === 0 || body[body.length - 1] !== 'prune: none') return false;
  const rest = body.slice(0, -1);
  if (rest.length === 1 && /^none [—-] make no other doc changes$/.test(rest[0])) return true;
  const its = itemsV2(sec.filter((l) => l !== 'prune: none'));
  return its.length > 0 && its.every(triple);
}

function s7v2(text) {
  const lines = text.split('\n');
  if (!/^Unit: \S+$/.test(lines[0])) return false;
  const flags = fenceFlags(lines);
  const heads = lines.filter((l, i) => flags[i] === null && /^## (.+)$/.test(l)).map((l) => l.slice(3));
  return heads.length === SCRIBE_HEADINGS.length && heads.every((h, i) => h === SCRIBE_HEADINGS[i]);
}

const SHAPES_V2 = {
  lead: { R1: r1v2, R2: r2v2, R3: r3v2, R4: r4v2, R5: r5v2, R6: r6v2, R7: r7v2 },
  scribe: { S1: s1v2, S2: s2v2, S3: s3v2, S4: s4v2, S5: r3v2, S6: s6v2, S7: s7v2 },
};

const SHAPES = {
  lead: { R1: r1, R2: r2, R3: r3, R4: r4, R5: r5, R6: r6, R7: r7 },
  scribe: { S1: s1, S2: s2, S3: s3, S4: s4, S5: s5 },
};

function main() {
  const args = process.argv.slice(2);
  const shapeArg = args.find((a) => a.startsWith('--shape='));
  const shape = shapeArg ? shapeArg.slice(8) : 'lead';
  const rubricArg = args.find((a) => a.startsWith('--rubric='));
  const rubric = rubricArg ? rubricArg.slice(9) : 'v1';
  const tables = { v1: SHAPES, v2: SHAPES_V2 };
  const table = Object.hasOwn(tables, rubric) ? tables[rubric] : null;
  const file = args.find((a) => !a.startsWith('--') || a === '-');
  if (!table || !Object.hasOwn(table, shape) || !file) { process.stderr.write('usage: contract-score.js <path|-> [--shape=lead|scribe] [--rubric=v1|v2]\n'); process.exit(2); }
  let buf;
  try { buf = fs.readFileSync(file === '-' ? 0 : file); } catch (e) { process.stderr.write(`unreadable: ${e.message}\n`); process.exit(2); }
  const raw = buf.toString('utf8');
  const text = rubric === 'v2' ? raw.replace(/\r\n/g, '\n') : raw;
  const rows = {};
  for (const [k, fn] of Object.entries(table[shape])) rows[k] = fn(text);
  const lines = maxBlockLines(text);
  const out = {
    shape,
    rubric,
    score: Object.values(rows).filter(Boolean).length,
    rows,
    bytes: buf.length,
    maxBlockLines: lines,
    sizeOver: buf.length > 30000 || lines > 80,
  };
  process.stdout.write(`${JSON.stringify(out)}\n`);
}

main();
