Unit: abt-u05h

## Objective
eval/abtest/checks/lib.sh fails closed: an empty, unset, missing, non-directory, newline-named, root, home, TMPDIR-parent or non-repository worktree exits 3 with a message and copies nothing; the same pattern is guarded in fixtures/lib.sh, the five build.sh scripts, verify-checks.sh, run-matrix.sh, arms/common.sh and eight test files. tests/abtest-checks.test.sh goes from 231 to 332 rows, all guard rows under a cp stub. One commit.

## Retrieval
GitHub issues: `gh issue view 619 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/checks/lib.sh` (anchor: line matching `ABT_WT="$(cd "$1" && pwd)"`)
- `eval/abtest/fixtures/lib.sh` (anchor: line matching `# commit the same baseline sha.`)
- `eval/abtest/verify-checks.sh` (anchor: line matching `T="$(mktemp -d)"`)
- `eval/abtest/run-matrix.sh` (anchor: line matching `WORK="$(abs_path "$WORK")"`)
- `eval/abtest/arms/common.sh` (anchor: line matching `rm -rf "$dir"`)
- `eval/abtest/fixtures/e01-ambiguous-tax/build.sh` (anchor: line matching `dest="${1:?usage: build.sh DEST}"`)
- `eval/abtest/fixtures/e02-preview-mutation/build.sh` (anchor: line matching `dest="${1:?usage: build.sh DEST}"`)
- `eval/abtest/fixtures/e03-rename-query/build.sh` (anchor: line matching `dest="${1:?usage: build.sh DEST}"`)
- `eval/abtest/fixtures/e04-search-injection/build.sh` (anchor: line matching `dest="${1:?usage: build.sh DEST}"`)
- `eval/abtest/fixtures/e05-tags-feature/build.sh` (anchor: line matching `dest="${1:?usage: build.sh DEST}"`)
- `tests/abtest-blind.test.sh` (anchor: line matching `T="$(mktemp -d)"`)
- `tests/abtest-arms.test.sh` (anchor: line matching `T="$(mktemp -d)"`)
- `tests/abtest-probe.test.sh` (anchor: line matching `T="$(mktemp -d)"`)
- `tests/abtest-runner.test.sh` (anchor: line matching `T="$(mktemp -d)"`)
- `tests/abtest-row.test.sh` (anchor: line matching `T="$(mktemp -d)"`)
- `tests/abtest-score.test.sh` (anchor: line matching `T="$(mktemp -d)"`)
- `tests/abtest-checks.test.sh` (anchor: line matching `T="$(mktemp -d)"`; second anchor: line matching `a fast check next to it still passes`)
- `tests/abtest-stream.test.sh` (anchor: line matching `ZW="$(mktemp -d)"`)

## Ordered edits
1. command: `test -f eval/abtest/checks/lib.sh && ! grep -q _abt_guard_wt eval/abtest/checks/lib.sh && ! grep -q abt_dest_guard eval/abtest/fixtures/lib.sh && ! grep -q "abt-u05h" tests/abtest-checks.test.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory' ':!tests/validate.sh')"`
   expect: 0
2. file: `eval/abtest/checks/lib.sh`
   anchor: line matching `the arm's own work (0 when unset); the E5 commit-count check subtracts it from its commit count.`
   indent: 0
   insert-after:
~~~~

# Fail closed (abt-u05h): a worktree that is empty, missing, not a directory, not the root of its own git repository,
# a filesystem root, a home directory or a parent of one is refused with exit 3 before anything is copied or written
# (an empty ABT_WT once made "$ABT_WT/." read /. and copied a whole disk). The copy target is a fresh mktemp directory.
_abt_refuse() { echo "abt-checks: refusing to run: $1" >&2; exit 3; }

