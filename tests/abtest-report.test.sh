#!/usr/bin/env bash
# Tests eval/abtest/report.py (experiment-log filling and eval-finding tickets)
# over a synthetic score report. Needs eval/abtest/score.py. No claude, no usage.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCORE="$REPO_ROOT/eval/abtest/score.py"
REPORT="$REPO_ROOT/eval/abtest/report.py"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

python3 -I - "$T" << 'PYEOF'
import json, sys

t = sys.argv[1]

def row(ev, arm, rep, passed, status="complete", defects=0, tokens=100, checks=None):
    return {
        "schema_version": 1, "run_id": f"{ev}/{arm}/uniform/{rep}", "eval_id": ev, "arm": arm,
        "model_policy": "uniform", "rep": rep, "started_at": "t", "harness_commit": "h",
        "plugin_commit": None, "plugin_version": None, "cli_version": "c", "fixture_commit": "f",
        "fixture_profile": {}, "prompt_sha": "p", "persona_config_sha": None,
        "completion_status": status, "result_subtype": None, "wall_clock_ms": 1000,
        "duration_api_ms": None, "total_cost_usd": None, "model_usage": {}, "tokens_in": tokens - 1,
        "tokens_out": 1, "tokens_cache_write": 0, "tokens_cache_read": 0, "tokens_total": tokens,
        "num_turns": 5, "subagent_spawns": 0, "tool_calls": 0, "human_interventions_required": 0,
        "checks": checks or [], "holdout_pass_rate": None, "defects_escaped": defects,
        "out_of_scope_lines": 0, "out_of_scope_files": 0, "commits": 1,
        "run_pass": passed and status == "complete", "process": {}, "blind_grades": {},
        "artifacts": {"stream": f"runs/{ev}_{arm}_{rep}/stream.jsonl", "diff": "d"},
    }

FAILED = [{"id": "hold-a", "kind": "defect", "required": True, "cmd": "node --test x", "exit": 1, "pass": False}]
rows = []
def add(ev, a_pass, b_pass, b_defects=0, b_checks=None):
    for i in range(5):
        rows.append(row(ev, "A", i + 1, i < a_pass))
        rows.append(row(ev, "B", i + 1, i < b_pass, defects=b_defects, checks=b_checks))

add("e01-ambiguous-tax", 4, 1, b_checks=FAILED)
add("e02-preview-mutation", 1, 4, b_defects=1)
add("e03-rename-query", 3, 4)
add("e04-search-injection", 1, 5)
for r in rows:
    if r["eval_id"] == "e04-search-injection" and r["arm"] == "B" and r["rep"] == 5:
        r["completion_status"], r["run_pass"] = "stalled-human", False
add("e05-tags-feature", 3, 3)
with open(t + "/rows.jsonl", "w") as f:
    for r in rows:
        f.write(json.dumps(r) + "\n")
with open(t + "/log.md", "w") as f:
    f.write("""# log

### E1: ambiguous (e01-ambiguous-tax)

- **Result**: pending
- **Verdict**: pending
- **Decision**: pending

### E2: preview (e02-preview-mutation)

- **Result**: pending
- **Verdict**: pending
- **Decision**: pending

### E3: rename (e03-rename-query)

- **Result**: pending
- **Verdict**: pending
- **Decision**: pending

### E4: search (e04-search-injection)

- **Result**: pending
- **Verdict**: pending
- **Decision**: pending

### E5: tags (e05-tags-feature)

- **Result**: pending
- **Verdict**: pending
- **Decision**: pending

## Verdict rules

- **Decision**: pending (outside every entry)
""")
PYEOF
python3 "$SCORE" "$T/rows.jsonl" --out-json "$T/score.json" > /dev/null

