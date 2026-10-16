Unit: abt-u02

## Objective
eval/abtest/lib/stream.py summarises a stream-json capture into one JSON object and classifies completion_status as complete, stalled-human, turn-cap, timeout, usage-limit or error (usage-limit is never a failure); tests/abtest-stream.test.sh passes over nine canned captures. One commit.

## Retrieval
GitHub issues: `gh issue view 570 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/lib/stream.py` (anchor: new file)
- `tests/abtest-stream.test.sh` (anchor: new file)
- `tests/fixtures/abtest/streams/complete.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/denied.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/limit-event.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/limit-text.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/limit.stderr` (anchor: new file)
- `tests/fixtures/abtest/streams/max-turns.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/mentions-limit.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/no-result.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/stall-ask.jsonl` (anchor: new file)

## Ordered edits
1. command: `test ! -e eval/abtest/lib && test ! -e tests/abtest-stream.test.sh && test ! -e tests/fixtures/abtest/streams && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/lib/stream.py`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env python3
"""Summarise one headless run's stream-json capture.

Usage:
  stream.py summarize STREAM_FILE [--exit-code N] [--stderr FILE] [--escalated N]

Prints one JSON object. completion_status is decided in this order:
  usage-limit  a subscription usage or rate limit stopped the run (never a failure)
  timeout      the wall-clock cap fired (exit code 124)
  turn-cap     the result subtype is error_max_turns
  stalled-human  an AskUserQuestion attempt, a permission denial or an
               escalation marker (--escalated) means the run needed a human
  error        no result object, an error result, or a non-zero exit with no clean result
  complete     everything else
"""
import argparse
import json
import re
import sys

LIMIT_RE = re.compile(
    r"usage limit|limit reached|rate[ _-]?limit|quota|too many requests|\b429\b",
    re.IGNORECASE,
)
SUBAGENT_TOOLS = ("Agent", "Task")


