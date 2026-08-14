#!/usr/bin/env node
'use strict';

// Mechanical half of the antislop ADAPT flow, packaged as a standalone
// installer so a project doesn't need GitHub collaborator access or the
// /plugin marketplace flow. This CLI does deterministic file scaffolding
// (copy, stamp, merge) plus, via --update/--wire-*-mcp, deterministic
// resync and MCP rescoping — it deliberately does NOT do the
// judgment-driven half (repo-specific test/lint commands, protected paths,
// third-party skill NAME selection, CLAUDE.md pruning, hook verification).
// That half still lives in skills/install-antislop/SKILL.md, which this CLI
// copies project-locally and tells you to run next. See --update and
// --wire-graph-mcp/--wire-arxiv-mcp below for the zero-LLM resync path.

const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const readline = require('readline');
const { spawnSync } = require('child_process');

const PKG_ROOT = path.resolve(__dirname, '..');
const CWD = process.cwd();

const CORE_PERSONAS = ['orchestrator', 'explorer', 'lead-programmer'];
const OPTIONAL_PERSONAS = ['spec-master', 'task-master', 'scribe', 'reviewer', 'milestone-auditor', 'agent-auditor'];

// Per-persona protocol delivery (OQ6=A body-inlining; @import does not resolve
// inside a subagent body — proven in issue #121 Step 2). Full-tier personas
// carry the whole persona-protocol.md inlined into their .claude/agents/*.md
// body; slim-tier ones carry persona-protocol-slim.md. Everyone else (the raw
// protocol docs themselves) carries neither. Replaces the single global
// `@.claude/persona-protocol.md` CLAUDE.md import.
const SLIM_TIER_PERSONAS = ['explorer', 'researcher', 'scribe', 'agent-auditor'];
function protocolTierFor(name) {
  if (SLIM_TIER_PERSONAS.includes(name)) return 'slim';
  return 'full';
}
// Legacy-token migration: the persona formerly named `planner` was renamed
// `hivemind` (repo-wide rename, plugin v0.6.0); `hivemind` was later split
// into `spec-master` and `task-master` (plugin v0.10.0); the persona
// formerly named `repo-historian` was renamed `scribe` (repo-wide rename,
// plugin v0.10.0) — these are deprecated, legacy `--personas=planner` /
// `--personas=hivemind` / `--personas=repo-historian` / legacy
// `personaSelection` entries only. Each value is an array of current
// token(s) a legacy token maps forward to (a plain string map can't
// represent the one-to-two hivemind split); entries chain (`planner` ->
// `hivemind` -> `spec-master`+`task-master`) via resolveLegacyToken below
// rather than being silently dropped by the OPTIONAL_PERSONAS intersection
// filter.
const LEGACY_PERSONA_MAP = {
  planner: ['hivemind'],
  hivemind: ['spec-master', 'task-master'],
  'repo-historian': ['scribe'],
}; // legacy token -> current token(s)
// researcher is handled separately: it's a template, not a plain agent copy.

// Matches unresolved substitution placeholders left in a stamped file after
// --update (e.g. <REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_4>,
// <MATTPOCOCK:slot>, bare <MATTPOCOCK>). Requires 2+ chars before an optional
// colon-suffix so bare prose like "Open Question <N>" doesn't false-positive
// — every real placeholder in this repo is multi-character.
const PLACEHOLDER_RE = /<[A-Z0-9_]{2,}(:[a-zA-Z0-9_-]+)?>/;

function readPluginVersion() {
  const pluginJsonPath = path.join(PKG_ROOT, '.claude-plugin', 'plugin.json');
  const pluginJson = JSON.parse(fs.readFileSync(pluginJsonPath, 'utf8'));
  return pluginJson.version;
}

// Compares two dotted semver strings by numeric components (missing
// components padded with 0). Any pre-release/build suffix (e.g. "-rc1" or a
// dotted "-beta.3") is dropped by splitting on the first '-' or '+' BEFORE
// splitting into dotted numeric segments, so a dotted suffix can't leak an
// extra non-numeric segment into the comparison. Returns <0, 0, or >0.
function compareSemver(a, b) {
  const parse = (v) => String(v).split(/[-+]/)[0].split('.').map((p) => parseInt(p, 10) || 0);
  const pa = parse(a);
  const pb = parse(b);
  const len = Math.max(pa.length, pb.length);
  for (let i = 0; i < len; i++) {
    const diff = (pa[i] || 0) - (pb[i] || 0);
    if (diff !== 0) return diff;
  }
  return 0;
}

// Warn (but proceed) when an --overwrite scaffold is about to stamp an OLDER
// plugin version over a newer recorded one (issue #110). Mirrors runUpdate's
// downgrade guard but is deliberately warn-and-proceed, not refuse: --overwrite
// is already an explicit destructive opt-in, so the defect being fixed is the
// silence, not the stamping. Must be called BEFORE the pluginVersion = version
// assignment so it reads the prior recorded value.
function warnIfDowngradeStamp(recordedVersion, version, configLabel) {
  if (recordedVersion && compareSemver(version, recordedVersion) < 0) {
    console.warn(
      `Warning: --overwrite is stamping a version downgrade into ${configLabel} — the resolved ` +
        `plugin version (v${version}) is OLDER than the recorded pluginVersion (v${recordedVersion}). ` +
        'Proceeding because --overwrite is an explicit opt-in; the stamp is being refreshed to ' +
        `v${version}.`
    );
  }
}

function mkdirp(p) {
  fs.mkdirSync(p, { recursive: true });
}

function versionStamp(version, sourceRelPath) {
  return `<!-- antislop v${version} | source: ${sourceRelPath} | ADAPT-substituted -->\n`;
}

function copyStamped(srcAbsPath, destAbsPath, version, sourceRelPath) {
  const body = fs.readFileSync(srcAbsPath, 'utf8');
  fs.writeFileSync(destAbsPath, insertStampAfterFrontmatter(body, versionStamp(version, sourceRelPath)));
}

// Claude Code's subagent discovery requires the file to start with the
// frontmatter delimiter `---` as its very first bytes — a leading HTML
// comment before it silently breaks discovery (confirmed: agents copied
// with a leading stamp comment never register as invocable agent types,
// even after the background-refresh lag that affects genuinely new files
// clears). So the stamp must go right after the closing `---`, not before
// the opening one.
function insertStampAfterFrontmatter(body, stamp) {
  const match = body.match(/^---\r?\n[\s\S]*?\r?\n---\r?\n/);
  if (!match) return stamp + body;
  const end = match[0].length;
  return body.slice(0, end) + stamp + body.slice(end);
}

function copyPlain(srcAbsPath, destAbsPath) {
  fs.copyFileSync(srcAbsPath, destAbsPath);
}

function copyDirRecursive(srcDir, destDir) {
  mkdirp(destDir);
  for (const entry of fs.readdirSync(srcDir, { withFileTypes: true })) {
    const srcPath = path.join(srcDir, entry.name);
    const destPath = path.join(destDir, entry.name);
    if (entry.isDirectory()) {
      copyDirRecursive(srcPath, destPath);
    } else {
      copyPlain(srcPath, destPath);
      const stat = fs.statSync(srcPath);
      fs.chmodSync(destPath, stat.mode);
    }
  }
}

// Returns how many lines were (or, under dryRun, would have been) appended —
// the answer has to survive the write being suppressed, or --dry-run loses the
// report line along with the write.
function appendUnique(filePath, lines, dryRun) {
  let existing = '';
  if (fs.existsSync(filePath)) {
    existing = fs.readFileSync(filePath, 'utf8');
  }
  const missing = lines.filter((line) => !existing.includes(line));
  if (missing.length === 0) return 0;
  if (!dryRun) {
    const sep = existing.length > 0 && !existing.endsWith('\n') ? '\n' : '';
    fs.writeFileSync(filePath, existing + sep + missing.join('\n') + '\n');
  }
  return missing.length;
}

function canonicalizeForComparison(obj) {
  if (obj === null || obj === undefined) {
    return JSON.stringify(obj);
  }
  if (typeof obj !== 'object') {
    return JSON.stringify(obj);
  }
  if (Array.isArray(obj)) {
    return JSON.stringify(obj.map(canonicalizeForComparison));
  }
  const sorted = {};
  Object.keys(obj).sort().forEach(key => {
    sorted[key] = canonicalizeForComparison(obj[key]);
  });
  return JSON.stringify(sorted);
}

function structuralEquals(a, b) {
  return canonicalizeForComparison(a) === canonicalizeForComparison(b);
}

function deepMerge(target, source) {
  for (const key of Object.keys(source)) {
    if (
      source[key] &&
      typeof source[key] === 'object' &&
      !Array.isArray(source[key]) &&
      target[key] &&
      typeof target[key] === 'object' &&
      !Array.isArray(target[key])
    ) {
      deepMerge(target[key], source[key]);
    } else if (Array.isArray(source[key]) && Array.isArray(target[key])) {
      for (const item of source[key]) {
        const isDuplicate = typeof item === 'object' && item !== null
          ? target[key].some(existing => structuralEquals(existing, item))
          : target[key].includes(item);
        if (!isDuplicate) target[key].push(item);
      }
    } else if (!(key in target)) {
      target[key] = source[key];
    }
  }
  return target;
}

async function prompt(rl, question) {
  return new Promise((resolve) => rl.question(question, resolve));
}

async function askYesNo(rl, question, defaultYes) {
  const suffix = defaultYes ? '[Y/n] ' : '[y/N] ';
  const answer = (await prompt(rl, `${question} ${suffix}`)).trim().toLowerCase();
  if (answer === '') return defaultYes;
  return answer === 'y' || answer === 'yes';
}

// For standalone yes/no prompts after the main persona-selection readline
// interface (if any) has already been closed.
async function askYesNoStandalone(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const answer = await askYesNo(rl, question, false);
  rl.close();
  return answer;
}

// ---------------------------------------------------------------------------
// --update / --wire-graph-mcp / --wire-arxiv-mcp: the deterministic resync
// path. Everything below regenerates a version-stamped file straight from
// the plugin's own source + the substitution values persona-config.json
// records at ADAPT time (see templates/persona-config.schema.json's
// `substitutions`/`fileHashes` fields) — no LLM judgment involved. A file
// only ever needs a human decision (not an LLM one) when it has genuinely
// diverged from the last known-clean baseline; see --accept=/--keep= below.
// ---------------------------------------------------------------------------

function sha256Hex(content) {
  return crypto.createHash('sha256').update(content, 'utf8').digest('hex');
}

const STAMP_LINE_RE = /<!-- antislop v[^\n]*ADAPT-substituted -->\r?\n/;
const STAMP_VERSION_RE = /<!-- antislop v([^\s]+)[^\n]*ADAPT-substituted -->\r?\n/;

function stripStamp(body) {
  return body.replace(STAMP_LINE_RE, '');
}

// Returns the version string from the first stamp-line occurrence, or null
// when no stamp is present (frontmatter-tolerant: the regex is unanchored).
function stampVersionOf(body) {
  const match = body.match(STAMP_VERSION_RE);
  return match ? match[1] : null;
}

function legacyTokensIn(selection) {
  return selection.filter((p) => Object.prototype.hasOwnProperty.call(LEGACY_PERSONA_MAP, p));
}

// Resolves a single token through LEGACY_PERSONA_MAP to a flat list of
// current tokens, chaining through intermediate legacy tokens (e.g.
// `planner` -> `hivemind` -> `spec-master`+`task-master`).
function resolveLegacyToken(token) {
  if (!(token in LEGACY_PERSONA_MAP)) return [token];
  return LEGACY_PERSONA_MAP[token].flatMap(resolveLegacyToken);
}

function migrateLegacyPersonaTokens(selection, { logNote } = {}) {
  const legacyTokens = legacyTokensIn(selection);
  if (legacyTokens.length === 0) return selection;
  if (logNote) {
    for (const token of legacyTokens) {
      const resolved = resolveLegacyToken(token).join('+');
      console.log(
        `Deprecation note: migrating the legacy "${token}" token to "${resolved}" ` +
          `(the legacy "${token}" token was renamed "${resolved}" in a prior plugin version).`
      );
    }
  }
  return [...new Set(selection.flatMap(resolveLegacyToken))];
}

