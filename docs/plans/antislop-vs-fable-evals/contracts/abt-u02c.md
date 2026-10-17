Unit: abt-u02c

## Objective
stream.py classifies usage-limit when a result or non-JSON text opens, after stripping whitespace and invisible characters, with the CLI limit wordings (Claude, Claude AI, Opus, Sonnet or Haiku, an optional usage, weekly, 5-hour or session kind, limit reached; you have or you've hit your limit; an optional Error: or API Error: prefix) or with API Error: 429 carrying the rate_limit_error type; a text that only mentions limits, 429 or rate_limit_error stays a plain error; tests/abtest-stream.test.sh gains 15 positive and 8 near-miss rows with one-line captures. One commit.

## Retrieval
GitHub issues: `gh issue view 598 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/lib/stream.py` (anchor: line matching `LIMIT_TEXT_RE = re.compile(`)
- `tests/abtest-stream.test.sh` (anchor: line matching `the hit-your-limit phrase is usage-limit`)
- `tests/fixtures/abtest/streams/lim-claude-usage.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/lim-opus-weekly.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/lim-sonnet-session.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/lim-haiku-weekly.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/lim-session.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/lim-5hour.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/lim-error-prefix.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/lim-api-error-prefix.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/lim-bom.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/lim-zerowidth.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/lim-leading-space.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/lim-have-hit.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/lim-curly-hit.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/lim-429-token.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/men-429-retry.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/men-handle.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/men-session-mid.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/men-token-name.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/men-error-429.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/men-bare-limit.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/men-hit-retries.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/men-quoted-end.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/men-session-cart.jsonl` (anchor: new file)
- `tests/fixtures/abtest/streams/lim-noise-tab.jsonl` (anchor: new file)

## Ordered edits
1. command: `test -f eval/abtest/lib/stream.py && test -f tests/abtest-stream.test.sh && ! grep -q "def clean" eval/abtest/lib/stream.py && test ! -e tests/fixtures/abtest/streams/lim-bom.jsonl && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/lib/stream.py`
   anchor: line matching `LIMIT_TEXT_RE = re.compile(`
   indent: 0
   before:
~~~~
LIMIT_TEXT_RE = re.compile(
    r"(claude ai usage limit reached|usage limit reached|you(?:'|\u2019)ve hit your (?:usage |weekly |5-hour )?limit|5-hour limit reached|weekly limit reached)",
    re.IGNORECASE,
)
~~~~
   after:
~~~~
_WHO = r"(?:claude(?: ai)? |opus |sonnet |haiku )"
_KIND = r"(?:usage |weekly |5-hour |session )"
_END = r"(?=\s*(?:[\u00b7\u2219.,|:;\u2014-]|$))"
LIMIT_TEXT_RE = re.compile(
    r"(?:(?:api )?error:\s*)?(?:"
    r"(?:" + _WHO + _KIND + r"?|" + _KIND + r")limit reached" + _END +
    r"|you(?:'ve|\u2019ve| have) hit your " + _KIND + r"?limit" + _END +
    r"|(?:api )?error:\s*429\b[^\n]*\brate_limit_error\b)",
    re.IGNORECASE,
)
INVISIBLE = "\ufeff\u200b\u200c\u200d\u2060"


def clean(text):
    """Strip whitespace and invisible characters from both ends of a text."""
    return str(text).strip(" \t\r\n\f\v" + INVISIBLE)
~~~~
3. file: `eval/abtest/lib/stream.py`
   anchor: line matching `texts = [str(`
   before: `        texts = [str((result or {}).get("result", "")).strip()] + [n.strip() for n in noise.split("\n")]`
   after: `        texts = [clean((result or {}).get("result", ""))] + [clean(n) for n in noise.split("\n")]`
4. file: `tests/abtest-stream.test.sh`
   anchor: line matching `the hit-your-limit phrase is usage-limit`
   indent: 0
   insert-after:
~~~~
# Wider limit wordings (abt-u02c): each positive capture is a real or documented limit message and must be usage-limit;
# each near-miss only mentions limits, 429 or rate_limit_error and must stay a plain error.
check "limit wording: Claude usage limit reached with a reset sentence" "$(field "$FX/lim-claude-usage.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: Opus weekly limit reached with a reset time" "$(field "$FX/lim-opus-weekly.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: Sonnet session limit reached" "$(field "$FX/lim-sonnet-session.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: Haiku weekly limit reached" "$(field "$FX/lim-haiku-weekly.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: Session limit reached on its own" "$(field "$FX/lim-session.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: 5-hour limit reached on its own" "$(field "$FX/lim-5hour.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: Error: prefix before the Claude AI phrase" "$(field "$FX/lim-error-prefix.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: API Error: prefix before the usage phrase" "$(field "$FX/lim-api-error-prefix.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: a byte order mark in front of the phrase" "$(field "$FX/lim-bom.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: a zero-width space in front of the phrase" "$(field "$FX/lim-zerowidth.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: leading blank lines and spaces in front of the phrase" "$(field "$FX/lim-leading-space.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: you have hit your limit" "$(field "$FX/lim-have-hit.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: curly-apostrophe weekly hit-your-limit" "$(field "$FX/lim-curly-hit.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: API Error 429 that carries the rate_limit_error type" "$(field "$FX/lim-429-token.jsonl" completion_status --exit-code 1)" "usage-limit"
ZW="$(mktemp -d)"
trap 'rm -rf "$ZW"' EXIT
printf '\xef\xbb\xbfClaude AI usage limit reached|1760000000\n' > "$ZW/bom-noise.jsonl"
printf '\xe2\x80\x8bClaude AI usage limit reached|1760000000\n' > "$ZW/zw-noise.jsonl"
check "limit wording: a byte order mark before a plain-text limit line" "$(field "$ZW/bom-noise.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: a zero-width space before a plain-text limit line" "$(field "$ZW/zw-noise.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: a tab-indented plain-text limit line" "$(field "$FX/lim-noise-tab.jsonl" completion_status --exit-code 1)" "usage-limit"
check "near miss stays an error: API Error 429 without the rate_limit_error token" "$(field "$FX/men-429-retry.jsonl" completion_status --exit-code 1)" "error"
check "near miss stays an error: an answer about handling 429 and rate limit errors" "$(field "$FX/men-handle.jsonl" completion_status --exit-code 1)" "error"
check "near miss stays an error: a session limit message quoted mid-text" "$(field "$FX/men-session-mid.jsonl" completion_status --exit-code 1)" "error"
check "near miss stays an error: the rate_limit_error type name at the start" "$(field "$FX/men-token-name.jsonl" completion_status --exit-code 1)" "error"
check "near miss stays an error: Error: 429 Too Many Requests from a test server" "$(field "$FX/men-error-429.jsonl" completion_status --exit-code 1)" "error"
check "near miss stays an error: a bare Limit reached sentence about a cart" "$(field "$FX/men-bare-limit.jsonl" completion_status --exit-code 1)" "error"
check "near miss stays an error: hitting a limit of 5 retries in a test" "$(field "$FX/men-hit-retries.jsonl" completion_status --exit-code 1)" "error"
check "near miss stays an error: a limit phrase quoted at the end of a sentence" "$(field "$FX/men-quoted-end.jsonl" completion_status --exit-code 1)" "error"
check "near miss stays an error: Session limit reached for a cart module" "$(field "$FX/men-session-cart.jsonl" completion_status --exit-code 1)" "error"
~~~~
5. file: `tests/fixtures/abtest/streams/lim-claude-usage.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"Claude usage limit reached. Your limit will reset at 5pm"}
~~~~
6. file: `tests/fixtures/abtest/streams/lim-opus-weekly.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"Opus weekly limit reached \u2219 resets Oct 20, 3pm"}
~~~~
7. file: `tests/fixtures/abtest/streams/lim-sonnet-session.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"Sonnet session limit reached \u2219 resets 3pm"}
~~~~
8. file: `tests/fixtures/abtest/streams/lim-haiku-weekly.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"Haiku weekly limit reached \u2219 resets Monday"}
~~~~
9. file: `tests/fixtures/abtest/streams/lim-session.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"Session limit reached \u2219 resets 3pm"}
~~~~
10. file: `tests/fixtures/abtest/streams/lim-5hour.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"5-hour limit reached \u2219 resets 2pm"}
~~~~
11. file: `tests/fixtures/abtest/streams/lim-error-prefix.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"Error: Claude AI usage limit reached"}
~~~~
12. file: `tests/fixtures/abtest/streams/lim-api-error-prefix.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"API Error: Claude usage limit reached|1760000000"}
~~~~
13. file: `tests/fixtures/abtest/streams/lim-bom.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"\ufeffClaude AI usage limit reached|1760000000"}
~~~~
14. file: `tests/fixtures/abtest/streams/lim-zerowidth.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"\u200bClaude AI usage limit reached"}
~~~~
15. file: `tests/fixtures/abtest/streams/lim-leading-space.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":" \n  Claude AI usage limit reached"}
~~~~
16. file: `tests/fixtures/abtest/streams/lim-have-hit.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"You have hit your limit \u00b7 resets 3pm"}
~~~~
17. file: `tests/fixtures/abtest/streams/lim-curly-hit.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"You\u2019ve hit your weekly limit \u00b7 resets Monday"}
~~~~
18. file: `tests/fixtures/abtest/streams/lim-429-token.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"API Error: 429 {\"type\":\"error\",\"error\":{\"type\":\"rate_limit_error\",\"message\":\"Number of requests has exceeded your rate limit.\"}}"}
~~~~
19. file: `tests/fixtures/abtest/streams/men-429-retry.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"API Error: 429 returned by the upstream, so we should retry"}
~~~~
20. file: `tests/fixtures/abtest/streams/men-handle.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"We should handle 429 and rate limit errors in the client."}
~~~~
21. file: `tests/fixtures/abtest/streams/men-session-mid.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"The session limit reached message appears in the log."}
~~~~
22. file: `tests/fixtures/abtest/streams/men-token-name.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"rate_limit_error is the type name the API uses for 429."}
~~~~
23. file: `tests/fixtures/abtest/streams/men-error-429.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"Error: 429 Too Many Requests from the test server"}
~~~~
24. file: `tests/fixtures/abtest/streams/men-bare-limit.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"Limit reached: the cart holds five items."}
~~~~
25. file: `tests/fixtures/abtest/streams/men-hit-retries.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"You have hit your limit of 5 retries in the test."}
~~~~
26. file: `tests/fixtures/abtest/streams/men-quoted-end.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"The log line said Claude usage limit reached."}
~~~~
27. file: `tests/fixtures/abtest/streams/men-session-cart.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
{"type":"result","subtype":"error_during_execution","is_error":true,"result":"Session limit reached for the cart module."}
~~~~
28. file: `tests/fixtures/abtest/streams/lim-noise-tab.jsonl`
   anchor: new file
   indent: 0
   insert-after:
~~~~
	Claude AI usage limit reached|1760000000
~~~~
29. command: `git add eval/abtest/lib/stream.py tests/abtest-stream.test.sh tests/fixtures/abtest/streams/lim-claude-usage.jsonl tests/fixtures/abtest/streams/lim-opus-weekly.jsonl tests/fixtures/abtest/streams/lim-sonnet-session.jsonl tests/fixtures/abtest/streams/lim-haiku-weekly.jsonl tests/fixtures/abtest/streams/lim-session.jsonl tests/fixtures/abtest/streams/lim-5hour.jsonl tests/fixtures/abtest/streams/lim-error-prefix.jsonl tests/fixtures/abtest/streams/lim-api-error-prefix.jsonl tests/fixtures/abtest/streams/lim-bom.jsonl tests/fixtures/abtest/streams/lim-zerowidth.jsonl tests/fixtures/abtest/streams/lim-leading-space.jsonl tests/fixtures/abtest/streams/lim-have-hit.jsonl tests/fixtures/abtest/streams/lim-curly-hit.jsonl tests/fixtures/abtest/streams/lim-429-token.jsonl tests/fixtures/abtest/streams/men-429-retry.jsonl tests/fixtures/abtest/streams/men-handle.jsonl tests/fixtures/abtest/streams/men-session-mid.jsonl tests/fixtures/abtest/streams/men-token-name.jsonl tests/fixtures/abtest/streams/men-error-429.jsonl tests/fixtures/abtest/streams/men-bare-limit.jsonl tests/fixtures/abtest/streams/men-hit-retries.jsonl tests/fixtures/abtest/streams/men-quoted-end.jsonl tests/fixtures/abtest/streams/men-session-cart.jsonl tests/fixtures/abtest/streams/lim-noise-tab.jsonl && git commit -m "fix(abt-u02c): stream.py recognises the real limit wordings and still ignores mentions (#598)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `tests/fixtures/abtest/streams/` captures that already exist (mention-error, mention-mid, limit-anchored, limit-hit, limit-text and the rest stay as landed)
- `eval/abtest/lib/make-row.py`, `eval/abtest/score.py`, `eval/abtest/run-matrix.sh` (other units own them)
- `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-stream.test.sh`
   exit: 0
   stdout: `All abtest-stream checks passed.`
   mutation: skip edit 2 (the widened pattern); the positive rows FAIL, the script exits non-zero and the fragment is absent.
   proof: mutation matrix, run in a scratch copy of the finished change, each making bash tests/abtest-stream.test.sh exit non-zero: M1 drop the opus, sonnet and haiku words; M2 drop the session kind; M3 drop the 5-hour kind; M4 drop the weekly kind; M5 drop the usage kind; M6 drop the optional error prefix; M7 replace clean() on the result text by a bare strip(); M8 drop the invisible characters from clean(); M9 replace clean() on the non-JSON lines by a bare strip(); M10 drop the you-have alternative; M11 drop the curly apostrophe; M12 drop the rate_limit_error alternative; M13 accept error 429 without the rate_limit_error token; M14 delete the end-of-phrase lookahead; M15 let a bare limit reached match; M16 replace match by search; M17 delete the claude ai spelling.
