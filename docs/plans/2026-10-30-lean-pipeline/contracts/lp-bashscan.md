Unit: lp-bashscan

## Objective
Drop Bash command-text scanning from `reviewed-path-gate.sh` and `harness-integrity-gate.sh` (plan change 4, decisions D5 and D6, step "U9 lp-bashscan", Risk R1). Both gates keep their `hooks/hooks.json` Bash registrations, which `tests/abtest-arms.test.sh` pins; in that file only the two `(the control)` rows change (G3). Each gate's Bash branch allows everything: when `.tool_input.command` is non-empty it exits 0 with empty stdout and runs nothing else. The Write/Edit branches, the PostToolUse bookkeeping, the reviewer grant, the no-reviewer fallback and the Set A/Set B ask/deny rules stay byte-for-byte in behaviour. `lib/benign-command.sh` goes. Its `normalize_path` is still needed by both Write/Edit branches, so it moves to a new `lib/normalize-path.sh`. No version bump.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-30-lean-pipeline.md`, step "U9 lp-bashscan", D5, D6, R1, R4, Context (marker-sweep note hcb-branch). This file is the contract of record and supersedes the plan's U9 file list where they differ. Dispatch after lp-joinstamp has PASSed and the user has answered G2 below. Implementer tier: opus.

## Affected files
- `hooks/scripts/harness-integrity-gate.sh` (Set B: see G2), `hooks/scripts/reviewed-path-gate.sh`, new `hooks/scripts/lib/normalize-path.sh` (mode 644, `normalize_path` moved verbatim with its comment); `git rm` these: `hooks/scripts/lib/benign-command.sh` and `tests/benign-command-families.test.sh`
- `bin/cli.js` (line 686, `CLAUDE_ONLY_HOOK_LIB_FILES`: `benign-command.sh` → `normalize-path.sh`); `tests/cli-hook-propagation.test.js` (lines 93, 122 and 126; use another lib file as the sample)
- `tests/reviewed-path-gate.test.sh`, `tests/harness-integrity-gate.test.sh`: delete or convert only the cases and sections about the Bash scan (allowlist, obfuscation, family table, brace-collapse property, memory-note parity, hot-path line pins, the Bash-side mutation controls, gh418, U7c). Name each removed section in the CHANGELOG bullet. `tests/validate.sh` (delete the benign-command block :1607-1612), `tests/watch-map.json` (line 23)
- Prose that turns false once Bash is never refused: `templates/persona-protocol.md` (the rephrasing-doctrine bullet near :94 and any surviving `only lets a non-reviewer caller` text), `agents/reviewer.md` (line 169), `agents/orchestrator.md` (line 340), `agents/spec-master.md` (line 211), `skills/install-antislop/SKILL.md` (:41, :58, :100, :154, :213, :315), `skills/install-antislop/hook-verification.md` (line 14), `skills/pathfinder/SKILL.md` (line 48, if the file still exists), `adapters/codex/agents-md-fragment.md`, `adapters/cursor/rules/persona-protocol.mdc`. Keep the advice to use `Read`, but drop the claim that Bash is refused.
- G3, Bash-denial cases outside the gate suites: `tests/abtest-arms.test.sh` (only the two rows `the shipped hooks deny the pilot-2 persona-config|pass-marker command (the control)`: delete them, or make them expect `allow` with a `the shipped hooks (now) let ... pilot-2 ...` label); `tests/refusal-disclosure.test.sh` (the `reviewed-path-gate.sh` lead-programmer case near :73: send a Write payload whose `file_path` is `$marker/9.pass`, keep its message asserts); `tests/agent-identity-namespace.test.sh` (`marker_payload` near :79 becomes a Write payload, `file_path` `.claude/reviewed/9.pass`; S1 and S2 keep their rc expectations); `tests/marker-write.test.sh` (delete the lead-programmer helper-invocation block near :188-193; keep the reviewer loop)
- `CHANGELOG.md`: one `[Unreleased]` bullet, which states the R1 loss in one sentence and names every removed or converted test section, the G3 ones included

## Ordered edits
1. Create `lib/normalize-path.sh` and commit it. Then write the new `harness-integrity-gate.sh`: source `normalize-path.sh` instead of `benign-command.sh`; after the PostToolUse block, replace everything from the Bash-branch comment to the end with `exit 0`, reached when `$command` is non-empty; delete `set_a_mentioned` and `is_benign_jq_read`. Rewrite the header: Set A and Set B are both Write/Edit-only, Set B has 4 literals (hcb-branch note), and the Bash registration is kept for A/B parity (D5). Apply it per G2. Do not write this path yourself.
2. `reviewed-path-gate.sh`: when `$command` is non-empty, `exit 0` immediately after the config check. Delete `mentions_marker_dir`, `mask_comments_only`, `write_with_commented_mention` and the Bash-only checks and messages. Rewrite the header (Write/Edit only; Bash registration kept per D5). The Write/Edit path stays as it is.
3. Tests. Add these exact labels, each through the file's own helper. In `reviewed-path-gate.test.sh`: `lean-pipeline R1 bash marker write allowed` (lead-programmer, `printf x > .claude/reviewed/a.pass` → allowed) and `lean-pipeline R1 write marker blocked` (Write, lead-programmer → blocked). In `harness-integrity-gate.test.sh`: `lean-pipeline R1 bash persona-config write allowed` (Bash `echo x > .claude/persona-config.json` → exit 0, empty stdout) and `lean-pipeline R1 write persona-config denied` (Write with `agent_id` set → exit 2). Then delete the Bash-scan cases.
4. Prose, the cli.js list, validate.sh and watch-map. Then run `node bin/cli.js --update --force-render` and `git add -- .claude adapters`.

