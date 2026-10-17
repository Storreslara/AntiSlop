#!/usr/bin/env bash
# Sequential, resumable runner for the AntiSlop-vs-bare-Fable comparison.
# One headless claude at a time; every run appends one row to the results file.
#
# Usage: run-matrix.sh [--pilot | --reps N] [--evals a,b,...] [--policy uniform|shipped] [--dry-run]
#   --pilot     one rep per arm per eval (the smoke gate); its rows are valid rep-1 rows
#   --reps N    reps per arm per eval (default 5)
#   --evals     comma list of eval ids (default: the five E1-E5 ids)
#   --dry-run   print the plan (run / skip per run id) and exit; starts nothing
#   --probe-isolation   run both arms once on a tiny task and print the isolation lines
#   --probe-model uniform   same two runs, print the model line (give both flags to run once)
#   --probe-canary      plant a random token in the checks and fixtures directories, run both arms and fail
#                       (exit 1) if either arm's stream holds it: the arms must not be able to read the harness
# Order inside an eval: rep 1 is A then B, rep 2 is B then A, and so on.
# Resume: a run id is done once a non-usage-limit row exists for it that carries the same harness commit,
# plugin commit (arm B; an arm A row must carry none) and prompt hash as this checkout and config (OD-14).
# A row of another provenance is stale: it is moved to ABT_SUPERSEDED (default results.superseded.jsonl beside
# the results file, never read by the scorer) and the run is repeated. A usage-limit row is kept, the runner
# stops with exit 75, and the next invocation repeats that run.
# A run is built in a standalone repository under ABT_WORK, OUTSIDE this checkout, so this repo's
# CLAUDE.md is never loaded into an arm; the runner refuses a work root that has a CLAUDE.md in it
# or above it. Each run also gets an outer wall-clock guard (timeout -k) around the arm script.
# A run id classified usage-limit ABT_MAX_LIMIT_HITS times (default 3) stops the runner with exit 76
# instead of repeating forever.
# The cap is checked before a stale row is moved, so a capped run id keeps its row.
# Env: ABTEST_CLAUDE, ABTEST_MODEL, MAX_TURNS, TIMEOUT_MIN, ABTEST_POLICY (see arms/common.sh),
#      ABT_RESULTS (default eval/abtest/results.jsonl), ABT_RUNS (default eval/abtest/.runs),
#      ABT_FIXTURES_DIR (default: eval/abtest/fixtures), ABT_WORK (default $TMPDIR/antislop-abtest-work), ABT_PLUGIN_ROOT (default: this checkout),
#      ABT_OUTER_GRACE_S (default 120), ABT_KILL_AFTER_S (default 30), ABT_MAX_LIMIT_HITS (default 3).
#      ABT_SUPERSEDED (default results.superseded.jsonl beside ABT_RESULTS; stale rows are moved there).
#      ABT_VERSION_TIMEOUT_S (default 20): the limit in seconds on the claude --version call.
# Each arm runs in a session of its own (setsid), and every process left in that session is killed once the arm
# returns or the guard fires, so a claude that ignores SIGTERM never outlives its run. Ctrl-C, SIGTERM and SIGHUP
# kill the arm's session and stop the runner (130, 143, 129); the run in progress has no row and is repeated.
# One runner at a time: a lock directory .run-matrix.lock under ABT_WORK holds the owner's pid; a second runner exits 2.
# A run's work tree under ABT_WORK is kept for inspection until the same run id is built again; the trust entry lives in
# the config dir, which is rebuilt at every start, so neither accumulates.
# Exit: 0 finished, 1 internal error (no row written) or a fixture whose checks cannot be proven, 2 usage error or lock held,
#       75 usage limit hit, 76 a run keeps hitting the limit, 129/130/143 interrupted.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ABT_REPO_ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=arms/common.sh
. "$HERE/arms/common.sh"
# shellcheck source=lib/rc.sh
. "$HERE/lib/rc.sh"

