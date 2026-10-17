#!/usr/bin/env bash
# Tests eval/abtest/run-matrix.sh with a fake claude: ordering, rows, resume,
# the usage-limit stop and re-run, the wall-clock cap and the dirty-tree snapshot.
# Uses the E1 fixture only. No network, no subscription usage.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN="$REPO_ROOT/eval/abtest/run-matrix.sh"
FX="$REPO_ROOT/tests/fixtures/abtest"
T="$(mktemp -d)"
trap 'pkill -KILL -f "$T/(wrap|fake-copy|hangver|stubborn)" 2> /dev/null; rm -rf "$T"' EXIT
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

# --- guards (abt-u12-fix1): one claude at a time, interrupts, one runner, fail-closed arm start, absolute paths ---
cp "$FX/fake-claude.sh" "$T/fake-copy.sh"
export FAKE_CLAUDE_BIN="$T/fake-copy.sh"
cat > "$T/wrap" << 'EOS'
#!/usr/bin/env bash
if [ "${1:-}" = --version ]; then echo wrap-0; exit 0; fi
trap '' TERM
exec "$FAKE_CLAUDE_BIN" "$@"
EOS
cat > "$T/hangver" << 'EOS'
#!/usr/bin/env bash
if [ "${1:-}" = --version ]; then exec sleep 60; fi
exec "$FAKE_CLAUDE_BIN" "$@"
EOS
chmod +x "$T/wrap" "$T/hangver"
# alive: how many processes of this test's claude doubles are running.
alive() { pgrep -f "$T/(wrap|fake-copy|hangver)" | wc -l | tr -d ' '; }
# nrows FILE: the number of rows in a results file, 0 when it is missing.
nrows() { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }
# statuses FILE: the completion statuses in order.
statuses() { python3 -I -c 'import json,sys;print([json.loads(l)["completion_status"] for l in open(sys.argv[1]) if l.strip()])' "$1"; }

# A claude that ignores SIGTERM must not outlive its run: the wrapper ignores TERM, then runs the fake.
rm -rf "$ABT_RESULTS" "$T/flog" "$T/work"
start=$SECONDS
ABTEST_CLAUDE="$T/wrap" FAKE_CLAUDE_SLEEP=8 FAKE_CLAUDE_TOUCH=late.txt TIMEOUT_MIN=0.02 ABT_OUTER_GRACE_S=3 ABT_KILL_AFTER_S=1 bash "$RUN" --pilot --evals $E > /dev/null 2>&1
elapsed=$((SECONDS - start))
check "a claude that ignores SIGTERM is recorded as a timeout for both arms" "$(statuses "$ABT_RESULTS")" "['timeout', 'timeout']"
check "no claude process is alive when the runner returns" "$(alive)" "0"
check "the run with a stubborn claude stayed bounded" "$([ "$elapsed" -lt 30 ] && echo fast || echo "slow:$elapsed")" "fast"
sleep 5
check "no late edit appears in a work tree after its row was written" "$(ls "$T"/work/*/w/late.txt 2> /dev/null | wc -l | tr -d ' ')" "0"