function escapeRegExp(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function renderMcpBlock(launch, indent) {
  const lines = [`${indent}command: ${launch.command}`, `${indent}args:`];
  for (const a of launch.args || []) lines.push(`${indent}  - ${a}`);
  if (launch.env && Object.keys(launch.env).length > 0) {
    lines.push(`${indent}env:`);
    for (const k of Object.keys(launch.env)) lines.push(`${indent}  ${k}: ${launch.env[k]}`);
  }
  return lines.join('\n');
}

function applyMcpPlaceholder(body, placeholder, launch, fileLabel) {
  if (!body.includes(placeholder)) return body;
  if (!launch) {
    throw new Error(
      `${fileLabel} still has the ${placeholder} placeholder but no launch command is ` +
        "recorded in persona-config.json's substitutions — run `bin/cli.js --wire-graph-mcp` " +
        '(or `--wire-arxiv-mcp=<server-key>`) to wire it, then re-run --update.'
    );
  }
  const lineRe = new RegExp(`^([ \\t]*)${escapeRegExp(placeholder)}\\r?\\n?`, 'm');
  const match = body.match(lineRe);
  const indent = match ? match[1] : '      ';
  return body.replace(lineRe, renderMcpBlock(launch, indent) + '\n');
}

const ARXIV_FALLBACK_NOTE =
  '<!-- No working arXiv MCP found at ADAPT time — operating in WebFetch/WebSearch fallback mode. -->\n';

function applyArxivFallback(body) {
  const stripped = body.replace(/\nmcpServers:\n(?:[ \t]+\S.*\n?)+/, '\n');
  const fmMatch = stripped.match(/^---\r?\n[\s\S]*?\r?\n---\r?\n/);
  if (!fmMatch) return ARXIV_FALLBACK_NOTE + stripped;
  const end = fmMatch[0].length;
  return stripped.slice(0, end) + ARXIV_FALLBACK_NOTE + stripped.slice(end);
}

// ---------------------------------------------------------------------------
// Legacy backfill (projects adapted before v0.6.4, whose persona-config.json
// has no `substitutions`/`fileHashes`): reverse-derive both, deterministically,
// from whatever's already on disk, instead of forcing the whole project onto
// the LLM-driven fallback. Best-effort — ADAPT substitution is a literal
// placeholder-line -> rendered MCP block text swap with no other prose
// changes (see install-antislop SKILL.md), so a project adapted at the
// CURRENT plugin version's persona files can
// always be derived this way; a project several versions behind may have
// some individual slots whose surrounding prose has since been reworded —
// those are left undetermined here and surfaced per-file, non-fatally, by
// the (now resilient) render loop below rather than guessed at.
// ---------------------------------------------------------------------------

function normalizeEol(s) {
  return s.replace(/\r\n/g, '\n');
}

// Reverse of renderMcpBlock: parses an already-rendered mcpServers: block
// back into { command, args, env }. Reuses applyArxivFallback's block-capture
// idiom (stop at the first line that returns to zero indent — mcpServers: is
// not guaranteed to be the last frontmatter key, e.g. explorer.md's
// `maxTurns:` follows it). Hand-rolled on purpose: this only ever needs to
// parse the fixed, single-server shape this file's own renderMcpBlock writes,
// not general YAML.
function deriveMcpLaunchFromDisk(body) {
  const blockMatch = normalizeEol(body).match(/\nmcpServers:\n((?:[ \t]+\S.*\n?)+)/);
  if (!blockMatch) return undefined;

  const lines = blockMatch[1].split('\n').filter((l) => l.trim().length > 0);
  let command;
  const args = [];
  const env = {};
  let mode = null; // null | 'args' | 'env'

  for (const rawLine of lines) {
    const t = rawLine.trim();
    if (t.startsWith('command:')) {
      command = t.slice('command:'.length).trim();
      mode = null;
    } else if (t === 'args:') {
      mode = 'args';
    } else if (t === 'env:') {
      mode = 'env';
    } else if (mode === 'args' && t.startsWith('- ')) {
      args.push(t.slice(2).trim());
    } else if (mode === 'env') {
      const kv = t.match(/^([^:\s][^:]*):\s*(.*)$/);
      if (kv) env[kv[1]] = kv[2];
    }
    // else: `- code-review-graph:` / `type: stdio` — expected, skip.
  }

  if (!command) return undefined;
  const launch = { command, args };
  if (Object.keys(env).length > 0) launch.env = env;
  return launch;
}

// Fills in only whatever substitutions.* keys are currently ABSENT (never
// overwrites an already-recorded value, including a deliberate `null` for
// "researcher wasn't wired" — hasOwnProperty, not truthiness, so that `null`
// isn't mistaken for "missing"). Returns whether anything changed.
function backfillSubstitutionsFromDisk(config, specs) {
  config.substitutions = config.substitutions || {};
  let changed = false;

  const mcpTargets = [
    { relPath: '.claude/agents/explorer.md', field: 'graphMcpLaunch', placeholder: '<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_4>' },
    { relPath: '.claude/agents/researcher.md', field: 'arxivMcpLaunch', placeholder: '<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_5>' },
  ];
  for (const t of mcpTargets) {
    if (Object.prototype.hasOwnProperty.call(config.substitutions, t.field)) continue;
    const destAbsPath = path.join(CWD, t.relPath);
    if (!fs.existsSync(destAbsPath)) continue;
    const body = fs.readFileSync(destAbsPath, 'utf8');
    if (body.includes(t.placeholder)) continue; // never wired — nothing to reverse-engineer
    if (t.field === 'arxivMcpLaunch' && body.includes(ARXIV_FALLBACK_NOTE)) {
      config.substitutions[t.field] = null;
      changed = true;
      continue;
    }
    const launch = deriveMcpLaunchFromDisk(body);
    if (launch) {
      config.substitutions[t.field] = launch;
      changed = true;
    }
  }
  return changed;
}

// Bootstraps fileHashes for whatever files exist on disk but have no
// recorded baseline yet: adopts current content as "known-clean" (there's no
// earlier baseline to compare against). A one-time transitional gap — if this
// project had genuine hand-edits predating fileHashes existing at all, this
// run treats them as the new clean baseline rather than flagging them; the
// caller logs this loudly rather than silently.
function backfillFileHashesFromDisk(config, specs) {
  config.fileHashes = config.fileHashes || {};
  let changed = false;
  for (const spec of specs) {
    const relKey = spec.projectRelPath;
    if (relKey in config.fileHashes) continue;
    const destAbsPath = path.join(CWD, relKey);
    if (!fs.existsSync(destAbsPath)) continue;
    config.fileHashes[relKey] = sha256Hex(stripStamp(fs.readFileSync(destAbsPath, 'utf8')));
    changed = true;
  }
  return changed;
}

// Drops fileHashes keys that no longer correspond to any current spec (e.g.
// a persona retired from OPTIONAL_PERSONAS) — otherwise they accumulate in
// persona-config.json forever, since the render loop below only ever writes
// keys for specs it iterates and never reads orphaned ones.
function pruneStaleFileHashes(fileHashes, specs) {
  const validKeys = new Set(specs.map((spec) => spec.projectRelPath));
  const pruned = {};
  for (const key of Object.keys(fileHashes)) {
    if (validKeys.has(key)) pruned[key] = fileHashes[key];
  }
  return pruned;
}

function copyStampedBody(destAbsPath, body, version, sourceRelPath) {
  mkdirp(path.dirname(destAbsPath));
  fs.writeFileSync(destAbsPath, insertStampAfterFrontmatter(body, versionStamp(version, sourceRelPath)));
}

// Single write site for the update loop: 'raw' specs (hook scripts) go out
// verbatim with the packaged file's mode, so a restored gate stays
// executable; everything else keeps its version stamp.
function writeSpecBody(spec, destAbsPath, body, version) {
  if (spec.kind !== 'raw') {
    copyStampedBody(destAbsPath, body, version, spec.sourceRelPath);
    return;
  }
  mkdirp(path.dirname(destAbsPath));
  fs.writeFileSync(destAbsPath, body);
  fs.chmodSync(destAbsPath, fs.statSync(spec.sourceAbsPath).mode & 0o777);
}

function listFilesRecursive(dir, prefix) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const rel = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (entry.isDirectory()) out.push(...listFilesRecursive(path.join(dir, entry.name), rel));
    else out.push(rel);
  }
  return out.sort();
}

function buildFileSpecs(personaSelection) {
  const selectedOptional = OPTIONAL_PERSONAS.filter((p) => personaSelection.includes(p));
  const specs = [];
  for (const name of CORE_PERSONAS.concat(selectedOptional)) {
    specs.push({
      projectRelPath: `.claude/agents/${name}.md`,
      sourceAbsPath: path.join(PKG_ROOT, 'agents', `${name}.md`),
      sourceRelPath: `agents/${name}.md`,
      kind: name === 'explorer' ? 'graph' : 'plain',
      protocolTier: protocolTierFor(name),
    });
  }
  if (personaSelection.includes('researcher')) {
    specs.push({
      projectRelPath: '.claude/agents/researcher.md',
      sourceAbsPath: path.join(PKG_ROOT, 'templates', 'researcher.md.tmpl'),
      sourceRelPath: 'templates/researcher.md.tmpl',
      kind: 'arxiv',
      protocolTier: protocolTierFor('researcher'),
    });
  }
  // Reverses OQ11=DROP (U12), which stopped generating this file on the
  // premise that "nothing reads it at runtime" — true while every full-tier
  // persona carried the whole protocol inlined. Once per-persona excerpts are
  // TRIMMED, a persona whose body no longer contains a rule needs somewhere to
  // read it, so the full doc is a managed on-disk reference again. Nothing
  // auto-loads it: zero tokens per dispatch, read only on demand.
  specs.push({
    projectRelPath: '.claude/persona-protocol.md',
    sourceAbsPath: path.join(PKG_ROOT, 'templates', 'persona-protocol.md'),
    sourceRelPath: 'templates/persona-protocol.md',
    kind: 'plain',
  });
  specs.push({
    projectRelPath: '.claude/persona-protocol-slim.md',
    sourceAbsPath: path.join(PKG_ROOT, 'templates', 'persona-protocol-slim.md'),
    sourceRelPath: 'templates/persona-protocol-slim.md',
    kind: 'plain',
  });
  specs.push({
    projectRelPath: '.claude/protocol-digest.md',
    sourceAbsPath: path.join(PKG_ROOT, 'templates', 'protocol-digest.md'),
    sourceRelPath: 'templates/protocol-digest.md',
    kind: 'plain',
  });
  return specs;
}

// Hook scripts, enumerated from the packaged directory at runtime (never a
// hardcoded list) so a gate added later reaches already-installed projects on
// their next --update. kind 'raw': copied verbatim — no protocol inlining and
// no version stamp (an HTML comment is not shell syntax), so they are tracked
// by content hash alone. Deliberately NOT part of buildFileSpecs(), whose
// callers treat every spec it returns as a stamped, ADAPT-rendered mirror;
// runUpdate concatenates the two lists.
function buildHookScriptSpecs() {
  const hooksSrcDir = path.join(PKG_ROOT, 'hooks', 'scripts');
  return listFilesRecursive(hooksSrcDir, '').map((rel) => ({
    projectRelPath: `.claude/hooks/scripts/${rel}`,
    sourceAbsPath: path.join(hooksSrcDir, rel),
    sourceRelPath: `hooks/scripts/${rel}`,
    kind: 'raw',
  }));
}

// Splits the canonical protocol into its leading header comment (which is NOT
// a section) plus one entry per `## ` heading, in template order. Joining the
// preamble and every section text with '\n' reproduces the file byte-for-byte.
function parseProtocolSections(text) {
  const preamble = [];
  const sections = [];
  for (const line of text.split('\n')) {
    if (line.startsWith('## ')) {
      sections.push({ header: line.slice(3).trim(), lines: [line] });
    } else if (sections.length) {
      sections[sections.length - 1].lines.push(line);
    } else {
      preamble.push(line);
    }
  }
  return { preamble: preamble.join('\n'), sections: sections.map((s) => ({ header: s.header, text: s.lines.join('\n') })) };
}

function canonicalProtocolText() {
  return fs.readFileSync(path.join(PKG_ROOT, 'templates', 'persona-protocol.md'), 'utf8');
}

const CANONICAL_PROTOCOL_SECTIONS = parseProtocolSections(canonicalProtocolText()).sections;
const CANONICAL_PROTOCOL_HEADERS = CANONICAL_PROTOCOL_SECTIONS.map((s) => s.header);

// Carried by every full-tier persona regardless of role.
const UNIVERSAL_PROTOCOL_CORE = [
  'Structural questions go to the explorer',
  'Answer shape',
  'Scope Bash output before it enters context',
  'Agent-teams mode (only relevant if you were spawned as a teammate)',
  'Terminal status line (every dispatched turn)',
  'Blocked by a gate you do not own (never self-authorize a bypass)',
];

// Which protocol sections each full-tier persona carries, keyed by the EXACT
// canonical header. Every row is an EXHAUSTIVE classification of the canonical
// section list into `include` (what that persona's body carries) and `drop` —
// checked at load by assertProtocolMatrixComplete below, so a section added to
// the template forces a per-persona decision instead of silently reaching
// everyone (cost) or no one (a lost rule). Both lists are literal on purpose:
// deriving either one from the other would remove that forcing function.
//
// `orchestrator` was originally deliberately untrimmed; gh348 Steps 4 and 11
// reversed that for the sections it never executes on (Third/Fourth verdict,
// Microworld bundles, the teammate Write/Edit fallback, and the memory note —
// it has no `memory:` frontmatter). The memory note is otherwise carried
// exactly by the personas whose agents/*.md declares `memory:` frontmatter.
const PROTOCOL_SECTIONS_BY_PERSONA = {
  orchestrator: {
    include: [
      ...UNIVERSAL_PROTOCOL_CORE,
      'WIP sentinel (mid-task handoff, not a bypass)',
      'Running acceptance-criteria commands (there is no self-wake)',
      'Retrieval contract',
      'Machine-checkable criteria',
      'Review ownership — one unit, one review, single owner',
      'Pending-review flag (default-mode review backstop)',
      'FAIL record (durable warning for future spawns)',
      'Continuing after a FAIL verdict',
    ],
    drop: [
      'Third verdict: insufficient-context',
      'Fourth verdict: escalate-to-human',
      'Microworld bundles (format and the check contract)',
      'Teammate Write/Edit fallback and gate rephrasing doctrine',
      'A note on `memory`',
    ],
  },
  'lead-programmer': {
    include: [
      ...UNIVERSAL_PROTOCOL_CORE,
      'Teammate Write/Edit fallback and gate rephrasing doctrine',
      'WIP sentinel (mid-task handoff, not a bypass)',
      'Running acceptance-criteria commands (there is no self-wake)',
      'Retrieval contract',
      'Machine-checkable criteria',
      'Review ownership — one unit, one review, single owner',
      'Continuing after a FAIL verdict',
      'A note on `memory`',
      'Microworld bundles (format and the check contract)',
    ],
    drop: [
      'Pending-review flag (default-mode review backstop)',
      'FAIL record (durable warning for future spawns)',
      'Third verdict: insufficient-context',
      'Fourth verdict: escalate-to-human',
    ],
  },
  reviewer: {
    include: [
      ...UNIVERSAL_PROTOCOL_CORE,
      'Teammate Write/Edit fallback and gate rephrasing doctrine',
      'Running acceptance-criteria commands (there is no self-wake)',
      'Retrieval contract',
      'Machine-checkable criteria',
      'Review ownership — one unit, one review, single owner',
      'Pending-review flag (default-mode review backstop)',
      'FAIL record (durable warning for future spawns)',
      'Third verdict: insufficient-context',
    ],
    drop: [
      'WIP sentinel (mid-task handoff, not a bypass)',
      'Continuing after a FAIL verdict',
      'A note on `memory`',
      'Fourth verdict: escalate-to-human',
      'Microworld bundles (format and the check contract)',
    ],
  },
  'spec-master': {
    include: [
      ...UNIVERSAL_PROTOCOL_CORE,
      'Teammate Write/Edit fallback and gate rephrasing doctrine',
      'Running acceptance-criteria commands (there is no self-wake)',
      'Retrieval contract',
      'Machine-checkable criteria',
      'Review ownership — one unit, one review, single owner',
      'FAIL record (durable warning for future spawns)',
      'Continuing after a FAIL verdict',
      'A note on `memory`',
    ],
    drop: [
      'WIP sentinel (mid-task handoff, not a bypass)',
      'Pending-review flag (default-mode review backstop)',
      'Third verdict: insufficient-context',
      'Fourth verdict: escalate-to-human',
      'Microworld bundles (format and the check contract)',
    ],
  },
  'task-master': {
    include: [
      ...UNIVERSAL_PROTOCOL_CORE,
      'Teammate Write/Edit fallback and gate rephrasing doctrine',
      'Running acceptance-criteria commands (there is no self-wake)',
      'Retrieval contract',
      'Machine-checkable criteria',
      'Review ownership — one unit, one review, single owner',
      'FAIL record (durable warning for future spawns)',
      'A note on `memory`',
    ],
    drop: [
      'WIP sentinel (mid-task handoff, not a bypass)',
      'Pending-review flag (default-mode review backstop)',
      'Third verdict: insufficient-context',
      'Fourth verdict: escalate-to-human',
      'Continuing after a FAIL verdict',
      'Microworld bundles (format and the check contract)',
    ],
  },
  'milestone-auditor': {
    include: [
      ...UNIVERSAL_PROTOCOL_CORE,
      'Teammate Write/Edit fallback and gate rephrasing doctrine',
      'Machine-checkable criteria',
      'Review ownership — one unit, one review, single owner',
      'FAIL record (durable warning for future spawns)',
      'Continuing after a FAIL verdict',
    ],
    drop: [
      'WIP sentinel (mid-task handoff, not a bypass)',
      'Running acceptance-criteria commands (there is no self-wake)',
      'Retrieval contract',
      'Pending-review flag (default-mode review backstop)',
      'Third verdict: insufficient-context',
      'Fourth verdict: escalate-to-human',
      'A note on `memory`',
      'Microworld bundles (format and the check contract)',
    ],
  },
};

