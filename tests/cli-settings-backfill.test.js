#!/usr/bin/env node
'use strict';

// Exercises bin/cli.js's runUpdate() bashOutputMaxChars settings backfill
// (issue #478) against synthetic fixture projects — deliberately NOT
// tests/cli-backfill.test.js's real-content philosophy, since there's no
// regex-risk here to round-trip against real agents/*.md; a throwaway
// temp-dir project is enough to exercise "lacks the key" / "already set".

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');
const cliPath = path.join(REPO_ROOT, 'bin', 'cli.js');
const cli = require(cliPath);
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

const pluginVersion = JSON.parse(
  fs.readFileSync(path.join(REPO_ROOT, '.claude-plugin', 'plugin.json'), 'utf8')
).version;
const graphMcpLaunch = { command: 'npx', args: ['code-review-graph-mcp'] };

// Mirrors tests/cli-backfill.test.js's stampBody helper (bin/cli.js's stamp
// insertion isn't exported).
function stampBody(body, sourceRelPath) {
  const stamp = `<!-- antislop v${pluginVersion} | source: ${sourceRelPath} | ADAPT-substituted -->\n`;
  const fmMatch = body.match(/^---\r?\n[\s\S]*?\r?\n---\r?\n/);
  if (!fmMatch) return stamp + body;
  const end = fmMatch[0].length;
  return body.slice(0, end) + stamp + body.slice(end);
}

// Builds a fully-baselined synthetic project in `tmp` (current pluginVersion,
// every mirror stamped and hashed) so --update reaches the settings backfill
// without also tripping the unrelated render/diff loop.
function buildBaselineProject(tmp) {
  const specs = cli.buildFileSpecs([]);
  const config = {
    pluginVersion,
    personaSelection: [],
    substitutions: { graphMcpLaunch },
    fileHashes: {},
  };
  for (const spec of specs) {
    const cleanBody = cli.renderCleanBody(spec, config);
    const destAbsPath = path.join(tmp, spec.projectRelPath);
    fs.mkdirSync(path.dirname(destAbsPath), { recursive: true });
    fs.writeFileSync(destAbsPath, stampBody(cleanBody, spec.sourceRelPath));
    config.fileHashes[spec.projectRelPath] = cli.sha256Hex(cleanBody);
  }
  for (const spec of cli.buildHookScriptSpecs()) {
    const body = fs.readFileSync(spec.sourceAbsPath, 'utf8');
    const destAbsPath = path.join(tmp, spec.projectRelPath);
    fs.mkdirSync(path.dirname(destAbsPath), { recursive: true });
    fs.writeFileSync(destAbsPath, body);
    config.fileHashes[spec.projectRelPath] = cli.sha256Hex(body);
  }
  const claudeDir = path.join(tmp, '.claude');
  fs.mkdirSync(claudeDir, { recursive: true });
  fs.writeFileSync(path.join(claudeDir, 'persona-config.json'), JSON.stringify(config, null, 2) + '\n');
  return config;
}

function writeSettings(tmp, json) {
  fs.writeFileSync(path.join(tmp, '.claude', 'settings.json'), JSON.stringify(json));
}

function readSettings(tmp) {
  return JSON.parse(fs.readFileSync(path.join(tmp, '.claude', 'settings.json'), 'utf8'));
}

// HOME is isolated per spawn (its own empty tmp dir) so detectMarketplacePlugin
// can't pick up whatever the machine actually running these tests has at
// ~/.claude/settings.json (this repo dogfoods the plugin on itself).
function runUpdateCmd(tmp, home) {
  return spawnSync('node', [cliPath, '--update'], {
    cwd: tmp,
    env: Object.assign({}, process.env, { HOME: home }),
    encoding: 'utf8',
  });
}

check('runUpdate backfills bashOutputMaxChars into a settings.json that lacks it', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-settings-backfill-'));
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-settings-backfill-home-'));
  try {
    buildBaselineProject(tmp);
    writeSettings(tmp, {});
    const result = runUpdateCmd(tmp, home);
    assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
    assert.strictEqual(readSettings(tmp).bashOutputMaxChars, 12000);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
    fs.rmSync(home, { recursive: true, force: true });
  }
});

check('runUpdate never clobbers a project-chosen bashOutputMaxChars', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-settings-backfill-'));
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-settings-backfill-home-'));
  try {
    buildBaselineProject(tmp);
    writeSettings(tmp, { bashOutputMaxChars: 4000 });
    const result = runUpdateCmd(tmp, home);
    assert.strictEqual(result.status, 0, `expected exit 0, got ${result.status}: ${result.stdout}${result.stderr}`);
    assert.strictEqual(readSettings(tmp).bashOutputMaxChars, 4000);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
    fs.rmSync(home, { recursive: true, force: true });
  }
});

if (failures > 0) {
  console.error(`\n${failures} test(s) failed.`);
  process.exit(1);
}
console.log('\nAll cli-settings-backfill tests passed.');