# Ctrl-C, SIGTERM and SIGHUP stop the runner and the claude it started; the run in progress has no row.
# The runner is started by python in a session of its own, so the signal reaches its process group only.
# The runner must exit within 5 seconds while the fake claude would sleep for 8, or the helper prints :slow.
sigrun() {
  python3 -I - "$1" "$T/flog" "$RUN" "$E" << 'PYEOF'
import os, signal, subprocess, sys, time

name, flog, run, ev = sys.argv[1:5]
p = subprocess.Popen(["bash", run, "--pilot", "--evals", ev], start_new_session=True,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
end = time.time() + 20
while not os.path.exists(os.path.join(flog, "argv.1")) and time.time() < end:
    time.sleep(0.1)
t0 = time.time()
os.killpg(p.pid, getattr(signal, "SIG" + name))
try:
    rc = p.wait(timeout=15)
    print(rc if time.time() - t0 < 5 else str(rc) + ":slow")
except subprocess.TimeoutExpired:
    os.killpg(p.pid, signal.SIGKILL)
    print("hung")
PYEOF
}
for pair in INT:130 TERM:143 HUP:129; do
  sg="${pair%%:*}"
  rm -rf "$ABT_RESULTS" "$T/flog" "$T/work"
  got="$(ABTEST_CLAUDE="$T/fake-copy.sh" FAKE_CLAUDE_SLEEP=8 sigrun "$sg")"
  check "SIG$sg stops the runner with exit ${pair##*:}" "$got" "${pair##*:}"
  check "after SIG$sg no row, no claude and no lock remain" "$(nrows "$ABT_RESULTS")|$(alive)|$(test -e "$T/work/.run-matrix.lock" && echo lock || echo none)" "0|0|none"
done

# One runner at a time.
rm -rf "$ABT_RESULTS" "$T/flog" "$T/work"
ABTEST_CLAUDE="$T/fake-copy.sh" FAKE_CLAUDE_SLEEP=6 bash "$RUN" --pilot --evals $E > /dev/null 2>&1 &
first=$!
for _ in $(seq 100); do [ -e "$T/flog/argv.1" ] && break; sleep 0.1; done
out="$(bash "$RUN" --pilot --evals $E 2>&1)"; rc=$?
check "a second runner started while one runs exits 2" "$rc" "2"
has "the refusal names the lock directory" "$out" "holds $T/work/.run-matrix.lock"
bash "$RUN" --pilot --evals $E --dry-run > /dev/null 2>&1
check "a dry run takes no lock and exits 0" "$?" "0"
kill -TERM "$first"
wait "$first" 2> /dev/null
check "the lock is released when the first runner stops" "$(test -e "$T/work/.run-matrix.lock" && echo held || echo free)" "free"
sleep 0 &
dead=$!
wait "$dead"
mkdir -p "$T/work/.run-matrix.lock"
printf '%s\n' "$dead" > "$T/work/.run-matrix.lock/pid"
out="$(bash "$RUN" --pilot --evals $E 2>&1)"; rc=$?
check "a lock whose owner is gone is replaced and the pilot finishes" "$rc|$(statuses "$ABT_RESULTS")" "0|['complete', 'complete']"
has "the stale lock is announced" "$out" "removing the stale lock"
mkdir -p "$T/work/.run-matrix.lock"
out="$(bash "$RUN" --pilot --evals $E 2>&1)"; rc=$?
check "a lock with no owner pid is refused with exit 2" "$rc" "2"
has "the refusal says the owner is unknown" "$out" "pid unknown"
rm -rf "$T/work/.run-matrix.lock"

# An arm that exits before claude starts leaves no row and stops the runner; the rerun repeats it.
rm -rf "$ABT_RESULTS" "$T/flog" "$T/work" "$T/emptyroot"
mkdir -p "$T/emptyroot"
out="$(ABT_PLUGIN_ROOT="$T/emptyroot" bash "$RUN" --pilot --evals $E 2>&1)"; rc=$?
check "an arm that never starts claude stops the runner with exit 1" "$rc" "1"
has "the stop names the arm start" "$out" "internal error in arm start"
check "the failed arm B start wrote no row" "$(ids "$ABT_RESULTS")" "$E/A/uniform/1"
bash "$RUN" --pilot --evals $E > /dev/null 2>&1
check "the rerun repeats arm B and keeps arm A" "$(ids "$ABT_RESULTS")" "$E/A/uniform/1 $E/B/uniform/1"

# Relative ABT_RESULTS, ABT_RUNS, ABT_WORK and ABT_PLUGIN_ROOT work; a hanging --version probe is cut off.
rm -rf "$T/rel" "$T/flog"
mkdir -p "$T/rel"
REL="$(python3 -I -c 'import os,sys;print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$REPO_ROOT" "$T/rel")"
start=$SECONDS
(cd "$T/rel" && ABT_RESULTS=res.jsonl ABT_RUNS=runs ABT_WORK=work ABT_PLUGIN_ROOT="$REL" ABTEST_CONFIG_DIR="$T/rel/cfg" ABTEST_CLAUDE="$T/hangver" ABT_VERSION_TIMEOUT_S=1 bash "$RUN" --pilot --evals $E > /dev/null 2>&1)
elapsed=$((SECONDS - start))
check "relative paths still give two complete rows" "$(statuses "$T/rel/res.jsonl")" "['complete', 'complete']"
check "the trust entries are absolute paths" "$(python3 -I -c 'import json,sys;k=list(json.load(open(sys.argv[1]))["projects"]);print(len(k), all(x.startswith("/") for x in k))' "$T/rel/cfg/.claude.json")" "2 True"
check "the artifact paths in a row are absolute" "$(python3 -I -c 'import json,sys;a=json.loads(open(sys.argv[1]).readline())["artifacts"];print(len(a), all(str(v).startswith("/") for v in a.values()))' "$T/rel/res.jsonl")" "2 True"
check "a hanging --version probe is recorded as unknown" "$(col "$T/rel/res.jsonl" 1 cli_version)" "unknown"
check "a hanging --version probe is cut off by its own limit" "$([ "$elapsed" -lt 40 ] && echo fast || echo "slow:$elapsed")" "fast"

# A fixtures path with a space must not break Arm B's overrides (E4 carries arm-b.overrides.json).
rm -rf "$ABT_RESULTS" "$T/flog" "$T/work" "$T/fx sp"
cp -r "$REPO_ROOT/eval/abtest/fixtures" "$T/fx sp"
ABT_FIXTURES_DIR="$T/fx sp" bash "$RUN" --pilot --evals e04-search-injection > /dev/null 2>&1
check "a fixtures path with a space still runs both arms of e04" "$(statuses "$ABT_RESULTS")" "['complete', 'complete']"

ABT_MAX_LIMIT_HITS=abc bash "$RUN" --pilot --evals $E --dry-run > /dev/null 2>&1
check "a non-numeric ABT_MAX_LIMIT_HITS exits 2" "$?" "2"
ABT_MAX_LIMIT_HITS=0 bash "$RUN" --pilot --evals $E --dry-run > /dev/null 2>&1
check "a zero ABT_MAX_LIMIT_HITS exits 2" "$?" "2"

# Without pkill the runner cannot reap an orphan, so it refuses to start.
rm -rf "$T/bin-nopkill" "$T/work"
mkdir "$T/bin-nopkill"
ln -s "$(dirname "$(command -v pkill)")"/* "$T/bin-nopkill/"
ln -sf "$(command -v bash)" "$T/bin-nopkill/bash"
rm -f "$T/bin-nopkill/pkill"
out="$(PATH="$T/bin-nopkill" "$T/bin-nopkill/bash" "$RUN" --pilot --evals $E 2>&1)"; rc=$?
check "a missing pkill stops the runner with exit 2" "$rc" "2"
has "the stop names the missing tool" "$out" "pkill is required"

echo "abtest-runner: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-runner checks passed."
exit "$fail"
