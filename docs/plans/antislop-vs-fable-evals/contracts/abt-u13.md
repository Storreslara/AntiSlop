Unit: abt-u13

## Objective
run-matrix.sh gains --probe-isolation and --probe-model uniform: both arms run once on a tiny task and the spec probe lines print; exit 0 only for a clean isolation and a fable model on both arms, 75 on a usage limit, 2 on a bad model; extra probe-detail lines report the max-turns flag, record types and a hook census. tests/abtest-probe.test.sh passes against a fake claude and tests/abtest-runner.test.sh still passes. One commit.

## Retrieval
GitHub issues: `gh issue view 582 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/run-matrix.sh` (anchor: line matching `DRY=0`)
- `tests/abtest-probe.test.sh` (anchor: new file)

## Ordered edits
1. command: `test -f eval/abtest/run-matrix.sh && test ! -e tests/abtest-probe.test.sh && ! grep -q probe eval/abtest/run-matrix.sh && test -f eval/abtest/lib/stream.py && test -f eval/abtest/fixtures/e01-ambiguous-tax/build.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `#   --dry-run   print the plan (run / skip per run id) and exit; starts nothing`
   indent: 0
   insert-after:
~~~~
#   --probe-isolation   run both arms once on a tiny task and print the isolation line
#   --probe-model uniform   same two runs, print the model line (give both flags to run once)
~~~~
3. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `DRY=0`
   indent: 0
   insert-after:
~~~~
PROBE_ISO=0
PROBE_MODEL=""
~~~~
4. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `    --dry-run) DRY=1 ;;`
   indent: 0
   insert-after:
~~~~
    --probe-isolation) PROBE_ISO=1 ;;
    --probe-model) PROBE_MODEL="${2:?--probe-model needs a value}"; shift ;;
~~~~
5. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `mkdir -p "$RUNS"`
   indent: 0
   insert-after:
~~~~
# probe_arm ARM: one tiny run of the arm on the E1 fixture, summarised under $RUNS/probe/ARM.
probe_arm() {
  local arm="$1" dir="$RUNS/probe/$1" rc=0
  rm -rf "$dir"
  mkdir -p "$dir"
  bash "$HERE/fixtures/e01-ambiguous-tax/build.sh" "$dir/w" > /dev/null
  printf 'Find where the function round2 is defined in this repository. Use a subagent if one is available. Reply with the file path only and change no file.\n' > "$dir/prompt.md"
  : > "$dir/stream.jsonl"
  : > "$dir/stderr.log"
  if [ "$arm" = A ]; then
    bash "$HERE/arms/arm-a.sh" "$dir/w" "$dir/prompt.md" "$dir/stream.jsonl" "$dir/stderr.log" > /dev/null 2>> "$dir/stderr.log" || rc=$?
  else
    bash "$HERE/arms/arm-b.sh" "$dir/w" "$dir/prompt.md" "$dir/stream.jsonl" "$dir/stderr.log" "$PLUGIN_ROOT" > /dev/null 2>> "$dir/stderr.log" || rc=$?
  fi
  python3 -I "$HERE/lib/stream.py" summarize "$dir/stream.jsonl" --exit-code "$rc" --stderr "$dir/stderr.log" > "$dir/summary.json" || internal "probe/$arm" summarize
}

# pf ARM KEY: one summary field of a probe run (a dict prints its sorted keys, comma-joined).
pf() {
  python3 -I -c 'import json,sys;v=json.load(open(sys.argv[1]))[sys.argv[2]];print(",".join(sorted(v)) if isinstance(v,dict) else v)' "$RUNS/probe/$1/summary.json" "$2"
}

# types ARM: the distinct record types of a probe stream, for comparing with the real CLI.
types() {
  python3 -I -c 'import json,sys
seen=set()
for l in open(sys.argv[1]):
    try:
        d=json.loads(l)
    except ValueError:
        continue
    seen.add(str(d.get("type"))+(":"+str(d["subtype"]) if d.get("subtype") else ""))
print(",".join(sorted(seen)))' "$RUNS/probe/$1/stream.jsonl"
}

