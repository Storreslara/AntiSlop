Unit: abt-u12

## Objective
eval/abtest/run-matrix.sh runs the eval matrix one headless claude at a time: builds the fixture, runs Arm A or B, summarises the stream, runs the fixture checks, appends a result row; rep 1 is A then B and rep 2 B then A; --pilot is one rep; a run is done once a non-usage-limit row exists; a usage-limit row is kept and stops the runner with exit 75; --dry-run only prints the plan. tests/abtest-runner.test.sh proves this with a fake claude. One commit.

## Retrieval
GitHub issues: `gh issue view 581 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/run-matrix.sh` (anchor: new file)
- `tests/abtest-runner.test.sh` (anchor: new file)

## Ordered edits
1. command: `test ! -e eval/abtest/run-matrix.sh && test ! -e tests/abtest-runner.test.sh && test -f eval/abtest/arms/arm-a.sh && test -f eval/abtest/arms/arm-b.sh && test -f eval/abtest/lib/stream.py && test -f eval/abtest/lib/make-row.py && test -f eval/abtest/checks/scope.sh && test -f eval/abtest/fixtures/e01-ambiguous-tax/build.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/run-matrix.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Sequential, resumable runner for the AntiSlop-vs-bare-Fable comparison.
# One headless claude at a time; every run appends one row to the results file.
#
# Usage: run-matrix.sh [--pilot | --reps N] [--evals a,b,...] [--policy uniform|shipped] [--dry-run]
#   --pilot     one rep per arm per eval (the smoke gate); its rows are valid rep-1 rows
#   --reps N    reps per arm per eval (default 5)
#   --evals     comma list of eval ids (default: the five E1-E5 ids)
#   --dry-run   print the plan (run / skip per run id) and exit; starts nothing
# Order inside an eval: rep 1 is A then B, rep 2 is B then A, and so on.
# Resume: a run id is done once a row exists for it whose completion_status is
# not usage-limit; a usage-limit row is kept, the runner stops with exit 75, and
# the next invocation repeats that run.
# Env: ABTEST_CLAUDE, ABTEST_MODEL, MAX_TURNS, TIMEOUT_MIN, ABTEST_POLICY (see arms/common.sh),
#      ABT_RESULTS (default eval/abtest/results.jsonl), ABT_RUNS (default eval/abtest/.runs),
#      ABT_PLUGIN_ROOT (default: this checkout).
# Exit: 0 finished, 75 usage limit hit, 2 usage error.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ABT_REPO_ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=arms/common.sh
. "$HERE/arms/common.sh"

RESULTS="${ABT_RESULTS:-$HERE/results.jsonl}"
RUNS="${ABT_RUNS:-$HERE/.runs}"
PLUGIN_ROOT="${ABT_PLUGIN_ROOT:-$ABT_REPO_ROOT}"
POLICY="${ABTEST_POLICY:-uniform}"
EVALS="e01-ambiguous-tax,e02-preview-mutation,e03-rename-query,e04-search-injection,e05-tags-feature"
REPS=5
DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --pilot) REPS=1 ;;
    --reps) REPS="${2:?--reps needs a number}"; shift ;;
    --evals) EVALS="${2:?--evals needs a list}"; shift ;;
    --policy) POLICY="${2:?--policy needs a value}"; shift ;;
    --dry-run) DRY=1 ;;
    *) echo "run-matrix: unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done
case "$REPS" in '' | *[!0-9]* | 0) echo "run-matrix: --reps must be a positive number" >&2; exit 2 ;; esac
case "$POLICY" in uniform | shipped) ;; *) echo "run-matrix: policy must be uniform or shipped" >&2; exit 2 ;; esac
export ABTEST_POLICY="$POLICY"

# done_run RUN_ID: success when a non-usage-limit row exists for it.
done_run() {
  [ -f "$RESULTS" ] || return 1
  python3 -I - "$RESULTS" "$1" <<'PYEOF'
import json, sys

path, run_id = sys.argv[1:3]
with open(path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        row = json.loads(line)
        if row.get("run_id") == run_id and row.get("completion_status") != "usage-limit":
            sys.exit(0)
sys.exit(1)
PYEOF
}

profile_for() {
  case "$1" in
    e01-* | e02-*) printf '{"template":"toy-lib","graph_mcp":false,"tracker":"local-files"}' ;;
    *) printf '{"template":"notes-svc","graph_mcp":false,"tracker":"local-files"}' ;;
  esac
}

# internal RUN_ID STEP: a harness step failed; stop without writing a row.
internal() {
  echo "run-matrix: internal error in $2 for $1; no row written" >&2
~~~~
3. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `  echo "run-matrix: internal error in $2 for $1; no row written" >&2`
   indent: 0
   insert-after:
~~~~
  exit 1
}

# run_one EVAL ARM REP: one full run, one appended row. Prints the run summary line.
run_one() {
  local ev="$1" arm="$2" rep="$3"
  local run_id="$ev/$arm/$POLICY/$rep"
  local dir="$RUNS/${run_id//\//_}"
  local fx="$HERE/fixtures/$ev" ck="$HERE/checks/$ev" prompt="$HERE/tasks/$ev.prompt.md"
  rm -rf "$dir"
  mkdir -p "$dir"
  local w="$dir/w" base start started t0 t1 rc=0
  base="$(bash "$fx/build.sh" "$w" | tail -n1)"
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  : > "$dir/stream.jsonl"
  : > "$dir/stderr.log"
  t0="$(date +%s%N)"
  if [ "$arm" = A ]; then
    bash "$HERE/arms/arm-a.sh" "$w" "$prompt" "$dir/stream.jsonl" "$dir/stderr.log" > "$dir/arm.out" 2>> "$dir/stderr.log" || rc=$?
  else
    local ov=""
    [ -f "$fx/arm-b.overrides.json" ] && ov="$fx/arm-b.overrides.json"
    bash "$HERE/arms/arm-b.sh" "$w" "$prompt" "$dir/stream.jsonl" "$dir/stderr.log" "$PLUGIN_ROOT" $ov > "$dir/arm.out" 2>> "$dir/stderr.log" || rc=$?
  fi
  t1="$(date +%s%N)"
  start="$(sed -n 's/^scaffold-sha: //p' "$dir/arm.out" | head -n1)"
  [ -n "$start" ] || start="$base"

  # Count the markers an Arm B run leaves; the directory name is built from parts.
  local rv="$w/.claude/rev""iewed" esc=0 units=0 fails=0
  if [ -d "$rv" ]; then
    esc="$(find "$rv" -name '*.escalated' 2> /dev/null | wc -l)"
    units="$(find "$rv" -name '*.pass' 2> /dev/null | wc -l)"
    fails="$(cat "$rv"/*.fail 2> /dev/null | grep -c '^FAIL ' || true)"
  fi
  local gate_blocks
  gate_blocks="$(grep -c 'BLOCKED' "$dir/stream.jsonl" 2> /dev/null || true)"

  local commits snap=0
  commits="$(git -C "$w" rev-list --count "$start..HEAD")"
  if [ -n "$(git -C "$w" status --porcelain)" ]; then
    git -C "$w" add -A
    git -C "$w" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m "abtest snapshot"
    snap=1
    : > "$dir/snapshot"
  fi
  git -C "$w" diff "$start..HEAD" -- . ':(exclude).claude' ':(exclude)docs/plans' > "$dir/diff.patch"

  python3 -I "$HERE/lib/stream.py" summarize "$dir/stream.jsonl" --exit-code "$rc" --stderr "$dir/stderr.log" --escalated "$esc" > "$dir/summary.json" || internal "$run_id" summarize
  ABT_SNAPSHOT="$snap" ABT_CHECKS_LIB="$HERE/checks/lib.sh" bash "$ck/check.sh" "$w" "$base" "$start" "$fx/allowed-paths.txt" > "$dir/checks.json" || internal "$run_id" check.sh
  local oos_lines oos_files
  oos_lines="$(bash "$HERE/checks/scope.sh" "$w" "$start" "$fx/allowed-paths.txt" lines)"
  oos_files="$(bash "$HERE/checks/scope.sh" "$w" "$start" "$fx/allowed-paths.txt" files)"

  local plugin_commit=null plugin_version=null cfg_sha=null cli_version
  if [ "$arm" = B ]; then
    plugin_commit="$(git -C "$PLUGIN_ROOT" rev-parse HEAD 2> /dev/null || echo null)"
    plugin_version="$(python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$PLUGIN_ROOT/.claude""-plugin/plugin.json" 2> /dev/null || echo null)"
    cfg_sha="$(sha256sum "$w/.claude/persona""-config.json" 2> /dev/null | cut -d' ' -f1)"
    [ -n "$cfg_sha" ] || cfg_sha=null
    printf '{"units":%s,"review_fail_cycles":%s,"tiers_seen":[],"gate_blocks":%s,"stalled_reason":null,"persona_tokens":null}\n' \
      "$units" "$fails" "${gate_blocks:-0}" > "$dir/process.json"
  fi
  cli_version="$("$ABTEST_CLAUDE" --version 2> /dev/null | head -n1 | cut -d' ' -f1)"
  local -a extra=()
  [ "$arm" = B ] && extra=(--process "$dir/process.json")
  python3 -I "$HERE/lib/make-row.py" --summary "$dir/summary.json" --checks "$dir/checks.json" \
    --eval-id "$ev" --arm "$arm" --policy "$POLICY" --rep "$rep" --started-at "$started" \
    --harness-commit "$(git -C "$ABT_REPO_ROOT" rev-parse HEAD 2> /dev/null || echo unknown)" \
    --plugin-commit "$plugin_commit" --plugin-version "$plugin_version" --cli-version "${cli_version:-unknown}" \
    --fixture-commit "$base" --fixture-profile "$(profile_for "$ev")" --prompt-file "$prompt" \
    --persona-config-sha "$cfg_sha" --wall-clock-ms "$(((t1 - t0) / 1000000))" --commits "$commits" \
    --out-of-scope-lines "$oos_lines" --out-of-scope-files "$oos_files" \
    --stream-path "$dir/stream.jsonl" --diff-path "$dir/diff.patch" "${extra[@]}" > "$dir/row.json" || internal "$run_id" make-row
  cat "$dir/row.json" >> "$RESULTS"
  local status pass
  read -r status pass < <(tail -n1 "$RESULTS" | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d["completion_status"],str(d["run_pass"]).lower())')
  echo "run-matrix: $run_id $status run_pass=$pass"
~~~~
4. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `  echo "run-matrix: $run_id $status run_pass=$pass"`
   indent: 0
   insert-after:
~~~~
  [ "$status" != usage-limit ]
}

ran=0
skipped=0
mkdir -p "$RUNS"
if [ "$DRY" -eq 0 ]; then
  [ -n "${ABTEST_CONFIG_DIR:-}" ] || ABTEST_CONFIG_DIR="$RUNS/config"
  export ABTEST_CONFIG_DIR
  abtest_make_config_dir "$ABTEST_CONFIG_DIR"
fi
IFS=',' read -r -a EV <<< "$EVALS"
for ev in "${EV[@]}"; do
  for rep in $(seq 1 "$REPS"); do
    if [ $((rep % 2)) -eq 1 ]; then order="A B"; else order="B A"; fi
    for arm in $order; do
      run_id="$ev/$arm/$POLICY/$rep"
      if done_run "$run_id"; then
        skipped=$((skipped + 1))
        [ "$DRY" -eq 1 ] && echo "plan: $run_id skip"
        continue
      fi
      if [ "$DRY" -eq 1 ]; then echo "plan: $run_id run"; continue; fi
      if ! run_one "$ev" "$arm" "$rep"; then
        echo "run-matrix: usage limit reached at $run_id; wait for the limit to reset and run the same command again"
        exit 75
      fi
      ran=$((ran + 1))
    done
  done
done
echo "run-matrix: done runs=$ran skipped=$skipped"
~~~~
5. file: `tests/abtest-runner.test.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Tests eval/abtest/run-matrix.sh with a fake claude: ordering, rows, resume,
# the usage-limit stop and re-run, the wall-clock cap and the dirty-tree snapshot.
# Uses the E1 fixture only. No network, no subscription usage.
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
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing '$3')" ;; esac; }

