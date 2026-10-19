Unit: abt-u13h

## Objective
`abtest_plugin_copy` in `eval/abtest/arms/common.sh` calls a new `abtest_relax_bash_gates`, so the pruned plugin copy that Arm B loads no longer registers `harness-integrity-gate.sh` and `reviewed-path-gate.sh` for the Bash matcher (every other hook, both Write|Edit registrations and every script stay as shipped, and nothing under `hooks/` changes); `tests/abtest-arms.test.sh` pins that and proves read-only reads of the persona config and a PASS marker pass the copy's Bash hooks (81 rows become 99); operator-decisions.md holds OD-20, the pre-registration and the README carry the dated amendment, and the 10 rows of the second pilot are stated superseded under OD-14. `eval/abtest/lib/stream.py` is untouched.

## Retrieval
GitHub issues: `gh issue view 625 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/arms/common.sh` (anchor: line matching `  [ -f "$dest/.claude-plugin/plugin.json" ] && [ -f "$dest/hooks/hooks.json" ] && [ -f "$dest/bin/cli.js" ] || return 1`)
- `tests/abtest-arms.test.sh` (anchor: line matching `abtest_plugin_copy "$T" "$T/pcopy2" 2> /dev/null; check "abtest_plugin_copy fails on a directory that is not a git checkout" "$?" "1"`)
- `docs/plans/antislop-vs-fable-evals/operator-decisions.md` (anchor: line matching `  (for example a different permission mode); this decision does not make it.`)
- `docs/experiments/abtest-2026-10.md` (anchor: line matching `and will be repeated. Stall detection is unchanged: a real ask or denial is still `stalled-human`.`)
- `eval/abtest/README.md` (anchor: line matching `token is the check, it must be re-run after OD-19, and a `FOUND` blocks everything.`)

## Ordered edits
1. command: `test -f eval/abtest/arms/common.sh && /usr/bin/grep -qF -e 'abtest_plugin_copy() {' eval/abtest/arms/common.sh && ! /usr/bin/grep -qF -e 'abtest_relax_bash_gates' eval/abtest/arms/common.sh && test -f tests/abtest-arms.test.sh && ! /usr/bin/grep -qF -e 'OD-20' docs/plans/antislop-vs-fable-evals/operator-decisions.md`
   expect: 0

2. file: `eval/abtest/arms/common.sh`
   anchor: line matching `  [ -f "$dest/.claude-plugin/plugin.json" ] && [ -f "$dest/hooks/hooks.json" ] && [ -f "$dest/bin/cli.js" ] || return 1`
   indent: 0
   before:
~~~~
  [ -f "$dest/.claude-plugin/plugin.json" ] && [ -f "$dest/hooks/hooks.json" ] && [ -f "$dest/bin/cli.js" ] || return 1
}
~~~~
   after:
~~~~
  [ -f "$dest/.claude-plugin/plugin.json" ] && [ -f "$dest/hooks/hooks.json" ] && [ -f "$dest/bin/cli.js" ] || return 1
  abtest_relax_bash_gates "$dest" || return 1
}

# abtest_relax_bash_gates DEST: OD-20. In the plugin copy only, hooks.json stops registering harness-integrity-gate.sh
# and reviewed-path-gate.sh for the Bash matcher: both denied read-only commands (a cat of the persona config, a head of
# a PASS marker) and any denial scores a row stalled-human. Their Write and Edit registrations, every other hook and
# every script stay as shipped, and the product tree is never edited. Fails unless exactly those two entries go.
abtest_relax_bash_gates() {
  python3 -I - "$1/hooks/hooks.json" <<'PYEOF'
import json, sys

path = sys.argv[1]
drop = ("harness-integrity-gate.sh", "reviewed-path-gate.sh")
with open(path) as f:
    cfg = json.load(f)
removed = 0
for entry in cfg["hooks"]["PreToolUse"]:
    if entry.get("matcher") != "Bash":
        continue
    keep = [h for h in entry["hooks"] if not h["command"].endswith(drop)]
    removed += len(entry["hooks"]) - len(keep)
    entry["hooks"] = keep
if removed != 2:
    sys.exit("abtest: expected to drop 2 Bash hook entries, dropped %d" % removed)
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PYEOF
}
~~~~

