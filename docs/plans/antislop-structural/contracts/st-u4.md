Unit: st-u4

## Objective
Size and risk routed lanes (spec Step 4, variation a; operator ruling OQ2 = (ii), 2026-10-20). New
`bin/unit-size.sh <unit> (--contract <path> | -- <path>...)`, installed to `.claude/bin/`, picks a lane from the
unit's PLANNED scope before anything is dispatched:
- **full**: a sensitive path (st-u1's library, the reviewer-tier class); a `.fail` record for the unit; more
  than 10 entries; a directory, glob or trailing-slash entry (unmeasurable); a missing contract or no
  input; or the libraries missing.
- **small**: 4 entries or fewer.
- **medium**: otherwise.

Entries under `.claude/` and `docs/plans/` never count. It prints `lane: <small|medium|full> files=<n>
reason=<word>`, writes `.claude/bookkeeping/<unit>.lane` and `<unit>.scope` (the precheck reads the scope list
when there is no contract), and exits 0, or 2 on a bad unit id.

`agents/orchestrator.md` gains "Lane routing":
- **small**: no spec-master and no explorer first;
- **medium**: no spec-master; the orchestrator writes `## Affected files` and at most 5 steps itself; more
  than 5 steps is full;
- **full**: the default feature pipeline;
- downgrade-only: a heavier lane than printed is allowed, never a lighter one; a missing script, a
  non-zero exit or any other output is full.

The routing-table line for planning and the pre-explorer sentence point at the section. Every unit still gets
its reviewer. reviewer-tier.sh is unchanged and still measures the actual diff.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-structural/spec.md`, "Step 4 (st-u4)" and "Context, a".
This file is the contract of record. Dispatch it only after st-u3 has reached PASS (its validate.sh block and
st-u2's `BIN_HELPER_FILES` entry are this unit's anchors).

## Affected files
- `tests/unit-size.test.sh` (anchor: new file, mode 755)
- `bin/unit-size.sh` (anchor: new file, mode 755)
- `bin/cli.js` (anchor: line matching `const BIN_HELPER_FILES = [`)
- `tests/bin-helpers-scaffold.test.sh` (anchor: line matching `FILES="ladder-tier.sh`)
- `agents/orchestrator.md` (anchors: line matching `- Planning a non-trivial change → two-stage: `; line matching `## Delegation contract`; line matching `For a lead-programmer dispatch that carries no dispatch contract, spawn`)
- `tests/validate.sh` (anchor: line matching `echo "== writer-scope-gate: lead-programmer, scribe and spec-master cannot stop with an out-of-scope change (Bash, st-u3) =="`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/bin/unit-size.sh`, `.claude/agents/orchestrator.md`, the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/unit-size.test.sh`
   anchor: new file (mode 755)
   indent: 0
   insert-after:
~~~
#!/usr/bin/env bash
# unit-size.sh (st-u4): the lane from a unit's planned scope. Cases (a) to (j) run in a temp repo;
# (k) reads the orchestrator prose (operator rulings OQ2 = ii, downgrade-only).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
US="$ROOT/bin/unit-size.sh"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cd "$T" || exit 1
git init -q . && mkdir -p src test hooks docs/plans/p/contracts
export CLAUDE_PROJECT_DIR="$T"
BK="$T/.claude/bookkeeping"
is() { # <label> <want-line> <args...>
  local label="$1" want="$2"; shift 2
  local got; got="$(bash "$US" "$@")"
  [ "$got" = "$want" ] && ok "$label -> $want" || bad "$label: want '$want', got '$got'"
}

is "(a) two paths" 'lane: small files=2 reason=paths' u1 -- src/a.js test/a.test.js
[ "$(cat "$BK/u1.lane")" = 'lane: small files=2 reason=paths' ] && ok "(a) lane recorded" || bad "(a) lane record"
[ "$(cat "$BK/u1.scope")" = "$(printf 'src/a.js\ntest/a.test.js')" ] && ok "(a) scope recorded" || bad "(a) scope record"
is "(a) four is still small" 'lane: small files=4 reason=paths' u1 -- a b c d
is "(b) five is medium" 'lane: medium files=5 reason=paths' u1 -- a b c d e
is "(b) ten is medium" 'lane: medium files=10 reason=paths' u1 -- a b c d e f g h i j
is "(c) eleven is full" 'lane: full files=11 reason=size' u1 -- a b c d e f g h i j k
is "(d) a sensitive path" 'lane: full files=2 reason=sensitive' u1 -- src/a.js hooks/x.sh
is "(d) agents/ is sensitive" 'lane: full files=1 reason=sensitive' u1 -- agents/reviewer.md
mkdir -p "$T/.claude/reviewed" && printf 'FAIL u9 2026-10-20T00:00:00Z\ntier: sonnet\n- x\n' > "$T/.claude/reviewed/u9.fail"
is "(e) a FAIL record" 'lane: full files=1 reason=fail-record' u9 -- src/a.js
is "(f) a directory entry" 'lane: full files=1 reason=unmeasurable' u1 -- src
is "(f) a trailing slash" 'lane: full files=1 reason=unmeasurable' u1 -- lib/
is "(f) a glob" 'lane: full files=1 reason=unmeasurable' u1 -- 'src/*.js'
cat > docs/plans/p/contracts/u2.md << 'MD'
Unit: u2

## Affected files
- `src/a.js`
- `test/a.test.js`
- `.claude/agents/reviewer.md`
- `docs/plans/p/spec.md`
MD
is "(g) contract, bookkeeping entries ignored" 'lane: small files=2 reason=contract' u2 --contract docs/plans/p/contracts/u2.md
is "(g) missing contract" 'lane: full files=0 reason=no-input' u2 --contract docs/plans/p/contracts/none.md
is "(g) no input" 'lane: full files=0 reason=no-input' u2
is "(h) only bookkeeping entries" 'lane: full files=0 reason=empty' u2 -- .claude/x docs/plans/y
bash "$US" '../x' -- a >/dev/null 2>&1; [ "$?" = 2 ] && [ ! -e "$T/.claude/x.lane" ] && ok "(i) bad unit id exit 2" || bad "(i) bad unit id"
mkdir -p "$T/lonely/bin" && cp "$US" "$T/lonely/bin/unit-size.sh"
[ "$(bash "$T/lonely/bin/unit-size.sh" u1 -- src/a.js)" = 'lane: full files=0 reason=unmeasurable' ] && ok "(j) library missing -> full" || bad "(j) library missing"

# (k) prose: the orchestrator routes on the lane, downgrade-only, medium lane without spec-master.
flat() { tr -s ' \n' ' ' < "$1"; }
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  for n in 'bash .claude/bin/unit-size.sh <task-id> --contract <contract file>' \
           'You may move a unit to a heavier lane than it prints, never to a lighter one.' \
           'A missing script, a non-zero exit or any other output is `full` too.' \
           'no spec-master and no explorer first' \
           'Write `## Affected files` and at most 5 numbered steps yourself' \
           'A request that needs more than 5 steps is `full`.' \
           'outside the small lane (see "Lane routing"), spawn `explorer` first' \
           '- Planning a non-trivial change in the full lane (see "Lane routing") → two-stage:'; do
    flat "$ROOT/$f" | grep -qF -- "$n" && ok "(k) $f: $n" || bad "(k) $f missing: $n"
  done
  flat "$ROOT/$f" | grep -qF 'Planning a non-trivial change → two-stage' && bad "(k) $f keeps the unrouted line" || ok "(k) $f: old routing line gone"
done
exit "$fail"
~~~
2. command: `bash tests/unit-size.test.sh`
   expect: 1
   The red step: the script does not exist and the prose rows (k) fail.
3. file: `bin/unit-size.sh`
   anchor: new file (mode 755)
   indent: 0
   insert-after:
~~~
#!/usr/bin/env bash
# unit-size.sh (st-u4): the lane for one unit, from its PLANNED scope, before any work is dispatched.
# Usage: unit-size.sh <unit> --contract <path> | unit-size.sh <unit> -- <path>...
# Prints `lane: <small|medium|full> files=<n> reason=<word>`, writes .claude/bookkeeping/<unit>.lane and
# <unit>.scope, exit 0 (2 only on a bad unit id). Fails closed: anything it cannot measure is `full`.
# The orchestrator may move a unit to a heavier lane than this prints, never to a lighter one.
set -uo pipefail
[ "$#" -ge 1 ] || { echo "usage: unit-size.sh <unit> (--contract <path> | -- <path>...)" >&2; exit 2; }
unit="$1"; shift
[[ "$unit" =~ ^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$ ]] || { echo "unit-size: bad unit id: $unit" >&2; exit 2; }
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
top="$(git rev-parse --show-toplevel 2>/dev/null)" || top="$PWD"
cd "$top" || exit 2
dot="${CLAUDE_PROJECT_DIR:-$top}/.claude"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
: > "$W/entries"
emit() { # <lane> <n> <reason>
  local line="lane: $1 files=$2 reason=$3"
  mkdir -p "$dot/bookkeeping" && printf '%s\n' "$line" > "$dot/bookkeeping/$unit.lane" \
    && cp "$W/entries" "$dot/bookkeeping/$unit.scope"
  echo "$line"; exit 0
}
lib="$dir/../hooks/scripts/lib"
{ . "$lib/sensitive-paths.sh" && . "$lib/unit-scope.sh"; } 2>/dev/null || emit full 0 unmeasurable
src=none
if [ "${1:-}" = --contract ]; then
  [ -n "${2:-}" ] && [ -f "$2" ] || emit full 0 no-input
  us_entries "$2" > "$W/raw"; src=contract
elif [ "${1:-}" = -- ]; then
  shift; printf '%s\n' "$@" > "$W/raw"; src=paths
else
  emit full 0 no-input
fi
# Bookkeeping entries never count: .claude/ copies are generated, docs/plans/ is the plan itself.
grep -vE '^(\.claude/|docs/plans/)' "$W/raw" | grep -v '^$' | sort -u > "$W/entries" || true
n="$(wc -l < "$W/entries" | tr -d ' ')"
[ "$n" -gt 0 ] || emit full 0 empty
while IFS= read -r p; do
  case "$p" in *[*?[]*|*/) emit full "$n" unmeasurable ;; esac
  [ -d "$p" ] && emit full "$n" unmeasurable
done < "$W/entries"
while IFS= read -r p; do
  touches_sensitive_path "$p" && emit full "$n" sensitive
done < "$W/entries"
[ -f "$dot/reviewed/$unit.fail" ] && emit full "$n" fail-record
[ "$n" -gt 10 ] && emit full "$n" size
[ "$n" -le 4 ] && emit small "$n" "$src"
emit medium "$n" "$src"
~~~
4. file: `bin/cli.js`
   anchor: line matching `const BIN_HELPER_FILES = [`
   indent: 0
   before: `const BIN_HELPER_FILES = ['ladder-tier.sh', 'contract-guard.js', 'contract-score.js', 'fail-count.sh', 'escalation-card.sh', 'unit-bookkeeping.sh', 'blast-radius.sh', 'review-precheck.sh'];`
   after: `const BIN_HELPER_FILES = ['ladder-tier.sh', 'contract-guard.js', 'contract-score.js', 'fail-count.sh', 'escalation-card.sh', 'unit-bookkeeping.sh', 'blast-radius.sh', 'review-precheck.sh', 'unit-size.sh'];`
5. file: `tests/bin-helpers-scaffold.test.sh`
   anchor: line matching `FILES="ladder-tier.sh`
   indent: 0
   before: `FILES="ladder-tier.sh contract-guard.js contract-score.js fail-count.sh escalation-card.sh unit-bookkeeping.sh blast-radius.sh review-precheck.sh"`
   after: `FILES="ladder-tier.sh contract-guard.js contract-score.js fail-count.sh escalation-card.sh unit-bookkeeping.sh blast-radius.sh review-precheck.sh unit-size.sh"`
   In the same file, change both occurrences of `(a) eight helpers present` to `(a) nine helpers present`.
6. file: `agents/orchestrator.md`
   anchor: line matching `- Planning a non-trivial change → two-stage: ` (routing table, the only such line)
   indent: 0
   before:
~~~
- Planning a non-trivial change → two-stage: `spec-master` (produces the
~~~
   after:
~~~
- Planning a non-trivial change in the full lane (see "Lane routing") → two-stage: `spec-master` (produces the
~~~
7. file: `agents/orchestrator.md`
   anchor: line matching `## Delegation contract` (the only such heading)
   indent: 0
   before: `## Delegation contract`
   after:
~~~
## Lane routing (size and risk, decided before dispatch)

Before planning or dispatching a change, run `bash .claude/bin/unit-size.sh <task-id> --contract <contract
file>`, or, with no contract, `bash .claude/bin/unit-size.sh <task-id> -- <path>...` with the paths you will
put under `## Affected files`. It prints `lane: <small|medium|full> files=<n> reason=<word>` and records the
lane and the scope list under `.claude/bookkeeping/`. A sensitive path, a `.fail` record for the unit, more
than 10 files, or anything it cannot measure prints `full`. A missing script, a non-zero exit or any other
output is `full` too. You may move a unit to a heavier lane than it prints, never to a lighter one.
- **small** (4 files or fewer): no spec-master and no explorer first. Write `## Affected files` from the
  paths the request names and their tests (one Glob or Grep call), and dispatch lead-programmer with the
  objective, that list and `## Pre-resolved context` reading `none (small lane: read the listed files
  yourself)`; then its reviewer.
- **medium** (5 to 10 files): no spec-master. Write `## Affected files` and at most 5 numbered steps
  yourself, and dispatch one lead-programmer per step, each followed by its reviewer; the explorer still
  runs first for a dispatch with no contract. A request that needs more than 5 steps is `full`.
- **full**: the "Default feature pipeline" below (spec-master, task-master when the spec has 6 or more
  units, the explorer before a dispatch with no contract).

Every unit in every lane gets its reviewer.

## Delegation contract
~~~
8. file: `agents/orchestrator.md`
   anchor: line matching `For a lead-programmer dispatch that carries no dispatch contract, spawn` (in "Delegation contract")
   indent: 0
   before:
~~~
For a lead-programmer dispatch that carries no dispatch contract, spawn `explorer` first
~~~
   after:
~~~
For a lead-programmer dispatch that carries no dispatch contract, outside the small lane (see "Lane
routing"), spawn `explorer` first
~~~
9. file: `tests/validate.sh`
   anchor: line matching `echo "== writer-scope-gate: lead-programmer, scribe and spec-master cannot stop with an out-of-scope change (Bash, st-u3) =="`
   indent: 0
   before:
~~~
echo "== writer-scope-gate: lead-programmer, scribe and spec-master cannot stop with an out-of-scope change (Bash, st-u3) =="
if bash tests/writer-scope-gate.test.sh > /dev/null; then
  echo "OK   tests/writer-scope-gate.test.sh"
else
  echo "FAIL tests/writer-scope-gate.test.sh"
  fail=1
fi
~~~
   after:
~~~
echo "== writer-scope-gate: lead-programmer, scribe and spec-master cannot stop with an out-of-scope change (Bash, st-u3) =="
if bash tests/writer-scope-gate.test.sh > /dev/null; then
  echo "OK   tests/writer-scope-gate.test.sh"
else
  echo "FAIL tests/writer-scope-gate.test.sh"
  fail=1
fi

echo
echo "== unit-size: lane from the planned scope, downgrade-only, fails closed to full (Bash, st-u4) =="
if bash tests/unit-size.test.sh > /dev/null; then
  echo "OK   tests/unit-size.test.sh"
else
  echo "FAIL tests/unit-size.test.sh"
  fail=1
fi
~~~
10. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.197 to 0.31.198).
11. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Lane routing (st-u4, VERSION).** New `bin/unit-size.sh`, installed to `.claude/bin/`, picks small, medium or full from a unit's planned `## Affected files` before dispatch: a sensitive path, a FAIL record, more than 10 files or anything unmeasurable is full; 4 files or fewer is small. agents/orchestrator.md "Lane routing": small skips spec-master and the explorer, medium skips spec-master (the orchestrator writes the scope and at most 5 steps; operator ruling OQ2), full is the default pipeline; downgrade-only, and a missing script means full. Every unit still gets its reviewer. New test tests/unit-size.test.sh.
~~~
   Replace `VERSION` with the version that edit 10 wrote.
12. command: `node bin/cli.js --update`
   expect: 0
13. command: `bash tests/unit-size.test.sh`
   expect: 0
14. command: `git add tests/unit-size.test.sh bin/unit-size.sh .claude/bin/unit-size.sh && git add -u && git commit -m "feat(st-u4): lane routing from the planned scope, downgrade-only and fail-closed to full"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `hooks/` and `.claude/hooks/`, including `hooks/scripts/reviewer-tier.sh` (it still measures the actual diff; criterion 5)
- `hooks/scripts/lib/sensitive-paths.sh` and `hooks/scripts/lib/unit-scope.sh` (st-u1's; this unit only sources them)
- `adapters/` (the codex and cursor orchestrator ports install no `.claude/bin/` and keep today's pipeline; criterion 5)
- `agents/lead-programmer.md`, `agents/reviewer.md`, `agents/spec-master.md` and `templates/` (the small-lane `Pre-resolved context` line is dispatch text; criterion 5)
- `.claude/agents/` and `.claude/bin/` by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'bash tests/unit-size.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: change `-gt 10` to `-gt 11` in the script; case (c) prints `FAIL (c) eleven is full` and stdout is `1`.
2. run: `cmp bin/unit-size.sh .claude/bin/unit-size.sh`
   exit: 0
   stdout: empty
   mutation: revert edit 4; `--update` installs nothing, cmp reports the missing file and exits 2.
3. run: `bash -c 'bash tests/bin-helpers-scaffold.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: revert edit 4; the scaffold has no `.claude/bin/unit-size.sh`, case (a) fails and stdout is `1`.
4. run: `bash -c 'bash .claude/bin/unit-size.sh st-u4 --contract docs/plans/antislop-structural/contracts/st-u4.md | grep -cE "^lane: full files=[0-9]+ reason=sensitive$"'`
   exit: 0
   stdout: `1`
   mutation: delete the sensitive-path loop from the script; it prints `lane: medium files=10 reason=contract` (spec-master ran this mutation), stdout is `0` and the exit is 1.
5. run: `bash -c 'b=$(git log --format=%H --grep="(st-u4)" | tail -1); git diff --name-only "$b^..HEAD" -- adapters hooks templates agents/lead-programmer.md agents/reviewer.md agents/spec-master.md | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `adapters/cursor/agents/orchestrator.md` in an st-u4 commit; stdout is at least `1`.
6. run: `bash -c 'node tests/adapter-protocol-parity.test.js >/dev/null && node tests/protocol-cross-references.test.js >/dev/null && bash tests/persona-prose-pins.test.sh >/dev/null && node tests/writer-tier-consistency.test.js >/dev/null && node tests/cli-backfill.test.js >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: in edit 8, also reword the pinned phrase `the contract of record, never a fix contract` elsewhere in orchestrator.md; writer-tier-consistency fails and stdout is `1`.
7. run: `bash -c 'b=$(git log --format=%H --grep="(st-u4)" | tail -1); bash hooks/scripts/version-stamp-check.sh "$b^..HEAD" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 10; stdout reads `version-stamp-check: violation touched: yes`.
8. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/unit-size.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes the test (edit 1) fails first (edit 2). spec-master applied edits 1 to 8 to a clone at eb59e217 with st-u1 to st-u3 applied: 19 script checks pass, the (k) prose rows fail before edits 6 to 8 and pass after `--update`; `cmp` is clean; scaffold, parity, cross-reference, prose-pin, writer-tier, cli-backfill, unit-scope-prose, knowledge-writes and unit-bookkeeping suites stay green. On that clone the installed script prints `lane: full files=11 reason=sensitive` for the qw-u5 contract. validate.sh was not run by spec-master.
blast-radius: agents/orchestrator.md:14 (routing-table planning line), agents/orchestrator.md:80 (`## Delegation contract`; the new section goes directly above it), agents/orchestrator.md:115 (pre-explorer sentence), bin/cli.js:656 (BIN_HELPER_FILES), tests/bin-helpers-scaffold.test.sh:15 and :22. Line numbers are at 4f8a545a, before qw-u2 to qw-u6 (none of whose payloads touch these three spans, checked by grep); work from the anchors.
lane-rules: entries are the contract's `## Affected files` tokens (st-u1 `us_entries`) or the `--` arguments; `.claude/` and `docs/plans/` entries are dropped. Check order: no input, empty, unmeasurable (glob, trailing slash, existing directory), sensitive, fail-record, size over 10, small at 4 or fewer, medium. The small and medium reason word is the input kind (`contract` or `paths`).
downgrade-only: the script never weakens anything that runs after the code exists; reviewer-tier.sh still measures the actual diff and the precheck still checks scope. The lane only decides spec-master, task-master and the pre-explorer.
operator-ruling: OQ2 = (ii), 2026-10-20: no spec-master in the medium lane; the orchestrator writes the scope and at most 5 steps itself.
version: .claude-plugin/plugin.json and package.json read 0.31.197 after st-u3 if no fix round bumped; edit 10 adds one (expected 0.31.198).
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2). The orchestrator mirror grows about 1.9k bytes (offsetting part of qw-u2 and qw-u4's diet); the lane section is what saves spec-master and explorer dispatches.
commit-message: feat(st-u4): lane routing from the planned scope, downgrade-only and fail-closed to full
diagnosis: none
review-packet:
~~~
unit: st-u4
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
If a `before:` payload is not found verbatim (qw-u2 to qw-u6 or a fix round may have rewrapped a line), stop and
report the current text; do not improvise. If `node bin/cli.js --update` refuses, quote it and stop. If a gate
blocks a command, report it and wait. Anything outside "Affected files" goes to your report as a proposal.