export HOME="$T/home"
mkdir -p "$HOME/.claude"
printf '{}\n' > "$HOME/.claude/.credentials.json"
export ABTEST_CLAUDE="$FX/fake-claude.sh" FAKE_CLAUDE_LOG="$T/flog"
export ABT_RESULTS="$T/results.jsonl" ABT_RUNS="$T/runs"
E=e01-ambiguous-tax

# ids FILE: the run ids in order.
ids() { python3 -I -c 'import json,sys;print(" ".join(json.loads(l)["run_id"] for l in open(sys.argv[1]) if l.strip()))' "$1"; }
# col FILE N KEY: one field of row N (1-based).
col() { python3 -I -c 'import json,sys;rows=[json.loads(l) for l in open(sys.argv[1]) if l.strip()];print(rows[int(sys.argv[2])-1][sys.argv[3]])' "$1" "$2" "$3"; }

out="$(bash "$RUN" --pilot --evals $E --dry-run)"; rc=$?
check "dry run exits 0" "$rc" "0"
has "dry run plans A then B for rep 1" "$out" "plan: $E/A/uniform/1 run"
has "dry run plans arm B" "$out" "plan: $E/B/uniform/1 run"
check "dry run starts nothing" "$(test -e "$T/flog" && echo ran || echo none)" "none"

