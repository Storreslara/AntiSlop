Unit: qw-u1

## Objective
The orchestrator's per-unit bookkeeping becomes one script call per phase. A new `bin/unit-bookkeeping.sh`,
installed to `.claude/bin/` like aof-u1's helpers, has two subcommands:
- `dispatch <unit> [--contract <path>]` runs `ladder-tier.sh`, prints its line and a `model:` line, appends the
  guard-demotion, no-contract and helper-missing RULING lines, and records the implementer tier;
- `review <unit> <baseline>` runs `reviewer-tier.sh`, writes the reviewer dispatch header
  `.claude/bookkeeping/<unit>.header` and prints it.

No gate, hook or marker changes. The downgrade-only and sensitive-path rules stay in `reviewer-tier.sh`; the
wrapper can only keep its word or turn it into `opus`. This is spec Step 1 (c2-B).

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-quick-wins/spec.md`, "Step 1 (qw-u1)" and "Context,
c2". This file is the contract of record. Dispatch it only after aof-u4 has reached PASS.

## Affected files
- `tests/unit-bookkeeping.test.sh` (anchor: new file)
- `bin/unit-bookkeeping.sh` (anchor: new file, mode 755)
- `bin/cli.js` (anchors: line matching `const BIN_HELPER_FILES = [`; line matching `'{DOTDIR}/microworld-audit.log',`)
- `tests/bin-helpers-scaffold.test.sh` (anchor: line matching `FILES="ladder-tier.sh`)
- `agents/orchestrator.md` ("Per-unit model routing", "Contract-score guard", "Reviewer gate model selection", "Rulings ledger")
- `tests/validate.sh` (anchor: line matching `echo "== bin-helpers-scaffold: ladder helpers installed to .claude/bin (Bash, aof-u1) =="`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/bin/unit-bookkeeping.sh`, `.claude/agents/orchestrator.md`,
  `.gitignore` (gains `.claude/bookkeeping/`), `.claude/persona-config.json` (`fileHashes`, `pluginVersion`)

## Ordered edits
1. file: `tests/unit-bookkeeping.test.sh`
   anchor: new file (mode 755)
   indent: 0
   insert-after:
~~~
#!/usr/bin/env bash
# unit-bookkeeping.sh (qw-u1): one call per phase runs the tier helper, appends the mechanical RULING
# lines and writes the reviewer dispatch header. Helpers are stubbed through UB_* and all state goes
# to a temp CLAUDE_PROJECT_DIR, so the real .claude/ is never touched.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UB="$ROOT/bin/unit-bookkeeping.sh"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/stub" "$T/repo"
stub() { printf '#!/usr/bin/env bash\necho "%s"\n' "$2" > "$T/stub/$1"; }
cd "$T/repo" || exit 1
g() { git -c user.email=t@t -c user.name=t "$@"; }
git init -q . && g commit -q --allow-empty -m base
BASE="$(git rev-parse HEAD)"
printf 'x\n' > a.txt && git add a.txt && g commit -q -m 'feat(u1): a'
export CLAUDE_PROJECT_DIR="$T/repo"
LOG="$T/repo/.claude/orchestrator-rulings.log"
HDR="$T/repo/.claude/bookkeeping"
lines() { if [ -f "$LOG" ]; then wc -l < "$LOG" | tr -d ' '; else echo 0; fi; }
TS='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'

stub ladder 'ladder-tier: sonnet n=0 ladder=haiku,sonnet,opus reason=guard-demotion'
stub guard 'contract-guard: sonnet score=5/7'
out="$(UB_LADDER="$T/stub/ladder" UB_GUARD="$T/stub/guard" bash "$UB" dispatch u1 --contract c.md)"
[ "$(printf '%s\n' "$out" | head -n1)" = 'ladder-tier: sonnet n=0 ladder=haiku,sonnet,opus reason=guard-demotion' ] && ok "(a) ladder line first" || bad "(a) ladder line first: $out"
printf '%s\n' "$out" | grep -qx 'model: sonnet' && ok "(a) model line" || bad "(a) model line"
printf '%s\n' "$out" | grep -qx 'guard: contract-guard: sonnet score=5/7' && ok "(a) guard line" || bad "(a) guard line"
grep -qE "^RULING $TS unit=u1 decision=contract-guard sonnet: contract-guard: sonnet score=5/7\$" "$LOG" && ok "(a) ruling" || bad "(a) ruling"
[ "$(cat "$HDR/u1.tier" 2>/dev/null)" = sonnet ] && ok "(a) tier recorded" || bad "(a) tier recorded"

stub ladder 'ladder-tier: sonnet n=0 ladder=haiku,sonnet,opus reason=no-contract'
UB_LADDER="$T/stub/ladder" bash "$UB" dispatch u2 >/dev/null
tail -n1 "$LOG" | grep -qE "^RULING $TS unit=u2 decision=contract-guard sonnet: no-contract\$" && ok "(b) no-contract ruling" || bad "(b) no-contract ruling"

n="$(lines)"; stub ladder 'ladder-tier: haiku n=0 ladder=haiku,sonnet,opus reason=default'
UB_LADDER="$T/stub/ladder" bash "$UB" dispatch u3 | grep -qx 'model: haiku' && ok "(c) model haiku" || bad "(c) model haiku"
[ "$(lines)" = "$n" ] && ok "(c) no ruling on reason=default" || bad "(c) ruling written on reason=default"

stub ladder 'nonsense'
UB_LADDER="$T/stub/ladder" bash "$UB" dispatch u4 | grep -qx 'model: opus' && ok "(d) unparseable -> opus" || bad "(d) unparseable -> opus"

UB_LADDER="$T/stub/absent" bash "$UB" dispatch u5 | grep -qx 'model: opus' && ok "(e) missing -> opus" || bad "(e) missing -> opus"
tail -n1 "$LOG" | grep -qF "unit=u5 decision=helper missing: $T/stub/absent: opus" && ok "(e) helper-missing ruling" || bad "(e) helper-missing ruling"

stub ladder 'ladder-tier: EXHAUSTED n=6 ladder=haiku,sonnet,opus reason=default'
UB_LADDER="$T/stub/ladder" bash "$UB" dispatch u6 | grep -qx 'model: EXHAUSTED' && ok "(f) exhausted" || bad "(f) exhausted"
[ ! -e "$HDR/u6.tier" ] && ok "(f) no tier recorded" || bad "(f) tier recorded on EXHAUSTED"

stub rtier 'sonnet'
UB_REVIEWER_TIER="$T/stub/rtier" bash "$UB" review u1 "$BASE" > "$T/out.txt"
H="$HDR/u1.header"
[ "$(sed -n 1p "$H")" = 'Unit: u1' ] && [ "$(sed -n 2p "$H")" = 'Implementer tier: sonnet' ] && ok "(g) Unit and Implementer tier lines" || bad "(g) first two lines"
grep -qx "Range: $BASE..$(git rev-parse HEAD)" "$H" && ok "(g) range" || bad "(g) range"
grep -qx 'Reviewer model: sonnet' "$H" && ok "(g) reviewer model" || bad "(g) reviewer model"
grep -qx -- '- a.txt' "$H" && ok "(g) changed files" || bad "(g) changed files"
cmp -s "$H" "$T/out.txt" && ok "(g) stdout equals header" || bad "(g) stdout differs from header"

stub rtier 'fable'
UB_REVIEWER_TIER="$T/stub/rtier" bash "$UB" review u1 "$BASE" | grep -qx 'Reviewer model: opus' && ok "(h) other word -> opus" || bad "(h) other word -> opus"
UB_REVIEWER_TIER="$T/stub/rtier" bash "$UB" review u7 "$BASE" | grep -q '^Implementer tier:' && bad "(h) unknown tier line printed" || ok "(h) no Implementer tier line when unknown"

bash "$UB" dispatch '../x' >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && [ ! -e "$T/repo/.claude/x.tier" ] && ok "(i) bad unit id rejected" || bad "(i) bad unit id: rc=$rc"
bash "$UB" review u1 'not-a-ref' >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok "(i) bad baseline rejected" || bad "(i) bad baseline: rc=$rc"

exit "$fail"
~~~
2. command: `bash tests/unit-bookkeeping.test.sh`
   expect: 1
   This is the red step: the script does not exist yet.
3. file: `bin/unit-bookkeeping.sh`
   anchor: new file (mode 755)
   indent: 0
   insert-after:
~~~
#!/usr/bin/env bash
# unit-bookkeeping.sh (qw-u1): the orchestrator's per-unit bookkeeping in one call per phase.
# dispatch <unit> [--contract <path>]: ladder-tier.sh plus the mechanical RULING lines.
# review <unit> <baseline>: reviewer-tier.sh plus the reviewer dispatch header. Never deletes anything.
~~~
   Below that header, write the body so that it meets every `script-spec-N:` row under Pre-resolved context.
4. command: `bash tests/unit-bookkeeping.test.sh`
   expect: 0
5. file: `bin/cli.js`
   anchor: line matching `const BIN_HELPER_FILES = [`
   before: `const BIN_HELPER_FILES = ['ladder-tier.sh', 'contract-guard.js', 'contract-score.js', 'fail-count.sh', 'escalation-card.sh'];`
   after: `const BIN_HELPER_FILES = ['ladder-tier.sh', 'contract-guard.js', 'contract-score.js', 'fail-count.sh', 'escalation-card.sh', 'unit-bookkeeping.sh'];`
6. file: `bin/cli.js`
   anchor: line matching `'{DOTDIR}/microworld-audit.log',`
   indent: 0
   insert-after:
~~~
  '{DOTDIR}/bookkeeping/',
~~~
7. file: `tests/bin-helpers-scaffold.test.sh`
   anchor: line matching `FILES="ladder-tier.sh`
   before: `FILES="ladder-tier.sh contract-guard.js contract-score.js fail-count.sh escalation-card.sh"`
   after: `FILES="ladder-tier.sh contract-guard.js contract-score.js fail-count.sh escalation-card.sh unit-bookkeeping.sh"`
   In the same file, change both occurrences of `(a) five helpers present` to `(a) six helpers present`.
8. file: `agents/orchestrator.md`
   anchor: line matching `## Per-unit model routing`
   indent: 0
   before:
~~~
Before every per-unit `lead-programmer` dispatch, run `bash .claude/bin/ladder-tier.sh
<task-id> --contract <contract file>` (the contract of record, never a fix
contract: a fix contract can score back onto `haiku`) and pass its tier as the
dispatch's `model` parameter.
~~~
   after:
~~~
Before every per-unit `lead-programmer` dispatch, run `bash .claude/bin/unit-bookkeeping.sh dispatch
<task-id> --contract <contract file>` (the contract of record, never a fix
contract: a fix contract can score back onto `haiku`) and pass the tier on its `model:` line as the
dispatch's `model` parameter. That one call runs `.claude/bin/ladder-tier.sh`, prints its line first,
records the tier for the reviewer dispatch header, and appends the guard-demotion, no-contract and
helper-missing RULING lines itself. If `.claude/bin/unit-bookkeeping.sh` is missing, run
`.claude/bin/ladder-tier.sh` with the same arguments and append those RULING lines yourself.
~~~
9. file: `agents/orchestrator.md`
   anchor: line matching `**Contract-score guard.**` (the payload starts with the paragraph's word `On` at the end of its fourth line)
   indent: 0
   before:
~~~
On
`reason=guard-demotion`, rerun the guard for its line, tell the user in one line
quoting it, and append `RULING <UTC ISO-8601 timestamp> unit=<task-id>
decision=contract-guard sonnet: <guard line>` to `.claude/orchestrator-rulings.log`
(**Rulings ledger**); the script never writes. `reason=no-contract` is a guard
demotion too (CONTEXT.md **guard demotion**): tell the user in one line that the
unit had no contract, and append `RULING <UTC ISO-8601 timestamp>
unit=<task-id> decision=contract-guard sonnet: no-contract`.
~~~
   after:
~~~
On
`reason=guard-demotion`, `unit-bookkeeping.sh` prints the guard's first line as `guard: <guard line>` and
appends `RULING <UTC ISO-8601 timestamp> unit=<task-id>
decision=contract-guard sonnet: <guard line>` to `.claude/orchestrator-rulings.log`
(**Rulings ledger**); tell the user in one line quoting it. `ladder-tier.sh` itself never writes.
`reason=no-contract` is a guard demotion too (CONTEXT.md **guard demotion**): tell the user in one line
that the unit had no contract; the wrapper appends `RULING <UTC ISO-8601 timestamp>
unit=<task-id> decision=contract-guard sonnet: no-contract`.
~~~
10. file: `agents/orchestrator.md`
   anchor: line matching `### Reviewer gate model selection (measured at dispatch time)`
   indent: 0
   before:
~~~
You decide the tier at reviewer-dispatch time by running, **from
the repo root**:

```
bash .claude/hooks/scripts/reviewer-tier.sh <task-id> <baseline>..HEAD
```

It prints exactly `sonnet` or `opus` (exit 0 either way); if missing,
non-zero exit, or anything else printed, treat the result as `opus`. Pass
that word as the reviewer dispatch's `model` parameter.
~~~
   after:
~~~
You decide the tier at reviewer-dispatch time with one Bash call, **from
the repo root**:

```
bash .claude/bin/unit-bookkeeping.sh review <task-id> <baseline>
```

It runs `.claude/hooks/scripts/reviewer-tier.sh <task-id> <baseline>..HEAD`, which prints exactly `sonnet`
or `opus` (exit 0 either way); a missing script, a non-zero exit or any other word becomes `opus`. It then
writes the reviewer dispatch header, `.claude/bookkeeping/<task-id>.header`, and prints it: `Unit: <task-id>`,
`Implementer tier: <t>` (omitted when unknown), `Range:`, `Reviewer model: <sonnet|opus>` and the changed
files. Open the reviewer dispatch with its `Unit:` and `Implementer tier:` lines verbatim and pass the
`Reviewer model:` word as the reviewer dispatch's `model` parameter. If the wrapper is missing, run
`bash .claude/hooks/scripts/reviewer-tier.sh <task-id> <baseline>..HEAD` yourself and treat anything but
`sonnet` as `opus`.
~~~
11. file: `agents/orchestrator.md`
   anchor: line matching `RULING <UTC ISO-8601 timestamp> unit=<task-id|n/a> decision=<short summary>` (the only such line, in "Rulings ledger")
   indent: 0
   insert-after:
~~~


The mechanical lines (contract-guard demotion, no-contract, helper missing) are appended by
`.claude/bin/unit-bookkeeping.sh`; append by hand only the judgment calls it cannot make, such as a
downgrade-only reviewer-tier override.
~~~
12. file: `tests/validate.sh`
   anchor: line matching `echo "== bin-helpers-scaffold: ladder helpers installed to .claude/bin (Bash, aof-u1) =="`
   indent: 0
   before:
~~~
echo "== bin-helpers-scaffold: ladder helpers installed to .claude/bin (Bash, aof-u1) =="
if bash tests/bin-helpers-scaffold.test.sh; then
  echo "OK   tests/bin-helpers-scaffold.test.sh"
else
  echo "FAIL tests/bin-helpers-scaffold.test.sh"
  fail=1
fi
~~~
   after:
~~~
echo "== bin-helpers-scaffold: ladder helpers installed to .claude/bin (Bash, aof-u1) =="
if bash tests/bin-helpers-scaffold.test.sh; then
  echo "OK   tests/bin-helpers-scaffold.test.sh"
else
  echo "FAIL tests/bin-helpers-scaffold.test.sh"
  fail=1
fi

echo
echo "== unit-bookkeeping: one call per phase for tier, RULING lines and dispatch header (Bash, qw-u1) =="
if bash tests/unit-bookkeeping.test.sh > /dev/null; then
  echo "OK   tests/unit-bookkeeping.test.sh"
else
  echo "FAIL tests/unit-bookkeeping.test.sh"
  fail=1
fi
~~~
13. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.187 to 0.31.188).
14. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Bookkeeping wrapper (qw-u1, VERSION).** New `bin/unit-bookkeeping.sh`, installed to `.claude/bin/`: `dispatch` runs ladder-tier.sh and appends the guard-demotion, no-contract and helper-missing RULING lines; `review` runs reviewer-tier.sh and writes the reviewer dispatch header `.claude/bookkeeping/<unit>.header`. agents/orchestrator.md now makes one call per phase. No gate or hook changed; the downgrade-only and sensitive-path rules are unchanged. New test tests/unit-bookkeeping.test.sh.
~~~
   Replace `VERSION` with the version that edit 13 wrote.
15. command: `node bin/cli.js --update`
   expect: 0
16. command: `git add tests/unit-bookkeeping.test.sh bin/unit-bookkeeping.sh .claude/bin/unit-bookkeeping.sh && git add -u && git commit -m "feat(qw-u1): one bookkeeping call per phase for tier, RULING lines and reviewer dispatch header"`
   expect: 0
   `git add -u` stages the generated config without naming it (a Bash command naming that file can be refused by harness-integrity-gate.sh). Before this edit, run `git status --short`: if a tracked file outside "Affected files" is modified (for example another agent's memory note), stop and report it instead of committing it.

## Do NOT touch
- `hooks/` and `.claude/hooks/` (no gate, hook or registration change; `reviewer-tier.sh` stays as it is)
- `bin/ladder-tier.sh` (its never-writes contract stays; the wrapper does the writing)
- `adapters/` (the codex and cursor orchestrator ports do not name the tier scripts)
- `templates/persona-protocol.md` (no protocol text changes in this unit)
- `.claude/agents/orchestrator.md` and `.claude/bin/` by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'bash tests/unit-bookkeeping.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: delete the no-contract RULING append from the script; case (b) fails and stdout is `1`.
2. run: `bash -c 'bash tests/bin-helpers-scaffold.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: revert edit 5; the scaffold has no `.claude/bin/unit-bookkeeping.sh`, case (a) fails and stdout is `1`.
3. run: `cmp bin/unit-bookkeeping.sh .claude/bin/unit-bookkeeping.sh`
   exit: 0
   stdout: empty
   mutation: append a line to `.claude/bin/unit-bookkeeping.sh`; cmp reports the difference and exits 1.
4. run: `bash -c 'for f in agents/orchestrator.md .claude/agents/orchestrator.md; do t=$(tr -s " \n" " " < "$f"); for n in "bash .claude/bin/unit-bookkeeping.sh dispatch" "bash .claude/bin/unit-bookkeeping.sh review <task-id> <baseline>" ".claude/bookkeeping/<task-id>.header" "You may **never upgrade** it" "decision=contract-guard sonnet: no-contract" "the contract of record, never a fix contract"; do printf "%s" "$t" | grep -qF -- "$n" || { echo "missing in $f: $n"; exit 1; }; done; done'`
   exit: 0
   stdout: empty
   mutation: skip edit 10; it prints `missing in agents/orchestrator.md: bash .claude/bin/unit-bookkeeping.sh review <task-id> <baseline>` and exits 1. On the pre-unit file it prints `missing in agents/orchestrator.md: bash .claude/bin/unit-bookkeeping.sh dispatch` (spec-master ran it).
5. run: `bash -c 'b=$(git log --format=%H --grep="(qw-u1)" | tail -1); git diff --name-only "$b^..HEAD" -- hooks .claude/hooks adapters | wc -l'`
   exit: 0
   stdout: `0`
   mutation: change any file under `hooks/` in a qw-u1 commit; stdout is at least `1`.
6. run: `grep -cxF '.claude/bookkeeping/' .gitignore`
   exit: 0
   stdout: `1`
   mutation: revert edit 6; `--update` appends nothing, stdout is `0` and the exit is 1.
7. run: `bash -c 'b=$(git log --format=%H --grep="(qw-u1)" | tail -1); bash hooks/scripts/version-stamp-check.sh "$b^..HEAD" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip the version-bump edit; stdout reads `version-stamp-check: violation touched: yes`.
8. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/unit-bookkeeping.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes the test (edit 1) comes first and fails (edit 2); spec-master ran it against a scratch implementation, where all 22 checks pass, so it is satisfiable.
blast-radius: agents/orchestrator.md:461 (Per-unit model routing), agents/orchestrator.md:487 (Contract-score guard), agents/orchestrator.md:522 (Reviewer gate model selection), agents/orchestrator.md:141 (Rulings ledger format line), bin/cli.js:655 (BIN_HELPER_FILES), bin/cli.js:171 (gitignore list), tests/bin-helpers-scaffold.test.sh:15, tests/validate.sh:741. Line numbers are at bce2ded2; aof-u3 and aof-u4 shift them, so work from the anchors.
script-spec-1: usage `bash bin/unit-bookkeeping.sh dispatch <unit> [--contract <path>]` and `bash bin/unit-bookkeeping.sh review <unit> <baseline>`, run from the repo root. Any other subcommand prints a usage line to stderr and exits 2.
script-spec-2: the unit id must match `^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$` (the dispatch-hygiene grammar); otherwise print an error to stderr and exit 2 before writing anything.
script-spec-3: state lives under `${CLAUDE_PROJECT_DIR:-$PWD}/.claude`: the ledger `orchestrator-rulings.log` and the directory `bookkeeping/`; create them with `mkdir -p` when needed.
script-spec-4: helpers, where `dir` is the script's own directory. Ladder: `${UB_LADDER:-$dir/ladder-tier.sh}`, run with `bash`, arguments `<unit>` plus `--contract <path>` when given. Guard: when `UB_GUARD` is set `bash "$UB_GUARD" <contract> --unit=<unit>`, otherwise `node "$dir/contract-guard.js" <contract> --unit=<unit>`. Reviewer tier: `${UB_REVIEWER_TIER:-$dir/../hooks/scripts/reviewer-tier.sh}`, run with `bash`, arguments `<unit> <baseline>..HEAD`. The `UB_*` variables exist for the test only. The default paths resolve in both layouts: `bin/` beside `hooks/` in this repo, `.claude/bin/` beside `.claude/hooks/` in an installed project.
script-spec-5: dispatch. If the ladder file does not exist, print `model: opus`, append `RULING <ts> unit=<unit> decision=helper missing: <ladder path>: opus`, exit 0. Otherwise print the ladder's first stdout line verbatim, then `model: <tier>`, where tier is the line's second field when that is `haiku`, `sonnet`, `opus` or `EXHAUSTED`, and `opus` otherwise.
script-spec-6: dispatch, RULING lines. On `reason=guard-demotion`, run the guard, print `guard: <its first line>` and append `RULING <ts> unit=<unit> decision=contract-guard sonnet: <that line>`. On `reason=no-contract`, append `RULING <ts> unit=<unit> decision=contract-guard sonnet: no-contract`. Any other reason appends nothing. `<ts>` is `date -u +%Y-%m-%dT%H:%M:%SZ`.
script-spec-7: dispatch, tier record. Unless the tier is `EXHAUSTED`, write the tier word alone to `bookkeeping/<unit>.tier`, overwriting it.
script-spec-8: review. The baseline must resolve with `git rev-parse --verify -q "<baseline>^{commit}"`, else exit 2. The reviewer word is reviewer-tier's first stdout line when that is exactly `sonnet` or `opus`; anything else, including a missing script, is `opus`. This is the downgrade-only rule: the wrapper never produces `sonnet` unless reviewer-tier.sh printed it.
script-spec-9: review, header file `bookkeeping/<unit>.header`, lines in this order: `Unit: <unit>`; `Implementer tier: <t>`, only when `bookkeeping/<unit>.tier` holds `haiku`, `sonnet` or `opus`; `Range: <baseline>..<full sha of HEAD>`; `Reviewer model: <word>`; `Changed files:`; then one `- <path>` line per `git diff --name-only <baseline>..HEAD` entry. Print the file's content to stdout and exit 0.
script-spec-10: the script never deletes a file and never writes outside those two state paths.
version: .claude-plugin/plugin.json and package.json read 0.31.187 after aof-u4 if no fix round bumped; edit 13 adds one to whatever is there (expected 0.31.188).
mirrors: `.claude/` copies and `fileHashes` change only through `node bin/cli.js --update` (constitution P2). aof-u1 showed that `--update` installs a new `BIN_HELPER_FILES` entry and appends a new gitignore pattern.
prior-fail: aof-u1 FAILed once because a moved phrase was pinned by tests/writer-tier-consistency.test.js. Edits 8 to 11 keep every pinned phrase: `**Contract-score guard.**`, `node .claude/bin/contract-guard.js`, `contract-guard: haiku`, `**guard demotion**`, `decision=contract-guard sonnet:`, `--shape=scribe`, `provided it is unchanged`, `the contract of record, never a fix contract`, `decision=contract-guard sonnet: no-contract`, `except a human-chosen (a)/(b) re-dispatch`.
terminology: the header file is the **reviewer dispatch header**. Do not call it a review packet: docs/harness-glossary.md already uses **review-packet** for the contract key and **advisory review packet** for lead-programmer's report.
commit-message: feat(qw-u1): one bookkeeping call per phase for tier, RULING lines and reviewer dispatch header
diagnosis: none
review-packet:
~~~
unit: qw-u1
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
If a `before:` payload is not found verbatim (aof-u3 or aof-u4 may have rewrapped a line), stop and report
the current text; do not improvise a replacement. If `node bin/cli.js --update` reports a diverged mirror it
will not regenerate, quote its message and stop. If a gate blocks a command, report it and wait. Changes
outside "Affected files" go to your report as proposals.
