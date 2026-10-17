Unit: abt-u05d

## Objective
abt_fixture_baseline commits every baseline as dev <dev@example.invalid> with the message initial import and the Arm B scaffold commit is dev with the message add project tooling, so no commit a candidate can read names the test; abt_leak_guard also scans the built repository history (authors, committers, messages on every branch, ref names, tag messages and taggers) for abtest, antislop, anti-slop, anti slop, eval, pilot, persona, claude, holdout, hidden check, fixture, trap and plant (whole words, plurals included), fails closed when git log, git for-each-ref or grep fails, and abt_fixture_baseline removes the repository again when its own history leaks. One commit.

## Retrieval
GitHub issues: `gh issue view 602 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/fixtures/lib.sh` (anchor: line matching `export GIT_AUTHOR_NAME=abtest`)
- `eval/abtest/arms/arm-b.sh` (anchor: line matching `git -c user.name=abtest -c user.email=abtest@example.invalid commit`)
- `tests/abtest-checks.test.sh` (anchor: line matching `the E1 build, with its own guard, still builds under the lib guard`)
- `tests/abtest-arms.test.sh` (anchor: line matching `check "arm B scaffold commit subject"`)

## Ordered edits
1. command: `test -f eval/abtest/fixtures/lib.sh && test -f eval/abtest/arms/arm-b.sh && test -f tests/abtest-checks.test.sh && test -f tests/abtest-arms.test.sh && grep -q "abt_leak_guard" eval/abtest/fixtures/lib.sh && ! grep -q "_abt_leak_hist" eval/abtest/fixtures/lib.sh && ! grep -q "dev@example.invalid" eval/abtest/fixtures/lib.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/fixtures/lib.sh`
   anchor: line matching `export GIT_AUTHOR_NAME=abtest`
   indent: 0
   before:
~~~~
  export GIT_AUTHOR_NAME=abtest GIT_AUTHOR_EMAIL=abtest@example.invalid
  export GIT_COMMITTER_NAME=abtest GIT_COMMITTER_EMAIL=abtest@example.invalid
~~~~
   after:
~~~~
  export GIT_AUTHOR_NAME=dev GIT_AUTHOR_EMAIL=dev@example.invalid
  export GIT_COMMITTER_NAME=dev GIT_COMMITTER_EMAIL=dev@example.invalid
~~~~
3. file: `eval/abtest/fixtures/lib.sh`
   anchor: line matching `# abt_leak_guard DEST: fail closed when the built baseline names the eval or the tool in the files an agent`
   indent: 0
   before:
~~~~
# abt_leak_guard DEST: fail closed when the built baseline names the eval or the tool in the files an agent
~~~~
   after:
~~~~
# The words a git history must not carry, matched case-insensitively as whole words (plurals included).
# evaluate, copilot, personality and the like are fine.
ABT_LEAK_GIT_WORDS='\b(anti[- ]?slop|abtest|evals?|pilots?|personas?|claude|holdouts?|fixtures?|traps?|plants?)\b|hidden checks?'

# _abt_leak_hit REGEX TEXT: print the first match and return 0; return 1 for no match, 2 when grep itself failed.
_abt_leak_hit() {
  local out rc
  out="$(grep -oiE "$1" <<< "$2")"; rc=$?
  if [ "$rc" -eq 0 ]; then printf '%s\n' "${out%%$'\n'*}"; return 0; fi
  [ "$rc" -eq 1 ] && return 1
  return 2
}

# _abt_leak_hist DEST: scan the git history of DEST (commit authors, committers and messages on every branch,
# ref names, tag messages and taggers) for ABT_LEAK_GIT_WORDS. Prints the word on stderr and returns 1; a
# failing git or grep also returns 1.
_abt_leak_hist() {
  local dest="$1" meta hit rc
  meta="$(git -C "$dest" log --all --format='%an%n%ae%n%cn%n%ce%n%B')" \
    || { echo "build: git log failed in $dest; the leak guard cannot scan it" >&2; return 1; }
  meta="$meta"$'\n'"$(git -C "$dest" for-each-ref --format='%(refname)%0a%(taggername)%0a%(contents)')" \
    || { echo "build: git for-each-ref failed in $dest; the leak guard cannot scan it" >&2; return 1; }
  hit="$(_abt_leak_hit "$ABT_LEAK_GIT_WORDS" "$meta")"; rc=$?
  case "$rc" in
    0) echo "build: the git history of $dest names the eval or the tool ('$hit')" >&2; return 1 ;;
    1) return 0 ;;
    *) echo "build: grep failed on the git history of $dest" >&2; return 1 ;;
  esac
}

