Unit: abt-u02e

## Objective
stream.py classifies usage-limit for every limit-hit message of claude 2.1.302 (the hit-your and reached-your names including Opus, Sonnet and Fable, out of usage credits, the org, seat, allocation and group messages, requires usage credits, their suffix clauses and the model picker sentences, with a reset time that may carry a year, midnight, noon or a time zone name) while warnings, notices and agent prose stay a plain error; tests/abtest-stream.test.sh grows from 144 to 242 rows (76 more limit-wording rows, 22 more near-miss rows); a 429 body must carry the opening brace and the type key on one line; and .gitignore ignores __pycache__ under eval/abtest. One commit.

## Retrieval
GitHub issues: `gh issue view 604 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/lib/stream.py` (anchor: line matching `_SEP = r"`)
- `tests/abtest-stream.test.sh` (anchor: line matching `a successful result that opens with a limit phrase stays complete`)
- `.gitignore` (anchor: line matching `eval/abtest/results.jsonl`)

## Ordered edits
1. command: `test -f eval/abtest/lib/stream.py && test -f tests/abtest-stream.test.sh && ! grep -q "_NAME" eval/abtest/lib/stream.py && ! grep -q "cli-name" tests/abtest-stream.test.sh && grep -q "x-mid-dot" tests/abtest-stream.test.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/lib/stream.py`
   anchor: line matching `_SEP = r"`
   indent: 0
   before:
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
   after:
~~~~
_SEP = r"[\u00b7\u2219\u2013\u2014|.,-]"
_DAY = r"(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)"
_MONTH = (r"(?:january|february|march|april|may|june|july|august|september|october|november|december"
          r"|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)")
_ZONE = r"(?:utc|gmt|pst|pdt|mst|mdt|cst|cdt|est|edt|cet|cest|bst)"
_WHEN = (r"(?:\d{1,2}(?::\d{2})?\s?(?:am|pm)?|\d{4}|" + _DAY + "|" + _MONTH + "|" + _ZONE +
         r"|today|tomorrow|midnight|noon|at|on|in|hours?|minutes?|days?|\(\w+(?:/[\w+-]+)*\))")
_RESET = r"(?:your (?:\w+ )?limit )?(?:will )?resets?(?:[\s,]+" + _WHEN + r"){1,8}"
_ADMIN = (r"(?:contact your admin(?: to increase it)?|add funds to continue|ask your admin for a higher limit"
          r"|(?:ask your admin to )?raise it at \S+|run \S+ to (?:raise it, or visit \S+|ask your admin for a higher limit)"
          r"|visit \S+ to raise it|an org owner or channel manager can raise it in the channel's claude settings)")
_PART = r"(?:" + _RESET + r"|progress saved|" + _ADMIN + r")"
_SWITCH = (r"(?:Switch to another model(?:, or manage usage credits at \S+,)? to continue\.|/model to switch models\."
           r"|Run /usage-credits to (?:raise it and keep using|keep using|manage your limit and keep using) [^\n]{1,60} or (?:/model to switch models|switch models to continue this chat)\."
           r"|Run /usage-credits to continue or switch models with /model\.)")
_TAIL = (r"(?:[.!]?(?:\s+" + _SWITCH + r")?$"
         r"|\|\d{9,13}$"
         r"|\s*(?:" + _SEP + r"\s*)?\(?" + _PART + r"(?:\)?\s*\u00b7\s*" + _PART + r")*\)?[.!]?$)")
_NAME = (r"(?:(?:usage |weekly |5-hour |session |opus |sonnet |fable |fast )?limit|team's shared budget"
         r"|(?:channel's monthly|individual|org's monthly) (?:spend|usage) limit|monthly spend limit)")
LIMIT_TEXT_RE = re.compile(
    r"(?:(?:api )?error:\s*)?(?:"
    r"(?:" + _WHO + _KIND + r"?|" + _KIND + r"|rate )limit reached"
    r"|you(?:'ve|\u2019ve| have) (?:hit|reached) your " + _NAME +
    r"|(?:you(?:'re|\u2019re| are) )?out of (?:extra usage|usage credits)"
    r"|your org is out of usage"
    r"|your seat type doesn't include (?:extra )?usage(?: credits)?"
    r"|your usage allocation has been disabled by your admin"
    r"|your group's usage limit is set to \$0"
    r"|(?:fable|haiku|mythos|opus|sonnet)(?: [^\u00b7\n]{1,40})? requires usage credits\."
    r")" + _TAIL +
    r'|(?:api )?error:\s*429 \{[^\n]*"type":"rate_limit_error"',
    re.IGNORECASE,
)
~~~~
3. file: `tests/abtest-stream.test.sh`
   anchor: line matching `a successful result that opens with a limit phrase stays complete`
   indent: 0
   insert-after:
~~~~
# Every non-warning limit-hit template of claude CLI 2.1.302 (abt-u02e) must read as usage-limit; every warning, notice and prose near miss stays an error.
i=0
for nm in "5-hour limit" "session limit" "weekly limit" "Opus limit" "Sonnet limit" "Fable limit" "fast limit" "usage limit" "limit" "team\u0027s shared budget" "channel\u0027s monthly spend limit" "channel\u0027s monthly usage limit" "individual spend limit" "individual usage limit" "org\u0027s monthly spend limit" "org\u0027s monthly usage limit" "monthly spend limit"; do
  i=$((i + 1))
  lw "cli-name$i" "the CLI name $nm in a hit message" "You\\u0027ve hit your $nm \\u00b7 resets 3pm (Europe/Madrid)"
done
i=0
for sfx in "contact your admin to increase it" "raise it at claude.ai/settings" "ask your admin to raise it at claude.ai/settings" "run /usage-credits to raise it, or visit claude.ai/settings" "visit claude.ai/settings to raise it" "run /usage-credits to ask your admin for a higher limit" "ask your admin for a higher limit" "an org owner or channel manager can raise it in the channel\u0027s Claude settings" "your session limit resets 3pm" "your Opus limit resets Jan 2, 2027, 3pm (UTC)"; do
  i=$((i + 1))
  lw "cli-admin$i" "the CLI clause $sfx after a hit message" "You\\u0027ve hit your org\\u0027s monthly spend limit \\u00b7 $sfx"
done
for z in UTC GMT PST PDT MST MDT CST CDT EST EDT CET CEST BST; do
  lw "zone-$z" "the zone $z after a reset time" "Session limit reached \\u2219 resets 3pm $z"
done
lw cli-reached "You have reached your Fable limit with a full stop" 'You\u0027ve reached your Fable limit.'
lw cli-reached-reset "reached your limit with a reset" 'You\u0027ve reached your weekly limit \u00b7 resets Monday'
lw cli-year "a reset with a year" 'You\u0027ve hit your session limit \u00b7 resets Jan 2, 2027, 3pm (America/New_York)'
lw cli-midnight "a reset at midnight" 'Session limit reached \u2219 resets midnight'
lw cli-noon "a reset at noon" 'Session limit reached \u2219 resets tomorrow noon'
lw cli-saved "the progress saved suffix" 'You\u0027ve hit your weekly limit \u00b7 resets 3pm (Europe/Madrid) \u00b7 progress saved'
lw cli-saved2 "the progress saved suffix after a credits message" 'You\u0027re out of usage credits \u00b7 resets Oct 20, 3pm \u00b7 progress saved'
lw cli-credits "out of usage credits on its own" 'You\u0027re out of usage credits'
lw cli-credits-reset "out of usage credits with a reset" 'You\u0027re out of usage credits \u00b7 resets 3pm'
lw cli-org-funds "the org is out of usage, add funds" 'Your org is out of usage \u00b7 add funds to continue'
lw cli-org-admin "the org is out of usage, contact your admin" 'Your org is out of usage \u00b7 contact your admin'
lw cli-seat1 "a seat type without usage credits" 'Your seat type doesn\u0027t include usage credits'
lw cli-seat2 "a seat type without usage" 'Your seat type doesn\u0027t include usage'
lw cli-seat3 "a seat type without extra usage" 'Your seat type doesn\u0027t include extra usage'
lw cli-alloc "a usage allocation disabled by the admin" 'Your usage allocation has been disabled by your admin'
lw cli-alloc2 "a usage allocation disabled with a clause" 'Your usage allocation has been disabled by your admin \u00b7 ask your admin for a higher limit'
lw cli-group "a group limit of zero" 'Your group\u0027s usage limit is set to $0'
lw cli-group2 "a group limit of zero with a clause" 'Your group\u0027s usage limit is set to $0 \u00b7 run /usage-credits to ask your admin for a higher limit'
for mdl in Fable Haiku Mythos Opus Sonnet; do
  lw "cli-model-$mdl" "the model $mdl requires usage credits" "$mdl 5 requires usage credits."
