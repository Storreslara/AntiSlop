#!/usr/bin/env node
'use strict';

// Read-only export of recorded unit outcomes: ids and labels only, never prompt or defect prose.

const cp = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const CLASSES = [
  ['mirror', ['mirror', '--force-render', 'regenerate', 'filehashes']],
  ['version', ['changelog', 'version bump', 'version-stamp', 'plugin.json']],
  ['vacuous', ['vacuous']],
  ['spec-gap', ['spec gap', 'ambiguous', 'underspecified', 'contradict']],
  ['scope', ['out of scope', 'do not touch', 'unrelated']],
  ['host', ['host-dependent', 'precondition', 'not on path']],
  ['unverified', ['did not run', 'unverified', 'no evidence']],
];

// H-D: the unit whose PASS opens rubric v2 (contract-hardening H2).
const RUBRIC_V2_UNIT = 'rgh-h2';
const FLAGS = ['repo', 'markers', 'transcripts', 'out', 'gate', 'until', 'help'];
const USAGE = 'usage: unit-outcomes.js [--repo=<dir>] [--markers=<dir>] [--transcripts=<dir>] [--until=<ISO-8601>] [--out=<file>] [--gate=G3] [--help]\n';

function parseArgs(argv) {
  const o = {};
  argv.forEach((a) => {
    const m = /^--([a-z]+)(?:=(.*))?$/.exec(a);
    if (!m) { process.stderr.write(`unit-outcomes.js: unrecognized argument: ${a}\n`); process.exit(2); }
    if (!FLAGS.includes(m[1])) { process.stderr.write(`unknown flag: ${a}\n`); process.exit(2); }
    o[m[1]] = m[2] === undefined ? true : m[2];
  });
  if (o.help) { process.stdout.write(USAGE); process.exit(0); }
  o.repo = path.resolve(o.repo || process.cwd());
  o.markers = o.markers || path.join(o.repo, '.claude/reviewed');
  o.transcripts = o.transcripts || path.join(os.homedir(), '.claude', 'projects', o.repo.replace(/\//g, '-'));
  o.until = o.until || new Date().toISOString();
  o.cutoff = Date.parse(o.until);
  if (Number.isNaN(o.cutoff)) { process.stderr.write('unit-outcomes.js: bad --until\n'); process.exit(2); }
  return o;
}

function readMarkers(dir) {
  const units = {};
  const get = (id) => (units[id] = units[id] || { passTs: null, commit: null, blocks: [] });
  fs.readdirSync(dir).forEach((name) => {
    const m = /^(.+)\.(pass|fail)$/.exec(name);
    if (!m) return;
    const text = fs.readFileSync(path.join(dir, name), 'utf8');
    if (m[2] === 'pass') {
      const p = /^PASS (\S+) (\S+) commit: (\S+)/.exec(text);
      if (p && p[1] === m[1]) Object.assign(get(m[1]), { passTs: p[2], commit: p[3] });
      return;
    }
    text.split(/^(?=FAIL )/m).forEach((b) => {
      const h = /^FAIL (\S+) (\S+)/.exec(b);
      if (h && h[1] === m[1]) get(m[1]).blocks.push({ ts: h[2], text: b });
    });
  });
  Object.values(units).forEach((u) => u.blocks.sort((a, b) => Date.parse(a.ts) - Date.parse(b.ts)));
  return units;
}

function firstLine(file) {
  const fd = fs.openSync(file, 'r');
  const buf = Buffer.alloc(1 << 20);
  const n = fs.readSync(fd, buf, 0, buf.length, 0);
  fs.closeSync(fd);
  return buf.toString('utf8', 0, n).split('\n')[0];
}

function walk(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => (
    e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]));
}

function readTranscripts(dir) {
  const recs = [];
  walk(dir).filter((f) => f.endsWith('.meta.json')).sort().forEach((f) => {
    try {
      const meta = JSON.parse(fs.readFileSync(f, 'utf8'));
      const first = JSON.parse(firstLine(f.replace(/\.meta\.json$/, '.jsonl')));
      const c = first.message && first.message.content;
      const text = typeof c === 'string' ? c : (c || []).map((x) => x.text || '').join('\n');
      const u = /^\s*Unit:\s*(\S+)/.exec(text);
      if (u) recs.push({ unit: u[1], agent: meta.agentType, model: meta.model || null, ts: first.timestamp || null, text });
    } catch (e) { /* unreadable or non-subagent record */ }
  });
  return recs;
}

