Unit: abt-u12

## Objective
run-matrix.sh runs every arm in a session of its own and kills what is left in it when the arm returns, when the outer guard fires and on INT, TERM and HUP (exit 130, 143, 129), so no claude outlives its run and Ctrl-C stops the runner; an arm that prints no scaffold-sha stops the runner with exit 1 and no row; the e04 override path is quoted; ABT_MAX_LIMIT_HITS must be a positive number; the --version probe is bounded; RESULTS, RUNS, WORK and the plugin root are absolute; a lock directory under ABT_WORK refuses a second runner; tests/abtest-runner.test.sh goes from 32 to 64 rows. One commit.

## Retrieval
GitHub issues: `gh issue view 581 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/run-matrix.sh` (anchor: line matching `# internal RUN_ID STEP: a harness step failed; stop without writing a row.`)
- `tests/abtest-runner.test.sh` (anchor: line matching `check "zero reps exits 2" "$?" "2"`)

## Ordered edits
1. command: `test "$(grep -c '^    timeout -k' eval/abtest/run-matrix.sh)" = 2 && test "$(grep -cF '[ -n "$start" ] || start="$base"' eval/abtest/run-matrix.sh)" = 1 && test "$(grep -cF 'check_work_root "$WORK" || exit 2' eval/abtest/run-matrix.sh)" = 1 && test "$(grep -cF 'check "zero reps exits 2" "$?" "2"' tests/abtest-runner.test.sh)" = 1 && ! grep -q run_guarded eval/abtest/run-matrix.sh && ! grep -q hardening tests/abtest-runner.test.sh && ! grep -q current_prov eval/abtest/run-matrix.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `# Exit: 0 finished, 75 usage limit hit`
   indent: 0
   before:
~~~~
# Exit: 0 finished, 75 usage limit hit, 76 a run keeps hitting the limit, 2 usage error.
~~~~
   after:
~~~~
#      ABT_VERSION_TIMEOUT_S (default 20): the limit in seconds on the claude --version call.
# Each arm runs in a session of its own (setsid), and every process left in that session is killed once the arm
# returns or the guard fires, so a claude that ignores SIGTERM never outlives its run. Ctrl-C, SIGTERM and SIGHUP
# kill the arm's session and stop the runner (130, 143, 129); the run in progress has no row and is repeated.
# One runner at a time: a lock directory .run-matrix.lock under ABT_WORK holds the owner's pid; a second runner exits 2.
# A run's work tree under ABT_WORK is kept for inspection until the same run id is built again; the trust entry lives in
# the config dir, which is rebuilt at every start, so neither accumulates.
# Exit: 0 finished, 1 internal error (no row written) or a fixture whose checks cannot be proven, 2 usage error or lock held,
#       75 usage limit hit, 76 a run keeps hitting the limit, 129/130/143 interrupted.
~~~~
3. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `WORK="${ABT_WORK:-${TMPDIR:-/tmp}/antislop-abtest-work}"`
   indent: 0
   insert-after:
~~~~
# These paths reach the arm scripts, which cd into the work tree, so each must be absolute.
abs_path() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$PWD" "$1" ;; esac; }
RESULTS="$(abs_path "$RESULTS")"
RUNS="$(abs_path "$RUNS")"
WORK="$(abs_path "$WORK")"
ABT_PLUGIN_ROOT="$(abs_path "${ABT_PLUGIN_ROOT:-$ABT_REPO_ROOT}")"
~~~~
4. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `case "$REPS" in`
   indent: 0
   insert-after:
~~~~
case "$MAX_LIMIT_HITS" in '' | *[!0-9]* | 0) echo "run-matrix: ABT_MAX_LIMIT_HITS must be a positive number" >&2; exit 2 ;; esac
~~~~
5. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `internal error in $2 for $1; no row written`
   indent: 0
   before:
~~~~
  echo "run-matrix: internal error in $2 for $1; no row written" >&2
  exit 1
}
~~~~
   after:
~~~~
  echo "run-matrix: internal error in $2 for $1; no row written" >&2
  exit 1
}

