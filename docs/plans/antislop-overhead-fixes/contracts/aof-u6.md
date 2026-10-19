Unit: aof-u6

## Objective
Under `ABTEST_POLICY=uniform`, Arm B really runs every persona on the run's model. In the plugin copy only:
- the `model:` frontmatter line is stripped from every `agents/*.md`;
- a copy-only PreToolUse hook on `Agent`/`Task` rewrites the dispatch's `model` to the run's model, through
  `hookSpecificOutput.updatedInput`.

The `shipped` policy, Arm A and the product tree are untouched. The change is recorded as amendment OD-23.
This is spec Step 6 (operator ruling OQ2 = b). It is a harness change, not a product change.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-overhead-fixes/spec.md`, "Step 6 (aof-u6)", which
holds the verbatim OD-23 and experiment-doc texts. This file is the contract of record. It depends on aof-u5
(OD-22 must already be in both documents).

## Affected files
- `eval/abtest/arms/common.sh`: a new function after `abtest_relax_bash_gates` (anchor: line matching `# abtest_arm_setup WORKTREE: refuse a worktree or config dir inside the harness and make a per-run HOME.`; insert before it)
- `eval/abtest/arms/arm-b.sh`: the line `abtest_plugin_copy "$plugin" "$copydir/plugin" || ...` (currently line 34), with the call added after it
- `tests/abtest-arms.test.sh`: new checks after the anchor line matching `abtest_relax_bash_gates "$T/pcopy" 2> /dev/null; check "a second relaxation of the same copy fails (nothing left to drop)"`
- `docs/plans/antislop-vs-fable-evals/operator-decisions.md`: append OD-23 after OD-22
- `docs/experiments/abtest-2026-10.md`: insert the OD-23 amendment paragraph directly after the OD-22 amendment paragraph

## Ordered edits
1. In `common.sh`, add `abtest_uniform_models DEST MODEL`, commented
   "# abtest_uniform_models DEST MODEL: OD-23. ...". It runs `python3 -I -` with a heredoc, in the same style
   as `abtest_relax_bash_gates`, and:
   - (a) for every `DEST/agents/*.md`, removes the line matching `^model:` inside the first `---` ... `---`
     frontmatter block only, and counts the removals;
   - (b) fails if the count is 0, or if any `^model:` line remains in any frontmatter;
   - (c) writes `DEST/hooks/scripts/abtest-uniform-model.sh` with mode 755, with MODEL baked in as a literal
     validated against `^[A-Za-z0-9._-]+$`, and fails otherwise. The script reads stdin JSON with `jq`. If
     `.tool_name` is `Agent` or `Task`, it prints
     `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":(.tool_input + {"model":"<MODEL>"})}}`.
     In every other case it prints nothing. It always exits 0;
   - (d) appends to `cfg["hooks"]["PreToolUse"]` one entry
     `{"matcher":"Agent|Task","hooks":[{"type":"command","command":"${CLAUDE_PLUGIN_ROOT}/hooks/scripts/abtest-uniform-model.sh"}]}`,
     failing if any existing entry already names `abtest-uniform-model.sh`. That failure makes a second
     application fail, as with `abtest_relax_bash_gates`.
2. In `arm-b.sh`, after the plugin-copy line and before the scaffold, add
   `if [ "$policy" = uniform ]; then abtest_uniform_models "$plugin" "$ABTEST_MODEL" || { echo "arm-b.sh: could not enforce the uniform model policy in the plugin copy" >&2; exit 3; }; fi`.
   Because the scaffold runs from this copy, the worktree's `.claude/agents/*.md` and settings inherit the
   strip and the hook.