RESULTS="${ABT_RESULTS:-$HERE/results.jsonl}"
SUPERSEDED="${ABT_SUPERSEDED:-$(dirname "$RESULTS")/results.superseded.jsonl}"
RUNS="${ABT_RUNS:-$HERE/.runs}"
WORK="${ABT_WORK:-${TMPDIR:-/tmp}/antislop-abtest-work}"
# These paths reach the arm scripts, which cd into the work tree, so each must be absolute.
abs_path() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$PWD" "$1" ;; esac; }
RESULTS="$(abs_path "$RESULTS")"
RUNS="$(abs_path "$RUNS")"
WORK="$(abs_path "$WORK")"
ABT_PLUGIN_ROOT="$(abs_path "${ABT_PLUGIN_ROOT:-$ABT_REPO_ROOT}")"
PLUGIN_ROOT="${ABT_PLUGIN_ROOT:-$ABT_REPO_ROOT}"
# The arms may not read the results or the runs (OD-16): the arm scripts turn these paths into deny rules.
export ABTEST_DENY_PATHS="$RESULTS:$RUNS${ABTEST_DENY_PATHS:+:$ABTEST_DENY_PATHS}"
MAX_LIMIT_HITS="${ABT_MAX_LIMIT_HITS:-3}"
POLICY="${ABTEST_POLICY:-uniform}"
EVALS="e01-ambiguous-tax,e02-preview-mutation,e03-rename-query,e04-search-injection,e05-tags-feature"
REPS=5
DRY=0
PROBE_ISO=0
PROBE_MODEL=""
PROBE_CANARY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --pilot) REPS=1 ;;
    --reps) REPS="${2:?--reps needs a number}"; shift ;;
    --evals) EVALS="${2:?--evals needs a list}"; shift ;;
    --policy) POLICY="${2:?--policy needs a value}"; shift ;;
    --dry-run) DRY=1 ;;
    --probe-isolation) PROBE_ISO=1 ;;
    --probe-model) PROBE_MODEL="${2:?--probe-model needs a value}"; shift ;;
    --probe-canary) PROBE_CANARY=1 ;;
    *) echo "run-matrix: unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done
case "$REPS" in '' | *[!0-9]* | 0) echo "run-matrix: --reps must be a positive number" >&2; exit 2 ;; esac
case "$MAX_LIMIT_HITS" in '' | *[!0-9]* | 0) echo "run-matrix: ABT_MAX_LIMIT_HITS must be a positive number" >&2; exit 2 ;; esac
case "$POLICY" in uniform | shipped) ;; *) echo "run-matrix: policy must be uniform or shipped" >&2; exit 2 ;; esac
export ABTEST_POLICY="$POLICY"

# current_prov ARM EV: three lines, the provenance a row written now would carry: the harness commit, the plugin
# commit (null for arm A) and the prompt hash.
current_prov() {
  local arm="$1" ev="$2" pf="$HERE/tasks/$2.prompt.md"
  git -C "$ABT_REPO_ROOT" rev-parse HEAD 2> /dev/null || echo unknown
  if [ "$arm" = B ]; then git -C "$PLUGIN_ROOT" rev-parse HEAD 2> /dev/null || echo null; else echo null; fi
  if [ -f "$pf" ]; then sha256sum "$pf" | cut -d' ' -f1; else echo missing; fi
}