cp "$T/log.md" "$T/log-pending.md"
python3 "$REPORT" fill-log "$T/score.json" "$T/log.md" "$T/rows.jsonl" > /dev/null; rc=$?
check "fill-log exits 0" "$rc" "0"
check "the E1 result line carries the pass counts" "$(grep -c '^- \*\*Result\*\*: run_pass A 4/5, B 1/5 (WIN_A)' "$T/log.md")" "1"
check "the verdict lines stay pending for the operator" "$(grep -c '^- \*\*Verdict\*\*: pending' "$T/log.md")" "5"
check "every not-superior, stalling or defect-escaping eval points at a ticket" "$(grep -c '^- \*\*Decision\*\*: ticket filed under the eval-finding label' "$T/log.md")" "4"
check "a superior eval with an escaped defect says a ticket is filed" "$(grep -c '^- \*\*Decision\*\*: ticket filed under the eval-finding label (an Arm B run let a defect escape in 5 run(s)); no change is shipped by this log; verdict superior: recorded as a measured advantage (directional' "$T/log.md")" "1"
check "an inconclusive eval asks for more data" "$(grep -c '^- \*\*Decision\*\*: NEEDS MORE DATA' "$T/log.md")" "1"
check "the E2 result line keeps the Fisher p and the directional mark" "$(grep -c 'Fisher p 0.21; .*verdict superior (directional, p=0.21)' "$T/log.md")" "1"
check "the E1 result line carries the per-check pass counts per arm" "$(grep -c 'run_pass A 4/5, B 1/5 (WIN_A).*checks passed per arm (of the usable rows) A \[none\], B \[hold-a 0/5\]' "$T/log.md")" "1"
check "a header after the last entry resets the entry scope" "$(grep -c '^- \*\*Decision\*\*: pending (outside every entry)' "$T/log.md")" "1"
cp "$T/log.md" "$T/log-filled.md"
python3 "$REPORT" fill-log "$T/score.json" "$T/log.md" "$T/rows.jsonl" > /dev/null
check "fill-log is idempotent" "$(cmp -s "$T/log.md" "$T/log-filled.md" && echo same || echo different)" "same"
grep -v 'e05-tags-feature' "$T/log-pending.md" | sed '/^### E5/,/^## Verdict/{/^## Verdict/!d}' > "$T/log-short.md"
cp "$T/log-short.md" "$T/log-short.before"
python3 "$REPORT" fill-log "$T/score.json" "$T/log-short.md" "$T/rows.jsonl" > /dev/null 2>&1; rc=$?
check "a log missing an eval of the report exits non-zero" "$rc" "1"
check "and the log is left unchanged" "$(cmp -s "$T/log-short.md" "$T/log-short.before" && echo same || echo different)" "same"
{ cat "$T/log-pending.md"; printf '\n### E6: extra (e06-extra-entry)\n\n- **Result**: pending\n- **Verdict**: pending\n- **Decision**: pending\n'; } > "$T/log-extra.md"
cp "$T/log-extra.md" "$T/log-extra.before"
python3 "$REPORT" fill-log "$T/score.json" "$T/log-extra.md" "$T/rows.jsonl" > /dev/null 2>&1; rc=$?
check "a log holding an eval the report lacks exits non-zero" "$rc $(cmp -s "$T/log-extra.md" "$T/log-extra.before" && echo same || echo different)" "1 same"
printf '{"policy": ' > "$T/bad.json"
python3 "$REPORT" fill-log "$T/bad.json" "$T/log-pending.md" "$T/rows.jsonl" > /dev/null 2> "$T/bad.err"; rc=$?
check "malformed score JSON exits non-zero with a named error" "$rc $(grep -c '^report: cannot read .*bad.json as JSON' "$T/bad.err")" "1 1"

python3 "$REPORT" tickets "$T/score.json" "$T/rows.jsonl" "$T/tickets" > "$T/t.txt"; rc=$?
check "tickets exits 0" "$rc" "0"
python3 "$REPORT" tickets "$T/score.json" "$T/rows.jsonl" "$T/tickets" > /dev/null 2>&1; rc=$?
check "tickets refuses an output directory that already holds files" "$rc" "1"
check "tickets for the losing, defect-escaping, stalling and tied-without-edge evals" "$(ls "$T/tickets" | paste -sd' ')" "e01-ambiguous-tax.md e02-preview-mutation.md e04-search-injection.md e05-tags-feature.md"
check "an inconclusive eval gets no ticket" "$(test -e "$T/tickets/e03-rename-query.md" && echo yes || echo no)" "no"
check "the ticket title line names the eval and verdict" "$(head -n1 "$T/tickets/e01-ambiguous-tax.md")" "[eval-finding] e01-ambiguous-tax: not-superior"
check "the ticket quotes the failed check verbatim" "$(grep -c 'e01-ambiguous-tax/B/uniform/1: hold-a (defect) cmd: node --test x' "$T/tickets/e01-ambiguous-tax.md")" "1"
check "the ticket lists Arm B transcripts" "$(grep -c 'runs/e01-ambiguous-tax_B_1/stream.jsonl' "$T/tickets/e01-ambiguous-tax.md")" "1"
check "the ticket carries the design's look-at entry" "$(grep -c 'spec-master grilling' "$T/tickets/e01-ambiguous-tax.md")" "1"
check "a stall ticket exists for the winning eval that stalled" "$(head -n1 "$T/tickets/e04-search-injection.md")" "[eval-finding] e04-search-injection: not-superior"

