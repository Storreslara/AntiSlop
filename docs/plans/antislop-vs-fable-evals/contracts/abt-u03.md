Unit: abt-u03

## Objective
eval/abtest/lib/make-row.py assembles one result row from a stream summary, a checks array and run metadata (run_pass, holdout_pass_rate, defects_escaped, token columns, completion_status including usage-limit, Arm A null process); tests/abtest-row.test.sh passes over canned inputs. One commit.

## Retrieval
GitHub issues: `gh issue view 571 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/lib/make-row.py` (anchor: new file)
- `tests/abtest-row.test.sh` (anchor: new file)
- `tests/fixtures/abtest/row/checks-fail.json` (anchor: new file)
- `tests/fixtures/abtest/row/checks-optional.json` (anchor: new file)
- `tests/fixtures/abtest/row/checks-pass.json` (anchor: new file)
- `tests/fixtures/abtest/row/process-b.json` (anchor: new file)
- `tests/fixtures/abtest/row/prompt.txt` (anchor: new file)
- `tests/fixtures/abtest/row/summary-complete.json` (anchor: new file)
- `tests/fixtures/abtest/row/summary-limit.json` (anchor: new file)
- `tests/fixtures/abtest/row/summary-stalled.json` (anchor: new file)

## Ordered edits
1. command: `test ! -e eval/abtest/lib/make-row.py && test ! -e tests/abtest-row.test.sh && test ! -e tests/fixtures/abtest/row && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/lib/make-row.py`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env python3
"""Assemble one result row (spec 4.3, amended by operator decisions OD-4/OD-5).

Usage: make-row.py --summary SUMMARY.json --checks CHECKS.json [options]
SUMMARY.json is the output of stream.py summarize; CHECKS.json is the JSON
array a check.sh prints. Prints one JSON object on one line.
"""
import argparse
import hashlib
import json
import sys

STATUSES = ("complete", "stalled-human", "turn-cap", "timeout", "usage-limit", "error")
ARM_A_PROCESS = {
    "units": None, "review_fail_cycles": None, "tiers_seen": None,
    "gate_blocks": 0, "stalled_reason": None, "persona_tokens": None,
}


