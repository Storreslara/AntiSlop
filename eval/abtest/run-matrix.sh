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
# A run is built in a standalone repository under ABT_WORK, OUTSIDE this checkout, so this repo's
# CLAUDE.md is never loaded into an arm; the runner refuses a work root that has a CLAUDE.md in it
# or above it. Each run also gets an outer wall-clock guard (timeout -k) around the arm script.
# A run id classified usage-limit ABT_MAX_LIMIT_HITS times (default 3) stops the runner with exit 76
# instead of repeating forever.
# Env: ABTEST_CLAUDE, ABTEST_MODEL, MAX_TURNS, TIMEOUT_MIN, ABTEST_POLICY (see arms/common.sh),
#      ABT_RESULTS (default eval/abtest/results.jsonl), ABT_RUNS (default eval/abtest/.runs),
#      ABT_FIXTURES_DIR (default: eval/abtest/fixtures), ABT_WORK (default $TMPDIR/antislop-abtest-work), ABT_PLUGIN_ROOT (default: this checkout),
#      ABT_OUTER_GRACE_S (default 120), ABT_KILL_AFTER_S (default 30), ABT_MAX_LIMIT_HITS (default 3).
# Exit: 0 finished, 75 usage limit hit, 76 a run keeps hitting the limit, 2 usage error.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ABT_REPO_ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=arms/common.sh
. "$HERE/arms/common.sh"
# shellcheck source=lib/rc.sh
. "$HERE/lib/rc.sh"

RESULTS="${ABT_RESULTS:-$HERE/results.jsonl}"
RUNS="${ABT_RUNS:-$HERE/.runs}"
WORK="${ABT_WORK:-${TMPDIR:-/tmp}/antislop-abtest-work}"
PLUGIN_ROOT="${ABT_PLUGIN_ROOT:-$ABT_REPO_ROOT}"
MAX_LIMIT_HITS="${ABT_MAX_LIMIT_HITS:-3}"
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
  t0="$(date +%s%N)"
  if [ "$arm" = A ]; then
    timeout -k "${ABT_KILL_AFTER_S:-30}s" "${outer_s}s" bash "$HERE/arms/arm-a.sh" "$w" "$prompt" "$dir/stream.jsonl" "$dir/stderr.log" > "$dir/arm.out" 2>> "$dir/stderr.log" || rc=$?
  else
    local ov=""
    [ -f "$fx/arm-b.overrides.json" ] && ov="$fx/arm-b.overrides.json"
    timeout -k "${ABT_KILL_AFTER_S:-30}s" "${outer_s}s" bash "$HERE/arms/arm-b.sh" "$w" "$prompt" "$dir/stream.jsonl" "$dir/stderr.log" "$PLUGIN_ROOT" $ov > "$dir/arm.out" 2>> "$dir/stderr.log" || rc=$?
  fi
  t1="$(date +%s%N)"
  rc="$(abtest_normalize_rc "$rc" "$(((t1 - t0) / 1000000000))" "$cap_s")"
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
  cli_version="$(cd "$wdir" && "$ABTEST_CLAUDE" --version 2> /dev/null | head -n1 | cut -d' ' -f1)"
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
if [ "$DRY" -eq 0 ]; then
  mkdir -p "$RUNS" "$WORK"
  [ -n "${ABTEST_CONFIG_DIR:-}" ] || ABTEST_CONFIG_DIR="$RUNS/config"
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
      if done_run "$run_id"; then
        skipped=$((skipped + 1))
        [ "$DRY" -eq 1 ] && echo "plan: $run_id skip"
        continue
      fi
      if [ "$DRY" -eq 1 ]; then echo "plan: $run_id run"; continue; fi
      hits="$(limit_hits "$run_id")" || exit 1
      if [ "$hits" -ge "$MAX_LIMIT_HITS" ]; then
        echo "run-matrix: $run_id was classified usage-limit $hits times; read $RUNS/${run_id//\//_}/stream.jsonl before retrying (raise ABT_MAX_LIMIT_HITS to try again)" >&2
        exit 76
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