# _abt_guard_wt CANDIDATE: on success ABT_WT holds CANDIDATE's physical absolute path; otherwise exit 3.
_abt_guard_wt() {
  local w="${1-}" r p rp top
  [ -n "$w" ] || _abt_refuse "the worktree argument is empty or unset"
  case "$w" in *$'\n'*) _abt_refuse "the worktree path contains a newline" ;; esac
  [ -d "$w" ] || _abt_refuse "the worktree is not an existing directory"
  r="$(cd -P -- "$w" 2> /dev/null && pwd -P)" || _abt_refuse "the worktree path cannot be resolved"
  case "$r" in /?*) ;; *) _abt_refuse "the worktree is the filesystem root" ;; esac
  case "$r" in *$'\n'*) _abt_refuse "the resolved worktree path contains a newline" ;; esac
  [ -d "$r" ] || _abt_refuse "the resolved worktree path is not a directory"
  for p in "${HOME-}" "${TMPDIR:-/tmp}"; do
    [ -n "$p" ] || continue
    rp="$(cd -P -- "$p" 2> /dev/null && pwd -P)" || continue
    case "$rp/" in "$r"/*) _abt_refuse "the worktree is, or contains, $p" ;; esac
  done
  [ -e "$r/.git" ] || _abt_refuse "the worktree has no .git"
  top="$(git -C "$r" rev-parse --show-toplevel 2> /dev/null)" || _abt_refuse "the worktree is not a git worktree"
  [ "$top" = "$r" ] || _abt_refuse "the worktree is not the root of its git repository"
  ABT_WT="$r"
}

# _abt_drop_refuse DIR MESSAGE: remove the (empty) directory this run just made, then refuse.
_abt_drop_refuse() { rmdir -- "${1-}" 2> /dev/null; _abt_refuse "$2"; }

# _abt_guard_copy DIR: DIR must be a fresh, empty, absolute directory that is neither inside the worktree nor above it.
_abt_guard_copy() {
  local c="${1-}" rc
  case "$c" in /?*) ;; *) _abt_drop_refuse "$c" "the copy directory is not an absolute path below /" ;; esac
  case "$c" in *$'\n'*) _abt_drop_refuse "$c" "the copy directory path contains a newline" ;; esac
  [ -d "$c" ] || _abt_refuse "the copy directory was not created"
  rc="$(cd -P -- "$c" 2> /dev/null && pwd -P)" || _abt_refuse "the copy directory cannot be resolved"
  case "$rc/" in "$ABT_WT"/*) _abt_drop_refuse "$c" "the copy directory is inside the worktree" ;; esac
  case "$ABT_WT/" in "$rc"/*) _abt_drop_refuse "$c" "the copy directory is above the worktree" ;; esac
  [ -z "$(ls -A -- "$rc")" ] || _abt_refuse "the copy directory is not empty"
}
~~~~
3. file: `eval/abtest/checks/lib.sh`
   anchor: line matching `ABT_WT="$(cd "$1" && pwd)"`
   before: `ABT_WT="$(cd "$1" && pwd)"`
   after: `_abt_guard_wt "${1-}"`
4. file: `eval/abtest/checks/lib.sh`
   anchor: line matching `copy="$(mktemp -d)"`
   indent: 0
   before:
~~~~
  copy="$(mktemp -d)"
  cp -a "$ABT_WT/." "$copy/"
~~~~
   after:
~~~~
  _abt_guard_wt "${ABT_WT-}"
  copy="$(mktemp -d "${TMPDIR:-/tmp}/abt-check.XXXXXX")" || _abt_refuse "cannot create the copy directory"
  _abt_guard_copy "$copy"
  cp -a -- "${ABT_WT:?}/." "${copy:?}/" || { rm -rf -- "${copy:?}"; _abt_refuse "copying the worktree failed"; }
~~~~
5. file: `eval/abtest/checks/lib.sh`
   anchor: line matching `rm -rf "$copy"`
   before: `rm -rf "$copy"`
   after: `rm -rf -- "${copy:?}"`
6. file: `eval/abtest/checks/lib.sh`
   anchor: line matching `abt_validate scope "$req"`
   indent: 0
   insert-after:
~~~~
  _abt_guard_wt "${ABT_WT-}"
~~~~
7. file: `eval/abtest/fixtures/lib.sh`
   anchor: line matching `# commit the same baseline sha.`
   indent: 0
   insert-after:
~~~~

# abt_dest_guard DEST (abt-u05h): refuse a build destination that is empty, contains a newline, is /, or is the home
# directory, the TMPDIR or a parent of either. A fixture is built into a directory of its own below them.
abt_dest_guard() {
  local d="${1-}" r p rp
  [ -n "$d" ] || { echo "build: the destination is empty" >&2; return 1; }
  case "$d" in *$'\n'*) echo "build: the destination contains a newline" >&2; return 1 ;; esac
  r="$(realpath -m -- "$d")" || { echo "build: cannot resolve the destination $d" >&2; return 1; }
  case "$r" in /?*) ;; *) echo "build: the destination $d is the filesystem root" >&2; return 1 ;; esac
  for p in "${HOME-}" "${TMPDIR:-/tmp}"; do
    [ -n "$p" ] || continue
    rp="$(realpath -m -- "$p")" || continue
    case "$rp/" in "$r"/*) echo "build: the destination $d is, or contains, $p" >&2; return 1 ;; esac
  done
  return 0
}
~~~~
8. file: `eval/abtest/fixtures/lib.sh`
   anchor: line matching `while [ "${d%/}" != "$d" ] && [ "$d" != / ]; do d="${d%/}"; done`
   indent: 0
   insert-after:
~~~~
  abt_dest_guard "$d" || return 1
~~~~
9. file: `eval/abtest/fixtures/e01-ambiguous-tax/build.sh`
   anchor: line matching `dest="${1:?usage: build.sh DEST}"`
   indent: 0
   insert-after:
~~~~
abt_dest_guard "$dest" || exit 2
~~~~
10. file: `eval/abtest/fixtures/e02-preview-mutation/build.sh`
   anchor: line matching `dest="${1:?usage: build.sh DEST}"`
   indent: 0
   insert-after:
~~~~
abt_dest_guard "$dest" || exit 2
~~~~
11. file: `eval/abtest/fixtures/e03-rename-query/build.sh`
   anchor: line matching `dest="${1:?usage: build.sh DEST}"`
   indent: 0
   insert-after:
~~~~
abt_dest_guard "$dest" || exit 2
~~~~
12. file: `eval/abtest/fixtures/e04-search-injection/build.sh`
   anchor: line matching `dest="${1:?usage: build.sh DEST}"`
   indent: 0
   insert-after:
~~~~
abt_dest_guard "$dest" || exit 2
~~~~
13. file: `eval/abtest/fixtures/e05-tags-feature/build.sh`
   anchor: line matching `dest="${1:?usage: build.sh DEST}"`
   indent: 0
   insert-after:
~~~~
abt_dest_guard "$dest" || exit 2
~~~~
14. file: `eval/abtest/verify-checks.sh`
   anchor: line matching `T="$(mktemp -d)"`
   before: `T="$(mktemp -d)"`
   after: `T="$(mktemp -d)" && [ -n "$T" ] && [ -d "$T" ] || { echo "verify-checks: cannot create a temp directory" >&2; exit 2; }`
15. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `WORK="$(abs_path "$WORK")"`
   indent: 0
   insert-after:
~~~~
# Refuse a runs or work root that is /, the home directory or a parent of it: a run starts by removing its own
# directories under these roots (abt-u05h).
for _p in "$RUNS" "$WORK"; do
  _r="$(realpath -m -- "$_p")"
  _h="$(realpath -m -- "${HOME:-/}")"
  case "$_r" in /?*) ;; *) echo "run-matrix: ABT_RUNS and ABT_WORK must not be / ($_p)" >&2; exit 2 ;; esac
  case "$_h/" in "$_r"/*) echo "run-matrix: ABT_RUNS and ABT_WORK must not be the home directory or a parent of it ($_p)" >&2; exit 2 ;; esac
done
unset _p _r _h
~~~~
16. file: `eval/abtest/arms/common.sh`
   anchor: line matching `rm -rf "$dir"`
   before: `rm -rf "$dir"`
   after: `rm -rf "${dir:?}"`
17. file: `tests/abtest-blind.test.sh`
   anchor: line matching `T="$(mktemp -d)"`
   before: `T="$(mktemp -d)"`
   after: `T="$(mktemp -d)" && [ -d "${T:-}" ] || { echo "mktemp -d failed" >&2; exit 2; }`
18. file: `tests/abtest-arms.test.sh`
   anchor: line matching `T="$(mktemp -d)"`
   before: `T="$(mktemp -d)"`
   after: `T="$(mktemp -d)" && [ -d "${T:-}" ] || { echo "mktemp -d failed" >&2; exit 2; }`
19. file: `tests/abtest-probe.test.sh`
   anchor: line matching `T="$(mktemp -d)"`
   before: `T="$(mktemp -d)"`
   after: `T="$(mktemp -d)" && [ -d "${T:-}" ] || { echo "mktemp -d failed" >&2; exit 2; }`
20. file: `tests/abtest-runner.test.sh`
   anchor: line matching `T="$(mktemp -d)"`
   before: `T="$(mktemp -d)"`
   after: `T="$(mktemp -d)" && [ -d "${T:-}" ] || { echo "mktemp -d failed" >&2; exit 2; }`
21. file: `tests/abtest-row.test.sh`
   anchor: line matching `T="$(mktemp -d)"`
   before: `T="$(mktemp -d)"`
   after: `T="$(mktemp -d)" && [ -d "${T:-}" ] || { echo "mktemp -d failed" >&2; exit 2; }`
22. file: `tests/abtest-score.test.sh`
   anchor: line matching `T="$(mktemp -d)"`
   before: `T="$(mktemp -d)"`
   after: `T="$(mktemp -d)" && [ -d "${T:-}" ] || { echo "mktemp -d failed" >&2; exit 2; }`
23. file: `tests/abtest-stream.test.sh`
   anchor: line matching `ZW="$(mktemp -d)"`
   before: `ZW="$(mktemp -d)"`
   after: `ZW="$(mktemp -d)" && [ -d "${ZW:-}" ] || { echo "mktemp -d failed" >&2; exit 2; }`
24. file: `tests/abtest-checks.test.sh`
   anchor: line matching `T="$(mktemp -d)"`
   before: `T="$(mktemp -d)"`
   after: `T="$(mktemp -d)" && [ -d "${T:-}" ] || { echo "mktemp -d failed" >&2; exit 2; }`
25. file: `tests/abtest-checks.test.sh`
   anchor: line matching `a fast check next to it still passes`
   indent: 0
   insert-after:
~~~~

# --- fail-closed worktree guard (abt-u05h): a bad worktree argument exits 3 and copies nothing ---
# Safe by construction: every guard run puts a cp stub first on PATH that copies only inside this test's temp dir
# and logs DANGER for any other path, so a lib.sh without the guard still cannot copy the filesystem.
REAL_CP="$(command -v cp)"
GROOT="$(realpath "$T")"
mkdir -p "$T/gstub" "$T/gtmp" "$T/gcwd" "$T/ghome"
cat > "$T/gstub/cp" << 'EOS'
#!/usr/bin/env bash
printf 'cp %s\n' "$*" >> "$GUARD_CP_LOG"
for a in "$@"; do
  case "$a" in -*) continue ;; esac
  r="$(realpath -m -- "$a" 2> /dev/null)"
  case "$r/" in "$GUARD_CP_ROOT"/*) ;; *) echo "DANGER $a" >> "$GUARD_CP_LOG"; echo "cp stub: refusing $a" >&2; exit 97 ;; esac
done
exec "$GUARD_REAL_CP" "$@"
EOS
chmod +x "$T/gstub/cp"
cat > "$T/guard-check.sh" << 'EOS'
. "$ABT_CHECKS_LIB"
abt_init "$1" "$2" "$3" "$4"
abt_check g defect true 'true'
abt_emit
EOS
cat > "$T/guard-noinit.sh" << 'EOS'
. "$ABT_CHECKS_LIB"
unset ABT_WT
ABT_BASE=x
abt_check g defect true 'true'
abt_emit
EOS
: > "$T/gcp.all"
guard_run() {
  : > "$T/gcp.log"
  gout="$(cd "$T/gcwd" && (ulimit -f 20480; PATH="$T/gstub:$PATH" TMPDIR="$T/gtmp" HOME="$T/ghome" GUARD_CP_LOG="$T/gcp.log" GUARD_CP_ROOT="$GROOT" GUARD_REAL_CP="$REAL_CP" ABT_CHECKS_LIB="$REPO_ROOT/eval/abtest/checks/lib.sh" timeout -k 2s 30s bash "$1" "$2" "$BASE" "$BASE" "$T/allowed" 2> "$T/gerr.txt"))"; grc=$?
  gerr="$(cat "$T/gerr.txt")"
  cat "$T/gcp.log" >> "$T/gcp.all"
}
guard_refused() {
  guard_run "$2" "$3"
  check "guard: $1 exits 3" "$grc" "3"
  has "guard: $1 says why" "$gerr" "$4"
  check "guard: $1 prints no JSON" "$gout" ""
  check "guard: $1 leaves TMPDIR empty" "$(ls -A "$T/gtmp" | wc -l | tr -d ' ')" "0"
  check "guard: $1 calls cp zero times" "$(wc -l < "$T/gcp.log" | tr -d ' ')" "0"
}
mkdir -p "$T/space dir" "$T/gitless/.git" "$T/nl"$'\n'
git -C "$T/nl"$'\n' init -q
printf 'x\n' > "$T/afile"
ln -s / "$T/rootlink"
guard_refused "a nonexistent worktree" "$T/guard-check.sh" "$T/nope" "not an existing directory"
guard_refused "an empty string argument" "$T/guard-check.sh" "" "empty or unset"
guard_refused "the root directory" "$T/guard-check.sh" "/" "filesystem root"
guard_refused "a symbolic link to the root directory" "$T/guard-check.sh" "$T/rootlink" "filesystem root"
guard_refused "a file instead of a directory" "$T/guard-check.sh" "$T/afile" "not an existing directory"
guard_refused "an unset ABT_WT" "$T/guard-noinit.sh" "$R" "empty or unset"
guard_refused "a nonexistent directory with a space in its name" "$T/guard-check.sh" "$T/no such dir" "not an existing directory"
guard_refused "an existing directory with a space that is no worktree" "$T/guard-check.sh" "$T/space dir" "has no .git"
guard_refused "a directory whose name ends in a newline" "$T/guard-check.sh" "$T/nl"$'\n' "contains a newline"
guard_refused "the home directory" "$T/guard-check.sh" "$T/ghome" "is, or contains"
guard_refused "a parent of the home directory" "$T/guard-check.sh" "$T" "is, or contains"
guard_refused "the TMPDIR itself" "$T/guard-check.sh" "$T/gtmp" "is, or contains"
guard_refused "a .git that is not a repository" "$T/guard-check.sh" "$T/gitless" "not a git worktree"
cp -r "$R" "$T/good repo"
guard_run "$T/guard-check.sh" "$T/good repo"
check "guard: a real worktree with a space in its name still runs" "$grc" "0"
check "guard: that run reports the check as passed" "$(printf '%s' "$gout" | python3 -I -c 'import json,sys;print(json.load(sys.stdin)[0]["pass"])')" "True"
check "guard: that run copied the tree exactly once" "$(wc -l < "$T/gcp.log" | tr -d ' ')" "1"
check "guard: that run removed its copy and its output file" "$(ls -A "$T/gtmp" | wc -l | tr -d ' ')" "0"
check "guard: no run offered cp a path outside the test temp dir" "$(grep -c '^DANGER' "$T/gcp.all")" "0"
check "guard: the agent tree is untouched by the guard runs" "$(cat "$R/package.json")" "x"

# verify-checks.sh: a failing mktemp stops it before any fixture is built (the build stub only records its argument).
mkdir -p "$T/vg/fx/syn-x" "$T/vg/ck/syn-x" "$T/vg/bin"
cat > "$T/vg/fx/syn-x/build.sh" << EOS
#!/usr/bin/env bash
printf '%s\n' "\$1" >> "$T/vg/built.log"
~~~~
26. file: `tests/abtest-checks.test.sh`
   anchor: line matching `printf '%s\n' "\$1" >> "$T/vg/built.log"`
   indent: 0
   insert-after:
~~~~
exit 1
EOS
: > "$T/vg/fx/syn-x/reference.patch"
: > "$T/vg/fx/syn-x/allowed-paths.txt"
printf '#!/usr/bin/env bash\n' > "$T/vg/ck/syn-x/check.sh"
printf '#!/bin/sh\nexit 1\n' > "$T/vg/bin/mktemp"
chmod +x "$T/vg/bin/mktemp"
vout="$(PATH="$T/vg/bin:$PATH" ABT_FIXTURES_DIR="$T/vg/fx" ABT_CHECKS_ROOT="$T/vg/ck" timeout 30s bash "$VERIFY" syn-x 2>&1)"; vrc=$?
check "verify-checks: a failing mktemp exits 2" "$vrc" "2"
has "verify-checks: a failing mktemp says so" "$vout" "cannot create a temp directory"
check "verify-checks: a failing mktemp builds nothing" "$(test -e "$T/vg/built.log" && echo built || echo none)" "none"

# run-matrix.sh: ABT_WORK and ABT_RUNS may not be /, the home directory or a parent of it (dry runs only; nothing is removed).
mkdir -p "$T/rmhome/.claude"
printf '{}\n' > "$T/rmhome/.claude/.credentials.json"
rm_dry() { HOME="$T/rmhome" ABTEST_CLAUDE="$REPO_ROOT/tests/fixtures/abtest/fake-claude.sh" ABT_RESULTS="$T/rm-res.jsonl" ABT_RUNS="${ABT_RUNS:-$T/rm-runs}" ABT_WORK="$1" timeout 60s bash "$REPO_ROOT/eval/abtest/run-matrix.sh" --pilot --evals e01-ambiguous-tax --dry-run 2>&1; }
for rmcase in "/" "$T/rmhome" "$T"; do
  rmout="$(rm_dry "$rmcase")"; rmrc=$?
  check "run-matrix: ABT_WORK=$rmcase exits 2" "$rmrc" "2"
  has "run-matrix: ABT_WORK=$rmcase says why" "$rmout" "ABT_RUNS and ABT_WORK must not be"
done
rmout="$(ABT_RUNS=/ rm_dry "$T/rmhome/work")"; rmrc=$?
check "run-matrix: ABT_RUNS=/ exits 2" "$rmrc" "2"
has "run-matrix: ABT_RUNS=/ says why" "$rmout" "ABT_RUNS and ABT_WORK must not be"
rmout="$(rm_dry "$T/rmhome/work")"; rmrc=$?
check "run-matrix: a work root below the home directory still plans" "$rmrc" "0"
has "run-matrix: that dry run lists the plan" "$rmout" "plan: e01-ambiguous-tax/A/uniform/1 run"

# fixtures/lib.sh abt_dest_guard and the five build.sh scripts: a build destination may not be empty, /, the home directory or a parent of it.
mkdir -p "$T/fakehome" "$T/ftmp"
dg() { ( export HOME="$T/fakehome" TMPDIR="$T/ftmp"; . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_dest_guard "$1" ) > /dev/null 2>&1; echo $?; }
check "dest guard: an empty destination is refused" "$(dg "")" "1"
check "dest guard: / is refused" "$(dg "/")" "1"
check "dest guard: the home directory is refused" "$(dg "$T/fakehome")" "1"
check "dest guard: a parent of the home directory is refused" "$(dg "$T")" "1"
check "dest guard: the TMPDIR is refused" "$(dg "$T/ftmp")" "1"
check "dest guard: a fresh directory below the TMPDIR is accepted" "$(dg "$T/ftmp/new dest")" "0"
for fxid in e01-ambiguous-tax e02-preview-mutation e03-rename-query e04-search-injection e05-tags-feature; do
  HOME="$T/fakehome" TMPDIR="$T/ftmp" timeout 60s bash "$REPO_ROOT/eval/abtest/fixtures/$fxid/build.sh" "$T/fakehome" > /dev/null 2>&1; fxrc=$?
  check "build.sh $fxid refuses the home directory as its destination" "$fxrc" "2"
  check "build.sh $fxid wrote nothing into the refused destination" "$(ls -A "$T/fakehome" | wc -l | tr -d ' ')" "0"
done

# arms/common.sh: the config directory is never removed through an empty variable.
check "common.sh removes the config dir only through a guarded expansion" "$(grep -cF 'rm -rf "${dir:?}"' "$REPO_ROOT/eval/abtest/arms/common.sh")|$(grep -cF 'rm -rf "$dir"' "$REPO_ROOT/eval/abtest/arms/common.sh")" "2|0"
~~~~
27. command: `git add eval/abtest/checks/lib.sh eval/abtest/fixtures/lib.sh eval/abtest/verify-checks.sh eval/abtest/run-matrix.sh eval/abtest/arms/common.sh eval/abtest/fixtures/e01-ambiguous-tax/build.sh eval/abtest/fixtures/e02-preview-mutation/build.sh eval/abtest/fixtures/e03-rename-query/build.sh eval/abtest/fixtures/e04-search-injection/build.sh eval/abtest/fixtures/e05-tags-feature/build.sh tests/abtest-blind.test.sh tests/abtest-arms.test.sh tests/abtest-probe.test.sh tests/abtest-runner.test.sh tests/abtest-row.test.sh tests/abtest-score.test.sh tests/abtest-checks.test.sh tests/abtest-stream.test.sh && git commit -m "fix(abt-u05h): checks/lib.sh fails closed on a bad worktree and the same guard everywhere a variable could be empty (#619)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `CHANGELOG.md` (a scribe owns the close-out entries; this unit adds none)
- `docs/harness-glossary.md`
- `eval/abtest/report.py` (and the four tests/abtest-report*.test.sh files: owned by the unlanded unit abt-u21a (#588), whose work is in progress)
- `tests/validate.sh` (abt-u21a edits it; this unit registers nothing)
- `eval/abtest/checks/scope.sh` and `eval/abtest/checks/e0*/check.sh` (they call lib.sh and need no change)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `set -o pipefail; bash tests/abtest-checks.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-checks checks passed.`
   mutation: skip edit 4; the unset-ABT_WT row reaches the old copy line, the stub logs DANGER and refuses it, and the suite exits non-zero.
2. run: `bash tests/abtest-checks.test.sh | grep -c '^ok   guard: '`
   exit: 0
   stdout: `71`
   mutation: skip edit 3; the empty, nonexistent, file, newline, home and root rows no longer exit 3 and the count falls below 71.
3. run: `bash tests/abtest-checks.test.sh | grep -c '^ok   verify-checks: a failing mktemp'`
   exit: 0
   stdout: `3`
   mutation: skip edit 14; the build stub is called with a root-level path and the count is 0.
4. run: `bash tests/abtest-checks.test.sh | grep -c '^ok   run-matrix: '`
   exit: 0
   stdout: `10`
   mutation: skip edit 15; the refusal cases print a plan and exit 0, and the count is 2.
5. run: `bash tests/abtest-checks.test.sh | grep -c '^ok   dest guard: '`
   exit: 0
   stdout: `6`
   mutation: skip edit 7; abt_dest_guard is undefined, every call exits 127, and the count is 0.
6. run: `bash tests/abtest-checks.test.sh | grep -cE '^ok   build\.sh e0[1-5]-[a-z0-9-]+ (refuses|wrote nothing)'`
   exit: 0
   stdout: `10`
   mutation: skip edit 13; the E5 build writes into the home directory and both E5 rows FAIL, so the count is 8.
7. run: `grep -c 'mktemp -d failed' tests/abtest-*.test.sh | grep -c ':1$'`
   exit: 0
   stdout: `8`
   mutation: skip edit 23; tests/abtest-stream.test.sh has no guard and the count is 7.
8. run: `echo "$(grep -cF '_abt_guard_wt' eval/abtest/checks/lib.sh) $(grep -cF 'cp -a -- "${ABT_WT:?}/." "${copy:?}/"' eval/abtest/checks/lib.sh) $(grep -cF 'cp -a "$ABT_WT' eval/abtest/checks/lib.sh) $(grep -cF 'rm -rf -- "${copy:?}"' eval/abtest/checks/lib.sh)"`
   exit: 0
   stdout: `5 1 0 2`
   mutation: skip edit 6; the first number is 4. Skip edit 5; the last number is 1.
