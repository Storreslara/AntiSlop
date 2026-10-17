Unit: abt-u05f

## Objective
abt_leak_guard refuses a symlinked destination and strips every trailing slash before it scans; words are delimited by anything that is not a letter or digit (EVAL_MODE, CLAUDE_API_KEY, anti_slop, hidden-check and a hidden or anti word pair across a line break are refused, retrieval and Describe pass); the history scan also reads git notes and tagger emails; abt_fixture_baseline deletes git's sample hooks so no forbidden word is left in .git outside objects; the lib.sh comment says top-level docs/; the E1 build says Minimal library (no fixture); and the test helpers fail a row whose setup fails. The suite goes from 178 to 231 rows. One commit.

## Retrieval
GitHub issues: `gh issue view 607 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/fixtures/lib.sh` (anchor: line matching `# The words a git history must not carry`)
- `eval/abtest/fixtures/e01-ambiguous-tax/build.sh` (anchor: line matching `Minimal fixture library with no external dependencies.`)
- `tests/abtest-checks.test.sh` (anchor: line matching `has "the failing build says why"`)

## Ordered edits
1. command: `test -f eval/abtest/fixtures/lib.sh && test -f eval/abtest/fixtures/e01-ambiguous-tax/build.sh && test -f tests/abtest-checks.test.sh && grep -q _abt_leak_hist eval/abtest/fixtures/lib.sh && ! grep -q "ABT_LEAK_BEFORE" eval/abtest/fixtures/lib.sh && ! grep -q "abt-u05f" tests/abtest-checks.test.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/fixtures/lib.sh`
   anchor: line matching `# The words a git history must not carry, matched case-insensitively as whole words (plurals included).`
   indent: 0
   before:
~~~~
# The words a git history must not carry, matched case-insensitively as whole words (plurals included).
# evaluate, copilot, personality and the like are fine.
ABT_LEAK_GIT_WORDS='\b(anti[- ]?slop|abtest|evals?|pilots?|personas?|claude|holdouts?|fixtures?|traps?|plants?)\b|hidden checks?'