# abt_leak_guard DEST: fail closed when the built baseline names the eval or the tool in the files an agent
~~~~
4. file: `eval/abtest/fixtures/lib.sh`
   anchor: line matching `  return 0`
   indent: 0
   before:
~~~~
  done
  return 0
}
~~~~
   after:
~~~~
  done
  if [ -e "$dest/.git" ]; then _abt_leak_hist "$dest" || return 1; fi
  return 0
}
~~~~
5. file: `eval/abtest/fixtures/lib.sh`
   anchor: line matching `# abt_fixture_baseline DEST: turn DEST into a git repo`
   indent: 0
   before:
~~~~
# abt_fixture_baseline DEST: turn DEST into a git repo with one commit named
# baseline and print the commit sha (the last stdout line of build.sh).
abt_fixture_baseline() {
  abt_leak_guard "$1" || return 1
  abt_fixture_env
  ( cd "$1" && git init -q -b main && git add -A && git commit -q -m baseline && git rev-parse HEAD )
}
~~~~
   after:
~~~~
# abt_fixture_baseline DEST: turn DEST into a git repo with one neutral commit ("initial import" by dev) and
# print the commit sha (the last stdout line of build.sh). The guard runs before the commit and again on the
# finished repository; a leaking history is removed, so no refused build leaves a repository behind.
abt_fixture_baseline() {
  abt_leak_guard "$1" || return 1
  abt_fixture_env
  ( cd "$1" && git init -q -b main && git add -A && git commit -q -m "initial import" ) || return 1
  abt_leak_guard "$1" || { rm -rf "${1%/}/.git"; return 1; }
  git -C "$1" rev-parse HEAD
}
~~~~
6. file: `eval/abtest/arms/arm-b.sh`
   anchor: line matching `git -c user.name=abtest -c user.email=abtest@example.invalid commit`
   before: `( cd "$wt" && git add -A && git -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m "arm-b scaffold" )`
   after: `( cd "$wt" && git add -A && git -c user.name=dev -c user.email=dev@example.invalid commit -q -m "add project tooling" )`
7. file: `tests/abtest-arms.test.sh`
   anchor: line matching `check "arm B scaffold commit subject"`
   indent: 0
   before:
~~~~
check "arm B scaffold commit subject" "$(git -C "$T/wb" log -1 --format=%s)" "arm-b scaffold"
~~~~
   after:
~~~~
check "arm B scaffold commit subject is neutral" "$(git -C "$T/wb" log -1 --format=%s)" "add project tooling"
check "arm B scaffold commit identity is neutral" "$(git -C "$T/wb" log -1 --format='%an|%ae|%cn|%ce')" "dev|dev@example.invalid|dev|dev@example.invalid"
check "no commit the candidate can see names the test" "$(git -C "$T/wb" log --format='%an %ae %cn %ce %B' | grep -ciE 'abtest|eval|scaffold')" "0"
~~~~
8. file: `tests/abtest-checks.test.sh`
   anchor: line matching `the E1 build, with its own guard, still builds under the lib guard`
   indent: 0
   insert-after:
~~~~
# --- neutral baseline identity and git-history scan (abt-u05d) ---
# A failing tool must fail the guard: each case puts a fake tool first on PATH that exits non-zero.
FK="$T/fake"; mkdir -p "$FK"
lgfake() {
  local tool="$1" body="$2" dir="$3"
  printf '#!/bin/sh\n%s\n' "$body" > "$FK/$tool"; chmod +x "$FK/$tool"
  ( PATH="$FK:$PATH"; . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_leak_guard "$dir" ) 2>&1; echo "rc=$?"
  rm -f "${FK:?}/${tool:?}"
}
rm -rf "$T/lg/gitfail"; mkdir -p "$T/lg/gitfail"; printf '{"description":"notes"}\n' > "$T/lg/gitfail/package.json"
( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_baseline "$T/lg/gitfail" > /dev/null )
printf '#!/bin/sh\ncase " $* " in *" $FAKE_GIT_FAIL "*) exit 128 ;; esac\nexec "$FAKE_GIT_REAL" "$@"\n' > "$FK/git"; chmod +x "$FK/git"
REALGIT="$(command -v git)"
lgfakegit() { ( PATH="$FK:$PATH"; FAKE_GIT_REAL="$REALGIT"; export FAKE_GIT_REAL; FAKE_GIT_FAIL="$1"; export FAKE_GIT_FAIL; . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_leak_guard "$2" ) 2>&1; echo "rc=$?"; }
out="$(lgfakegit log "$T/lg/gitfail")"
has "leak guard: a failing git log fails the guard" "$out" "git log failed in"
out="$(lgfakegit for-each-ref "$T/lg/gitfail")"
has "leak guard: a failing git for-each-ref fails the guard" "$out" "git for-each-ref failed in"
out="$(lgfakegit nothing "$T/lg/gitfail")"
has "leak guard: the same fake git that fails nothing lets a clean history pass (control)" "$out" "rc=0"
rm -f "${FK:?}/git"
rm -rf "$T/lg/gitnoscope"; mkdir -p "$T/lg/gitnoscope/src"; printf 'x\n' > "$T/lg/gitnoscope/src/x.js"
( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_baseline "$T/lg/gitnoscope" > /dev/null )
out="$(lgfake grep 'exit 2' "$T/lg/gitnoscope")"
has "leak guard: a failing grep fails the guard on a history" "$out" "grep failed on the git history"
# The git history is scanned too.
lgrepo() {
  local name="$1" msg="$2"
  rm -rf "$T/lg/hist"; mkdir -p "$T/lg/hist"; printf '{"description":"notes"}\n' > "$T/lg/hist/package.json"
  shift 2
  ( cd "$T/lg/hist" && git init -q -b main && git add -A \
    && env GIT_AUTHOR_NAME=dev GIT_AUTHOR_EMAIL=dev@example.invalid GIT_COMMITTER_NAME=dev GIT_COMMITTER_EMAIL=dev@example.invalid "$@" git commit -q -m "$msg" )
}
lgrepo neutral "initial import"
lgcase "leak guard: a neutral history passes (control)" "$T/lg/hist" 0 ""
lgrepo trapezoid "trapezoid and plantation notes"
lgcase "leak guard: near words in a history are fine (control)" "$T/lg/hist" 0 ""
lgrepo an "initial import" GIT_AUTHOR_NAME=abtest
lgcase "leak guard: an author name abtest is refused" "$T/lg/hist" 1 "git history of $T/lg/hist names the eval or the tool ('abtest')"
lgrepo ae "initial import" GIT_AUTHOR_EMAIL=abtest@example.invalid
lgcase "leak guard: an author email abtest is refused" "$T/lg/hist" 1 "('abtest')"
lgrepo cn "initial import" GIT_COMMITTER_NAME=eval
lgcase "leak guard: a committer name eval is refused" "$T/lg/hist" 1 "('eval')"
lgrepo ce "initial import" GIT_COMMITTER_EMAIL=claude@example.invalid
lgcase "leak guard: a committer email claude is refused" "$T/lg/hist" 1 "('claude')"
lgrepo m1 "fixture baseline"
lgcase "leak guard: the word fixture in a commit message is refused" "$T/lg/hist" 1 "('fixture')"
lgrepo m2 "add the trap"
lgcase "leak guard: the word trap in a commit message is refused" "$T/lg/hist" 1 "('trap')"
lgrepo m3 "AntiSlop import"
lgcase "leak guard: AntiSlop in a commit message is refused" "$T/lg/hist" 1 "('AntiSlop')"
lgrepo m4 "initial import"
git -C "$T/lg/hist" commit -q --amend -m "initial import" -m "the plant is here"
lgcase "leak guard: a word in the body of a commit message is refused" "$T/lg/hist" 1 "('plant')"
for spec in "evals|evals" "pilots|pilots" "personas|personas" "holdouts|holdouts" "hidden checks|hidden checks" "Anti-Slop|Anti-Slop" "anti slop|anti slop" "traps|traps" "plants|plants" "fixtures|fixtures"; do
  IFS='|' read -r hm hw <<< "$spec"
  lgrepo hw "update $hm"
  lgcase "leak guard: the history word $hm is refused" "$T/lg/hist" 1 "('$hw')"