2. run: `bash tests/abtest-stream.test.sh | grep -c '^ok   limit wording'`
   exit: 0
   stdout: `17`
   mutation: skip edit 2; the positive rows FAIL and the count drops.
3. run: `bash tests/abtest-stream.test.sh | grep -c '^ok   near miss stays an error'`
   exit: 0
   stdout: `9`
   mutation: delete the end-of-phrase lookahead from the pattern; the limit-of-5-retries and cart near misses turn into usage-limit, their rows FAIL and the count drops below 9.
   proof: mutation M14 of the matrix in criterion 1, run in a scratch copy: the near-miss count printed 7.
4. run: `python3 -I eval/abtest/lib/stream.py summarize tests/fixtures/abtest/streams/lim-opus-weekly.jsonl --exit-code 1 | python3 -I -c 'import json,sys;print(json.load(sys.stdin)["completion_status"])'`
   exit: 0
   stdout: `usage-limit`
   mutation: skip edit 2; the old pattern does not know the Opus wording and prints error.
5. run: `python3 -I eval/abtest/lib/stream.py summarize tests/fixtures/abtest/streams/lim-bom.jsonl --exit-code 1 | python3 -I -c 'import json,sys;print(json.load(sys.stdin)["completion_status"])'`
   exit: 0
   stdout: `usage-limit`
   mutation: skip edit 3; a bare strip() leaves the byte order mark and prints error.