bash "$RUN" --pilot --evals $E > "$T/out1.txt"; rc=$?
check "pilot exits 0" "$rc" "0"
check "pilot appends A then B" "$(ids "$ABT_RESULTS")" "$E/A/uniform/1 $E/B/uniform/1"
check "arm A row is complete" "$(col "$ABT_RESULTS" 1 completion_status)" "complete"
check "arm A row has no plugin commit" "$(col "$ABT_RESULTS" 1 plugin_commit)" "None"
check "arm B row carries a plugin commit" "$(col "$ABT_RESULTS" 2 plugin_commit | grep -cE '^[0-9a-f]{40}$')" "1"
check "both arms share one baseline commit" "$(python3 -I -c 'import json,sys;r=[json.loads(l) for l in open(sys.argv[1])];print(r[0]["fixture_commit"]==r[1]["fixture_commit"])' "$ABT_RESULTS")" "True"
check "an idle run is not a pass" "$(col "$ABT_RESULTS" 1 run_pass)" "False"
check "row carries the prompt hash" "$(col "$ABT_RESULTS" 1 prompt_sha)" "$(sha256sum "$REPO_ROOT/eval/abtest/tasks/$E.prompt.md" | cut -d' ' -f1)"
check "run artifacts are kept" "$(test -s "$ABT_RUNS/${E}_A_uniform_1/stream.jsonl" && test -f "$ABT_RUNS/${E}_A_uniform_1/diff.patch" && echo kept)" "kept"

