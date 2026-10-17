Unit: abt-u05c

## Objective
The T2 template package.json describes itself as "Zero-dependency notes service." and fixtures/lib.sh abt_leak_guard, called by abt_fixture_baseline, refuses (return 1, file and word named) any built baseline whose package.json, README.md, CONTEXT.md, CLAUDE.md or docs/ files contain antislop, eval, pilot, persona, claude, holdout or hidden check as whole words (the file name CLAUDE.md excepted); tests/abtest-checks.test.sh gains 12 leak guard rows with a positive control, the real T2 tree and the old leaking description. One commit.

## Retrieval
GitHub issues: `gh issue view 599 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/templates/notes-svc/package.json` (anchor: line matching `"description": "Zero-dependency notes service for the antislop`)
- `eval/abtest/fixtures/lib.sh` (anchor: line matching `abt_fixture_baseline DEST: turn DEST`)
- `tests/abtest-checks.test.sh` (anchor: line matching `echo "abtest-checks: $pass passed, $fail failed"`)

## Ordered edits
1. command: `grep -q "Zero-dependency notes service for the antislop" eval/abtest/templates/notes-svc/package.json && test -f eval/abtest/fixtures/lib.sh && ! grep -q abt_leak_guard eval/abtest/fixtures/lib.sh && test -f tests/abtest-checks.test.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/templates/notes-svc/package.json`
   anchor: line matching `"description": "Zero-dependency notes service for the antislop`
   before: `  "description": "Zero-dependency notes service for the antislop comparison evals. Network-free on purpose.",`
   after: `  "description": "Zero-dependency notes service.",`
3. file: `eval/abtest/fixtures/lib.sh`
   anchor: line matching `# abt_fixture_baseline DEST: turn DEST`
   indent: 0
   before:
~~~~
# abt_fixture_baseline DEST: turn DEST into a git repo with one commit named
~~~~
   after:
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
  return 0
}

# abt_fixture_baseline DEST: turn DEST into a git repo with one commit named
~~~~
4. file: `eval/abtest/fixtures/lib.sh`
   anchor: line matching `  abt_fixture_env`
   indent: 0
   before:
~~~~
  abt_fixture_env
~~~~
   after:
~~~~
  abt_leak_guard "$1" || return 1
  abt_fixture_env
~~~~
5. file: `tests/abtest-checks.test.sh`
   anchor: line matching `echo "abtest-checks: $pass passed, $fail failed"`
   indent: 0
   before:
~~~~
echo "abtest-checks: $pass passed, $fail failed"
~~~~
   after:
~~~~
# --- leak guard (abt-u05c): fixtures/lib.sh abt_leak_guard scans the built baseline tree ---
lg() { ( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_leak_guard "$1" ) 2>&1; echo "rc=$?"; }
lgcase() {
  local name="$1" dir="$2" rc="$3" text="$4" out
  out="$(lg "$dir")"
  if [ -z "$text" ]; then
    [ "$out" = "rc=$rc" ] && ok "$name" || bad "$name (got '$out')"
  else
    [[ "$out" == *"$text"* && "$out" == *"rc=$rc" ]] && ok "$name" || bad "$name (got '$out')"
  fi
}
lgmk() { mkdir -p "$T/lg/$1/$(dirname "$2")"; printf '%s\n' "$3" > "$T/lg/$1/$2"; }
lgmk clean package.json '{"name":"x","description":"Zero-dependency notes service."}'
lgmk clean README.md 'We evaluate options. Retrieval, medieval and copilot are fine. See CLAUDE.md for conventions.'
lgmk clean CLAUDE.md 'Run npm test. CLAUDE.md is this file.'
lgmk clean docs/adr/0001-x.md 'An in-memory store.'
lgcase "leak guard: a clean tree passes (positive control)" "$T/lg/clean" 0 ""
for spec in "package.json|{\"description\":\"for the antislop comparison suite\"}|'antislop'" "README.md|the eval harness|'eval'" "CONTEXT.md|a pilot run|'pilot'" \
            "docs/adr/0002-y.md|the persona files|'persona'" "CLAUDE.md|Ask Claude for help|'Claude'" "README.md|a holdout test|'holdout'" \
            "CONTEXT.md|the hidden check passes|'hidden check'" "docs/wiki/a/b.md|AntiSlop notes|'AntiSlop'"; do
  IFS='|' read -r f c w <<< "$spec"
  rm -rf "$T/lg/leak"; cp -r "$T/lg/clean" "$T/lg/leak"; lgmk leak "$f" "$c"
  lgcase "leak guard: $f naming $w is refused" "$T/lg/leak" 1 "$f names the eval or the tool ($w)"