9. run: `grep -c 'rm -rf "${dir:?}"' eval/abtest/arms/common.sh`
   exit: 0
   stdout: `2`
   mutation: skip edit 16; stdout 1.
10. run: `for f in eval/abtest/checks/lib.sh eval/abtest/fixtures/lib.sh eval/abtest/verify-checks.sh eval/abtest/run-matrix.sh eval/abtest/arms/common.sh eval/abtest/fixtures/e01-ambiguous-tax/build.sh eval/abtest/fixtures/e02-preview-mutation/build.sh eval/abtest/fixtures/e03-rename-query/build.sh eval/abtest/fixtures/e04-search-injection/build.sh eval/abtest/fixtures/e05-tags-feature/build.sh; do bash -n "$f" || exit 1; done; echo syntax-ok`
   exit: 0
   stdout: `syntax-ok`
   mutation: delete the closing brace line of _abt_guard_copy in eval/abtest/checks/lib.sh; bash -n exits 2 and syntax-ok is not printed.
   proof: scratch run: with the last line of eval/abtest/checks/lib.sh deleted, `bash -n eval/abtest/checks/lib.sh` exited 2 with syntax error: unexpected end of file.
11. run: `bash eval/abtest/verify-checks.sh --all | tail -n 1`
   exit: 0
   stdout: `verify-checks: ok`
   mutation: skip edit 2; the guard functions are undefined, every real check.sh run fails, and the last line reads verify-checks: FAILED.
12. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05h\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/arms/common.sh eval/abtest/checks/lib.sh eval/abtest/fixtures/e01-ambiguous-tax/build.sh eval/abtest/fixtures/e02-preview-mutation/build.sh eval/abtest/fixtures/e03-rename-query/build.sh eval/abtest/fixtures/e04-search-injection/build.sh eval/abtest/fixtures/e05-tags-feature/build.sh eval/abtest/fixtures/lib.sh eval/abtest/run-matrix.sh eval/abtest/verify-checks.sh tests/abtest-arms.test.sh tests/abtest-blind.test.sh tests/abtest-checks.test.sh tests/abtest-probe.test.sh tests/abtest-row.test.sh tests/abtest-runner.test.sh tests/abtest-score.test.sh tests/abtest-stream.test.sh`
   mutation: skip edit 27 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
13. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05h\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 27; no unit commit exists and the exit is 3.
14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u05h\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/checks/lib.sh eval/abtest/fixtures/lib.sh eval/abtest/verify-checks.sh eval/abtest/run-matrix.sh eval/abtest/arms/common.sh eval/abtest/fixtures/e01-ambiguous-tax/build.sh eval/abtest/fixtures/e02-preview-mutation/build.sh eval/abtest/fixtures/e03-rename-query/build.sh eval/abtest/fixtures/e04-search-injection/build.sh eval/abtest/fixtures/e05-tags-feature/build.sh tests/abtest-blind.test.sh tests/abtest-arms.test.sh tests/abtest-probe.test.sh tests/abtest-runner.test.sh tests/abtest-row.test.sh tests/abtest-score.test.sh tests/abtest-checks.test.sh tests/abtest-stream.test.sh | grep -vcE "^[a-z]+\(abt-u05h\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
15. run: `git status --porcelain -- eval/abtest/checks/lib.sh eval/abtest/fixtures/lib.sh eval/abtest/verify-checks.sh eval/abtest/run-matrix.sh eval/abtest/arms/common.sh eval/abtest/fixtures/e01-ambiguous-tax/build.sh eval/abtest/fixtures/e02-preview-mutation/build.sh eval/abtest/fixtures/e03-rename-query/build.sh eval/abtest/fixtures/e04-search-injection/build.sh eval/abtest/fixtures/e05-tags-feature/build.sh tests/abtest-blind.test.sh tests/abtest-arms.test.sh tests/abtest-probe.test.sh tests/abtest-runner.test.sh tests/abtest-row.test.sh tests/abtest-score.test.sh tests/abtest-checks.test.sh tests/abtest-stream.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 27; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-checks.test.sh (criteria 2-7 are red-then-green: the new rows do not exist at HEAD)
blast-radius: eval/abtest/checks/e01-ambiguous-tax/check.sh:3 eval/abtest/run-matrix.sh:330 eval/abtest/verify-checks.sh:18
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
safety: every guard row runs lib.sh under a cp stub (written by the test) that copies only between paths inside the test temp dir and refuses any other path with exit 97 and a DANGER log line, with a 30 s timeout, a 20 MB file-size limit and an empty TMPDIR that must stay empty. Never run an unguarded checks/lib.sh by hand with an empty or nonexistent worktree: that expanded to cp -a /. and copied a whole disk.
already-green: criteria 1, 10 and 11 pass at HEAD by design (1 and 11 guard the existing suite and the five real fixtures against an over-strict guard; 10 is a syntax check).
newline-argument: a worktree path ending in a newline is refused on purpose ($(cd DIR && pwd) strips the newline and names another directory); a directory with a space is accepted when it is a git worktree root, and one test row pins that.
not-done: the four tests/abtest-report*.test.sh files keep their unguarded T="$(mktemp -d)" (owned by the unlanded unit abt-u21a); a one-line follow-up after it lands. The three rm -rf "$dir" "$wdir" lines of run-matrix.sh are covered by the new ABT_RUNS/ABT_WORK guard and stay.
not-stamped: no agents/*.md or templates/ file is touched, so there is no version bump and no CHANGELOG entry.
commit-message: fix(abt-u05h): checks/lib.sh fails closed on a bad worktree and the same guard everywhere a variable could be empty (#619)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u05h (#619)
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
