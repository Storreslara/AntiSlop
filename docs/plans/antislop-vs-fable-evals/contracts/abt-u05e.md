Unit: abt-u05e

## Objective
abt_leak_guard matches the plurals evals, pilots, personas, holdouts and hidden checks, Anti-Slop and anti slop, and abtest; scans package.json, docs/ in any case, every dot-path except .git and any file named README, CONTEXT, CLAUDE or AGENTS in any case and at any depth; refuses a symlink in those places; fails closed when find, grep, sed or mktemp fails; and the test suite reads the exit code of a failing E1 build from the build itself, with the misleading T2 row renamed. One commit.

## Retrieval
GitHub issues: `gh issue view 603 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/fixtures/lib.sh` (anchor: line matching `# abt_leak_guard DEST: fail closed when the built baseline names the eval or the tool in the files an agent`)
- `tests/abtest-checks.test.sh` (anchor: line matching `check "the refused baseline left no repository"`)

## Ordered edits
1. command: `test -f eval/abtest/fixtures/lib.sh && test -f tests/abtest-checks.test.sh && grep -q "_abt_leak_hist" eval/abtest/fixtures/lib.sh && ! grep -q "_abt_leak_scan" eval/abtest/fixtures/lib.sh && ! grep -q "lgleak" tests/abtest-checks.test.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/fixtures/lib.sh`
   anchor: line matching `# abt_leak_guard DEST: fail closed when the built baseline names the eval or the tool in the files an agent`
   indent: 0
   before:
~~~~
# abt_leak_guard DEST: fail closed when the built baseline names the eval or the tool in the files an agent
# reads first: package.json, README.md, CONTEXT.md, CLAUDE.md and everything under docs/. The literal file
# name CLAUDE.md is allowed; the whole words antislop, eval, pilot, persona, claude and holdout, and the
# phrase hidden check, are not (case-insensitive; evaluate or copilot are fine). Source and test files are
# not scanned. Prints the file and the word on stderr and returns 1.
abt_leak_guard() {
  local dest="$1" f content hit
  local -a files=()
  [ -d "$dest" ] || { echo "build: $dest is not a directory; the leak guard cannot scan it" >&2; return 1; }
  for f in package.json README.md CONTEXT.md CLAUDE.md; do
    [ -f "$dest/$f" ] && files+=("$dest/$f")
  done
  if [ -d "$dest/docs" ]; then
    while IFS= read -r f; do files+=("$f"); done < <(find "$dest/docs" -type f | sort)
  fi
  for f in ${files[@]+"${files[@]}"}; do
    content="$(sed 's/CLAUDE\.md//g' "$f")" || { echo "build: cannot read $f for the leak guard" >&2; return 1; }
    hit="$(printf '%s\n' "$content" | grep -oiE '\b(antislop|eval|pilot|persona|claude|holdout)\b|hidden check' | head -n1)"
    if [ -n "$hit" ]; then
      echo "build: $f names the eval or the tool ('$hit')" >&2
      return 1
    fi
  done
  if [ -e "$dest/.git" ]; then _abt_leak_hist "$dest" || return 1; fi
  return 0
}
~~~~
   after:
~~~~
# The words that must not reach a candidate in the files it reads first: matched case-insensitively as whole
# words, plurals included. evaluate, copilot, personality and the like are fine.
ABT_LEAK_WORDS='\b(anti[- ]?slop|abtest|evals?|pilots?|personas?|claude|holdouts?)\b|hidden checks?'

