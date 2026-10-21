Unit: qw-u1

## Objective
Fix the three defects the reviewer found in eb59e217 (`bin/unit-bookkeeping.sh`, `agents/orchestrator.md`), version 0.31.189:
1. `review` forces `opus` when the reviewer-tier helper exits non-zero, even if it printed `sonnet`;
2. the reviewer dispatch header's `Implementer tier:` line comes from a new trailing `--implementer-tier <haiku|sonnet|opus>` argument that the orchestrator passes from the model it actually dispatched with (after any `Suggested model:` raise), and is omitted when the argument is absent or invalid;
3. `dispatch` stores no tier file at all, so a stale tier can never reach a header after a helper-missing or EXHAUSTED dispatch.
It also carries three reviewer follow-ups: a failed contract-guard prints `guard unavailable`, guard stderr is suppressed, and a ladder line whose first field is not `ladder-tier:` becomes `opus`.

## Retrieval
Fast path, no tracker issue. Original contract: `docs/plans/antislop-quick-wins/contracts/qw-u1.md` (contract of record; do not edit it). Spec: `docs/plans/antislop-quick-wins/spec.md`, "Step 1 (qw-u1)". The FAIL being fixed is the latest block of the qw-u1 FAIL record, header `FAIL qw-u1 2026-10-21T02:06:00Z`.

