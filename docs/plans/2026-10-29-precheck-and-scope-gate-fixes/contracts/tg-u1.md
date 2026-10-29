Unit: tg-u1

## Objective
Make `bin/review-precheck.sh` grade a criterion whose `stdout:` spec is "`A` then `B`" (two or more backticked
parts joined by ` then `) as one expected stdout of several lines. Today `run_one()` takes the whole spec for one
literal with inner backticks and reports a false `fail` (`criterion 1: fail stdout want=0` then `rc=0 got=0`).
Reviewers had to override this by hand on rfp-u2, rfp-u3, rfp-u4 and rfp-u5. After the fix such a spec is split
on `` ` then ` ``, its outer backticks are stripped, the parts are joined with newlines and the result is
compared exactly, as the single-literal case compares. A mismatch prints both sides on one line. Every other
spec shape keeps its current verdict: `empty`, a single literal (also one that contains the word `then`), and
anything else, which is `judge`, including the `` `A` then `B` (two lines) `` form.

`bin/` is not a version-stamped path, so there is no version bump and no CHANGELOG entry (constitution P3).
This unit does **not** regenerate `.claude/bin/review-precheck.sh`: tg-u2 runs the one `node bin/cli.js
--update` for both units. `tests/validate.sh` checks `.claude/bin` for presence only, so it stays green.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-29-precheck-and-scope-gate-fixes.md` ("Bug 1", "Fix
design"). This file is the contract of record. tg-u1 shares no hand-edited file with tg-u2. Dispatch order:
tg-u1 first (plan Open Question 1).

## Affected files
- `bin/review-precheck.sh` (anchor: line matching `  case "$spec" in`, inside `run_one()`; mode stays 755)
- `tests/review-precheck.test.sh` (anchor: line matching `# (k) a scope library that is missing or defines nothing: exit 2 and no packet (the reviewer runs the checks itself).`; mode stays 755)

## Ordered edits
spec-master applied edits 1 and 2 to a clone of 080b49da and ran every criterion and mutation below there.
Use the Edit tool for both. Do not use a Bash heredoc: the test file must not be rewritten through Bash.

1. file: `bin/review-precheck.sh`
   anchor: line matching `  case "$spec" in` (the only one; it is the first line of `run_one()`'s `case`)
   before:
~~~
  case "$spec" in
~~~
   after:
~~~
  # "`A` then `B`" (tg-u1): two or more backticked parts are one expected stdout of several lines. The parts
  # lose their backticks, are joined by newlines and compared exactly. A part holds no backtick, so a literal
  # that only contains the word then, or text after the last part, keeps its old reading.
  local multi='^`[^`]*`( then `[^`]*`)+$'
  if [[ "$spec" =~ $multi ]]; then
    local parts="${spec#\`}"; parts="${parts%\`}"; parts="${parts//\` then \`/$'\n'}"
    [ "$got" = "$parts" ] && { echo "criterion $n: pass exit=$rc"; return 0; }
    echo "criterion $n: fail stdout want=$spec got=$(printf '%s\n' "$got" | awk 'BEGIN { ORS = "" } { printf "%s`%s`", (NR > 1 ? " then " : ""), $0 }')"; return 1
  fi
  case "$spec" in
~~~

2. file: `tests/review-precheck.test.sh`
   anchor: line matching `# (k) a scope library that is missing or defines nothing: exit 2 and no packet (the reviewer runs the checks itself).`
   before:
~~~
# (k) a scope library that is missing or defines nothing: exit 2 and no packet (the reviewer runs the checks itself).
~~~
   after:
~~~
# (m) a "`A` then `B`" stdout spec (tg-u1) is one expected stdout of several lines: the parts lose their
# backticks, are joined by newlines and compared exactly. Any other shape keeps its old reading.
C5=docs/plans/p/contracts/u5.md
cat > "$C5" << 'MD'
Unit: u5

## Acceptance criteria
1. run: `printf '0\nrc=0\n'`
   exit: 0
   stdout: `0` then `rc=0`
   mutation: none
2. run: `printf '0\nrc=1\n'`
   exit: 0
   stdout: `0` then `rc=0`
   mutation: none
3. run: `printf '1\n2\n3\n'`
   exit: 0
   stdout: `1` then `2` then `3`
   mutation: none
4. run: `echo 'a then b'`
   exit: 0
   stdout: `a then b`
   mutation: none
5. run: `printf '0\n1\n'`
   exit: 0
   stdout: `0` then `1` (two lines)
   mutation: none
6. run: `printf '0\n'`
   exit: 0
   stdout: `0` then `rc=0`
   mutation: none
MD
g add "$C5" && g commit -q -m 'u5 contract' && B5="$(git rev-parse HEAD)"
m5() { bash "$PC" u5 "$B5" --contract "$C5" --criterion "$1"; }
[ "$(m5 1)" = 'criterion 1: pass exit=0' ] && ok "(m) two-part spec passes" || bad "(m) two-part: $(m5 1)"
[ "$(m5 2)" = 'criterion 2: fail stdout want=`0` then `rc=0` got=`0` then `rc=1`' ] && ok "(m) two-part mismatch fails, both sides shown" || bad "(m) mismatch: $(m5 2)"
[ "$(m5 3)" = 'criterion 3: pass exit=0' ] && ok "(m) three-part spec passes" || bad "(m) three-part: $(m5 3)"
[ "$(m5 4)" = 'criterion 4: pass exit=0' ] && ok "(m) a literal holding the word then is not split" || bad "(m) then-literal: $(m5 4)"
[ "$(m5 5)" = 'criterion 5: judge stdout exit=0' ] && ok "(m) text after the last part stays judge" || bad "(m) annotated: $(m5 5)"
[ "$(m5 6)" = 'criterion 6: fail stdout want=`0` then `rc=0` got=`0`' ] && ok "(m) a missing line fails" || bad "(m) short output: $(m5 6)"
g reset -q --hard HEAD~1

# (k) a scope library that is missing or defines nothing: exit 2 and no packet (the reviewer runs the checks itself).
~~~

3. command: `bash -c 'out=$(bash tests/review-precheck.test.sh 2>&1); rc=$?; echo "fails=$(printf "%s\n" "$out" | grep -c "^FAIL") m=$(printf "%s\n" "$out" | grep -c "^OK   (m) ") rc=$rc"'`
   expect: 0, stdout `fails=0 m=6 rc=0`
   TDD order: apply edit 2 first and run this. Before edit 1 it prints `fails=4 m=2 rc=1` (RED). Then apply edit 1.

4. command: `git add bin/review-precheck.sh tests/review-precheck.test.sh && git commit -m 'fix(tg-u1): review-precheck reads a multi-part stdout spec as a multi-line literal'`
   expect: 0
   Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report it,
   unless it is one of tg-u2's files (`hooks/scripts/writer-scope-gate.sh`, `tests/writer-scope-gate.test.sh`,
   their `.claude/` copies): leave those unstaged. A fix round is a new commit whose subject keeps `(tg-u1): `.