3. file: `tests/abtest-arms.test.sh`
   anchor: line matching `check "the scaffold from the pruned copy equals the scaffold from the full checkout" "$(diff -rq -x 'persona-config.json' "$T/refscaf/.claude" "$T/wb/.claude" > /dev/null && echo same || echo differ)" "same"`
   indent: 0
   before:
~~~~
check "the scaffold from the pruned copy equals the scaffold from the full checkout" "$(diff -rq -x 'persona-config.json' "$T/refscaf/.claude" "$T/wb/.claude" > /dev/null && echo same || echo differ)" "same"
~~~~
   after:
~~~~
check "the scaffold from the pruned copy equals the scaffold from the full checkout, settings.json aside" "$(diff -rq -x 'persona-config.json' -x 'settings.json' "$T/refscaf/.claude" "$T/wb/.claude" > /dev/null && echo same || echo differ)" "same"
check "the scaffolded settings.json of the pruned copy only lacks the two Bash gate registrations (OD-20)" "$(diff "$T/refscaf/.claude/settings.json" "$T/wb/.claude/settings.json" | grep -c '^>')|$(diff "$T/refscaf/.claude/settings.json" "$T/wb/.claude/settings.json" | grep '^<' | grep -c -e reviewed-path-gate.sh -e harness-integrity-gate.sh)" "0|2"
~~~~

4. file: `tests/abtest-arms.test.sh`
   anchor: line matching `abtest_plugin_copy "$T" "$T/pcopy2" 2> /dev/null; check "abtest_plugin_copy fails on a directory that is not a git checkout" "$?" "1"`
   indent: 0
   insert-after:
~~~~
# --- OD-20 (abt-u13h): the pruned copy no longer registers the two gates that denied read-only Bash commands ---
OP="$T/od20proj"
mkdir -p "$OP/.claude/reviewed"
printf '{"gatedAgents":["lead-programmer"],"personaSelection":["reviewer"]}\n' > "$OP/.claude/persona-config.json"
printf 'PASS x\n' > "$OP/.claude/reviewed/x.pass"
hooks_of() {
  python3 -I -c 'import json, sys
for e in json.load(open(sys.argv[1] + "/hooks/hooks.json"))["hooks"]["PreToolUse"]:
    if e.get("matcher") == sys.argv[2]:
        for h in e["hooks"]:
            print(h["command"].replace("${CLAUDE_PLUGIN_ROOT}", sys.argv[1]))' "$1" "$2"
}
names_of() { hooks_of "$1" "$2" | sed 's#.*/##' | sort | tr '\n' ' '; }
verdict() {
  local root="$1" matcher="$2" payload="$3" h rc=0
  while IFS= read -r h; do
    printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$OP" CLAUDE_PLUGIN_ROOT="$root" bash "$h" > /dev/null 2>&1 || rc=1
  done < <(hooks_of "$root" "$matcher")
  [ "$rc" -eq 0 ] && echo allow || echo deny
}
bash_payload() { jq -n --arg c "$1" --arg d "$OP" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d, hook_event_name: "PreToolUse"}'; }
CMD_CFG="cat .claude/persona-config.json"
CMD_PASS="head -1 .claude/reviewed/x.pass"
CMD_STALL1="git status --short | head -20 && git log --oneline | head -5 && find . -path ./node_modules -prune -o -type f -print | head -50 && ls .claude/agents 2>/dev/null; cat .claude/persona-config.json 2>/dev/null | head -30"
CMD_STALL2="head -1 .claude/reviewed/x.pass; ls .claude/.pending-review.* 2>&1; git status --short"
check "the shipped hooks.json registers three hooks for the Bash matcher" "$(names_of "$REPO_ROOT" Bash)" "harness-integrity-gate.sh human-decision-gate.sh reviewed-path-gate.sh "
check "the pruned copy registers only human-decision-gate.sh for the Bash matcher" "$(names_of "$T/pcopy" Bash)" "human-decision-gate.sh "
check "the pruned copy keeps both gates on the Write|Edit matcher" "$(names_of "$T/pcopy" 'Write|Edit' | grep -o -e harness-integrity-gate.sh -e reviewed-path-gate.sh | sort | tr '\n' ' ')" "harness-integrity-gate.sh reviewed-path-gate.sh "
check "the pruned copy drops exactly two registrations and no other" "$(( $(grep -c 'CLAUDE_PLUGIN_ROOT' "$REPO_ROOT/hooks/hooks.json") - $(grep -c 'CLAUDE_PLUGIN_ROOT' "$T/pcopy/hooks/hooks.json") ))" "2"
check "the pruned copy keeps the PostToolUse registration of harness-integrity-gate.sh" "$(grep -c 'harness-integrity-gate.sh' "$T/pcopy/hooks/hooks.json")" "2"
check "every hook script of the pruned copy is byte-identical to the product tree" "$(diff -r "$T/pcopy/hooks/scripts" "$REPO_ROOT/hooks/scripts" > /dev/null && echo same || echo differ)" "same"
check "the product tree hooks are unchanged since HEAD" "$(git -C "$REPO_ROOT" diff --quiet HEAD -- hooks && echo clean || echo changed)" "clean"
check "arm B builds its plugin copy with abtest_plugin_copy, which applies the relaxation" "$(grep -cF 'abtest_plugin_copy "$plugin" "$copydir/plugin"' "$ARMS/arm-b.sh")" "1"
check "the pruned copy lets cat of the persona config through" "$(verdict "$T/pcopy" Bash "$(bash_payload "$CMD_CFG")")" "allow"
check "the pruned copy lets head of a PASS marker through" "$(verdict "$T/pcopy" Bash "$(bash_payload "$CMD_PASS")")" "allow"
check "the shipped hooks let the same two reads through" "$(verdict "$REPO_ROOT" Bash "$(bash_payload "$CMD_CFG")")|$(verdict "$REPO_ROOT" Bash "$(bash_payload "$CMD_PASS")")" "allow|allow"
check "the shipped hooks deny the pilot-2 persona-config command (the control)" "$(verdict "$REPO_ROOT" Bash "$(bash_payload "$CMD_STALL1")")" "deny"
check "the pruned copy lets the pilot-2 persona-config command through" "$(verdict "$T/pcopy" Bash "$(bash_payload "$CMD_STALL1")")" "allow"
check "the shipped hooks deny the pilot-2 pass-marker command (the control)" "$(verdict "$REPO_ROOT" Bash "$(bash_payload "$CMD_STALL2")")" "deny"
check "the pruned copy lets the pilot-2 pass-marker command through" "$(verdict "$T/pcopy" Bash "$(bash_payload "$CMD_STALL2")")" "allow"
WPAY="$(jq -n --arg f "$OP/.claude/reviewed/y.pass" --arg d "$OP" '{tool_name: "Write", tool_input: {file_path: $f, content: "PASS y"}, cwd: $d, hook_event_name: "PreToolUse"}')"
check "the pruned copy still denies a Write into the marker directory" "$(verdict "$T/pcopy" 'Write|Edit' "$WPAY")" "deny"
abtest_relax_bash_gates "$T/pcopy" 2> /dev/null; check "a second relaxation of the same copy fails (nothing left to drop)" "$?" "1"
~~~~

5. file: `docs/plans/antislop-vs-fable-evals/operator-decisions.md`
   anchor: line matching `  (for example a different permission mode); this decision does not make it.`
   indent: 0
   insert-after:
~~~~
- OD-20 (2026-10-19, two Bash gates relaxed in the Arm B plugin copy; binding operator decision from the second pilot)
  Evidence (eval/abtest/results.superseded.jsonl and eval/abtest/results.jsonl, run
  eval/abtest/.runs/e03-rename-query_B_uniform_1/): 4 of 10 rows stalled in pilot 1 and 1 of 10 in pilot 2. The pilot 2
  row is E3 B (`human_interventions_required` 3, `permission_denials` 3). Two of its three denials are hook denials
  (exit 2) of read-only Bash commands, and lib/stream.py counts any denial as `stalled-human` (OD-3, OD-13).
  (1) hooks/scripts/harness-integrity-gate.sh blocked `git status --short | head -20 && ... && ls .claude/agents
  2>/dev/null; cat .claude/persona-config.json 2>/dev/null | head -30` (the Bash text names the audit and config
  surface of Set A). (2) hooks/scripts/reviewed-path-gate.sh blocked `head -1 .claude/reviewed/<id>.pass; ls
  .claude/.pending-review.* 2>&1; git status --short` (the Bash text names the marker directory). Both commands only
  read, so both denials are false positives, and left as they are the stalls would measure the two gates, not the arms.
  (a) The rule. In the plugin copy that arm-b.sh loads (abtest_plugin_copy in eval/abtest/arms/common.sh, through
  abtest_relax_bash_gates), hooks/hooks.json stops registering harness-integrity-gate.sh and reviewed-path-gate.sh for
  the Bash matcher; the function fails the copy unless exactly those two entries go. The scaffold builds the worktree's
  settings.json from that hooks.json, so the two gates are absent there for Bash too.
  (b) Unchanged. hooks/scripts/ in the product tree and in the copy (byte-identical), the shipped plugin, the Write
  and Edit registrations of both gates, the PostToolUse registration of harness-integrity-gate.sh, every other hook
  (human-decision-gate.sh stays on the Bash matcher), Arm A (it loads no plugin) and lib/stream.py.
  (c) Cost. In Arm B a Bash command that writes the audit and config surface or the review marker directory is no
  longer stopped by these two gates (a Write or Edit still is). The relaxation is for the eval run only and the report
  must say that Arm B ran with the two gates relaxed (pre-registration amendment 2026-10-19).
  (d) Not covered. The same row holds a third denial, a `permission_denied` record (`subcommandResults`) for
  `sed -n '1,/^---$/p' .claude/agents/lead-programmer.md`. It comes from the permission rules, not from a hook, and
  this decision does not touch it. If the pilot still stalls on it, that is a new operator decision.
  (e) Whether the stalls stop is confirmed only by re-running. After this lands, the operator re-runs, in order,
  `run-matrix.sh --probe-isolation`, `run-matrix.sh --probe-canary` and `run-matrix.sh --pilot`. The 10 rows of the
  second pilot were made by the previous harness; the change moves `harness_commit`, so the 10 rows of the second
  pilot are superseded under OD-14 by this harness change and the pilot repeats them.
~~~~

6. file: `docs/experiments/abtest-2026-10.md`
   anchor: line matching `and will be repeated. Stall detection is unchanged: a real ask or denial is still `stalled-human`.`
   indent: 0
   insert-after:
~~~~
Amendment 2026-10-19 (OD-20, before the first full run): Arm B runs with two gates relaxed. In the plugin copy Arm B
loads, `hooks/hooks.json` no longer registers `harness-integrity-gate.sh` and `reviewed-path-gate.sh` for the Bash
matcher, because both denied read-only Bash commands (a compound command that read `.claude/persona-config.json`, a
`head` of a PASS marker) and any denial scores a row `stalled-human`; the first pilot stalled 4 of 10 rows and the
second pilot 1 of 10 (E3 B). Their Write and Edit registrations, every other hook and every script are unchanged, Arm A
loads no plugin and the product tree is not edited. Arm B therefore measures AntiSlop with these two Bash checks off:
a Bash write to the audit and config surface or to the marker directory is no longer stopped by them. A third denial
in that row (a permission rule on a `sed` of an agent file) is not covered. The 10 rows of the second pilot are
superseded by this harness change (OD-14) and will be repeated. Stall detection is unchanged.
~~~~