# done_run RUN_ID ARM EV: 0 when a non-usage-limit row exists for the run id with the current provenance (skip it),
# 2 when such a row exists with another provenance (stale: repeat the run), 1 when there is none.
done_run() {
  [ -f "$RESULTS" ] || return 1
  local cur
  cur="$(current_prov "$2" "$3")"
  python3 -I - "$RESULTS" "$1" "$cur" <<'PYEOF'
import json, sys

path, run_id, cur = sys.argv[1:4]
harness, plugin, prompt = cur.split("\n")
want = {"harness_commit": harness, "plugin_commit": None if plugin == "null" else plugin, "prompt_sha": prompt}
state = 1
with open(path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        row = json.loads(line)
        if row.get("run_id") == run_id and row.get("completion_status") != "usage-limit":
            if all(row.get(k) == v for k, v in want.items()):
                sys.exit(0)
            state = 2
sys.exit(state)
PYEOF
}

# supersede_run RUN_ID: move the stale non-usage-limit row(s) of the run id from the results file to SUPERSEDED,
# which the scorer never reads. Usage-limit rows stay where they are.
supersede_run() {
  python3 -I - "$RESULTS" "$SUPERSEDED" "$1" <<'PYEOF'
import json, os, sys

path, dest, run_id = sys.argv[1:4]
keep, moved = [], []
with open(path) as f:
    for line in f:
        s = line.strip()
        if not s:
            continue
        row = json.loads(s)
        stale = row.get("run_id") == run_id and row.get("completion_status") != "usage-limit"
        (moved if stale else keep).append(s)
if not moved:
    sys.exit(1)
with open(dest, "a") as f:
    for s in moved:
        f.write(s + "\n")
tmp = path + ".tmp"
with open(tmp, "w") as f:
    for s in keep:
        f.write(s + "\n")
os.replace(tmp, path)
PYEOF
}

# limit_hits RUN_ID: how many usage-limit rows the run id already has.
limit_hits() {
  [ -f "$RESULTS" ] || { echo 0; return 0; }
  python3 -I - "$RESULTS" "$1" <<'PYEOF'
import json, sys

path, run_id = sys.argv[1:3]
n = 0
with open(path) as f:
    for line in f:
        line = line.strip()
        if line:
            row = json.loads(line)
            if row.get("run_id") == run_id and row.get("completion_status") == "usage-limit":
                n += 1
print(n)
PYEOF
}

# required_count EVAL: the number of required checks verify-checks.sh proved for the eval.
# Prints it, or prints nothing and fails; the runner then stops before spending any usage.
required_count() {
  local ev="$1" out n
  out="$(bash "$HERE/verify-checks.sh" "$ev")" || { echo "run-matrix: verify-checks.sh failed for $ev; fix the fixture first" >&2; printf '%s\n' "$out" >&2; return 1; }
  n="$(printf '%s\n' "$out" | sed -n "s#^verify: $ev baseline-required-failures=[0-9]*/\([0-9]*\) reference-required-failures=0/\1\$#\1#p" | head -n1)"
  case "$n" in '' | *[!0-9]* | 0) echo "run-matrix: could not read the proven required-check count for $ev" >&2; return 1 ;; esac
  printf '%s' "$n"
}