# _abt_leak_scan DEST LISTFILE: list every file and symlink under DEST except .git, then scan package.json,
# everything under docs/ (any case), every path with a dot-directory or dot-file component, and any file named
# README, CONTEXT, CLAUDE or AGENTS (any case, at any depth, with or without an extension md, markdown, mdx,
# txt or rst). Source and test files are not scanned. A symlink in scope is refused (links are never followed).
# Every failing find, sed or grep fails the scan.
_abt_leak_scan() {
  local dest="$1" list="$2" f rel low content hit rc
  find "$dest" -path "$dest/.git" -prune -o \( -type f -o -type l \) -print0 > "$list" \
    || { echo "build: find failed under $dest; the leak guard cannot scan it" >&2; return 1; }
  while IFS= read -r -d '' f; do
    rel="${f#"$dest"/}"; low="${rel,,}"
    case "/$low" in
      /package.json | /docs | /docs/* | */.*) ;;
      *) [[ "${low##*/}" =~ ^(readme|context|claude|agents)(\.(md|markdown|mdx|txt|rst))?$ ]] || continue ;;
    esac
    if [ -L "$f" ]; then
      echo "build: $f is a symbolic link; the leak guard does not follow links" >&2
      return 1
    fi
    content="$(sed 's/CLAUDE\.md//g' "$f")" || { echo "build: cannot read $f for the leak guard" >&2; return 1; }
    hit="$(_abt_leak_hit "$ABT_LEAK_WORDS" "$content")"; rc=$?
    case "$rc" in
      0) echo "build: $f names the eval or the tool ('$hit')" >&2; return 1 ;;
      1) ;;
      *) echo "build: grep failed on $f; the leak guard cannot scan it" >&2; return 1 ;;
    esac
  done < "$list"
  return 0
}

# abt_leak_guard DEST: fail closed when the built baseline names the eval or the tool where a candidate agent
# would read it: the files _abt_leak_scan scans and, when DEST holds a git repository, its history
# (_abt_leak_hist). Prints the file and the word on stderr and returns 1.
abt_leak_guard() {
  local dest="${1%/}" list rc
  [ -d "$dest" ] || { echo "build: $dest is not a directory; the leak guard cannot scan it" >&2; return 1; }
  list="$(mktemp)" || { echo "build: cannot create a temp file for the leak guard" >&2; return 1; }
  _abt_leak_scan "$dest" "$list"; rc=$?
  rm -f "$list"
  [ "$rc" -eq 0 ] || return "$rc"
  if [ -e "$dest/.git" ]; then _abt_leak_hist "$dest" || return 1; fi
  return 0
}
~~~~
3. file: `tests/abtest-checks.test.sh`
   anchor: line matching `the T2 template passes (every named file and docs/ scanned)`
   before: `lgcase "leak guard: the T2 template passes (every named file and docs/ scanned)" "$T/lg/real" 0 ""`
   after: `lgcase "leak guard: the real T2 template tree passes" "$T/lg/real" 0 ""`
4. file: `tests/abtest-checks.test.sh`
   anchor: line matching `build.sh" "$T/lg/e01" | tail -n1)"; rc=$?`
   indent: 0
   before:
~~~~
sha="$(ABT_REPO_ROOT="$REPO_ROOT" bash "$REPO_ROOT/eval/abtest/fixtures/e01-ambiguous-tax/build.sh" "$T/lg/e01" | tail -n1)"; rc=$?
~~~~
   after:
~~~~
ABT_REPO_ROOT="$REPO_ROOT" bash "$REPO_ROOT/eval/abtest/fixtures/e01-ambiguous-tax/build.sh" "$T/lg/e01" > "$T/lg/e01.out" 2> "$T/lg/e01.err"; rc=$?
sha="$(tail -n1 "$T/lg/e01.out")"
~~~~
5. file: `tests/abtest-checks.test.sh`
   anchor: line matching `check "the refused baseline left no repository"`
   indent: 0
   insert-after:
~~~~
# --- leak guard hardening (abt-u05e): plurals, spellings, file names, dot-directories, symlinks, tool failures ---
lgleak() {
  rm -rf "$T/lg/leak"; cp -r "$T/lg/clean" "$T/lg/leak"; lgmk leak "$2" "$3"
  lgcase "leak guard: $1" "$T/lg/leak" 1 "$2 names the eval or the tool ('$4')"
}
lgleak "the plural evals in README.md is refused" README.md 'the evals run nightly' evals
lgleak "the plural personas in CONTEXT.md is refused" CONTEXT.md 'three personas review' personas
lgleak "the plural holdouts in docs is refused" docs/a.md 'two holdouts remain' holdouts
lgleak "the plural pilots in README.md is refused" README.md 'a pilots list' pilots
lgleak "the plural hidden checks in README.md is refused" README.md 'the hidden checks run' 'hidden checks'
lgleak "Anti-Slop with a hyphen is refused" README.md 'About Anti-Slop notes' Anti-Slop
lgleak "anti slop with a space is refused" README.md 'about anti slop notes' 'anti slop'
lgleak "abtest in README.md is refused" README.md 'run the abtest now' abtest
lgleak "a lower-case readme.md is scanned" readme.md 'the eval harness' eval
lgleak "a mixed-case Readme.MD is scanned" Readme.MD 'the eval harness' eval
lgleak "a README with no extension is scanned" README 'the eval harness' eval
lgleak "agents.md is scanned" agents.md 'the eval harness' eval
lgleak "AGENTS.md is scanned" AGENTS.md 'the eval harness' eval
lgleak "a lower-case context.md is scanned" context.md 'the eval harness' eval
lgleak "a lower-case claude.md is scanned" claude.md 'the eval harness' eval
lgleak "a nested README.md is scanned" sub/dir/README.md 'the eval harness' eval
lgleak "README.txt is scanned" README.txt 'the eval harness' eval
lgleak "README.markdown is scanned" README.markdown 'the eval harness' eval
lgleak "CONTEXT.mdx is scanned" CONTEXT.mdx 'the eval harness' eval
lgleak "agents.rst is scanned" agents.rst 'the eval harness' eval
lgleak "a Docs directory in another case is scanned" Docs/a.md 'the eval harness' eval
lgleak "a text file under docs is scanned" docs/notes.txt 'the eval harness' eval
lgleak "a file in .github is scanned" .github/workflows/ci.yml 'run claude here' claude
lgleak "a file in .claude is scanned" .claude/settings.json '{"note":"eval"}' eval
lgleak "a top-level dot file is scanned" .npmrc 'eval=true' eval
lgleak "a file in a nested dot-directory is scanned" src/.cache/x.txt 'the pilot run' pilot
rm -rf "$T/lg/leak"; cp -r "$T/lg/clean" "$T/lg/leak"; lgmk leak docs/a.md 'the eval harness'
lgcase "leak guard: a destination with a trailing slash is scanned in full" "$T/lg/leak/" 1 "docs/a.md names the eval or the tool ('eval')"
rm -rf "$T/lg/ctl"; cp -r "$T/lg/clean" "$T/lg/ctl"
lgmk ctl src/context.js 'function evalAll() { return eval("1"); }'
lgmk ctl src/notes.js '// a persona and a pilot, in source'
lgmk ctl test/readme-notes.test.js 'eval persona holdout'
lgmk ctl notes.md 'eval persona holdout, in a file the guard does not name'
lgmk ctl README.extra 'eval'
lgmk ctl docs/ok.md 'We evaluate options; personality, copilot, pilotage, claudette and anti-social slopes are fine.'
lgcase "leak guard: source, test and unnamed files are not scanned, near words are fine (control)" "$T/lg/ctl" 0 ""
rm -rf "$T/lg/sym"; cp -r "$T/lg/clean" "$T/lg/sym"; lgmk sym src/x.js 'eval'; ln -s ../src/x.js "$T/lg/sym/docs/link.md"
lgcase "leak guard: a symlink under docs is refused" "$T/lg/sym" 1 "docs/link.md is a symbolic link"
rm -rf "$T/lg/sym"; cp -r "$T/lg/clean" "$T/lg/sym"; ln -s missing.md "$T/lg/sym/docs/dangling.md"
lgcase "leak guard: a dangling symlink under docs is refused" "$T/lg/sym" 1 "docs/dangling.md is a symbolic link"
rm -rf "$T/lg/sym"; cp -r "$T/lg/clean" "$T/lg/sym"; lgmk sym src/x.js 'eval'; ln -s src/x.js "$T/lg/sym/README.txt"
lgcase "leak guard: a symlink named README.txt is refused" "$T/lg/sym" 1 "README.txt is a symbolic link"
rm -rf "$T/lg/sym"; cp -r "$T/lg/clean" "$T/lg/sym"; mkdir -p "$T/lg/sym/real"; ln -s real "$T/lg/sym/.claude"
lgcase "leak guard: a symlinked dot-directory is refused" "$T/lg/sym" 1 ".claude is a symbolic link"
rm -rf "$T/lg/sym"; cp -r "$T/lg/clean" "$T/lg/sym"; mkdir -p "$T/lg/sym/real"; printf 'x\n' > "$T/lg/sym/real/a.md"; rm -rf "$T/lg/sym/docs"; ln -s real "$T/lg/sym/docs"
lgcase "leak guard: a symlinked docs directory is refused" "$T/lg/sym" 1 "docs is a symbolic link"
rm -rf "$T/lg/sym"; cp -r "$T/lg/clean" "$T/lg/sym"; lgmk sym src/x.js 'x'; ln -s x.js "$T/lg/sym/src/link.js"
lgcase "leak guard: a symlink outside the scanned files is fine (control)" "$T/lg/sym" 0 ""
out="$(lgfake find 'exit 2' "$T/lg/clean")"
has "leak guard: a failing find fails the guard" "$out" "find failed under"
out="$(lgfake find 'printf "x\0"; exit 2' "$T/lg/clean")"
has "leak guard: a find that fails after printing fails the guard" "$out" "find failed under"
out="$(lgfake grep 'echo eval; exit 2' "$T/lg/clean")"
has "leak guard: a failing grep fails the guard" "$out" "grep failed on"
has "leak guard: a failing grep exits 1" "$out" "rc=1"
out="$(lgfake sed 'exit 4' "$T/lg/clean")"
has "leak guard: a failing sed fails the guard" "$out" "cannot read"
out="$(lgfake mktemp 'exit 1' "$T/lg/clean")"
has "leak guard: a failing mktemp fails the guard" "$out" "cannot create a temp file"
lgrepo gd "initial import"
printf 'eval\n' > "$T/lg/hist/.git/hooks/note"
lgcase "leak guard: files inside .git are not scanned (control)" "$T/lg/hist" 0 ""
# A failing fixture build must be seen as failed (the exit code is read from the build itself, not from a pipe).
rm -rf "$T/lg/badroot"; mkdir -p "$T/lg/badroot/eval/abtest/fixtures" "$T/lg/badroot/eval/fixtures"
cp "$REPO_ROOT/eval/abtest/fixtures/lib.sh" "$T/lg/badroot/eval/abtest/fixtures/lib.sh"
cp -r "$REPO_ROOT/eval/fixtures/toy-lib-template" "$T/lg/badroot/eval/fixtures/toy-lib-template"
mkdir -p "$T/lg/badroot/eval/fixtures/toy-lib-template/docs"; printf 'The eval harness.\n' > "$T/lg/badroot/eval/fixtures/toy-lib-template/docs/notes.md"
ABT_REPO_ROOT="$T/lg/badroot" bash "$E1FX/build.sh" "$T/lg/badbuild" > "$T/lg/badbuild.out" 2> "$T/lg/badbuild.err"; brc=$?
check "a failing E1 build exits non-zero" "$brc" "1"
has "the failing build says why" "$(cat "$T/lg/badbuild.err")" "names the eval or the tool"
~~~~
6. command: `git add eval/abtest/fixtures/lib.sh tests/abtest-checks.test.sh && git commit -m "fix(abt-u05e): the leak guard matches plurals and spellings, scans files by name and dot-directories, refuses symlinks and fails closed on a failing tool (#603)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/arms/`, `tests/abtest-arms.test.sh` (abt-u05d owns the scaffold commit)
- `eval/abtest/verify-checks.sh`, `eval/abtest/checks/` (other units own them)
- `eval/abtest/fixtures/e01-ambiguous-tax/` (its build.sh keeps its own description and word checks)
- `eval/abtest/templates/` (the T2 template already passes the new guard; abt-u06b owns its edits)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-checks.test.sh`
   exit: 0
   stdout: `All abtest-checks checks passed.`
   mutation: skip edit 2 (the new guard); the new rows FAIL, the script exits non-zero and the fragment is absent.
   proof: mutation matrix of 41 single edits, run in a scratch copy of the finished change, each making a suite exit non-zero: L06-L10 drop a plural (evals, personas, holdouts, pilots, hidden checks); L11-L13 drop the hyphen, the space or the optional part of anti-slop; L14-L16 drop abtest, claude or antislop; L27 ignore a failing find; L28 scan .git; L29 do not list symlinks; L30 accept symlinks; L31-L34 drop docs links, docs, dot paths or package.json from the scope; L35 keep the case of the path; L36-L39 drop the file name readme, context, claude or agents; L40-L45 require an extension or drop md, markdown, mdx, txt or rst; L46 match the whole path instead of the base name; L47 ignore a failing sed; L48 do not strip CLAUDE.md; L49 let a hit pass; L50 let a failing grep pass; L66 keep a trailing slash; L67 ignore a failing mktemp; L68 accept a missing directory; L69 drop the leading word boundary; L74 change the symlink message; T1 read the exit code of the failing E1 build through a pipe
2. run: `bash tests/abtest-checks.test.sh | grep -c '^ok   leak guard:'`
   exit: 0
   stdout: `85`
   mutation: skip edit 2; the new refusal rows FAIL and the count drops below 85.
3. run: `d=$(mktemp -d); printf 'the evals run\n' > "$d/README.md"; ( . eval/abtest/fixtures/lib.sh; abt_leak_guard "$d" ) 2>&1 | grep -o "README.md names the eval or the tool ('evals')"; rc=$?; rm -rf "${d:?}"; exit $rc`
   exit: 0
   stdout: `README.md names the eval or the tool ('evals')`
   mutation: skip edit 2; the old guard has no plural, prints nothing and grep exits 1.
4. run: `d=$(mktemp -d); printf 'About Anti-Slop notes\n' > "$d/README.md"; ( . eval/abtest/fixtures/lib.sh; abt_leak_guard "$d" ) 2>&1 | grep -o "README.md names the eval or the tool ('Anti-Slop')"; rc=$?; rm -rf "${d:?}"; exit $rc`
   exit: 0
   stdout: `README.md names the eval or the tool ('Anti-Slop')`
   mutation: skip edit 2; the old guard has no Anti-Slop spelling and grep exits 1.
5. run: `d=$(mktemp -d); printf 'the eval harness\n' > "$d/agents.md"; ( . eval/abtest/fixtures/lib.sh; abt_leak_guard "$d" ) 2>&1 | grep -o "agents.md names the eval or the tool ('eval')"; rc=$?; rm -rf "${d:?}"; exit $rc`
   exit: 0
   stdout: `agents.md names the eval or the tool ('eval')`
   mutation: skip edit 2; the old guard scans only the four exact names and grep exits 1.
6. run: `d=$(mktemp -d); mkdir -p "$d/.github/workflows"; printf 'run claude here\n' > "$d/.github/workflows/ci.yml"; ( . eval/abtest/fixtures/lib.sh; abt_leak_guard "$d" ) 2>&1 | grep -o "ci.yml names the eval or the tool ('claude')"; rc=$?; rm -rf "${d:?}"; exit $rc`
   exit: 0
   stdout: `ci.yml names the eval or the tool ('claude')`
   mutation: skip edit 2; the old guard never opens a dot-directory and grep exits 1.
7. run: `d=$(mktemp -d); mkdir "$d/docs"; ln -s ../x "$d/docs/l.md"; ( . eval/abtest/fixtures/lib.sh; abt_leak_guard "$d" ) 2>&1 | grep -o "docs/l.md is a symbolic link"; rc=$?; rm -rf "${d:?}"; exit $rc`
   exit: 0
   stdout: `docs/l.md is a symbolic link`
   mutation: skip edit 2; the old guard lists only regular files, prints nothing and grep exits 1.
8. run: `d=$(mktemp -d); f=$(mktemp -d); printf '#!/bin/sh\nexit 2\n' > "$f/find"; chmod +x "$f/find"; mkdir "$d/docs"; ( PATH="$f:$PATH"; . eval/abtest/fixtures/lib.sh; abt_leak_guard "$d" ) 2>&1 | grep -o 'find failed under'; rc=$?; rm -rf "${d:?}" "${f:?}"; exit $rc`
   exit: 0
   stdout: `find failed under`
   mutation: skip edit 2; the old guard cannot see a find error, prints nothing and grep exits 1.
9. run: `grep -c 'every named file and docs/ scanned' tests/abtest-checks.test.sh`
   exit: 1
   stdout: `0`
   mutation: skip edit 3; the misleading name is still there, stdout 1 and the exit is 0.
10. run: `grep -cF '"$T/lg/e01" | tail -n1)"; rc=$?' tests/abtest-checks.test.sh`
   exit: 1
   stdout: `0`
   mutation: skip edit 4; the pipe that reads the exit code of tail is still there, stdout 1 and the exit is 0.
11. run: `bash tests/abtest-checks.test.sh | grep -c '^ok   a failing E1 build exits non-zero'`
   exit: 0
   stdout: `1`
   mutation: skip edit 5 (the last block of rows); the count is 0 and the exit is 1.
   proof: mutation T1 of the matrix in criterion 1, run in a scratch copy: with the capture of the failing E1 build replaced by a pipe into tail followed by brc=$?, the row prints FAIL (it reads tail exit 0).
12. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05e\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/fixtures/lib.sh tests/abtest-checks.test.sh`
   mutation: skip edit 6 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
13. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05e\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; no unit commit exists and the exit is 3.
14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05e\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/fixtures/lib.sh tests/abtest-checks.test.sh | grep -vcE "^[a-z]+\(abt-u05e\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
15. run: `git status --porcelain -- eval/abtest/fixtures/lib.sh tests/abtest-checks.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 6; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-checks.test.sh (criteria 2 to 8 and 11 are the red-then-green checks: the new refusals and rows do not exist at HEAD)
blast-radius: eval/abtest/fixtures/lib.sh:50, eval/abtest/fixtures/e01-ambiguous-tax/build.sh:27, tests/abtest-checks.test.sh:307
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 1 (the suite passes at HEAD) and criterion 15 (the scoped clean-tree check) pass at HEAD by design; criteria 2 to 11 fail at HEAD.
extends-landed-code: abt-u05d (#602) must have landed (edit 1 checks for _abt_leak_hist and STOPs otherwise); every anchor and the replaced guard block are taken from the tree after it. The guard comment and function are replaced as one block; the rows are inserted after the last row abt-u05d adds, because they reuse its helpers lgfake and lgrepo.
order: abt-u06b also edits tests/abtest-checks.test.sh (a block before its final summary line); either order gives a clean tree, the edge only keeps the shared file serial.
scope-of-scan: package.json, docs/ in any case, every path with a dot component except .git, and files named README, CONTEXT, CLAUDE or AGENTS in any case and at any depth (extensions md, markdown, mdx, txt, rst, or none); symlinks in those places are refused, never followed. Source and test files are not scanned, and the words fixture, trap and plant are checked only in the git history (E1 and E2 describe the project as a fixture library in package.json).
fail-closed: every row compares an explicit status or fragment; a crash or empty output reads as FAILURE. A failing find, grep, sed or mktemp fails the guard.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u05e): the leak guard matches plurals and spellings, scans files by name and dot-directories, refuses symlinks and fails closed on a failing tool (#603)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u05e (#603)
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