done
lgcase "leak guard: a missing directory is refused" "$T/lg/absent" 1 "is not a directory"
rm -rf "$T/lg/real"; mkdir -p "$T/lg/real"; cp -r "$REPO_ROOT/eval/abtest/templates/notes-svc/." "$T/lg/real/"
lgcase "leak guard: the T2 template passes (every named file and docs/ scanned)" "$T/lg/real" 0 ""
check "the T2 package.json description is neutral" "$(grep -c '"description": "Zero-dependency notes service."' "$T/lg/real/package.json")" "1"
sed -i 's|^  "description": .*$|  "description": "Zero-dependency notes service for the antislop comparison evals. Network-free on purpose.",|' "$T/lg/real/package.json"
lgcase "leak guard: the old T2 description is refused (the real leak)" "$T/lg/real" 1 "package.json names the eval or the tool ('antislop')"
rm -rf "$T/lg/mk"; mkdir -p "$T/lg/mk"; printf '{"description":"an eval harness"}\n' > "$T/lg/mk/package.json"
out="$( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_baseline "$T/lg/mk" 2>&1 )"; rc=$?
check "abt_fixture_baseline refuses a leaking tree" "$rc" "1"
check "the refused baseline made no repository" "$(test -d "$T/lg/mk/.git" && echo made || echo none)" "none"
rm -rf "$T/lg/ok"; mkdir -p "$T/lg/ok"; printf '{"description":"notes"}\n' > "$T/lg/ok/package.json"
sha="$( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_baseline "$T/lg/ok" )"; rc=$?
check "abt_fixture_baseline still commits a clean tree" "$rc|$(printf '%s' "$sha" | tail -n1 | grep -cE '^[0-9a-f]{40}$')" "0|1"
sha="$(ABT_REPO_ROOT="$REPO_ROOT" bash "$REPO_ROOT/eval/abtest/fixtures/e01-ambiguous-tax/build.sh" "$T/lg/e01" | tail -n1)"; rc=$?
check "the E1 build, with its own guard, still builds under the lib guard" "$rc|$(printf '%s' "$sha" | grep -cE '^[0-9a-f]{40}$')" "0|1"

echo "abtest-checks: $pass passed, $fail failed"
~~~~
6. command: `git add eval/abtest/templates/notes-svc/package.json eval/abtest/fixtures/lib.sh tests/abtest-checks.test.sh && git commit -m "fix(abt-u05c): the T2 template no longer names the eval and every fixture build scans for such words (#599)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/templates/notes-svc/src/`, `eval/abtest/templates/notes-svc/test/`, `eval/abtest/templates/notes-svc/README.md`, `eval/abtest/templates/notes-svc/CONTEXT.md`, `eval/abtest/templates/notes-svc/CLAUDE.md` (a scan of the whole template found no hit outside package.json)
- `eval/abtest/fixtures/e01-ambiguous-tax/` and every other fixture directory (each build.sh already sources fixtures/lib.sh; E2 neutralises its own T1 description in abt-u08)
- `eval/abtest/verify-checks.sh`, `eval/abtest/checks/` (the guard lives in the shared build library, which verify-checks reaches through each build.sh)
- `tests/validate.sh` (the checks test is already registered by abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-checks.test.sh`
   exit: 0
   stdout: `All abtest-checks checks passed.`
   mutation: skip edit 4 (the guard call); abt_fixture_baseline accepts a leaking tree, its row FAILs and the fragment is absent.
   proof: mutation matrix, run in a scratch copy of the finished change, each making bash tests/abtest-checks.test.sh exit non-zero: G1 drop package.json from the scanned files; G2 drop README.md; G3 drop CONTEXT.md; G4 drop CLAUDE.md; G5 drop the docs loop; G6 drop the antislop word; G7 drop eval; G8 drop pilot; G9 drop persona; G10 drop claude; G11 drop holdout; G12 drop the hidden check phrase; G13 remove the word boundaries; G14 stop removing the CLAUDE.md file name; G15 delete the guard call in abt_fixture_baseline; G16 turn the missing-directory refusal into a pass; G17 restore the old T2 description.
2. run: `grep -c 'antislop' eval/abtest/templates/notes-svc/package.json`
   exit: 1
   stdout: `0`
   mutation: skip edit 2 (the description); stdout 1 and the exit is 0.
3. run: `bash tests/abtest-checks.test.sh | grep -c '^ok   leak guard'`
   exit: 0
   stdout: `12`
   mutation: skip edit 5 (the new rows); none exist and stdout is 0.
4. run: `grep -c 'abt_leak_guard' eval/abtest/fixtures/lib.sh`
   exit: 0
   stdout: `3`
   mutation: skip edit 3 (the function); the call alone remains and the count is 1.
5. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/fixtures/lib.sh eval/abtest/templates/notes-svc/package.json tests/abtest-checks.test.sh`
   mutation: skip edit 6 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; no unit commit exists and the exit is 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/templates/notes-svc/package.json eval/abtest/fixtures/lib.sh tests/abtest-checks.test.sh | grep -vcE "^[a-z]+\(abt-u05c\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
8. run: `git status --porcelain -- eval/abtest/templates/notes-svc/package.json eval/abtest/fixtures/lib.sh tests/abtest-checks.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 6; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-checks.test.sh (criteria 1 to 4 are the red-then-green checks: the guard, the neutral description and the rows do not exist at HEAD)
blast-radius: eval/abtest/fixtures/lib.sh:14
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 8 (the scoped clean-tree check) passes at HEAD by design; it turns red only when the commit step is skipped.
depends-on: abt-u06 must have landed (the template tests, README, CONTEXT.md, CLAUDE.md and ADR exist); edit 1 checks the old description is still there and STOPs otherwise.
extends-landed-code: package.json line 5 is replaced by one line, so no line number in the template shifts; fixtures/lib.sh gains a function and one line; the test gains rows before its summary line. Nothing is rewritten.
effect-on-fixtures: every fixture build.sh ends in abt_fixture_baseline, so E3, E4 and E5 (T2) are scanned at build and verify time. E1 neutralises its own T1 description (its guard is compatible and kept). E2 builds from the same T1 and abt-u08 now neutralises it too, or its build would fail here.
fail-closed: the guard returns 1 for a missing directory or an unreadable file; the rows assert both the return code and the named file and word.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u05c): the T2 template no longer names the eval and every fixture build scans for such words (#599)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u05c (#599)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