## Affected files
- `tests/unit-bookkeeping.test.sh` (anchors: line matching `(a) tier recorded`; line matching `(f) no tier recorded`; line matching `review u1 "$BASE" > "$T/out.txt"`; line matching `exit "$fail"`)
- `bin/unit-bookkeeping.sh` (anchors: line matching `# review <unit> <baseline>: reviewer-tier.sh plus the reviewer dispatch header. Never deletes anything.`; line matching `record_tier() {`; line matching `g="$(bash "$UB_GUARD"`; line matching `case "$tier" in haiku|sonnet|opus|EXHAUSTED) ;; *) tier=opus ;; esac`; line matching `review_header() {`; line matching `local unit="$2" base="$3" word rt=`)
- `agents/orchestrator.md` (anchors: line matching `records the tier for the reviewer dispatch header, and appends the guard-demotion, no-contract and`; line matching `bash .claude/bin/unit-bookkeeping.sh review <task-id> <baseline>`; line matching `files. Open the reviewer dispatch with its`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.188",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- generated only, by `node bin/cli.js --update`: `.claude/bin/unit-bookkeeping.sh`, `.claude/agents/orchestrator.md`, `.claude/agents/agent-auditor.md`, `.claude/agents/explorer.md`, `.claude/agents/lead-programmer.md`, `.claude/agents/milestone-auditor.md`, `.claude/agents/researcher.md`, `.claude/agents/reviewer.md`, `.claude/agents/scribe.md`, `.claude/agents/spec-master.md`, `.claude/agents/task-master.md`, `.claude/persona-config.json` (`fileHashes`, `pluginVersion`), `.claude/persona-protocol-slim.md`, `.claude/persona-protocol.md`, `.claude/protocol-digest.md` (version stamps)

## Ordered edits
1. file: `tests/unit-bookkeeping.test.sh`
   anchor: line matching `(a) tier recorded`
   indent: 0
   before:
~~~
[ "$(cat "$HDR/u1.tier" 2>/dev/null)" = sonnet ] && ok "(a) tier recorded" || bad "(a) tier recorded"
~~~
   after:
~~~
[ -z "$(ls "$HDR" 2>/dev/null | grep '\.tier$')" ] && ok "(a) no tier file written" || bad "(a) tier file written"
~~~
2. file: `tests/unit-bookkeeping.test.sh`
   anchor: line matching `(f) no tier recorded`
   indent: 0
   before:
~~~
[ ! -e "$HDR/u6.tier" ] && ok "(f) no tier recorded" || bad "(f) tier recorded on EXHAUSTED"
~~~
   after:
~~~
[ -z "$(ls "$HDR" 2>/dev/null | grep '\.tier$')" ] && ok "(f) no tier file after EXHAUSTED or helper-missing" || bad "(f) tier file written"
~~~
3. file: `tests/unit-bookkeeping.test.sh`
   anchor: line matching `review u1 "$BASE" > "$T/out.txt"`
   indent: 0
   before:
~~~
UB_REVIEWER_TIER="$T/stub/rtier" bash "$UB" review u1 "$BASE" > "$T/out.txt"
~~~
   after:
~~~
UB_REVIEWER_TIER="$T/stub/rtier" bash "$UB" review u1 "$BASE" --implementer-tier sonnet > "$T/out.txt"
~~~
4. file: `tests/unit-bookkeeping.test.sh`
   anchor: line matching `exit "$fail"`
   indent: 0
   before:
~~~
exit "$fail"
~~~
   after:
~~~
printf '#!/usr/bin/env bash\necho sonnet\nexit 1\n' > "$T/stub/rtierbad"
UB_REVIEWER_TIER="$T/stub/rtierbad" bash "$UB" review u1 "$BASE" | grep -qx 'Reviewer model: opus' && ok "(j) helper prints sonnet then exits 1 -> opus" || bad "(j) helper prints sonnet then exits 1 -> opus"
UB_REVIEWER_TIER="$T/stub/absent" bash "$UB" review u1 "$BASE" | grep -qx 'Reviewer model: opus' && ok "(j) missing helper -> opus" || bad "(j) missing helper -> opus"

stub ladder 'ladder-tier: haiku n=0 ladder=haiku,sonnet,opus reason=default'
UB_LADDER="$T/stub/ladder" bash "$UB" dispatch u8 >/dev/null
o="$(UB_REVIEWER_TIER="$T/stub/rtier" bash "$UB" review u8 "$BASE" --implementer-tier sonnet)"
[ "$(printf '%s\n' "$o" | sed -n 2p)" = 'Implementer tier: sonnet' ] && ok "(k) ladder haiku raised to sonnet: header says sonnet" || bad "(k) raised tier: $o"

UB_LADDER="$T/stub/ladder" bash "$UB" dispatch u9 >/dev/null
UB_LADDER="$T/stub/absent" bash "$UB" dispatch u9 >/dev/null
o="$(UB_REVIEWER_TIER="$T/stub/rtier" bash "$UB" review u9 "$BASE")"
printf '%s\n' "$o" | grep -qx 'Unit: u9' && ! printf '%s\n' "$o" | grep -q '^Implementer tier:' && ok "(l) no stale tier after ladder then helper-missing" || bad "(l) stale tier: $o"
o="$(UB_REVIEWER_TIER="$T/stub/rtier" bash "$UB" review u9 "$BASE" --implementer-tier fable)"
printf '%s\n' "$o" | grep -qx 'Unit: u9' && ! printf '%s\n' "$o" | grep -q '^Implementer tier:' && ok "(l) invalid tier omitted" || bad "(l) invalid tier: $o"
bash "$UB" review u9 "$BASE" --implementer-tier >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok "(l) flag without value rejected" || bad "(l) flag without value: rc=$rc"
bash "$UB" review u9 "$BASE" --bogus x >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok "(l) unknown flag rejected" || bad "(l) unknown flag: rc=$rc"

printf '#!/usr/bin/env bash\nexit 1\n' > "$T/stub/guardbad"
stub ladder 'ladder-tier: sonnet n=0 ladder=haiku,sonnet,opus reason=guard-demotion'
out="$(UB_LADDER="$T/stub/ladder" UB_GUARD="$T/stub/guardbad" bash "$UB" dispatch u10 --contract c.md)"
printf '%s\n' "$out" | grep -qx 'guard: guard unavailable' && ok "(m) failed guard prints a placeholder" || bad "(m) failed guard: $out"
tail -n1 "$LOG" | grep -qF 'unit=u10 decision=contract-guard sonnet: guard unavailable' && ok "(m) failed guard ruling has a placeholder" || bad "(m) failed guard ruling"

stub ladder 'other-tag: haiku n=0 ladder=haiku,sonnet,opus reason=default'
UB_LADDER="$T/stub/ladder" bash "$UB" dispatch u11 | grep -qx 'model: opus' && ok "(n) wrong first field -> opus" || bad "(n) wrong first field -> opus"

exit "$fail"
~~~
5. command: `bash tests/unit-bookkeeping.test.sh`
   expect: 1
   This is the red step: the test now asserts behavior the script does not have yet. `|| true` is not used; the exit is 1.
6. file: `bin/unit-bookkeeping.sh`
   anchor: line matching `# review <unit> <baseline>: reviewer-tier.sh plus the reviewer dispatch header. Never deletes anything.`
   indent: 0
   before:
~~~
# review <unit> <baseline>: reviewer-tier.sh plus the reviewer dispatch header. Never deletes anything.
~~~
   after:
~~~
# review <unit> <baseline> [--implementer-tier <t>]: reviewer-tier.sh plus the reviewer dispatch header.
# The header names the implementer tier only from that flag; no tier is stored. Never deletes anything.
~~~
7. file: `bin/unit-bookkeeping.sh`
   anchor: line matching `record_tier() {`
   indent: 0
   before:
~~~
record_tier() {
  if [ "$2" != EXHAUSTED ]; then mkdir -p "$bk"; printf '%s\n' "$2" > "$bk/$1.tier"; fi
}

guard_demote() {
~~~
   after:
~~~
guard_demote() {
~~~
8. file: `bin/unit-bookkeeping.sh`
   anchor: line matching `g="$(bash "$UB_GUARD"`
   indent: 0
   before:
~~~
guard_demote() {
  local g
  if [ -n "${UB_GUARD:-}" ]; then
    g="$(bash "$UB_GUARD" "$1" --unit="$2" | head -n1)"
  else
    g="$(node "$dir/contract-guard.js" "$1" --unit="$2" | head -n1)"
  fi
  echo "guard: $g"
~~~
   after:
~~~
guard_demote() {
  local g
  if [ -n "${UB_GUARD:-}" ]; then
    g="$(bash "$UB_GUARD" "$1" --unit="$2" 2>/dev/null | head -n1)"
  else
    g="$(node "$dir/contract-guard.js" "$1" --unit="$2" 2>/dev/null | head -n1)"
  fi
  if [ -z "$g" ]; then g="guard unavailable"; fi
  echo "guard: $g"
~~~
9. file: `bin/unit-bookkeeping.sh`
   anchor: line matching `case "$tier" in haiku|sonnet|opus|EXHAUSTED) ;; *) tier=opus ;; esac`
   indent: 0
   before:
~~~
  case "$tier" in haiku|sonnet|opus|EXHAUSTED) ;; *) tier=opus ;; esac
  if [ -n "$line" ]; then echo "$line"; fi
  echo "model: $tier"
  record_tier "$unit" "$tier"
  case " $line " in
    *" reason=guard-demotion "*) guard_demote "$contract" "$unit" ;;
    *" reason=no-contract "*) ruling "$unit" "contract-guard sonnet: no-contract" ;;
  esac
}
~~~
   after:
~~~
  if [ "${f[0]:-}" != ladder-tier: ]; then tier=opus; fi
  case "$tier" in haiku|sonnet|opus|EXHAUSTED) ;; *) tier=opus ;; esac
  if [ -n "$line" ]; then echo "$line"; fi
  echo "model: $tier"
  case " $line " in
    *" reason=guard-demotion "*) guard_demote "$contract" "$unit" ;;
    *" reason=no-contract "*) ruling "$unit" "contract-guard sonnet: no-contract" ;;
  esac
}
~~~
10. file: `bin/unit-bookkeeping.sh`
   anchor: line matching `review_header() {`
   indent: 0
   before:
~~~
review_header() {
  local unit="$1" base="$2" word="$3" tier=""
  if [ -f "$bk/$unit.tier" ]; then tier="$(cat "$bk/$unit.tier")"; fi
  echo "Unit: $unit"
~~~
   after:
~~~
review_header() {
  local unit="$1" base="$2" word="$3" tier="$4"
  echo "Unit: $unit"
~~~
11. file: `bin/unit-bookkeeping.sh`
   anchor: line matching `local unit="$2" base="$3" word rt=`
   indent: 0
   before:
~~~
review_cmd() {
  local unit="$2" base="$3" word rt="${UB_REVIEWER_TIER:-$dir/../hooks/scripts/reviewer-tier.sh}"
  [ "$#" -eq 3 ] || usage
  check_unit "$unit"
  if ! git rev-parse --verify -q "$base^{commit}" >/dev/null; then
    echo "unit-bookkeeping: bad baseline: $base" >&2; exit 2
  fi
  word="$(bash "$rt" "$unit" "$base..HEAD" 2>/dev/null | head -n1)"
  case "$word" in sonnet|opus) ;; *) word=opus ;; esac
  mkdir -p "$bk"
  review_header "$unit" "$base" "$word" > "$bk/$unit.header"
~~~
   after:
~~~
review_cmd() {
  local unit="$2" base="$3" word rc itier="" rt="${UB_REVIEWER_TIER:-$dir/../hooks/scripts/reviewer-tier.sh}"
  case "$#" in
    3) ;;
    5) if [ "$4" = --implementer-tier ]; then itier="$5"; else usage; fi ;;
    *) usage ;;
  esac
  check_unit "$unit"
  if ! git rev-parse --verify -q "$base^{commit}" >/dev/null; then
    echo "unit-bookkeeping: bad baseline: $base" >&2; exit 2
  fi
  word="$(bash "$rt" "$unit" "$base..HEAD" 2>/dev/null)"; rc=$?
  word="$(printf '%s\n' "$word" | head -n1)"
  if [ "$rc" -ne 0 ]; then word=opus; fi
  case "$word" in sonnet|opus) ;; *) word=opus ;; esac
  mkdir -p "$bk"
  review_header "$unit" "$base" "$word" "$itier" > "$bk/$unit.header"
