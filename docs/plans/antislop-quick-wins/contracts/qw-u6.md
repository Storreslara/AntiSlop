Unit: qw-u6

## Objective
Operator ruling e2 (OQ3 = c, "set sonnet in the product"): the main session, which runs as the orchestrator
(`"agent": "orchestrator"` in the settings fragment), runs on `sonnet` by default, with a documented
per-project opt-out.
- `agents/orchestrator.md` frontmatter changes from `model: inherit` to `model: sonnet`. Claude Code applies
  an `agent`-driven main thread's frontmatter model to the whole session (documented), and the line touches
  nothing else: every subagent keeps its own `model:` line.
- New persona-config key `orchestratorModel` (`sonnet` | `opus` | `haiku` | `inherit`, default `sonnet`).
  `bin/cli.js` renders it into the installed `.claude/agents/orchestrator.md` frontmatter at scaffold and at
  `--update --force-render`; `inherit` restores today's behaviour (the user's own session model). An absent
  key, an unrecognised value (a printed note), another persona, or a source with no `model:` line leaves
  the body unchanged.
- README states the new default and the opt-out.

No eval amendment is needed: the A/B harness's `uniform` policy (aof-u6, OD-23) strips every frontmatter
`model:` line in Arm B's plugin copy, so the orchestrator line goes too, and the renderer never adds a line
that is not there. This is spec Step 6.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-quick-wins/spec.md`, "Step 6 (qw-u6)" and "Context,
e2". This file is the contract of record. Dispatch it only after qw-u5 has reached PASS (shared `bin/cli.js`,
`tests/validate.sh` anchor and bump files; aof-u4's `knowledgeWrites` schema property must already exist).

## Affected files
- `tests/orchestrator-model.test.js` (anchor: new file)
- `agents/orchestrator.md` (anchor: the frontmatter line `model: inherit`, line 4)
- `bin/cli.js` (anchors: line matching `function renderCleanBody(spec, config) {`; the `return inlineProtocolBlock(body, spec.protocolTier, ...` line inside it; the scaffold line `const body = inlineProtocolBlock(fs.readFileSync(src, 'utf8'), protocolTierFor(name), name, gatedAgents);`; line matching `module.exports = {`)
- `templates/persona-config.schema.json` (anchor: line matching `    "pluginVersion": {`)
- `README.md` (anchors: the persona-table row starting `` | `orchestrator` | inherit |``; the config-table row starting `` | `defaultImplementerModel` |``)
- `tests/validate.sh` (anchor: line matching `echo "== blast-radius: the reviewer's own file-level blast radius, explorer only as fallback (Bash, qw-u5) =="`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/agents/*.md` (orchestrator frontmatter; others only their stamp), `.claude/persona-protocol*.md`, `.claude/protocol-digest.md`, the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/orchestrator-model.test.js`
   anchor: new file
   indent: 0
   insert-after:
~~~
#!/usr/bin/env node
'use strict';

// qw-u6: the orchestrator ships `model: sonnet`; persona-config `orchestratorModel` overrides the
// rendered mirror's frontmatter line, and `inherit` keeps the user's session model.

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');
const cli = require(path.join(REPO_ROOT, 'bin/cli.js'));

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

function frontmatterModels(text) {
  const fm = text.match(/^---\n[\s\S]*?\n---\n/);
  return fm ? (fm[0].match(/^model: .*$/gm) || []) : [];
}

const SRC = fs.readFileSync(path.join(REPO_ROOT, 'agents/orchestrator.md'), 'utf8');

check('(a) agents/orchestrator.md ships exactly one frontmatter line `model: sonnet`', () => {
  assert.deepStrictEqual(frontmatterModels(SRC), ['model: sonnet']);
});

check('(b) an absent key leaves the body unchanged', () => {
  assert.strictEqual(cli.applyOrchestratorModel(SRC, 'orchestrator', {}), SRC);
  assert.strictEqual(cli.applyOrchestratorModel(SRC, 'orchestrator', null), SRC);
});

check('(c) inherit and opus replace only the frontmatter model line', () => {
  for (const v of ['inherit', 'opus', 'haiku']) {
    const out = cli.applyOrchestratorModel(SRC, 'orchestrator', { orchestratorModel: v });
    assert.deepStrictEqual(frontmatterModels(out), [`model: ${v}`]);
    assert.strictEqual(out.replace(`model: ${v}`, 'model: sonnet'), SRC);
  }
});

check('(d) an unrecognised value keeps the shipped model', () => {
  assert.strictEqual(cli.applyOrchestratorModel(SRC, 'orchestrator', { orchestratorModel: 'gpt-x' }), SRC);
});

check('(e) another persona is never touched', () => {
  const rev = fs.readFileSync(path.join(REPO_ROOT, 'agents/reviewer.md'), 'utf8');
  assert.strictEqual(cli.applyOrchestratorModel(rev, 'reviewer', { orchestratorModel: 'inherit' }), rev);
});

check('(f) a source with no model line (A/B uniform strip) gains none', () => {
  const stripped = SRC.replace(/^model: sonnet\n/m, '') + '\nmodel: example prose\n';
  assert.deepStrictEqual(frontmatterModels(stripped), []);
  assert.strictEqual(cli.applyOrchestratorModel(stripped, 'orchestrator', { orchestratorModel: 'opus' }), stripped);
});

check('(g) a body line after the frontmatter that starts with model: is left alone', () => {
  const body = SRC + '\nmodel: example prose\n';
  const out = cli.applyOrchestratorModel(body, 'orchestrator', { orchestratorModel: 'inherit' });
  assert.ok(out.endsWith('\nmodel: example prose\n'));
});

check('(h) the schema declares orchestratorModel with the four values and default sonnet', () => {
  const schema = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'templates/persona-config.schema.json'), 'utf8'));
  const p = schema.properties.orchestratorModel;
  assert.ok(p, 'no orchestratorModel property');
  assert.deepStrictEqual(p.enum, ['sonnet', 'opus', 'haiku', 'inherit']);
  assert.strictEqual(p.default, 'sonnet');
});

check('(i) scaffold renders sonnet; the opt-out renders inherit after --update --force-render', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'orch-model-'));
  try {
    const run = (args) => execFileSync('node', [path.join(REPO_ROOT, 'bin/cli.js'), ...args], { cwd: tmp, stdio: 'pipe' });
    execFileSync('git', ['init', '-q', '.'], { cwd: tmp });
    run(['--personas=spec-master,task-master,reviewer,scribe']);
    const mirror = path.join(tmp, '.claude', 'agents', 'orchestrator.md');
    assert.deepStrictEqual(frontmatterModels(fs.readFileSync(mirror, 'utf8')), ['model: sonnet']);
    const cfgPath = path.join(tmp, '.claude', 'persona' + '-config.json');
    const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
    cfg.orchestratorModel = 'inherit';
    fs.writeFileSync(cfgPath, JSON.stringify(cfg, null, 2) + '\n');
    // A fresh scaffold has no graph launch command recorded, so --update exits 1 over explorer.md
    // after rendering every other file; only the orchestrator mirror matters here.
    let out = '';
    try { out = run(['--update', '--force-render']).toString(); } catch (e) { out = String(e.stdout); }
    assert.ok(out.includes('.claude/agents/orchestrator.md: updated'), `orchestrator mirror not re-rendered: ${out.slice(0, 300)}`);
    assert.deepStrictEqual(frontmatterModels(fs.readFileSync(mirror, 'utf8')), ['model: inherit']);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

if (failures > 0) {
  console.log(`${failures} orchestrator-model check(s) FAILED.`);
  process.exit(1);
}
console.log('All orchestrator-model checks passed.');
~~~
2. command: `node tests/orchestrator-model.test.js`
   expect: 1
   The red step: `applyOrchestratorModel` is not exported yet and the frontmatter still reads `inherit`.
3. file: `agents/orchestrator.md`
   anchor: line matching `model: inherit` (frontmatter, line 4; the only such line)
   indent: 0
   before: `model: inherit`
   after: `model: sonnet`
4. file: `bin/cli.js`
   anchor: line matching `function renderCleanBody(spec, config) {`
   indent: 0
   before: `function renderCleanBody(spec, config) {`
   after:
~~~
// qw-u6: the orchestrator runs as the main session (settings `"agent": "orchestrator"`), so its
// frontmatter `model:` sets the session model; agents/orchestrator.md ships `model: sonnet`.
// persona-config.json `orchestratorModel` overrides that one line in the rendered mirror; `inherit`
// keeps the user's own session model. An absent key, an unrecognised value, another persona, or a
// source with no `model:` line (the A/B harness strips it under `uniform`) leaves the body unchanged.
const ORCHESTRATOR_MODELS = ['sonnet', 'opus', 'haiku', 'inherit'];

function applyOrchestratorModel(body, name, config) {
  if (name !== 'orchestrator' || config == null || config.orchestratorModel == null) return body;
  const value = config.orchestratorModel;
  if (!ORCHESTRATOR_MODELS.includes(value)) {
    console.warn(`Note: persona-config.json orchestratorModel "${value}" is not one of ${ORCHESTRATOR_MODELS.join(', ')}; keeping the shipped orchestrator model.`);
    return body;
  }
  const fm = body.match(/^---\n[\s\S]*?\n---\n/);
  if (!fm || !/^model: .*$/m.test(fm[0])) return body;
  return fm[0].replace(/^model: .*$/m, `model: ${value}`) + body.slice(fm[0].length);
}

function renderCleanBody(spec, config) {
~~~
5. file: `bin/cli.js`
   anchor: line matching `  return inlineProtocolBlock(body, spec.protocolTier, path.basename(spec.projectRelPath, '.md'), config.gatedAgents);`
   indent: 2
   before: `  return inlineProtocolBlock(body, spec.protocolTier, path.basename(spec.projectRelPath, '.md'), config.gatedAgents);`
   after:
~~~
  const personaName = path.basename(spec.projectRelPath, '.md');
  return inlineProtocolBlock(applyOrchestratorModel(body, personaName, config), spec.protocolTier, personaName, config.gatedAgents);
~~~
6. file: `bin/cli.js`
   anchor: line matching `    const body = inlineProtocolBlock(fs.readFileSync(src, 'utf8'), protocolTierFor(name), name, gatedAgents);` (the scaffold loop over `allAgentNames`)
   indent: 4
   before: `    const body = inlineProtocolBlock(fs.readFileSync(src, 'utf8'), protocolTierFor(name), name, gatedAgents);`
   after: `    const body = inlineProtocolBlock(applyOrchestratorModel(fs.readFileSync(src, 'utf8'), name, existingPersonaConfig), protocolTierFor(name), name, gatedAgents);`
7. file: `bin/cli.js`
   anchor: line matching `module.exports = {`
   indent: 0
   before: `module.exports = {`
   after:
~~~
module.exports = {
  applyOrchestratorModel,
~~~
8. file: `templates/persona-config.schema.json`
   anchor: line matching `    "pluginVersion": {`
   indent: 4
   before: `    "pluginVersion": {`
   after:
~~~
    "orchestratorModel": {
      "type": "string",
      "enum": ["sonnet", "opus", "haiku", "inherit"],
      "default": "sonnet",
      "description": "The model of the main session, which runs as the orchestrator. Rendered into .claude/agents/orchestrator.md's frontmatter `model:` line by install and by `--update --force-render`. Absent: the shipped `model: sonnet`. `inherit` keeps your own session model (the behaviour before qw-u6). An unrecognised value keeps the shipped model and prints a note."
    },
    "pluginVersion": {
~~~
9. file: `README.md`
   anchor: the persona-table row for `orchestrator` (README.md:70 at 1d4abf5a)
   indent: 0
   before:
~~~
| `orchestrator` | inherit | Always on. Main agent; routes, never implements. |
~~~
   after:
~~~
| `orchestrator` | sonnet | Always on. Main agent; routes, never implements. Set `orchestratorModel` to `inherit` to keep your own session model. |
~~~
10. file: `README.md`
   anchor: the configuration-table row for `defaultImplementerModel` (README.md:104 at 1d4abf5a)
   indent: 0
   before:
~~~
| `defaultImplementerModel` | `haiku` | Tier the escalation ladder starts from. |
~~~
   after:
~~~
| `defaultImplementerModel` | `haiku` | Tier the escalation ladder starts from. |
| `orchestratorModel` | `sonnet` | Model of the main session (the orchestrator): `sonnet`, `opus`, `haiku` or `inherit` (your own session model). Apply a change with `node <plugin>/bin/cli.js --update --force-render`. |
~~~
11. file: `tests/validate.sh`
   anchor: line matching `echo "== blast-radius: the reviewer's own file-level blast radius, explorer only as fallback (Bash, qw-u5) =="`
   indent: 0
   before:
~~~
echo "== blast-radius: the reviewer's own file-level blast radius, explorer only as fallback (Bash, qw-u5) =="
if bash tests/blast-radius.test.sh > /dev/null; then
  echo "OK   tests/blast-radius.test.sh"
else
  echo "FAIL tests/blast-radius.test.sh"
  fail=1
fi
~~~
   after:
~~~
echo "== blast-radius: the reviewer's own file-level blast radius, explorer only as fallback (Bash, qw-u5) =="
if bash tests/blast-radius.test.sh > /dev/null; then
  echo "OK   tests/blast-radius.test.sh"
else
  echo "FAIL tests/blast-radius.test.sh"
  fail=1
fi

echo
echo "== orchestrator-model: sonnet by default, orchestratorModel opt-out (Node, qw-u6) =="
if node tests/orchestrator-model.test.js > /dev/null 2>&1; then
  echo "OK   tests/orchestrator-model.test.js"
else
  echo "FAIL tests/orchestrator-model.test.js"
  fail=1
fi
~~~
12. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.192 to 0.31.193).
13. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Orchestrator on sonnet by default (qw-u6, VERSION).** Operator ruling e2: agents/orchestrator.md ships `model: sonnet` instead of `model: inherit`, so the main session, which runs as the orchestrator, uses sonnet unless the project opts out. New persona-config key `orchestratorModel` (`sonnet`, `opus`, `haiku`, `inherit`; default `sonnet`) is rendered into the installed orchestrator's frontmatter by install and by `--update --force-render`; `inherit` keeps your own session model. Subagent models are unchanged. The A/B harness's `uniform` policy still strips the line, so no eval change. New test tests/orchestrator-model.test.js.
~~~
   Replace `VERSION` with the version that edit 12 wrote.
14. command: `node bin/cli.js --update`
   expect: 0
15. command: `node tests/orchestrator-model.test.js`
   expect: 0
16. command: `git add tests/orchestrator-model.test.js && git add -u && git commit -m "feat(qw-u6): the orchestrator runs on sonnet by default; orchestratorModel opts out"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `templates/settings-fragment.json` (no `"model"` key: it would set the session model from settings, below `--model` and `/model`, and apply even when a user removes `"agent"`; criterion 5)
- `eval/` and `tests/abtest-arms.test.sh` (aof-u6's strip already covers the orchestrator line; criterion 6 re-runs its test)
- `agents/reviewer.md`, `agents/lead-programmer.md` and every other `agents/*.md` frontmatter (subagent tiers are unchanged)
- `adapters/` (the cursor and codex orchestrator ports keep their own model handling; criterion 5)
- `.claude/agents/` by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'node tests/orchestrator-model.test.js >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: delete the `if (!ORCHESTRATOR_MODELS.includes(value)) { ... }` block; check (d) renders `model: gpt-x` and fails, and stdout is `1`. A second mutation, applying the replace to the whole body instead of the frontmatter, fails check (f).
2. run: `bash -c 'for f in agents/orchestrator.md .claude/agents/orchestrator.md; do sed -n "/^---$/,/^---$/p" "$f" | grep -c "^model: sonnet$"; done | tr "\n" " "'`
   exit: 0
   stdout: `1 1 `
   mutation: skip edit 3; both files still read `model: inherit` and stdout is `0 0 `.
3. run: `bash -c 'for f in agents/*.md; do [ "$f" = agents/orchestrator.md ] && continue; b=$(git log --format=%H --grep="(qw-u6)" | tail -1); git diff "$b^..HEAD" -- "$f" | grep -c "^[-+]model:" ; done | sort -u | tr "\n" " "'`
   exit: 0
   stdout: `0 `
   mutation: change `agents/reviewer.md` to `model: sonnet` in a qw-u6 commit; a `1` joins the output.
4. run: `bash -c 'node -e "const s=require(\"./templates/persona-config.schema.json\").properties.orchestratorModel; console.log(s.default, s.enum.join(\",\"))"'`
   exit: 0
   stdout: `sonnet sonnet,opus,haiku,inherit`
   mutation: skip edit 8; node throws on `undefined.default` and exits 1.
5. run: `bash -c 'b=$(git log --format=%H --grep="(qw-u6)" | tail -1); git diff --name-only "$b^..HEAD" -- templates/settings-fragment.json eval adapters hooks | wc -l'`
   exit: 0
   stdout: `0`
   mutation: add `"model": "sonnet"` to `templates/settings-fragment.json` in a qw-u6 commit; stdout is `1`.
6. run: `bash -c 'bash tests/abtest-arms.test.sh >/dev/null 2>&1 && node tests/cli-backfill.test.js >/dev/null && node tests/default-implementer-model.test.js >/dev/null && node tests/writer-tier-consistency.test.js >/dev/null && node tests/effort-tier-consistency.test.js >/dev/null; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: in a scratch copy, make `abtest_uniform_models` skip `orchestrator.md`; the check `no persona frontmatter in the uniform copy has a model line` fails and stdout is `1`.
7. run: `bash -c 'b=$(git log --format=%H --grep="(qw-u6)" | tail -1); bash hooks/scripts/version-stamp-check.sh "$b^..HEAD" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 12; stdout reads `version-stamp-check: violation touched: yes`.
8. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `process.exit(1);` as line 3 of tests/orchestrator-model.test.js; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes the test (edit 1) fails first (edit 2, 10 checks fail). spec-master ran edits 1 to 8 on a clone of 1d4abf5a: all 9 checks pass, including (i), which scaffolds a temp project (mirror reads `model: sonnet`), sets `orchestratorModel: inherit` and runs `--update --force-render` (mirror reads `model: inherit`). A fresh scaffold has no graph launch command, so that `--update` exits 1 over explorer.md after rendering the orchestrator; the test reads the `orchestrator.md: updated` line instead of the exit code. On the same clone cli-backfill, default-implementer-model, writer-tier-consistency, effort-tier-consistency, adapter-protocol-parity and abtest-arms (108 passed, after commit) all pass.
alternatives: A frontmatter `model: sonnet` alone: narrowest (only the `agent`-driven main thread; documented: "the main thread itself takes on that subagent's tool restrictions and model"), but its only opt-out is hand-editing a managed mirror, which `--update` then reports as diverged. B `"model": "sonnet"` in templates/settings-fragment.json: sets the session model from project settings, which Claude Code ranks below `/model`, `--model` and `ANTHROPIC_MODEL`, still applies when a user drops `"agent"`, and leaves the frontmatter saying `inherit`; rejected. C (chosen) A plus the `orchestratorModel` config key rendered into the mirror: same scope as A, the opt-out survives `--update`, and absent config means sonnet.
precedence: Claude Code documents that the agent frontmatter model applies to the main session, and ranks `/model` > `--model` > `ANTHROPIC_MODEL` > settings `model` for a plain session. Where the agent frontmatter sits relative to `/model` and `--model` is not documented (claude-code-guide, 2026-10-20). The documented opt-out is therefore the config key, not `/model`.
eval: Arm B runs `claude --agent orchestrator --model "$ABTEST_MODEL"`. Under `uniform`, `abtest_uniform_models` strips every `^model:` frontmatter line from the copy's `agents/*.md` before the scaffold, and the scaffold runs with no persona-config yet, so `applyOrchestratorModel` gets `existingPersonaConfig = null` and the stripped source: the worktree orchestrator has no `model:` line, as today. Under `shipped`, the worktree orchestrator reads `model: sonnet` and the undocumented precedence decides whether `--model` wins; that is a measurement note for the next shipped run (read the orchestrator's model from the result's `modelUsage`), not a config change. No OD amendment, no qw-u7.
pins-searched: no test pins the orchestrator's `model: inherit` (grep over tests/). writer-tier-consistency AC-D9 bans the prose "`model: sonnet` frontmatter is the" in agents/orchestrator.md; this unit adds no orchestrator prose. README.md:70 was the only doc stating `inherit` for the orchestrator.
this-repo: the plugin's own `.claude/persona-config.json` has no `orchestratorModel`, so after `--update` this repo's main session also runs on sonnet. Opting this repo out is an operator decision, not part of this unit.
blast-radius: agents/orchestrator.md:4, bin/cli.js:1103 (renderCleanBody, used by runUpdate), bin/cli.js:2504 (initial scaffold loop), bin/cli.js:2778 (module.exports), templates/persona-config.schema.json:60, README.md:70 and :104, eval/abtest/arms/arm-b.sh:35 and :88 (read only). Line numbers are at 1d4abf5a; work from the anchors.
version: .claude-plugin/plugin.json and package.json read 0.31.192 after qw-u5 if no fix round bumped; edit 12 adds one (expected 0.31.193).
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
commit-message: feat(qw-u6): the orchestrator runs on sonnet by default; orchestratorModel opts out
diagnosis: none
review-packet:
~~~
unit: qw-u6
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
~~~

## Escalation
If a `before:` payload is not found verbatim (aof-u4 edits `bin/cli.js` argument handling and the schema;
qw-u1 and qw-u5 edit `bin/cli.js` and `tests/validate.sh`), stop and report the current text. If `node
bin/cli.js --update` reports the orchestrator mirror as diverged, quote it and stop. If a gate blocks a
command, report it and wait. Anything outside "Affected files" goes to your report as a proposal.
