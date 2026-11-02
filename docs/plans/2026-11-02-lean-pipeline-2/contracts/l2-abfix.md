Unit: l2-abfix

## Objective
Unit 7 (D6), after 19125118: a denial plus an error must not score `complete`. (a) `stream.py summarize` adds `is_error` (bool; true if no result or its `is_error` is truthy) and `exit_code` (the `--exit-code` int); no other key changes. (b) `denial_only()` also needs `result_subtype == "success"`, `is_error is False`, `exit_code` a non-bool int == 0; missing or mistyped never qualifies (row stays `stalled-human`). (c) `summary-denied.json` gains `"is_error":false,"exit_code":0`. (d) Tests: `(l2-a5)` stream keys; `(l2-a6)` denial + `is_error` true, `(l2-a7)` denial + exit 1, each `[False, 'stalled-human']`. (e) The README l2-abfix parenthetical and the existing `l2-abfix` CHANGELOG bullet gain "otherwise clean run"; no new bullet.

## Retrieval
No issue; `docs/plans/2026-11-02-lean-pipeline-2.md` unit 7.

## Affected files
- `eval/abtest/lib/stream.py`
- `eval/abtest/lib/make-row.py`
- `eval/abtest/README.md`
- `tests/abtest-stream.test.sh`
- `tests/abtest-row.test.sh`
- `tests/fixtures/abtest/row/summary-denied.json`
- `CHANGELOG.md`

## Do NOT touch
- `tests/abtest-arms.test.sh`, `eval/abtest/score.py`, `eval/abtest/results*.jsonl`

## Acceptance criteria
1. run: `o=$(bash tests/abtest-row.test.sh 2>&1 && bash tests/abtest-stream.test.sh 2>&1); r=$?; grep '^ok ' <<<"$o" | grep -oE '\(l2-a[1-7]\)' | sort -u | wc -l | tr -d ' '; exit $r`
   exit: 0
   stdout: `7`
   mutation: drop the `(l2-a7)` test → `6`.
2. run: `d=tests/fixtures/abtest/streams; for a in denied:3 mention-error:1 no-result:0; do python3 eval/abtest/lib/stream.py summarize $d/${a%:*}.jsonl --exit-code ${a#*:} | jq -c '[.is_error,.exit_code]'; done | paste -sd' '`
   exit: 0
   stdout: `[false,3] [true,1] [true,0]`
   mutation: `is_error` taken from the result only → no-result `null`.
3. run: `x=tests/fixtures/abtest/row; t=$(mktemp); for f in . .is_error=true .exit_code=1 .is_error=0 .exit_code=false '.exit_code="0"' 'del(.is_error)' '.result_subtype="x"'; do jq -c "$f" $x/summary-denied.json >$t; python3 eval/abtest/lib/make-row.py --summary $t --checks $x/checks-pass.json --arm A --eval-id e --rep 1 --started-at t --harness-commit h --cli-version 2 --fixture-commit f --prompt-file $x/prompt.txt --wall-clock-ms 1 --expected-required 2 | jq .run_pass; done | paste -sd' '; rm -f $t`
   exit: 0
   stdout: `true false false false false false false false`
   mutation: test `not is_error` instead of `is False` → item 4 `true`.
4. run: `tr '\n' ' ' < eval/abtest/README.md | tr -s ' ' | grep -oE 'only stall cause is a permission denial|otherwise clean run' | wc -l | tr -d ' '`
   exit: 0
   stdout: `2`
   mutation: omit "otherwise clean run" → `1`.
5. run: `s=$(sed -n '/^## \[Unreleased\]/,/^## \[0\.33\.0\]/p' CHANGELOG.md); grep -c 'l2-abfix' <<<"$s"; grep 'l2-abfix' <<<"$s" | grep -c 'otherwise clean run'`
   exit: 0
   stdout: `1` then `1`
   mutation: add a second bullet → `2` then `1`.
6. run: `bash tests/validate.sh >/dev/null 2>&1` (timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