## Do NOT touch
- `.claude/bin/review-precheck.sh` and every other `.claude/` file (only tg-u2's `node bin/cli.js --update` writes them; criterion 5)
- `hooks/` (every hook, gate and library, including `hooks/scripts/lib/unit-scope.sh`), `hooks/hooks.json`, `bin/cli.js` (criterion 5)
- `tests/validate.sh` (the suite is already registered at its line 879)
- `docs/plans/2026-10-27-refutation-pass/` (criterion 3 only reads those contracts)
- `eval/refutation-replay/labels.tsv`, `corpus.jsonl`, `report.jsonl`; anything under `.claude/reviewed/`
- Never run `eval/refutation-replay/run.sh` without `--dry-run`. Mutations go in a scratch clone made with a unique `mktemp -d`, never in this working tree.

## Acceptance criteria
1. run: `bash -c 'out=$(bash tests/review-precheck.test.sh 2>&1); rc=$?; echo "fails=$(printf "%s\n" "$out" | grep -c "^FAIL") m=$(printf "%s\n" "$out" | grep -c "^OK   (m) ") rc=$rc"'`
   exit: 0
   stdout: `fails=0 m=6 rc=0`
   mutation: in a scratch clone, each alone (spec-master ran all four). With no edit 1 (`review-precheck.sh` at 080b49da) it prints `fails=4 m=2 rc=1`. Detecting and splitting on ` then ` without the backticks makes cases 1, 3 and 4 red: `fails=3 m=3 rc=1`. Letting text follow the last part (`)+.*$`) makes case 5 red: `fails=1 m=5 rc=1`. Joining the parts with a space instead of a newline makes cases 1 and 3 red: `fails=2 m=4 rc=1`.
2. run: `bash -c 'bash -n bin/review-precheck.sh && stat -c %a bin/review-precheck.sh tests/review-precheck.test.sh | paste -sd " " -'`
   exit: 0
   stdout: `755 755`
   mutation: `chmod 644 tests/review-precheck.test.sh` (as a recreated file would be) prints `755 644`. Deleting edit 1's `fi` makes `bash -n` fail, so stdout is empty and exit is 2.
3. run: `bash -c 'D=$(mktemp -d); P=$(mktemp -d); trap "rm -rf \"$D\" \"$P\"" EXIT; mkdir -p "$D/bin" && git show 080b49da:bin/review-precheck.sh > "$D/bin/review-precheck.sh" && ln -s "$PWD/hooks" "$D/hooks" || exit 1; C=docs/plans/2026-10-27-refutation-pass/contracts; bad=0; fixed=0; for u in rfp-u2 rfp-u3 rfp-u4 rfp-u5; do CLAUDE_PROJECT_DIR="$P" bash "$D/bin/review-precheck.sh" "$u" HEAD --contract "$C/$u.md" | grep -E "^criterion [0-9]+: " | cut -d" " -f2,3 > "$P/old"; CLAUDE_PROJECT_DIR="$P" bash bin/review-precheck.sh "$u" HEAD --contract "$C/$u.md" | grep -E "^criterion [0-9]+: " | cut -d" " -f2,3 > "$P/new"; while read -r n w; do o=$(grep -E "^$n " "$P/old" | cut -d" " -f2); [ "$o" = "$w" ] && continue; case "$o>$w $u#${n%:}" in "fail>pass rfp-u2#3"|"fail>pass rfp-u3#"[148]|"fail>pass rfp-u4#"[13]|"fail>pass rfp-u5#1") fixed=$((fixed+1)) ;; *) bad=$((bad+1)) ;; esac; done < "$P/new"; done; [ "$fixed" -ge 5 ] && fixed=ok; echo "bad=$bad fixed=$fixed"'`
   exit: 0
   stdout: `bad=0 fixed=ok`
   mutation: with no edit 1 it prints `bad=0 fixed=0` (spec-master ran it). This is the re-run over the real contracts. The precheck at 080b49da (old) and the working copy (new) each grade every non-long criterion of rfp-u2 to rfp-u5 on the same tree, writing only under a temp `CLAUDE_PROJECT_DIR`. `bad` counts every verdict change other than fail to pass on one of the seven multi-part criteria, so a previously passing criterion that changes verdict counts here. The threshold is 5, not 7: rfp-u2#3 fails on its merits today (`real=41`), and rfp-u3#8 depends on the untracked `report.jsonl`. It takes about 12 s and runs nothing that writes (no `run.sh`).
4. run: `bash -c 'C=docs/plans/2026-10-27-refutation-pass/contracts; P=$(mktemp -d); for x in rfp-u3:1 rfp-u3:4 rfp-u4:1 rfp-u4:3 rfp-u5:1; do CLAUDE_PROJECT_DIR="$P" bash bin/review-precheck.sh "${x%:*}" HEAD --contract "$C/${x%:*}.md" --criterion "${x#*:}" | cut -d" " -f3; done | sort | uniq -c | tr -s " " | sed "s/^ //"; rm -rf "$P"'`
   exit: 0
   stdout: `5 pass`
   mutation: with no edit 1 it prints `5 fail` (spec-master ran it). These five are the false fails reviewers overrode by hand, and none of them depends on `report.jsonl`.
5. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(tg-u1): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -vxE "bin/review-precheck\.sh|tests/review-precheck\.test\.sh" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: commit an edit to `.claude/bin/review-precheck.sh` under a `(tg-u1): ` subject, and stdout is `1`. With no `(tg-u1): ` commit, stdout is `no-commits`, exit 1.

## Pre-resolved context
- Verified behaviour at 080b49da: the pure form is a false FAIL, not a judge (`criterion 1: fail stdout
  want=0` then `rc=0 got=0`). The `(two lines)` form is `judge`, and `` `a then b` `` passes. All seven
  multi-part criteria in rfp-u2 to rfp-u5 fail today.
- spec-master applied edits 1 and 2 to a clone of 080b49da and committed them under a `(tg-u1): ` subject.
  Edit 3 printed `fails=0 m=6 rc=0`, criteria 1 to 5 printed their stated stdout, and every mutation behaved
  as stated. The other 69 OK lines of the suite are unchanged.
- `local multi=…` holds the regex in a variable, so `[[ … =~ $multi ]]` reads it unquoted, as bash requires.
  `${parts//\` then \`/$'\n'}` replaces every separator, and the backslashes keep the backticks literal.
- A part may not contain a backtick (`[^`]*`), so the split is unambiguous. Any spec with a backtick inside a
  part falls through to the old `` `*` `` or `judge` branches unchanged.
- The case adds a contract `u5.md` at its own commit and resets that commit afterwards, the same pattern as
  case (e2). Case (k) after it still uses `$BASE` and `$C`.
- The reviewer's own `.claude/bin/review-precheck.sh` is still the old copy while this unit is reviewed. Every
  criterion above has a one-line stdout spec, so the old copy grades them correctly.

## Escalation
If the `before` text of edit 1 or 2 is not found exactly once, stop and report the current text. If the
Edit tool is unavailable (`exists but is not enabled in this context`), report it and wait. Do not rewrite
either file through a Bash heredoc. If a gate blocks a command, quote its refusal and wait; do not reword
the command. The operator authorised edits to `bin/review-precheck.sh` and `tests/review-precheck.test.sh`
for this unit (session of 2026-10-29). `protectedPaths` is empty, and neither file is in
`harness-integrity-gate.sh`'s Set A or Set B, so no human-confirmation prompt is expected. If one appears
anyway, the orchestrator relays the exact prompt to the human; the lead never answers it itself. Anything
outside "Affected files" goes in your report as a proposal.