7. file: `eval/abtest/README.md`
   anchor: line matching `token is the check, it must be re-run after OD-19, and a `FOUND` blocks everything.`
   indent: 0
   insert-after:
~~~~
Since OD-20 Arm B runs with two gates relaxed: the plugin copy that `arm-b.sh` loads (`abtest_plugin_copy`, which
calls `abtest_relax_bash_gates`) does not register `harness-integrity-gate.sh` and `reviewed-path-gate.sh` for the Bash
matcher, because both denied read-only commands and any denial scores a row `stalled-human`. Their Write and Edit
registrations, every other hook, the scripts and the product tree are as shipped. The rows of the second pilot are
superseded under OD-14, so after this change run steps 1, 2 and 4 again. A third denial in the E3 B row (a permission
rule on a `sed` of an agent file) is not covered; if the pilot still stalls on it, report it.
~~~~

8. command: `git commit -m "fix(abt-u13h): Arm B plugin copy stops registering two Bash gates that denied read-only commands (OD-20) (#625)" -- eval/abtest/arms/common.sh tests/abtest-arms.test.sh docs/plans/antislop-vs-fable-evals/operator-decisions.md docs/experiments/abtest-2026-10.md eval/abtest/README.md`
   expect: 0
   trailers: before running it, add one more `-m` argument for the Co-Authored-By trailer and one for the Claude-Session trailer, both taken from the session attribution; the paths after `--` stay explicit and no `git add` runs.

## Do NOT touch
- `hooks/` (hooks.json and every script stay as shipped; the relaxation lives only in the plugin copy the arm builds, never in the product tree)
- `eval/abtest/lib/stream.py` (the stalled-human rule: any AskUserQuestion, permission denial or escalation marker; spec 4.1, OD-3, OD-13 bind it and OD-20 keeps it)
- `eval/abtest/arms/arm-a.sh`, `eval/abtest/arms/arm-b.sh` (arm-b.sh already calls abtest_plugin_copy; Arm A loads no plugin)
- `eval/abtest/run-matrix.sh`, `tests/abtest-probe.test.sh`, `tests/abtest-stream.test.sh`, `tests/fixtures/abtest/`, `tests/validate.sh` (the fake claude and the probes are unchanged)
- `eval/abtest/results.jsonl`, `eval/abtest/results.superseded.jsonl`, `eval/abtest/.runs/` (run output; the pilot is repeated by the operator, not edited)
- `bin/cli.js`, `docs/plans/antislop-vs-fable-evals.md`, `docs/harness-glossary.md`, `CHANGELOG.md` (the design stays as written; a scribe owns the CHANGELOG entry and any glossary close-out)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json` (no persona change, no version bump)

## Acceptance criteria
1. run: `set -o pipefail; bash tests/abtest-arms.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-arms checks passed.`
   mutation: skip edit 2; exit 7, stdout `abtest-arms: 92 passed, 7 failed`.
2. run: `bash tests/abtest-arms.test.sh | /usr/bin/grep -c '^ok'`
   exit: 0
   stdout: `99`
   mutation: skip edit 4; exit 0, stdout `82`.
3. run: `bash tests/abtest-arms.test.sh | /usr/bin/grep -c '^FAIL'`
   exit: 1
   stdout: `0`
   mutation: skip edit 2; exit 0, stdout `7`.
4. run: `/usr/bin/grep -cF 'abtest_relax_bash_gates "$dest" || return 1' eval/abtest/arms/common.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; exit 1, stdout `0`.
5. run: `/usr/bin/grep -c 'CLAUDE_PLUGIN_ROOT' hooks/hooks.json`
   exit: 0
   stdout: `17`
   mutation: delete one `reviewed-path-gate.sh` registration line from hooks/hooks.json; exit 0, stdout `16`.
   proof: scratch worktree at HEAD, `sed -i '0,/reviewed-path-gate.sh/{/reviewed-path-gate.sh/d}' hooks/hooks.json`, then the run: command there