done
lgrepo br "initial import"
git -C "$T/lg/hist" branch eval-branch
lgcase "leak guard: a branch name with eval is refused" "$T/lg/hist" 1 "('eval')"
lgrepo tg "initial import"
git -C "$T/lg/hist" tag pilot-1
lgcase "leak guard: a tag name with pilot is refused" "$T/lg/hist" 1 "('pilot')"
lgrepo ta "initial import"
git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid tag -a v1 -m "persona release"
lgcase "leak guard: an annotated tag message with persona is refused" "$T/lg/hist" 1 "('persona')"
lgrepo tn "initial import"
git -C "$T/lg/hist" -c user.name=abtest -c user.email=dev@example.invalid tag -a v2 -m "release"
lgcase "leak guard: an annotated tag by a tagger abtest is refused" "$T/lg/hist" 1 "('abtest')"
lgrepo ob "initial import"
git -C "$T/lg/hist" checkout -q -b other && git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid commit -q --allow-empty -m "fixture notes" && git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid commit -q --allow-empty -m "tidy" && git -C "$T/lg/hist" checkout -q main && git -C "$T/lg/hist" branch -q -m other side
lgcase "leak guard: a commit reachable only from another branch is scanned" "$T/lg/hist" 1 "('fixture')"
lgrepo oc "fixture first"
git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid commit -q --allow-empty -m "tidy"
lgcase "leak guard: a leaking subject on an older commit is refused" "$T/lg/hist" 1 "('fixture')"
lgrepo od "initial import"
~~~~
9. file: `tests/abtest-checks.test.sh`
   anchor: line matching `lgrepo od "initial import"`
   indent: 0
   insert-after:
~~~~
git -C "$T/lg/hist" commit -q --amend -m "initial import" -m "the plant is here"
git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid commit -q --allow-empty -m "tidy"
lgcase "leak guard: a leaking body on an older commit is refused" "$T/lg/hist" 1 "('plant')"
lgrepo nw "subtrap and microeval notes"
lgcase "leak guard: a word glued to other letters in a history is fine (control)" "$T/lg/hist" 0 ""
# abt_fixture_baseline: neutral identity, neutral message, one branch, and a leaking history leaves no repository.
rm -rf "$T/lg/id"; mkdir -p "$T/lg/id"; printf '{"description":"notes"}\n' > "$T/lg/id/package.json"
( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_baseline "$T/lg/id" > /dev/null )
check "the baseline commit has a neutral identity and message" "$(git -C "$T/lg/id" log --format='%an|%ae|%cn|%ce|%s')" "dev|dev@example.invalid|dev|dev@example.invalid|initial import"
check "the baseline repository has one commit and one ref" "$(git -C "$T/lg/id" rev-list --all --count)|$(git -C "$T/lg/id" for-each-ref --format='%(refname)')" "1|refs/heads/main"
check "the baseline commit date is fixed" "$(git -C "$T/lg/id" log -1 --format='%aI|%cI')" "2026-01-01T00:00:00+00:00|2026-01-01T00:00:00+00:00"
check "a built E1 baseline passes the guard, history included" "$(lg "$T/lg/e01")" "rc=0"
check "the built E1 baseline history is neutral" "$(git -C "$T/lg/e01" log --format='%an|%ae|%s')" "dev|dev@example.invalid|initial import"
rm -rf "$T/lg/leakid"; mkdir -p "$T/lg/leakid"; printf '{"description":"notes"}\n' > "$T/lg/leakid/package.json"
out="$( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_env() { export GIT_AUTHOR_NAME=abtest GIT_AUTHOR_EMAIL=a@example.invalid GIT_COMMITTER_NAME=dev GIT_COMMITTER_EMAIL=dev@example.invalid; }; abt_fixture_baseline "$T/lg/leakid" 2>&1 )"; rc=$?
check "a baseline whose history leaks is refused" "$rc" "1"
has "the history leak is named" "$out" "names the eval or the tool ('abtest')"
check "the refused baseline left no repository" "$(test -e "$T/lg/leakid/.git" && echo made || echo none)" "none"
~~~~
10. command: `git add eval/abtest/fixtures/lib.sh eval/abtest/arms/arm-b.sh tests/abtest-checks.test.sh tests/abtest-arms.test.sh && git commit -m "fix(abt-u05d): fixture baselines and the arm B scaffold commit carry a neutral identity and the leak guard scans the git history (#602)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/verify-checks.sh`, `eval/abtest/checks/` (other units own them; the reference commit made while verifying is never visible to a candidate)
- `eval/abtest/fixtures/e01-ambiguous-tax/` (its build.sh keeps its own description and word checks)
- `eval/abtest/templates/` (the T2 template is not touched by this unit)
- `tests/abtest-blind.test.sh`, `tests/abtest-row.test.sh`, `tests/abtest-stream.test.sh` (other units own them)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-checks.test.sh`
   exit: 0
   stdout: `All abtest-checks checks passed.`
   mutation: skip edit 3 (the history scan); the new rows FAIL, the script exits non-zero and the fragment is absent.
   proof: mutation matrix of 46 single edits, run in a scratch copy of the finished change, each making a suite exit non-zero: L01-L04 put abtest back into the author or committer name or email of abt_fixture_env; L05 the old commit message baseline; L17-L22 and L75-L84 drop one history word, plural or spelling (fixtures, traps, plants, abtest, evals, pilots, personas, holdouts, hidden checks, the hyphen or the space of Anti-Slop, claude, holdout); L23 scan the history with the file word list; L24 drop case-insensitivity; L25-L26 swap the grep exit-code handling; L51-L52 ignore a failing git log or git for-each-ref; L53-L54 let a failing grep or a hit pass; L55-L60 drop the author name, author email, committer name, committer email, the message, or read the subject only; L61 read only the current branch; L62-L64 drop ref names, taggers or tag messages; L65 skip the history scan; L69b drop the leading word boundary; L71 drop the second guard run; L72 keep the repository when the history leaks; A1-A3 put abtest or the old subject back into arm-b.sh. Two edits are equivalent and not counted: dropping the first guard run (the second one still refuses and removes the repository) and ignoring a failing git commit (git rev-parse still fails)
2. run: `bash tests/abtest-arms.test.sh`
   exit: 0
   stdout: `All abtest-arms checks passed.`
   mutation: skip edit 6 (the neutral scaffold commit); the subject and identity rows FAIL and the fragment is absent.
3. run: `bash tests/abtest-checks.test.sh | grep -c '^ok   leak guard:'`
   exit: 0
   stdout: `44`
   mutation: skip edit 3; the history rows FAIL and the count drops below 44.
4. run: `d=$(mktemp -d); mkdir "$d/w"; printf '{"description":"notes"}\n' > "$d/w/package.json"; ( . eval/abtest/fixtures/lib.sh; abt_fixture_baseline "$d/w" > /dev/null ); git -C "$d/w" log --format='%an|%ae|%cn|%ce|%s'; rm -rf "${d:?}"`
   exit: 0
   stdout: `dev|dev@example.invalid|dev|dev@example.invalid|initial import`
   mutation: skip edit 2; the log prints abtest as author and committer name.
5. run: `d=$(mktemp -d); printf '{"description":"notes"}\n' > "$d/package.json"; git -C "$d" init -q -b main; git -C "$d" add -A; env GIT_AUTHOR_NAME=abtest GIT_AUTHOR_EMAIL=dev@example.invalid GIT_COMMITTER_NAME=dev GIT_COMMITTER_EMAIL=dev@example.invalid git -C "$d" commit -q -m "initial import"; ( . eval/abtest/fixtures/lib.sh; abt_leak_guard "$d" ) 2>&1 | grep -o "names the eval or the tool ('abtest')"; rc=$?; rm -rf "${d:?}"; exit $rc`
   exit: 0
   stdout: `names the eval or the tool ('abtest')`
   mutation: skip edit 4 (the call of the history scan); the guard never reads the history, prints nothing and grep exits 1.
6. run: `bash tests/abtest-arms.test.sh | grep -c -e '^ok   arm B scaffold commit subject is neutral' -e '^ok   arm B scaffold commit identity is neutral' -e '^ok   no commit the candidate can see names the test'`
   exit: 0
   stdout: `3`
   mutation: skip edit 7; the rows are absent and the count is 0 (exit 1).
7. run: `bash tests/abtest-checks.test.sh | grep -c '^ok   the refused baseline left no repository'`
   exit: 0
   stdout: `1`
   mutation: skip edit 5 (the baseline function with its second guard run); the old function never scans the history, the leaking baseline is not refused and the count is 0 (exit 1).
   proof: mutation L71 of the matrix in criterion 1, run in a scratch copy: with the second guard run deleted from abt_fixture_baseline the leaking-history rows print FAIL.
8. run: `bash eval/abtest/verify-checks.sh e01-ambiguous-tax`
   exit: 0
   stdout: `verify-checks: ok`
   mutation: delete the GIT_AUTHOR_DATE and GIT_COMMITTER_DATE export line from abt_fixture_env in the finished lib.sh; two builds then commit different shas and verify-checks exits 1.
   proof: scratch run of that edit: verify-checks printed nondeterministic build and exited 1.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05d\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/arms/arm-b.sh eval/abtest/fixtures/lib.sh tests/abtest-arms.test.sh tests/abtest-checks.test.sh`
   mutation: skip edit 10 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05d\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 10; no unit commit exists and the exit is 3.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05d\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/fixtures/lib.sh eval/abtest/arms/arm-b.sh tests/abtest-checks.test.sh tests/abtest-arms.test.sh | grep -vcE "^[a-z]+\(abt-u05d\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