def read_records(path):
    """Return (JSON objects, text of the lines that were not JSON)."""
    records = []
    noise = []
    with open(path, errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                noise.append(line)
                continue
            if isinstance(obj, dict):
                records.append(obj)
    return records, "\n".join(noise)


def hook_name(rec):
    for key in ("hook_event", "hookEvent", "hook_name", "hookName"):
        if rec.get(key):
            return str(rec[key])
    return ""


def is_hook_record(rec):
    kind = str(rec.get("type", ""))
    sub = str(rec.get("subtype", ""))
    return kind.startswith("hook") or (kind == "system" and sub.startswith("hook"))


def tool_uses(rec):
    if rec.get("type") != "assistant":
        return []
    content = (rec.get("message") or {}).get("content") or []
    return [b for b in content if isinstance(b, dict) and b.get("type") == "tool_use"]


def limit_event(rec):
    if rec.get("type") != "rate_limit_event":
        return False
    info = rec.get("rate_limit_info") or {}
    return str(info.get("status", "")).lower() in ("rejected", "blocked", "exceeded")


def summarize(path, exit_code, stderr_text, escalated):
    records, noise = read_records(path)
    result = None
    for rec in records:
        if rec.get("type") == "result":
~~~~
3. file: `eval/abtest/lib/stream.py`
   anchor: line matching `        if rec.get("type") == "result":`
   indent: 0
   insert-after:
~~~~
            result = rec
    hooks = [r for r in records if is_hook_record(r)]
    hook_names = [hook_name(r) for r in hooks]
    tools = [b for r in records for b in tool_uses(r)]
    spawns = sum(1 for b in tools if b.get("name") in SUBAGENT_TOOLS)
    asks = sum(1 for b in tools if b.get("name") == "AskUserQuestion")
    denials = len((result or {}).get("permission_denials") or [])

    usage = (result or {}).get("usage") or {}
    tok_in = int(usage.get("input_tokens") or 0)
    tok_out = int(usage.get("output_tokens") or 0)
    tok_cw = int(usage.get("cache_creation_input_tokens") or 0)
    tok_cr = int(usage.get("cache_read_input_tokens") or 0)

    limited = any(limit_event(r) for r in records)
    if exit_code != 0 and LIMIT_RE.search(stderr_text):
        limited = True
    if result is None or result.get("is_error"):
        if LIMIT_RE.search(str((result or {}).get("result", "")) + "\n" + noise):
            limited = True

    subtype = (result or {}).get("subtype")
    if limited:
        status = "usage-limit"
    elif exit_code == 124:
        status = "timeout"
    elif subtype == "error_max_turns":
        status = "turn-cap"
    elif asks > 0 or denials > 0 or escalated > 0:
        status = "stalled-human"
    elif result is None or result.get("is_error") or exit_code != 0:
        status = "error"
    else:
        status = "complete"

    return {
        "completion_status": status,
        "result_subtype": subtype,
        "result_text": (result or {}).get("result"),
        "num_turns": (result or {}).get("num_turns"),
        "duration_api_ms": (result or {}).get("duration_api_ms"),
        "total_cost_usd": (result or {}).get("total_cost_usd"),
        "tokens_in": tok_in,
        "tokens_out": tok_out,
        "tokens_cache_write": tok_cw,
        "tokens_cache_read": tok_cr,
        "tokens_total": tok_in + tok_out + tok_cw,
        "model_usage": (result or {}).get("modelUsage") or {},
        "hook_events": len(hooks),
        "session_start_events": sum(1 for n in hook_names if n.startswith("SessionStart")),
        "subagent_spawns": spawns,
        "tool_calls": len(tools),
        "ask_user_attempts": asks,
        "permission_denials": denials,
        "escalated_markers": escalated,
        "human_interventions_required": asks + denials + escalated,
    }


def main(argv):
    ap = argparse.ArgumentParser(prog="stream.py")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sm = sub.add_parser("summarize")
    sm.add_argument("stream")
    sm.add_argument("--exit-code", type=int, default=0)
    sm.add_argument("--stderr", default="")
    sm.add_argument("--escalated", type=int, default=0)
    args = ap.parse_args(argv)
    stderr_text = ""
    if args.stderr:
        with open(args.stderr, errors="replace") as f:
            stderr_text = f.read()
    out = summarize(args.stream, args.exit_code, stderr_text, args.escalated)
    json.dump(out, sys.stdout, sort_keys=True)
    sys.stdout.write("\n")
    return 0
~~~~
4. file: `eval/abtest/lib/stream.py`
   anchor: line matching `    return 0`
   indent: 0
   insert-after:
~~~~


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
~~~~
5. file: `tests/abtest-stream.test.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Tests eval/abtest/lib/stream.py: completion_status classification and the
# counters, over canned stream-json captures. No claude, no usage.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="$REPO_ROOT/eval/abtest/lib/stream.py"
FX="$REPO_ROOT/tests/fixtures/abtest/streams"
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

# field STREAM KEY [summarize flags...]: print one summary field.
field() {
  local s="$1" k="$2"
  shift 2
  python3 "$PY" summarize "$s" "$@" | python3 -c 'import json,sys;print(json.load(sys.stdin)[sys.argv[1]])' "$k"
}

check "clean run is complete" "$(field "$FX/complete.jsonl" completion_status)" "complete"
check "error_max_turns is turn-cap" "$(field "$FX/max-turns.jsonl" completion_status)" "turn-cap"
check "AskUserQuestion is stalled-human" "$(field "$FX/stall-ask.jsonl" completion_status)" "stalled-human"
check "permission denial is stalled-human" "$(field "$FX/denied.jsonl" completion_status)" "stalled-human"
check "escalation marker is stalled-human" "$(field "$FX/complete.jsonl" completion_status --escalated 1)" "stalled-human"
check "rate_limit_event rejected is usage-limit" "$(field "$FX/limit-event.jsonl" completion_status)" "usage-limit"
check "plain-text limit message is usage-limit" "$(field "$FX/limit-text.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit text on stderr with exit 1 is usage-limit" "$(field "$FX/no-result.jsonl" completion_status --exit-code 1 --stderr "$FX/limit.stderr")" "usage-limit"
check "limit text on stderr with exit 0 is ignored" "$(field "$FX/complete.jsonl" completion_status --stderr "$FX/limit.stderr")" "complete"
check "a successful result that mentions rate limits stays complete" "$(field "$FX/mentions-limit.jsonl" completion_status)" "complete"
check "exit 124 is timeout" "$(field "$FX/complete.jsonl" completion_status --exit-code 124)" "timeout"
check "no result object is error" "$(field "$FX/no-result.jsonl" completion_status --exit-code 1)" "error"
check "empty capture is error" "$(field /dev/null completion_status --exit-code 1)" "error"
check "tokens_total is input plus output plus cache write" "$(field "$FX/complete.jsonl" tokens_total)" "60"
check "cache read is kept but not in the total" "$(field "$FX/complete.jsonl" tokens_cache_read)" "400"
check "hook events counted" "$(field "$FX/complete.jsonl" hook_events)" "2"
check "SessionStart events counted" "$(field "$FX/complete.jsonl" session_start_events)" "2"
check "subagent spawns counted" "$(field "$FX/complete.jsonl" subagent_spawns)" "1"
check "tool calls counted" "$(field "$FX/complete.jsonl" tool_calls)" "2"
check "turns read from the result" "$(field "$FX/complete.jsonl" num_turns)" "7"
check "human interventions sum asks, denials, escalations" "$(field "$FX/stall-ask.jsonl" human_interventions_required --escalated 2)" "3"

echo "abtest-stream: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-stream checks passed."
exit "$fail"
~~~~
6. file: `tests/fixtures/abtest/streams/complete.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"system","subtype":"hook_started","hook_event":"SessionStart","hook_name":"SessionStart:startup"}
{"type":"system","subtype":"hook_response","hook_event":"SessionStart","hook_name":"SessionStart:startup"}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Agent","input":{}},{"type":"tool_use","name":"Bash","input":{}}]}}
{"type":"result","subtype":"success","is_error":false,"num_turns":7,"duration_api_ms":900,"total_cost_usd":1.5,"result":"done","permission_denials":[],"usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":30,"cache_read_input_tokens":400},"modelUsage":{"fable-x":{"inputTokens":10,"outputTokens":20,"cacheCreationInputTokens":30,"cacheReadInputTokens":400}}}
~~~~
7. file: `tests/fixtures/abtest/streams/denied.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"success","is_error":false,"num_turns":3,"result":"denied","permission_denials":[{"tool_name":"Bash"}],"usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":30,"cache_read_input_tokens":400},"modelUsage":{"fable-x":{"inputTokens":10,"outputTokens":20,"cacheCreationInputTokens":30,"cacheReadInputTokens":400}}}
~~~~
8. file: `tests/fixtures/abtest/streams/limit-event.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"rate_limit_event","rate_limit_info":{"status":"rejected"}}
{"type":"result","subtype":"error_during_execution","is_error":true,"num_turns":1,"result":"boom","usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":30,"cache_read_input_tokens":400},"modelUsage":{"fable-x":{"inputTokens":10,"outputTokens":20,"cacheCreationInputTokens":30,"cacheReadInputTokens":400}}}
~~~~
9. file: `tests/fixtures/abtest/streams/limit-text.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
Claude AI usage limit reached|1760000000
~~~~
10. file: `tests/fixtures/abtest/streams/limit.stderr`
   anchor: new file
   indent: 0
   insert-after:
~~~~
5-hour limit reached - resets 3pm
~~~~
11. file: `tests/fixtures/abtest/streams/max-turns.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_max_turns","is_error":true,"num_turns":100,"result":"","usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":30,"cache_read_input_tokens":400},"modelUsage":{"fable-x":{"inputTokens":10,"outputTokens":20,"cacheCreationInputTokens":30,"cacheReadInputTokens":400}}}
~~~~
12. file: `tests/fixtures/abtest/streams/mentions-limit.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"success","is_error":false,"num_turns":4,"result":"I added a rate limit to the API and a quota check","usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":30,"cache_read_input_tokens":400},"modelUsage":{"fable-x":{"inputTokens":10,"outputTokens":20,"cacheCreationInputTokens":30,"cacheReadInputTokens":400}}}
~~~~
13. file: `tests/fixtures/abtest/streams/no-result.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"assistant","message":{"content":[{"type":"text","text":"hi"}]}}
~~~~
14. file: `tests/fixtures/abtest/streams/stall-ask.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"AskUserQuestion","input":{}}]}}
{"type":"result","subtype":"success","is_error":false,"num_turns":3,"result":"asked","usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":30,"cache_read_input_tokens":400},"modelUsage":{"fable-x":{"inputTokens":10,"outputTokens":20,"cacheCreationInputTokens":30,"cacheReadInputTokens":400}}}
~~~~
15. command: `chmod +x eval/abtest/lib/stream.py tests/abtest-stream.test.sh`
   expect: 0
16. command: `git add eval/abtest/lib/stream.py tests/abtest-stream.test.sh tests/fixtures/abtest/streams/complete.jsonl tests/fixtures/abtest/streams/denied.jsonl tests/fixtures/abtest/streams/limit-event.jsonl tests/fixtures/abtest/streams/limit-text.jsonl tests/fixtures/abtest/streams/limit.stderr tests/fixtures/abtest/streams/max-turns.jsonl tests/fixtures/abtest/streams/mentions-limit.jsonl tests/fixtures/abtest/streams/no-result.jsonl tests/fixtures/abtest/streams/stall-ask.jsonl && git commit -m "feat(abt-u02): stream summariser and completion-status classifier (#570)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/arms/` (unit abt-u01 owns the arm scripts)
- `eval/harness/` (the one-arm pilot harness stays untouched)
- `tests/validate.sh` (merge-gate registration of the new tests is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-stream.test.sh`
   exit: 0
   stdout: `All abtest-stream checks passed.`
   mutation: skip edit 8 (limit-event.jsonl); the rate_limit_event row FAILs, the script exits non-zero and the fragment is absent.
2. run: `python3 -I eval/abtest/lib/stream.py summarize tests/fixtures/abtest/streams/complete.jsonl | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d["completion_status"],d["tokens_total"],d["subagent_spawns"])'`
   exit: 0
   stdout: `complete 60 1`
   mutation: skip edit 6 (complete.jsonl); summarize exits non-zero on the missing capture and nothing prints.