// Per-row, not per-union: a union check is vacuous the moment one row carries
// every section, and would pass a header quietly deleted from one persona's
// row while another row still witnesses it. Pure — reads no module state — so
// it can be exercised on synthetic headers.
function assertProtocolMatrixComplete(canonicalHeaders, matrix) {
  const quote = (headers) => headers.map((h) => `"${h}"`).join(', ');
  for (const name of Object.keys(matrix)) {
    const row = `PROTOCOL_SECTIONS_BY_PERSONA['${name}']`;
    const include = matrix[name].include || [];
    const drop = matrix[name].drop || [];
    const unknown = include.concat(drop).filter((h) => !canonicalHeaders.includes(h));
    if (unknown.length) {
      throw new Error(`${row} names sections absent from templates/persona-protocol.md: ${quote(unknown)}. Remove each from that row's include/drop lists, or restore the canonical heading.`);
    }
    const both = include.filter((h) => drop.includes(h));
    if (both.length) {
      throw new Error(`${row} lists the same section in both include and drop: ${quote(both)}. Keep each in exactly one of the two lists.`);
    }
    const uncovered = canonicalHeaders.filter((h) => !include.includes(h) && !drop.includes(h));
    if (uncovered.length) {
      throw new Error(`${row} does not classify every canonical section of templates/persona-protocol.md: ${quote(uncovered)}. Add each to that row's include or drop list.`);
    }
  }
}

// At load, so a matrix that no longer partitions the template makes bin/cli.js
// unloadable — no command can render a single mirror from a stale matrix.
assertProtocolMatrixComplete(CANONICAL_PROTOCOL_HEADERS, PROTOCOL_SECTIONS_BY_PERSONA);