# One session per arm. ARM_SID is the session id (the pid of the setsid process) while an arm runs.
ARM_SID=""
LOCK_DIR=""

# reap_arm: kill every process still in the arm's session (an orphaned inner timeout or claude, for example).
reap_arm() {
  if [ -n "$ARM_SID" ]; then pkill -KILL -s "$ARM_SID" 2> /dev/null; fi
  ARM_SID=""
  return 0
}

# run_guarded OUT ERR OUTER_S CMD...: run CMD in a session of its own under the outer timeout -k, stdout to OUT, stderr
# appended to ERR; then kill what is left in the session. Returns the exit code of the timeout.
run_guarded() {
  local out="$1" err="$2" outer="$3" grc=0
  shift 3
  setsid -w timeout -k "${ABT_KILL_AFTER_S:-30}s" "${outer}s" "$@" > "$out" 2>> "$err" &
  ARM_SID=$!
  wait "$ARM_SID" || grc=$?
  reap_arm
  return "$grc"
}

# release_lock: remove the lock directory this runner took.
release_lock() {
  if [ -n "$LOCK_DIR" ]; then rm -rf "$LOCK_DIR"; fi
  LOCK_DIR=""
  return 0
}

# acquire_lock: refuse to start without setsid and pkill (they keep a claude from outliving its run), then take the
# lock: one runner at a time (a second one would rebuild the config dir under a live claude). The lock is a directory
# under ABT_WORK holding the owner's pid; a lock whose owner is gone is stale and is replaced.
acquire_lock() {
  local lock="$WORK/.run-matrix.lock" owner t
  for t in setsid pkill; do
    command -v "$t" > /dev/null 2>&1 || { echo "run-matrix: $t is required to keep a claude from outliving its run" >&2; exit 2; }
  done
  mkdir -p "$WORK"
  if ! mkdir "$lock" 2> /dev/null; then
    owner="$(cat "$lock/pid" 2> /dev/null || true)"
    if [ -z "$owner" ] || kill -0 "$owner" 2> /dev/null; then
      echo "run-matrix: another runner (pid ${owner:-unknown}) holds $lock; wait for it, or remove that directory if no runner is running" >&2
      exit 2
    fi
    echo "run-matrix: removing the stale lock $lock (pid $owner is gone)" >&2
    rm -rf "$lock"
    mkdir "$lock" 2> /dev/null || { echo "run-matrix: could not take $lock" >&2; exit 2; }
  fi
  LOCK_DIR="$lock"
  printf '%s\n' "$$" > "$lock/pid"
}

# on_signal NAME CODE: an interrupt stops the runner; the arm's session dies with it and the run has no row.
on_signal() {
  reap_arm
  echo "run-matrix: interrupted by $1; the run in progress has no row and is repeated by the next invocation" >&2
  exit "$2"
}
trap 'on_signal INT 130' INT
trap 'on_signal TERM 143' TERM
trap 'on_signal HUP 129' HUP
trap release_lock EXIT
~~~~
6. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `    local ov=""`
   indent: 0
   before:
~~~~
  t0="$(date +%s%N)"
  if [ "$arm" = A ]; then
    timeout -k "${ABT_KILL_AFTER_S:-30}s" "${outer_s}s" bash "$HERE/arms/arm-a.sh" "$w" "$prompt" "$dir/stream.jsonl" "$dir/stderr.log" > "$dir/arm.out" 2>> "$dir/stderr.log" || rc=$?
  else
    local ov=""
    [ -f "$fx/arm-b.overrides.json" ] && ov="$fx/arm-b.overrides.json"
    timeout -k "${ABT_KILL_AFTER_S:-30}s" "${outer_s}s" bash "$HERE/arms/arm-b.sh" "$w" "$prompt" "$dir/stream.jsonl" "$dir/stderr.log" "$PLUGIN_ROOT" $ov > "$dir/arm.out" 2>> "$dir/stderr.log" || rc=$?
  fi
~~~~
   after:
~~~~
  local -a armcmd ov=()
  if [ "$arm" = A ]; then
    armcmd=(bash "$HERE/arms/arm-a.sh" "$w" "$prompt" "$dir/stream.jsonl" "$dir/stderr.log")
  else
    [ -f "$fx/arm-b.overrides.json" ] && ov=("$fx/arm-b.overrides.json")
    armcmd=(bash "$HERE/arms/arm-b.sh" "$w" "$prompt" "$dir/stream.jsonl" "$dir/stderr.log" "$PLUGIN_ROOT" "${ov[@]}")
  fi
  t0="$(date +%s%N)"
  run_guarded "$dir/arm.out" "$dir/stderr.log" "$outer_s" "${armcmd[@]}" || rc=$?
~~~~
7. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `[ -n "$start" ] || start="$base"`
   before: `  [ -n "$start" ] || start="$base"`
   after: `  [ -n "$start" ] || internal "$run_id" "arm start (no scaffold-sha line, so claude never started; read $dir/stderr.log)"`
8. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `cli_version="$(cd "$wdir" && "$ABTEST_CLAUDE" --version`
   before: `  cli_version="$(cd "$wdir" && "$ABTEST_CLAUDE" --version 2> /dev/null | head -n1 | cut -d' ' -f1)"`
   after: `  cli_version="$(cd "$wdir" && timeout -k 5s "${ABT_VERSION_TIMEOUT_S:-20}s" "$ABTEST_CLAUDE" --version 2> /dev/null | head -n1 | cut -d' ' -f1)"`
9. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `check_work_root "$WORK" || exit 2`
   indent: 0
   insert-after:
~~~~
[ "$DRY" -eq 1 ] || acquire_lock
~~~~
10. file: `tests/abtest-runner.test.sh`
   anchor: line matching `trap 'rm -rf "$T"' EXIT`
   before: `trap 'rm -rf "$T"' EXIT`
   after: `trap 'pkill -KILL -f "$T/(wrap|fake-copy|hangver|stubborn)" 2> /dev/null; rm -rf "$T"' EXIT`
11. file: `tests/abtest-runner.test.sh`
   anchor: line matching `check "zero reps exits 2" "$?" "2"`
   indent: 0
   insert-after:
~~~~

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
sigrun() {
  python3 -I - "$1" "$T/flog" "$RUN" "$E" << 'PYEOF'
import os, signal, subprocess, sys, time

name, flog, run, ev = sys.argv[1:5]
p = subprocess.Popen(["bash", run, "--pilot", "--evals", ev], start_new_session=True,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
end = time.time() + 20
while not os.path.exists(os.path.join(flog, "argv.1")) and time.time() < end:
    time.sleep(0.1)
os.killpg(p.pid, getattr(signal, "SIG" + name))
try:
    print(p.wait(timeout=15))
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
~~~~
12. file: `tests/abtest-runner.test.sh`
   anchor: line matching `wait "$dead"`
   indent: 0
   insert-after:
~~~~
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
~~~~
13. command: `git add eval/abtest/run-matrix.sh tests/abtest-runner.test.sh && git commit -m "fix(abt-u12): the runner kills a claude that ignores SIGTERM, stops on Ctrl-C, takes a lock and writes no row for an arm that never started (#581)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/arms/` (the arm scripts and common.sh are units abt-u01 and abt-u01b; the guard wraps them instead of editing them)
- `eval/abtest/lib/` (rc.sh, stream.py and make-row.py are other units; this fix only calls them)
- `eval/abtest/checks/`, `eval/abtest/fixtures/`, `eval/abtest/verify-checks.sh`, `eval/abtest/templates/` (other units own them)
- `tests/fixtures/abtest/` (the fake claude and canned streams belong to earlier units; the wrapper stubs are written by the test into its temp directory)
- `eval/harness/`, `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-runner.test.sh`
   exit: 0
   stdout: `All abtest-runner checks passed.`
   mutation: skip edit 6 (the arm launch); the process-group, interrupt and space-path rows FAIL, the script exits non-zero and the fragment is absent.
2. run: `bash tests/abtest-runner.test.sh | grep -c '^ok'`
   exit: 0
   stdout: `64`
   mutation: skip edit 12 (the last test chunk); its rows are gone and the count drops.
3. run: `bash tests/abtest-runner.test.sh | grep -c '^ok   the failed arm B start wrote no row'`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; a missing scaffold-sha again falls back to the baseline and writes an error row, so the row FAILs (stdout 0, exit 1).
4. run: `bash tests/abtest-runner.test.sh | grep -c '^ok   no claude process is alive when the runner returns\|^ok   no late edit appears in a work tree'`
   exit: 0
   stdout: `2`
   mutation: skip edit 6; the old plain timeout orphans the inner timeout and claude, so both rows FAIL (stdout 0, exit 1).
5. run: `bash tests/abtest-runner.test.sh | grep -c '^ok   SIG[A-Z]* stops the runner with exit\|^ok   after SIG[A-Z]* no row, no claude and no lock remain'`
   exit: 0
   stdout: `6`
   mutation: skip edit 6; the runner ignores the signals while an arm runs, so every row FAILs (stdout 0, exit 1).
6. run: `bash tests/abtest-runner.test.sh | grep -c '^ok   a fixtures path with a space still runs both arms of e04'`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; the unquoted override path is split again, arm B errors and the row FAILs (stdout 0, exit 1).
7. run: `bash tests/abtest-runner.test.sh | grep -c '^ok   a second runner started while one runs exits 2\|^ok   the lock is released when the first runner stops\|^ok   a lock whose owner is gone is replaced\|^ok   a lock with no owner pid is refused\|^ok   a missing pkill stops the runner'`
   exit: 0
   stdout: `5`
   mutation: skip edit 9 (the lock call); two runners run at once and no tool check happens, so the rows FAIL (stdout 0, exit 1).
8. run: `bash tests/abtest-runner.test.sh | grep -c '^ok   a non-numeric ABT_MAX_LIMIT_HITS exits 2\|^ok   a zero ABT_MAX_LIMIT_HITS exits 2'`
   exit: 0
   stdout: `2`
   mutation: skip edit 4; the cap is silently disabled, exit stays 0 and the rows FAIL (stdout 0, exit 1).
9. run: `bash tests/abtest-runner.test.sh | grep -c '^ok   a hanging --version probe is cut off by its own limit'`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; the probe waits for the hanging stub (about 60 seconds per arm) and the row FAILs (stdout 0, exit 1).
10. run: `bash tests/abtest-runner.test.sh | grep -c '^ok   relative paths still give two complete rows\|^ok   the trust entries are absolute paths\|^ok   the artifact paths in a row are absolute'`
   exit: 0
   stdout: `3`
   mutation: skip edit 3; a relative plugin root breaks arm B and relative trust and artifact paths are written, so the rows FAIL (stdout 0, exit 1).
11. run: `grep -c '^# Exit: 0 finished, 1 internal error\|^# A run.s work tree under ABT_WORK is kept for inspection' eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `2`
   mutation: skip edit 2; the old header is back, stdout 0 and the exit is 1.
12. run: `grep -c '^    timeout -k' eval/abtest/run-matrix.sh`
   exit: 1
   stdout: `0`
   mutation: skip edit 6; the two plain timeout lines are back, stdout 2 and the exit is 0.
13. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u12\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/run-matrix.sh tests/abtest-runner.test.sh`
   mutation: skip edit 13 (the commit); the newest abt-u12 commit is the original and the list also names eval/abtest/lib/rc.sh.
14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u12\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -cE "^(fix\(abt-u12\): the runner kills a claude that ignores SIGTERM|Co-Authored-By: Claude .* <noreply@anthropic.com>$)"`
   exit: 0
   stdout: `2`
   mutation: skip edit 13; the newest abt-u12 commit is the original (subject feat(...)), so only the trailer line matches and stdout is 1.
15. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u12\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/run-matrix.sh tests/abtest-runner.test.sh | grep -vcE "^[a-z]+\(abt-u12\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
16. run: `git status --porcelain -- eval/abtest/run-matrix.sh tests/abtest-runner.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 13; the two modified files are listed.
17. run: `bash tests/abtest-runner.test.sh > /dev/null 2>&1; git status --porcelain --untracked-files=all | wc -l | tr -d ' '`
   exit: 0
   stdout: `0`
   precondition: run after the commit with the working tree clean before the command.
   mutation: in run-matrix.sh remove `cd "$wdir" && ` from the cli_version line; the version call then runs in the checkout, the dirty-tree row has the fake claude create stray.txt there, which is listed as untracked, and the count is 2.
   proof: scratch run in a git clone (eval/ is export-ignored, so never git archive): with the cd removed the suite exited 0 and left stray.txt, so git status listed 2 lines (the modified run-matrix.sh and stray.txt); with the cd present the count was 0.

## Pre-resolved context
tdd: yes tests/abtest-runner.test.sh (criteria 1 to 11 are red-then-green: the new rows FAIL at HEAD)
blast-radius: eval/abtest/run-matrix.sh:155 eval/abtest/run-matrix.sh:159 eval/abtest/run-matrix.sh:163 tests/abtest-runner.test.sh:7
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part. The before payloads are exact copies of the committed text: copy, do not retype.
fix-of: 2026-10-17T14:47:30Z
why: the review FAIL showed paid runs going wrong: an arm that exits before claude starts became a permanent error row; a claude that ignores SIGTERM lived on after its row was written (the outer timeout and the inner timeout of arms/common.sh sit in different process groups) and Ctrl-C never reached the arm. Each arm now runs in a session of its own (setsid -w timeout -k) and every process left in that session is killed with pkill -KILL -s when the arm returns, when the guard fires and on INT, TERM and HUP (exit 130, 143, 129). The roast items are folded in: the e04 override path is quoted, ABT_MAX_LIMIT_HITS and the version probe are validated or bounded, RESULTS, RUNS, WORK and the plugin root are made absolute, and a lock directory under ABT_WORK keeps two runners apart.
chain: this fix lands after abt-u12 and before abt-u12b, abt-u01b, abt-u12c, abt-u13 and abt-u13b, and the whole chain was replayed in a clone (runner suite 64, then 95 after abt-u12b, then 122 after abt-u12c; probe suite 70; arms suite 69). Those contracts were amended in the same round: abt-u12b counts 95 rows, adds a row that no stub process survives the guard and now expects 4 claude calls under ABT_WORK (two arms and two version calls; the old expected 2 already failed at HEAD); abt-u12c counts 122 rows; abt-u13 and abt-u13b run their arms through run_guarded instead of copying the timeout lines, abt-u13b releases the lock in its exit trap, and abt-u13 anchors its probe block on the acquire_lock line.
config-dir: the default ABTEST_CONFIG_DIR (the runs directory) is not touched here; abt-u12c moves it to ABT_WORK/config and abt-u01b refuses a config dir inside the harness, so nothing is duplicated.
kept-trees: work trees under ABT_WORK are kept for inspection (the abt-u12b rows read them) and the trust entry sits in the config dir, which every start rebuilds; the header documents this as a limitation instead of adding a cleanup.
stdin: an arm now starts as a background job, so its stdin is /dev/null instead of the terminal; both arms are equal.
not-claimed: the RESULTS line of the absolute-path block has no row (its effect shows only in the abt-u12c deny rules); a per-run HOME or plugin copy that abt-u01b makes is not removed when the guard KILLs an arm.
already-green: criterion 15 (the untagged-tail count) and criterion 16 (the scoped clean-tree check) pass at HEAD by design and turn red only when a later commit is untagged or the commit step is skipped.
no-real-claude: nothing here runs the real claude CLI; the test sets ABTEST_CLAUDE to a fake or a wrapper and HOME to a temp directory. The suite takes about 80 seconds.
gate-names: run-matrix.sh builds the persona-config, audit and marker directory names from two parts on purpose; keep it that way and apply every edit with the Write or Edit tool.
commit-message: fix(abt-u12): the runner kills a claude that ignores SIGTERM, stops on Ctrl-C, takes a lock and writes no row for an arm that never started (#581)
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
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
criterion 15: <FILL: exit and stdout>
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
