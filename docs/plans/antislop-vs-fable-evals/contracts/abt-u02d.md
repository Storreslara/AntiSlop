Unit: abt-u02d

## Objective
stream.py classifies usage-limit when a result or non-JSON text opens, after stripping whitespace and invisible characters, with a CLI limit phrase (including You're out of extra usage and Rate limit reached) and then continues only with nothing, a trailing full stop or exclamation mark, a pipe and a 9 to 13 digit epoch, or a reset clause made only of time words; agent prose after the phrase, and a 429 without the compact rate_limit_error JSON, stay a plain error. tests/abtest-stream.test.sh grows from 51 to 144 rows: 72 more limit-wording rows (17 to 89), 20 more near-miss rows (9 to 29) and one success-result row. One commit.

## Retrieval
GitHub issues: `gh issue view 601 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/lib/stream.py` (anchor: line matching `_END = r"`)
- `tests/abtest-stream.test.sh` (anchor: line matching `near miss stays an error: Session limit reached for a cart module`)

## Ordered edits
1. command: `test -f eval/abtest/lib/stream.py && test -f tests/abtest-stream.test.sh && grep -q "def clean" eval/abtest/lib/stream.py && ! grep -q "_TAIL" eval/abtest/lib/stream.py && ! grep -q "x-mid-dot" tests/abtest-stream.test.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/lib/stream.py`
   anchor: line matching `_END = r"`
   indent: 0
   before:
~~~~
_END = r"(?=\s*(?:[\u00b7\u2219.,|:;\u2014-]|$))"
LIMIT_TEXT_RE = re.compile(
    r"(?:(?:api )?error:\s*)?(?:"
    r"(?:" + _WHO + _KIND + r"?|" + _KIND + r")limit reached" + _END +
    r"|you(?:'ve|\u2019ve| have) hit your " + _KIND + r"?limit" + _END +
    r"|(?:api )?error:\s*429\b[^\n]*\brate_limit_error\b)",
    re.IGNORECASE,
)
~~~~
   after:
~~~~
_SEP = r"[\u00b7\u2219\u2013\u2014|.,-]"
_DAY = r"(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)"
_MONTH = (r"(?:january|february|march|april|may|june|july|august|september|october|november|december"
          r"|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)")
_WHEN = (r"(?:\d{1,2}(?::\d{2})?\s?(?:am|pm)?|" + _DAY + "|" + _MONTH +
         r"|today|tomorrow|at|on|in|hours?|minutes?|days?|utc|\(\w+(?:/[\w+-]+)*\))")
_RESET = r"(?:your (?:\w+ )?limit )?(?:will )?resets?(?:[\s,]+" + _WHEN + r"){1,8}"
_TAIL = (r"(?:[.!]?$"
         r"|\|\d{9,13}$"
         r"|\s*(?:" + _SEP + r"\s*)?\(?" + _RESET + r"\)?[.!]?$)")
LIMIT_TEXT_RE = re.compile(
    r"(?:(?:api )?error:\s*)?(?:"
    r"(?:" + _WHO + _KIND + r"?|" + _KIND + r"|rate )limit reached"
    r"|you(?:'ve|\u2019ve| have) hit your " + _KIND + r"?limit"
    r"|(?:you(?:'re|\u2019re| are) )?out of extra usage"
    r")" + _TAIL +
    r'|(?:api )?error:\s*429 \{[^\n]*"type":"rate_limit_error"',
    re.IGNORECASE,
)
~~~~
3. file: `tests/abtest-stream.test.sh`
   anchor: line matching `near miss stays an error: Session limit reached for a cart module`
   indent: 0
   insert-after:
~~~~
# Stricter and wider limit wording (abt-u02d). Each capture below is written with JSON escapes only (no literal invisible
# or non-ASCII character): mkerr NAME TEXT writes an error result and mkok NAME TEXT a success result in $ZW.
mkerr() { printf '{"type":"result","subtype":"error_during_execution","is_error":true,"result":"%s"}\n' "$2" > "$ZW/$1.jsonl"; }
mkok() { printf '{"type":"result","subtype":"success","is_error":false,"result":"%s"}\n' "$2" > "$ZW/$1.jsonl"; }
lw() { mkerr "$1" "$3"; check "limit wording: $2" "$(field "$ZW/$1.jsonl" completion_status --exit-code 1)" "usage-limit"; }
nm() { mkerr "$1" "$3"; check "near miss stays an error: $2" "$(field "$ZW/$1.jsonl" completion_status --exit-code 1)" "error"; }
lw x-mid-dot "out of extra usage with a middle dot" 'You\u0027re out of extra usage \u00b7 resets 3pm'
lw x-bullet "out of extra usage with a curly apostrophe and a bullet operator" 'You\u2019re out of extra usage \u2219 resets Monday'
lw x-en-extra "out of extra usage with an en dash" 'You\u0027re out of extra usage \u2013 resets 3pm'
lw x-hyphen-extra "out of extra usage with a hyphen and a dated reset" 'You\u0027re out of extra usage - resets Oct 20, 3pm'
lw x-extra-alone "out of extra usage on its own" 'You\u0027re out of extra usage'
lw x-extra-bare "out of extra usage without the you-are" 'Out of extra usage \u00b7 resets 3pm'
lw x-you-are "you are out of extra usage" 'You are out of extra usage \u00b7 resets 3pm'
lw x-rate-pipe "API Error: Rate limit reached with a pipe and an epoch" 'API Error: Rate limit reached|1760000000'
lw x-bang-claude "a trailing exclamation mark after the Claude AI phrase" 'Claude AI usage limit reached!'
lw x-bang-hit "a trailing exclamation mark after hit your limit" 'You\u0027ve hit your limit!'
lw x-period-alone "a trailing full stop after the Claude AI phrase" 'Claude AI usage limit reached.'
lw x-reset-period "a full stop after the reset" 'Session limit reached \u2219 resets 3pm.'
lw x-reset-bang "an exclamation mark after the reset" 'Session limit reached \u2219 resets 3pm!'
lw x-en-dash "an en dash before the reset" 'Session limit reached \u2013 resets 3pm'
lw x-em-dash "an em dash before the reset" 'Session limit reached \u2014 resets 3pm'
lw x-paren "a parenthesised reset" 'Session limit reached (resets 3pm)'
lw x-tz "a reset with a time zone" 'Opus weekly limit reached \u2219 resets Oct 20, 3pm (America/New_York)'
lw x-comma "a comma before the reset" 'Session limit reached, resets 3pm'
lw x-pipe-reset "a pipe before the reset" 'Session limit reached | resets 3pm'
lw x-relative "a relative reset in hours" 'Claude usage limit reached. Your weekly limit will reset in 2 hours'
lw x-hour "a relative reset in one hour" 'Claude usage limit reached. Your limit will reset in 1 hour'
lw x-minutes "a relative reset in minutes" 'Claude usage limit reached. Your limit will reset in 30 minutes'
lw x-minute "a relative reset in one minute" 'Claude usage limit reached. Your limit will reset in 1 minute'
lw x-days "a relative reset in days" 'Session limit reached \u2219 resets in 3 days'
lw x-day "a relative reset in one day" 'Session limit reached \u2219 resets in 1 day'
lw x-on "a reset on a weekday" 'Session limit reached \u2219 resets on Monday'
lw x-tomorrow "a reset tomorrow" 'Session limit reached \u2219 resets tomorrow at 9am'
lw x-today-utc "a reset today in UTC" 'Session limit reached \u2219 resets today 9am UTC'
lw x-clock "a reset with minutes" 'Session limit reached \u2219 resets 10:30pm'
lw x-am "a reset in the morning" 'Session limit reached \u2219 resets 9am'
lw x-space-pm "a reset with a space before pm" 'Session limit reached \u2219 resets 3 pm'
lw x-two-lines "the reset on the second line" 'Claude usage limit reached.\nYour limit will reset at 5pm'
lw x-wordjoiner "a word joiner (U+2060) in front of the phrase" '\u2060Session limit reached \u2219 resets 3pm'
lw x-zwnj "a zero-width non-joiner (U+200C) in front of the phrase" '\u200cSession limit reached \u2219 resets 3pm'
lw x-zwj "a zero-width joiner (U+200D) in front of the phrase" '\u200dSession limit reached \u2219 resets 3pm'
nm y-usage-added "Usage limit reached followed by agent prose" 'Usage limit reached. I added a test for the retry path'
nm y-session-403 "Session limit reached, so the server returns 403" 'Session limit reached, so the server returns 403 for the next call'
nm y-hit-copy "hit your limit followed by agent prose" 'You\u0027ve hit your limit. That\u0027s the copy the banner shows'
nm y-error-429-py "error: 429 handling in rate_limit_error.py" 'error: 429 handling in rate_limit_error.py is untested'
nm y-resets-are "Resets used as a noun after the phrase" 'Usage limit reached. Resets are handled in billing.py'
nm y-resets-counter "a reset clause that is a sentence" 'Session limit reached - resets the counter after the fix'
nm y-resets-bare "a reset clause with no time" 'Usage limit reached. Resets'
nm y-reset-trailing "prose after a full reset clause" 'Session limit reached \u2219 resets 3pm and then I added a retry'
nm y-pipe-docs "a pipe followed by prose" 'Session limit reached | see the retry docs'
nm y-pipe-short "a pipe followed by a short number" 'Session limit reached|123'
nm y-pipe-trailing "prose after a pipe and an epoch" 'Session limit reached|1760000000 and I added a test'
nm y-extra-prose "out of extra usage followed by agent prose" 'You\u0027re out of extra usage, so I skipped the live test'
nm y-extra-mid "out of extra usage quoted mid-text" 'The banner said You\u0027re out of extra usage \u00b7 resets 3pm'
nm y-two-lines "the phrase then a prose line" 'Session limit reached\nI added a test for it'
nm y-rate-cart "Rate limit reached for an API under test" 'Rate limit reached for the cart API, so I added a retry'
nm y-credit "Credit balance is too low (API-key billing, out of scope)" 'Credit balance is too low'
nm y-overloaded "Error: Overloaded" 'Error: Overloaded'
nm y-529 "API Error 529" 'API Error: 529 {\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\",\"message\":\"Overloaded\"}}'
nm y-500 "API Error 500" 'API Error: 500 {\"type\":\"error\",\"error\":{\"type\":\"api_error\",\"message\":\"Internal server error\"}}'
nm y-429-overloaded "API Error 429 with a different error type" 'API Error: 429 {\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\"}}'
for d in Monday Tuesday Wednesday Thursday Friday Saturday Sunday Mon Tue Wed Thu Fri Sat Sun; do
  lw "d-$d" "the weekday $d in a reset" "Session limit reached \\u2219 resets $d"
done
for m in January February March April May June July August September October November December Jan Feb Mar Apr Jun Jul Aug Sep Oct Nov Dec; do
  lw "m-$m" "the month $m in a reset" "Session limit reached \\u2219 resets $m 20"
done
mkok z-success 'Session limit reached \u2219 resets 3pm'
check "a successful result that opens with a limit phrase stays complete" "$(field "$ZW/z-success.jsonl" completion_status)" "complete"
~~~~
4. command: `git add eval/abtest/lib/stream.py tests/abtest-stream.test.sh && git commit -m "fix(abt-u02d): stream.py reads the extra-usage and pipe-epoch limit wordings and stops reading agent prose as a limit (#601)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `tests/fixtures/abtest/streams/` (no new committed capture: the test writes its own into a temp directory; the landed ones stay as they are)
- `eval/abtest/lib/make-row.py`, `eval/abtest/score.py`, `eval/abtest/run-matrix.sh` (other units own them)
- `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-stream.test.sh`
   exit: 0
   stdout: `All abtest-stream checks passed.`
   mutation: skip edit 2 (the new pattern); the new rows FAIL, the script exits non-zero and the fragment is absent.
   proof: mutation matrix of 109 single edits to the finished stream.py, run in a scratch copy, each making bash tests/abtest-stream.test.sh exit non-zero: M01-M04 drop the extra-usage alternative, its optional you-are, its curly apostrophe or its you-are; M05 drop the rate alternative; M06-M09 drop the exclamation mark or the full stop from either ending; M10-M12 drop the pipe-epoch alternative, loosen its digit count or its end; M13-M14 delete either end anchor; M15-M22 drop one separator character (middle dot, bullet operator, en dash, em dash, pipe, full stop, comma, hyphen); M23-M24 drop the opening or closing parenthesis; M25-M28 drop will, the your-limit prefix, its middle word or the singular reset; M29-M30 allow an empty reset body or cap it at 3 words; M31-M32 drop the time zone word or its slash part; M33-M37 drop the clock minutes, the second hour digit, the space before pm, am or pm; M38-M46 drop each of today, tomorrow, at, on, in, hours, minutes, days (singular and plural separately) or utc; M47 remove the is_error test; M48-M50 loosen the 429 form; M51-M56 drop the invisible characters (all, then each of U+FEFF, U+200B, U+200C, U+200D, U+2060); M57 replace match by search; M58-M59 drop the Error: or API prefix; M60-M62 drop a whitespace gap around the separator; M64-M65 change the body separator; M66-M69 drop the full or short weekday names or month names; M70 drop the hit-your alternative; and one edit per weekday name, short weekday name, month name and short month name
2. run: `bash tests/abtest-stream.test.sh | grep -c '^ok   limit wording'`
   exit: 0
   stdout: `89`
   mutation: skip edit 2; the new positive rows FAIL and the count drops below 89.
3. run: `bash tests/abtest-stream.test.sh | grep -c '^ok   near miss stays an error'`
   exit: 0
   stdout: `29`
   mutation: skip edit 2; the old pattern reads agent prose after the phrase as a limit, those rows FAIL and the count drops below 29.
4. run: `bash tests/abtest-stream.test.sh | grep -c '^ok '`
   exit: 0
   stdout: `144`
   mutation: skip edit 2; rows FAIL and the count drops below 144.
5. run: `bash tests/abtest-stream.test.sh | grep -c '^ok   a successful result that opens with a limit phrase stays complete'`
   exit: 0
   stdout: `1`
   mutation: skip edit 3 (the last block of rows holds this row); the count is 0 and the exit is 1.
   proof: mutation M47 of the matrix in criterion 1, run in a scratch copy: with the is_error test in stream.py replaced by True the row prints FAIL and the suite exits non-zero.
6. run: `bash tests/abtest-stream.test.sh | grep -cF -e 'ok   limit wording: an em dash before the reset' -e 'ok   limit wording: a word joiner (U+2060) in front of the phrase' -e 'ok   limit wording: a zero-width non-joiner (U+200C) in front of the phrase' -e 'ok   limit wording: a zero-width joiner (U+200D) in front of the phrase'`
   exit: 0
   stdout: `4`
   mutation: delete the character U+2060 from the INVISIBLE string in the finished stream.py; the word joiner row prints FAIL and the count is 3.
   proof: mutations M18 and M54 to M56 of the matrix in criterion 1, run in a scratch copy: each makes exactly one of these four rows FAIL.
7. run: `python3 -I -c "import importlib.util as u;s=u.spec_from_file_location('s','eval/abtest/lib/stream.py');m=u.module_from_spec(s);s.loader.exec_module(m);print(int(bool(m.LIMIT_TEXT_RE.match('Usage limit reached. I added a test'))))"`
   exit: 0
   stdout: `0`
   mutation: skip edit 2; the old pattern accepts a full stop after the phrase and prints 1.
8. run: `python3 -I -c "import importlib.util as u;s=u.spec_from_file_location('s','eval/abtest/lib/stream.py');m=u.module_from_spec(s);s.loader.exec_module(m);print(int(bool(m.LIMIT_TEXT_RE.match('You are out of extra usage - resets 3pm'))))"`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; the old pattern has no extra-usage wording and prints 0.
9. run: `grep -c '_END' eval/abtest/lib/stream.py`
   exit: 1
   stdout: `0`
   mutation: skip edit 2; the old lookahead is still there, stdout 3 and the exit is 0.
10. run: `timeout 10 python3 -I -c "import importlib.util as u;s=u.spec_from_file_location('s','eval/abtest/lib/stream.py');m=u.module_from_spec(s);s.loader.exec_module(m);print(int(bool(m.LIMIT_TEXT_RE.match('Session limit reached' + ' ' * 60000 + 'x'))))"`
   exit: 0
   stdout: `0`
   mutation: in the finished stream.py put a whitespace gap back in front of the reset clause (replace the text \(?" + _RESET by \(?\s*" + _RESET); the stacked gaps backtrack for far longer than 10 seconds and timeout exits 124.
   proof: scratch run of that edit: the same command with 60000 spaces exited 124 (20000 spaces already took 5 seconds); the finished file answered 0 in a few milliseconds.
11. run: `cat eval/abtest/lib/stream.py tests/abtest-stream.test.sh | grep -cP '[^\x00-\x7F]'`
   exit: 1
   stdout: `0`
   mutation: replace one backslash-u escape by the character it stands for in the finished test file; stdout 1 and the exit is 0.
   proof: scratch run: after replacing the escape for the bullet operator in one row by the literal character, the count printed 1 (exit 0).
12. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u02d\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/lib/stream.py tests/abtest-stream.test.sh`
   mutation: skip edit 4 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
13. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u02d\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; no unit commit exists and the exit is 3.
14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u02d\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/lib/stream.py tests/abtest-stream.test.sh | grep -vcE "^[a-z]+\(abt-u02d\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
15. run: `git status --porcelain -- eval/abtest/lib/stream.py tests/abtest-stream.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 4; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-stream.test.sh (criteria 2, 3, 4, 7, 8 and 9 are the red-then-green checks: the new wordings, rows and pattern do not exist at HEAD)
blast-radius: eval/abtest/lib/stream.py:28, eval/abtest/lib/stream.py:112, eval/abtest/run-matrix.sh:219
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 1 (the whole suite passes at HEAD), criterion 10 (the old pattern is linear), criterion 11 (both files are ASCII at HEAD) and criterion 15 (the scoped clean-tree check) pass at HEAD by design; criteria 2 to 9 fail at HEAD.
extends-landed-code: abt-u02c is on master (commit 444f1b82), so every anchor and the replaced block are taken from that commit. Edit 2 replaces the lookahead _END and the pattern LIMIT_TEXT_RE (ten lines) and leaves INVISIBLE, clean and everything after them as landed. Edit 3 onward insert rows after one existing row; no row is changed.
why: a real limit read as an error counts as a failed run, and agent prose read as a limit hides a failed run as a pause (operator decision OD-4, usage-limit is never a failure). Both directions are pinned by rows: 72 new positives, 20 new near misses and one success row.
escapes-only: every new capture is written by the test itself with mkerr or mkok from JSON ASCII escapes into the temp directory $ZW; the test and stream.py stay pure ASCII (criterion 11). Copy each backslash-u escape as the six characters it is; never replace one by the character it stands for.
out-of-scope: Credit balance is too low (API-key billing) stays a plain error, as do Error: Overloaded and HTTP 529 and 500; rows pin that.
fail-closed: every row compares an explicit status word; a crash or empty output reads as FAILURE. The 429 form counts only as API Error: 429 followed by the compact JSON with "type":"rate_limit_error".
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u02d): stream.py reads the extra-usage and pipe-epoch limit wordings and stops reading agent prose as a limit (#601)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u02d (#601)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
