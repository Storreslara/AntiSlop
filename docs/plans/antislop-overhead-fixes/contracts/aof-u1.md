Unit: aof-u1

## Objective
Make the ladder helper scripts reachable in every installed project, so the orchestrator never searches the
filesystem for them. `bin/cli.js` installs `ladder-tier.sh`, `contract-guard.js`, `contract-score.js`,
`fail-count.sh` and `escalation-card.sh` into `<project>/.claude/bin/`, on both the fresh standalone scaffold
and `--update`. The orchestrator, task-master and agent-auditor prose then points to `.claude/bin/...` and to
`.claude/hooks/scripts/reviewer-tier.sh`, and forbids filesystem-wide searches. This is spec Step 1 (P1, alt 1A).

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-overhead-fixes/spec.md`, "Step 1 (aof-u1)" and
"Context, P1". This file is the contract of record.

## Affected files
- `bin/cli.js`: new constant plus spec builder next to `buildHookScriptSpecs()` (anchor: line matching
  `function buildHookScriptSpecs() {`); the `runUpdate` concatenation of hook-script specs; the standalone
  scaffold copy (anchor: line matching `copyDirRecursive(path.join(PKG_ROOT, 'hooks', 'scripts'), hooksScriptsDir);`)
- `agents/orchestrator.md`: lines that name `bin/ladder-tier.sh`, `bin/escalation-card.sh`,
  `bin/contract-guard.js` and `hooks/scripts/reviewer-tier.sh` (currently 394, 467-468, 473-474, 481-483,
  492-502, 532-533, 559-560), plus line 474-475 ("A set `CLAUDE_CODE_SUBAGENT_MODEL` silently wins ...")
- `agents/task-master.md`: lines 72, 122-129 and 336 (contract-guard references)
- `agents/agent-auditor.md`: line 92 (prose reference)
- `.claude/agents/orchestrator.md`, `.claude/agents/task-master.md`, `.claude/agents/agent-auditor.md`,
  `.claude/bin/*` and the `fileHashes` in `.claude/persona-config.json`: **generated only** by
  `node bin/cli.js --update`
- `.claude-plugin/plugin.json` (version bump) and `CHANGELOG.md` (entry), in the same commit
- `tests/bin-helpers-scaffold.test.sh` (new)
- `tests/validate.sh`: registration (anchor: the block for `tests/ladder-tier.test.sh`, or the nearest
  helper-test block)

## Ordered edits
1. In `bin/cli.js`, add `const BIN_HELPER_FILES = ['ladder-tier.sh', 'contract-guard.js', 'contract-score.js', 'fail-count.sh', 'escalation-card.sh'];`
   and a `buildBinHelperSpecs()` that returns, for each file,
   `{ projectRelPath: '.claude/bin/<f>', sourceAbsPath: <PKG_ROOT>/bin/<f>, sourceRelPath: 'bin/<f>', kind: 'raw' }`,
   modelled exactly on `buildHookScriptSpecs()`. It must be an explicit list and must **not** include
   `harness-integrity.sh` (spec R2).
2. Wherever `runUpdate` concatenates `buildHookScriptSpecs()` into its spec list, concatenate
   `buildBinHelperSpecs()` beside it, so drift detection and `fileHashes` cover `.claude/bin/*`.
3. In the standalone scaffold, right after the `hooks/scripts` copy, copy each `BIN_HELPER_FILES` entry to
   `<claudeDir>/bin/`, creating the directory, and log `  bin/<helpers> -> .claude/bin/`. Then confirm that
   the scaffold's recorded hashes include the five files. If the scaffold records hashes through a spec list,
   reuse `buildBinHelperSpecs()`.
4. In `agents/orchestrator.md`:
   - replace `bash bin/ladder-tier.sh` with `bash .claude/bin/ladder-tier.sh`;
   - replace `bash bin/escalation-card.sh` with `bash .claude/bin/escalation-card.sh`;
   - replace `node bin/contract-guard.js` with `node .claude/bin/contract-guard.js`;
   - replace the prose `bin/ladder-tier.sh` with `.claude/bin/ladder-tier.sh`;
   - replace `bash hooks/scripts/reviewer-tier.sh` and the prose `hooks/scripts/reviewer-tier.sh` with
     `.claude/hooks/scripts/reviewer-tier.sh`. Keep `HEAD` without angle brackets in the example (spec
     disposition of marker notes 265-267).

   Add this paragraph at the end of "Per-unit model routing":
   "Never search the filesystem for a harness script (`find /`, `locate`, a glob over `~` or `/`): the
   installed copies are at `.claude/bin/` and `.claude/hooks/scripts/`. If one is missing, take that
   script's own fail-closed result (`opus`), append `RULING <UTC ISO-8601 timestamp> unit=<task-id>
   decision=helper missing: <path>: opus` to the rulings ledger, and tell the user to run
   `node <plugin>/bin/cli.js --update`."

   Replace the sentence "A set `CLAUDE_CODE_SUBAGENT_MODEL` silently wins over this routing." with
   "An explicit dispatch `model` and a persona's frontmatter `model:` take precedence over
   `CLAUDE_CODE_SUBAGENT_MODEL` (measured on CLI 2.1.302, A/B pilot 4)."
5. In `agents/task-master.md` and `agents/agent-auditor.md`, make the same path replacements for every
   `bin/contract-guard.js`, `bin/ladder-tier.sh` and `bin/escalation-card.sh` reference that names a command
   to run. References that name the plugin's source file (for example "edit `bin/contract-guard.js`") stay as
   they are.
6. Bump `.claude-plugin/plugin.json`'s `version` (patch) and add a `CHANGELOG.md` entry naming aof-u1.
7. Run `node bin/cli.js --update` to regenerate the `.claude/` mirrors, `.claude/bin/` and `fileHashes`. Never
   hand-edit a `.claude/` mirror.
8. Write `tests/bin-helpers-scaffold.test.sh`. In a `mktemp -d` git repo with one commit, run
   `node "$ROOT/bin/cli.js" --personas=spec-master,task-master,reviewer,scribe` and then assert:
   - (a) the 5 files exist under `.claude/bin/`;
   - (b) `.claude/bin/harness-integrity.sh` does not exist;
   - (c) the output of `bash .claude/bin/ladder-tier.sh u1` matches
     `^ladder-tier: (haiku|sonnet) n=0 ladder=[a-z,]+ reason=no-contract$`;
   - (d) the first line of `node .claude/bin/contract-guard.js <tmp contract file> --unit=u1` starts
     `contract-guard: `. Use any small contract with the nine headings;
   - (e) after `rm -rf .claude/bin` and `node "$ROOT/bin/cli.js" --update`, (a) holds again.

   Clean up with a trap. Register the test in `tests/validate.sh` in the same shape as its neighbours
   (`if bash tests/...; then echo OK; else echo FAIL; failures=...`), placed so that a FAIL increments the
   counter that makes validate.sh exit non-zero.
9. Commit with the subject `feat(aof-u1): install ladder helpers to .claude/bin and point the orchestrator at them`.

## Do NOT touch
- `bin/ladder-tier.sh`, `bin/contract-guard.js`, `bin/contract-score.js`, `bin/fail-count.sh`,
  `bin/escalation-card.sh`: no script edits. The layout already resolves under `.claude/`.
- `bin/harness-integrity.sh` and `hooks/scripts/session-start.sh` (spec R2; re-arming the drift check is a
  separate operator decision).
- `hooks/scripts/reviewer-tier.sh`: thresholds, sensitive paths and downgrade-only prose are unchanged.
- `hooks/hooks.json`, `templates/settings-fragment.json`, `harness-integrity-gate.sh`'s Set A lists.
- Anything under `eval/`.
- `.claude/persona-config.json`, except through `node bin/cli.js --update`.

## Acceptance criteria
- AC1.1 run: `bash tests/bin-helpers-scaffold.test.sh` (exit 0). mutation: removing the copy in ordered
  edit 3 fails (a); removing the concatenation in ordered edit 2 fails (e).
- AC1.2 run: `test "$(grep -cE 'bash bin/(ladder-tier|escalation-card)\.sh|node bin/contract-guard\.js|bash hooks/scripts/reviewer-tier\.sh' agents/orchestrator.md agents/task-master.md | awk -F: '{s+=$2} END{print s}')" = 0`.
  mutation: restoring one old command path fails it.
- AC1.3 run: `grep -qF 'Never search the filesystem for a harness script' agents/orchestrator.md && ! grep -qF 'silently wins over this routing' agents/orchestrator.md`.
  mutation: reverting either edit fails it.
- AC1.4 run: `bash tests/validate.sh` (exit 0). mutation: inserting `exit 1` as line 2 of the new test makes
  validate.sh exit non-zero.
- AC1.5 run: `! node bin/cli.js --update --dry-run 2>&1 | grep -q 'unresolved placeholder.*orchestrator.md'`.
  mutation: writing `<HEAD>` in the reviewer-tier example fails it.
- AC1.6 run: `git show --name-only --format= HEAD | grep -qx '.claude-plugin/plugin.json' && git show --name-only --format= HEAD | grep -qx CHANGELOG.md` (constitution P3, same commit).

## Pre-resolved context
- Evidence: in pilot 4, E1, E2 and E5 lost about 120 s each to `find /` timeouts, and every B run logged
  `RULING ... no-contract (bin/ladder-tier.sh absent)` (`eval/abtest/.runs/*_B_uniform_1/stream.jsonl`).
- The layout check that makes the shim work without script edits. `ladder-tier.sh:35` sets
  `repo_root=<script dir>/..`, which is `.claude`. Its dependencies, and where they resolve:
  - `:51` sources `hooks/scripts/lib/state-access.sh`, which is `.claude/hooks/scripts/lib/state-access.sh`;
  - `:74` reads `agents/lead-programmer.md`, which is `.claude/agents/lead-programmer.md`;
  - `:84` reads the cutover line from `agents/orchestrator.md`, which is `.claude/agents/orchestrator.md`;
  - `:118` runs `bin/contract-guard.js`, which is `.claude/bin/contract-guard.js`.

  `contract-guard.js:97` finds `contract-score.js` through `__dirname`. `fail-count.sh` and
  `escalation-card.sh` use the same `repo_root` pattern (lines 6-13 and 8-15).
- The scaffold copy is at cli.js:2523, and `buildHookScriptSpecs()` is at cli.js:642 (explorer
  `overhead-fixes-explorer`, grep-derived). The standalone scaffold copies nothing from `bin/` today
  (explorer 1a).
- Under a fresh scaffold, `lead-programmer.md` frontmatter is `model: haiku` and there is no contract, so the
  expected output is `ladder-tier: sonnet n=0 ladder=sonnet,sonnet,opus,opus reason=no-contract`. The
  criterion also accepts `haiku` in case the scaffold changes the default.
- The orchestrator's reviewer-tier example is at agents/orchestrator.md:532-533.

## Escalation
If `ladder-tier.sh` run from `.claude/bin/` prints `reason=fail-closed` in the temporary scaffold, a
dependency did not resolve. Report which one, and do not edit the script: the fix belongs in the scaffold
copy list. If `--update` refuses to regenerate a mirror, report the cli.js message verbatim. If a gate
(harness-integrity, reviewed-path, protected-paths) blocks a write, report it and wait; never route around it.
Any change outside "Affected files" goes to the report as a proposal.