12. run: `git status --porcelain -- eval/abtest/fixtures/lib.sh eval/abtest/arms/arm-b.sh tests/abtest-checks.test.sh tests/abtest-arms.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 10; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-checks.test.sh and tests/abtest-arms.test.sh (criteria 3 to 7 are the red-then-green checks: the neutral identity, the history scan and the new rows do not exist at HEAD)
blast-radius: eval/abtest/fixtures/lib.sh:7, eval/abtest/fixtures/lib.sh:43, eval/abtest/fixtures/e01-ambiguous-tax/build.sh:27, eval/abtest/arms/arm-b.sh:67, tests/abtest-arms.test.sh:53
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 1 and 2 (both suites pass at HEAD), criterion 8 (two builds already agree) and criterion 12 (the scoped clean-tree check) pass at HEAD by design; criteria 3 to 7 fail at HEAD.
extends-landed-code: abt-u05c is on master (907e8b92); every anchor and every replaced block is taken from that commit. The identity lines, one comment line, the end of the guard function, the baseline function, one line of arm-b.sh and one row of abtest-arms.test.sh are replaced; the rest of each file stays. abt-u05e (the file-scan hardening) replaces the guard function again and is blocked by this unit.
order: abt-u06b also edits tests/abtest-checks.test.sh (a block before its final summary line); either order gives a clean tree, the edge only keeps the shared file serial.
sha-ripple: every fixture baseline sha changes (E1 19d7542b becomes b1142670) because the identity and the message are part of the commit. Nothing in the repository keys a literal baseline sha; verify-checks still proves two builds give one sha.
visible-to-candidate: the baseline commit (dev, initial import) and the Arm B scaffold commit (dev, add project tooling) are the only commits a candidate sees. The reference commit made by verify-checks and the post-run snapshot commit of the runner are never visible to it.
helpers: the rows define lgfake (a fake tool first on PATH) and lgfakegit; abt-u05e reuses them, so keep their names.
fail-closed: every row compares an explicit status or fragment; a crash or empty output reads as FAILURE. A failing git log, git for-each-ref or grep fails the guard.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u05d): fixture baselines and the arm B scaffold commit carry a neutral identity and the leak guard scans the git history (#602)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u05d (#602)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