done
lw cli-three-parts "three clauses after a hit message" 'You\u0027ve hit your org\u0027s monthly spend limit \u00b7 visit claude.ai/settings to raise it \u00b7 your session limit resets 3pm \u00b7 progress saved'
lw cli-fable-req "Fable 5 requires usage credits" 'Fable 5 requires usage credits.'
lw cli-opus-req "Opus 4.6 requires usage credits" 'Opus 4.6 requires usage credits.'
lw cli-sw-a "team budget with a switch sentence" 'You\u0027ve hit your team\u0027s shared budget. Switch to another model to continue.'
lw cli-sw-b "out of credits with a switch sentence and a link" 'You\u0027re out of usage credits. Switch to another model, or manage usage credits at claude.ai/settings, to continue.'
lw cli-sw-c "a monthly spend limit with a switch sentence" 'You\u0027ve hit your monthly spend limit. Switch to another model to continue.'
lw cli-sw-d "Fable limit with a switch sentence" 'You\u0027ve reached your Fable limit. Switch to another model to continue.'
lw cli-sw-e "team budget with a usage-credits sentence" 'You\u0027ve hit your team\u0027s shared budget. Run /usage-credits to raise it and keep using Fable 5 or switch models to continue this chat.'
lw cli-sw-f "team budget with a model sentence" 'You\u0027ve hit your team\u0027s shared budget. /model to switch models.'
lw cli-sw-g "out of credits with a usage-credits sentence" 'You\u0027re out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.'
lw cli-sw-h "out of credits with a model sentence" 'You\u0027re out of usage credits. /model to switch models.'
lw cli-sw-i "a channel spend limit with a manage sentence" 'You\u0027ve hit your channel\u0027s monthly spend limit. Run /usage-credits to manage your limit and keep using Opus 4.6 or switch models to continue this chat.'
lw cli-sw-j "a requires-credits message with a continue sentence" 'Fable 5 requires usage credits. Run /usage-credits to continue or switch models with /model.'
nm w-used "a warning that uses a percentage" 'You\u0027ve used 90% of your session limit \u00b7 resets 3pm'
nm w-approach "an Approaching warning" 'Approaching weekly limit \u00b7 resets Monday'
nm w-close "a close-to-your-limit warning" 'You\u0027re close to your usage limit'
nm w-now "a now-using-usage-credits notice" 'You\u0027re now using usage credits \u00b7 Your session limit resets 3pm'
nm w-now2 "a Now using usage credits for Fable notice" 'Now using usage credits for Fable \u00b7 Your Fable limit resets 3pm'
nm w-fast "the fast limit notice" 'Fast limit reached and temporarily disabled \u00b7 resets in 8m'
nm w-wrap "the wrapping up banner" 'Usage limit reached \u00b7 wrapping up'
nm w-context "the context limit message" 'Context limit reached'
nm w-disabled "a service disabled for the org (not a limit)" 'This service is disabled for your org'
nm w-credit "a low credit balance (API billing)" 'Credit balance is too low'
nm p-hit-prose "a CLI hit message followed by agent prose" 'You\u0027ve hit your session limit. I added a test for the retry path'
nm p-credits-prose "out of usage credits followed by agent prose" 'You\u0027re out of usage credits, so I skipped the live test'
nm p-requires-prose "requires usage credits followed by agent prose" 'Opus requires usage credits. I added a mock for it'
nm p-org-prose "the org is out of usage followed by prose" 'Your org is out of usage. I added a fallback'
nm p-clause-prose "a CLI clause followed by agent prose" 'You\u0027ve hit your limit \u00b7 contact your admin and then I added a test'
nm p-switch-prose "a switch sentence followed by agent prose" 'You\u0027re out of usage credits. Switch to another model to continue. I added a test'
nm p-name "an unknown name after hit your" 'You\u0027ve hit your rate of five requests per second'
nm p-seat-prose "a seat message followed by prose" 'Your seat type doesn\u0027t include usage credits, so I mocked the call'
nm r-key "a bare rate_limit_error token inside a 429 body" 'API Error: 429 {\"error\":{\"message\":\"rate_limit_error\"}}'
nm r-brace "a 429 type key without the opening brace" 'API Error: 429 \"type\":\"rate_limit_error\"'
nm r-newline "a 429 body whose type key is on a second line" 'API Error: 429 {\n\"type\":\"rate_limit_error\"}'
nm p-switch-long "a model name longer than the sentence allows" 'You\u0027re out of usage credits. Run /usage-credits to keep using aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa or /model to switch models.'
~~~~
4. file: `.gitignore`
   anchor: line matching `eval/abtest/results.jsonl`
   indent: 0
   insert-after:
~~~~
eval/abtest/**/__pycache__/
~~~~
5. command: `git add eval/abtest/lib/stream.py tests/abtest-stream.test.sh .gitignore && git commit -m "fix(abt-u02e): stream.py reads every limit-hit message of claude 2.1.302 and keeps warnings and notices as plain errors (#604)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `tests/fixtures/abtest/streams/` (no new committed capture: the test writes its own into a temp directory)
- `eval/abtest/lib/make-row.py`, `eval/abtest/score.py`, `eval/abtest/run-matrix.sh` (other units own them)
- `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-stream.test.sh`
   exit: 0
   stdout: `All abtest-stream checks passed.`
   mutation: skip edit 2 (the new pattern); the new rows FAIL, the script exits non-zero and the fragment is absent.
   proof: mutation matrix of 82 single edits to the finished stream.py, run in a scratch copy, each making bash tests/abtest-stream.test.sh exit non-zero: N drops one name or kind (usage, weekly, 5-hour, session, opus, sonnet, fable, fast, the bare limit, team's shared budget, channel's monthly, individual, org's monthly, spend, usage, monthly spend limit); H drops hit or reached, or widens them to used N% of; O drops extra usage, usage credits, the optional you-are prefix, its apostrophes or are; S drops the org, seat, allocation, group or requires-usage-credits wording, the seat's extra or credits parts, each of the five model names or the model suffix; A drops contact your admin, add funds, ask your admin for a higher limit, raise it at (with or without ask your admin to), run to raise it or visit, run to ask your admin, visit to raise it, or the org owner clause; P drops progress saved, the admin clauses, the clause chain (one clause only, or another joiner); W drops the switch sentence, each of its four forms, its link, each of its three keep-using openings, each of its two endings, or unbounds the model name; Z drops the year, midnight, noon, or one of the 13 time zone names; R accepts a bare rate_limit_error, a 429 without the opening brace, or a type key on another line; E replaces match by search
2. run: `bash tests/abtest-stream.test.sh | grep -c '^ok   limit wording'`
   exit: 0
   stdout: `165`
   mutation: skip edit 2; the new positive rows FAIL and the count drops below 165.
3. run: `bash tests/abtest-stream.test.sh | grep -c '^ok   near miss stays an error'`
   exit: 0
   stdout: `51`
   mutation: skip edit 3 (the rows); the new near-miss rows are absent and the count drops to 29.
   proof: the matrix in criterion 1 holds the edits that turn a near miss into a limit: R, H used, N and W mutations print FAIL on these rows.
4. run: `bash tests/abtest-stream.test.sh | grep -c '^ok '`
   exit: 0
   stdout: `242`
   mutation: skip edit 2; rows FAIL and the count drops below 242.
5. run: `python3 -I -c "import importlib.util as u;s=u.spec_from_file_location('s','eval/abtest/lib/stream.py');m=u.module_from_spec(s);s.loader.exec_module(m);print(int(bool(m.LIMIT_TEXT_RE.match('You\x27ve hit your Fable limit \xb7 resets 3pm'))))"`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; the old kinds lack Fable, the match fails and 0 prints.
6. run: `python3 -I -c "import importlib.util as u;s=u.spec_from_file_location('s','eval/abtest/lib/stream.py');m=u.module_from_spec(s);s.loader.exec_module(m);print(int(bool(m.LIMIT_TEXT_RE.match('You\x27re out of usage credits \xb7 resets Jan 2, 2027, 3pm (UTC) \xb7 progress saved'))))"`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; the old pattern has no usage credits wording, no year and no progress saved clause, and 0 prints.
7. run: `python3 -I -c "import importlib.util as u;s=u.spec_from_file_location('s','eval/abtest/lib/stream.py');m=u.module_from_spec(s);s.loader.exec_module(m);print(int(bool(m.LIMIT_TEXT_RE.match('Fable 5 requires usage credits.'))))"`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; the old pattern has no requires-usage-credits wording and 0 prints.
8. run: `python3 -I -c "import importlib.util as u;s=u.spec_from_file_location('s','eval/abtest/lib/stream.py');m=u.module_from_spec(s);s.loader.exec_module(m);print(int(bool(m.LIMIT_TEXT_RE.match('You\x27ve used 90% of your session limit \xb7 resets 3pm'))))"`
   exit: 0
   stdout: `0`
   mutation: in the finished stream.py replace the text (?:hit|reached) your by (?:hit|reached|used \d+% of) your; the warning reads as a limit and 1 prints.
   proof: mutation H used of the matrix in criterion 1, run in a scratch copy: the warning row printed FAIL and this command printed 1.
9. run: `grep -c '^_NAME = ' eval/abtest/lib/stream.py`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; the new name list is absent, stdout 0 and the exit is 1.
10. run: `git check-ignore -q eval/abtest/__pycache__/x.pyc && git check-ignore -q eval/abtest/lib/__pycache__/x.pyc && echo ignored`
   exit: 0
   stdout: `ignored`
   mutation: skip edit 4; neither path is ignored, nothing prints and the exit is 1.
11. run: `cat eval/abtest/lib/stream.py tests/abtest-stream.test.sh | grep -cP '[^\x00-\x7F]'`
   exit: 1
   stdout: `0`
   mutation: replace one backslash-u escape by the character it stands for in the finished test file; stdout 1 and the exit is 0.
   proof: scratch run: after replacing the escape for the middle dot in one row by the literal character, the count printed 1 (exit 0).
12. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u02e\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `.gitignore eval/abtest/lib/stream.py tests/abtest-stream.test.sh`
   mutation: skip edit 5 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
13. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u02e\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; no unit commit exists and the exit is 3.
14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u02e\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/lib/stream.py tests/abtest-stream.test.sh .gitignore | grep -vcE "^[a-z]+\(abt-u02e\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
15. run: `git status --porcelain -- eval/abtest/lib/stream.py tests/abtest-stream.test.sh .gitignore`
   exit: 0
   stdout: empty
   mutation: skip edit 5; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-stream.test.sh (criteria 2 to 7, 9 and 10 are the red-then-green checks: the new wordings, rows, pattern and ignore rule do not exist at HEAD)
blast-radius: eval/abtest/lib/stream.py:28, eval/abtest/lib/stream.py:112, eval/abtest/run-matrix.sh:219
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 1 (the whole suite passes at HEAD), criterion 8 (the old pattern does not read a warning as a limit), criterion 11 (both files are ASCII at HEAD) and criterion 15 (the scoped clean-tree check) pass at HEAD by design; criteria 2 to 7, 9 and 10 fail at HEAD.
cli-source-of-truth: claude 2.1.302, the single executable under versions/2.1.302 of the claude install (found with command -v claude and readlink -f); its JavaScript source is embedded in it. The message builders read are ES (the rejected-limit message), lt (You've hit your NAME SUFFIX, with an optional progress saved suffix), AS and AOr (the per-window names), RS (warnings), YWo (model picker prompts), eP (the reset time), and the CLI's own prefix lists G$r, sFo, aFo and lFo.
limit-hit-templates: every one of these reads as usage-limit. You've hit your NAME and You've reached your NAME, where NAME is limit, session limit, weekly limit, Opus limit, Sonnet limit, Fable limit, usage limit, fast limit, team's shared budget, channel's monthly spend limit, channel's monthly usage limit, individual spend limit, individual usage limit, org's monthly spend limit, org's monthly usage limit or monthly spend limit; You're out of usage credits; You're out of extra usage; Your org is out of usage with add funds to continue or contact your admin; Your seat type doesn't include usage, usage credits or extra usage; Your usage allocation has been disabled by your admin; Your group's usage limit is set to $0; MODEL requires usage credits. for Fable, Haiku, Mythos, Opus and Sonnet. Suffix clauses, each introduced by a middle dot: resets TIME (TIME is a clock time or a month, day and optional year, then a time zone in parentheses), your NAME resets TIME, progress saved, contact your admin to increase it, ask your admin for a higher limit, raise it at URL, ask your admin to raise it at URL, run COMMAND to raise it or visit URL, run COMMAND to ask your admin for a higher limit, visit URL to raise it, an org owner or channel manager can raise it in the channel's Claude settings, add funds to continue. Model picker sentences after a full stop: Switch to another model [or manage usage credits at URL] to continue., /model to switch models., Run /usage-credits to (raise it and) keep using MODEL or /model to switch models., Run /usage-credits to manage your limit and keep using MODEL or switch models to continue this chat., Run /usage-credits to continue or switch models with /model.
not-limit-hits: these stay plain errors and rows pin them. You've used N% of your NAME; Approaching NAME; You're close to your usage limit; You're now using usage credits and Now using usage credits for MODEL (notices); Fast limit reached and temporarily disabled; Usage limit reached followed by wrapping up (a banner); Context limit reached; This service is disabled for your org (an org setting, not a pause); Credit balance is too low (API billing); agent prose after any limit phrase.
escapes-only: every new capture is written by the test itself with mkerr or mkok from JSON ASCII escapes into the temp directory $ZW; the test and stream.py stay pure ASCII (criterion 11). Copy each backslash-u escape as the six characters it is; never replace one by the character it stands for.
fail-closed: every row compares an explicit status word; a crash or empty output reads as FAILURE. The 429 form counts only as API Error: 429 followed by an opening brace and the key "type":"rate_limit_error" on the same line.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u02e): stream.py reads every limit-hit message of claude 2.1.302 and keeps warnings and notices as plain errors (#604)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u02e (#604)
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