6. run: `/usr/bin/grep -c '^- OD-20 (2026-10-19, two Bash gates relaxed in the Arm B plugin copy' docs/plans/antislop-vs-fable-evals/operator-decisions.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; exit 1, stdout `0`.
7. run: `tr '\n' ' ' < docs/plans/antislop-vs-fable-evals/operator-decisions.md | tr -s ' ' | /usr/bin/grep -cF '4 of 10 rows stalled in pilot 1 and 1 of 10 in pilot 2'`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; exit 1, stdout `0`.
8. run: `tr '\n' ' ' < docs/plans/antislop-vs-fable-evals/operator-decisions.md | tr -s ' ' | /usr/bin/grep -cF 'the 10 rows of the second pilot are superseded under OD-14 by this harness change'`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; exit 1, stdout `0`.
9. run: `/usr/bin/grep -c '^Amendment 2026-10-19 (OD-20, before the first full run): Arm B runs with two gates relaxed' docs/experiments/abtest-2026-10.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; exit 1, stdout `0`.
10. run: `tr '\n' ' ' < docs/experiments/abtest-2026-10.md | tr -s ' ' | /usr/bin/grep -cF 'the first pilot stalled 4 of 10 rows and the second pilot 1 of 10 (E3 B)'`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; exit 1, stdout `0`.
11. run: `tr '\n' ' ' < docs/experiments/abtest-2026-10.md | tr -s ' ' | /usr/bin/grep -cF 'The 10 rows of the second pilot are superseded by this harness change (OD-14) and will be repeated'`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; exit 1, stdout `0`.
12. run: `tr '\n' ' ' < eval/abtest/README.md | tr -s ' ' | /usr/bin/grep -cF 'Since OD-20 Arm B runs with two gates relaxed'`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; exit 1, stdout `0`.
13. run: `tr '\n' ' ' < eval/abtest/README.md | tr -s ' ' | /usr/bin/grep -cF 'The rows of the second pilot are superseded under OD-14, so after this change run steps 1, 2 and 4 again'`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; exit 1, stdout `0`.
14. run: `set -o pipefail; bash tests/abtest-stream.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-stream checks passed.`
   mutation: delete `denials > 0 or ` from eval/abtest/lib/stream.py; exit 1, stdout `abtest-stream: 241 passed, 1 failed`.
   proof: scratch worktree at HEAD, `sed -i 's/denials > 0 or //' eval/abtest/lib/stream.py`, run `bash tests/abtest-stream.test.sh` there: exit 1, `abtest-stream: 241 passed, 1 failed`
15. run: `/usr/bin/grep -cF 'T="$(mktemp -d)" && [ -d "${T:-}" ]' tests/abtest-arms.test.sh`
   exit: 0
   stdout: `1`
   mutation: replace the guarded mktemp line with `T=$(mktemp -d)`; exit 1, stdout `0`.
   proof: scratch worktree with edits 2-7 applied, replace the guarded mktemp line in tests/abtest-arms.test.sh with `T=$(mktemp -d)`, rerun the run: command there
16. run: `/usr/bin/grep -cE '^[^#"]*(^|[ ;|&(])claude( |$)' tests/abtest-arms.test.sh`
   exit: 1
   stdout: `0`
   mutation: append the line `claude -p hi` to tests/abtest-arms.test.sh; exit 0, stdout `1`.
   proof: scratch worktree with edits 2-7 applied, append `claude -p hi` to tests/abtest-arms.test.sh, rerun the run: command there
17. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13h\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `docs/experiments/abtest-2026-10.md docs/plans/antislop-vs-fable-evals/operator-decisions.md eval/abtest/README.md eval/abtest/arms/common.sh tests/abtest-arms.test.sh`
   mutation: skip edit 8 (the commit); exit 3, stdout `no-unit-commit`.
18. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13h\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 8 (the commit); exit 3, stdout `no-unit-commit`.
19. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13h\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/arms/common.sh tests/abtest-arms.test.sh docs/plans/antislop-vs-fable-evals/operator-decisions.md docs/experiments/abtest-2026-10.md eval/abtest/README.md | grep -vcE "^[a-z]+\(abt-u13h\): "`
   exit: 1
   stdout: `0`
   mutation: skip edit 8 (the commit); a later commit `docs: tail` touching eval/abtest/README.md without the unit scope prints 1; exit 3, stdout `no-unit-commit`.

## Pre-resolved context
tdd: yes tests/abtest-arms.test.sh (criterion 2 is the red count: 81 rows at HEAD become 99; criteria 4 and 6 to 13 fail at HEAD)
blast-radius: eval/abtest/arms/common.sh:79 eval/abtest/arms/common.sh:84 eval/abtest/arms/arm-b.sh:34 tests/abtest-arms.test.sh:110 tests/abtest-arms.test.sh:113 tests/abtest-arms.test.sh:114 hooks/hooks.json:32 bin/cli.js:2049 eval/abtest/lib/stream.py:152 (grep-derived; abtest_plugin_copy is called only from arm-b.sh and the arms test; bin/cli.js readStandaloneHooksConfig builds the scaffolded settings.json from the hooks.json it finds, so the copy's scaffold lacks the same two Bash registrations, which is why edit 3 changes one existing row)
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc. The payloads below name the persona config and the marker directory as plain text: that is why the tool, not the shell, writes them.
payload-indent: every fenced payload in this contract starts at column 0 of the contract file, keeps its own leading spaces, and states indent: N; strip exactly N spaces; empty payload lines stay empty.
decision: no SPEC-GAP. Operator decision 2026-10-19 (user, this session): relax two gates in Arm B's pruned plugin copy only, recorded as OD-20. Mechanism chosen: hooks.json of the copy stops registering harness-integrity-gate.sh and reviewed-path-gate.sh for the Bash matcher, because a registration edit leaves hooks/scripts byte-identical to the product tree and keeps both gates armed on Write and Edit; abtest_relax_bash_gates fails the copy unless exactly two entries go. Counts, each checked by command on 2026-10-19: `grep -c '"completion_status": "stalled-human"'` prints 4 for eval/abtest/results.superseded.jsonl (4 of 10 stalled in pilot 1) and 1 for eval/abtest/results.jsonl (1 of 10 in pilot 2, E3 B).
evidence: the E3 B row has permission_denials 3: two hook denials (exit 2) and one permission-rule denial (`sed -n '1,/^---$/p' .claude/agents/lead-programmer.md`, subcommandResults). The product-tree gates reproduce both hook denials offline on the exact command texts (the arms test uses them as the control). The third denial is NOT covered by OD-20 and is named as such in OD-20(d), the pre-registration and the README; if the repeat pilot still stalls on it, that is a new operator decision.
operator-checklist: after landing, the operator re-runs `run-matrix.sh --probe-isolation`, `--probe-canary` and `--pilot` in that order. The 10 rows of the second pilot (eval/abtest/results.jsonl) are superseded under OD-14 and repeat.
green-at-HEAD: criteria 1, 5 and 14 to 16 already pass before the edits (regression guards: the suite is green at 81 rows, hooks.json has 17 registrations, stream.py is untouched, the test file keeps its guarded mktemp and runs no real claude); criteria 2, 4 and 6 to 13 are red at HEAD; criteria 17 to 19 print no-unit-commit with exit 3 until edit 8 runs; criterion 3 prints 0 at HEAD and after.
not-stamped: no agents/*.md or templates/ file is touched, so there is no version bump and no CHANGELOG entry; a scribe close-out owns the CHANGELOG entry.
commit-message: fix(abt-u13h): Arm B plugin copy stops registering two Bash gates that denied read-only commands (OD-20) (#625)
trailers: use the Co-Authored-By and Claude-Session trailers from the session attribution (criterion 18 greps the Co-Authored-By line)
diagnosis: none
review-packet:
~~~
unit: abt-u13h (#625)
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
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
criterion 15: <FILL: exit and stdout>
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
criterion 18: <FILL: exit and stdout>
criterion 19: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