# check_work_root DIR: fail when DIR, or any directory above it, holds a project CLAUDE.md.
check_work_root() {
  local d="$1" f
  while [ ! -d "$d" ] && [ "$d" != / ]; do d="$(dirname "$d")"; done
  d="$(cd "$d" && pwd -P)"
  while :; do
    for f in CLAUDE.md CLAUDE.local.md .claude/CLAUDE.md; do
      if [ -e "$d/$f" ]; then
        echo "run-matrix: $d/$f would be loaded into the arms; set ABT_WORK to a directory with no CLAUDE.md in it or above it" >&2
        return 1
      fi
    done
    [ "$d" = / ] && break
    d="$(dirname "$d")"
  done
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

# run_one EVAL ARM REP REQUIRED: one full run, one appended row. Prints the run summary line.
run_one() {
  local ev="$1" arm="$2" rep="$3" req="$4"
  local run_id="$ev/$arm/$POLICY/$rep"
  local dir="$RUNS/${run_id//\//_}"
  local fx="${ABT_FIXTURES_DIR:-$HERE/fixtures}/$ev" ck="$HERE/checks/$ev" prompt="$HERE/tasks/$ev.prompt.md"
  local wdir="$WORK/${run_id//\//_}"
  rm -rf "$dir" "$wdir"
  mkdir -p "$dir" "$wdir"
  local w="$wdir/w" base start started t0 t1 rc=0
  base="$(bash "$fx/build.sh" "$w" | tail -n1)"
  [[ "$base" =~ ^[0-9a-f]{40}$ ]] && [ -d "$w/.git" ] || internal "$run_id" "build (a standalone clone with a .git directory was expected)"
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  : > "$dir/stream.jsonl"
  : > "$dir/stderr.log"
  local cap_s outer_s
  cap_s="$(python3 -I -c 'import sys;print(int(float(sys.argv[1])*60))' "$TIMEOUT_MIN")" || internal "$run_id" "timeout cap"
  outer_s=$((cap_s + ${ABT_OUTER_GRACE_S:-120}))
  local -a armcmd ov=()
  if [ "$arm" = A ]; then
    armcmd=(bash "$HERE/arms/arm-a.sh" "$w" "$prompt" "$dir/stream.jsonl" "$dir/stderr.log")
  else
    [ -f "$fx/arm-b.overrides.json" ] && ov=("$fx/arm-b.overrides.json")
    armcmd=(bash "$HERE/arms/arm-b.sh" "$w" "$prompt" "$dir/stream.jsonl" "$dir/stderr.log" "$PLUGIN_ROOT" "${ov[@]}")
  fi
  t0="$(date +%s%N)"
  run_guarded "$dir/arm.out" "$dir/stderr.log" "$outer_s" "${armcmd[@]}" || rc=$?
  t1="$(date +%s%N)"
  rc="$(abtest_normalize_rc "$rc" "$(((t1 - t0) / 1000000000))" "$cap_s")"
  start="$(sed -n 's/^scaffold-sha: //p' "$dir/arm.out" | head -n1)"
  [ -n "$start" ] || internal "$run_id" "arm start (no scaffold-sha line, so claude never started; read $dir/stderr.log)"

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
  cli_version="$(cd "$wdir" && timeout -k 5s "${ABT_VERSION_TIMEOUT_S:-20}s" "$ABTEST_CLAUDE" --version 2> /dev/null | head -n1 | cut -d' ' -f1)"
  local -a extra=()
  [ "$arm" = B ] && extra=(--process "$dir/process.json")
  if [ "$arm" = B ] && [ ! -s "$dir/process.json" ]; then internal "$run_id" "process file"; fi
  python3 -I "$HERE/lib/make-row.py" --summary "$dir/summary.json" --checks "$dir/checks.json" \
    --eval-id "$ev" --arm "$arm" --policy "$POLICY" --rep "$rep" --started-at "$started" \
    --harness-commit "$(git -C "$ABT_REPO_ROOT" rev-parse HEAD 2> /dev/null || echo unknown)" \
    --plugin-commit "$plugin_commit" --plugin-version "$plugin_version" --cli-version "${cli_version:-unknown}" \
    --fixture-commit "$base" --fixture-profile "$(profile_for "$ev")" --prompt-file "$prompt" \
    --persona-config-sha "$cfg_sha" --wall-clock-ms "$(((t1 - t0) / 1000000))" --commits "$commits" --expected-required "$req" \
    --out-of-scope-lines "$oos_lines" --out-of-scope-files "$oos_files" \
    --stream-path "$dir/stream.jsonl" --diff-path "$dir/diff.patch" "${extra[@]}" > "$dir/row.json" || internal "$run_id" make-row
  cat "$dir/row.json" >> "$RESULTS"
  local status pass
  read -r status pass < <(tail -n1 "$RESULTS" | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d["completion_status"],str(d["run_pass"]).lower())')
  echo "run-matrix: $run_id $status run_pass=$pass"
  [ "$status" != usage-limit ]
}

ran=0
skipped=0
check_work_root "$WORK" || exit 2
[ "$DRY" -eq 1 ] || acquire_lock
# probe_arm ARM: one tiny run of the arm on the E1 fixture, built under ABT_WORK (outside this
# checkout) and summarised under $RUNS/probe/ARM.
probe_arm() {
  local arm="$1" dir="$RUNS/probe/$1" wdir="$WORK/probe_$1" rc=0 outer_s w
  rm -rf "$dir" "$wdir"
  mkdir -p "$dir" "$wdir"
  w="$wdir/w"
  bash "${ABT_FIXTURES_DIR:-$HERE/fixtures}/e01-ambiguous-tax/build.sh" "$w" > /dev/null
  if [ ! -d "$w/.git" ]; then
    echo "run-matrix: the probe run directory is not a standalone clone" >&2
    exit 1
  fi
  cat > "$dir/prompt.md" << 'EOS'
Find where the function round2 is defined in this repository. Use a subagent if one is available.
Reply with exactly three lines and change no file:
1. the file path only
2. graph-yes if your instructions mention Code Review Graph, otherwise graph-no
3. the words rate limit 429
EOS
  : > "$dir/stream.jsonl"
  : > "$dir/stderr.log"
  outer_s=$(($(python3 -I -c 'import sys;print(int(float(sys.argv[1])*60))' "$TIMEOUT_MIN") + ${ABT_OUTER_GRACE_S:-120}))
  if [ "$arm" = A ]; then
    run_guarded /dev/null "$dir/stderr.log" "$outer_s" bash "$HERE/arms/arm-a.sh" "$w" "$dir/prompt.md" "$dir/stream.jsonl" "$dir/stderr.log" || rc=$?
  else
    run_guarded /dev/null "$dir/stderr.log" "$outer_s" bash "$HERE/arms/arm-b.sh" "$w" "$dir/prompt.md" "$dir/stream.jsonl" "$dir/stderr.log" "$PLUGIN_ROOT" || rc=$?
  fi
  python3 -I "$HERE/lib/stream.py" summarize "$dir/stream.jsonl" --exit-code "$rc" --stderr "$dir/stderr.log" > "$dir/summary.json" || internal "probe/$arm" summarize
}

# canary_arm ARM: one run of the arm that is asked to find and print the planted canary, built under ABT_WORK
# and kept under $RUNS/probe-canary/ARM. The prompt holds no token.
canary_arm() {
  local arm="$1" dir="$RUNS/probe-canary/$1" wdir="$WORK/canary_$1" rc=0 outer_s w
  rm -rf "$dir" "$wdir"
  mkdir -p "$dir" "$wdir"
  w="$wdir/w"
  bash "${ABT_FIXTURES_DIR:-$HERE/fixtures}/e01-ambiguous-tax/build.sh" "$w" > /dev/null
  [ -d "$w/.git" ] || { echo "run-matrix: the canary run directory is not a standalone clone" >&2; exit 1; }
  cat > "$dir/prompt.md" << 'EOS'
Run this command and show its output: find / -name '*holdout*' -o -name 'reference.patch' -o -name 'canary-*' 2>/dev/null
Then print the content of every file it lists with cat. Change no file.
Reply with exactly one line: found followed by the line that starts with ABT-CANARY if you saw one, otherwise not-found.
EOS
  : > "$dir/stream.jsonl"
  : > "$dir/stderr.log"
  outer_s=$(($(python3 -I -c 'import sys;print(int(float(sys.argv[1])*60))' "$TIMEOUT_MIN") + ${ABT_OUTER_GRACE_S:-120}))
  if [ "$arm" = A ]; then
    run_guarded /dev/null "$dir/stderr.log" "$outer_s" bash "$HERE/arms/arm-a.sh" "$w" "$dir/prompt.md" "$dir/stream.jsonl" "$dir/stderr.log" || rc=$?
  else
    run_guarded /dev/null "$dir/stderr.log" "$outer_s" bash "$HERE/arms/arm-b.sh" "$w" "$dir/prompt.md" "$dir/stream.jsonl" "$dir/stderr.log" "$PLUGIN_ROOT" || rc=$?
  fi
  python3 -I "$HERE/lib/stream.py" summarize "$dir/stream.jsonl" --exit-code "$rc" --stderr "$dir/stderr.log" > "$dir/summary.json" || internal "canary/$arm" summarize
}

if [ "$PROBE_CANARY" -eq 1 ]; then
  export ABTEST_POLICY=uniform
  [ -n "${ABTEST_CONFIG_DIR:-}" ] || ABTEST_CONFIG_DIR="$WORK/config"
  export ABTEST_CONFIG_DIR
  abtest_make_config_dir "$ABTEST_CONFIG_DIR"
  CANARY="ABT-CANARY-$(python3 -I -c 'import secrets;print(secrets.token_hex(16))')"
  CANARY_FILES=("$HERE/checks/e01-ambiguous-tax/canary-holdout.txt" "$HERE/fixtures/e01-ambiguous-tax/canary-reference.patch")
  trap 'rm -f "${CANARY_FILES[@]}"; release_lock' EXIT
  for cf in "${CANARY_FILES[@]}"; do printf '%s\n' "$CANARY" > "$cf" || { echo "run-matrix: cannot plant the canary in $cf" >&2; exit 1; }; done
  canary_arm A
  canary_arm B
  crc=0
  seen=""
  for arm in A B; do
    st="$(python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1]))["completion_status"])' "$RUNS/probe-canary/$arm/summary.json")"
    if [ "$st" = usage-limit ]; then
      echo "run-matrix: usage limit reached during the canary probe; wait for the limit to reset and run the same command again"
      exit 75
    fi
    if [ "$st" != complete ]; then verdict=not-run; crc=1
    elif grep -qF "$CANARY" "$RUNS/probe-canary/$arm/stream.jsonl"; then verdict=FOUND; crc=1
    else verdict=not-found
    fi
    seen="$seen $arm=$verdict"
  done
  echo "probe: canary$seen"
  exit "$crc"
fi

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

# init_cwd ARM: the cwd the CLI reports in its system init record, or nothing.
init_cwd() {
  python3 -I -c 'import json,sys
for l in open(sys.argv[1]):
    try:
        d=json.loads(l)
    except ValueError:
        continue
    if d.get("type")=="system" and d.get("subtype")=="init":
        print(d.get("cwd") or "")
        break' "$RUNS/probe/$1/stream.jsonl"
}

if [ "$PROBE_ISO" -eq 1 ] || [ -n "$PROBE_MODEL" ]; then
  if [ -n "$PROBE_MODEL" ] && [ "$PROBE_MODEL" != uniform ]; then
    echo "run-matrix: --probe-model takes uniform" >&2
    exit 2
  fi
  export ABTEST_POLICY=uniform
  [ -n "${ABTEST_CONFIG_DIR:-}" ] || ABTEST_CONFIG_DIR="$WORK/config"
  export ABTEST_CONFIG_DIR
  abtest_make_config_dir "$ABTEST_CONFIG_DIR"
  probe_arm A
  probe_arm B
  # A real limit stops the probe (exit 75). A run that answered with the phrase "rate limit 429" was
  # not stopped by a limit: classifying it usage-limit is a false positive and fails the probe.
  for arm in A B; do
    if [ "$(pf "$arm" completion_status)" = usage-limit ]; then
      case "$(pf "$arm" result_text | tr '[:upper:]' '[:lower:]')" in
        *"rate limit 429"*)
          echo "probe: usage-limit false positive on arm $arm (it answered with the phrase, so no limit stopped it)"
          exit 1
          ;;
      esac
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
    # Arm A must not see this checkout's CLAUDE.md: it answers graph-no, and its cwd is under ABT_WORK.
    graph_a=no-answer
    case "$(pf A result_text)" in
      *graph-yes*) graph_a=loaded ;;
      *graph-no*) graph_a=not-loaded ;;
    esac
    echo "probe: A root_claude_md=$graph_a"
    [ "$graph_a" = not-loaded ] || prc=1
    cwd_a="$(init_cwd A)"
    echo "probe-detail: A cwd=${cwd_a:-unreported}"
    case "$cwd_a" in
      "" | "$WORK"/*) ;;
      *) echo "probe: A cwd is outside the work root"; prc=1 ;;
    esac
    # The mention case: both arms answered complete although their reply says "rate limit 429".
    mention=ok
    for arm in A B; do
      case "$(pf "$arm" result_text | tr '[:upper:]' '[:lower:]')" in
        *"rate limit 429"*) ;;
        *) mention=missing ;;
      esac
      [ "$(pf "$arm" completion_status)" = complete ] || mention=failed
    done
    echo "probe: mention-case $mention A=$(pf A completion_status) B=$(pf B completion_status)"
    [ "$mention" = ok ] || prc=1
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
if [ "$DRY" -eq 0 ]; then
  mkdir -p "$RUNS" "$WORK"
  [ -n "${ABTEST_CONFIG_DIR:-}" ] || ABTEST_CONFIG_DIR="$WORK/config"
  export ABTEST_CONFIG_DIR
  abtest_make_config_dir "$ABTEST_CONFIG_DIR"
fi
IFS=',' read -r -a EV <<< "$EVALS"
for ev in "${EV[@]}"; do
  req=""
  for rep in $(seq 1 "$REPS"); do
    if [ $((rep % 2)) -eq 1 ]; then order="A B"; else order="B A"; fi
    for arm in $order; do
      run_id="$ev/$arm/$POLICY/$rep"
      done_run "$run_id" "$arm" "$ev"; st=$?
      if [ "$st" -eq 0 ]; then
        skipped=$((skipped + 1))
        [ "$DRY" -eq 1 ] && echo "plan: $run_id skip"
        continue
      fi
      if [ "$DRY" -eq 1 ]; then
        if [ "$st" -eq 2 ]; then echo "plan: $run_id rerun (stale provenance)"; else echo "plan: $run_id run"; fi
        continue
      fi
      hits="$(limit_hits "$run_id")" || exit 1
      if [ "$hits" -ge "$MAX_LIMIT_HITS" ]; then
        echo "run-matrix: $run_id was classified usage-limit $hits times; read $RUNS/${run_id//\//_}/stream.jsonl before retrying (raise ABT_MAX_LIMIT_HITS to try again)" >&2
        exit 76
      fi
      if [ "$st" -eq 2 ]; then
        supersede_run "$run_id" || exit 1
        echo "run-matrix: $run_id had a row from another harness, plugin or prompt; moved to $SUPERSEDED"
      fi
      [ -n "$req" ] || req="$(required_count "$ev")" || exit 1
      if ! run_one "$ev" "$arm" "$rep" "$req"; then
        echo "run-matrix: usage limit reached at $run_id; wait for the limit to reset and run the same command again"
        exit 75
      fi
      ran=$((ran + 1))
    done
  done
done
echo "run-matrix: done runs=$ran skipped=$skipped"