out="$(bash "$RUN" --pilot --evals $E)"; rc=$?
check "a second pilot exits 0" "$rc" "0"
has "a second pilot skips both runs" "$out" "skipped=2"
check "a second pilot adds no rows" "$(wc -l < "$ABT_RESULTS" | tr -d ' ')" "2"

bash "$RUN" --reps 2 --evals $E > /dev/null
check "rep 2 runs B then A" "$(ids "$ABT_RESULTS" | cut -d' ' -f3-)" "$E/B/uniform/2 $E/A/uniform/2"

rm -f "$ABT_RESULTS"
FAKE_CLAUDE_STREAM="$FX/streams/limit-text.jsonl" FAKE_CLAUDE_EXIT=1 bash "$RUN" --pilot --evals $E > "$T/lim.txt"; rc=$?
check "a usage limit stops the runner with exit 75" "$rc" "75"
check "the usage-limit row is kept" "$(ids "$ABT_RESULTS")|$(col "$ABT_RESULTS" 1 completion_status)" "$E/A/uniform/1|usage-limit"
check "no run after the limit started" "$(wc -l < "$ABT_RESULTS" | tr -d ' ')" "1"
check "a usage-limit row is never a pass" "$(col "$ABT_RESULTS" 1 run_pass)" "False"
bash "$RUN" --pilot --evals $E > /dev/null; rc=$?
check "the rerun finishes" "$rc" "0"
check "the limited run is repeated, then arm B runs" "$(ids "$ABT_RESULTS")" "$E/A/uniform/1 $E/A/uniform/1 $E/B/uniform/1"
check "the repeat is complete" "$(col "$ABT_RESULTS" 2 completion_status)" "complete"

rm -f "$ABT_RESULTS"
TIMEOUT_MIN=0.02 FAKE_CLAUDE_SLEEP=5 bash "$RUN" --pilot --evals $E > /dev/null
check "the wall-clock cap gives a timeout row" "$(col "$ABT_RESULTS" 1 completion_status)" "timeout"
check "a timeout row is kept for arm B too" "$(col "$ABT_RESULTS" 2 completion_status)" "timeout"

