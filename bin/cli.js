#!/usr/bin/env node
'use strict';

// Mechanical half of the seb-personas ADAPT flow, packaged as a standalone
// installer so a project doesn't need GitHub collaborator access or the
// /plugin marketplace flow. This CLI only does deterministic file
// scaffolding (copy, stamp, merge) — it deliberately does NOT do the
// judgment-driven half (repo-specific test/lint commands, protected paths,
// third-party skill installs, graph/MCP wiring, CLAUDE.md pruning, hook
// verification). That half still lives in skills/setup-personas/SKILL.md,
// which this CLI copies project-locally and tells you to run next.

const fs = require('fs');
const path = require('path');
const readline = require('readline');

const PKG_ROOT = path.resolve(__dirname, '..');
const CWD = process.cwd();

const CORE_PERSONAS = ['orchestrator', 'explorer', 'lead-programmer'];
const OPTIONAL_PERSONAS = ['planner', 'repo-historian', 'reviewer', 'milestone-auditor'];
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
  return `<!-- seb-personas v${version} | source: ${sourceRelPath} | ADAPT-substituted -->\n`;
}

function copyStamped(srcAbsPath, destAbsPath, version, sourceRelPath) {
  const body = fs.readFileSync(srcAbsPath, 'utf8');
  fs.writeFileSync(destAbsPath, versionStamp(version, sourceRelPath) + body);
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

async function main() {
  const args = process.argv.slice(2);
  const yesToAll = args.includes('--yes') || args.includes('-y');
  const personasFlag = args.find((a) => a.startsWith('--personas='));

  const version = readPluginVersion();
  console.log(`seb-personas-setup v${version} — scaffolding into ${CWD}\n`);

  const existingConfig = path.join(CWD, '.claude', 'persona-config.json');
  if (fs.existsSync(existingConfig)) {
    console.log(
      'A .claude/persona-config.json already exists here — this looks like an ' +
        'existing install, not a fresh one. This CLI only does fresh scaffolding; ' +
        'for re-syncing an already-adapted project against a newer version, run ' +
        'the /setup-personas skill with --update instead (it diffs before ' +
        'overwriting, this CLI does not). Exiting without changes.'
    );
    process.exit(1);
  }

  let selected;
  if (personasFlag) {
    const requested = personasFlag.slice('--personas='.length).split(',').map((s) => s.trim()).filter(Boolean);
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
        planner: 'planner (turns ambiguous goals into precise plans; skip only for purely mechanical/small work)',
        'repo-historian': 'repo-historian (maintains wiki/CONTEXT.md/ADRs; skip if no maintained wiki wanted)',
        'milestone-auditor': 'milestone-auditor (audits plan premises at milestone boundaries; skip if no real milestone structure or planner was also skipped)',
      }[persona];
      const include = await askYesNo(rl, `\nInclude ${label}?`, true);
      if (include) selected.push(persona);
    }
    let researcherSelected = await askYesNo(
      rl,
      '\nInclude researcher (bridges academic literature via an arXiv MCP; needs ' +
        'a real MCP launch command wired in later via /setup-personas)?',
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
    console.log('  templates/researcher.md.tmpl -> .claude/agents/researcher.md (mcpServers placeholder still needs a real launch command — /setup-personas step 5 handles this)');
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

  copyDirRecursive(path.join(PKG_ROOT, 'skills', 'setup-personas'), path.join(skillsDir, 'setup-personas'));
  copyDirRecursive(path.join(PKG_ROOT, 'skills', 'coding-discipline'), path.join(skillsDir, 'coding-discipline'));
  console.log('  skills/setup-personas, skills/coding-discipline -> .claude/skills/ (invoke /setup-personas next)');

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
  ]);
  console.log('  .gitignore updated');

  const personaConfig = {
    testAndLintCommand: '',
    lintCommand: '',
    graphUpdateCommand: '',
    sourceGlobs: [],
    protectedPaths: [],
    gatedAgents: ['lead-programmer'],
    pluginVersion: version,
    personaSelection: selected.filter((p) => OPTIONAL_PERSONAS.includes(p)).concat(includeResearcher ? ['researcher'] : []),
    issueTracker: '',
  };
  fs.writeFileSync(path.join(claudeDir, 'persona-config.json'), JSON.stringify(personaConfig, null, 2) + '\n');
  console.log('  .claude/persona-config.json written (skeleton — fields blank until /setup-personas fills them in from a real repo scan)');

  console.log(
    '\nDone with the mechanical scaffolding. This CLI intentionally stops here — ' +
      'it does NOT scan your repo for test/lint commands, install third-party ' +
      'skills, build the code-review-graph, wire an arXiv MCP, prune CLAUDE.md, ' +
      'or run hook verification, because those all need real judgment against ' +
      'THIS repo\'s actual contents, not a deterministic copy.\n\n' +
      'Next step: open Claude Code in this project and run:\n\n' +
      '  /setup-personas\n\n' +
      '(it now exists as a project-local skill from the copy above) to finish ' +
      'the repo-specific config, verify hooks, and fill in persona-config.json ' +
      'for real.'
  );
}

main().catch((err) => {
  console.error('seb-personas-setup failed:', err.message);
  process.exit(1);
});
