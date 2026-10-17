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
export ABT_RESULTS="$T/results.jsonl" ABT_RUNS="$T/runs" ABT_WORK="$T/work"
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
check "dry run creates no run or work directory" "$(test -e "$T/runs" || test -e "$T/work" && echo made || echo none)" "none"

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
bash "$RUN" --reps 0 > /dev/null 2>&1
check "zero reps exits 2" "$?" "2"

echo "abtest-runner: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-runner checks passed."
exit "$fail"