3. run: `python3 -I eval/abtest/lib/stream.py summarize tests/fixtures/abtest/streams/limit-text.jsonl --exit-code 1 | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d["completion_status"])'`
   exit: 0
   stdout: `usage-limit`
   mutation: skip edit 9 (limit-text.jsonl); summarize exits non-zero on the missing capture and nothing prints.
4. run: `python3 -I eval/abtest/lib/stream.py summarize tests/fixtures/abtest/streams/mentions-limit.jsonl | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d["completion_status"])'`
   exit: 0
   stdout: `complete`
   mutation: skip edit 12 (mentions-limit.jsonl); summarize exits non-zero on the missing capture and nothing prints.
5. run: `grep -c '^if __name__' eval/abtest/lib/stream.py`
   exit: 0
   stdout: `1`
   mutation: skip edit 4 (the last part of stream.py, which holds the __main__ guard); stdout 0 and the exit is 1.
6. run: `test -x eval/abtest/lib/stream.py && test -x tests/abtest-stream.test.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: skip edit 15; the files are not executable and nothing prints.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u02\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/lib/stream.py tests/abtest-stream.test.sh tests/fixtures/abtest/streams/complete.jsonl tests/fixtures/abtest/streams/denied.jsonl tests/fixtures/abtest/streams/limit-event.jsonl tests/fixtures/abtest/streams/limit-text.jsonl tests/fixtures/abtest/streams/limit.stderr tests/fixtures/abtest/streams/max-turns.jsonl tests/fixtures/abtest/streams/mentions-limit.jsonl tests/fixtures/abtest/streams/no-result.jsonl tests/fixtures/abtest/streams/stall-ask.jsonl`
   mutation: skip edit 16 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u02\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 16; no unit commit exists and the exit is 3.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u02\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/lib/stream.py tests/abtest-stream.test.sh tests/fixtures/abtest/streams/complete.jsonl tests/fixtures/abtest/streams/denied.jsonl tests/fixtures/abtest/streams/limit-event.jsonl tests/fixtures/abtest/streams/limit-text.jsonl tests/fixtures/abtest/streams/limit.stderr tests/fixtures/abtest/streams/max-turns.jsonl tests/fixtures/abtest/streams/mentions-limit.jsonl tests/fixtures/abtest/streams/no-result.jsonl tests/fixtures/abtest/streams/stall-ask.jsonl | grep -vcE "^[a-z]+\(abt-u02\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
10. run: `git status --porcelain -- eval/abtest/lib tests/abtest-stream.test.sh tests/fixtures/abtest/streams`
   exit: 0
   stdout: empty
   mutation: skip edit 16; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-stream.test.sh (criteria 1-4 are the red-then-green checks; none of the files exist at HEAD)
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 10 (the scoped clean-tree check) passes at HEAD by design, because no file of the unit exists yet; it turns red only when the commit step is skipped.
no-real-claude: no command in this contract runs the real claude CLI; the fixtures are canned captures. Never run a headless claude in this unit.
stream-format-note: the hook-event and rate-limit record shapes in stream.py and the fixtures are best-effort guesses of Claude Code 2.1.300 stream-json; the operator-run pilot (abt-u19) checks them against a real capture. Do not change them here.
commit-message: feat(abt-u02): stream summariser and completion-status classifier (#570)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u02 (#570)
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