6. run: `python3 -I eval/abtest/lib/stream.py summarize tests/fixtures/abtest/streams/men-429-retry.jsonl --exit-code 1 | python3 -I -c 'import json,sys;print(json.load(sys.stdin)["completion_status"])'`
   exit: 0
   stdout: `error`
   mutation: skip edit 19 (the capture); the file is missing, python raises and nothing prints.
7. run: `grep -c 'def clean' eval/abtest/lib/stream.py`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; stdout 0 and the exit is 1.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u02c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/lib/stream.py tests/abtest-stream.test.sh tests/fixtures/abtest/streams/lim-429-token.jsonl tests/fixtures/abtest/streams/lim-5hour.jsonl tests/fixtures/abtest/streams/lim-api-error-prefix.jsonl tests/fixtures/abtest/streams/lim-bom.jsonl tests/fixtures/abtest/streams/lim-claude-usage.jsonl tests/fixtures/abtest/streams/lim-curly-hit.jsonl tests/fixtures/abtest/streams/lim-error-prefix.jsonl tests/fixtures/abtest/streams/lim-haiku-weekly.jsonl tests/fixtures/abtest/streams/lim-have-hit.jsonl tests/fixtures/abtest/streams/lim-leading-space.jsonl tests/fixtures/abtest/streams/lim-noise-tab.jsonl tests/fixtures/abtest/streams/lim-opus-weekly.jsonl tests/fixtures/abtest/streams/lim-session.jsonl tests/fixtures/abtest/streams/lim-sonnet-session.jsonl tests/fixtures/abtest/streams/lim-zerowidth.jsonl tests/fixtures/abtest/streams/men-429-retry.jsonl tests/fixtures/abtest/streams/men-bare-limit.jsonl tests/fixtures/abtest/streams/men-error-429.jsonl tests/fixtures/abtest/streams/men-handle.jsonl tests/fixtures/abtest/streams/men-hit-retries.jsonl tests/fixtures/abtest/streams/men-quoted-end.jsonl tests/fixtures/abtest/streams/men-session-cart.jsonl tests/fixtures/abtest/streams/men-session-mid.jsonl tests/fixtures/abtest/streams/men-token-name.jsonl`
   mutation: skip edit 29 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u02c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 29; no unit commit exists and the exit is 3.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u02c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/lib/stream.py tests/abtest-stream.test.sh tests/fixtures/abtest/streams/lim-claude-usage.jsonl tests/fixtures/abtest/streams/lim-opus-weekly.jsonl tests/fixtures/abtest/streams/lim-sonnet-session.jsonl tests/fixtures/abtest/streams/lim-haiku-weekly.jsonl tests/fixtures/abtest/streams/lim-session.jsonl tests/fixtures/abtest/streams/lim-5hour.jsonl tests/fixtures/abtest/streams/lim-error-prefix.jsonl tests/fixtures/abtest/streams/lim-api-error-prefix.jsonl tests/fixtures/abtest/streams/lim-bom.jsonl tests/fixtures/abtest/streams/lim-zerowidth.jsonl tests/fixtures/abtest/streams/lim-leading-space.jsonl tests/fixtures/abtest/streams/lim-have-hit.jsonl tests/fixtures/abtest/streams/lim-curly-hit.jsonl tests/fixtures/abtest/streams/lim-429-token.jsonl tests/fixtures/abtest/streams/men-429-retry.jsonl tests/fixtures/abtest/streams/men-handle.jsonl tests/fixtures/abtest/streams/men-session-mid.jsonl tests/fixtures/abtest/streams/men-token-name.jsonl tests/fixtures/abtest/streams/men-error-429.jsonl tests/fixtures/abtest/streams/men-bare-limit.jsonl tests/fixtures/abtest/streams/men-hit-retries.jsonl tests/fixtures/abtest/streams/men-quoted-end.jsonl tests/fixtures/abtest/streams/men-session-cart.jsonl tests/fixtures/abtest/streams/lim-noise-tab.jsonl | grep -vcE "^[a-z]+\(abt-u02c\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
11. run: `git status --porcelain -- eval/abtest/lib/stream.py tests/abtest-stream.test.sh tests/fixtures/abtest/streams/lim-claude-usage.jsonl tests/fixtures/abtest/streams/lim-opus-weekly.jsonl tests/fixtures/abtest/streams/lim-sonnet-session.jsonl tests/fixtures/abtest/streams/lim-haiku-weekly.jsonl tests/fixtures/abtest/streams/lim-session.jsonl tests/fixtures/abtest/streams/lim-5hour.jsonl tests/fixtures/abtest/streams/lim-error-prefix.jsonl tests/fixtures/abtest/streams/lim-api-error-prefix.jsonl tests/fixtures/abtest/streams/lim-bom.jsonl tests/fixtures/abtest/streams/lim-zerowidth.jsonl tests/fixtures/abtest/streams/lim-leading-space.jsonl tests/fixtures/abtest/streams/lim-have-hit.jsonl tests/fixtures/abtest/streams/lim-curly-hit.jsonl tests/fixtures/abtest/streams/lim-429-token.jsonl tests/fixtures/abtest/streams/men-429-retry.jsonl tests/fixtures/abtest/streams/men-handle.jsonl tests/fixtures/abtest/streams/men-session-mid.jsonl tests/fixtures/abtest/streams/men-token-name.jsonl tests/fixtures/abtest/streams/men-error-429.jsonl tests/fixtures/abtest/streams/men-bare-limit.jsonl tests/fixtures/abtest/streams/men-hit-retries.jsonl tests/fixtures/abtest/streams/men-quoted-end.jsonl tests/fixtures/abtest/streams/men-session-cart.jsonl tests/fixtures/abtest/streams/lim-noise-tab.jsonl`
   exit: 0
   stdout: empty
   mutation: skip edit 29; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-stream.test.sh (criteria 2, 4 and 5 are the red-then-green checks: the new captures and wordings do not exist at HEAD)
blast-radius: eval/abtest/lib/stream.py:26
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 1 (the whole suite passes at HEAD; the new rows are criteria 2, 4 and 5) and criterion 11 (the scoped clean-tree check) pass at HEAD by design.
extends-landed-code: abt-u02b is on master (commit 035ee430). Edits are a two-spot replacement in stream.py, an insertion after one test row and new one-line captures; nothing is rewritten. The old pattern missed real wordings (reviewer finding on abt-u02b): a real limit read as an error would count as a failed run, against OD-4.
fail-closed: every row compares an explicit status word; a crash or empty output reads as FAILURE. The 429 signal counts only when the text opens with API Error: 429 and carries the rate_limit_error type token; a bare 429 never counts.
tab-capture: lim-noise-tab.jsonl starts with a TAB character (not spaces); keep it, it pins that non-JSON lines are cleaned too. Write the file with the Write or Edit tool so the tab survives.
pinned-samples: when the operator pilot (abt-u19) sees a real limit-hit stream it is saved as a pinned sample under tests/fixtures/abtest/streams/ and gets its own row; the wordings here come from documented and reviewer-quoted messages, not yet from a capture.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u02c): stream.py recognises the real limit wordings and still ignores mentions (#598)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u02c (#598)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
