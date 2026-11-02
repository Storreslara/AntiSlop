Unit: l2-tests

## Objective
Plan unit 14 (lp-tidy2, lp-bashscan notes). (1) `tests/marker-write.test.sh`: `source <(sed -n '/^marker_valid() {/,/^}/p' hooks/scripts/task-gate.sh)` and check both PASS markers (unitA, spec2-unitC) with `marker_valid` (`task_id` = unit, `dot` = its project's `.claude`). `marker_format_valid` stays only for FAIL and BLOCKED markers; the header comment (:6-10) says so, not "checks that rule locally". The comment ending "staying BLOCKED above for the same identity." (:206-207) ends "since 0.32.0 the gates allow every Bash command, so the real helper_cmd is allowed too." (2) `tests/escalation-retired.test.sh` check (d) (:48): `awk '/^const BIN_HELPER_FILES/{f=1} f{print} f&&/\];/{exit}' bin/cli.js | grep -q "$card"`. (3) `CHANGELOG.md`: the 0.32.0 lp-bashscan bullet's "the comment sections (case 25)" becomes "the two comment sections (both case 25)"; one `[Unreleased]` bullet naming `l2-tests`.

## Retrieval
No tracker issue; plan `docs/plans/2026-11-02-lean-pipeline-2.md`, unit 14.

## Affected files
- `tests/marker-write.test.sh`
- `tests/escalation-retired.test.sh`
- `CHANGELOG.md`

## Do NOT touch
- `hooks/`, `bin/`, `tests/validate.sh`

## Acceptance criteria
1. run: `o=$(bash tests/marker-write.test.sh 2>&1); r=$?; grep -c '^FAIL' <<<"$o"; exit $r`
   exit: 0
   stdout: `0`
   mutation: call `marker_valid` with `task_id` unset → FAIL lines, exit 1.
2. run: `d=$(mktemp -d); mkdir $d/tests; cp tests/marker-write.test.sh $d/tests/; cp -r hooks $d/; sed -i '/^marker_valid() {/a\  return 1' $d/hooks/scripts/task-gate.sh; cd $d; bash tests/marker-write.test.sh 2>&1 | grep -c '^FAIL'`
   exit: 0
   stdout: `2`
   mutation: PASS checks stay local → `0`, exit 1.
3. run: `f=tests/marker-write.test.sh; echo "$(grep -cE 'marker_format_valid +"[^"]*" +[^ ]+ +PASS' $f) $(grep -c 'staying BLOCKED' $f) $(grep -c 'checks that rule locally' $f) $(tr -s ' \n#' ' ' <$f | grep -c 'gates allow every Bash command, so the real helper_cmd')"`
   exit: 0
   stdout: `0 0 0 1`
   mutation: leave the :206 comment → `0 1 0 0`.
4. run: `card="escalation""-card.sh"; blk=$(sed -n '/BIN_HELPER_FILES/,/^  fi$/p' tests/escalation-retired.test.sh); d=$(mktemp -d); mkdir $d/bin; t(){ printf "$1" "$card" >$d/bin/cli.js; (cd $d; bad(){ echo hit; }; eval "$blk") | wc -l | tr -d ' '; }; echo "$(t "const BIN_HELPER_FILES = [\n  'a.sh',\n  '%s',\n];\n") $(t "const BIN_HELPER_FILES = ['a.sh'];\nconst X = ['%s'];\n") $(t "const BIN_HELPER_FILES = ['a.sh', '%s'];\n")"`
   exit: 0
   stdout: `1 0 1`
   mutation: keep today's one-line grep → `0 0 1`; a sed range → `1 1 1`.
5. run: `echo "$(grep -c 'the two comment sections (both case 25)' CHANGELOG.md) $(grep -c 'the comment sections (case 25)' CHANGELOG.md) $(sed -n '/^## \[Unreleased\]/,/^## \[0\.33\.0\]/p' CHANGELOG.md | grep -c 'l2-tests')"`
   exit: 0
   stdout: `1 0 1`
   mutation: skip the 0.32.0 wording → `0 1 1`.
6. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