## Do NOT touch
- `hooks/hooks.json`, `.claude/settings.json`, `eval/`
- `tests/abtest-arms.test.sh` outside the two G3 control rows (its `hooks.json` registration pins stay as they are)
- `hooks/scripts/human-decision-gate.sh` (lp-hdg's stub), `hooks/scripts/protected-paths.sh`, stop-gate files, `hooks/scripts/reviewer-route-gate.sh`, `hooks/scripts/lib/reviewer-route-gate-core.sh`
- `docs/` (U12; the glossary's `reviewed-path denial` entry is a scribe item), `.claude/agent-memory/`
- Never run a mutation by editing `hooks/scripts/harness-integrity-gate.sh` in place: use a copy and `GATE_UNDER_TEST`

## Acceptance criteria
1. run: `{ bash tests/reviewed-path-gate.test.sh && bash tests/harness-integrity-gate.test.sh; } >/dev/null && grep -c 'lean-pipeline R1' tests/reviewed-path-gate.test.sh tests/harness-integrity-gate.test.sh`
   exit: 0
   stdout: `tests/reviewed-path-gate.test.sh:2` then `tests/harness-integrity-gate.test.sh:2`
   mutation: copy a gate and `lib/` into `d=$(mktemp -d)`, then make the copy's Write/Edit branch `exit 0` before its case statement. `GATE_UNDER_TEST=$d/<gate> bash tests/<gate test>` → exit 1, and the `write ... blocked|denied` label fails.
2. run: `git grep -nE 'mentions_marker_dir|set_a_mentioned|is_benign_jq_read|command_is_provably_benign|benign-command' -- hooks bin adapters | wc -l; test ! -e hooks/scripts/lib/benign-command.sh && test -f hooks/scripts/lib/normalize-path.sh && echo ok`
   exit: 0
   stdout: `0` then `ok`
3. run: `git grep -nE 'can be refused by .harness-integrity-gate|is refused by .harness-integrity-gate|harness-integrity-gate.sh. refuses|only lets a non-reviewer caller|refuses a heredoc|lone read-only .jq|a lone .jq. read is allowed' -- agents templates commands skills adapters README.md | wc -l`
   exit: 0
   stdout: `0`
   mutation: restore `agents/spec-master.md` → ≥ 1.
4. run: `{ bash tests/abtest-arms.test.sh && node tests/cli-hook-propagation.test.js; } >/dev/null && git diff --quiet 7717b64a -- hooks/hooks.json && git diff -U0 7717b64a -- tests/abtest-arms.test.sh | grep -E '^[-+][^-+]' | grep -vE '^-check "the shipped hooks deny the pilot-2 (persona-config|pass-marker) command \(the control\)"|^\+check "the shipped hooks (now )?(let|allow)[^"]*pilot-2[^"]*" "\$\(verdict "\$REPO_ROOT" Bash "\$\(bash_payload "\$CMD_STALL[12]"\)"\)" "allow"$' | wc -l`
   exit: 0
   stdout: `0`
   mutation: edit any other `abtest-arms` line (a `hooks.json` pin or a pruned-copy row) → stdout ≥ 1.
   when: after the final commit.
5. run: `{ bash tests/escalation-retired.test.sh prose && bash tests/escalation-retired.test.sh code-hdg && bash tests/escalation-retired.test.sh code-bin; } >/dev/null`
   exit: 0
   stdout: empty
6. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters` (C-mirror)
   exit: 0
   stdout: empty
7. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; C-full, run once by the reviewer after the final commit)
   exit: 0
   stdout: empty
8. run: `{ bash tests/refusal-disclosure.test.sh && bash tests/marker-write.test.sh && bash tests/agent-identity-namespace.test.sh; } >/dev/null 2>&1; echo $?`
   exit: 0
   stdout: `0`
   mutation: restore the Bash form of `marker_payload` in `tests/agent-identity-namespace.test.sh` → stdout `1`.

## Pre-resolved context
- Today (2026-10-30, 7717b64a): the label grep gives 0 in both files; criterion 2 counts 28; criterion 3 counts 15 in 9 files; both gate suites, `abtest-arms` and `cli-hook-propagation` pass.
- Both test files already honour `GATE_UNDER_TEST`, which must be an absolute path. The gates source `lib/` relative to their own directory.
- G3 (amendment, aa1ce356): `validate.sh` FAILs only in `abtest-arms` (2 control rows), `refusal-disclosure`, `marker-write` and `agent-identity-namespace`. Their G3 edits, tried on scratch copies, pass: the Write branch keeps every expected rc=2, the denial text and the drift line. Criteria 4, 7 and 8 can then pass.
- G2 (resolved: cb021a4b). Plan R4 expects an approval prompt, but `ask_allowed` never asks inside a subagent (`agent_id` is set there), so a writer's Write/Edit to the gate is denied outright. The orchestrator has no Write tool. Recommended default: the writer puts the full new gate text at `docs/plans/2026-10-30-lean-pipeline/staged/harness-integrity-gate.sh`, commits it, and ends with `STATUS: incomplete — G2: apply staged gate`. The user copies the file over the gate at their own terminal and commits. The orchestrator then resumes the writer for edits 2-4. The writer `git rm`s the staged file in its final commit.

## Escalation
On any `harness-integrity-gate.sh` block, or any other gate block, stop and report the path and the refusal text. Never reword the command, split it, use a scratch worktree, or use Bash to write a path the gate denies on Write/Edit. If a test outside the affected files fails because `benign-command.sh` is gone, stop and report its path and line.