~~~
12. command: `bash tests/unit-bookkeeping.test.sh`
   expect: 0
   Green: all 32 checks print `OK`.
13. file: `agents/orchestrator.md`
   anchor: line matching `records the tier for the reviewer dispatch header, and appends the guard-demotion, no-contract and`
   indent: 0
   before:
~~~
records the tier for the reviewer dispatch header, and appends the guard-demotion, no-contract and
helper-missing RULING lines itself. If `.claude/bin/unit-bookkeeping.sh` is missing, run
~~~
   after:
~~~
and appends the guard-demotion, no-contract and helper-missing RULING lines itself; it records no tier,
so keep the `model` you finally dispatch with for the review call's `--implementer-tier`. If
`.claude/bin/unit-bookkeeping.sh` is missing, run
~~~
14. file: `agents/orchestrator.md`
   anchor: line matching `bash .claude/bin/unit-bookkeeping.sh review <task-id> <baseline>`
   indent: 0
   before:
~~~
bash .claude/bin/unit-bookkeeping.sh review <task-id> <baseline>
~~~
   after:
~~~
bash .claude/bin/unit-bookkeeping.sh review <task-id> <baseline> [--implementer-tier <t>]
~~~
15. file: `agents/orchestrator.md`
   anchor: line matching `files. Open the reviewer dispatch with its`
   indent: 0
   before:
~~~
`Implementer tier: <t>` (omitted when unknown), `Range:`, `Reviewer model: <sonnet|opus>` and the changed
files. Open the reviewer dispatch with its `Unit:` and `Implementer tier:` lines verbatim and pass the
`Reviewer model:` word as the reviewer dispatch's `model` parameter. If the wrapper is missing, run
~~~
   after:
~~~
`Implementer tier: <t>` (omitted when you pass no flag or an invalid tier), `Range:`,
`Reviewer model: <sonnet|opus>` and the changed files. Pass `--implementer-tier <t>`, where `<t>` is the
tier (`haiku`, `sonnet` or `opus`) of the `model` the unit's latest implementer dispatch actually ran on,
after any `Suggested model:` raise; omit the flag when that dispatch passed no `model`. The tier line comes
from that flag alone, never from a stored value, so it cannot be stale. Open the reviewer dispatch with the
header's `Unit:` line and, unless the dispatch is advisory, its `Implementer tier:` line verbatim (an
advisory dispatch puts `Mode: advisory` second and the tier line third, per **Review routing**), and pass the
`Reviewer model:` word as the reviewer dispatch's `model` parameter. If the wrapper is missing, run
~~~
16. file: `.claude-plugin/plugin.json`
   anchor: line matching `"version": "0.31.188",`
   before: `"version": "0.31.188",`
   after: `"version": "0.31.189",`
   This is edit 14 of the version bump: 0.31.188 to 0.31.189 (HEAD reads 0.31.188 after eb59e217; stop if it does not).