if [ "$PROBE_ISO" -eq 1 ] || [ -n "$PROBE_MODEL" ]; then
  if [ -n "$PROBE_MODEL" ] && [ "$PROBE_MODEL" != uniform ]; then
    echo "run-matrix: --probe-model takes uniform" >&2
    exit 2
  fi
  export ABTEST_POLICY=uniform
  [ -n "${ABTEST_CONFIG_DIR:-}" ] || ABTEST_CONFIG_DIR="$RUNS/config"
  export ABTEST_CONFIG_DIR
  abtest_make_config_dir "$ABTEST_CONFIG_DIR"
  probe_arm A
  probe_arm B
  for arm in A B; do
    if [ "$(pf "$arm" completion_status)" = usage-limit ]; then
      echo "run-matrix: usage limit reached during the probe; wait for the limit to reset and run the same command again"
      exit 75
    fi
  done
  prc=0
  ahook="$(pf A hook_events)"
  bhook="$(pf B hook_events)"
  bspawn="$(pf B subagent_spawns)"
  aref="$(grep -cE 'agent_type[^,}]*(orchestrator|spec-master|task-master|lead-programmer|reviewer|scribe|explorer)' "$RUNS/probe/A/stream.jsonl" || true)"
  if [ "$PROBE_ISO" -eq 1 ]; then
    echo "probe: A hook_events=$ahook persona_refs=$aref B hook_events=$bhook subagent_spawns=$bspawn"
    if [ "$ahook" != 0 ] || [ "$aref" != 0 ] || [ "$bhook" -lt 1 ] || [ "$bspawn" -lt 1 ]; then prc=1; fi
  fi
  if [ -n "$PROBE_MODEL" ]; then
    ma="$(pf A model_usage)"
    mb="$(pf B model_usage)"
    echo "probe: A model=$ma B model=$mb"
    case "$ma" in *fable*) ;; *) prc=1 ;; esac
    case "$mb" in *fable*) ;; *) prc=1 ;; esac
  fi
  echo "probe-detail: A status=$(pf A completion_status) B status=$(pf B completion_status)"
  if grep -qiE "unknown option|max-turns" "$RUNS/probe/A/stderr.log" "$RUNS/probe/B/stderr.log"; then
    echo "probe-detail: max-turns flag accepted=no (see stderr.log under $RUNS/probe)"
  else
    echo "probe-detail: max-turns flag accepted=yes"
  fi
  echo "probe-detail: B session_start_events=$(pf B session_start_events) (a hook counted twice here may mean the plugin and the scaffolded settings both registered it; see hook-names.txt)"
  python3 -I -c 'import collections,json,sys
c=collections.Counter()
~~~~
6. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `c=collections.Counter()`
   indent: 0
   insert-after:
~~~~
for l in open(sys.argv[1]):
    try:
        d=json.loads(l)
    except ValueError:
        continue
    if str(d.get("type","")).startswith("hook") or str(d.get("subtype","")).startswith("hook"):
        c[str(d.get("hook_name") or d.get("hookName") or d.get("hook_event") or "?")+" "+str(d.get("subtype") or d.get("type"))]+=1
for k,v in sorted(c.items()):
    print(v,k)' "$RUNS/probe/B/stream.jsonl" > "$RUNS/probe/B/hook-names.txt"
  echo "probe-detail: A record types: $(types A)"
  echo "probe-detail: B record types: $(types B)"
  exit "$prc"
