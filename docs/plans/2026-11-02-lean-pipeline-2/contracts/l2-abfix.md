Unit: l2-abfix

## Objective
Plan unit 7 (D6). (a) Both `allowed-paths.txt` files gain the line `CONTEXT.md`. (b) `make-row.py` `build()`: when `status` is `stalled-human`, summary `permission_denials` is an int > 0, `ask_user_attempts` and `escalated_markers` are ints == 0 (a missing key never qualifies) and every required check passed, set `status = "complete"`; `human_interventions_required` unchanged. (c) README: the sentence ending "any denial scores a row `stalled-human`" gains "(since l2-abfix, a row whose only stall cause is a permission denial with all required checks passing scores `complete`)". (d) `summary-denied.json`: `summary-stalled.json` + `"permission_denials":1,"ask_user_attempts":0,"escalated_markers":0`, `human_interventions_required` 1. (e) Tests labelled `(l2-a1)`-`(l2-a4)`: denial-only + all pass → `[True, 'complete', 1]`; + `checks-fail.json` → `[False, 'stalled-human']`; + `ask_user_attempts` 1 → stalled; + `escalated_markers` 1 → stalled. Existing cases unchanged. One `[Unreleased]` CHANGELOG bullet naming `l2-abfix`. `tests/abtest-arms.test.sh` pins none of this; not edited.

## Retrieval
No tracker issue; spec in `docs/plans/2026-11-02-lean-pipeline-2.md`, unit 7.

## Affected files
- `eval/abtest/fixtures/e03-rename-query/allowed-paths.txt`
- `eval/abtest/fixtures/e05-tags-feature/allowed-paths.txt`
- `eval/abtest/lib/make-row.py`
- `eval/abtest/README.md`
- `tests/abtest-row.test.sh`
- `tests/fixtures/abtest/row/summary-denied.json`
- `CHANGELOG.md`

## Do NOT touch
- `tests/abtest-arms.test.sh`, `eval/abtest/lib/stream.py`, `eval/abtest/score.py`, `eval/abtest/results*.jsonl`

## Acceptance criteria
1. run: `o=$(bash tests/abtest-row.test.sh 2>&1); r=$?; grep '^ok ' <<<"$o" | grep -oE '\(l2-a[1-4]\)' | sort -u | wc -l | tr -d ' '; exit $r`
   exit: 0
   stdout: `4`
   mutation: drop the `escalated_markers` test → exit 1.
2. run: `x=tests/fixtures/abtest/row; for c in pass fail; do python3 eval/abtest/lib/make-row.py --summary $x/summary-denied.json --checks $x/checks-$c.json --arm A --eval-id e --rep 1 --started-at t --harness-commit h --cli-version 2 --fixture-commit f --prompt-file $x/prompt.txt --wall-clock-ms 1 --expected-required 2 | jq -r '"\(.run_pass) \(.completion_status) \(.human_interventions_required)"'; done`
   exit: 0
   stdout: `true complete 1` then `false stalled-human 1`
   mutation: skip the checks test → line 2 `false complete 1`.
3. run: `cat eval/abtest/fixtures/e0[35]-*/allowed-paths.txt | grep -cx 'CONTEXT.md'`
   exit: 0
   stdout: `2`
   mutation: skip e05 → `1`.
4. run: `tr '\n' ' ' < eval/abtest/README.md | tr -s ' ' | grep -o 'only stall cause is a permission denial' | wc -l | tr -d ' '`
   exit: 0
   stdout: `1`
   mutation: omit it → `0`.
5. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.33\.0\]/p' CHANGELOG.md | grep -c 'l2-abfix'`
   exit: 0
   stdout: `1`
   mutation: bullet under 0.33.0 → `0`, exit 1.
6. run: `bash tests/validate.sh >/dev/null 2>&1` (timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