17. file: `package.json`
   anchor: line matching `"version": "0.31.188",`
   before: `"version": "0.31.188",`
   after: `"version": "0.31.189",`
18. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~


**Bookkeeping wrapper takes the dispatched tier from the caller (qw-u1, 0.31.189).** `bin/unit-bookkeeping.sh`: `review` accepts a trailing `--implementer-tier <haiku|sonnet|opus>` and the reviewer dispatch header's `Implementer tier:` line comes from it alone (omitted when absent or invalid); `dispatch` no longer stores a tier file, so a stale tier cannot reach a header after a helper-missing or EXHAUSTED dispatch. A reviewer-tier helper that exits non-zero now forces `opus` even when it printed `sonnet`. A failed contract-guard prints `guard unavailable` instead of an empty line, and a ladder line whose first field is not `ladder-tier:` becomes `opus`. `agents/orchestrator.md` (Per-unit model routing, Reviewer gate model selection) tells the orchestrator to pass the model it actually dispatched with. Test tests/unit-bookkeeping.test.sh gains checks (j) to (n).
~~~
19. command: `node bin/cli.js --update`
   expect: 0
20. command: `git add tests/unit-bookkeeping.test.sh bin/unit-bookkeeping.sh .claude/bin/unit-bookkeeping.sh agents/orchestrator.md CHANGELOG.md package.json .claude-plugin/plugin.json && git add -u -- .claude && git commit -m "fix(qw-u1): reviewer header takes the dispatched implementer tier; helper non-zero exit forces opus"`
   expect: 0
   Stage by path only, never `git add -A`: spec-master is writing untracked docs under docs/plans/antislop-structural/. `git add -u -- .claude` stages the 15 paths `--update` regenerates (list in Affected files) without naming `persona-config.json` (a Bash command naming it can be refused by harness-integrity-gate.sh). Before this edit run `git status --porcelain --untracked-files=no`: if a tracked file outside Affected files is modified (for example an agent-memory note), stop and report it instead of committing it.

## Do NOT touch
- `hooks/` and `.claude/hooks/` (no gate, hook or registration change; `reviewer-tier.sh` stays as it is)
- `bin/ladder-tier.sh`, `bin/cli.js`, `tests/validate.sh`, `tests/bin-helpers-scaffold.test.sh` (nothing in them changes; the helper list and gitignore entry from eb59e217 stay)
- `docs/plans/antislop-quick-wins/contracts/qw-u1.md` (the contract of record is not edited; this file amends script-spec-5a, 7, 8 and 9 below)
- `docs/plans/antislop-structural/` (spec-master is writing there; stage by path, never `git add -A`)
- `.claude/agents/orchestrator.md` and `.claude/bin/` by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'bash tests/unit-bookkeeping.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edits 10 and 11 (header and review_cmd); checks (k) and (l) fail and stdout is `1`.
   proof: replaying the finished change in a scratch copy with only those two edits skipped printed `1`.
2. run: `bash -c 'bash tests/unit-bookkeeping.test.sh | grep -c "^OK"'`
   exit: 0
   stdout: `32`
   mutation: skip edit 4 (the new checks (j) to (n)); stdout is `22`.
3. run: `bash -c 'bash tests/unit-bookkeeping.test.sh | grep -c "^OK   (j) "'`
   exit: 0
   stdout: `2`
   mutation: delete the line `if [ "$rc" -ne 0 ]; then word=opus; fi` from `bin/unit-bookkeeping.sh`; the check for the stub that prints sonnet and exits 1 fails and stdout is `1`.
   proof: `sed -i '/if \[ "\$rc" -ne 0 \]; then word=opus; fi/d' bin/unit-bookkeeping.sh` in a scratch copy, then this run, printed `1`.
