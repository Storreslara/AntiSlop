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
const OPTIONAL_PERSONAS = ['hivemind', 'repo-historian', 'reviewer', 'milestone-auditor'];
// Legacy-token migration: the persona formerly named `planner` was renamed
// `hivemind` (repo-wide rename, plugin v0.6.0) — this is a deprecated,
// legacy `--personas=planner` / legacy `personaSelection` entry of
// `"planner"` concern only; both map forward via LEGACY_PERSONA_MAP below
// rather than being silently dropped by the OPTIONAL_PERSONAS intersection
// filter.
const LEGACY_PERSONA_MAP = { planner: 'hivemind' }; // legacy token -> current token
// researcher is handled separately: it's a template, not a plain agent copy.

function readPluginVersion() {
  const pluginJsonPath = path.join(PKG_ROOT, '.claude-plugin', 'plugin.json');
  const pluginJson = JSON.parse(fs.readFileSync(pluginJsonPath, 'utf8'));
  return pluginJson.version;
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

function appendUnique(filePath, lines) {
  let existing = '';
  if (fs.existsSync(filePath)) {
    existing = fs.readFileSync(filePath, 'utf8');
  }
  const missing = lines.filter((line) => !existing.includes(line));
  if (missing.length === 0) return;
  const sep = existing.length > 0 && !existing.endsWith('\n') ? '\n' : '';
  fs.writeFileSync(filePath, existing + sep + missing.join('\n') + '\n');
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
        if (!target[key].includes(item)) target[key].push(item);
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

function stripStamp(body) {
  return body.replace(STAMP_LINE_RE, '');
}

function migrateLegacyPersonaTokens(selection, { logNote } = {}) {
  if (!selection.includes('planner')) return selection;
  if (logNote) {
    console.log(
      'Deprecation note: migrating the legacy "planner" token to "hivemind" ' +
        '(the legacy "planner" token was renamed hivemind in plugin v0.6.0).'
    );
  }
  return selection.map((p) => LEGACY_PERSONA_MAP[p] || p);
}

function escapeRegExp(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

const MATTPOCOCK_RE = /<MATTPOCOCK:([a-zA-Z0-9_-]+)>/g;

function applyMattpocockSubs(body, mattpocockSkills, fileLabel) {
  const map = mattpocockSkills || {};
  return body.replace(MATTPOCOCK_RE, (full, slot) => {
    if (!(slot in map)) {
      throw new Error(
        `No recorded substitution for <MATTPOCOCK:${slot}> in ${fileLabel} — ` +
          "persona-config.json's substitutions.mattpocockSkills is incomplete and this " +
          "plugin's --update couldn't auto-derive it from what's on disk. Add " +
          `"${slot}": "<the mattpocock skill's registered name>" to that map yourself ` +
          '(list installed skill names via `.claude/skills/*/SKILL.md` frontmatter), then re-run --update.'
      );
    }
    return map[slot];
  });
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
// `<MATTPOCOCK:slot>` -> resolved-name (or placeholder-line -> rendered MCP
// block) text swap with no other prose changes (see install-antislop SKILL.md),
// so a project adapted at the CURRENT plugin version's persona files can
// always be derived this way; a project several versions behind may have
// some individual slots whose surrounding prose has since been reworded —
// those are left undetermined here and surfaced per-file, non-fatally, by
// the (now resilient) render loop below rather than guessed at.
// ---------------------------------------------------------------------------

function normalizeEol(s) {
  return s.replace(/\r\n/g, '\n');
}

// Diffs one plugin-source persona file (still containing <MATTPOCOCK:slot>
// tokens) against the project's already-substituted copy, line by line: each
// source line containing placeholder(s) becomes a regex (literal text
// escaped, each placeholder -> a capture group), searched for across the
// ENTIRE current file (not by line number — unrelated lines may have shifted
// between the version this project was adapted at and the plugin's current
// source). Ambiguous (0 or >1 matching lines) or conflicting (same slot
// resolves to two different values across files) slots are left unresolved
// rather than guessed.
function deriveMattpocockSubsForFile(sourceBody, currentBody) {
  const resolved = {};
  const unresolvedSlots = new Set();
  const normalizedCurrent = normalizeEol(currentBody);
  const sourceLines = normalizeEol(sourceBody).split('\n');

  for (const line of sourceLines) {
    MATTPOCOCK_RE.lastIndex = 0;
    if (!MATTPOCOCK_RE.test(line)) continue;

    MATTPOCOCK_RE.lastIndex = 0;
    let pattern = '';
    let lastIndex = 0;
    const slotsInLine = [];
    let m;
    while ((m = MATTPOCOCK_RE.exec(line)) !== null) {
      pattern += escapeRegExp(line.slice(lastIndex, m.index)) + '(\\S+?)';
      slotsInLine.push(m[1]);
      lastIndex = m.index + m[0].length;
    }
    pattern += escapeRegExp(line.slice(lastIndex));

    const matches = [...normalizedCurrent.matchAll(new RegExp('^' + pattern + '$', 'gm'))];
    if (matches.length !== 1) {
      for (const slot of slotsInLine) unresolvedSlots.add(slot);
      continue;
    }
    slotsInLine.forEach((slot, i) => {
      const value = matches[0][i + 1];
      if (slot in resolved && resolved[slot] !== value) {
        unresolvedSlots.add(slot);
        delete resolved[slot];
        return;
      }
      if (!unresolvedSlots.has(slot)) resolved[slot] = value;
    });
  }
  return { resolved, unresolvedSlots: [...unresolvedSlots] };
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
  config.substitutions.mattpocockSkills = config.substitutions.mattpocockSkills || {};
  let changed = false;

  for (const spec of specs) {
    const destAbsPath = path.join(CWD, spec.projectRelPath);
    if (!fs.existsSync(destAbsPath)) continue;
    const sourceBody = fs.readFileSync(spec.sourceAbsPath, 'utf8');
    if (!sourceBody.includes('<MATTPOCOCK:')) continue; // plain substring check — MATTPOCOCK_RE is a shared /g regex, unsafe to .test() without a lastIndex reset
    const currentBody = stripStamp(fs.readFileSync(destAbsPath, 'utf8'));
    const { resolved } = deriveMattpocockSubsForFile(sourceBody, currentBody);
    for (const [slot, value] of Object.entries(resolved)) {
      if (slot in config.substitutions.mattpocockSkills) continue;
      config.substitutions.mattpocockSkills[slot] = value;
      changed = true;
    }
  }

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

function copyStampedBody(destAbsPath, body, version, sourceRelPath) {
  mkdirp(path.dirname(destAbsPath));
  fs.writeFileSync(destAbsPath, insertStampAfterFrontmatter(body, versionStamp(version, sourceRelPath)));
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
    });
  }
  if (personaSelection.includes('researcher')) {
    specs.push({
      projectRelPath: '.claude/agents/researcher.md',
      sourceAbsPath: path.join(PKG_ROOT, 'templates', 'researcher.md.tmpl'),
      sourceRelPath: 'templates/researcher.md.tmpl',
      kind: 'arxiv',
    });
  }
  specs.push({
    projectRelPath: '.claude/persona-protocol.md',
    sourceAbsPath: path.join(PKG_ROOT, 'templates', 'persona-protocol.md'),
    sourceRelPath: 'templates/persona-protocol.md',
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

function renderCleanBody(spec, config) {
  let body = fs.readFileSync(spec.sourceAbsPath, 'utf8');
  body = applyMattpocockSubs(body, (config.substitutions || {}).mattpocockSkills, spec.projectRelPath);
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
  return body;
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

async function runUpdate(args) {
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

  let personaSelection = config.personaSelection || [];
  const hadLegacyToken = personaSelection.includes('planner');
  personaSelection = migrateLegacyPersonaTokens(personaSelection, { logNote: true });
  if (hadLegacyToken) {
    config.personaSelection = personaSelection;
    const legacyPath = path.join(CWD, '.claude', 'agents', 'planner.md');
    if (fs.existsSync(legacyPath)) fs.unlinkSync(legacyPath);
  }

  const specs = buildFileSpecs(personaSelection);

  // Legacy backfill: derive whatever substitutions/fileHashes entries are
  // missing from what's already on disk — deterministic, zero LLM cost. Runs
  // unconditionally (cheap, idempotent no-op once fully populated) rather
  // than being gated behind an existence check, so it also fills gaps left
  // by a prior partial run (e.g. --wire-graph-mcp ran but mattpocockSkills
  // never got backfilled).
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

  if (config.pluginVersion === version && !hadLegacyToken && !backfilled) {
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
      copyStampedBody(destAbsPath, cleanBody, version, spec.sourceRelPath);
      newFileHashes[relKey] = cleanHash;
      summary.push(`  ${relKey}: created`);
      continue;
    }

    const currentBody = fs.readFileSync(destAbsPath, 'utf8');
    const currentStripped = stripStamp(currentBody);
    const recordedHash = config.fileHashes[relKey];
    const noLocalEdits = Boolean(recordedHash) && sha256Hex(currentStripped) === recordedHash;

    if (noLocalEdits && cleanHash === recordedHash) {
      summary.push(`  ${relKey}: already current`);
      continue;
    }

    if (noLocalEdits) {
      copyStampedBody(destAbsPath, cleanBody, version, spec.sourceRelPath);
      newFileHashes[relKey] = cleanHash;
      summary.push(`  ${relKey}: updated (no local edits detected)`);
      continue;
    }

    if (acceptAll || acceptList.includes(relKey)) {
      copyStampedBody(destAbsPath, cleanBody, version, spec.sourceRelPath);
      newFileHashes[relKey] = cleanHash;
      summary.push(`  ${relKey}: overwritten (--accept)`);
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
      summary.push(`  ${relKey}: kept as-is (local edits preserved; will be re-flagged on future drift)`);
    } else {
      pending.push({ relKey, currentStripped, cleanBody });
    }
  }

  if (pending.length > 0) {
    console.log(`\n${pending.length} file(s) have diverged from a fresh copy and need a decision:\n`);
    for (const p of pending) {
      console.log(`--- ${p.relKey} ---`);
      printUnifiedDiff(p.currentStripped, p.cleanBody, p.relKey);
      console.log('');
    }
  }

  if (pending.length > 0 || unresolvedRender.length > 0) {
    config.fileHashes = newFileHashes;
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');
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
    process.exit(unresolvedRender.length > 0 ? 1 : 2);
  }

  config.fileHashes = newFileHashes;
  config.pluginVersion = version;
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');

  console.log(`antislop v${version} — update complete in ${CWD}:\n`);
  console.log(summary.join('\n'));

  const placeholderRe = /<[A-Z0-9_]+(:[a-zA-Z0-9_-]+)?>/;
  const leftover = specs
    .map((s) => path.join(CWD, s.projectRelPath))
    .filter((p) => fs.existsSync(p) && placeholderRe.test(fs.readFileSync(p, 'utf8')));
  if (leftover.length > 0) {
    console.log(
      `\nWARNING: unresolved placeholder(s) remain in: ${leftover.join(', ')} — this should not ` +
        "happen after a clean --update; inspect persona-config.json's substitutions field."
    );
  }
}

async function runWireMcp(kind, args) {
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
    targetFile = path.join(CWD, '.claude', 'agents', 'explorer.md');
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
    body = applyMcpPlaceholder(body, placeholder, launch, targetFile);
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
  const configPath = path.join(CWD, '.claude', 'persona-config.json');
  let config = {};
  if (fs.existsSync(configPath)) {
    config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  } else {
    mkdirp(path.dirname(configPath));
  }
  config.substitutions = config.substitutions || {};
  config.substitutions[substitutionField] = launch;
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');
  console.log(`  .claude/persona-config.json: substitutions.${substitutionField} recorded.`);

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

  if (existingConfig) {
    existingConfig.personaSelection = CURSOR_MVP_PERSONAS.slice();
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

async function main() {
  const args = process.argv.slice(2);

  if (args.includes('--update')) {
    return runUpdate(args);
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
  if (target !== 'claude') {
    console.error(`antislop: unknown --target=${target} (supported: claude, cursor).`);
    process.exit(1);
  }

  const yesToAll = args.includes('--yes') || args.includes('-y');
  const personasFlag = args.find((a) => a.startsWith('--personas='));
  const overwrite = args.includes('--overwrite');

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
    if (priorSelection.includes('planner')) { // legacy token check
      console.log(
        'Deprecation note: this project\'s recorded personaSelection contains the ' +
          'legacy "planner" token — migrating the legacy "planner" token to "hivemind" ' +
          '(the legacy "planner" token was renamed hivemind in plugin v0.6.0).'
      );
      priorSelection = priorSelection.map((p) => LEGACY_PERSONA_MAP[p] || p);
    }
    selected = OPTIONAL_PERSONAS.filter((p) => priorSelection.includes(p));
    selected._researcher = priorSelection.includes('researcher');
  } else if (personasFlag) {
    let requested = personasFlag.slice('--personas='.length).split(',').map((s) => s.trim()).filter(Boolean);
    if (requested.includes('planner')) { // legacy token check
      console.log(
        'Deprecation note: "planner" is a legacy persona token — mapping the legacy ' +
          '"planner" token to "hivemind" (the legacy "planner" token was renamed ' +
          'hivemind in plugin v0.6.0). Use --personas=hivemind,... going forward.'
      );
      requested = requested.map((p) => LEGACY_PERSONA_MAP[p] || p);
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
        hivemind: 'hivemind (turns ambiguous goals into precise plans; skip only for purely mechanical/small work)',
        'repo-historian': 'repo-historian (maintains wiki/CONTEXT.md/ADRs; skip if no maintained wiki wanted)',
        'milestone-auditor': 'milestone-auditor (audits plan premises at milestone boundaries; skip if no real milestone structure or hivemind was also skipped)',
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

  const allAgentNames = CORE_PERSONAS.concat(selected.filter((p) => OPTIONAL_PERSONAS.includes(p)));
  for (const name of allAgentNames) {
    const src = path.join(PKG_ROOT, 'agents', `${name}.md`);
    const dest = path.join(agentsDir, `${name}.md`);
    copyStamped(src, dest, version, `agents/${name}.md`);
    console.log(`  agents/${name}.md -> .claude/agents/${name}.md`);
  }

  if (includeResearcher) {
    const src = path.join(PKG_ROOT, 'templates', 'researcher.md.tmpl');
    const dest = path.join(agentsDir, 'researcher.md');
    copyStamped(src, dest, version, 'templates/researcher.md.tmpl');
    console.log('  templates/researcher.md.tmpl -> .claude/agents/researcher.md (mcpServers placeholder still needs a real launch command — /install-antislop step 5 handles this)');
  }

  copyStamped(
    path.join(PKG_ROOT, 'templates', 'persona-protocol.md'),
    path.join(claudeDir, 'persona-protocol.md'),
    version,
    'templates/persona-protocol.md'
  );
  copyStamped(
    path.join(PKG_ROOT, 'templates', 'protocol-digest.md'),
    path.join(claudeDir, 'protocol-digest.md'),
    version,
    'templates/protocol-digest.md'
  );
  console.log('  templates/persona-protocol.md -> .claude/persona-protocol.md');
  console.log('  templates/protocol-digest.md -> .claude/protocol-digest.md');

  copyDirRecursive(path.join(PKG_ROOT, 'hooks', 'scripts'), hooksScriptsDir);
  console.log('  hooks/scripts/*.sh -> .claude/hooks/scripts/');

  copyDirRecursive(path.join(PKG_ROOT, 'skills', 'install-antislop'), path.join(skillsDir, 'install-antislop'));
  copyDirRecursive(path.join(PKG_ROOT, 'skills', 'coding-discipline'), path.join(skillsDir, 'coding-discipline'));
  console.log('  skills/install-antislop, skills/coding-discipline -> .claude/skills/ (invoke /install-antislop next)');

  const rawHooksJson = fs.readFileSync(path.join(PKG_ROOT, 'hooks', 'hooks.json'), 'utf8');
  const hooksConfig = JSON.parse(
    rawHooksJson.replace(/\$\{CLAUDE_PLUGIN_ROOT\}\/hooks\/scripts/g, '${CLAUDE_PROJECT_DIR}/.claude/hooks/scripts')
  );

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
  deepMerge(settings, hooksConfig);
  fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
  console.log('  .claude/settings.json updated (agent, hooks, env, permission placeholders merged in — merge, not overwrite)');

  const claudeMdPath = path.join(CWD, 'CLAUDE.md');
  const importLine = '@.claude/persona-protocol.md';
  if (!fs.existsSync(claudeMdPath)) {
    fs.writeFileSync(claudeMdPath, `${importLine}\n`);
    console.log('  CLAUDE.md created with the persona-protocol import line');
  } else {
    appendUnique(claudeMdPath, [importLine]);
    console.log('  CLAUDE.md: persona-protocol import line ensured present');
  }

  appendUnique(path.join(CWD, '.gitignore'), [
    '.claude/reviewed/',
    '.claude/wip-handoff.*',
    '.claude/.session-baseline.*',
    '.claude/wip-audit.log',
    '.claude/.pending-review.*',
    '.claude/review-audit.log',
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
      gatedAgents: ['lead-programmer'],
      pluginVersion: version,
      personaSelection,
      issueTracker: '',
    };
    fs.writeFileSync(path.join(claudeDir, 'persona-config.json'), JSON.stringify(personaConfig, null, 2) + '\n');
    console.log('  .claude/persona-config.json written (skeleton — fields blank until /install-antislop fills them in from a real repo scan)');
  }

  const scriptedMode = yesToAll || Boolean(personasFlag) || overwrite;
  const wantMattpocock = args.includes('--with-mattpocock')
    ? true
    : scriptedMode
    ? false
    : await askYesNoStandalone(
        '\nRun the mattpocock/skills installer now (npx skills@latest add mattpocock/skills)? ' +
          'It opens an interactive picker in this same terminal — you select the skills yourself.'
      );
  if (wantMattpocock) {
    const result = spawnSync('bash', [path.join(PKG_ROOT, 'bin', 'install-deps.sh'), '--only-mattpocock'], {
      stdio: 'inherit',
      cwd: CWD,
    });
    if (result.status !== 0) {
      console.log('  install-deps.sh reported a problem with the mattpocock/skills step — see output above.');
    }
    console.log(
      '  /install-antislop still needs to record which skills you picked and substitute the ' +
        '<MATTPOCOCK:*> placeholders in the copied persona files — it cannot be inferred from here.'
    );
  } else if (!scriptedMode) {
    console.log('  Skipped — run it yourself later, or re-run this CLI with --with-mattpocock.');
  }

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

if (require.main === module) {
  main().catch((err) => {
    console.error('antislop failed:', err.message);
    process.exit(1);
  });
}

module.exports = {
  sha256Hex,
  stripStamp,
  applyMattpocockSubs,
  renderMcpBlock,
  applyMcpPlaceholder,
  applyArxivFallback,
  buildFileSpecs,
  renderCleanBody,
  migrateLegacyPersonaTokens,
  deriveMattpocockSubsForFile,
  deriveMcpLaunchFromDisk,
  backfillSubstitutionsFromDisk,
  backfillFileHashesFromDisk,
};
