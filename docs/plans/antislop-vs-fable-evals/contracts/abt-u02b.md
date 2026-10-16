Unit: abt-u02b

## Objective
stream.py classifies usage-limit from a result or non-JSON line only when the text opens with the CLI limit phrase (Claude AI usage limit reached, usage limit reached, you have hit your limit, 5-hour or weekly limit reached); a result that only mentions 429 or rate limits is an ordinary error; rate_limit_event and stderr evidence are unchanged; tests/abtest-stream.test.sh gains four rows and four canned captures. One commit.

## Retrieval
GitHub issues: `gh issue view 595 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/lib/stream.py` (anchor: line matching `SUBAGENT_TOOLS = ("Agent", "Task")`)
- `tests/abtest-stream.test.sh` (anchor: line matching `a successful result that mentions rate limits stays complete`)
- `tests/fixtures/abtest/streams/mention-error.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/mention-mid.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/limit-anchored.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/limit-hit.jsonl` (anchor: new file)

## Ordered edits
1. command: `test -f eval/abtest/lib/stream.py && test -f tests/abtest-stream.test.sh && ! grep -q LIMIT_TEXT_RE eval/abtest/lib/stream.py && test ! -e tests/fixtures/abtest/streams/mention-error.jsonl && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/lib/stream.py`
   anchor: line matching `SUBAGENT_TOOLS = ("Agent", "Task")`
   indent: 0
   insert-after:
~~~~
LIMIT_TEXT_RE = re.compile(
    r"(claude ai usage limit reached|usage limit reached|you(?:'|\u2019)ve hit your (?:usage |weekly |5-hour )?limit|5-hour limit reached|weekly limit reached)",
    re.IGNORECASE,
)
~~~~
3. file: `eval/abtest/lib/stream.py`
   anchor: line matching `    if result is None or result.get("is_error"):`
   indent: 0
   before:
~~~~
    if result is None or result.get("is_error"):
        if LIMIT_RE.search(str((result or {}).get("result", "")) + "\n" + noise):
            limited = True
~~~~
   after:
~~~~
    if result is None or result.get("is_error"):
        # Only the CLI's own limit phrasing at the start of a text counts; a result that merely
        # mentions 429 or rate limits (an eval about rate limiting) is an ordinary error.
        texts = [str((result or {}).get("result", "")).strip()] + [n.strip() for n in noise.split("\n")]
        if any(LIMIT_TEXT_RE.match(t) for t in texts):
            limited = True
~~~~
4. file: `tests/abtest-stream.test.sh`
   anchor: line matching `check "a successful result that mentions rate limits stays complete"`
   indent: 0
   insert-after:
~~~~
check "an error result that only mentions 429 and rate limits is an error" "$(field "$FX/mention-error.jsonl" completion_status --exit-code 1)" "error"
check "a limit phrase in the middle of an error result is an error" "$(field "$FX/mention-mid.jsonl" completion_status --exit-code 1)" "error"
check "an error result that opens with the CLI limit phrase is usage-limit" "$(field "$FX/limit-anchored.jsonl" completion_status --exit-code 1)" "usage-limit"
check "the hit-your-limit phrase is usage-limit" "$(field "$FX/limit-hit.jsonl" completion_status --exit-code 1)" "usage-limit"
~~~~
5. file: `tests/fixtures/abtest/streams/mention-error.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"num_turns":3,"result":"My test hit HTTP 429 and a rate limit in the code under test; fix the retry loop.","usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":30,"cache_read_input_tokens":400},"modelUsage":{"fable-x":{"inputTokens":10,"outputTokens":20,"cacheCreationInputTokens":30,"cacheReadInputTokens":400}}}
~~~~
6. file: `tests/fixtures/abtest/streams/mention-mid.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"num_turns":3,"result":"The run failed. The string Claude AI usage limit reached appeared in a log line I was grepping.","usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":30,"cache_read_input_tokens":400},"modelUsage":{"fable-x":{"inputTokens":10,"outputTokens":20,"cacheCreationInputTokens":30,"cacheReadInputTokens":400}}}
~~~~
7. file: `tests/fixtures/abtest/streams/limit-anchored.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"num_turns":3,"result":"Claude AI usage limit reached|1760000000","usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":30,"cache_read_input_tokens":400},"modelUsage":{"fable-x":{"inputTokens":10,"outputTokens":20,"cacheCreationInputTokens":30,"cacheReadInputTokens":400}}}
~~~~
8. file: `tests/fixtures/abtest/streams/limit-hit.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"num_turns":3,"result":"You've hit your limit · resets 3pm","usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":30,"cache_read_input_tokens":400},"modelUsage":{"fable-x":{"inputTokens":10,"outputTokens":20,"cacheCreationInputTokens":30,"cacheReadInputTokens":400}}}
~~~~
9. command: `git add eval/abtest/lib/stream.py tests/abtest-stream.test.sh tests/fixtures/abtest/streams/mention-error.jsonl tests/fixtures/abtest/streams/mention-mid.jsonl tests/fixtures/abtest/streams/limit-anchored.jsonl tests/fixtures/abtest/streams/limit-hit.jsonl && git commit -m "fix(abt-u02b): stream.py classifies usage-limit only on the CLI limit phrase, not on a mention (#595)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `tests/fixtures/abtest/streams/complete.jsonl`, `tests/fixtures/abtest/streams/limit-event.jsonl`, `tests/fixtures/abtest/streams/limit-text.jsonl`, `tests/fixtures/abtest/streams/mentions-limit.jsonl` and the other landed captures (they stay as they are)
- `eval/abtest/lib/make-row.py`, `eval/abtest/score.py`, `eval/abtest/run-matrix.sh` (other units own them; the runner caps repeats of a usage-limit run itself)
- `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-stream.test.sh`
   exit: 0
   stdout: `All abtest-stream checks passed.`
   mutation: skip edit 3 (the narrowed block); the mention rows FAIL, the script exits non-zero and the fragment is absent.
   proof: mutation matrix, run in a scratch copy of the finished change, each making bash tests/abtest-stream.test.sh exit non-zero: M1 restore LIMIT_RE.search over the result text; M2 replace LIMIT_TEXT_RE.match by .search; M3 drop the noise lines from texts; M4 drop the result text from texts; M5 delete the hit-your-limit alternative.
2. run: `python3 -I eval/abtest/lib/stream.py summarize tests/fixtures/abtest/streams/mention-error.jsonl --exit-code 1 | python3 -I -c 'import json,sys;print(json.load(sys.stdin)["completion_status"])'`
   exit: 0
   stdout: `error`
   mutation: skip edit 3; the old regex reads 429 and rate limit in the text and prints usage-limit.
3. run: `python3 -I eval/abtest/lib/stream.py summarize tests/fixtures/abtest/streams/mention-mid.jsonl --exit-code 1 | python3 -I -c 'import json,sys;print(json.load(sys.stdin)["completion_status"])'`
   exit: 0
   stdout: `error`
   mutation: skip edit 3; the old regex finds the phrase anywhere and prints usage-limit.
4. run: `python3 -I eval/abtest/lib/stream.py summarize tests/fixtures/abtest/streams/limit-anchored.jsonl --exit-code 1 | python3 -I -c 'import json,sys;print(json.load(sys.stdin)["completion_status"])'`
   exit: 0
   stdout: `usage-limit`
   mutation: skip edit 2 (the new pattern); the block names LIMIT_TEXT_RE, python raises NameError and nothing prints.
5. run: `python3 -I eval/abtest/lib/stream.py summarize tests/fixtures/abtest/streams/limit-hit.jsonl --exit-code 1 | python3 -I -c 'import json,sys;print(json.load(sys.stdin)["completion_status"])'`
   exit: 0
   stdout: `usage-limit`
   mutation: skip edit 2; python raises NameError and nothing prints.
6. run: `python3 -I eval/abtest/lib/stream.py summarize tests/fixtures/abtest/streams/limit-text.jsonl --exit-code 1 | python3 -I -c 'import json,sys;print(json.load(sys.stdin)["completion_status"])'`
   exit: 0
   stdout: `usage-limit`
   mutation: skip edit 2; python raises NameError and nothing prints.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u02b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/lib/stream.py tests/abtest-stream.test.sh tests/fixtures/abtest/streams/limit-anchored.jsonl tests/fixtures/abtest/streams/limit-hit.jsonl tests/fixtures/abtest/streams/mention-error.jsonl tests/fixtures/abtest/streams/mention-mid.jsonl`
   mutation: skip edit 9 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u02b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 9; no unit commit exists and the exit is 3.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u02b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/lib/stream.py tests/abtest-stream.test.sh tests/fixtures/abtest/streams/mention-error.jsonl tests/fixtures/abtest/streams/mention-mid.jsonl tests/fixtures/abtest/streams/limit-anchored.jsonl tests/fixtures/abtest/streams/limit-hit.jsonl | grep -vcE "^[a-z]+\(abt-u02b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
10. run: `git status --porcelain -- eval/abtest/lib/stream.py tests/abtest-stream.test.sh tests/fixtures/abtest/streams/mention-error.jsonl tests/fixtures/abtest/streams/mention-mid.jsonl tests/fixtures/abtest/streams/limit-anchored.jsonl tests/fixtures/abtest/streams/limit-hit.jsonl`
   exit: 0
   stdout: empty
   mutation: skip edit 9; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-stream.test.sh (criteria 2 to 5 are the red-then-green rows; the fixtures and the new pattern do not exist at HEAD)
blast-radius: eval/abtest/lib/stream.py:95
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 1 (the whole suite passes at HEAD; criteria 2 to 5 are the red-then-green rows), criterion 6 (the plain-text limit line) and criterion 10 (the scoped clean-tree check) pass at HEAD by design; criterion 6 stays green only if the narrowed block still reads the non-JSON lines.
extends-landed-code: abt-u02 is on master (commit e1bd4e6c). Edits are anchored on lines that exist there; no file is rewritten. LIMIT_RE stays for stderr (exit code non-zero only) and is not touched.
why: the runner repeats usage-limit rows on resume, so a result that merely mentions 429 or rate limits (an eval about rate limiting) must not be classified usage-limit (carry-forward on abt-u02).
fail-closed: a crash or empty output in a row must read as FAILURE; the rows compare the printed status to an expected word, never only an exit code.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u02b): stream.py classifies usage-limit only on the CLI limit phrase, not on a mention (#595)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u02b (#595)
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