// The short form a cross-reference actually names: header text up to its
// first ":", "(", or " — " separator, e.g. "WIP sentinel" for "WIP sentinel
// (mid-task handoff, not a bypass)" or "Third verdict" for "Third verdict:
// insufficient-context".
function headerReferenceKey(header) {
  const cut = header.search(/[:(]| — /);
  return (cut === -1 ? header : header.slice(0, cut)).trim();
}

// True if `text` names `header` the way 2.2's dangling references did:
// quoted (`"Third verdict"`), or the bare key phrase within ~50 characters of
// a positional "above"/"below" (`WIP sentinel described above`). The
// character window (rather than requiring the words to be adjacent) is what
// lets this survive markdown decoration like `**WIP sentinel**` between the
// key and the word that makes it a backward reference.
function sectionReferencesHeader(text, header) {
  const key = headerReferenceKey(header).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const joined = text.replace(/\s+/g, ' ');
  const quoted = new RegExp(`"${key}"`);
  const positional = new RegExp(`${key}.{0,50}?\\b(above|below)\\b`);
  return quoted.test(joined) || positional.test(joined);
}

// Rejects a row whose `include` set keeps a section that names — by the
// shape above — a header the SAME row `drop`s: "this persona keeps section
// X, but X's text references header Y, and Y is dropped for this persona."
// This is what turns 2.2's class of dangle into a load-time error instead of
// something a reviewer has to notice by hand. Takes parsed sections rather
// than reading canonicalProtocolText() itself, so it is pure and exercisable
// against a synthetic matrix in tests. Not exhaustive — a reference that
// names the DROPPED CONTENT without naming the header itself (e.g. "the cap
// below" instead of "Continuing after a FAIL verdict") is outside what a
// text-matching guard can see; those are caught by hand, same as today.
function assertNoDanglingCrossReferences(sections, matrix) {
  const textByHeader = new Map(sections.map((s) => [s.header, s.text]));
  for (const name of Object.keys(matrix)) {
    const include = matrix[name].include || [];
    const drop = matrix[name].drop || [];
    for (const kept of include) {
      const text = textByHeader.get(kept);
      if (text === undefined) continue;
      for (const dropped of drop) {
        if (sectionReferencesHeader(text, dropped)) {
          throw new Error(`PROTOCOL_SECTIONS_BY_PERSONA['${name}'] keeps "${kept}", whose text references "${dropped}" — but that row drops "${dropped}". Make the reference self-contained at the point it appears, or stop dropping the header.`);
        }
      }
    }
  }
}

// At load, alongside assertProtocolMatrixComplete: a row that keeps a
// section referencing a header it drops makes bin/cli.js unloadable, the
// same fail-closed shape as that check.
assertNoDanglingCrossReferences(CANONICAL_PROTOCOL_SECTIONS, PROTOCOL_SECTIONS_BY_PERSONA);

// A persona whose turns are gated always gets the two sections describing that
// gate, whatever its matrix row says — config wins, so the matrix cannot go
// stale against .claude/persona-config.json's gatedAgents.
const GATED_AGENT_SECTIONS = [
  'WIP sentinel (mid-task handoff, not a bypass)',
  'Pending-review flag (default-mode review backstop)',
];

// Renaming a canonical heading would leave these naming nothing, turning the
// force-include into a silent no-op — the one failure mode the matrix guard
// above cannot see, since these headers appear in no row's include list.
function assertGatedSectionsCanonical(canonicalHeaders, gatedSections) {
  const unknown = gatedSections.filter((h) => !canonicalHeaders.includes(h));
  if (unknown.length) {
    throw new Error(`GATED_AGENT_SECTIONS names sections absent from templates/persona-protocol.md: ${unknown.map((h) => `"${h}"`).join(', ')}. Update it to the current canonical heading, or the gatedAgents force-include silently stops applying.`);
  }
}

assertGatedSectionsCanonical(CANONICAL_PROTOCOL_HEADERS, GATED_AGENT_SECTIONS);

// What a project starts life with: lead-programmer's turns are gated by the
// stop hook. Shared by the scaffold's render loop and the config it writes, so
// the two cannot disagree.
const DEFAULT_GATED_AGENTS = ['lead-programmer'];

// A slim-tier persona's body is persona-protocol-slim.md wholesale, which
// carries neither gate section — so gating one would make the force-include
// above a silent no-op, the same fail-open shape the guards above exist to
// prevent. Checked at load for the scaffold default, and on every render for
// the project's own config (the only place a real gatedAgents list is known).
function assertGatedAgentsFullTier(gatedAgents) {
  const nonFull = (gatedAgents || []).filter((name) => protocolTierFor(name) !== 'full');
  if (nonFull.length) {
    throw new Error(`gatedAgents names non-full-tier persona(s) ${nonFull.map((n) => `"${n}"`).join(', ')}: their body is templates/persona-protocol-slim.md, which carries neither ${GATED_AGENT_SECTIONS.map((h) => `"${h}"`).join(' nor ')}, so the force-include cannot be honoured. Drop each from gatedAgents, or move that persona to the full protocol tier.`);
  }
}

assertGatedAgentsFullTier(DEFAULT_GATED_AGENTS);

// Fail-closed four ways: the slim tier throws rather than answer for a persona
// the renderer never consults it about; any other non-full tier is never
// trimmed; a persona with no matrix row gets every section; a row naming a
// header the template does not define throws, so renaming a canonical heading
// can never silently drop content from a persona. Headers in template order.
function selectProtocolSections(name, tier, gatedAgents) {
  if (tier === 'slim') {
    throw new Error(`selectProtocolSections('${name}') is undefined for the slim tier: a slim persona's protocol block is templates/persona-protocol-slim.md wholesale, so it carries none of templates/persona-protocol.md's sections and this function is never consulted for one.`);
  }
  const all = parseProtocolSections(canonicalProtocolText()).sections.map((s) => s.header);
  const row = PROTOCOL_SECTIONS_BY_PERSONA[name];
  if (tier !== 'full' || !row) return all;
  const wanted = row.include;
  for (const header of wanted) {
    if (!all.includes(header)) {
      throw new Error(`PROTOCOL_SECTIONS_BY_PERSONA['${name}'] names a section absent from templates/persona-protocol.md: "${header}"`);
    }
  }
  const forced = (gatedAgents || []).includes(name) ? GATED_AGENT_SECTIONS : [];
  return all.filter((h) => wanted.includes(h) || forced.includes(h));
}

// Appends the tier-appropriate protocol as a version-agnostic marked block to
// a persona body. Deterministic (source body carries no marker, the block is
// always rebuilt from the template), so re-running --update is idempotent.
// Mirrors the Codex `upsertMarkedBlock` inline mechanism (same marker names)
// but intentionally emits a version-less begin marker, unlike that function's
// `v${version}` one: this function always rebuilds the whole persona body
// from pristine source and never searches for its own prior marker, so a
// version number would serve no idempotency purpose here; the `.claude/`
// copy already carries its own top-of-file `<!-- antislop vX -->` stamp.
function inlineProtocolBlock(body, tier, name, gatedAgents) {
  assertGatedAgentsFullTier(gatedAgents);
  if (!tier) return body;
  let protocol;
  if (tier === 'slim') {
    protocol = fs.readFileSync(path.join(PKG_ROOT, 'templates', 'persona-protocol-slim.md'), 'utf8');
  } else {
    const { preamble, sections } = parseProtocolSections(canonicalProtocolText());
    const keep = selectProtocolSections(name, tier, gatedAgents);
    protocol = [preamble, ...sections.filter((s) => keep.includes(s.header)).map((s) => s.text)].join('\n');
  }
  protocol = protocol.replace(/\s+$/, '');
  const block = `${ANTISLOP_BLOCK_PREFIX} -->\n${protocol}\n${ANTISLOP_BLOCK_END}`;
  return `${body.replace(/\s+$/, '')}\n\n${block}\n`;
}

function renderCleanBody(spec, config) {
  let body = fs.readFileSync(spec.sourceAbsPath, 'utf8');
  if (spec.kind === 'raw') return body;
  if (spec.kind === 'graph') {
    body = applyMcpPlaceholder(
      body,
      '<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_4>',
      (config.substitutions || {}).graphMcpLaunch,
      spec.projectRelPath
    );
  } else if (spec.kind === 'arxiv') {
    const launch = (config.substitutions || {}).arxivMcpLaunch;
    if (launch === null || launch === undefined) {
      body = applyArxivFallback(body);
    } else {
      body = applyMcpPlaceholder(body, '<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_5>', launch, spec.projectRelPath);
    }
  }
  return inlineProtocolBlock(body, spec.protocolTier, path.basename(spec.projectRelPath, '.md'), config.gatedAgents);
}

function printUnifiedDiff(oldStr, newStr, label) {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-diff-'));
  const oldPath = path.join(tmpDir, 'current');
  const newPath = path.join(tmpDir, 'fresh');
  fs.writeFileSync(oldPath, oldStr);
  fs.writeFileSync(newPath, newStr);
  const result = spawnSync(
    'diff',
    ['-u', '--label', `${label} (current)`, '--label', `${label} (fresh)`, oldPath, newPath],
    { encoding: 'utf8' }
  );
  console.log(result.stdout || '(diff produced no textual output)');
  fs.rmSync(tmpDir, { recursive: true, force: true });
}

// OQ9=A auto-migration: strip the old global `@.claude/persona-protocol.md`
// import from CLAUDE.md (protocol is now inlined per-persona). Returns true if
// it removed the line, which forces the render loop below to re-inline bodies
// even at a matching pluginVersion.
// Under dryRun the write is suppressed but the return value is unchanged —
// it is both the report signal and the `migratedClaudeMd` term of the
// fast-path condition below, so an `if (!dryRun)` around the CALL would
// silently drop both.
function migrateGlobalProtocolImport(cwd, dryRun) {
  const p = path.join(cwd, 'CLAUDE.md');
  if (!fs.existsSync(p)) return false;
  const lines = fs.readFileSync(p, 'utf8').split('\n');
  const kept = lines.filter((l) => l.trim() !== '@.claude/persona-protocol.md');
  if (kept.length === lines.length) return false;
  if (!dryRun) fs.writeFileSync(p, kept.join('\n').replace(/\n+$/, '\n'));
  return true;
}

// Sites 10/11, the persona-config.json rewrite. The no-write predicate is just
// the serialized form compared against the bytes already on disk, so --dry-run
// never needs a speculative write to learn its own answer. Returns whether the
// file was (or would be) changed.
function writeConfigOrReport(configPath, config, dryRun) {
  const body = JSON.stringify(config, null, 2) + '\n';
  if (!dryRun) {
    fs.writeFileSync(configPath, body);
    return true;
  }
  if (fs.readFileSync(configPath, 'utf8') === body) return false;
  console.log('  .claude/persona-config.json: would be rewritten.');
  return true;
}

async function runUpdate(args) {
  // Flag surface first, before any output or write, so the deprecation warning
  // for the `--check` alias is genuinely the first thing the run prints.
  const dryRun = args.includes('--dry-run');
  // Set by every site that would change the tree. Under --dry-run this is the
  // whole exit code: 0 iff a live run would leave every path under the project
  // root byte- and mode-identical and create nothing, 3 otherwise. Stated over
  // the effect on the tree, not over an enumeration of summary phrases, so a
  // write site added later is visible to it by default rather than invisible.
  let wouldMutate = false;
  if (args.includes('--check') && !args.includes('--force-render')) {
    console.error(
      'WARNING: --check is deprecated and is NOT a dry-run — it writes files (it renders ' +
        'mirrors and rewrites persona-config.json). Use --force-render for the same behaviour ' +
        'under an honest name, or --dry-run for a genuine no-write report.'
    );
  }

  const version = readPluginVersion();
  const configPath = path.join(CWD, '.claude', 'persona-config.json');
  if (!fs.existsSync(configPath)) {
    console.log(
      'No .claude/persona-config.json found — this project was never adapted. Run ' +
        '/antislop:install-antislop (a fresh install) instead of --update.'
    );
    process.exit(1);
  }
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

  // Resolve how antislop is installed BEFORE the downgrade guard so the
  // refusal's recovery text can be tailored to it (issue #109 1b). Reused
  // later by the hooks-collision pass — computed once here, not twice.
  const pluginState = detectMarketplacePlugin('claude', CWD, os.homedir());

  // Downgrade guard (issue #102): refuse to resolve an OLDER plugin version
  // than the project's recorded pluginVersion — a stale scope registration
  // could otherwise silently downgrade persona files and stamp the version
  // backward. Must sit ahead of any file write (legacy-token migration,
  // render loop) so the refusal path mutates nothing.
  const isDowngrade = config.pluginVersion && compareSemver(version, config.pluginVersion) < 0;
  if (isDowngrade && !args.includes('--allow-downgrade')) {
    const recovery = pluginState.enabled
      ? 'Update the plugin first with `claude plugin update antislop@antislop-marketplace ' +
        `--scope <local|project|user>` + '` (enabled via ' + pluginState.source + '), or pass ' +
        '--allow-downgrade to proceed intentionally.'
      : 'This project is not on the marketplace plugin, so re-run its local install to get a ' +
        'current version first: re-run the `--plugin-dir <clone>` update against an up-to-date ' +
        'clone, or re-run the standalone `bin/cli.js` scaffold. Or pass --allow-downgrade to ' +
        'proceed intentionally.';
    console.error(
      `Refusing to downgrade: the resolved plugin version (v${version}) is OLDER than this ` +
        `project's recorded pluginVersion (v${config.pluginVersion}). This --update would ` +
        'stamp persona files backward, likely from a stale scope registration. ' +
        recovery
    );
    process.exit(1);
  }
  if (isDowngrade) {
    console.log(
      `Proceeding with intentional downgrade: resolved plugin version (v${version}) is older ` +
        `than the recorded pluginVersion (v${config.pluginVersion}) and --allow-downgrade was passed.`
    );
  }

  let personaSelection = config.personaSelection || [];
  const legacyTokens = legacyTokensIn(personaSelection);
  const hadLegacyToken = legacyTokens.length > 0;
  personaSelection = migrateLegacyPersonaTokens(personaSelection, { logNote: true });

  // --personas=<a,b,c> (issue #289): UNIONS the named tokens with the
  // recorded personaSelection, never replaces it — that replacement
  // semantics stays exclusive to the fresh-scaffold path below `main()`'s
  // `--update` early return. Note: --overwrite is never read on this path
  // either; main() returns runUpdate(args) before the scaffold path ever
  // parses --overwrite, so there is no interaction between the two flags to
  // design. Validated and exited on (before any write below, e.g. the
  // legacy-agent fs.unlinkSync just under this block) so an invalid token
  // writes nothing.
  const personasFlag = args.find((a) => a.startsWith('--personas='));
  if (personasFlag) {
    const requestedRaw = personasFlag.slice('--personas='.length).split(',').map((s) => s.trim()).filter(Boolean);
    const validTokens = OPTIONAL_PERSONAS.concat(['researcher'], CORE_PERSONAS);
    if (requestedRaw.length === 0) {
      console.error(`--personas= was given an empty value. Valid tokens: ${validTokens.join(', ')}.`);
      process.exit(1);
    }
    const requested = migrateLegacyPersonaTokens(requestedRaw, { logNote: true });
    const unknown = requested.filter((t) => !validTokens.includes(t));
    if (unknown.length > 0) {
      console.error(`Unknown --personas= token(s): ${unknown.join(', ')}. Valid tokens: ${validTokens.join(', ')}.`);
      process.exit(1);
    }
    for (const t of requested.filter((t) => CORE_PERSONAS.includes(t))) {
      console.log(`  personaSelection: "${t}" is a core persona (always installed) — --personas= is a no-op for it.`);
    }
    const recordable = OPTIONAL_PERSONAS.concat(['researcher']).filter((t) => requested.includes(t));
    for (const t of recordable.filter((t) => personaSelection.includes(t))) {
      console.log(`  personaSelection: "${t}" is already selected — --personas= is a no-op for it.`);
    }
    const added = recordable.filter((t) => !personaSelection.includes(t));
    if (added.length > 0) {
      personaSelection = personaSelection.concat(added);
      console.log(`  personaSelection: added ${added.join(', ')} (union with --personas=; nothing removed)`);
    }
    config.personaSelection = personaSelection;
  }

  if (hadLegacyToken) {
    config.personaSelection = personaSelection;
    for (const token of legacyTokens) {
      const legacyPath = path.join(CWD, '.claude', 'agents', `${token}.md`);
      if (!fs.existsSync(legacyPath)) continue;
      if (dryRun) {
        wouldMutate = true;
        console.log(`  .claude/agents/${token}.md: would be removed (legacy persona token)`);
      } else {
        fs.unlinkSync(legacyPath);
      }
    }
  }

  const migratedClaudeMd = migrateGlobalProtocolImport(CWD, dryRun);
  if (migratedClaudeMd && dryRun) {
    wouldMutate = true;
    console.log('  CLAUDE.md: would remove the legacy global @.claude/persona-protocol.md import (now delivered per-persona).');
  } else if (migratedClaudeMd) {
    console.log('  CLAUDE.md: removed the legacy global @.claude/persona-protocol.md import (now delivered per-persona).');
  }

  // Backfill .gitignore reach for the two dispatch-hygiene state files
  // (Step 5, token-hygiene-dispatch-gate) into already-adapted projects,
  // which a scaffold-list-only change would never reach.
  let gitignoreAdds = appendUnique(path.join(CWD, '.gitignore'), [
    '.claude/dispatch-audit.log',
    '.claude/.dispatch-override',
  ], dryRun);

  // Same reach problem for microworld bundles and human-review escalation
  // packets (Step 3a): without this, an already-adapted project sees both as
  // untracked noise and plausibly commits them.
  gitignoreAdds += appendUnique(path.join(CWD, '.gitignore'), [
    'microworlds/',
    '.claude/human-review/',
    '.claude/microworld-audit.log',
  ], dryRun);

  if (dryRun && gitignoreAdds > 0) {
    wouldMutate = true;
    console.log(`  .gitignore: ${gitignoreAdds} managed entry(ies) would be appended to it.`);
  }

  const specs = buildFileSpecs(personaSelection).concat(buildHookScriptSpecs());

  // Legacy backfill: derive whatever substitutions/fileHashes entries are
  // missing from what's already on disk — deterministic, zero LLM cost. Runs
  // unconditionally (cheap, idempotent no-op once fully populated) rather
  // than being gated behind an existence check, so it also fills gaps left
  // by a prior partial run (e.g. --wire-graph-mcp recorded graphMcpLaunch
  // but the arxiv MCP launch never got backfilled).
  // Captured BEFORE the backfill adopts them, so the note below can name the
  // hook scripts whose on-disk content is about to become their own baseline.
  const unbaselinedHooks = specs
    .filter((s) => s.kind === 'raw' && !((config.fileHashes || {})[s.projectRelPath]))
    .map((s) => s.projectRelPath)
    .filter((rel) => fs.existsSync(path.join(CWD, rel)));

  const backfilledSubs = backfillSubstitutionsFromDisk(config, specs);
  const backfilledHashes = backfillFileHashesFromDisk(config, specs);
  const backfilled = backfilledSubs || backfilledHashes;
  if (backfilled) {
    console.log(
      'Note: persona-config.json was missing some substitutions/fileHashes entries ' +
        '(this project predates plugin v0.6.4) — auto-backfilled what could be ' +
        'determined from the files already on disk, continuing at zero LLM cost. If you ' +
        'had hand-edited any persona files before now, diff against git history to confirm ' +
        'nothing was silently treated as "clean baseline" incorrectly by this one-time bootstrap.\n'
    );
  }
  if (unbaselinedHooks.length > 0) {
    console.log(
      `Note: ${unbaselinedHooks.length} hook script(s) had no recorded fileHashes baseline, so ` +
        'this one-time bootstrap adopts their current on-disk content as clean. A hand-edit made ' +
        'to any of them BEFORE this version is therefore refreshed to the packaged version ' +
        'without a divergence prompt (there is no earlier hash to compare against). Affected: ' +
        `${unbaselinedHooks.join(', ')}\n`
    );
  }

  // Detect/warn/dedupe pass for stale standalone hook registrations that
  // collide with the marketplace plugin (issue #76). Runs on every --update,
  // BEFORE the version-match fast-path below, so a project already current
  // on persona files still gets warned/deduped about stale hooks. Separate
  // from the fileHashes/pending/--accept/--keep machinery below — this pass
  // operates on JSON settings, not stamped .md content.
  const dedupeHooks = args.includes('--dedupe-hooks');
  const settingsPath = path.join(CWD, '.claude', 'settings.json');
  let settings = null;
  try {
    if (fs.existsSync(settingsPath)) settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
  } catch (_) {
    settings = null; // malformed -> best-effort, treat as no standalone hooks
  }
  const standaloneHooks = settings ? findStandaloneHookRegistrations(settings) : [];
  const hooksCollision = pluginState.enabled && standaloneHooks.length > 0;

  if (hooksCollision && dedupeHooks && dryRun) {
    wouldMutate = true;
    console.log(
      `  .claude/settings.json: would remove ${standaloneHooks.length} standalone antislop hook ` +
        `registration(s) (the marketplace plugin, enabled per ${pluginState.source}, already ` +
        'provides them via ${CLAUDE_PLUGIN_ROOT}).'
    );
  } else if (hooksCollision && dedupeHooks) {
    const cleaned = stripStandaloneHookRegistrations(settings);
    fs.writeFileSync(settingsPath, JSON.stringify(cleaned, null, 2) + '\n');
    console.log(
      `  Removed ${standaloneHooks.length} standalone antislop hook registration(s) from ` +
        `.claude/settings.json (the marketplace plugin, enabled per ${pluginState.source}, ` +
        'already provides them via ${CLAUDE_PLUGIN_ROOT}). Duplicate hook firing ("Ran 2 stop ' +
        'hooks") resolved.'
    );
  } else if (hooksCollision) {
    console.log(
      `  NOTE: antislop is enabled via the marketplace plugin (${pluginState.source}) AND ` +
        `.claude/settings.json still carries ${standaloneHooks.length} standalone antislop hook ` +
        'registration(s) from a pre-guard install — every hook fires twice ("Ran 2 stop hooks"). ' +
        'Re-run with --dedupe-hooks to remove the standalone registrations (the plugin keeps ' +
        'providing them). If you intentionally want BOTH active, do nothing.'
    );
  } else if (dedupeHooks && standaloneHooks.length > 0 && !pluginState.enabled) {
    console.log(
      '  --dedupe-hooks: the marketplace plugin is NOT enabled for this project, so the ' +
        'standalone hook registrations are the ONLY ones present — leaving them in place ' +
        '(removing them would disable all hooks). Nothing removed.'
    );
  }

  // Registration backfill: a project adapted before a hook existed never got
  // its hooks.json entry, so the script would sit inert even once the file
  // above lands. Adds only what's missing (mergeNestedHooksJson dedupes by
  // matcher then by entry). Skipped entirely when the marketplace plugin is
  // enabled — it already provides every registration via ${CLAUDE_PLUGIN_ROOT},
  // and merging on top is the "Ran 2 stop hooks" double-fire (issue #76).
  if (settings && !pluginState.enabled) {
    const merged = mergeNestedHooksJson(JSON.parse(JSON.stringify(settings)), readStandaloneHooksConfig());
    if (JSON.stringify(merged.hooks) !== JSON.stringify(settings.hooks)) {
      if (!dryRun) fs.writeFileSync(settingsPath, JSON.stringify(merged, null, 2) + '\n');
      const added = findStandaloneHookRegistrations(merged).length - standaloneHooks.length;
      // Kept even under --dry-run: suppress the write, not the computation, so
      // anything reading `settings` below sees a state a real run also has.
      settings = merged;
      if (dryRun) wouldMutate = true;
      console.log(
        `  .claude/settings.json: ${dryRun ? 'would add' : 'added'} ${added} missing antislop hook ` +
          'registration(s) — a hook script that ships with this version but was never registered ' +
          'by the original install would otherwise sit on disk and never fire.'
      );
    }
  }

  // Forces the render/diff loop to run even when nothing else above tripped
  // it — the version-match fast-path otherwise means a plain --update can
  // never detect per-file drift (hand-edits, corruption) once pluginVersion
  // already matches. `--check` is the deprecated alias for the same thing
  // (warned about at the top of this function); `--dry-run` implies it, since
  // a dry run that fast-paths out reports nothing.
  const forceRender = args.includes('--force-render') || args.includes('--check') || dryRun;

  // Pre-scan (Step 3, cli-stale-version-stamp-fix, Layer 1 of the two-layer
  // bug): detect a MISSING or stale-stamped managed destination BEFORE the
  // fast-path below, so a project whose persona files are already
  // content-clean but still carry an outdated stamp — or whose mirror was
  // deleted outright — doesn't bail out before ever reaching the per-file
  // loop that recreates/refreshes it (Layer 2, #170, `:730` above). Absence
  // used to be skipped here, which meant --update reported "already current"
  // for a deleted managed file and never self-healed it. Read-only — never
  // writes; the render loop's own !fs.existsSync branch does the creating.
  let needsRender = false;
  for (const spec of specs) {
    const destAbsPath = path.join(CWD, spec.projectRelPath);
    if (!fs.existsSync(destAbsPath)) {
      needsRender = true;
      break;
    }
    let body;
    try {
      body = fs.readFileSync(destAbsPath, 'utf8');
    } catch (_) {
      continue;
    }
    // Hook scripts carry no stamp, so content drift against the packaged
    // source is the only signal that a patched gate has yet to land.
    if (spec.kind === 'raw') {
      if (body !== fs.readFileSync(spec.sourceAbsPath, 'utf8')) {
        needsRender = true;
        break;
      }
      // Also check if the stored hash is stale — mirror may match source but
      // hash was never updated by writeSpecBody. Force a full loop run so it
      // can be healed.
      const recordedHash = config.fileHashes[spec.projectRelPath];
      if (recordedHash && sha256Hex(body) !== recordedHash) {
        needsRender = true;
        break;
      }
      continue;
    }
    if (stampVersionOf(body) !== version) {
      needsRender = true;
      break;
    }
  }

  if (config.pluginVersion === version && !hadLegacyToken && !backfilled && !forceRender && !migratedClaudeMd && !needsRender) {
    console.log(`antislop v${version} — already current in ${CWD}. Nothing to update.`);
    return;
  }

  const acceptFlag = args.find((a) => a.startsWith('--accept='));
  const keepFlag = args.find((a) => a.startsWith('--keep='));
  const acceptList = acceptFlag ? acceptFlag.slice('--accept='.length).split(',').map((s) => s.trim()) : [];
  const keepList = keepFlag ? keepFlag.slice('--keep='.length).split(',').map((s) => s.trim()) : [];
  const acceptAll = acceptList.includes('all');
  const keepAll = keepList.includes('all');

  const newFileHashes = Object.assign({}, config.fileHashes);
  const pending = [];
  const unresolvedRender = [];
  const summary = [];

  for (const spec of specs) {
    let cleanBody;
    try {
      cleanBody = renderCleanBody(spec, config);
    } catch (err) {
      unresolvedRender.push({ relKey: spec.projectRelPath, message: err.message });
      continue;
    }
    const cleanHash = sha256Hex(cleanBody);
    const destAbsPath = path.join(CWD, spec.projectRelPath);
    const relKey = spec.projectRelPath;

    if (!fs.existsSync(destAbsPath)) {
      if (dryRun) wouldMutate = true;
      else writeSpecBody(spec, destAbsPath, cleanBody, version);
      newFileHashes[relKey] = cleanHash;
      summary.push(`  ${relKey}: ${dryRun ? 'would be created' : 'created'}`);
      continue;
    }

    const currentBody = fs.readFileSync(destAbsPath, 'utf8');
    const currentStripped = stripStamp(currentBody);
    const recordedHash = config.fileHashes[relKey];
    const noLocalEdits = Boolean(recordedHash) && sha256Hex(currentStripped) === recordedHash;

    if (noLocalEdits && cleanHash === recordedHash) {
      const currentStampVersion = stampVersionOf(currentBody);
      if (spec.kind !== 'raw' && currentStampVersion !== version) {
        if (dryRun) wouldMutate = true;
        else copyStampedBody(destAbsPath, cleanBody, version, spec.sourceRelPath);
        newFileHashes[relKey] = cleanHash;
        summary.push(
          `  ${relKey}: stamp ${dryRun ? 'would be refreshed' : 'refreshed'} (${currentStampVersion === null ? 'absent' : `v${currentStampVersion}`} -> v${version}, content unchanged)`
        );
      } else {
        summary.push(`  ${relKey}: already current`);
      }
      continue;
    }

    if (noLocalEdits) {
      if (dryRun) wouldMutate = true;
      else writeSpecBody(spec, destAbsPath, cleanBody, version);
      newFileHashes[relKey] = cleanHash;
      summary.push(`  ${relKey}: ${dryRun ? 'would be updated' : 'updated'} (no local edits detected)`);
      continue;
    }

    // Even if recordedHash is stale, if the actual current content already
    // matches a fresh clean regeneration, there's no real divergence — just
    // silently heal the stale hash and move on.
    if (currentStripped === cleanBody) {
      newFileHashes[relKey] = cleanHash;
      summary.push(`  ${relKey}: hash ${dryRun ? 'would be healed' : 'healed'} (content unchanged, hash was stale)`);
      continue;
    }

    if (acceptAll || acceptList.includes(relKey)) {
      if (dryRun) wouldMutate = true;
      else writeSpecBody(spec, destAbsPath, cleanBody, version);
      newFileHashes[relKey] = cleanHash;
      summary.push(`  ${relKey}: ${dryRun ? 'would be overwritten' : 'overwritten'} (--accept)`);
    } else if (keepAll || keepList.includes(relKey)) {
      // Deliberately do NOT touch newFileHashes[relKey] here — it must stay
      // pointed at the original no-local-edits baseline. Rebasing it to the
      // current (customized) content would make a LATER version bump whose
      // upstream content happens to stop changing look "no local edits
      // detected" relative to that rebased hash, silently overwriting the
      // very customization --keep was just asked to preserve. Leaving the
      // baseline alone means this file keeps getting flagged (and asked
      // about) on every future drift, which is the safe default — "never
      // silently clobber a local edit" — even though it costs a repeat ask.
      summary.push(`  ${relKey}: ${dryRun ? 'would be kept as-is' : 'kept as-is'} (local edits preserved; will be re-flagged on future drift)`);
    } else {
      pending.push({ relKey, currentStripped, cleanBody });
    }
  }

  if (pending.length > 0) {
    if (dryRun) wouldMutate = true;
    console.log(
      `\n${pending.length} file(s) ${dryRun ? 'would be pending a decision — they have' : 'have'} ` +
        'diverged from a fresh copy:\n'
    );
    for (const p of pending) {
      console.log(`--- ${p.relKey} ---`);
      printUnifiedDiff(p.currentStripped, p.cleanBody, p.relKey);
      console.log('');
    }
  }

  if (pending.length > 0 || unresolvedRender.length > 0) {
    config.fileHashes = pruneStaleFileHashes(newFileHashes, specs);
    writeConfigOrReport(configPath, config, dryRun);
    console.log(summary.join('\n'));
    if (pending.length > 0) {
      console.log(
        `\n${pending.length} file(s) pending. Re-run with --accept=<path,path> (overwrite with the ` +
          'regenerated version) or --keep=<path,path> (keep local edits for now — you will be asked ' +
          'again on the next drift, by design) for each — or --accept=all / --keep=all.'
      );
    }
    if (unresolvedRender.length > 0) {
      console.log(`\n${unresolvedRender.length} file(s) could not be rendered — missing substitution data:\n`);
      for (const u of unresolvedRender) console.log(`  ${u.relKey}: ${u.message}`);
    }
    console.log('\npluginVersion stays unbumped until every file above is resolved.');
    if (unresolvedRender.length > 0) process.exit(1);
    process.exit(dryRun ? 3 : 2);
  }

  config.fileHashes = pruneStaleFileHashes(newFileHashes, specs);
  config.pluginVersion = version;
  if (writeConfigOrReport(configPath, config, dryRun)) wouldMutate = true;

  console.log(
    dryRun
      ? `antislop v${version} — dry run in ${CWD}, nothing written:\n`
      : `antislop v${version} — update complete in ${CWD}:\n`
  );
  console.log(summary.join('\n'));

  const leftover = specs
    .map((s) => path.join(CWD, s.projectRelPath))
    .filter((p) => fs.existsSync(p) && PLACEHOLDER_RE.test(fs.readFileSync(p, 'utf8')));
  if (leftover.length > 0) {
    console.log(
      `\nWARNING: unresolved placeholder(s) remain in: ${leftover.join(', ')} — this should not ` +
        "happen after a clean --update; inspect persona-config.json's substitutions field."
    );
  }

  if (dryRun && wouldMutate) process.exit(3);
}

async function runWireMcp(kind, args) {
  const targetFlag = args.find((a) => a.startsWith('--target='));
  const wireTarget = targetFlag ? targetFlag.slice('--target='.length).trim() : 'claude';
  if (wireTarget !== 'claude' && wireTarget !== 'codex') {
    console.error(`antislop --wire-${kind}-mcp failed: unknown --target=${wireTarget} (supported: claude, codex).`);
    process.exit(1);
  }
  if (wireTarget === 'codex' && kind === 'arxiv') {
    console.error(
      'antislop --wire-arxiv-mcp --target=codex failed: the researcher persona is not part of ' +
        "the Codex MVP port (see docs/specs/codex-plugin.md §11) - there's no researcher.toml to wire yet."
    );
    process.exit(1);
  }

  const mcpJsonPath = path.join(CWD, '.mcp.json');
  if (!fs.existsSync(mcpJsonPath)) {
    console.error(`antislop --wire-${kind}-mcp failed: no .mcp.json found at ${mcpJsonPath}.`);
    process.exit(1);
  }
  const mcpJson = JSON.parse(fs.readFileSync(mcpJsonPath, 'utf8'));
  const servers = mcpJson.mcpServers || {};

  let serverKey;
  let targetFile;
  let placeholder;
  let substitutionField;
  if (kind === 'graph') {
    serverKey = 'code-review-graph';
    targetFile =
      wireTarget === 'codex'
        ? path.join(CWD, '.codex', 'agents', 'explorer.toml')
        : path.join(CWD, '.claude', 'agents', 'explorer.md');
    placeholder = '<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_4>';
    substitutionField = 'graphMcpLaunch';
  } else {
    const keyFlag = args.find((a) => a.startsWith('--wire-arxiv-mcp='));
    serverKey = keyFlag ? keyFlag.slice('--wire-arxiv-mcp='.length) : null;
    if (!serverKey) {
      console.error(
        'antislop --wire-arxiv-mcp requires =<server-key-in-.mcp.json>, e.g. ' +
          '--wire-arxiv-mcp=arxiv-mcp-server'
      );
      process.exit(1);
    }
    targetFile = path.join(CWD, '.claude', 'agents', 'researcher.md');
    placeholder = '<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_5>';
    substitutionField = 'arxivMcpLaunch';
  }

  const entry = servers[serverKey];
  if (!entry) {
    console.error(
      `antislop --wire-${kind}-mcp failed: no "${serverKey}" entry in .mcp.json's mcpServers. ` +
        `Found: ${Object.keys(servers).join(', ') || '(none)'}`
    );
    process.exit(1);
  }
  if (!fs.existsSync(targetFile)) {
    console.error(`antislop --wire-${kind}-mcp failed: ${targetFile} does not exist yet — scaffold it first.`);
    process.exit(1);
  }

  const launch = { command: entry.command, args: entry.args || [] };
  if (entry.env && Object.keys(entry.env).length > 0) launch.env = entry.env;

  let body = fs.readFileSync(targetFile, 'utf8');
  if (!body.includes(placeholder)) {
    console.log(`  ${targetFile} has no ${placeholder} placeholder left — already wired, nothing to do.`);
  } else {
    body =
      wireTarget === 'codex'
        ? applyMcpTomlPlaceholder(body, placeholder, launch, targetFile)
        : applyMcpPlaceholder(body, placeholder, launch, targetFile);
    fs.writeFileSync(targetFile, body);
    console.log(`  ${targetFile}: inlined ${serverKey}'s launch command from .mcp.json.`);
  }

  delete servers[serverKey];
  mcpJson.mcpServers = servers;
  fs.writeFileSync(mcpJsonPath, JSON.stringify(mcpJson, null, 2) + '\n');
  console.log(
    `  .mcp.json: removed the project-wide "${serverKey}" entry (rescoped to ` +
      `${path.basename(targetFile)} alone).`
  );

  // Written regardless of whether persona-config.json exists yet: this
  // command deletes the .mcp.json entry it just consumed, so it can't be
  // re-run later to backfill the substitution once step 6 creates the full
  // config — record it now, as a partial file if necessary, and step 6
  // MERGES into it (preserving this key) rather than overwriting wholesale.
  const configPath =
    wireTarget === 'codex'
      ? path.join(CWD, '.codex', 'persona-config.json')
      : path.join(CWD, '.claude', 'persona-config.json');
  let config = {};
  if (fs.existsSync(configPath)) {
    config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  } else {
    mkdirp(path.dirname(configPath));
  }
  config.substitutions = config.substitutions || {};
  config.substitutions[substitutionField] = launch;
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');
  console.log(`  ${wireTarget === 'codex' ? '.codex' : '.claude'}/persona-config.json: substitutions.${substitutionField} recorded.`);

  console.log(
    `\nDone. Verify the connection works: spawn the ${
      kind === 'graph' ? 'explorer' : 'researcher'
    } with one real query and confirm it self-reports the answer as MCP-derived, not a grep/WebFetch fallback.`
  );
}

// ---------------------------------------------------------------------------
// --target=cursor: scaffold the Cursor adapter (adapters/cursor/) into a
// project's .cursor/ directory. This is the Cursor-port sibling of the default
// (implicit --target=claude) flow above. It ships only the MVP four personas
// (orchestrator/explorer/lead-programmer/reviewer), the shared persona-protocol
// rule, and the ported enforcement hooks - agent-teams mode, the optional
// personas, and per-agent tool/turn/MCP/memory scoping are dropped or degraded
// on Cursor (see docs/cursor-port-notes.md). It reuses the same "merge, never
// clobber" discipline: hooks.json is deep-merged, and on --overwrite the
// judgment-driven persona-config fields are preserved, exactly like the Claude
// path.
// ---------------------------------------------------------------------------

const CURSOR_MVP_PERSONAS = ['orchestrator', 'explorer', 'lead-programmer', 'reviewer'];

async function scaffoldCursor(args) {
  const version = readPluginVersion();
  const overwrite = args.includes('--overwrite');
  const forceHooks = args.includes('--force-hooks');
  const cursorSrc = path.join(PKG_ROOT, 'adapters', 'cursor');
  console.log(`antislop v${version} (Cursor target) — scaffolding into ${CWD}\n`);

  const cursorDir = path.join(CWD, '.cursor');
  const configPath = path.join(cursorDir, 'persona-config.json');
  let existingConfig = null;
  if (fs.existsSync(configPath)) {
    if (!overwrite) {
      console.log(
        'A .cursor/persona-config.json already exists here — this looks like an ' +
          'existing Cursor install, not a fresh one. This CLI only does fresh ' +
          'scaffolding; re-run with --overwrite to re-copy the mechanical files ' +
          '(agents, hooks, rule, protocol) unconditionally while preserving your ' +
          'judgment-driven config fields. Exiting without changes.'
      );
      process.exit(1);
    }
    existingConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    console.log(
      '--overwrite: existing Cursor install found — re-copying agents/hooks/rule/' +
        'protocol unconditionally. persona-config.json\'s judgment-driven fields ' +
        '(testAndLintCommand, protectedPaths, etc.) are preserved; only ' +
        'pluginVersion/personaSelection are refreshed.\n'
    );
  }

  const agentsDir = path.join(cursorDir, 'agents');
  const scriptsDir = path.join(cursorDir, 'hooks', 'scripts');
  const rulesDir = path.join(cursorDir, 'rules');
  mkdirp(agentsDir);
  mkdirp(scriptsDir);
  mkdirp(rulesDir);
  mkdirp(path.join(cursorDir, 'reviewed'));
  mkdirp(path.join(cursorDir, 'memory'));

  for (const name of CURSOR_MVP_PERSONAS) {
    copyStamped(
      path.join(cursorSrc, 'agents', `${name}.md`),
      path.join(agentsDir, `${name}.md`),
      version,
      `adapters/cursor/agents/${name}.md`
    );
    console.log(`  adapters/cursor/agents/${name}.md -> .cursor/agents/${name}.md`);
  }

  copyStamped(
    path.join(cursorSrc, 'rules', 'persona-protocol.mdc'),
    path.join(rulesDir, 'persona-protocol.mdc'),
    version,
    'adapters/cursor/rules/persona-protocol.mdc'
  );
  console.log('  adapters/cursor/rules/persona-protocol.mdc -> .cursor/rules/persona-protocol.mdc (alwaysApply rule)');

  copyDirRecursive(path.join(cursorSrc, 'hooks', 'scripts'), scriptsDir);
  console.log('  adapters/cursor/hooks/scripts/*.sh -> .cursor/hooks/scripts/');

  // hooks.json: rewrite the plugin-root placeholder to a project-relative path,
  // then deep-merge into any existing .cursor/hooks.json (merge, not clobber).
  const rawHooks = fs.readFileSync(path.join(cursorSrc, 'hooks', 'hooks.json'), 'utf8');
  const hooksConfig = JSON.parse(
    rawHooks.replace(/\$\{CURSOR_PLUGIN_ROOT\}\/hooks\/scripts/g, '.cursor/hooks/scripts')
  );
  const hooksPath = path.join(cursorDir, 'hooks.json');
  let hooks = { version: 1, hooks: {} };
  if (fs.existsSync(hooksPath)) {
    hooks = JSON.parse(fs.readFileSync(hooksPath, 'utf8'));
  }
  // Same coexistence guard as the claude target (issue #68), wired here for
  // uniformity. detectMarketplacePlugin always returns enabled:false for
  // 'cursor' (see its own no-op comment, issue #67 — no antislop marketplace
  // plugin-enable distribution exists for cursor), so this is a documented
  // no-op: the else branch below always runs today.
  const pluginState = detectMarketplacePlugin('cursor', CWD, os.homedir());
  if (pluginState.enabled && !forceHooks) {
    console.log(
      `  Hook registration SKIPPED — antislop is already enabled via the marketplace ` +
        `plugin (detected in ${pluginState.source}). Re-run with --force-hooks to merge anyway.`
    );
  } else {
    // Idempotent, dedupe-aware merge: the generic deepMerge appends array items
    // by reference equality, so identical `{command: ...}` objects would
    // duplicate on every --overwrite re-run (each fires the same hook twice).
    // Dedupe per-event by the entry's JSON so a re-run is a no-op while any
    // user-added hook entries are preserved.
    hooks.version = hooks.version || hooksConfig.version || 1;
    hooks.hooks = hooks.hooks || {};
    for (const [event, entries] of Object.entries(hooksConfig.hooks || {})) {
      const existing = hooks.hooks[event] || [];
      const seen = new Set(existing.map((e) => JSON.stringify(e)));
      for (const entry of entries) {
        const key = JSON.stringify(entry);
        if (!seen.has(key)) {
          existing.push(entry);
          seen.add(key);
        }
      }
      hooks.hooks[event] = existing;
    }
    fs.writeFileSync(hooksPath, JSON.stringify(hooks, null, 2) + '\n');
    console.log('  .cursor/hooks.json updated (version 1, camelCase events; merge, not overwrite)');
  }

  if (existingConfig) {
    existingConfig.personaSelection = CURSOR_MVP_PERSONAS.slice();
    warnIfDowngradeStamp(existingConfig.pluginVersion, version, '.cursor/persona-config.json');
    existingConfig.pluginVersion = version;
    if (!existingConfig.mainAgent) existingConfig.mainAgent = 'orchestrator';
    if (!existingConfig.gatedAgents) existingConfig.gatedAgents = ['lead-programmer'];
    fs.writeFileSync(configPath, JSON.stringify(existingConfig, null, 2) + '\n');
    console.log('  .cursor/persona-config.json: personaSelection + pluginVersion refreshed, other fields preserved');
  } else {
    const personaConfig = {
      target: 'cursor',
      testAndLintCommand: '',
      lintCommand: '',
      graphUpdateCommand: '',
      sourceGlobs: [],
      protectedPaths: [],
      gatedAgents: ['lead-programmer'],
      // Cursor has no settings.json "agent" key; stop-gate.sh reads this to
      // know which name to treat as the (gated-or-not) main agent.
      mainAgent: 'orchestrator',
      pluginVersion: version,
      personaSelection: CURSOR_MVP_PERSONAS.slice(),
      issueTracker: '',
    };
    fs.writeFileSync(configPath, JSON.stringify(personaConfig, null, 2) + '\n');
    console.log('  .cursor/persona-config.json written (skeleton — fill in test/lint/graph/protected fields against this repo)');
  }

  appendUnique(path.join(CWD, '.gitignore'), [
    '.cursor/reviewed/',
    '.cursor/wip-handoff.*',
    '.cursor/.session-baseline.*',
    '.cursor/wip-audit.log',
    '.cursor/.pending-review.*',
    '.cursor/review-audit.log',
    '.cursor/dispatch-audit.log',
    '.cursor/.dispatch-override',
    'microworlds/',
    '.cursor/human-review/',
    '.cursor/microworld-audit.log',
  ]);
  console.log('  .gitignore updated');

  console.log(
    '\nDone with the mechanical Cursor scaffolding.\n\n' +
      'Verify/finish by hand (Cursor-specific caveats, see docs/cursor-port-notes.md):\n' +
      '  1. The persona-protocol rule reaching SUBAGENTS is UNVERIFIED on Cursor;\n' +
      '     the load-bearing invariants are inlined into each subagent body as a\n' +
      '     backstop, but confirm the rule loads for the main agent at least.\n' +
      '  2. .cursor/hooks.json commands use project-relative paths — confirm Cursor\n' +
      '     resolves hook commands relative to the workspace root on your setup.\n' +
      '  3. Fill in .cursor/persona-config.json (testAndLintCommand, sourceGlobs,\n' +
      '     protectedPaths, graphUpdateCommand) for THIS repo.\n' +
      '  4. If you use the Code Review Graph, register it PROJECT-WIDE in\n' +
      '     .cursor/mcp.json (Cursor has no per-agent MCP scoping).\n' +
      '  5. Optionally set opus/cheap model ids in the reviewer/explorer frontmatter\n' +
      '     (currently `inherit` — the tier mapping is a project decision).'
  );
}

// ---------------------------------------------------------------------------
// --target=codex: scaffold the Codex adapter (adapters/codex/) into a
// project's .codex/ directory, plus inline the shared persona-protocol into
// AGENTS.md (Codex has no @import/include mechanism, so - like Claude, which
// physically inlines the protocol per persona - the content must be
// physically inlined). Same MVP four personas as the Cursor port. See
// docs/specs/codex-plugin.md for the design this implements and
// docs/codex-port-notes.md for what shipped degraded/unverified. Codex is
// the one ported platform that keeps PER-AGENT MCP SCOPING (the Code Review
// Graph stays scoped to the explorer alone, unlike Cursor's project-wide
// fallback) - see explorer.toml.
// ---------------------------------------------------------------------------

const CODEX_MVP_PERSONAS = ['orchestrator', 'explorer', 'lead-programmer', 'reviewer'];
const ANTISLOP_BLOCK_PREFIX = '<!-- ANTISLOP:BEGIN persona-protocol';
const ANTISLOP_BLOCK_END = '<!-- ANTISLOP:END persona-protocol -->';

// Version-agnostic upsert: searches by the marker PREFIX (no version), not
// the full begin line, so a later version's block finds and replaces an
// earlier version's block rather than accumulating duplicates. Everything
// outside the marked span is left untouched - "merge, never clobber" applied
// to a single file's content instead of a JSON object.
function upsertMarkedBlock(filePath, version, content) {
  const beginLine = `${ANTISLOP_BLOCK_PREFIX} v${version} -->`;
  const block = `${beginLine}\n${content}\n${ANTISLOP_BLOCK_END}`;
  if (!fs.existsSync(filePath)) {
    mkdirp(path.dirname(filePath));
    fs.writeFileSync(filePath, block + '\n');
    return 'created';
  }
  const existing = fs.readFileSync(filePath, 'utf8');
  const beginIdx = existing.indexOf(ANTISLOP_BLOCK_PREFIX);
  if (beginIdx === -1) {
    const sep = existing.length > 0 && !existing.endsWith('\n') ? '\n\n' : '\n';
    fs.writeFileSync(filePath, existing + sep + block + '\n');
    return 'appended';
  }
  const endIdx = existing.indexOf(ANTISLOP_BLOCK_END, beginIdx);
  if (endIdx === -1) {
    throw new Error(
      `${filePath} has a "${ANTISLOP_BLOCK_PREFIX}" marker with no matching ` +
        `"${ANTISLOP_BLOCK_END}" - manual conflict, refusing to guess. Resolve by hand.`
    );
  }
  const before = existing.slice(0, beginIdx);
  const after = existing.slice(endIdx + ANTISLOP_BLOCK_END.length);
  fs.writeFileSync(filePath, before + block + after);
  return 'replaced';
}

const MARKETPLACE_PLUGIN_KEY = 'antislop@antislop-marketplace';

// Detects whether antislop is already enabled via the Claude Code
// marketplace plugin (enabledPlugins["antislop@antislop-marketplace"] ===
// true, strict), which auto-loads hooks.json and would otherwise collide
// with this CLI's own standalone hook registration for the same target.
// Side-effect-free; best-effort — any absent/unreadable/malformed candidate
// file counts as not-enabled rather than throwing.
function detectMarketplacePlugin(target, cwd, homeDir) {
  if (target !== 'claude') {
    // No antislop marketplace/plugin-enable distribution exists for cursor
    // or codex - the standalone CLI scaffold is the ONLY hook-registration
    // path for those targets, so the double-registration collision this
    // guard exists for is structurally impossible there. Kept as an
    // explicit, always-false no-op (never scans) for uniformity across
    // targets rather than silently omitted.
    return { enabled: false, source: null,
      reason: `no marketplace plugin-enable mechanism for target '${target}'` };
  }
  // Claude Code precedence, HIGHEST scope first (settings.md "How Scopes
  // Interact"): Local > Project > User. enabledPlugins deep-merges per-key
  // with higher scope winning, so the first file that sets the key to an
  // explicit true or false decides; an absent (or non-boolean) key falls
  // through to the next-lower scope.
  const candidates = [
    path.join(cwd, '.claude', 'settings.local.json'),
    path.join(cwd, '.claude', 'settings.json'),
    path.join(homeDir, '.claude', 'settings.json'),
  ];
  for (const file of candidates) {
    let val;
    try {
      if (!fs.existsSync(file)) continue;
      const json = JSON.parse(fs.readFileSync(file, 'utf8'));
      if (json && json.enabledPlugins &&
          Object.prototype.hasOwnProperty.call(json.enabledPlugins, MARKETPLACE_PLUGIN_KEY)) {
        val = json.enabledPlugins[MARKETPLACE_PLUGIN_KEY];
      }
    } catch (_) { continue; /* malformed/unreadable -> key not set here */ }
    if (val === true) return { enabled: true, source: file, reason: null };
    if (val === false) return { enabled: false, source: null,
      reason: `explicitly disabled at ${file} (higher-precedence scope)` };
  }
  return { enabled: false, source: null, reason: null };
}

// The exact prefix the standalone installer rewrites hook commands to
// (bin/cli.js scaffold: ${CLAUDE_PLUGIN_ROOT}/hooks/scripts -> this). Already
// the test harness's HOOK_MARKER (tests/cli-backfill.test.js:355).
const STANDALONE_HOOK_PATH_MARKER = '${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts/';

// The packaged hooks.json with plugin-root paths rewritten to the standalone
// location — the exact registration set a non-plugin project should carry.
function readStandaloneHooksConfig() {
  const raw = fs.readFileSync(path.join(PKG_ROOT, 'hooks', 'hooks.json'), 'utf8');
  return JSON.parse(raw.replace(/\$\{CLAUDE_PLUGIN_ROOT\}\/hooks\/scripts/g, '${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts'));
}

// Returns an array describing every standalone antislop hook registration
// found in settings.hooks, e.g. [{ event, matcher, script }]. Pure,
// best-effort: tolerates a missing/malformed/non-object hooks shape by
// returning []. Never throws.
function findStandaloneHookRegistrations(settings) {
  const found = [];
  const hooks = settings && settings.hooks;
  if (!hooks || typeof hooks !== 'object') return found;
  for (const event of Object.keys(hooks)) {
    const groups = Array.isArray(hooks[event]) ? hooks[event] : [];
    for (const group of groups) {
      const entries = group && Array.isArray(group.hooks) ? group.hooks : [];
      for (const entry of entries) {
        if (entry && typeof entry.command === 'string' &&
            entry.command.includes(STANDALONE_HOOK_PATH_MARKER)) {
          found.push({ event, matcher: group.matcher || null,
            script: entry.command.split('/').pop() });
        }
      }
    }
  }
  return found;
}

// Returns a NEW (deep-cloned) settings object with every marker-matched
// standalone antislop hook entry removed, plus now-empty matcher-groups and
// now-empty event arrays pruned; the hooks key is deleted entirely if it
// becomes empty. Every other key is preserved untouched. Pure - does not
// mutate its input, does no I/O.
function stripStandaloneHookRegistrations(settings) {
  const clone = JSON.parse(JSON.stringify(settings));
  const hooks = clone.hooks;
  if (!hooks || typeof hooks !== 'object') return clone;
  for (const event of Object.keys(hooks)) {
    const groups = Array.isArray(hooks[event]) ? hooks[event] : [];
    for (const group of groups) {
      if (group && Array.isArray(group.hooks)) {
        group.hooks = group.hooks.filter((e) =>
          !(e && typeof e.command === 'string' &&
            e.command.includes(STANDALONE_HOOK_PATH_MARKER)));
      }
    }
    hooks[event] = groups.filter((g) => !(g && Array.isArray(g.hooks) && g.hooks.length === 0));
    if (hooks[event].length === 0) delete hooks[event];
  }
  if (Object.keys(hooks).length === 0) delete clone.hooks;
  return clone;
}

// Codex's hooks.json uses the SAME nested {matcher?, hooks:[{type,command}]}
// shape as Claude's (confirmed live against learn.chatgpt.com/docs/hooks -
// NOT Cursor's flatter {command} list), so it needs its own dedupe-aware
// merge rather than reusing scaffoldCursor's flat-shape merge loop: matches
// an incoming matcher-group against an existing one by `matcher` value, then
// dedupes individual {type,command} entries within it by content. Idempotent
// across --overwrite reruns; preserves any user-added hook entries.
function mergeNestedHooksJson(existing, incomingHooksConfig) {
  existing.hooks = existing.hooks || {};
  for (const [event, incomingGroups] of Object.entries(incomingHooksConfig.hooks || {})) {
    const existingGroups = existing.hooks[event] || [];
    for (const incomingGroup of incomingGroups) {
      const matchIdx = existingGroups.findIndex(
        (g) => (g.matcher || null) === (incomingGroup.matcher || null)
      );
      if (matchIdx === -1) {
        existingGroups.push(JSON.parse(JSON.stringify(incomingGroup)));
        continue;
      }
      const targetGroup = existingGroups[matchIdx];
      targetGroup.hooks = targetGroup.hooks || [];
      const seen = new Set(targetGroup.hooks.map((h) => JSON.stringify(h)));
      for (const h of incomingGroup.hooks || []) {
        const key = JSON.stringify(h);
        if (!seen.has(key)) {
          targetGroup.hooks.push(h);
          seen.add(key);
        }
      }
    }
    existing.hooks[event] = existingGroups;
  }
  return existing;
}

// TOML analogue of renderMcpBlock/applyMcpPlaceholder: the explorer.toml
// source ships a syntactically VALID placeholder table (a string value, not
// a bare token - see explorer.toml's port note), so this replaces the whole
// `[mcp_servers.code-review-graph]` table rather than a single line.
function renderMcpTomlBlock(launch) {
  const lines = ['[mcp_servers.code-review-graph]', `command = ${JSON.stringify(launch.command)}`];
  const argsList = (launch.args || []).map((a) => JSON.stringify(a)).join(', ');
  lines.push(`args = [${argsList}]`);
  if (launch.env && Object.keys(launch.env).length > 0) {
    lines.push('', '[mcp_servers.code-review-graph.env]');
    for (const k of Object.keys(launch.env)) lines.push(`${k} = ${JSON.stringify(launch.env[k])}`);
  }
  return lines.join('\n');
}

function applyMcpTomlPlaceholder(body, placeholder, launch, fileLabel) {
  if (!body.includes(placeholder)) return body;
  if (!launch) {
    throw new Error(
      `${fileLabel} still has the ${placeholder} placeholder but no launch command is ` +
        "recorded in persona-config.json's substitutions - run `bin/cli.js --wire-graph-mcp " +
        '--target=codex` to wire it, then re-run --update.'
    );
  }
  // `(^|\n)` (not the `m` flag) anchors the opening bracket to an ACTUAL line
  // start, so a mere mention of the literal bracket text inside a prose
  // comment (e.g. explaining TOML key ordering) can't match first and have
  // the non-greedy span swallow everything up to the real header, deleting
  // developer_instructions in the process (caught by this port's own
  // end-to-end scaffold test - docs/codex-port-notes.md, attempt #1).
  // Deliberately NOT using the `m` flag for this: with `m`, `$` matches
  // end-of-LINE, not end-of-string, so the lazy quantifier below would
  // satisfy `(?=\n\[|$)` immediately after the header line itself, leaving
  // the placeholder's command/args lines behind to be silently swallowed
  // into the newly-inserted `.env` sub-table by the TOML parser on the next
  // read (attempt #2, also caught by that same test). Without `m`, `$` means
  // true end-of-string, matching only once the whole table is consumed.
  const tableRe = /(^|\n)\[mcp_servers\.code-review-graph\][\s\S]*?(?=\n\[|$)/;
  const match = body.match(tableRe);
  if (!match) {
    throw new Error(`${fileLabel}: could not find the [mcp_servers.code-review-graph] table to replace.`);
  }
  // match[1] is the leading anchor ('' at string start, or the '\n' before
  // the header) captured by `(^|\n)` above - match[0] includes it, so it
  // must be preserved in front of the rendered block or the preceding line
  // and the new table would merge onto one line.
  return body.replace(match[0], match[1] + renderMcpTomlBlock(launch));
}

async function scaffoldCodex(args) {
  const version = readPluginVersion();
  const overwrite = args.includes('--overwrite');
  const forceHooks = args.includes('--force-hooks');
  const codexSrc = path.join(PKG_ROOT, 'adapters', 'codex');
  console.log(`antislop v${version} (Codex target) — scaffolding into ${CWD}\n`);

  const codexDir = path.join(CWD, '.codex');
  const configPath = path.join(codexDir, 'persona-config.json');
  let existingConfig = null;
  if (fs.existsSync(configPath)) {
    if (!overwrite) {
      console.log(
        'A .codex/persona-config.json already exists here — this looks like an ' +
          'existing Codex install, not a fresh one. This CLI only does fresh ' +
          'scaffolding; re-run with --overwrite to re-copy the mechanical files ' +
          '(agents, hooks, AGENTS.md fragment) unconditionally while preserving ' +
          'your judgment-driven config fields. Exiting without changes.'
      );
      process.exit(1);
    }
    existingConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    console.log(
      '--overwrite: existing Codex install found — re-copying agents/hooks/AGENTS.md ' +
        'fragment unconditionally. persona-config.json\'s judgment-driven fields ' +
        '(testAndLintCommand, protectedPaths, etc.) are preserved; only ' +
        'pluginVersion/personaSelection are refreshed.\n'
    );
  }

  const agentsDir = path.join(codexDir, 'agents');
  const scriptsDir = path.join(codexDir, 'hooks', 'scripts');
  mkdirp(agentsDir);
  mkdirp(scriptsDir);
  mkdirp(path.join(codexDir, 'reviewed'));
  mkdirp(path.join(codexDir, 'memory'));

  for (const name of CODEX_MVP_PERSONAS) {
    const srcPath = path.join(codexSrc, 'agents', `${name}.toml`);
    const destPath = path.join(agentsDir, `${name}.toml`);
    const body = fs.readFileSync(srcPath, 'utf8');
    // TOML has no leading-delimiter discovery constraint like Claude's
    // markdown frontmatter (docs/specs/codex-plugin.md §4), so a leading
    // comment stamp is safe here - no insertStampAfterFrontmatter needed.
    const stamp = `# antislop v${version} | source: adapters/codex/agents/${name}.toml | ADAPT-substituted\n`;
    fs.writeFileSync(destPath, stamp + body);
    console.log(`  adapters/codex/agents/${name}.toml -> .codex/agents/${name}.toml`);
  }

  copyDirRecursive(path.join(codexSrc, 'hooks', 'scripts'), scriptsDir);
  console.log('  adapters/codex/hooks/scripts/*.sh -> .codex/hooks/scripts/');

  const rawHooks = fs.readFileSync(path.join(codexSrc, 'hooks', 'hooks.json'), 'utf8');
  const hooksConfig = JSON.parse(
    rawHooks.replace(/\$\{PLUGIN_ROOT\}\/hooks\/scripts/g, '.codex/hooks/scripts')
  );
  const hooksPath = path.join(codexDir, 'hooks.json');
  let hooks = { hooks: {} };
  if (fs.existsSync(hooksPath)) {
    hooks = JSON.parse(fs.readFileSync(hooksPath, 'utf8'));
  }
  // Same coexistence guard as the claude target (issue #68), wired here for
  // uniformity. detectMarketplacePlugin always returns enabled:false for
  // 'codex' (see its own no-op comment, issue #67 — no antislop marketplace
  // plugin-enable distribution exists for codex), so this is a documented
  // no-op: the else branch below always runs today.
  const pluginState = detectMarketplacePlugin('codex', CWD, os.homedir());
  if (pluginState.enabled && !forceHooks) {
    console.log(
      `  Hook registration SKIPPED — antislop is already enabled via the marketplace ` +
        `plugin (detected in ${pluginState.source}). Re-run with --force-hooks to merge anyway.`
    );
  } else {
    mergeNestedHooksJson(hooks, hooksConfig);
    fs.writeFileSync(hooksPath, JSON.stringify(hooks, null, 2) + '\n');
    console.log('  .codex/hooks.json updated (nested matcher/hooks shape; merge, not overwrite)');
  }

  const fragmentContent = fs.readFileSync(path.join(codexSrc, 'agents-md-fragment.md'), 'utf8').trimEnd();
  const agentsMdPath = path.join(CWD, 'AGENTS.md');
  const blockResult = upsertMarkedBlock(agentsMdPath, version, fragmentContent);
  console.log(`  AGENTS.md: persona-protocol block ${blockResult}`);

  if (existingConfig) {
    existingConfig.personaSelection = CODEX_MVP_PERSONAS.slice();
    warnIfDowngradeStamp(existingConfig.pluginVersion, version, '.codex/persona-config.json');
    existingConfig.pluginVersion = version;
    existingConfig.target = 'codex';
    if (!existingConfig.mainAgent) existingConfig.mainAgent = 'orchestrator';
    if (!existingConfig.gatedAgents) existingConfig.gatedAgents = ['lead-programmer'];
    fs.writeFileSync(configPath, JSON.stringify(existingConfig, null, 2) + '\n');
    console.log('  .codex/persona-config.json: personaSelection + pluginVersion refreshed, other fields preserved');
  } else {
    const personaConfig = {
      target: 'codex',
      testAndLintCommand: '',
      lintCommand: '',
      graphUpdateCommand: '',
      sourceGlobs: [],
      protectedPaths: [],
      gatedAgents: ['lead-programmer'],
      // Codex has no config.toml key equivalent to Claude's settings.json
      // "agent" field; stop-gate.sh reads this to know which name to treat
      // as the (gated-or-not) main session.
      mainAgent: 'orchestrator',
      pluginVersion: version,
      personaSelection: CODEX_MVP_PERSONAS.slice(),
      issueTracker: '',
    };
    fs.writeFileSync(configPath, JSON.stringify(personaConfig, null, 2) + '\n');
    console.log('  .codex/persona-config.json written (skeleton — fill in test/lint/graph/protected fields against this repo)');
  }

  appendUnique(path.join(CWD, '.gitignore'), [
    '.codex/reviewed/',
    '.codex/wip-handoff.*',
    '.codex/.session-baseline.*',
    '.codex/wip-audit.log',
    '.codex/.pending-review.*',
    '.codex/review-audit.log',
    '.codex/dispatch-audit.log',
    '.codex/.dispatch-override',
    '.codex/.stop-loop-guard.*',
    'microworlds/',
    '.codex/human-review/',
    '.codex/microworld-audit.log',
  ]);
  console.log('  .gitignore updated');

  console.log(
    '\nDone with the mechanical Codex scaffolding.\n\n' +
      'Verify/finish by hand (Codex-specific caveats, see docs/codex-port-notes.md):\n' +
      '  1. HOOKS ARE SCAFFOLDED BUT NOT YET TRUSTED - Codex requires reviewing and\n' +
      '     approving non-managed command hooks before they run (the confirmed\n' +
      '     trust-approval flow on your installed version, e.g. a `/hooks` command) -\n' +
      '     an untrusted hooks.json is silently INERT, not silently broken.\n' +
      '  2. AGENTS.md reaching subagents is DOC-STATED by Codex but not yet\n' +
      '     empirically confirmed by this project - the load-bearing protocol rules\n' +
      '     are also inlined into each persona TOML as a backstop regardless.\n' +
      '  3. Fill in .codex/persona-config.json (testAndLintCommand, sourceGlobs,\n' +
      '     protectedPaths, graphUpdateCommand) for THIS repo.\n' +
      '  4. If you use the Code Review Graph, wire its launch command into\n' +
      '     .codex/agents/explorer.toml via `bin/cli.js --wire-graph-mcp --target=codex`\n' +
      '     - Codex is the one ported platform that keeps this scoped to the explorer\n' +
      '     alone, unlike the Cursor port which had to go project-wide.\n' +
      '  5. Optionally set model/model_reasoning_effort per agent in each TOML\n' +
      '     (currently omitted/inherited - the tier mapping is a project decision).\n' +
      '  6. The exact hooks.json registration shape and the marketplace.json\n' +
      '     placement were NOT verified against a live Codex build in this port -\n' +
      '     see docs/codex-port-notes.md before relying on either.'
  );
}

async function main() {
  const args = process.argv.slice(2);

  if (args.includes('--update')) {
    return runUpdate(args);
  }
  if (args.includes('--dashboard')) {
    return runDashboard(args);
  }
  if (args.includes('--wire-graph-mcp')) {
    return runWireMcp('graph', args);
  }
  if (args.some((a) => a === '--wire-arxiv-mcp' || a.startsWith('--wire-arxiv-mcp='))) {
    return runWireMcp('arxiv', args);
  }

  const targetFlag = args.find((a) => a.startsWith('--target='));
  const target = targetFlag ? targetFlag.slice('--target='.length).trim() : 'claude';
  if (target === 'cursor') {
    return scaffoldCursor(args);
  }
  if (target === 'codex') {
    return scaffoldCodex(args);
  }
  if (target !== 'claude') {
    console.error(`antislop: unknown --target=${target} (supported: claude, cursor, codex).`);
    process.exit(1);
  }

  const yesToAll = args.includes('--yes') || args.includes('-y');
  const personasFlag = args.find((a) => a.startsWith('--personas='));
  const overwrite = args.includes('--overwrite');
  const forceHooks = args.includes('--force-hooks');

  const version = readPluginVersion();
  console.log(`antislop v${version} — scaffolding into ${CWD}\n`);

  const existingConfig = path.join(CWD, '.claude', 'persona-config.json');
  const existingConfigFound = fs.existsSync(existingConfig);
  let existingPersonaConfig = null;
  if (existingConfigFound) {
    if (!overwrite) {
      console.log(
        'A .claude/persona-config.json already exists here — this looks like an ' +
          'existing install, not a fresh one. This CLI only does fresh scaffolding; ' +
          'for re-syncing an already-adapted project against a newer version, run ' +
          '`node bin/cli.js --update` instead (it diffs before overwriting, this ' +
          'scaffolding path does not), or re-run this CLI with --overwrite to ' +
          're-copy the mechanical files (agents, hooks, skills, protocol) unconditionally. ' +
          'Exiting without changes.'
      );
      process.exit(1);
    }
    existingPersonaConfig = JSON.parse(fs.readFileSync(existingConfig, 'utf8'));
    console.log(
      '--overwrite: existing install found — re-copying agents/hooks/skills/protocol ' +
        'unconditionally. persona-config.json\'s judgment-driven fields ' +
        '(testAndLintCommand, protectedPaths, etc.) are preserved as-is; only ' +
        'personaSelection and pluginVersion are refreshed, unless --personas=/--yes ' +
        'is also passed to change the selection.\n'
    );
  }

  // --overwrite with no explicit selection flag reuses the existing project's
  // recorded persona selection (least surprising: "refresh what's already
  // here" shouldn't silently add personas nobody chose) — an explicit
  // --personas=/--yes still wins, same precedence as a fresh install.
  const reuseExistingSelection = overwrite && existingPersonaConfig && !personasFlag && !yesToAll;

  let selected;
  if (reuseExistingSelection) {
    let priorSelection = existingPersonaConfig.personaSelection || [];
    if (legacyTokensIn(priorSelection).length > 0) { // legacy token check
      priorSelection = migrateLegacyPersonaTokens(priorSelection, { logNote: true });
    }
    selected = OPTIONAL_PERSONAS.filter((p) => priorSelection.includes(p));
    selected._researcher = priorSelection.includes('researcher');
  } else if (personasFlag) {
    let requested = personasFlag.slice('--personas='.length).split(',').map((s) => s.trim()).filter(Boolean);
    if (legacyTokensIn(requested).length > 0) { // legacy token check
      requested = migrateLegacyPersonaTokens(requested, { logNote: true });
    }
    selected = OPTIONAL_PERSONAS.filter((p) => requested.includes(p));
    if (requested.includes('reviewer') === false && requested.length > 0) {
      console.log('Note: reviewer not in --personas list — skipping it (see README on what that gives up).');
    }
  } else if (yesToAll) {
    selected = OPTIONAL_PERSONAS.slice();
  } else {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    selected = [];
    for (const persona of OPTIONAL_PERSONAS) {
      if (persona === 'reviewer') {
        const include = await askYesNo(
          rl,
          '\nInclude reviewer? This is the system\'s core safety property (the ' +
            'Writer/Reviewer split) — skipping it means the lead-programmer\'s own ' +
            '"ready-for-review" report becomes the closest thing to a done-check. ' +
            'Include it?',
          true
        );
        if (!include) {
          const confirm = (
            await prompt(rl, 'Type "skip reviewer" to confirm you want to skip it: ')
          ).trim();
          if (confirm !== 'skip reviewer') {
            console.log('Confirmation text did not match — including reviewer.');
            selected.push('reviewer');
            continue;
          }
        } else {
          selected.push('reviewer');
        }
        continue;
      }
      const label = {
        'spec-master': 'spec-master (turns ambiguous goals into precise specs; skip only for purely mechanical/small work)',
        'task-master': 'task-master (slices a finalized spec into dispatch-ready tasks; skip only for purely mechanical/small work)',
        scribe: 'scribe (maintains wiki/CONTEXT.md/ADRs; skip if no maintained wiki wanted)',
        'milestone-auditor': 'milestone-auditor (audits plan premises at milestone boundaries; skip if no real milestone structure or spec-master was also skipped)',
        'agent-auditor': 'agent-auditor (read-only report on dispatch anomalies and model/skill-usage summaries; skip if you don\'t want this observability report)',
      }[persona];
      const include = await askYesNo(rl, `\nInclude ${label}?`, true);
      if (include) selected.push(persona);
    }
    let researcherSelected = await askYesNo(
      rl,
      '\nInclude researcher (bridges academic literature via an arXiv MCP; needs ' +
        'a real MCP launch command wired in later via /install-antislop)?',
      false
    );
    selected._researcher = researcherSelected;
    rl.close();
  }

  const includeResearcher = personasFlag
    ? args.some((a) => a.startsWith('--personas=') && a.includes('researcher'))
    : yesToAll
    ? true
    : Boolean(selected._researcher);

  const claudeDir = path.join(CWD, '.claude');
  const agentsDir = path.join(claudeDir, 'agents');
  const hooksScriptsDir = path.join(claudeDir, 'hooks', 'scripts');
  const skillsDir = path.join(claudeDir, 'skills');
  mkdirp(agentsDir);
  mkdirp(hooksScriptsDir);
  mkdirp(skillsDir);
  mkdirp(path.join(claudeDir, 'reviewed'));

  // The same gatedAgents this run is about to persist below (preserved as-is
  // when --overwrite reuses an existing config), so the bodies written here are
  // what the project's first --update would render, not a divergent variant.
  const gatedAgents = existingPersonaConfig
    ? existingPersonaConfig.gatedAgents
    : DEFAULT_GATED_AGENTS;

  const allAgentNames = CORE_PERSONAS.concat(selected.filter((p) => OPTIONAL_PERSONAS.includes(p)));
  for (const name of allAgentNames) {
    const src = path.join(PKG_ROOT, 'agents', `${name}.md`);
    const dest = path.join(agentsDir, `${name}.md`);
    const body = inlineProtocolBlock(fs.readFileSync(src, 'utf8'), protocolTierFor(name), name, gatedAgents);
    copyStampedBody(dest, body, version, `agents/${name}.md`);
    console.log(`  agents/${name}.md -> .claude/agents/${name}.md`);
  }

  if (includeResearcher) {
    const src = path.join(PKG_ROOT, 'templates', 'researcher.md.tmpl');
    const dest = path.join(agentsDir, 'researcher.md');
    const body = inlineProtocolBlock(fs.readFileSync(src, 'utf8'), protocolTierFor('researcher'), 'researcher', gatedAgents);
    copyStampedBody(dest, body, version, 'templates/researcher.md.tmpl');
    console.log('  templates/researcher.md.tmpl -> .claude/agents/researcher.md (mcpServers placeholder still needs a real launch command — /install-antislop step 5 handles this)');
  }

  copyStamped(
    path.join(PKG_ROOT, 'templates', 'protocol-digest.md'),
    path.join(claudeDir, 'protocol-digest.md'),
    version,
    'templates/protocol-digest.md'
  );
  console.log('  templates/protocol-digest.md -> .claude/protocol-digest.md');

  // This path hand-lists its copies and never calls buildFileSpecs, so
  // registering the spec there alone would leave a fresh install without the
  // full protocol until its first --update.
  copyStamped(
    path.join(PKG_ROOT, 'templates', 'persona-protocol.md'),
    path.join(claudeDir, 'persona-protocol.md'),
    version,
    'templates/persona-protocol.md'
  );
  console.log('  templates/persona-protocol.md -> .claude/persona-protocol.md');

  copyDirRecursive(path.join(PKG_ROOT, 'hooks', 'scripts'), hooksScriptsDir);
  console.log('  hooks/scripts/*.sh -> .claude/hooks/scripts/');

  copyDirRecursive(path.join(PKG_ROOT, 'skills', 'install-antislop'), path.join(skillsDir, 'install-antislop'));
  copyDirRecursive(path.join(PKG_ROOT, 'skills', 'coding-discipline'), path.join(skillsDir, 'coding-discipline'));
  console.log('  skills/install-antislop, skills/coding-discipline -> .claude/skills/ (invoke /install-antislop next)');

  const hooksConfig = readStandaloneHooksConfig();

  const settingsFragment = JSON.parse(
    fs.readFileSync(path.join(PKG_ROOT, 'templates', 'settings-fragment.json'), 'utf8')
  );
  delete settingsFragment._comment;

  const settingsPath = path.join(claudeDir, 'settings.json');
  let settings = {};
  if (fs.existsSync(settingsPath)) {
    settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
  }
  deepMerge(settings, settingsFragment);

  const pluginState = detectMarketplacePlugin('claude', CWD, os.homedir());
  let hooksNote = 'hooks';
  if (pluginState.enabled && !forceHooks) {
    hooksNote = 'hooks NOT merged, see above';
    console.log(
      `  Hook registration SKIPPED — antislop is already enabled via the Claude Code ` +
        `marketplace plugin (enabledPlugins["antislop@antislop-marketplace"] === true, ` +
        `detected in ${pluginState.source}), which already auto-loads hooks.json via ` +
        '${CLAUDE_PLUGIN_ROOT}. Merging this CLI\'s own hook registrations too would fire ' +
        `every hook twice. Re-run with --force-hooks to merge them anyway.`
    );
  } else {
    if (pluginState.enabled && forceHooks) {
      console.log(
        `  --force-hooks: antislop is already enabled via the marketplace plugin ` +
          `(detected in ${pluginState.source}) AND hooks are being merged anyway — expect ` +
          'every hook to fire twice until the plugin is disabled.'
      );
    }
    deepMerge(settings, hooksConfig);
  }
  fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
  console.log(`  .claude/settings.json updated (agent, ${hooksNote}, env, permission placeholders merged in — merge, not overwrite)`);

  // Protocol is delivered per-persona (inlined into each .claude/agents/*.md
  // body above), not via a global CLAUDE.md import. Strip any legacy global
  // import left by a pre-v0.13.x install; never add one.
  if (migrateGlobalProtocolImport(CWD)) {
    console.log('  CLAUDE.md: removed the legacy global @.claude/persona-protocol.md import (protocol is now per-persona).');
  }

  appendUnique(path.join(CWD, '.gitignore'), [
    '.claude/reviewed/',
    '.claude/wip-handoff.*',
    '.claude/.session-baseline.*',
    '.claude/wip-audit.log',
    '.claude/.pending-review.*',
    '.claude/review-audit.log',
    '.claude/dispatch-audit.log',
    '.claude/.dispatch-override',
    'microworlds/',
    '.claude/human-review/',
    '.claude/microworld-audit.log',
  ]);
  console.log('  .gitignore updated');

  const personaSelection = selected.filter((p) => OPTIONAL_PERSONAS.includes(p)).concat(includeResearcher ? ['researcher'] : []);

  if (existingPersonaConfig) {
    // --overwrite over an existing install: preserve every judgment-driven
    // field (testAndLintCommand, protectedPaths, etc.) exactly as recorded —
    // this CLI has no way to re-derive those from a repo scan, only
    // /install-antislop --update does. Only refresh what a plain re-copy of
    // the mechanical files actually implies: the selection (if explicitly
    // overridden) and the version stamp.
    existingPersonaConfig.personaSelection = personaSelection;
    warnIfDowngradeStamp(existingPersonaConfig.pluginVersion, version, '.claude/persona-config.json');
    existingPersonaConfig.pluginVersion = version;
    fs.writeFileSync(path.join(claudeDir, 'persona-config.json'), JSON.stringify(existingPersonaConfig, null, 2) + '\n');
    console.log('  .claude/persona-config.json: personaSelection + pluginVersion refreshed, other fields preserved');
  } else {
    const personaConfig = {
      testAndLintCommand: '',
      lintCommand: '',
      graphUpdateCommand: '',
      sourceGlobs: [],
      protectedPaths: [],
      gatedAgents: DEFAULT_GATED_AGENTS,
      // Shipped default is `critical` (on). Deliberately NOT backfilled into
      // the existingPersonaConfig branch above — already-adapted projects get
      // this default from the consumer's absent-key fallback instead (see
      // agents/reviewer.md), which is what keeps that branch's
      // preserve-every-field contract intact.
      humanReviewMode: 'critical',
      pluginVersion: version,
      personaSelection,
      issueTracker: '',
    };
    fs.writeFileSync(path.join(claudeDir, 'persona-config.json'), JSON.stringify(personaConfig, null, 2) + '\n');
    console.log('  .claude/persona-config.json written (skeleton — fields blank until /install-antislop fills them in from a real repo scan)');
  }

  const scriptedMode = yesToAll || Boolean(personasFlag) || overwrite;
  const wantGraph = args.includes('--with-graph')
    ? true
    : scriptedMode
    ? false
    : await askYesNoStandalone(
        '\nInstall the Code Review Graph now (pipx install code-review-graph, then ' +
          'code-review-graph install --platform claude-code)? Requires pipx/Python.'
      );
  if (wantGraph) {
    const result = spawnSync('bash', [path.join(PKG_ROOT, 'bin', 'install-deps.sh'), '--only-graph'], {
      stdio: 'inherit',
      cwd: CWD,
    });
    if (result.status === 0) {
      console.log(
        '  IMPORTANT: this tool registers itself PROJECT-WIDE in .mcp.json by default — every ' +
          'persona would inherit it, which is exactly the context-bloat problem this system avoids ' +
          'elsewhere. This CLI deliberately does NOT edit .mcp.json or explorer.md\'s `mcpServers:` ' +
          'placeholder for you (it would mean guessing at a schema this CLI hasn\'t verified against ' +
          'what got written). /install-antislop step 4 does that rescoping for real — run it next, ' +
          'don\'t skip straight past this.'
      );
    } else {
      console.log('  install-deps.sh reported a problem with the code-review-graph step — see output above.');
    }
  } else if (!scriptedMode) {
    console.log('  Skipped — /install-antislop step 4 covers this if you want it done via the LLM-driven flow instead.');
  }

  console.log(
    '\nDone with the mechanical scaffolding. This CLI intentionally stops here — ' +
      'it does NOT scan your repo for test/lint commands, install third-party ' +
      'skills, build the code-review-graph, wire an arXiv MCP, prune CLAUDE.md, ' +
      'or run hook verification, because those all need real judgment against ' +
      'THIS repo\'s actual contents, not a deterministic copy.\n\n' +
      'Next step: open Claude Code in this project and run:\n\n' +
      '  /install-antislop\n\n' +
      '(it now exists as a project-local skill from the copy above) to finish ' +
      'the repo-specific config, verify hooks, and fill in persona-config.json ' +
      'for real.'
  );
}

async function runDashboard(args) {
  const portFlag = args.find((a) => a.startsWith('--dashboard-port='));
  const port = portFlag ? parseInt(portFlag.slice('--dashboard-port='.length), 10) : 0;

  const { startServer } = require('./microworld-dashboard/server');
  const { server } = startServer(process.cwd(), port);

  // Handle SIGINT gracefully
  process.on('SIGINT', () => {
    server.close(() => {
      process.exit(0);
    });
  });
}

if (require.main === module) {
  main().catch((err) => {
    console.error('antislop failed:', err.message);
    process.exit(1);
  });
}

module.exports = {
  PLACEHOLDER_RE,
  compareSemver,
  sha256Hex,
  stripStamp,
  stampVersionOf,
  renderMcpBlock,
  applyMcpPlaceholder,
  applyArxivFallback,
  buildFileSpecs,
  buildHookScriptSpecs,
  renderCleanBody,
  protocolTierFor,
  selectProtocolSections,
  assertProtocolMatrixComplete,
  assertNoDanglingCrossReferences,
  assertGatedSectionsCanonical,
  GATED_AGENT_SECTIONS,
  PROTOCOL_SECTIONS_BY_PERSONA,
  migrateLegacyPersonaTokens,
  deriveMcpLaunchFromDisk,
  detectMarketplacePlugin,
  findStandaloneHookRegistrations,
  stripStandaloneHookRegistrations,
  backfillSubstitutionsFromDisk,
  backfillFileHashesFromDisk,
  pruneStaleFileHashes,
  deepMerge,
};
