#!/usr/bin/env bash
# Drives one headless pilot run against an already-scaffolded (and
# optionally variant-patched) fixture, scores it, and appends one row to
# eval/results.jsonl.
#
# Usage: run.sh DEST TASK_NAME VARIANT REP PROJECT_NAME [MAX_BUDGET_USD] [MODEL]
#   DEST            scaffolded fixture dir (see scaffold.sh)
#   TASK_NAME       basename under eval/tasks/, e.g. "feature-task" — reads
#                   eval/tasks/TASK_NAME.md as the prompt and, if present,
#                   eval/tasks/TASK_NAME.holdout.test.js as the independent
#                   quality gate applied AFTER the run
#   VARIANT         label recorded in the results row (informational only —
#                   apply-variant.sh must already have been run)
#   REP             rep index, recorded in the results row
#   PROJECT_NAME    this fixture's OTel project.name, as printed by
#                   scaffold.sh — recorded in the results row for later
#                   cross-referencing against ~/otel/otel_data.duckdb
#   MAX_BUDGET_USD  default 1.00 — hard circuit breaker per invocation
#   MODEL           default sonnet
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

DEST_ARG="${1:?usage: run.sh DEST TASK_NAME VARIANT REP PROJECT_NAME [MAX_BUDGET_USD] [MODEL]}"
DEST="$(cd "$DEST_ARG" && pwd)"
TASK_NAME="${2:?missing TASK_NAME}"
VARIANT="${3:?missing VARIANT}"
REP="${4:?missing REP}"
PROJECT_NAME="${5:?missing PROJECT_NAME}"
MAX_BUDGET_USD="${6:-1.00}"
MODEL="${7:-sonnet}"

TASK_PROMPT="$REPO_ROOT/eval/tasks/$TASK_NAME.md"
HOLDOUT_TEST="$REPO_ROOT/eval/tasks/$TASK_NAME.holdout.test.js"
[ -f "$TASK_PROMPT" ] || { echo "run.sh: no such task prompt: $TASK_PROMPT" >&2; exit 1; }

RESULT_JSON="$DEST/.eval-result.json"
RESULTS_LOG="$REPO_ROOT/eval/results.jsonl"

echo "run.sh: launching claude -p in $DEST (variant=$VARIANT task=$TASK_NAME rep=$REP)"
START_NS=$(date +%s%N)
set +e
( cd "$DEST" && claude -p "$(cat "$TASK_PROMPT")" \
    --output-format json \
    --permission-mode acceptEdits \
    --allowedTools "Bash(npm test)" "Bash(npm run *)" "Bash(git *)" \
    --max-budget-usd "$MAX_BUDGET_USD" \
    --model "$MODEL" \
    --no-session-persistence ) > "$RESULT_JSON" 2> "$DEST/.eval-stderr.log"
CLAUDE_EXIT=$?
set -e
END_NS=$(date +%s%N)
WALL_CLOCK_MS=$(( (END_NS - START_NS) / 1000000 ))

# Independent scoring — never trust the transcript's own claimed verdict.
# Pass 1: implementer's own tests only. Pass 2: after adding the harness's
# held-out invariant test, if this task has one.
cd "$DEST"
set +e
npm test > .eval-test-own.log 2>&1
TESTS_PASS_OWN=$([ $? -eq 0 ] && echo true || echo false)
set -e

HOLDOUT_PRESENT=false
TESTS_PASS_WITH_HOLDOUT="null"
if [ -f "$HOLDOUT_TEST" ]; then
  HOLDOUT_PRESENT=true
  cp "$HOLDOUT_TEST" "$DEST/test/holdout.test.js"
  set +e
  npm test > .eval-test-holdout.log 2>&1
  TESTS_PASS_WITH_HOLDOUT=$([ $? -eq 0 ] && echo true || echo false)
  set -e
fi

python3 - "$RESULT_JSON" "$RESULTS_LOG" \
  "$VARIANT" "$TASK_NAME" "$REP" "$PROJECT_NAME" "$DEST" "$CLAUDE_EXIT" \
  "$WALL_CLOCK_MS" "$TESTS_PASS_OWN" "$HOLDOUT_PRESENT" "$TESTS_PASS_WITH_HOLDOUT" <<'PYEOF'
import json, sys, datetime

(result_path, results_log, variant, task_name, rep, project_name, dest,
 claude_exit, wall_clock_ms, tests_pass_own, holdout_present,
 tests_pass_with_holdout) = sys.argv[1:]

row = {
    "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "variant": variant,
    "task": task_name,
    "rep": int(rep),
    "project_name": project_name,
    "dest": dest,
    "claude_exit_code": int(claude_exit),
    "wall_clock_ms": int(wall_clock_ms),
    "tests_pass_own": tests_pass_own == "true",
    "holdout_present": holdout_present == "true",
    "tests_pass_with_holdout": (
        None if tests_pass_with_holdout == "null"
        else tests_pass_with_holdout == "true"
    ),
}

try:
    with open(result_path) as f:
        result = json.load(f)
    row["result_subtype"] = result.get("subtype")
    row["is_error"] = result.get("is_error")
    row["total_cost_usd"] = result.get("total_cost_usd")
    row["num_turns"] = result.get("num_turns")
    row["duration_ms"] = result.get("duration_ms")
    row["duration_api_ms"] = result.get("duration_api_ms")
    row["usage"] = result.get("usage")
except (FileNotFoundError, json.JSONDecodeError) as e:
    row["result_parse_error"] = str(e)

with open(results_log, "a") as f:
    f.write(json.dumps(row) + "\n")

print(json.dumps(row, indent=2))
PYEOF