4. run: `bash -c 'd=$(mktemp -d); printf "#!/usr/bin/env bash\necho sonnet\nexit 1\n" > "$d/rt"; CLAUDE_PROJECT_DIR="$d" UB_REVIEWER_TIER="$d/rt" bash bin/unit-bookkeeping.sh review u1 HEAD~1 | grep -x "Reviewer model: .*"; rc=$?; rm -rf "$d"; exit $rc'`
   exit: 0
   stdout: `Reviewer model: opus`
   mutation: delete the `rc` line as in criterion 3; stdout is `Reviewer model: sonnet`.
   proof: the sed command of criterion 3 in a scratch copy, then this run from the scratch root.
5. run: `bash -c 'bash tests/unit-bookkeeping.test.sh | grep -c "^OK   (k) "'`
   exit: 0
   stdout: `1`
   mutation: skip edits 10 and 11; the header ignores the flag and stdout is `0`. Check (k) dispatches with a haiku ladder, then reviews with `--implementer-tier sonnet` and requires `Implementer tier: sonnet` on line 2.
6. run: `bash -c 'bash tests/unit-bookkeeping.test.sh | grep -c "^OK   (l) "'`
   exit: 0
   stdout: `4`
   mutation: skip edits 6 to 11 (the whole script back to eb59e217); the stale tier line and the flag checks fail and stdout is `2`.
7. run: `bash -c 'bash tests/unit-bookkeeping.test.sh | grep -c "^OK   ([af]) "'`
   exit: 0
   stdout: `7`
   mutation: skip edits 6 to 11; `dispatch` writes `<unit>.tier` again, checks (a) and (f) fail and stdout is `5`.
8. run: `bash -c 'bash tests/unit-bookkeeping.test.sh | grep -c "^OK   ([mn]) "'`
   exit: 0
   stdout: `3`
   mutation: skip edit 8 (guard placeholder); check (m) fails twice and stdout is `1`.
9. run: `bash -c 'for f in agents/orchestrator.md .claude/agents/orchestrator.md; do t=$(tr -s " \n" " " < "$f"); for n in "bash .claude/bin/unit-bookkeeping.sh dispatch" "bash .claude/bin/unit-bookkeeping.sh review <task-id> <baseline> [--implementer-tier <t>]" ".claude/bookkeeping/<task-id>.header" "it records no tier, so keep the" "actually ran on, after any" "so it cannot be stale" "the contract of record, never a fix contract"; do printf "%s" "$t" | grep -qF -- "$n" || { echo "missing in $f: $n"; exit 1; }; done; case "$t" in *"records the tier for the reviewer dispatch header"*) echo "stale phrase in $f"; exit 1;; esac; done'`
   exit: 0
   stdout: empty
   mutation: skip edit 14; it prints `missing in agents/orchestrator.md: bash .claude/bin/unit-bookkeeping.sh review <task-id> <baseline> [--implementer-tier <t>]` and exits 1. Skip edit 13 instead: it prints `missing in agents/orchestrator.md: it records no tier, so keep the`. On the pre-fix file the stale-phrase guard would print `stale phrase in agents/orchestrator.md` once the new phrases exist.
10. run: `cmp bin/unit-bookkeeping.sh .claude/bin/unit-bookkeeping.sh`
    exit: 0
    stdout: empty
    mutation: skip the `node bin/cli.js --update` item (19); the mirror keeps the old script and cmp exits 1 with a difference report.
11. run: `node -p "require('./.claude-plugin/plugin.json').version"`
    exit: 0
    stdout: `0.31.189`
    mutation: skip edit 16; stdout is `0.31.188`.
12. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;process.exit(a===b?0:1)" && echo version-sync: ok`
    exit: 0
    stdout: `version-sync: ok`
    mutation: skip edit 17; nothing prints and the exit is 1.
13. run: `bash -c 'bash hooks/scripts/version-stamp-check.sh HEAD~1..HEAD | cut -d" " -f1-4'`
    exit: 0
    stdout: `version-stamp-check: ok touched: yes`
    mutation: skip edits 16 to 18; stdout reads `version-stamp-check: violation touched: yes`.
14. run: `bash -c 'git diff --name-only HEAD~1..HEAD -- hooks .claude/hooks adapters | wc -l'`
    exit: 0
    stdout: `0`
    mutation: change any file under `hooks/` in the commit; stdout is at least `1`.