fi
~~~~
7. file: `tests/abtest-probe.test.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Tests the --probe-isolation and --probe-model modes of run-matrix.sh with a
# fake claude whose canned stream depends on the arm. No network, no usage.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN="$REPO_ROOT/eval/abtest/run-matrix.sh"
FX="$REPO_ROOT/tests/fixtures/abtest"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing '$3' in '$2')" ;; esac; }

export HOME="$T/home"
mkdir -p "$HOME/.claude"
printf '{}\n' > "$HOME/.claude/.credentials.json"
export FAKE_CLAUDE_LOG="$T/flog" ABT_RESULTS="$T/results.jsonl" ABT_RUNS="$T/runs"

# A wrapper that hands Arm B (the one given --plugin-dir) its own canned stream.
cat > "$T/claude" << EOS
#!/usr/bin/env bash
case " \$* " in
  *" --plugin-dir "*) export FAKE_CLAUDE_STREAM="\$PROBE_B" ;;
  *) export FAKE_CLAUDE_STREAM="\$PROBE_A" ;;
esac
exec "$FX/fake-claude.sh" "\$@"
EOS
chmod +x "$T/claude"
export ABTEST_CLAUDE="$T/claude"
GOOD_A="$FX/streams/mentions-limit.jsonl"
GOOD_B="$FX/streams/complete.jsonl"
sed 's/fable-x/sonnet-y/g' "$GOOD_B" > "$T/b-sonnet.jsonl"

export PROBE_A="$GOOD_A" PROBE_B="$GOOD_B"
out="$(bash "$RUN" --probe-isolation)"; rc=$?
check "a clean isolation probe exits 0" "$rc" "0"
has "the isolation line has the spec shape" "$out" "probe: A hook_events=0 persona_refs=0 B hook_events=2 subagent_spawns=1"
check "the isolation line matches the spec regex" "$(printf '%s\n' "$out" | grep -cE '^probe: A hook_events=0 persona_refs=0 B hook_events=[1-9][0-9]* subagent_spawns=[1-9][0-9]*$')" "1"
has "the probe reports the max-turns flag as accepted" "$out" "max-turns flag accepted=yes"
has "the probe lists record types for the operator" "$out" "probe-detail: B record types:"
check "the hook name census is written" "$(test -s "$ABT_RUNS/probe/B/hook-names.txt" && echo yes)" "yes"

out="$(bash "$RUN" --probe-model uniform)"; rc=$?
check "a clean model probe exits 0" "$rc" "0"
check "the model line matches the spec regex" "$(printf '%s\n' "$out" | grep -cE '^probe: A model=.*fable.* B model=.*fable.*$')" "1"

rm -rf "$T/flog"
out="$(bash "$RUN" --probe-isolation --probe-model uniform)"; rc=$?
check "both probes in one call exit 0" "$rc" "0"
has "both lines print" "$out" "probe: A model="
check "both probes share one pair of runs" "$(ls "$T/flog" | grep -c '^argv\.')" "2"

PROBE_B="$GOOD_A" bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "an arm B without hook events fails the probe" "$rc" "1"
has "the failing line shows zero hook events for B" "$(cat "$T/o.txt")" "B hook_events=0 subagent_spawns=0"

PROBE_A="$GOOD_B" bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "an arm A with hook events fails the probe" "$rc" "1"
has "the failing line shows hook events for A" "$(cat "$T/o.txt")" "probe: A hook_events=2"

PROBE_B="$T/b-sonnet.jsonl" bash "$RUN" --probe-model uniform > "$T/o.txt"; rc=$?
check "a model without fable fails the probe" "$rc" "1"
has "the model line shows what ran" "$(cat "$T/o.txt")" "B model=sonnet-y"

PROBE_B="$FX/streams/limit-text.jsonl" FAKE_CLAUDE_EXIT=1 bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "a usage limit during the probe exits 75" "$rc" "75"

FAKE_CLAUDE_STDERR="error: unknown option '--max-turns'" bash "$RUN" --probe-isolation > "$T/o.txt"
has "a rejected max-turns flag is reported" "$(cat "$T/o.txt")" "max-turns flag accepted=no"

bash "$RUN" --probe-model other > /dev/null 2>&1
check "an unknown probe model exits 2" "$?" "2"

echo "abtest-probe: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-probe checks passed."
~~~~
8. file: `tests/abtest-probe.test.sh`
   anchor: line matching `[ "$fail" -eq 0 ] && echo "All abtest-probe checks passed."`
   indent: 0
   insert-after:
~~~~
exit "$fail"
~~~~
9. command: `chmod +x tests/abtest-probe.test.sh`
   expect: 0
10. command: `git add eval/abtest/run-matrix.sh tests/abtest-probe.test.sh && git commit -m "feat(abt-u13): isolation and model probes in the runner (#582)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/arms/`, `eval/abtest/lib/`, `eval/abtest/checks/`, `eval/abtest/fixtures/`, `eval/abtest/verify-checks.sh` (other units own them)
- `tests/abtest-runner.test.sh`, `tests/fixtures/abtest/` (unit abt-u12 and earlier own them; this unit must leave the runner test passing)
- `eval/harness/`, `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-probe.test.sh`
   exit: 0
   stdout: `All abtest-probe checks passed.`
   mutation: skip edit 6 (the last part of the probe block); the exit and verdict rows FAIL, the script exits non-zero and the fragment is absent.
2. run: `bash tests/abtest-runner.test.sh`
   exit: 0
   stdout: `All abtest-runner checks passed.`
   mutation: skip edit 3 (the probe variable defaults); the unset variable stops the runner and the rows FAIL.
3. run: `grep -c -e '--probe-isolation' -e '--probe-model' eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `5`
   mutation: skip edit 4 (the argument cases); only the two usage comment lines and the block mention remain, so the count is 3.
4. run: `grep -c 'max-budget' eval/abtest/run-matrix.sh`
   exit: 1
   stdout: `0`
   mutation: add a line containing --max-budget-usd to run-matrix.sh; stdout 1 and the exit is 0.
   proof: scratch run: a run-matrix.sh containing a max-budget-usd flag printed 1 with exit 0; the finished file prints 0 with exit 1.
5. run: `test -x tests/abtest-probe.test.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: skip edit 9; the file is not executable and nothing prints.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/run-matrix.sh tests/abtest-probe.test.sh`
   mutation: skip edit 10 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 10; no unit commit exists and the exit is 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/run-matrix.sh tests/abtest-probe.test.sh | grep -vcE "^[a-z]+\(abt-u13\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
9. run: `git status --porcelain -- eval/abtest/run-matrix.sh tests/abtest-probe.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 10; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-probe.test.sh (criterion 1 is the red-then-green check; the test file does not exist at HEAD)
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criteria 2 and 4 (regression guards on the finished runner) and criterion 9 (the scoped clean-tree check) pass at HEAD by design; criterion 2 turns red only if the probe edits break the runner, criterion 4 only if a dollar flag is added, criterion 9 only when the commit step is skipped.
depends-on: abt-u12 must have landed (run-matrix.sh exists); edit 1 checks for it and STOPs otherwise.
no-real-claude: no command in this contract runs the real claude CLI; the test uses a fake claude wrapper and a temp HOME.
insertion-order: edit 5 and the next edits insert the probe block after the line mkdir -p "$RUNS"; it must run before the normal config-dir setup, and it creates its own config dir.
commit-message: feat(abt-u13): isolation and model probes in the runner (#582)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u13 (#582)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