def sha256_file(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def load(path):
    with open(path) as f:
        return json.load(f)


def build(a):
    summary = load(a.summary)
    checks = load(a.checks)
    status = summary["completion_status"]
    if status not in STATUSES:
        raise SystemExit(f"make-row: unknown completion_status {status!r}")
    required = [c for c in checks if c.get("required")]
    passed = [c for c in required if c.get("pass")]
    rate = (len(passed) / len(required)) if required else None
    escaped = sum(1 for c in checks if c.get("kind") in ("defect", "security") and not c.get("pass"))
    run_pass = status == "complete" and len(passed) == len(required)
    if a.arm == "A":
        process = dict(ARM_A_PROCESS)
    else:
        process = dict(ARM_A_PROCESS)
        process["gate_blocks"] = 0
        if a.process:
            process.update(load(a.process))
    return {
        "schema_version": 1,
        "run_id": f"{a.eval_id}/{a.arm}/{a.policy}/{a.rep}",
        "eval_id": a.eval_id,
        "arm": a.arm,
        "model_policy": a.policy,
        "rep": a.rep,
        "started_at": a.started_at,
        "harness_commit": a.harness_commit,
        "plugin_commit": None if a.plugin_commit == "null" else a.plugin_commit,
        "plugin_version": None if a.plugin_version == "null" else a.plugin_version,
        "cli_version": a.cli_version,
        "fixture_commit": a.fixture_commit,
        "fixture_profile": json.loads(a.fixture_profile),
        "prompt_sha": sha256_file(a.prompt_file),
        "persona_config_sha": None if a.persona_config_sha == "null" else a.persona_config_sha,
        "completion_status": status,
        "result_subtype": summary.get("result_subtype"),
        "wall_clock_ms": a.wall_clock_ms,
        "duration_api_ms": summary.get("duration_api_ms"),
        "total_cost_usd": summary.get("total_cost_usd"),
        "model_usage": summary.get("model_usage") or {},
        "tokens_in": summary["tokens_in"],
        "tokens_out": summary["tokens_out"],
        "tokens_cache_write": summary["tokens_cache_write"],
        "tokens_cache_read": summary["tokens_cache_read"],
        "tokens_total": summary["tokens_total"],
        "num_turns": summary.get("num_turns"),
        "subagent_spawns": summary.get("subagent_spawns"),
        "tool_calls": summary.get("tool_calls"),
        "human_interventions_required": summary.get("human_interventions_required"),
~~~~
3. file: `eval/abtest/lib/make-row.py`
   anchor: line matching `        "human_interventions_required": summary.get("human_interventions_required"),`
   indent: 0
   insert-after:
~~~~
        "checks": checks,
        "holdout_pass_rate": rate,
        "defects_escaped": escaped,
        "out_of_scope_lines": a.out_of_scope_lines,
        "out_of_scope_files": a.out_of_scope_files,
        "commits": a.commits,
        "run_pass": run_pass,
        "process": process,
        "blind_grades": json.loads(a.blind_grades),
        "artifacts": {"stream": a.stream_path, "diff": a.diff_path},
    }


def main(argv):
    p = argparse.ArgumentParser(prog="make-row.py")
    p.add_argument("--summary", required=True)
    p.add_argument("--checks", required=True)
    p.add_argument("--eval-id", required=True)
    p.add_argument("--arm", required=True, choices=("A", "B"))
    p.add_argument("--policy", default="uniform", choices=("uniform", "shipped"))
    p.add_argument("--rep", type=int, required=True)
    p.add_argument("--started-at", required=True)
    p.add_argument("--harness-commit", required=True)
    p.add_argument("--plugin-commit", default="null")
    p.add_argument("--plugin-version", default="null")
    p.add_argument("--cli-version", required=True)
    p.add_argument("--fixture-commit", required=True)
    p.add_argument("--fixture-profile", default="{}")
    p.add_argument("--prompt-file", required=True)
    p.add_argument("--persona-config-sha", default="null")
    p.add_argument("--wall-clock-ms", type=int, required=True)
    p.add_argument("--commits", type=int, default=0)
    p.add_argument("--out-of-scope-lines", type=int, default=0)
    p.add_argument("--out-of-scope-files", type=int, default=0)
    p.add_argument("--process", default="")
    p.add_argument("--blind-grades", default="{}")
    p.add_argument("--stream-path", default="")
    p.add_argument("--diff-path", default="")
    a = p.parse_args(argv)
    sys.stdout.write(json.dumps(build(a), sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
~~~~
4. file: `tests/abtest-row.test.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Tests eval/abtest/lib/make-row.py over canned summaries and check arrays.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="$REPO_ROOT/eval/abtest/lib/make-row.py"
FX="$REPO_ROOT/tests/fixtures/abtest/row"
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

# row SUMMARY CHECKS ARM [extra flags]: print the row JSON.
row() {
  local s="$1" c="$2" arm="$3"
  shift 3
  python3 "$PY" --summary "$FX/$s" --checks "$FX/$c" --arm "$arm" --eval-id e01-ambiguous-tax --rep 3 \
    --started-at 2026-10-20T14:03:11Z --harness-commit h1 --cli-version 2.1.300 --fixture-commit f1 \
    --prompt-file "$FX/prompt.txt" --wall-clock-ms 4000 "$@"
}
# field JSON EXPR: evaluate a python expression over the row d.
field() { printf '%s' "$1" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(eval(sys.argv[1]))' "$2"; }

R="$(row summary-complete.json checks-pass.json A)"
check "run_id joins eval, arm, policy and rep" "$(field "$R" 'd["run_id"]')" "e01-ambiguous-tax/A/uniform/3"
check "clean complete run passes" "$(field "$R" 'd["run_pass"]')" "True"
check "pass rate is 1.0" "$(field "$R" 'd["holdout_pass_rate"]')" "1.0"
check "arm A process fields are null except gate_blocks 0" "$(field "$R" '[d["process"]["units"], d["process"]["gate_blocks"]]')" "[None, 0]"
check "prompt_sha is the sha256 of the prompt file" "$(field "$R" 'd["prompt_sha"]')" "$(sha256sum "$FX/prompt.txt" | cut -d' ' -f1)"
check "plugin fields are null for arm A" "$(field "$R" '[d["plugin_commit"], d["plugin_version"]]')" "[None, None]"
check "token columns are copied" "$(field "$R" '[d["tokens_total"], d["tokens_cache_read"]]')" "[60, 400]"
check "cost is carried for information" "$(field "$R" 'd["total_cost_usd"]')" "1.5"
check "schema_version is 1" "$(field "$R" 'd["schema_version"]')" "1"

R="$(row summary-complete.json checks-fail.json B --policy uniform --plugin-commit abc --plugin-version 0.31.181 --process "$FX/process-b.json")"
check "a failed required check fails the run" "$(field "$R" 'd["run_pass"]')" "False"
check "pass rate is a half" "$(field "$R" 'd["holdout_pass_rate"]')" "0.5"
check "a failed security check is an escaped defect" "$(field "$R" 'd["defects_escaped"]')" "1"
check "arm B process comes from the process file" "$(field "$R" '[d["process"]["units"], d["process"]["gate_blocks"]]')" "[3, 2]"
check "plugin fields are kept for arm B" "$(field "$R" '[d["plugin_commit"], d["plugin_version"]]')" "['abc', '0.31.181']"

R="$(row summary-stalled.json checks-pass.json B)"
check "a stall fails the run with every check passing" "$(field "$R" '[d["run_pass"], d["completion_status"]]')" "[False, 'stalled-human']"

R="$(row summary-limit.json checks-pass.json A)"
check "a usage-limit row is kept with its own status" "$(field "$R" '[d["run_pass"], d["completion_status"]]')" "[False, 'usage-limit']"

R="$(row summary-complete.json checks-optional.json A)"
check "no required checks gives a null pass rate" "$(field "$R" 'd["holdout_pass_rate"]')" "None"
check "an optional failed check does not fail the run" "$(field "$R" 'd["run_pass"]')" "True"

echo '{"completion_status":"budget"}' > "$FX/../row-bad.tmp"
python3 "$PY" --summary "$FX/../row-bad.tmp" --checks "$FX/checks-pass.json" --arm A --eval-id x --rep 1 --started-at t \
  --harness-commit h --cli-version c --fixture-commit f --prompt-file "$FX/prompt.txt" --wall-clock-ms 1 > /dev/null 2>&1
check "the retired budget status is rejected" "$?" "1"
rm -f "$FX/../row-bad.tmp"

echo "abtest-row: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-row checks passed."
exit "$fail"
~~~~
5. file: `tests/fixtures/abtest/row/checks-fail.json`
   anchor: new file
   indent: 0
   insert-after:
~~~~
[{"id":"hold-a","kind":"defect","required":true,"cmd":"x","exit":0,"pass":true},{"id":"hold-b","kind":"security","required":true,"cmd":"z","exit":1,"pass":false}]
~~~~
6. file: `tests/fixtures/abtest/row/checks-optional.json`
   anchor: new file
   indent: 0
   insert-after:
~~~~
[{"id":"opt","kind":"process","required":false,"cmd":"w","exit":1,"pass":false}]
~~~~
7. file: `tests/fixtures/abtest/row/checks-pass.json`
   anchor: new file
   indent: 0
   insert-after:
~~~~
[{"id":"hold-a","kind":"defect","required":true,"cmd":"x","exit":0,"pass":true},{"id":"scope","kind":"scope","required":true,"cmd":"y","exit":0,"pass":true,"value":0}]
~~~~
8. file: `tests/fixtures/abtest/row/process-b.json`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"units":3,"review_fail_cycles":1,"tiers_seen":["fable"],"gate_blocks":2,"stalled_reason":null,"persona_tokens":{"reviewer":{"in":1,"out":2}}}
~~~~
9. file: `tests/fixtures/abtest/row/prompt.txt`
   anchor: new file
   indent: 0
   insert-after:
~~~~
Do the task.
~~~~
10. file: `tests/fixtures/abtest/row/summary-complete.json`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"completion_status":"complete","model_usage":{"fable-x":{"inputTokens":1}},"num_turns":7,"duration_api_ms":900,"total_cost_usd":1.5,"result_subtype":"success","subagent_spawns":2,"tool_calls":9,"human_interventions_required":0,"tokens_in":10,"tokens_out":20,"tokens_cache_write":30,"tokens_cache_read":400,"tokens_total":60}
~~~~
11. file: `tests/fixtures/abtest/row/summary-limit.json`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"completion_status":"usage-limit","model_usage":{"fable-x":{"inputTokens":1}},"num_turns":7,"duration_api_ms":900,"total_cost_usd":1.5,"result_subtype":"success","subagent_spawns":2,"tool_calls":9,"human_interventions_required":0,"tokens_in":10,"tokens_out":20,"tokens_cache_write":30,"tokens_cache_read":400,"tokens_total":60}
~~~~
12. file: `tests/fixtures/abtest/row/summary-stalled.json`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"completion_status":"stalled-human","model_usage":{"fable-x":{"inputTokens":1}},"num_turns":7,"duration_api_ms":900,"total_cost_usd":1.5,"result_subtype":"success","subagent_spawns":2,"tool_calls":9,"human_interventions_required":0,"tokens_in":10,"tokens_out":20,"tokens_cache_write":30,"tokens_cache_read":400,"tokens_total":60}
~~~~
13. command: `chmod +x eval/abtest/lib/make-row.py tests/abtest-row.test.sh`
   expect: 0
14. command: `git add eval/abtest/lib/make-row.py tests/abtest-row.test.sh tests/fixtures/abtest/row/checks-fail.json tests/fixtures/abtest/row/checks-optional.json tests/fixtures/abtest/row/checks-pass.json tests/fixtures/abtest/row/process-b.json tests/fixtures/abtest/row/prompt.txt tests/fixtures/abtest/row/summary-complete.json tests/fixtures/abtest/row/summary-limit.json tests/fixtures/abtest/row/summary-stalled.json && git commit -m "feat(abt-u03): result-row assembler with token columns and usage-limit rows (#571)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/lib/stream.py` (unit abt-u02 owns the stream summariser)
- `eval/abtest/arms/` (unit abt-u01 owns the arm scripts)
- `eval/harness/` (the one-arm pilot harness stays untouched)
- `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-row.test.sh`
   exit: 0
   stdout: `All abtest-row checks passed.`
   mutation: skip edit 11 (summary-limit.json); the usage-limit row FAILs, the script exits non-zero and the fragment is absent.
2. run: `python3 -I eval/abtest/lib/make-row.py --summary tests/fixtures/abtest/row/summary-complete.json --checks tests/fixtures/abtest/row/checks-pass.json --arm A --eval-id e01-ambiguous-tax --rep 1 --started-at t --harness-commit h --cli-version c --fixture-commit f --prompt-file tests/fixtures/abtest/row/prompt.txt --wall-clock-ms 1 | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d["run_id"],d["run_pass"],d["tokens_total"])'`
   exit: 0
   stdout: `e01-ambiguous-tax/A/uniform/1 True 60`
   mutation: skip edit 7 (checks-pass.json); make-row exits non-zero on the missing file and nothing prints.
3. run: `python3 -I eval/abtest/lib/make-row.py --summary tests/fixtures/abtest/row/summary-limit.json --checks tests/fixtures/abtest/row/checks-pass.json --arm A --eval-id e01-ambiguous-tax --rep 1 --started-at t --harness-commit h --cli-version c --fixture-commit f --prompt-file tests/fixtures/abtest/row/prompt.txt --wall-clock-ms 1 | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d["completion_status"],d["run_pass"])'`
   exit: 0
   stdout: `usage-limit False`
   mutation: skip edit 11; make-row exits non-zero on the missing file and nothing prints.
4. run: `python3 -I eval/abtest/lib/make-row.py --summary tests/fixtures/abtest/row/summary-complete.json --checks tests/fixtures/abtest/row/checks-fail.json --arm A --eval-id e01-ambiguous-tax --rep 1 --started-at t --harness-commit h --cli-version c --fixture-commit f --prompt-file tests/fixtures/abtest/row/prompt.txt --wall-clock-ms 1 | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d["defects_escaped"],d["holdout_pass_rate"])'`
   exit: 0
   stdout: `1 0.5`
   mutation: skip edit 5 (checks-fail.json); make-row exits non-zero on the missing file and nothing prints.
5. run: `grep -c '^if __name__' eval/abtest/lib/make-row.py`
   exit: 0
   stdout: `1`
   mutation: skip edit 3 (the last part of make-row.py, which holds the __main__ guard); stdout 0 and the exit is 1.
6. run: `test -x eval/abtest/lib/make-row.py && test -x tests/abtest-row.test.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: skip edit 13; the files are not executable and nothing prints.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u03\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/lib/make-row.py tests/abtest-row.test.sh tests/fixtures/abtest/row/checks-fail.json tests/fixtures/abtest/row/checks-optional.json tests/fixtures/abtest/row/checks-pass.json tests/fixtures/abtest/row/process-b.json tests/fixtures/abtest/row/prompt.txt tests/fixtures/abtest/row/summary-complete.json tests/fixtures/abtest/row/summary-limit.json tests/fixtures/abtest/row/summary-stalled.json`
   mutation: skip edit 14 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u03\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 14; no unit commit exists and the exit is 3.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u03\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/lib/make-row.py tests/abtest-row.test.sh tests/fixtures/abtest/row/checks-fail.json tests/fixtures/abtest/row/checks-optional.json tests/fixtures/abtest/row/checks-pass.json tests/fixtures/abtest/row/process-b.json tests/fixtures/abtest/row/prompt.txt tests/fixtures/abtest/row/summary-complete.json tests/fixtures/abtest/row/summary-limit.json tests/fixtures/abtest/row/summary-stalled.json | grep -vcE "^[a-z]+\(abt-u03\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
10. run: `git status --porcelain -- eval/abtest/lib tests/abtest-row.test.sh tests/fixtures/abtest/row`
   exit: 0
   stdout: empty
   mutation: skip edit 14; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-row.test.sh (criteria 1-4 are the red-then-green checks; none of the files exist at HEAD)
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 10 (the scoped clean-tree check) passes at HEAD by design, because no file of the unit exists yet; it turns red only when the commit step is skipped.
no-real-claude: no command in this contract runs the real claude CLI.
no-dependency-files: this unit reads only canned JSON. It does not import or run stream.py; abt-u02 may or may not have landed.
commit-message: feat(abt-u03): result-row assembler with token columns and usage-limit rows (#571)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u03 (#571)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