# _abt_leak_hit REGEX TEXT: print the first match and return 0; return 1 for no match, 2 when grep itself failed.
_abt_leak_hit() {
  local out rc
  out="$(grep -oiE "$1" <<< "$2")"; rc=$?
  if [ "$rc" -eq 0 ]; then printf '%s\n' "${out%%$'\n'*}"; return 0; fi
~~~~
   after:
~~~~
# The words a git history must not carry, matched case-insensitively. A word is delimited by anything that is not
# a letter or digit, so EVAL_MODE, CLAUDE_API_KEY, anti_slop and eval_run are caught while evaluate, retrieval,
# Describe and personality are not. anti and slop, or hidden and check, may be separated by any run of other
# characters; plurals are included. Out of scope: words joined to letters or digits (HiddenCheck, myEvalMode).
ABT_LEAK_GIT_WORDS='(^|[^[:alnum:]])(anti[^[:alnum:]]*slop|abtest|evals?|pilots?|personas?|claude|holdouts?|fixtures?|traps?|plants?|hidden[^[:alnum:]]+checks?)([^[:alnum:]]|$)'

# _abt_leak_hit REGEX TEXT: print the first match without its delimiters and return 0; return 1 for no match, 2
# when grep itself failed. Line breaks count as spaces, so a word pair split across two lines is still found.
_abt_leak_hit() {
  local out rc hit flat="${2//$'\n'/ }"
  out="$(grep -oiE "$1" <<< "$flat")"; rc=$?
  if [ "$rc" -eq 0 ]; then
    hit="${out%%$'\n'*}"
    hit="${hit#"${hit%%[[:alnum:]]*}"}"
    printf '%s\n' "${hit%"${hit##*[[:alnum:]]}"}"
    return 0
  fi
~~~~
3. file: `eval/abtest/fixtures/lib.sh`
   anchor: line matching `# ref names, tag messages and taggers) for ABT_LEAK_GIT_WORDS. Prints the word on stderr and returns 1; a`
   before: `# ref names, tag messages and taggers) for ABT_LEAK_GIT_WORDS. Prints the word on stderr and returns 1; a`
   after: `# notes, ref names, tag messages, taggers and tagger emails) for ABT_LEAK_GIT_WORDS. Prints the word on stderr and returns 1; a`
4. file: `eval/abtest/fixtures/lib.sh`
   anchor: line matching `  meta="$(git -C "$dest" log --all --format='%an%n%ae%n%cn%n%ce%n%B')" \`
   indent: 0
   before:
~~~~
  meta="$(git -C "$dest" log --all --format='%an%n%ae%n%cn%n%ce%n%B')" \
    || { echo "build: git log failed in $dest; the leak guard cannot scan it" >&2; return 1; }
  meta="$meta"$'\n'"$(git -C "$dest" for-each-ref --format='%(refname)%0a%(taggername)%0a%(contents)')" \
~~~~
   after:
~~~~
  meta="$(git -C "$dest" log --all --show-notes='*' --format='%an%n%ae%n%cn%n%ce%n%B%n%N')" \
    || { echo "build: git log failed in $dest; the leak guard cannot scan it" >&2; return 1; }
  meta="$meta"$'\n'"$(git -C "$dest" for-each-ref --format='%(refname)%0a%(taggername)%0a%(taggeremail)%0a%(contents)')" \
~~~~
5. file: `eval/abtest/fixtures/lib.sh`
   anchor: line matching `# The words that must not reach a candidate in the files it reads first: matched case-insensitively as whole`
   indent: 0
   before:
~~~~
# The words that must not reach a candidate in the files it reads first: matched case-insensitively as whole
# words, plurals included. evaluate, copilot, personality and the like are fine.
ABT_LEAK_WORDS='\b(anti[- ]?slop|abtest|evals?|pilots?|personas?|claude|holdouts?)\b|hidden checks?'
~~~~
   after:
~~~~
# The words that must not reach a candidate in the files it reads first, with the same delimiting rule as
# ABT_LEAK_GIT_WORDS (fixture, trap and plant are checked in the history only).
ABT_LEAK_WORDS='(^|[^[:alnum:]])(anti[^[:alnum:]]*slop|abtest|evals?|pilots?|personas?|claude|holdouts?|hidden[^[:alnum:]]+checks?)([^[:alnum:]]|$)'
~~~~
6. file: `eval/abtest/fixtures/lib.sh`
   anchor: line matching `# everything under docs/ (any case), every path with a dot-directory or dot-file component, and any file named`
   before: `# everything under docs/ (any case), every path with a dot-directory or dot-file component, and any file named`
   after: `# everything under the top-level docs/ (any case; a docs directory deeper down is not special), every path with a dot-directory or dot-file component, and any file named`
7. file: `eval/abtest/fixtures/lib.sh`
   anchor: line matching `  local dest="${1%/}" list rc`
   indent: 0
   before:
~~~~
  local dest="${1%/}" list rc
~~~~
   after:
~~~~
  local dest="$1" list rc
  while [ "${dest%/}" != "$dest" ] && [ "$dest" != / ]; do dest="${dest%/}"; done
  [ ! -L "$dest" ] || { echo "build: $dest is a symbolic link; the leak guard does not follow links" >&2; return 1; }
~~~~
8. file: `eval/abtest/fixtures/lib.sh`
   anchor: line matching `# abt_fixture_baseline DEST: turn DEST into a git repo with one neutral commit ("initial import" by dev) and`
   indent: 0
   before:
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
~~~~
   after:
~~~~
# abt_fixture_baseline DEST: turn DEST into a git repo with one neutral commit ("initial import" by dev), without
# git's sample hooks, and print the commit sha (the last stdout line of build.sh). The guard runs before the
# commit and again on the finished repository; a leaking history is removed, so no refused build leaves one behind.
abt_fixture_baseline() {
  local d="$1"
  while [ "${d%/}" != "$d" ] && [ "$d" != / ]; do d="${d%/}"; done
  abt_leak_guard "$d" || return 1
  abt_fixture_env
  ( cd "$d" && git init -q -b main ) || return 1
  # git's sample hooks name eval and trap; a candidate would read them in .git/hooks.
  [ ! -d "$d/.git/hooks" ] || find "$d/.git/hooks" -type f -name '*.sample' -delete || return 1
  ( cd "$d" && git add -A && git commit -q -m "initial import" ) || return 1
  abt_leak_guard "$d" || { rm -rf "${d:?}/.git"; return 1; }
  git -C "$d" rev-parse HEAD
~~~~
9. file: `eval/abtest/fixtures/e01-ambiguous-tax/build.sh`
   anchor: line matching `sed -i 's|^\(  "description": \).*$|\1"Minimal fixture library with no external dependencies.",|' "$dest/package.json"`
   before: `sed -i 's|^\(  "description": \).*$|\1"Minimal fixture library with no external dependencies.",|' "$dest/package.json"`
   after: `sed -i 's|^\(  "description": \).*$|\1"Minimal library with no external dependencies.",|' "$dest/package.json"`
10. file: `eval/abtest/fixtures/e01-ambiguous-tax/build.sh`
   anchor: line matching `need package.json '"description": "Minimal fixture library with no external dependencies."'`
   before: `need package.json '"description": "Minimal fixture library with no external dependencies."'`
   after: `need package.json '"description": "Minimal library with no external dependencies."'`
11. file: `tests/abtest-checks.test.sh`
   anchor: line matching `lgmk() { mkdir -p "$T/lg/$1/$(dirname "$2")"; printf '%s\n' "$3" > "$T/lg/$1/$2"; }`
   before: `lgmk() { mkdir -p "$T/lg/$1/$(dirname "$2")"; printf '%s\n' "$3" > "$T/lg/$1/$2"; }`
   after: `lgmk() { mkdir -p "$T/lg/$1/$(dirname "$2")" && printf '%s\n' "$3" > "$T/lg/$1/$2" || bad "setup: could not write lg/$1/$2"; }`
12. file: `tests/abtest-checks.test.sh`
   anchor: line matching `rm -rf "$T/lg/leak"; cp -r "$T/lg/clean" "$T/lg/leak"; lgmk leak "$2" "$3"`
   before: `  rm -rf "$T/lg/leak"; cp -r "$T/lg/clean" "$T/lg/leak"; lgmk leak "$2" "$3"`
   after: `  rm -rf "$T/lg/leak"; cp -r "$T/lg/clean" "$T/lg/leak" || bad "setup: cp failed for $1"; lgmk leak "$2" "$3"`
13. file: `tests/abtest-checks.test.sh`
   anchor: line matching `&& env GIT_AUTHOR_NAME=dev GIT_AUTHOR_EMAIL=dev@example.invalid GIT_COMMITTER_NAME=dev GIT_COMMITTER_EMAIL=dev@example.invalid "$@" git commit -q -m "$msg" )`
   before: `    && env GIT_AUTHOR_NAME=dev GIT_AUTHOR_EMAIL=dev@example.invalid GIT_COMMITTER_NAME=dev GIT_COMMITTER_EMAIL=dev@example.invalid "$@" git commit -q -m "$msg" )`
   after: `    && env GIT_AUTHOR_NAME=dev GIT_AUTHOR_EMAIL=dev@example.invalid GIT_COMMITTER_NAME=dev GIT_COMMITTER_EMAIL=dev@example.invalid "$@" git commit -q -m "$msg" ) || bad "setup: git commit failed for $name"`
14. file: `tests/abtest-checks.test.sh`
   anchor: line matching `has "the failing build says why"`
   indent: 0
   insert-after:
~~~~
# --- leak guard, last hardening round (abt-u05f): symlinked destination, slashes, word delimiters, notes, sample hooks ---
printf 'x\n' > "$T/lg/blockfile"
out="$( bad() { echo "BAD:$*"; }; lgmk blockfile/sub f x 2> /dev/null )"
has "lgmk reports a setup that cannot write" "$out" "BAD:setup: could not write lg/blockfile/sub/f"
out="$( bad() { echo "BAD:$*"; }; lgrepo broken "initial import" GIT_AUTHOR_DATE=not-a-date 2> /dev/null )"
has "lgrepo reports a commit that fails" "$out" "BAD:setup: git commit failed for broken"
out="$( cp() { return 1; }; bad() { echo "BAD:$*"; }; lgleak "probe" README.md x eval 2> /dev/null )"
has "lgleak reports a copy that fails" "$out" "BAD:setup: cp failed for probe"
ln -s "$T/lg/clean" "$T/lg/linkdest"
lgcase "leak guard: a symlinked destination is refused" "$T/lg/linkdest" 1 "is a symbolic link"
lgcase "leak guard: a symlinked destination with trailing slashes is refused" "$T/lg/linkdest//" 1 "linkdest is a symbolic link"
rm -rf "$T/lg/linktarget" "$T/lg/linkbase"; mkdir -p "$T/lg/linktarget"; printf '{"description":"notes"}\n' > "$T/lg/linktarget/package.json"; ln -s "$T/lg/linktarget" "$T/lg/linkbase"
out="$( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_baseline "$T/lg/linkbase" 2>&1 )"; rc=$?
check "a baseline into a symlinked destination is refused" "$rc" "1"
check "the refused symlinked destination got no repository" "$(test -e "$T/lg/linktarget/.git" && echo made || echo none)" "none"
rm -rf "$T/lg/slash"; cp -r "$T/lg/clean" "$T/lg/slash" || bad "setup: cp failed for slash"
lgmk slash docs/a.md 'the eval harness'
lgcase "leak guard: two trailing slashes still scan docs" "$T/lg/slash//" 1 "docs/a.md names the eval or the tool ('eval')"
rm -f "${T:?}/lg/slash/docs/a.md"
lgmk slash .github/x.yml 'run claude here'
lgcase "leak guard: three trailing slashes still scan dot-paths" "$T/lg/slash///" 1 ".github/x.yml names the eval or the tool ('claude')"
# Word delimiters: anything that is not a letter or digit ends a word, so underscores and hyphens join nothing.
while IFS='|' read -r txt want; do
  rm -rf "$T/lg/word"; mkdir -p "$T/lg/word" && printf '%b\n' "$txt" > "$T/lg/word/README.md" || bad "setup: word table"
  lgcase "leak guard word table: '$txt' is refused" "$T/lg/word" 1 "README.md names the eval or the tool ('$want')"
done << 'EOF'
EVAL_MODE=1|EVAL
run_eval|eval
MY_CLAUDE|CLAUDE
use claude|claude
CLAUDE_API_KEY=x|CLAUDE
ANTI_SLOP_HOME=/x|ANTI_SLOP
anti_slop|anti_slop
eval_run|eval
my-eval-run|eval
hidden-check|hidden-check
hidden  check|hidden  check
hidden_checks|hidden_checks
(persona)|persona
--holdout=1|holdout
eval(x)|eval
Pilot.|Pilot
abtest_runner|abtest
anti\nslop|anti slop
hidden\ncheck|hidden check
EOF
while IFS= read -r txt; do
  rm -rf "$T/lg/word"; mkdir -p "$T/lg/word" && printf '%b\n' "$txt" > "$T/lg/word/README.md" || bad "setup: word table"
  lgcase "leak guard word table: '$txt' passes" "$T/lg/word" 0 ""
done << 'EOF'
Describe the retrieval of inscribed text
prevalent and medieval and evaluate and evaluation
personality, pilotage, copilot and claudette
anti-social slopes and a sloppy diff
hidden checkpoint and a hidden clock
ev\nal and anti\nsocial
EOF
while IFS= read -r txt; do
  rm -rf "$T/lg/word"; mkdir -p "$T/lg/word" && printf '%b\n' "$txt" > "$T/lg/word/README.md" || bad "setup: word table"
  lgcase "leak guard word table (out of scope, joined to letters or digits): '$txt' passes" "$T/lg/word" 0 ""
done << 'EOF'
HiddenCheck and hiddencheck
myEvalMode and AntiSlopHome
eval2 and 2eval
EOF
# History rows that were missing: singular words, joined words, tagger email, notes.
for spec in "a holdout run|holdout" "the hidden check|hidden check" "EVAL_MODE on|EVAL" "hidden-check|hidden-check" "anti_slop|anti_slop" "the hidden  check|hidden  check" "run_eval now|eval"; do
  IFS='|' read -r hm hw <<< "$spec"
  lgrepo hs "update $hm"
  lgcase "leak guard: the history phrase $hm is refused" "$T/lg/hist" 1 "('$hw')"
done
lgrepo te "initial import"
git -C "$T/lg/hist" -c user.name=dev -c user.email=abtest@example.invalid tag -a v9 -m "release" || bad "setup: tag failed"
lgcase "leak guard: an annotated tag by an abtest email is refused" "$T/lg/hist" 1 "('abtest')"
lgrepo nt "initial import"
git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid notes add -m "the plant is here" || bad "setup: notes add failed"
lgcase "leak guard: a git note is refused" "$T/lg/hist" 1 "('plant')"
lgrepo nt2 "initial import"
~~~~
15. file: `tests/abtest-checks.test.sh`
   anchor: line matching `lgrepo nt2 "initial import"`
   indent: 0
   insert-after:
~~~~
git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid notes --ref=review add -m "the trap is here" || bad "setup: notes add failed"
lgcase "leak guard: a note in another notes ref is refused" "$T/lg/hist" 1 "('trap')"
out="$(lgfake grep 'exit 2' "$T/lg/gitnoscope")"
has "leak guard: a failing grep on a history exits 1" "$out" "rc=1"
# git's sample hooks name eval and trap: the built baseline carries none, and no forbidden word sits anywhere in .git outside objects.
RE_GIT='(^|[^[:alnum:]])(eval|trap|fixture|plant|pilot|persona|claude|holdout|abtest)([^[:alnum:]]|$)'
gitwords() { find "$1/.git" -path "$1/.git/objects" -prune -o -type f -exec grep -IiEl "$RE_GIT" {} +; }
rm -rf "$T/lg/plain"; mkdir -p "$T/lg/plain"; git -C "$T/lg/plain" init -q || bad "setup: git init failed"
check "a plain git init does carry forbidden words in its sample hooks (control)" "$(test -n "$(gitwords "$T/lg/plain")" && echo found || echo none)" "found"
rm -rf "$T/lg/built"; mkdir -p "$T/lg/built"; printf '{"description":"notes"}\n' > "$T/lg/built/package.json"
( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_baseline "$T/lg/built" > /dev/null )
check "the built baseline carries no forbidden word in .git outside objects" "$(gitwords "$T/lg/built")" ""
check "the built baseline has no sample hook" "$(find "$T/lg/built/.git/hooks" -name '*.sample' | wc -l | tr -d ' ')" "0"
check "the built E1 baseline carries no forbidden word in .git outside objects" "$(gitwords "$T/lg/e01")" ""
check "the E1 description does not call the tree a fixture" "$(grep -c '"description": "Minimal library with no external dependencies."' "$T/lg/e01/package.json")|$(grep -ci fixture "$T/lg/e01/package.json")" "1|0"
~~~~
16. command: `git add eval/abtest/fixtures/lib.sh eval/abtest/fixtures/e01-ambiguous-tax/build.sh tests/abtest-checks.test.sh && git commit -m "fix(abt-u05f): the leak guard refuses a symlinked destination, strips every slash, delimits words by non-alphanumerics, reads notes, and the baseline carries no sample hooks (#607)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/fixtures/e02-preview-mutation/`, `eval/abtest/fixtures/e03-rename-query/`, `eval/abtest/fixtures/e04-search-injection/`, `eval/abtest/fixtures/e05-tags-feature/` (other units own them; abt-u08 is being implemented)
- `eval/abtest/arms/`, `eval/abtest/verify-checks.sh`, `eval/abtest/checks/` (other units own them)
- `eval/abtest/templates/`, `eval/fixtures/` (the T1 and T2 templates are not touched)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-checks.test.sh`
   exit: 0
   stdout: `All abtest-checks checks passed.`
   mutation: skip edit 2 (the first change of lib.sh); the new rows FAIL, the script exits non-zero and the fragment is absent.
   proof: mutation matrix of 53 single edits, run in a scratch copy of the finished change, each making bash tests/abtest-checks.test.sh exit non-zero: F drops one word of the file list (abtest, evals, pilots, personas, claude, holdouts, anti slop, hidden check), joins anti and slop, allows one separator in hidden check, drops the plural of check, removes the start or end delimiter, or lets an underscore or a digit join a word; G does the same to the history list (nine words, anti slop, hidden check, the single separator, the start delimiter, underscores); H removes the line flattening, either trim of the match, or case-insensitivity, or reads a failing grep as no hit; I drops git notes, the note text, the tagger email, the tagger name, ref names, or lets a failing grep on a history return 0; J accepts a symlinked destination, strips one slash only, or changes the symlink message; K removes the sample hook deletion, deletes the wrong pattern, makes a commit before the hooks are removed, or keeps the repository when the history leaks; T removes the failure report of lgmk, lgrepo or lgleak; E puts fixture back into the E1 description. Two edits are not claimed because they are equivalent today: the end delimiter of the history list (git output always ends with a line break) and the first guard run of abt_fixture_baseline (the second run and the removal of .git still refuse)
2. run: `bash tests/abtest-checks.test.sh | grep -c '^ok '`
   exit: 0
   stdout: `231`
   mutation: skip edit 2; the new rows FAIL and the count drops below 231.
3. run: `bash tests/abtest-checks.test.sh | grep -c '^ok   leak guard'`
   exit: 0
   stdout: `128`
   mutation: skip edit 2; the new refusal rows FAIL and the count drops below 128.
4. run: `d=$(mktemp -d); printf 'EVAL_MODE=1\n' > "$d/README.md"; ( . eval/abtest/fixtures/lib.sh; abt_leak_guard "$d" ) 2>&1 | grep -o "README.md names the eval or the tool ('EVAL')"; rc=$?; rm -rf "${d:?}"; exit $rc`
   exit: 0
   stdout: `README.md names the eval or the tool ('EVAL')`
   mutation: skip edit 5; the old pattern needs a word boundary, EVAL_MODE passes, nothing prints and grep exits 1.
5. run: `d=$(mktemp -d); printf 'a hidden  check here\n' > "$d/README.md"; ( . eval/abtest/fixtures/lib.sh; abt_leak_guard "$d" ) 2>&1 | grep -o "README.md names the eval or the tool ('hidden  check')"; rc=$?; rm -rf "${d:?}"; exit $rc`
   exit: 0
   stdout: `README.md names the eval or the tool ('hidden  check')`
   mutation: skip edit 5; the old pattern allows one space only, nothing prints and grep exits 1.
6. run: `d=$(mktemp -d); mkdir "$d/real"; ln -s "$d/real" "$d/link"; ( . eval/abtest/fixtures/lib.sh; abt_leak_guard "$d/link" ) 2>&1 | grep -o 'link is a symbolic link'; rc=$?; rm -rf "${d:?}"; exit $rc`
   exit: 0
   stdout: `link is a symbolic link`
   mutation: skip edit 7; the old guard follows the link and scans the target, prints nothing and grep exits 1.
7. run: `d=$(mktemp -d); mkdir -p "$d/w/docs"; printf 'the eval harness\n' > "$d/w/docs/a.md"; ( . eval/abtest/fixtures/lib.sh; abt_leak_guard "$d/w//" ) 2>&1 | grep -o "docs/a.md names the eval or the tool ('eval')"; rc=$?; rm -rf "${d:?}"; exit $rc`
   exit: 0
   stdout: `docs/a.md names the eval or the tool ('eval')`
   mutation: skip edit 7; two trailing slashes drop docs out of scope, nothing prints and grep exits 1.
8. run: `d=$(mktemp -d); mkdir "$d/w"; printf '{"description":"notes"}\n' > "$d/w/package.json"; ( . eval/abtest/fixtures/lib.sh; abt_fixture_baseline "$d/w" > /dev/null ); find "$d/w/.git/hooks" -name '*.sample' | wc -l | tr -d ' '; rm -rf "${d:?}"`
   exit: 0
   stdout: `0`
   mutation: skip edit 8 (the baseline function); the sample hooks stay and the count is 12 or more.
9. run: `grep -c 'the top-level docs/' eval/abtest/fixtures/lib.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; the comment still says everything under docs/, stdout 0 and the exit is 1.
10. run: `grep -c 'everything under docs/' eval/abtest/fixtures/lib.sh`
   exit: 1
   stdout: `0`
   mutation: skip edit 6; the stale comment is still there, stdout 1 and the exit is 0.
11. run: `grep -c 'Minimal fixture library' eval/abtest/fixtures/e01-ambiguous-tax/build.sh`
   exit: 1
   stdout: `0`
   mutation: skip edit 9; the E1 description still says fixture, stdout 2 and the exit is 0.
12. run: `bash eval/abtest/verify-checks.sh e01-ambiguous-tax`
   exit: 0
   stdout: `verify-checks: ok`
   mutation: delete the GIT_AUTHOR_DATE and GIT_COMMITTER_DATE export line from abt_fixture_env in the finished lib.sh; two builds then commit different shas and verify-checks exits 1.
   proof: scratch run of that edit: verify-checks printed nondeterministic build and exited 1.
13. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05f\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/fixtures/e01-ambiguous-tax/build.sh eval/abtest/fixtures/lib.sh tests/abtest-checks.test.sh`
   mutation: skip edit 16 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05f\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 16; no unit commit exists and the exit is 3.
15. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05f\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/fixtures/lib.sh eval/abtest/fixtures/e01-ambiguous-tax/build.sh tests/abtest-checks.test.sh | grep -vcE "^[a-z]+\(abt-u05f\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
16. run: `git status --porcelain -- eval/abtest/fixtures/lib.sh eval/abtest/fixtures/e01-ambiguous-tax/build.sh tests/abtest-checks.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 16; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-checks.test.sh (criteria 2 to 11 are the red-then-green checks: the new rows, comment and description do not exist at HEAD)
blast-radius: eval/abtest/fixtures/lib.sh:12, eval/abtest/fixtures/lib.sh:60, eval/abtest/fixtures/e01-ambiguous-tax/build.sh:14
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 1 (the suite passes before the new rows exist), criterion 12 (two builds already agree) and criterion 16 (the scoped clean-tree check) pass at HEAD by design; criteria 2 to 11 fail at HEAD.
extends-landed-code: abt-u05e is on master (3898a60b); every anchor and replaced block is a line of that commit. The edits are small replacements of single lines or short blocks of lib.sh; the guard keeps its structure. abt-u08 (E2) may be in flight: this unit does not touch it, and its build.sh still says Minimal fixture library, which a follow-up must change the same way (listed in the handoff note).
word-delimiters: a word is delimited by anything that is not a letter or digit (a regular expression class [^[:alnum:]] or the start or end of the text), so EVAL_MODE, CLAUDE_API_KEY, ANTI_SLOP_HOME, anti_slop, eval_run, run_eval and my-eval-run are refused, and Describe, inscribed, retrieval, prevalent, medieval, evaluate, personality, pilotage, copilot, claudette, anti-social, a sloppy diff and hidden checkpoint pass. Line breaks count as spaces, so anti and slop, or hidden and check, on two lines are found; anti or hidden followed by any run of non-alphanumerics and then slop or check is found. Out of scope and pinned by rows: words joined to letters or digits (HiddenCheck, hiddencheck, myEvalMode, AntiSlopHome, eval2, 2eval) and a word broken inside (ev and al on two lines). The message names the match without its delimiters.
sha-note: removing .git/hooks/*.sample does not change the baseline sha (hooks are not in the commit); the E1 description change does, so the E1 baseline sha changes again (b1142670 to bf87820d at the time of writing). Nothing in the repository keys a literal baseline sha; verify-checks still proves two builds give one sha.
sample-hooks: git init copies sample hooks into .git/hooks; fsmonitor-watchman.sample and pre-receive.sample contain eval and sendemail-validate.sample contains trap. abt_fixture_baseline deletes every *.sample file there before the commit, and a row proves no forbidden word is left anywhere in .git outside objects (a plain git init is the positive control).
fail-closed: every row compares an explicit status or fragment; a crash or empty output reads as FAILURE. The setup helpers lgmk, lgleak and lgrepo now fail the row when their own setup fails.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u05f): the leak guard refuses a symlinked destination, strips every slash, delimits words by non-alphanumerics, reads notes, and the baseline carries no sample hooks (#607)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u05f (#607)
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
criterion 16: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