function frontmatterModel(repo, agent) {
  try {
    const m = /^---\n[\s\S]*?\nmodel:\s*(\S+)/.exec(fs.readFileSync(path.join(repo, 'agents', `${agent}.md`), 'utf8'));
    return m ? m[1] : 'unknown';
  } catch (e) { return 'unknown'; }
}

// The haiku-default cutover (ADR-0040), read from the orchestrator's own
// literal so the two cannot drift; null if the line is absent.
const HAIKU_CUTOVER = (() => {
  try {
    const text = fs.readFileSync(path.join(__dirname, '..', 'agents', 'orchestrator.md'), 'utf8');
    const m = text.match(/\*\*Haiku-default cutover: (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\.\*\*/);
    return m ? m[1] : null;
  } catch (_) {
    return null;
  }
})();

// Implementer tier by era when no transcript meta exists (ADR-0010, ADR-0026, ADR-0040).
// Only the default tier of the era: a laddered unit's later tiers are not inferred.
function eraTier(ts) {
  const t = Date.parse(ts);
  if (HAIKU_CUTOVER && t >= Date.parse(HAIKU_CUTOVER)) return 'haiku';
  return t >= Date.parse('2026-08-02') && t < Date.parse('2026-08-25') ? 'haiku' : 'sonnet';
}

function tiers(recs, agent, opt, eraTs) {
  const seen = new Set();
  const out = [];
  const mine = recs.filter((r) => r.agent === agent);
  if (!mine.length && agent === 'lead-programmer' && eraTs) return [{ tier: eraTier(eraTs), source: 'era-inferred' }];
  mine.forEach((r) => {
    const t = r.model
      ? { tier: r.model, source: 'observed' }
      : { tier: frontmatterModel(opt.repo, agent), source: 'frontmatter-inferred' };
    const k = `${t.tier}/${t.source}`;
    if (!seen.has(k)) { seen.add(k); out.push(t); }
  });
  return out;
}

function failClasses(blocks) {
  const text = blocks.map((b) => b.text).join('\n').toLowerCase();
  return CLASSES.filter(([, subs]) => subs.some((s) => text.includes(s))).map(([c]) => c);
}

function gitLog(opt) {
  try {
    const out = cp.execFileSync('git', ['log', '--reverse', `--until=${opt.until}`, '--format=%H%x09%s'],
      { cwd: opt.repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
    return out.split('\n').filter(Boolean).map((l) => l.split('\t'));
  } catch (e) { return []; }
}

function baselineOf(id, log, opt) {
  const esc = id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const hit = log.find(([, subject]) => new RegExp(`^[a-z]+!?\\(${esc}\\)`).test(subject));
  if (!hit) return null;
  try {
    return cp.execFileSync('git', ['rev-parse', `${hit[0]}^`],
      { cwd: opt.repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  } catch (e) { return null; }
}

// The first `~~~`+ block under `## Dispatch contract`, fences excluded; null when absent.
// Closes on a tilde-only line at least as long as the opening run (CommonMark).
function contractBlock(body) {
  const lines = body.split('\n');
  const h = lines.findIndex((l) => l.trim() === '## Dispatch contract');
  const open = lines.findIndex((l, k) => k > h && /^~{3,}/.test(l));
  if (h < 0 || open < 0) return null;
  const run = /^~+/.exec(lines[open])[0].length;
  const close = lines.findIndex((l, k) => k > open && /^~+$/.test(l.trim()) && l.trim().length >= run);
  return close < 0 ? null : lines.slice(open + 1, close).join('\n');
}

// An issue belongs to a unit only if its contract's Unit: token or its title's first word is the exact id.
function issueIsUnit(issue, id) {
  const block = contractBlock(issue.body || '');
  const u = block && /^Unit:\s*(\S+)/.exec(block);
  return (u && u[1] === id) || (issue.title || '').split(/\s+/)[0] === id;
}

function ghIssue(id, opt) {
  try {
    const out = cp.execFileSync(process.env.GH_BIN || 'gh', ['issue', 'list', '--search', `${id} in:title`,
      '--state', 'all', '--json', 'number,title,body,labels,createdAt', '--limit', '20'],
    { cwd: opt.repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
    return JSON.parse(out).find((i) => issueIsUnit(i, id)) || null;
  } catch (e) { return null; }
}

function planBlock(id, opt) {
  const dir = path.join(opt.repo, 'docs', 'plans');
  if (!fs.existsSync(dir)) return null;
  for (const f of fs.readdirSync(dir).filter((n) => n.endsWith('.md')).sort()) {
    const lines = fs.readFileSync(path.join(dir, f), 'utf8').split('\n');
    const i = lines.findIndex((l) => l.trim() === `### Unit: ${id}`);
    if (i < 0) continue;
    let j = lines.findIndex((l, k) => k > i && /^#{2,3} /.test(l));
    if (j < 0) j = lines.length;
    return { path: `docs/plans/${f}`, plan: f.replace(/\.md$/, ''), text: lines.slice(i, j).join('\n') };
  }
  return null;
}

// Committer date of the oldest commit that introduced the unit's plan block; null when unknown.
function planTs(id, p, opt) {
  try {
    const out = cp.execFileSync('git', ['log', '-S', `### Unit: ${id}`, '--format=%cI', '--', p.path],
      { cwd: opt.repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
    return out.split('\n').filter(Boolean).pop() || null;
  } catch (e) { return null; }
}

// Source order: issue Dispatch-contract block, plan block, transcript with `## Ordered edits`, none.
function contractFor(id, recs, opt) {
  const issue = ghIssue(id, opt);
  const block = issue && contractBlock(issue.body || '');
  if (block !== null) {
    const label = (issue.labels || []).map((l) => l.name).find((n) => n.startsWith('plan/'));
    return { source: `issue#${issue.number}`, author: 'task-master', plan: label ? label.slice(5) : null,
      text: block, ts: issue.createdAt || null };
  }
  const p = planBlock(id, opt);
  if (p) return { source: `plan:${p.path}`, author: 'spec-master', plan: p.plan, text: p.text, ts: planTs(id, p, opt) };
  const t = recs.find((r) => r.unit === id && r.agent === 'lead-programmer' && /^## Ordered edits\s*$/m.test(r.text));
  if (t) return { source: 'transcript', author: 'unknown', plan: null, text: t.text, ts: null };
  return { source: 'none', author: 'unknown', plan: null, text: null, ts: null };
}

function scoreOf(text, rubric) {
  if (text === null) return null;
  const args = [path.join(__dirname, '..', 'bin', 'contract-score.js'), '-'];
  if (rubric) args.push(`--rubric=${rubric}`);
  const r = cp.spawnSync('node', args, { input: text, encoding: 'utf8' });
  try { return JSON.parse(r.stdout).score; } catch (e) { return null; }
}

// As-of-cutoff: events after the cutoff are dropped before anything is derived; null when no terminal event.
function terminalOf(u, cutoff) {
  const fails = u.blocks.filter((b) => Date.parse(b.ts) <= cutoff);
  const passTs = u.passTs && Date.parse(u.passTs) <= cutoff ? u.passTs : null;
  const cands = [passTs, fails.length >= 2 ? fails[1].ts : null].filter(Boolean);
  if (!cands.length) return null;
  const ts = cands.reduce((a, b) => (Date.parse(a) <= Date.parse(b) ? a : b));
  const first = [passTs, ...fails.map((f) => f.ts)].filter(Boolean).reduce((a, b) => (Date.parse(a) <= Date.parse(b) ? a : b));
  return { ts, fails, passTs, first };
}

function buildRow(id, u, term, ctx) {
  const recs = ctx.recs.filter((r) => r.unit === id && (!r.ts || Date.parse(r.ts) <= ctx.opt.cutoff));
  const base = baselineOf(id, ctx.log, ctx.opt);
  const c = contractFor(id, recs, ctx.opt);
  return {
    id,
    plan: c.plan,
    contract_author: c.author,
    contract_source: c.source,
    contract_score: scoreOf(c.text),
    contract_score_v2: scoreOf(c.text, 'v2'),
    contract_ts: c.ts,
    rubric_version: rubricVersion(c.ts, ctx.h2Pass),
    baseline: base,
    final_commit: term.passTs && u.commit !== 'none' ? u.commit : null,
    range_source: base ? 'commit-scope' : 'none',
    implementer_tiers: tiers(recs, 'lead-programmer', ctx.opt, term.first),
    attempts: term.fails.length + (term.passTs ? 1 : 0),
    reviewer_tiers: tiers(recs, 'reviewer', ctx.opt),
    fail_classes: failClasses(term.fails),
    cap_hit: term.fails.length >= 2,
    task_master_cutoff: null,
    pass_ts: term.passTs,
    terminal_ts: term.ts,
    fail_blocks: term.fails.length,
  };
}

// H-D: null without a contract; v1 until RUBRIC_V2_UNIT has a PASS as of the cutoff; then by contract_ts.
function rubricVersion(contractTs, h2Pass) {
  if (contractTs === null || contractTs === undefined) return null;
  if (Number.isNaN(Date.parse(contractTs))) return null;
  if (!h2Pass) return 'v1';
  return Date.parse(contractTs) <= Date.parse(h2Pass) ? 'v1' : 'v2';
}

function exportRows(opt) {
  const units = readMarkers(opt.markers);
  const ctx = { opt, recs: readTranscripts(opt.transcripts), log: gitLog(opt) };
  const h2 = units[RUBRIC_V2_UNIT] ? terminalOf(units[RUBRIC_V2_UNIT], opt.cutoff) : null;
  ctx.h2Pass = h2 && h2.passTs ? h2.passTs : null;
  return Object.keys(units).sort().flatMap((id) => {
    const term = terminalOf(units[id], opt.cutoff);
    return term ? [buildRow(id, units[id], term, ctx)] : [];
  });
}

function classMix(rows) {
  return CLASSES.map(([c]) => [c, rows.filter((r) => r.fail_classes.includes(c)).length])
    .filter(([, n]) => n > 0).map(([c, n]) => `${c}=${n}`).join(',');
}

function gateG3(rows) {
  const u34 = rows.find((r) => r.id === 'rgh-u3-4');
  if (!u34 || !u34.pass_ts) return 'G3 closed: rgh-u3-4 has no PASS yet (rubric era not started)';
  const inEra = (r) => r.contract_author === 'task-master' && r.contract_ts !== null
    && Date.parse(r.contract_ts) > Date.parse(u34.pass_ts);
  const era = rows.filter(inEra);
  const pre = rows.filter((r) => Date.parse(r.terminal_ts) >= Date.parse('2026-08-25T00:00:00Z') && !inEra(r));
  // H11: each rubric-era unit is scored under its own rubric_version.
  const seven = era.filter((r) => (r.rubric_version === 'v2' ? r.contract_score_v2 : r.contract_score) === 7).length;
  const flagged = era.filter((r) => r.task_master_cutoff !== null);
  const cutoffs = flagged.length ? flagged.filter((r) => r.task_master_cutoff === true).length : 'unmeasured';
  const counts = `rubric_era=${era.length} scored7=${seven} task_master_cutoffs=${cutoffs}`;
  const head = era.length >= 60 && seven >= 20 ? `G3 open\n${counts}` : `G3 closed: ${counts}`;
  return `${head}\nrubric_classes=${classMix(era)}\npre_rubric_classes=${classMix(pre)}`;
}

function main() {
  const opt = parseArgs(process.argv.slice(2));
  const rows = exportRows(opt);
  if (opt.gate) {
    if (opt.gate !== 'G3') { process.stderr.write('unit-outcomes.js: only --gate=G3 is supported\n'); process.exit(2); }
    process.stdout.write(`${gateG3(rows)}\n`);
    return;
  }
  const text = rows.map((r) => `${JSON.stringify(r)}\n`).join('');
  if (opt.out && opt.out !== true) fs.writeFileSync(opt.out, text); else process.stdout.write(text);
}

main();