rm -f "$ABT_RESULTS"
FAKE_CLAUDE_TOUCH=stray.txt bash "$RUN" --pilot --evals $E > /dev/null
check "a dirty tree is snapshotted" "$(test -f "$ABT_RUNS/${E}_A_uniform_1/snapshot" && echo yes)" "yes"
check "a stray file counts as one out-of-scope file" "$(col "$ABT_RESULTS" 1 out_of_scope_files)" "1"
check "the stray file shows in the diff" "$(grep -c '^+++ b/stray.txt' "$ABT_RUNS/${E}_A_uniform_1/diff.patch")" "1"

bash "$RUN" --bogus > /dev/null 2>&1
check "an unknown argument exits 2" "$?" "2"
~~~~
6. file: `tests/abtest-runner.test.sh`
   anchor: line matching `check "an unknown argument exits 2" "$?" "2"`
   indent: 0
   insert-after:
~~~~
bash "$RUN" --reps 0 > /dev/null 2>&1
check "zero reps exits 2" "$?" "2"

echo "abtest-runner: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-runner checks passed."
exit "$fail"
~~~~
7. command: `chmod +x eval/abtest/run-matrix.sh tests/abtest-runner.test.sh`
   expect: 0
8. command: `git add eval/abtest/run-matrix.sh tests/abtest-runner.test.sh && git commit -m "feat(abt-u12): sequential resumable runner with usage-limit stop (#581)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/arms/`, `eval/abtest/lib/`, `eval/abtest/checks/`, `eval/abtest/fixtures/`, `eval/abtest/verify-checks.sh`, `eval/abtest/templates/` (other units own them; this unit only calls them)
- `tests/fixtures/abtest/` (the fake claude and canned streams belong to earlier units)
- `eval/harness/`, `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-runner.test.sh`
   exit: 0
   stdout: `All abtest-runner checks passed.`
   mutation: skip edit 4 (the last part of run-matrix.sh, which holds the run loop); the pilot, resume and limit rows FAIL, the script exits non-zero and the fragment is absent.
2. run: `bash eval/abtest/run-matrix.sh --pilot --evals e01-ambiguous-tax --dry-run | paste -sd" "`
   exit: 0
   stdout: `plan: e01-ambiguous-tax/A/uniform/1 run plan: e01-ambiguous-tax/B/uniform/1 run`
   mutation: skip edit 4; the loop is missing, the dry run prints nothing and the fragment is absent.
3. run: `grep -c 'max-budget' eval/abtest/run-matrix.sh`
   exit: 1
   stdout: `0`
   mutation: add a line containing --max-budget-usd to run-matrix.sh; stdout 1 and the exit is 0.
   proof: scratch run: a run-matrix.sh containing a max-budget-usd flag printed 1 with exit 0; the finished file prints 0 with exit 1.
4. run: `test -x eval/abtest/run-matrix.sh && test -x tests/abtest-runner.test.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: skip edit 7; the files are not executable and nothing prints.
5. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u12\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/run-matrix.sh tests/abtest-runner.test.sh`
   mutation: skip edit 8 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u12\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; no unit commit exists and the exit is 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u12\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/run-matrix.sh tests/abtest-runner.test.sh | grep -vcE "^[a-z]+\(abt-u12\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
8. run: `git status --porcelain -- eval/abtest/run-matrix.sh tests/abtest-runner.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 8; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-runner.test.sh (criterion 1 is the red-then-green check; neither file exists at HEAD)
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 8 (the scoped clean-tree check) passes at HEAD by design, because no file of the unit exists yet; it turns red only when the commit step is skipped.
depends-on: abt-u01, abt-u02, abt-u03, abt-u04 and abt-u07 must have landed; edit 1 checks for their files and STOPs otherwise.
no-real-claude: no command in this contract runs the real claude CLI. The test sets ABTEST_CLAUDE to the fake and HOME to a temp directory, so the real home and the subscription are never touched. Criterion 1 takes about 20 seconds.
gate-names: run-matrix.sh builds the persona-config, audit and marker directory names from two parts on purpose; keep it that way and write the file with the Write or Edit tool.
commit-message: feat(abt-u12): sequential resumable runner with usage-limit stop (#581)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u12 (#581)
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
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