python3 -I - "$T" << 'PYEOF'
import json, sys

t = sys.argv[1]
rows = [json.loads(l) for l in open(t + "/rows.jsonl")]
mixed = [r for r in rows if r["eval_id"] == "e03-rename-query"]
mixed[0]["harness_commit"] = "old"
bad = [dict(r) for r in rows if r["eval_id"] == "e04-search-injection"]
for r in bad:
    if r["arm"] == "B" and r["rep"] >= 4:
        r["completion_status"], r["run_pass"] = "turn-cap", False
with open(t + "/rows-bad.jsonl", "w") as f:
    for r in bad:
        f.write(json.dumps(r) + "\n")
with open(t + "/log-bad.md", "w") as f:
    f.write("### E4: search (e04-search-injection)\n\n- **Result**: pending\n- **Verdict**: pending\n- **Decision**: pending\n")
with open(t + "/rows-other.jsonl", "w") as f:
    for r in mixed:
        f.write(json.dumps(r) + "\n")
    for r in mixed[:2]:
        o = dict(r)
        o["model_policy"], o["run_id"], o["defects_escaped"] = "shipped", r["run_id"] + "-s", 7
        f.write(json.dumps(o) + "\n")
with open(t + "/rows-mixed.jsonl", "w") as f:
    for r in mixed:
        f.write(json.dumps(r) + "\n")
with open(t + "/log-mixed.md", "w") as f:
    f.write("### E3: rename (e03-rename-query)\n\n- **Result**: pending\n- **Verdict**: pending\n- **Decision**: pending\n")
PYEOF
python3 "$SCORE" "$T/rows-mixed.jsonl" --out-json "$T/score-mixed.json" > /dev/null
python3 "$REPORT" fill-log "$T/score-mixed.json" "$T/log-mixed.md" "$T/rows-mixed.jsonl" > /dev/null
check "mixed provenance asks for a rerun, not a top-up" "$(grep -c '^- \*\*Decision\*\*: RERUN: the rows mix provenance (mixed provenance: harness_commit)' "$T/log-mixed.md")" "1"
check "mixed provenance never asks for more data" "$(grep -c 'NEEDS MORE DATA' "$T/log-mixed.md")" "0"
check "the mixed result line still names the outcome" "$(grep -c '(INCONCLUSIVE)' "$T/log-mixed.md")" "1"

python3 "$SCORE" "$T/rows-bad.jsonl" --out-json "$T/score-bad.json" > /dev/null
python3 "$REPORT" fill-log "$T/score-bad.json" "$T/log-bad.md" "$T/rows-bad.jsonl" > /dev/null
check "two bad rows say no more runs help, never a top-up" "$(grep -c '^- \*\*Decision\*\*: NO MORE RUNS HELP: two or more turn-cap' "$T/log-bad.md")" "1"
check "two bad rows never ask for more data" "$(grep -c 'NEEDS MORE DATA\|<eval-id>' "$T/log-bad.md")" "0"
python3 "$REPORT" tickets "$T/score-mixed.json" "$T/rows-other.jsonl" "$T/tickets-other" > /dev/null 2>&1; rc=$?
check "tickets ignores the rows of another policy" "$rc $(ls "$T/tickets-other" | wc -l | tr -d ' ')" "0 0"
sed 's/e04-search-injection/..\/escape/g' "$T/score.json" > "$T/score-evil.json"
sed 's/e04-search-injection/..\/escape/g' "$T/rows.jsonl" > "$T/rows-evil.jsonl"
python3 "$REPORT" tickets "$T/score-evil.json" "$T/rows-evil.jsonl" "$T/tickets-evil" > /dev/null 2>&1; rc=$?
check "tickets refuses an eval id that is not an eval id" "$rc $(test -e "$T/tickets-evil" && echo yes || echo no)" "1 no"

python3 "$REPORT" bogus > /dev/null 2>&1
check "a bad command exits 2" "$?" "2"

echo "abtest-report: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-report checks passed."
exit "$fail"
