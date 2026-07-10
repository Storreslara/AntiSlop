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
const { spawnSync } = require('child_process');

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

  const scriptedMode = yesToAll || Boolean(personasFlag);
  const wantMattpocock = args.includes('--with-mattpocock')
    ? true
    : scriptedMode
    ? false
    : await askYesNoStandalone(
        '\nRun the mattpocock/skills installer now (npx skills@latest add mattpocock/skills)? ' +
          'It opens an interactive picker in this same terminal — you select the skills yourself.'
      );
  if (wantMattpocock) {
    console.log('\nRunning: npx skills@latest add mattpocock/skills (interactive — follow the prompts)');
    const result = spawnSync('npx', ['skills@latest', 'add', 'mattpocock/skills'], {
      stdio: 'inherit',
      cwd: CWD,
    });
    if (result.status !== 0) {
      console.log('  mattpocock/skills installer exited non-zero — re-run it yourself if that was unintended.');
    }
    console.log(
      '  Done. /setup-personas still needs to record which skills you picked and substitute the ' +
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
    console.log('\nRunning: pipx install code-review-graph');
    const pipx = spawnSync('pipx', ['install', 'code-review-graph'], { stdio: 'inherit', cwd: CWD });
    if (pipx.error || pipx.status !== 0) {
      console.log('  pipx install failed or pipx is not installed — install pipx/Python first, then re-run with --with-graph.');
    } else {
      console.log('\nRunning: code-review-graph install --platform claude-code');
      spawnSync('code-review-graph', ['install', '--platform', 'claude-code'], { stdio: 'inherit', cwd: CWD });
      console.log(
        '  Installed. IMPORTANT: this tool registers itself PROJECT-WIDE in .mcp.json by default — ' +
          'every persona would inherit it, which is exactly the context-bloat problem this system ' +
          'avoids elsewhere. This CLI deliberately does NOT edit .mcp.json or explorer.md\'s ' +
          '`mcpServers:` placeholder for you (it would mean guessing at a schema this CLI hasn\'t ' +
          'verified against what got written). /setup-personas step 4 does that rescoping for real — ' +
          'run it next, don\'t skip straight past this.'
      );
    }
  } else if (!scriptedMode) {
    console.log('  Skipped — /setup-personas step 4 covers this if you want it done via the LLM-driven flow instead.');
  }

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