3. In `tests/abtest-arms.test.sh`, add these checks on a fresh `abtest_plugin_copy "$REPO_ROOT" "$T/ucopy"`:
   - (a) `abtest_uniform_models "$T/ucopy" fable` returns 0, and no `agents/*.md` frontmatter in the copy
     contains `^model:`;
   - (b) piping `{"hook_event_name":"PreToolUse","tool_name":"Agent","tool_input":{"subagent_type":"reviewer","model":"opus","prompt":"p"}}`
     to the copy's hook gives output where `jq -c .hookSpecificOutput.updatedInput` equals
     `{"subagent_type":"reviewer","model":"fable","prompt":"p"}`;
   - (c) a `{"tool_name":"Bash","tool_input":{"command":"ls"}}` payload gives empty output and exit 0;
   - (d) the copy's `hooks.json` names `abtest-uniform-model.sh` exactly once;
   - (e) a second `abtest_uniform_models` on the same copy returns non-zero;
   - (f) the call in `arm-b.sh` sits inside an `if [ "$policy" = uniform ]` line (one grep for the exact
     line from edit 2);
   - (g) `grep -c '^model:' "$REPO_ROOT/agents/reviewer.md"` is 1, so the product is untouched;
   - (h) a bad model name such as `'a b'` makes the function fail.
4. Append OD-23 to `operator-decisions.md`, verbatim from the spec under "OD-23 text".
5. Insert the experiment-doc amendment, verbatim from the spec under "Experiment-doc amendment (verbatim
   draft, appended after the OD-22 paragraph)".
6. Commit with the subject `feat(aof-u6): enforce the uniform model policy in Arm B's plugin copy (OD-23)`.

## Do NOT touch
- Every product file (`agents/`, `hooks/`, `bin/`, `templates/`): the strip and the hook exist only in the
  temporary plugin copy.
- `abtest_relax_bash_gates` (OD-20), the deny rules and lock (OD-16, OD-21), `arm-a.sh`, and the
  `shipped` branch of `arm-b.sh`.
- `lib/stream.py` (aof-u5), the scorer, checks, allowed paths and prompts.
- `CLAUDE_CODE_SUBAGENT_MODEL` handling in arm-b.sh: keep the export as it is.

## Acceptance criteria
- AC6.1 run: `bash tests/abtest-arms.test.sh` (exit 0). mutation: dropping the frontmatter strip fails (a);
  dropping the `model` override in the hook fails (b); calling the function outside the `uniform` branch
  fails (f).
- AC6.2 run: `grep -q '^- OD-23 (2026-10-19' docs/plans/antislop-vs-fable-evals/operator-decisions.md && grep -q '^Amendment 2026-10-19 (OD-23' docs/experiments/abtest-2026-10.md && grep -n '^- OD-2[23] ' docs/plans/antislop-vs-fable-evals/operator-decisions.md | head -1 | grep -q 'OD-22'`
  (OD-23 follows OD-22).
- AC6.3 run: `bash tests/validate.sh` (exit 0).

## Pre-resolved context
- Evidence from pilot 4: every B row labelled `uniform` has haiku, sonnet and opus in `model_usage`. The
  orchestrator dispatched `model: sonnet` (lead-programmer), `model: opus` (reviewer, spec-master), and
  `model: sonnet` (2 E5 reviews). Explorer dispatches carried no model and ran on frontmatter `haiku`.
  `arm-b.sh:80-84` exports `CLAUDE_CODE_SUBAGENT_MODEL="$ABTEST_MODEL"` (default `fable`, common.sh:8),
  and it did not win.
- `abtest_plugin_copy` (common.sh:137-144) builds the copy from `git archive HEAD` and then applies
  `abtest_relax_bash_gates`, so the new function runs after both. The scaffold
  (`node "$plugin/bin/cli.js" --personas=...`, arm-b.sh:41) builds the worktree's agents and settings from
  the copy (OD-20(a) notes the same for hooks).
- No product gate reads a dispatch's `model` to block it: only `agent-audit.sh` reads it, for audit
  (grep-verified). `reviewer-route-gate.sh` and `dispatch-hygiene.sh` key off `subagent_type` and the prompt.
- Whether the CLI applies `updatedInput` on `Agent` cannot be shown by a unit test. Re-pilot S8 is the live
  check (spec R9).

## Escalation
If `jq` is not available to the hook in the worktree, report it; do not rewrite the hook in another language
without saying so. If `tests/abtest-arms.test.sh` cannot build a copy because HEAD lacks a file, report it.
If a gate blocks an edit, report it and wait. Anything outside "Affected files" goes to the report as a
proposal.
