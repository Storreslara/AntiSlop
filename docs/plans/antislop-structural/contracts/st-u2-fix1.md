Unit: st-u2

## Objective
Fix round 1 for st-u2 (fix-of: 2026-10-21T06:51:44Z, the latest FAIL block). `bin/review-precheck.sh` normalizes
`--contract` to a repository-relative path (absolute and `..` spellings give the same packet as the relative one),
reads the contract only from the baseline commit, compares HEAD (not the working tree) for `contract:
changed-since-baseline`, and prints `contract: not-at-baseline` as a counted failure line, with no criterion run,
when the baseline lacks the contract. `tests/review-precheck.test.sh` case (e) fails under working-tree grading.
`agents/reviewer.md` lists `scope: excluded` and `contract: not-at-baseline` among the FAIL lines. Version
0.31.201 to 0.31.202; mirrors refreshed.

## Retrieval
Fast path, no tracker issue. Original contract: `docs/plans/antislop-structural/contracts/st-u2.md` (not edited).
This file is the fix contract of record for the same `Unit: st-u2`; the original criteria are kept (criteria 1, 2, 9,
10 and 14 here) and one criterion per defect is added. Dispatch it after st-u2's FAIL and before rp-u11,
st-u3 and st-u4: it edits no file those units or rp-u4 to rp-u7 and rp-u10 edit (they touch `tests/validate.sh`,
`templates/persona-protocol.md`, `bin/blast-radius.sh`, `bin/cli.js`, `hooks/`), so only the version files serialize
with them, and each of their `perl` bump edits adds one to whatever it finds.