15. run: `bash -c 'git status --porcelain --untracked-files=no -- bin tests agents CHANGELOG.md package.json .claude-plugin .claude | wc -l'`
    exit: 0
    stdout: `0`
    mutation: leave one `--update` path unstaged (skip `git add -u -- .claude`); stdout is at least `1`.
16. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
    exit: 0
    stdout: `0`
    mutation: put `exit 1` as line 2 of tests/unit-bookkeeping.test.sh; validate.sh exits 1 and stdout is `1`.
17. run: `bash -c 'git log -1 --format=%s | grep -c "^fix(qw-u1): "'`
    exit: 0
    stdout: `1`
    mutation: commit with a subject lacking the `fix(qw-u1): ` prefix; stdout is `0` and the exit is 1.

## Pre-resolved context
tdd: yes tests/unit-bookkeeping.test.sh (edits 1 to 4 come first and the run in item 5 is red; replayed in a scratch copy, the finished change passes all 32 checks and the old script fails them)
blast-radius: bin/unit-bookkeeping.sh:19, bin/unit-bookkeeping.sh:23, bin/unit-bookkeeping.sh:49, bin/unit-bookkeeping.sh:59, bin/unit-bookkeeping.sh:70, agents/orchestrator.md:476, agents/orchestrator.md:545, agents/orchestrator.md:551, tests/unit-bookkeeping.test.sh:32, tests/unit-bookkeeping.test.sh:50, tests/unit-bookkeeping.test.sh:53. Line numbers are at eb59e217; work from the anchors.
script-spec-5a (replaced by this fix): `dispatch` never writes a tier file, on any path (ladder, helper-missing or EXHAUSTED). The reviewer dispatch header gets its `Implementer tier:` line only from the `--implementer-tier` argument, so the helper-missing path cannot leave a stale tier.
script-spec-7 (replaced by this fix): `dispatch` records nothing; script-spec-10 holds trivially.
script-spec-8 (extended): the reviewer word is reviewer-tier's first stdout line when the helper exits 0 and that line is exactly `sonnet` or `opus`; a non-zero exit, a missing script or any other word is `opus`.
script-spec-9 (amended): `review <unit> <baseline> [--implementer-tier <t>]` takes the flag as the 4th and 5th argument, or no extra argument; any other argument count, or a 4th argument other than `--implementer-tier`, prints the usage line and exits 2. The header's second line is `Implementer tier: <t>` only when `<t>` is `haiku`, `sonnet` or `opus`; otherwise the line is omitted.
script-spec-11: a contract-guard that fails or prints nothing yields `guard: guard unavailable` and the RULING `decision=contract-guard sonnet: guard unavailable`; the guard's stderr is discarded. A ladder line whose first field is not `ladder-tier:` yields `model: opus`.
design-note: the CLI change (a trailing flag on `review`) was weighed as a decision beyond a fix contract and judged inside it: the flag is optional, the three-argument form still works, and it is the only way to honor orchestrator.md's rule that the tier is that of the model the latest implementer dispatch actually ran on.
orchestrator-prose: no pinned phrase moves. The edits keep `bash .claude/bin/unit-bookkeeping.sh review <task-id> <baseline>` as a prefix, `.claude/bookkeeping/<task-id>.header`, and the phrases pinned by tests/writer-tier-consistency.test.js and tests/reviewer-dispatch-line-order.test.js (replayed in a scratch copy: both pass).
version: .claude-plugin/plugin.json and package.json read 0.31.188 at eb59e217; edits 16 and 17 set 0.31.189. Stop if either reads otherwise.
mirrors: `.claude/` copies and `fileHashes` change only through `node bin/cli.js --update` (constitution P2); it also restamps the 13 other `.claude` files listed in Affected files, which `git add -u -- .claude` stages.
commit-message: fix(qw-u1): reviewer header takes the dispatched implementer tier; helper non-zero exit forces opus
fix-of: 2026-10-21T02:06:00Z
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
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
criterion 15: <FILL: exit and stdout>
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise. In particular, if a `before:` payload is not found verbatim, quote the current text and stop. If `node bin/cli.js --update` reports a diverged mirror it will not regenerate, quote its message and stop. If a gate blocks a command, report it and wait.