## Affected files
- `bin/review-precheck.sh` (anchors: line matching `# Writes only .claude/bookkeeping/<unit>.precheck (a copy of stdout).`; line matching `# The contract is read as it was at the baseline, so the unit cannot rewrite its own criteria.`; line matching `crit_items() { # prints`; line matching `say "criteria: none (no contract; run the project's test and lint command yourself)"`)
- `tests/review-precheck.test.sh` (anchors: line matching `grep -qxF 'scope: excluded CONTEXT.md'`; line matching `g commit -qam 'u1: weaken criterion'`; line matching `'Read code only for judgment'; do`)
- `agents/reviewer.md` (anchor: line matching `is a FAIL ground on its own: return FAIL quoting those lines, without reading`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.201",`; new version 0.31.202), `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- generated only, by `node bin/cli.js --update`: `.claude/bin/review-precheck.sh`, `.claude/agents/*.md` (reviewer inlines its body; the rest the protocol), `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`, the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `bin/review-precheck.sh`
   anchor: line matching `# Writes only .claude/bookkeeping/<unit>.precheck (a copy of stdout).`
   indent: 0
   header comment: the contract is read only from the baseline (note 5); `--fix-contract` is read from the working tree (note 4)
   before:
~~~
# Writes only .claude/bookkeeping/<unit>.precheck (a copy of stdout).
~~~
   after:
~~~
# Writes only .claude/bookkeeping/<unit>.precheck (a copy of stdout).
# --contract is read ONLY from the baseline commit, never from the working tree: criteria run here through
# `bash -c`, so no PreToolUse hook sees them, and a copy a writer can edit must not be able to run commands.
# A contract that is not at the baseline is a failure line (`contract: not-at-baseline`), not a fallback.
# --fix-contract is the exception: it is written after the baseline, so it is read from the working tree.
~~~
2. file: `bin/review-precheck.sh`
   anchor: line matching `# The contract is read as it was at the baseline, so the unit cannot rewrite its own criteria.`
   indent: 0
   normalize `--contract`; compare HEAD, not the working tree (note 2); a contract absent at the baseline is a counted failure line, never a working-tree fallback (note 5)
   before:
~~~
# The contract is read as it was at the baseline, so the unit cannot rewrite its own criteria.
cfile=""
if [ -n "$contract" ]; then
  if git cat-file -e "$base:$contract" 2>/dev/null; then
    git show "$base:$contract" > "$W/contract"; cfile="$W/contract"
    if [ -e "$contract" ] && ! cmp -s "$W/contract" "$contract"; then failon "contract: changed-since-baseline $contract"; fi
  elif [ -f "$contract" ]; then
    cp "$contract" "$W/contract"; cfile="$W/contract"; say "contract: not-at-baseline $contract"
  else
    echo "review-precheck: contract not found: $contract" >&2; exit 2
  fi
fi
~~~
   after:
~~~
# --contract as a repository-relative path with "." and ".." folded; an absolute path under the top is
# stripped to it. Prints nothing and returns 1 for a path outside the repository.
top_rel() {
  local p="$1" seg out=() n IFS=/
  case "$p" in "$top"/*) p="${p#"$top"/}" ;; /*) return 1 ;; esac
  read -ra segs <<< "$p"
  for seg in ${segs[@]+"${segs[@]}"}; do
    case "$seg" in
      ''|.) ;;
      ..) n=${#out[@]}; [ "$n" -gt 0 ] || return 1; out=("${out[@]:0:n-1}") ;;
      *) out+=("$seg") ;;
    esac
  done
  [ "${#out[@]}" -gt 0 ] || return 1
  printf '%s' "${out[*]}"
}
if [ -n "$contract" ]; then
  c0="$contract"; contract="$(top_rel "$c0")" || { echo "review-precheck: contract is not a path inside the repository: $c0" >&2; exit 2; }
fi

# The contract is read as it was at the baseline, so the unit cannot rewrite its own criteria. It is
# compared with HEAD, not the working tree, so an uncommitted doc edit is not the unit's change.
cfile=""
if [ -n "$contract" ]; then
  if git cat-file -e "$base:$contract" 2>/dev/null; then
    git show "$base:$contract" > "$W/contract"; cfile="$W/contract"
    if ! git show "$head:$contract" 2>/dev/null | cmp -s "$W/contract" -; then failon "contract: changed-since-baseline $contract"; fi
  elif [ -e "$contract" ] || git cat-file -e "$head:$contract" 2>/dev/null; then
    failon "contract: not-at-baseline $contract"
  else
    echo "review-precheck: contract not found: $contract" >&2; exit 2
  fi
fi
~~~
3. file: `bin/review-precheck.sh`
   anchor: line matching `crit_items() { # prints`
   indent: 0
   reword the comment whose `<TAB>` tokens made `--update` warn of unresolved placeholders (note 3)
   before:
~~~
crit_items() { # prints "n<TAB>cmd<TAB>exit<TAB>stdout-spec<TAB>long" per criterion
~~~
   after:
~~~
crit_items() { # prints one tab-separated line per criterion: n, cmd, exit, stdout-spec, long
~~~
4. file: `bin/review-precheck.sh`
   anchor: line matching `say "criteria: none (no contract; run the project's test and lint command yourself)"`
   indent: 0
   the `criteria: none` line says why when a contract was given
   before:
~~~
else
  say "criteria: none (no contract; run the project's test and lint command yourself)"
~~~
   after:
~~~
elif [ -n "$contract" ]; then
  say "criteria: none (the contract is not at the baseline; no criteria are read from anywhere else)"
else
  say "criteria: none (no contract; run the project's test and lint command yourself)"
~~~
5. file: `tests/review-precheck.test.sh`
   anchor: line matching `bash "$PC" u2 "$BASE" --contract "$C2" | grep -qxF 'scope: excluded CONTEXT.md'`
   indent: 0
   test (c): the `scope: excluded` file is counted in `fails=` (note 1)
   before:
~~~
bash "$PC" u2 "$BASE" --contract "$C2" | grep -qxF 'scope: excluded CONTEXT.md' && ok "(c) a whole-file Do NOT touch bullet" || bad "(c) excluded class"
~~~
   after:
~~~
o2="$(bash "$PC" u2 "$BASE" --contract "$C2")"
printf '%s\n' "$o2" | grep -qxF 'scope: excluded CONTEXT.md' && ok "(c) a whole-file Do NOT touch bullet" || bad "(c) excluded class"
first "$o2" | grep -q '^precheck: result=fail .* fails=2 ' && ok "(c) an excluded file counts as a failure" || bad "(c) excluded not counted: $(first "$o2")"
~~~
6. file: `tests/review-precheck.test.sh`
   anchor: line matching `printf 'a\nb\n' > src/a.js && sed -i 's/grep -c b/grep -c a/' "$C" && g commit -qam 'u1: weaken criterion'`
   indent: 0
   test (e): the weakened criterion now differs from the baseline one; new rows for absolute and `..` spellings, outside-repository paths, a missing baseline contract (e2) and an uncommitted contract edit (e3)
   before:
~~~
printf 'a\nb\n' > src/a.js && sed -i 's/grep -c b/grep -c a/' "$C" && g commit -qam 'u1: weaken criterion'
out="$(bash "$PC" u1 "$BASE" --contract "$C")"
printf '%s\n' "$out" | grep -qxF "contract: changed-since-baseline $C" && ok "(e) contract edited after the baseline" || bad "(e) contract edit not flagged"
printf '%s\n' "$out" | grep -qxF 'criterion 1: pass exit=0' && ok "(e) baseline criteria used" || bad "(e) criteria not from baseline"
g reset -q --hard HEAD~1
~~~
   after:
~~~
printf 'a\n' > src/a.js && sed -i 's/grep -c b/grep -c a/' "$C" && g commit -qam 'u1: weaken criterion'
out="$(bash "$PC" u1 "$BASE" --contract "$C")"
printf '%s\n' "$out" | grep -qxF "contract: changed-since-baseline $C" && ok "(e) contract edited after the baseline" || bad "(e) contract edit not flagged"
# The weakened criterion (grep -c a) passes on this tree and the baseline one (grep -c b) fails: only the baseline one may be graded.
printf '%s\n' "$out" | grep -qxF 'criterion 1: fail exit=1 want=0' && ok "(e) baseline criteria used" || bad "(e) criteria not from baseline"
TOP="$(git rev-parse --show-toplevel)"
out_abs="$(bash "$PC" u1 "$BASE" --contract "$TOP/$C")"; out_dots="$(bash "$PC" u1 "$BASE" --contract "docs/plans/p/../p/./contracts/u1.md")"
[ "$out_abs" = "$out" ] && ok "(e) an absolute --contract gives the same packet" || bad "(e) absolute spelling differs: $(first "$out_abs")"
[ "$out_dots" = "$out" ] && ok "(e) a .. and . --contract gives the same packet" || bad "(e) dots spelling differs: $(first "$out_dots")"
for bad_c in /etc/hostname ../x docs/../../x "$TOP/../x"; do
  bash "$PC" u1 "$BASE" --contract "$bad_c" >/dev/null 2>&1; [ "$?" = 2 ] && ok "(e) --contract outside the repository exit 2: $bad_c" || bad "(e) outside path accepted: $bad_c"
done
g reset -q --hard HEAD~1

# (e2) A contract the baseline does not have is a failure line and is never read from the working tree or HEAD.
C3=docs/plans/p/contracts/u3.md
cat > "$C3" << 'MD'
Unit: u3

## Affected files
- `src/a.js`

## Acceptance criteria
1. run: `bash -c 'echo 1'`
   exit: 0
   stdout: `1`
   mutation: none
MD
for stage in untracked committed-later; do
  [ "$stage" = committed-later ] && g add "$C3" && g commit -q -m 'contract after the baseline'
  out="$(bash "$PC" u3 "$BASE" --contract "$C3")"
  printf '%s\n' "$out" | grep -qxF "contract: not-at-baseline $C3" && ok "(e2) $stage: not-at-baseline line" || bad "(e2) $stage: no not-at-baseline line"
  first "$out" | grep -q '^precheck: result=fail .* fails=2 ' && ok "(e2) $stage: result=fail fails=2" || bad "(e2) $stage: $(first "$out")"
  printf '%s\n' "$out" | grep -q '^criterion [0-9]*: ' && bad "(e2) $stage: a criterion ran from an unpinned contract" || ok "(e2) $stage: no criterion ran"
  bash "$PC" u3 "$BASE" --contract "$C3" --criterion 1 >/dev/null 2>&1; [ "$?" = 2 ] && ok "(e2) $stage: --criterion exit 2" || bad "(e2) $stage: --criterion ran"
done
g reset -q --hard HEAD~1

# (e3) An uncommitted edit of the contract is not the unit's change: HEAD is compared, and criteria still come from the baseline.
sed -i 's/grep -c b/grep -c a/' "$C"
out="$(bash "$PC" u1 "$BASE" --contract "$C")"
printf '%s\n' "$out" | grep -q '^contract: ' && bad "(e3) an uncommitted contract edit was flagged" || ok "(e3) an uncommitted contract edit is not flagged"
printf '%s\n' "$out" | grep -q '^criterion 1: fail stdout want=1 got=2$' && ok "(e3) criteria still from the baseline" || bad "(e3) criteria from the working tree"
g checkout -q -- "$C"
~~~
7. file: `tests/review-precheck.test.sh`
   anchor: line matching `'Read code only for judgment'; do`
   indent: 0
   test (j): the reviewer prose names the new FAIL lines and the baseline-only rule
   before:
~~~
for f in agents/reviewer.md .claude/agents/reviewer.md; do
  for n in 'run `bash .claude/bin/review-precheck.sh <task-id> <baseline> --contract <contract path>` yourself' \
           'is a FAIL ground on its own: return FAIL quoting those lines, without reading the code' \
           'Do not re-run a criterion it reports `pass`; run each `deferred` one yourself with `--criterion <n>`' \
           'Read code only for judgment'; do
~~~
   after:
~~~
for f in agents/reviewer.md .claude/agents/reviewer.md; do
  for n in 'run `bash .claude/bin/review-precheck.sh <task-id> <baseline> --contract <contract path>` yourself' \
           'is a FAIL ground on its own: return FAIL quoting those lines, without reading the code' \
           'Do not re-run a criterion it reports `pass`; run each `deferred` one yourself with `--criterion <n>`' \
           '`scope: excluded`, `scope: no-affected-list`' \
           'or `contract: not-at-baseline` line is a FAIL ground on its own' \
           'The script reads the contract only from the baseline commit.' \
           'Read code only for judgment'; do
~~~
8. file: `agents/reviewer.md`
   anchor: line matching `is a FAIL ground on its own: return FAIL quoting those lines, without reading`
   indent: 0
   reviewer bullet: add the two FAIL lines and the baseline-only sentence
   before:
~~~
- **Run the mechanical pre-review first**: run
  `bash .claude/bin/review-precheck.sh <task-id> <baseline> --contract <contract path>`
  yourself, from the repo root, with a Bash timeout of 600000 ms (with no
  contract, pass each `## Affected files` path of the dispatch as
  `--affected <path>`; in a fix round add `--fix-contract <path>`). Line 1 reads
  `precheck: result=<pass|fail> ... fails=<n> deferred=<n> judge=<n>`. Each
  `scope: out`, `scope: no-affected-list`, `criterion <n>: fail`,
  `version-stamp: ... violation` or `contract: changed-since-baseline` line
  is a FAIL ground on its own: return FAIL quoting those lines, without reading
  the code. Do not re-run a criterion it reports `pass`; run each `deferred`
~~~
   after:
~~~
- **Run the mechanical pre-review first**: run
  `bash .claude/bin/review-precheck.sh <task-id> <baseline> --contract <contract path>`
  yourself, from the repo root, with a Bash timeout of 600000 ms (with no
  contract, pass each `## Affected files` path of the dispatch as
  `--affected <path>`; in a fix round add `--fix-contract <path>`). Line 1 reads
  `precheck: result=<pass|fail> ... fails=<n> deferred=<n> judge=<n>`. Each
  `scope: out`, `scope: excluded`, `scope: no-affected-list`,
  `criterion <n>: fail`, `version-stamp: ... violation`,
  `contract: changed-since-baseline` or `contract: not-at-baseline` line
  is a FAIL ground on its own: return FAIL quoting those lines, without reading
  the code. The script reads the contract only from the baseline commit. Do not
  re-run a criterion it reports `pass`; run each `deferred`
~~~
9. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.201 to 0.31.202; one above whatever HEAD holds if another unit bumped first).
10. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Reviewer pre-review fixes (st-u2-fix1, VERSION).** bin/review-precheck.sh: `--contract` is normalized to a repository-relative path (an absolute path under the repository, `.` and `..` segments), so every spelling reads the contract from the baseline commit; a path outside the repository exits 2. A contract the baseline does not have is a `contract: not-at-baseline` failure line and no criterion runs from any working-tree or HEAD copy (criteria run through `bash -c`, outside every hook). The changed-since-baseline check compares HEAD, not the working tree. `--fix-contract` is still read from the working tree. agents/reviewer.md: `scope: excluded` and `contract: not-at-baseline` join the FAIL lines. tests/review-precheck.test.sh: case (e) now fails under working-tree grading; new rows for absolute and `..` spellings, a missing baseline contract, an uncommitted contract edit and `scope: excluded` counted.
~~~
   Replace `VERSION` with the version edit 9 wrote.
11. command: `node bin/cli.js --update`
   expect: 0
12. command: `bash tests/review-precheck.test.sh`
   expect: 0
13. command: `git add bin/review-precheck.sh tests/review-precheck.test.sh agents/reviewer.md CHANGELOG.md package.json .claude-plugin/plugin.json .claude/bin/review-precheck.sh && git add -u -- .claude && git commit -m "fix(st-u2): review-precheck pins the contract at the baseline for every path spelling; a missing baseline contract is a failure line"`
   expect: 0
   Run `git status --porcelain --untracked-files=no` first: if a tracked file outside "Affected files" is modified, stop and report it. After the commit it prints nothing.

## Do NOT touch
- `adapters/` (the codex and cursor reviewers install no `.claude/bin/`; criterion 12)
- `hooks/` and `.claude/hooks/` (the script is the reviewer's own tool, not a gate; criterion 12)
- `hooks/scripts/lib/unit-scope.sh` and `hooks/scripts/lib/sensitive-paths.sh` (st-u1's and rp-u11's; this unit only sources them)
- `agents/orchestrator.md` (the orchestrator neither runs nor forwards the packet; criterion 12)
- `templates/persona-protocol.md` (rp-u7 edits that paragraph; the st-u2 sentence in it stays as written)
- `tests/validate.sh` (st-u3 and st-u4 anchor on its st-u2 block, which already runs the test)
- `bin/cli.js` (BIN_HELPER_FILES already lists the script)
- `docs/plans/antislop-structural/contracts/st-u2.md` (the original contract is not edited)
- `.claude/agents/` and `.claude/bin/` by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'bash tests/review-precheck.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: in a scratch copy of the finished change, keep the changed-since-baseline compare but grade from the working tree (`git show "$base:$contract" > "$W/contract"; cfile="$contract"`): the suite prints `FAIL (e) criteria not from baseline` and stdout is `1`. Restoring the `[ -f "$contract" ]` copy fallback fails the (e2) rows; dropping the `top_rel` call fails the spelling rows; comparing the working tree for the HEAD compare fails (e3); making `scope: excluded` a `say` fails the (c) fails=2 row.
   proof: each mutant replayed in `git worktree add --detach` checkouts of the finished change on 2026-10-21; each printed the named FAIL line and the suite exited 1.

2. run: `cmp bin/review-precheck.sh .claude/bin/review-precheck.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 11 (`--update`); the installed copy keeps the old script, cmp reports a difference and exits 1.

3. run: `bash -c 'bash tests/review-precheck.test.sh | grep -cE "^OK   \(e\) (an absolute|a \.\. and \.)"' `
   exit: 0
   stdout: `2`
   mutation: drop the `top_rel` call (replace `contract="$(top_rel "$c0")"` with `contract="$c0"`); both rows print FAIL, the count is 0 and the exit is 1.
   proof: replayed in a scratch checkout; count 0, exit 1.

4. run: `bash -c 'bash tests/review-precheck.test.sh | grep -cE "^OK   \(e2\) "' `
   exit: 0
   stdout: `8`
   mutation: restore the fallback (replace `failon "contract: not-at-baseline $contract"` with `cp "$contract" "$W/contract"; cfile="$W/contract"; say "contract: not-at-baseline $contract"`); the (e2) rows print FAIL, the count drops below 8.
   proof: replayed in a scratch checkout; the (e2) rows for `result=fail`, `no criterion ran` and `--criterion exit 2` printed FAIL, count 2.

5. run: `bash -c 'bash tests/review-precheck.test.sh | grep -cE "^OK   \((e|e3)\) (baseline criteria used|criteria still from the baseline|an uncommitted contract edit is not flagged)"' `
   exit: 0
   stdout: `3`
   mutation: grade from the working tree (`git show "$base:$contract" > "$W/contract"; cfile="$contract"`); `(e) baseline criteria used` and `(e3) criteria still from the baseline` print FAIL, the count is 1.
   proof: replayed in a scratch checkout; count 1, exit 0, so the stdout check `3` fails.

6. run: `bash -c 'bash tests/review-precheck.test.sh | grep -c "^OK   (c) an excluded file counts as a failure"' `
   exit: 0
   stdout: `1`
   mutation: make the `excluded)` arm a `say` instead of `failon`; the row prints FAIL (fails=1), the count is 0 and the exit is 1.
   proof: replayed in a scratch checkout.

7. run: `bash -c 'bash .claude/bin/review-precheck.sh st-u2 HEAD --contract /etc/hostname >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `2`
   mutation: skip edit 11 (`--update`); the installed copy falls back to the existing `/etc/hostname`, exits 0 and stdout is `0`.

8. run: `bash -c 'for p in "scope: excluded" "contract: not-at-baseline" "reads the contract only from the baseline commit"; do cat agents/reviewer.md .claude/agents/reviewer.md | tr "\n" " " | tr -s " " | grep -oF "$p" | wc -l; done | paste -sd, -' `
   exit: 0
   stdout: `2,2,2`
   mutation: skip edit 8; each count is 0 (`0,0,0`).

9. run: `bash -c 'node tests/adapter-protocol-parity.test.js >/dev/null && node tests/protocol-doc-drift.test.js >/dev/null && node tests/protocol-cross-references.test.js >/dev/null && bash tests/persona-prose-pins.test.sh >/dev/null && bash tests/bin-helpers-scaffold.test.sh >/dev/null && node tests/cli-backfill.test.js >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: add a line starting `## ` inside the persona-protocol mirror; protocol-doc-drift's section count no longer matches and stdout is `1`.
   proof: the original st-u2 criterion 6 mutation, unchanged: this unit edits no protocol text, so the check guards the reviewer.md bullet pins.

10. run: `bash -c 'l=$(git log --format="%H %s" | grep -E "^[0-9a-f]+ [a-z]+\(st-u2\): " | cut -d" " -f1 | head -1); bash hooks/scripts/version-stamp-check.sh "$l~1..$l" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 9; stdout reads `version-stamp-check: violation touched: yes`.

11. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;process.exit(a===b?0:1)" && echo version-sync: ok`
   exit: 0
   stdout: `version-sync: ok`
   mutation: revert the package.json hunk of edit 9 only; nothing prints and the exit is 1.

12. run: `bash -c 'l=$(git log --format="%H %s" | grep -E "^[0-9a-f]+ [a-z]+\(st-u2\): " | cut -d" " -f1 | head -1); git diff --name-only "$l~1..$l" | grep -vcE "^(bin/review-precheck\.sh|tests/review-precheck\.test\.sh|agents/reviewer\.md|CHANGELOG\.md|package\.json|\.claude-plugin/plugin\.json|\.claude/.*)$"'`
   exit: 1
   stdout: `0`
   mutation: also edit `bin/cli.js` in the commit; stdout is `1`.

13. run: `bash -c 'l=$(git log --format="%H %s" | grep -E "^[0-9a-f]+ [a-z]+\(st-u2\): " | cut -d" " -f1 | head -1); git log --format=%s "$l..HEAD" -- bin/review-precheck.sh tests/review-precheck.test.sh agents/reviewer.md | grep -vcE "^[a-z]+\(st-u2\): "'`
   exit: 1
   stdout: `0`
   mutation: a later commit touching `agents/reviewer.md` with a subject outside `<type>(st-u2): ` makes stdout `1` (run at review time over the unit's content files).

14. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?' (Bash tool timeout 600000 ms)`
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/review-precheck.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes tests/review-precheck.test.sh is edited first in effect: its new rows fail against the unfixed script (edits 5 to 7 are tests, 1 to 4 the script).
blast-radius: bin/review-precheck.sh:39-50 (the contract block edit 2 replaces), bin/review-precheck.sh:53 (crit_items comment), bin/review-precheck.sh:133-135 (criteria none), tests/review-precheck.test.sh:121 (excluded row), tests/review-precheck.test.sh:134-138 (case e), tests/review-precheck.test.sh:169-176 (prose rows), agents/reviewer.md:18-31 (the bullet), bin/cli.js:656 (BIN_HELPER_FILES, unchanged), .claude/bin/review-precheck.sh (mirror). The only callers of the script are the reviewer bullet and the test; no other file reads its output lines.
fix-of: 2026-10-21T06:51:44Z
before-the-edit: at HEAD (0e2a8539) criteria 3 to 8 and 12 fail; criteria 1, 2, 9, 10, 11 and 13 already pass and guard against regression (criterion 1 passes because the new rows come with the edit; criterion 14 is the full suite, green at HEAD and after, replayed 2026-10-21 in a scratch checkout of the finished change with exit 0).
order: dispatch after st-u2's FAIL and before rp-u11, st-u3 and st-u4. It shares no file with rp-u4 to rp-u7, rp-u10, rp-u11, st-u3 or st-u4 except the version files and CHANGELOG, whose edits are `perl` increments and an insert after `## [Unreleased]`, so each of those units' text "expected 0.31.20x" in prose is one low but their commands are correct. rp-u7 edits the protocol paragraph and bin/blast-radius.sh, rp-u10 edits reviewer-tier, unit-bookkeeping and stop-gate; neither is touched here.
notes: reviewer notes 1, 2, 3 and 5 are in this commit (edits 5, 2, 3 and 2 with 1). Note 4 (`--fix-contract` is read from the working tree) is recorded in the script header (edit 1) and the CHANGELOG. Not done, follow-up: the reviewer bullet does not say what to do when the contract is committed after the baseline; the script now returns FAIL for it, which is the intended grade.
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
commit-message: fix(st-u2): review-precheck pins the contract at the baseline for every path spelling; a missing baseline contract is a failure line
diagnosis: none
review-packet:
~~~
unit: st-u2 (fix round 1)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise. If a `before:` payload is not found verbatim, quote the current text and stop. If `node bin/cli.js --update` refuses, quote its message and stop. If a gate blocks a command, report it and wait.
